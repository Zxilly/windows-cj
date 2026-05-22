#!/usr/bin/env python3
"""Build and run workspace tests without the root std.testrunner worker path.

The root `cjpm test` aggregation runs package test binaries as unittest workers.
On Windows, the worker protocol can keep `windows_runtime.exe` alive after the
test body has completed. Captured `--no-progress` runtime output has shown the
same shutdown issue, so direct execution uses `--progress-brief`, matching the
runtime-specific watchdog runner. This runner still uses `cjpm test --no-run`
for the supported build path, but executes each produced test binary directly
through `cjv exec` under an external process-tree watchdog.
"""

from __future__ import annotations

import argparse
import os
import re
import signal
import subprocess
import sys
import tempfile
import tomllib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
UNITTEST_BIN = ROOT / "target" / "release" / "unittest_bin"
DEFAULT_TIMEOUT_SECONDS = 240
SUMMARY_HEADER_RE = re.compile(r"(?m)^\s*Summary:\s*TOTAL:\s*(?P<total>\d+)\s*$")
SUMMARY_FOOTER_RE = re.compile(r"(?m)^\s*-{10,}\s*$")
SUMMARY_COUNT_RE = re.compile(r"\b(PASSED|SKIPPED|FAILED|ERROR):\s*(\d+)\b")
SUMMARY_NAMES = ("PASSED", "SKIPPED", "FAILED", "ERROR")
PACKAGE_RE = re.compile(r"^\s*package\s+([A-Za-z_][A-Za-z0-9_.]*)", re.MULTILINE)


def positive_int(value: str) -> int:
    parsed = int(value)
    if parsed <= 0:
        raise argparse.ArgumentTypeError("must be greater than zero")
    return parsed


def load_toml(path: Path) -> dict:
    with path.open("rb") as f:
        return tomllib.load(f)


def workspace_members() -> list[str]:
    config = load_toml(ROOT / "cjpm.toml")
    return list(config.get("workspace", {}).get("members", []))


def package_name(member: str) -> str:
    config = load_toml(ROOT / member / "cjpm.toml")
    name = config.get("package", {}).get("name")
    if not isinstance(name, str) or not name:
        raise RuntimeError(f"{member} cjpm.toml is missing package.name")
    return name


def source_files(member: str) -> list[Path]:
    root = ROOT / member
    sources: list[Path] = []
    for source in root.rglob("*.cj"):
        if "target" in source.relative_to(root).parts:
            continue
        sources.append(source)
    return sorted(sources)


def test_package_names(member: str) -> list[str]:
    names: set[str] = set()
    for source in source_files(member):
        text = source.read_text(encoding="utf-8")
        if "@Test" not in text:
            continue
        match = PACKAGE_RE.search(text)
        if match is None:
            raise RuntimeError(f"{source.relative_to(ROOT)} contains @Test but no package declaration")
        names.add(match.group(1))
    return sorted(names)


def test_binaries_for_member(member: str) -> list[Path]:
    return [UNITTEST_BIN / f"{name}.exe" for name in test_package_names(member)]


def remove_expected_test_binaries(member: str) -> None:
    for binary in test_binaries_for_member(member):
        stale_paths = (
            binary,
            binary.with_name(f"{binary.stem}$test.cjo"),
            binary.with_name(f"{binary.stem}$test.cjo.flag"),
        )
        for stale in stale_paths:
            if stale.exists():
                stale.unlink()


def member_has_tests(member: str) -> bool:
    return len(test_package_names(member)) > 0


def kill_process_tree(process: subprocess.Popen[str]) -> None:
    if process.poll() is not None:
        return
    if os.name == "nt":
        subprocess.run(
            ["taskkill", "/F", "/T", "/PID", str(process.pid)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        return
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass


def run_with_watchdog(
    command: list[str],
    *,
    env: dict[str, str],
    timeout_seconds: int,
) -> tuple[int, str]:
    print(f"+ {' '.join(command)}", flush=True)
    creationflags = subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0
    process = subprocess.Popen(
        command,
        cwd=ROOT,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        creationflags=creationflags,
        start_new_session=(os.name != "nt"),
    )
    try:
        output, _ = process.communicate(timeout=timeout_seconds)
    except subprocess.TimeoutExpired:
        kill_process_tree(process)
        output, _ = process.communicate()
        if output:
            print(output, end="")
        print(
            f"workspace test watchdog expired after {timeout_seconds}s; "
            f"killed process tree for: {' '.join(command)}",
            file=sys.stderr,
        )
        return 124, output or ""
    if output:
        print(output, end="")
    return process.returncode, output or ""


def summary_counts(output: str) -> dict[str, int] | None:
    headers = list(SUMMARY_HEADER_RE.finditer(output))
    if not headers:
        return None
    for header in reversed(headers):
        block = output[header.end():]
        footer = SUMMARY_FOOTER_RE.search(block)
        if footer:
            block = block[:footer.start()]
        matches = SUMMARY_COUNT_RE.findall(block)
        counts = {name: int(value) for name, value in matches}
        total = int(header.group("total"))
        if all(name in counts for name in SUMMARY_NAMES) and sum(counts[name] for name in SUMMARY_NAMES) == total:
            return {name: counts[name] for name in SUMMARY_NAMES}
    return None


def executed_test_count(counts: dict[str, int]) -> int:
    return counts.get("PASSED", 0) + counts.get("FAILED", 0) + counts.get("ERROR", 0)


def workspace_build_command(member: str) -> list[str]:
    return ["cjpm", "test", "-m", member, "--no-run", "--no-progress", "--no-color"]


def workspace_test_command(binary: Path) -> list[str]:
    return ["cjv", "exec", str(binary), "--no-color", "--progress-brief"]


def parse_members(requested: list[str]) -> list[str]:
    members = workspace_members()
    if not requested:
        return [member for member in members if member_has_tests(member)]
    unknown = sorted(set(requested) - set(members))
    if unknown:
        raise RuntimeError(f"unknown workspace members: {unknown}")
    return requested


def dry_run_member(member: str, *, skip_build: bool) -> int:
    name = package_name(member)
    print(f"\n== {member} ({name}) ==", flush=True)
    if skip_build:
        print("# skip-build: existing unittest binaries")
    else:
        print(f"+ {' '.join(workspace_build_command(member))}")
    binaries = test_binaries_for_member(member)
    if not binaries:
        print(f"{member} has no test packages", file=sys.stderr)
        return 2
    for binary in binaries:
        print(f"+ {' '.join(workspace_test_command(binary))}")
    return 0


def run_member(member: str, *, skip_build: bool, env: dict[str, str], timeout_seconds: int) -> int:
    name = package_name(member)
    print(f"\n== {member} ({name}) ==", flush=True)

    if not skip_build:
        remove_expected_test_binaries(member)
        build_result, _ = run_with_watchdog(
            workspace_build_command(member),
            env=env,
            timeout_seconds=timeout_seconds,
        )
        if build_result != 0:
            return build_result

    binaries = test_binaries_for_member(member)
    if not binaries:
        print(f"{member} has no test packages", file=sys.stderr)
        return 2
    missing = [binary for binary in binaries if not binary.exists()]
    if missing:
        for binary in missing:
            print(f"missing unittest binary: {binary}", file=sys.stderr)
        return 2

    for binary in binaries:
        test_result, output = run_with_watchdog(
            workspace_test_command(binary),
            env=env,
            timeout_seconds=timeout_seconds,
        )
        if test_result != 0:
            return test_result

        counts = summary_counts(output)
        if counts is None:
            print(f"unable to parse unittest summary for {binary.name}", file=sys.stderr)
            return 2
        failed = counts.get("FAILED", 0)
        errors = counts.get("ERROR", 0)
        if failed != 0 or errors != 0:
            print(f"{binary.name} reported FAILED={failed}, ERROR={errors}", file=sys.stderr)
            return 1
        executed = executed_test_count(counts)
        if executed == 0:
            print(f"{binary.name} matched zero tests", file=sys.stderr)
            return 3
    return 0


def write_self_test_file(root: Path, relative: str, text: str) -> Path:
    path = root / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    return path


def self_test() -> None:
    original_root = ROOT
    original_unittest_bin = UNITTEST_BIN
    with tempfile.TemporaryDirectory(prefix="workspace-runner-self-test-") as temp_dir:
        workspace = Path(temp_dir)
        globals()["ROOT"] = workspace
        globals()["UNITTEST_BIN"] = workspace / "target" / "release" / "unittest_bin"
        try:
            write_self_test_file(
                workspace,
                "cjpm.toml",
                '[workspace]\nmembers = ["windows-core", "windows-empty"]\n',
            )
            write_self_test_file(workspace, "windows-core/cjpm.toml", '[package]\nname = "windows_core"\n')
            write_self_test_file(workspace, "windows-empty/cjpm.toml", '[package]\nname = "windows_empty"\n')
            write_self_test_file(workspace, "windows-core/src/core_test.cj", "package windows_core.tests\n@Test\nclass T {}\n")
            write_self_test_file(workspace, "windows-empty/src/lib.cj", "package windows_empty\n")
            write_self_test_file(workspace, "windows-core/target/ignored_test.cj", "package ignored\n@Test\nclass T {}\n")

            assert workspace_members() == ["windows-core", "windows-empty"]
            assert package_name("windows-core") == "windows_core"
            assert test_package_names("windows-core") == ["windows_core.tests"]
            assert test_package_names("windows-empty") == []
            assert parse_members([]) == ["windows-core"]
            try:
                parse_members(["missing"])
                raise AssertionError("unknown workspace member was accepted")
            except RuntimeError as exc:
                assert "unknown workspace members" in str(exc)

            binary = globals()["UNITTEST_BIN"] / "windows_core.tests.exe"
            assert test_binaries_for_member("windows-core") == [binary]
            assert workspace_build_command("windows-core") == [
                "cjpm",
                "test",
                "-m",
                "windows-core",
                "--no-run",
                "--no-progress",
                "--no-color",
            ]
            assert workspace_test_command(binary) == ["cjv", "exec", str(binary), "--no-color", "--progress-brief"]

            binary.parent.mkdir(parents=True, exist_ok=True)
            stale_paths = (
                binary,
                binary.with_name(f"{binary.stem}$test.cjo"),
                binary.with_name(f"{binary.stem}$test.cjo.flag"),
            )
            for stale in stale_paths:
                stale.write_text("stale\n", encoding="utf-8")
            remove_expected_test_binaries("windows-core")
            assert not any(stale.exists() for stale in stale_paths)

            counts = summary_counts("Summary: TOTAL: 4\n    PASSED: 4, SKIPPED: 0, ERROR: 0\n    FAILED: 0\n")
            assert counts == {"PASSED": 4, "SKIPPED": 0, "FAILED": 0, "ERROR": 0}
            assert executed_test_count(counts) == 4
            assert summary_counts("missing summary") is None
            assert summary_counts("Summary: TOTAL: 1\n    PASSED: 1\n") is None
            assert summary_counts("Summary: TOTAL: 2\n    PASSED: 1, SKIPPED: 0, ERROR: 0\n    FAILED: 0\n") is None
        finally:
            globals()["ROOT"] = original_root
            globals()["UNITTEST_BIN"] = original_unittest_bin
    print("OK: workspace direct-binary runner self-test completed")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("members", nargs="*", help="Optional workspace members to test.")
    parser.add_argument("--skip-build", action="store_true", help="Run existing root unittest binaries.")
    parser.add_argument("--dry-run", action="store_true", help="Print exact build and cjv exec commands without running them.")
    parser.add_argument("--list", action="store_true", help="List workspace members that contain tests.")
    parser.add_argument("--self-test", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument(
        "--timeout-seconds",
        type=positive_int,
        default=DEFAULT_TIMEOUT_SECONDS,
        help="External process-tree watchdog per build/test step.",
    )
    args = parser.parse_args()

    if args.self_test:
        self_test()
        return 0

    try:
        members = parse_members(args.members)
    except RuntimeError as exc:
        print(str(exc), file=sys.stderr)
        return 2

    if args.list:
        for member in members:
            print(member)
        return 0

    if args.dry_run:
        for member in members:
            result = dry_run_member(member, skip_build=args.skip_build)
            if result != 0:
                return result
        return 0

    env = os.environ.copy()
    env["cjHeapSize"] = "32GB"

    for member in members:
        result = run_member(member, skip_build=args.skip_build, env=env, timeout_seconds=args.timeout_seconds)
        if result != 0:
            return result
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
