#!/usr/bin/env python3
"""Run windows-runtime tests without relying on unittest --timeout-each.

The Cangjie unittest timeout path starts a worker process and asks the worker
to exit gracefully. On Windows that can hang while the runtime scheduler is
shutting down. This runner keeps the timeout outside the Cangjie test process
and kills the whole child process tree if the run exceeds the watchdog.
"""

from __future__ import annotations

import argparse
import os
import re
import signal
import subprocess
import sys
from pathlib import Path
from typing import Sequence


ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / "windows-runtime"
BINARY = PACKAGE / "target" / "release" / "unittest_bin" / "windows_runtime.exe"


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


SUMMARY_HEADER_RE = re.compile(r"(?m)^\s*Summary:\s*TOTAL:\s*(?P<total>\d+)\s*$")
SUMMARY_FOOTER_RE = re.compile(r"(?m)^\s*-{10,}\s*$")
SUMMARY_COUNT_RE = re.compile(r"\b(PASSED|SKIPPED|FAILED|ERROR):\s*(\d+)\b")
SUMMARY_NAMES = ("PASSED", "SKIPPED", "FAILED", "ERROR")


def positive_int(value: str) -> int:
    parsed = int(value)
    if parsed <= 0:
        raise argparse.ArgumentTypeError("must be greater than zero")
    return parsed


def run_with_watchdog(command: list[str], *, cwd: Path, env: dict[str, str], timeout_seconds: int) -> tuple[int, str]:
    print(f"+ {' '.join(command)}", flush=True)
    creationflags = subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0
    process = subprocess.Popen(
        command,
        cwd=cwd,
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
        print(f"runtime test watchdog expired after {timeout_seconds}s; killed process tree", file=sys.stderr)
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


def runtime_binary_outputs(binary: Path = BINARY) -> tuple[Path, ...]:
    return (
        binary,
        binary.with_name(f"{binary.stem}$test.cjo"),
        binary.with_name(f"{binary.stem}$test.cjo.flag"),
    )


def remove_expected_runtime_binary(binary: Path = BINARY) -> None:
    for stale in runtime_binary_outputs(binary):
        if stale.exists():
            stale.unlink()


def normalize_extra_args(extra_args: list[str]) -> list[str]:
    normalized = extra_args[1:] if extra_args and extra_args[0] == "--" else list(extra_args)
    if any(arg.startswith("--timeout-each") for arg in normalized):
        raise RuntimeError("do not pass --timeout-each here; use --timeout-seconds for the external watchdog")
    return normalized


def runtime_test_command(binary: Path, filter_value: str | None, extra_args: list[str]) -> list[str]:
    command = ["cjv", "exec", str(binary), "--no-color", "--progress-brief"]
    if filter_value:
        command.append(f"--filter={filter_value}")
    command.extend(normalize_extra_args(extra_args))
    return command


def self_test() -> None:
    counts = summary_counts("Summary: TOTAL: 3\n    PASSED: 3, SKIPPED: 0, ERROR: 0\n    FAILED: 0\n")
    assert counts == {"PASSED": 3, "SKIPPED": 0, "FAILED": 0, "ERROR": 0}
    assert executed_test_count(counts) == 3
    assert summary_counts("no summary here") is None
    assert summary_counts("Summary: TOTAL: 1\n    PASSED: 1\n") is None
    assert summary_counts("Summary: TOTAL: 2\n    PASSED: 1, SKIPPED: 0, ERROR: 0\n    FAILED: 0\n") is None
    command = runtime_test_command(Path("runtime.exe"), "Collections", ["--", "--random-seed=1"])
    assert command == [
        "cjv",
        "exec",
        "runtime.exe",
        "--no-color",
        "--progress-brief",
        "--filter=Collections",
        "--random-seed=1",
    ]
    try:
        runtime_test_command(Path("runtime.exe"), None, ["--timeout-each=1"])
        raise AssertionError("--timeout-each was accepted")
    except RuntimeError as exc:
        assert "do not pass --timeout-each" in str(exc)
    binary = Path("runtime.exe")
    assert runtime_binary_outputs(binary) == (
        binary,
        Path("runtime$test.cjo"),
        Path("runtime$test.cjo.flag"),
    )
    print("OK: windows-runtime runner self-test completed")


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--skip-build", action="store_true", help="Run the existing unittest binary.")
    parser.add_argument("--timeout-seconds", type=positive_int, default=120, help="External process-tree watchdog.")
    parser.add_argument(
        "--filter",
        action="append",
        dest="filters",
        default=[],
        help="Forward a unittest filter to the binary. Can be repeated after one build.",
    )
    parser.add_argument("--self-test", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("extra_args", nargs=argparse.REMAINDER, help="Additional unittest arguments after --.")
    args = parser.parse_args(argv)

    if args.self_test:
        self_test()
        return 0

    env = os.environ.copy()
    env["cjHeapSize"] = "32GB"

    if not args.skip_build:
        remove_expected_runtime_binary()
        build_result, _ = run_with_watchdog(
            ["cjpm", "test", "--no-run", "--no-progress", "--no-color"],
            cwd=PACKAGE,
            env=env,
            timeout_seconds=args.timeout_seconds,
        )
        if build_result != 0:
            return build_result
    if not BINARY.exists():
        print(f"missing unittest binary: {BINARY}", file=sys.stderr)
        return 2

    filters = args.filters if args.filters else [None]
    for filter_value in filters:
        try:
            test_args = runtime_test_command(BINARY, filter_value, args.extra_args)
        except RuntimeError as exc:
            print(str(exc), file=sys.stderr)
            return 2

        result, output = run_with_watchdog(test_args, cwd=ROOT, env=env, timeout_seconds=args.timeout_seconds)
        if result != 0:
            return result
        counts = summary_counts(output)
        if counts is None:
            print("unable to parse unittest summary for runtime run", file=sys.stderr)
            return 2
        failed = counts.get("FAILED", 0)
        errors = counts.get("ERROR", 0)
        if failed != 0 or errors != 0:
            print(f"runtime run reported FAILED={failed}, ERROR={errors}", file=sys.stderr)
            return 1
        executed = executed_test_count(counts)
        if executed == 0:
            if filter_value:
                print(f"filtered runtime run matched zero tests: {filter_value}", file=sys.stderr)
            else:
                print("runtime run executed zero tests", file=sys.stderr)
            return 3
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
