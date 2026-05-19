#!/usr/bin/env python3
"""Convert local WinMD roots into split winmd-to-json metadata directories."""

from __future__ import annotations

import argparse
import hashlib
import os
import re
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Sequence


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_PROJECT = ROOT / "winmd-to-json" / "winmd-to-json.csproj"
DEFAULT_TIMEOUT_SECONDS = 300
WINMD_TO_JSON_EXE = "winmd-to-json.exe" if os.name == "nt" else "winmd-to-json"
WINUI_PACKAGE_NAMES = ("microsoft.windowsappsdk", "microsoft.ui.xaml")
JSON_HEADER_RE = {
    "winmd_file": re.compile(r'"winmd_file"\s*:\s*"([^"]+)"'),
    "winmd_sha256": re.compile(r'"winmd_sha256"\s*:\s*"([0-9a-fA-F]+)"'),
}


@dataclass(frozen=True)
class CommandResult:
    returncode: int
    output: str


@dataclass(frozen=True)
class CandidateRoot:
    path: Path
    package_name: str
    version: str
    winmd_count: int


def fail(message: str) -> None:
    raise RuntimeError(message)


def positive_int(value: str) -> int:
    parsed = int(value)
    if parsed <= 0:
        raise argparse.ArgumentTypeError("must be greater than zero")
    return parsed


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Convert explicit WinUI/WindowsAppSDK .winmd roots into JSON for "
            "check_windows_common_codegen.py."
        )
    )
    parser.add_argument(
        "--winmd-root",
        action="append",
        type=Path,
        default=[],
        metavar="PATH",
        help="Raw .winmd file or directory to convert. Repeat for multiple roots.",
    )
    parser.add_argument(
        "--json-dir",
        type=Path,
        metavar="DIR",
        help="Output directory for split JSON files.",
    )
    parser.add_argument(
        "--project",
        type=Path,
        default=DEFAULT_PROJECT,
        help="Local winmd-to-json dotnet project. Defaults to windows-cj/winmd-to-json.",
    )
    parser.add_argument(
        "--configuration",
        default="Release",
        help="dotnet publish configuration used for the local converter project.",
    )
    parser.add_argument(
        "--tool-dir",
        type=Path,
        metavar="DIR",
        help="Directory for the published converter. Defaults to a temporary directory.",
    )
    parser.add_argument(
        "--tool-exe",
        type=Path,
        metavar="EXE",
        help="Use an already-built local winmd-to-json executable instead of publishing.",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Remove existing top-level .json files from --json-dir before converting.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Validate inputs and print the publish/convert commands without writing JSON.",
    )
    parser.add_argument(
        "--list-candidates",
        action="store_true",
        help=(
            "List local WinUI/WindowsAppSDK WinMD roots from the NuGet cache. "
            "These paths are never used unless passed back with --winmd-root."
        ),
    )
    parser.add_argument(
        "--candidate-limit",
        type=positive_int,
        default=20,
        help="Maximum number of candidate roots to print with --list-candidates.",
    )
    parser.add_argument(
        "--timeout-seconds",
        type=positive_int,
        default=DEFAULT_TIMEOUT_SECONDS,
        help="Timeout for dotnet publish and winmd-to-json conversion.",
    )
    parser.add_argument(
        "--self-test",
        action="store_true",
        help=argparse.SUPPRESS,
    )
    return parser.parse_args(argv)


def display_path(path: Path) -> str:
    try:
        return str(path.resolve(strict=False).relative_to(Path.cwd().resolve()))
    except ValueError:
        return str(path)


def resolve_path(path: Path) -> Path:
    path = path.expanduser()
    if not path.is_absolute():
        path = Path.cwd() / path
    return path.resolve(strict=False)


def unique_paths(paths: Sequence[Path]) -> list[Path]:
    unique: list[Path] = []
    seen: set[str] = set()
    for path in paths:
        key = os.path.normcase(str(path.resolve(strict=False)))
        if key in seen:
            continue
        seen.add(key)
        unique.append(path)
    return unique


def quote_command(command: Sequence[object]) -> str:
    return subprocess.list2cmdline([str(part) for part in command])


def run_command(command: Sequence[object], label: str, timeout_seconds: int) -> CommandResult:
    print(f"+ {quote_command(command)}")
    completed = subprocess.run(
        [str(part) for part in command],
        cwd=str(ROOT),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=timeout_seconds,
    )
    output = completed.stdout or ""
    if output.strip():
        print(output.rstrip())
    if completed.returncode != 0:
        fail(f"{label} failed with exit code {completed.returncode}")
    return CommandResult(completed.returncode, output)


def resolve_project(path: Path) -> Path:
    project = resolve_path(path)
    if not project.exists():
        fail(f"missing local winmd-to-json project: {project}")
    if not project.is_file():
        fail(f"winmd-to-json project is not a file: {project}")
    return project


def resolve_tool_exe(path: Path) -> Path:
    tool = resolve_path(path)
    if not tool.exists():
        fail(f"missing winmd-to-json executable: {tool}")
    if not tool.is_file():
        fail(f"winmd-to-json executable is not a file: {tool}")
    return tool


def publish_tool(project: Path, tool_dir: Path, configuration: str, timeout_seconds: int) -> Path:
    tool_dir.mkdir(parents=True, exist_ok=True)
    command = [
        "dotnet",
        "publish",
        project,
        "-c",
        configuration,
        "--no-restore",
        "-o",
        tool_dir,
    ]
    run_command(command, "winmd-to-json publish", timeout_seconds)
    tool = tool_dir / WINMD_TO_JSON_EXE
    if not tool.exists():
        fail(f"winmd-to-json executable was not produced: {tool}")
    return tool


def collect_winmd_files(roots: Sequence[Path]) -> list[Path]:
    files: list[Path] = []
    for raw_root in roots:
        root = resolve_path(raw_root)
        if not root.exists():
            fail(f"missing WinMD root: {root}")
        if root.is_file():
            if root.suffix.lower() != ".winmd":
                fail(f"WinMD file path must end with .winmd: {root}")
            files.append(root)
            continue
        root_files = sorted(path for path in root.rglob("*.winmd") if path.is_file())
        if not root_files:
            fail(f"WinMD directory contains no .winmd files: {root}")
        files.extend(root_files)
    return unique_paths(files)


def prepare_json_dir(path: Path, overwrite: bool, dry_run: bool) -> Path:
    json_dir = resolve_path(path)
    if dry_run:
        if json_dir.exists() and not json_dir.is_dir():
            fail(f"--json-dir exists but is not a directory: {json_dir}")
        return json_dir
    if json_dir.exists() and not json_dir.is_dir():
        fail(f"--json-dir exists but is not a directory: {json_dir}")
    existing_json = sorted(json_dir.glob("*.json")) if json_dir.exists() else []
    if existing_json and not overwrite:
        fail(
            f"--json-dir already contains {len(existing_json)} JSON file(s): {json_dir}. "
            "Use --overwrite to replace top-level JSON files."
        )
    json_dir.mkdir(parents=True, exist_ok=True)
    if overwrite:
        for json_file in existing_json:
            json_file.unlink()
    return json_dir


def compute_winmd_hashes(files: Sequence[Path]) -> dict[str, set[str]]:
    hashes: dict[str, set[str]] = {}
    for path in files:
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        hashes.setdefault(path.name, set()).add(digest)
    return hashes


def extract_json_header(path: Path) -> tuple[str, str]:
    with path.open("r", encoding="utf-8", errors="replace") as f:
        prefix = f.read(4096)
    values: dict[str, str] = {}
    for name, pattern in JSON_HEADER_RE.items():
        match = pattern.search(prefix)
        if match is None:
            fail(f"{display_path(path)} is missing top-level {name}")
        values[name] = match.group(1)
    return values["winmd_file"], values["winmd_sha256"].lower()


def validate_json_headers(json_dir: Path, winmd_files: Sequence[Path]) -> int:
    json_files = sorted(json_dir.glob("*.json"))
    if not json_files:
        fail(f"winmd-to-json produced no JSON files in {json_dir}")
    hashes = compute_winmd_hashes(winmd_files)
    for json_file in json_files:
        winmd_file, winmd_sha256 = extract_json_header(json_file)
        expected = hashes.get(winmd_file)
        if expected is None:
            fail(f"{display_path(json_file)} references an input not passed to the helper: {winmd_file}")
        if winmd_sha256 not in expected:
            fail(f"{display_path(json_file)} has a winmd_sha256 that does not match {winmd_file}")
    return len(json_files)


def convert_winmds(tool: Path, json_dir: Path, winmd_files: Sequence[Path], timeout_seconds: int) -> None:
    command = [tool, "-d", json_dir, *winmd_files]
    run_command(command, "winmd-to-json conversion", timeout_seconds)


def nuget_package_roots() -> list[Path]:
    roots: list[Path] = []
    if os.environ.get("NUGET_PACKAGES"):
        roots.append(resolve_path(Path(os.environ["NUGET_PACKAGES"])))
    if os.environ.get("USERPROFILE"):
        roots.append(resolve_path(Path(os.environ["USERPROFILE"]) / ".nuget" / "packages"))
    return unique_paths(roots)


def discover_candidates(limit: int) -> list[CandidateRoot]:
    candidates: list[CandidateRoot] = []
    seen: set[str] = set()
    for package_root in nuget_package_roots():
        if not package_root.exists():
            continue
        for package_name in WINUI_PACKAGE_NAMES:
            package_dir = package_root / package_name
            if not package_dir.exists():
                continue
            versions = sorted((path for path in package_dir.iterdir() if path.is_dir()), key=lambda p: p.name, reverse=True)
            for version_dir in versions:
                parents = sorted({path.parent for path in version_dir.rglob("*.winmd") if path.is_file()})
                for parent in parents:
                    key = os.path.normcase(str(parent.resolve(strict=False)))
                    if key in seen:
                        continue
                    winmd_count = len(list(parent.glob("*.winmd")))
                    if winmd_count == 0:
                        continue
                    seen.add(key)
                    candidates.append(CandidateRoot(parent, package_name, version_dir.name, winmd_count))
                    if len(candidates) >= limit:
                        return candidates
    return candidates


def print_candidates(limit: int) -> None:
    candidates = discover_candidates(limit)
    if not candidates:
        print("No local WinUI/WindowsAppSDK WinMD candidate roots found.")
        print("Conversion still requires an explicit --winmd-root path.")
        return
    print("Local WinUI/WindowsAppSDK WinMD candidate roots:")
    for candidate in candidates:
        print(
            f"  {candidate.path} "
            f"({candidate.package_name} {candidate.version}, {candidate.winmd_count} winmd file(s))"
        )
    print("Pass one or more paths back with --winmd-root; no candidate is used automatically.")


def print_plan(winmd_files: Sequence[Path], json_dir: Path, roots: Sequence[Path]) -> None:
    print(f"WinMD inputs: {len(winmd_files)}")
    for path in winmd_files[:20]:
        print(f"  {path}")
    if len(winmd_files) > 20:
        print(f"  ... {len(winmd_files) - 20} more")
    print(f"JSON output directory: {json_dir}")
    gate_args = ["--winui-winmd-json-dir", str(json_dir)]
    for root in roots:
        gate_args.extend(["--winui-winmd-root", str(resolve_path(root))])
    print("Gate arguments:")
    print(f"  {' '.join(gate_args)}")


def print_dry_run(
    project: Path,
    tool_dir: Path | None,
    tool_exe: Path | None,
    configuration: str,
    json_dir: Path,
    winmd_files: Sequence[Path],
) -> None:
    print("DRY-RUN: no files will be written.")
    if tool_exe is None:
        publish_dir = tool_dir if tool_dir is not None else Path("<temporary-tool-dir>")
        publish_command = ["dotnet", "publish", project, "-c", configuration, "--no-restore", "-o", publish_dir]
        planned_tool = publish_dir / WINMD_TO_JSON_EXE
        print(f"DRY-RUN publish: {quote_command(publish_command)}")
    else:
        planned_tool = tool_exe
        print(f"DRY-RUN tool: {planned_tool}")
    convert_command = [planned_tool, "-d", json_dir, *winmd_files]
    print(f"DRY-RUN convert: {quote_command(convert_command)}")


def self_test() -> None:
    assert unique_paths([Path("a"), Path("a")]) == [Path("a")]
    assert collect_winmd_files([]) == []
    command = quote_command(["tool", "-d", "out", "input.winmd"])
    assert "tool" in command and "input.winmd" in command
    print("OK: convert_winmd_to_json self-test completed")


def validate_args(args: argparse.Namespace) -> None:
    if args.tool_dir is not None and args.tool_exe is not None:
        fail("--tool-dir and --tool-exe are mutually exclusive")
    if not args.winmd_root and not args.list_candidates and not args.self_test:
        fail("add --winmd-root <file-or-dir> or use --list-candidates")
    if args.winmd_root and args.json_dir is None:
        fail("--json-dir is required when --winmd-root is provided")


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        validate_args(args)
        if args.self_test:
            self_test()
            return 0
        if args.list_candidates:
            print_candidates(args.candidate_limit)
            if not args.winmd_root:
                return 0

        project = resolve_project(args.project)
        tool_exe = resolve_tool_exe(args.tool_exe) if args.tool_exe is not None else None
        tool_dir = resolve_path(args.tool_dir) if args.tool_dir is not None else None
        winmd_files = collect_winmd_files(args.winmd_root)
        json_dir = prepare_json_dir(args.json_dir, args.overwrite, args.dry_run)
        print_plan(winmd_files, json_dir, args.winmd_root)

        if args.dry_run:
            print_dry_run(project, tool_dir, tool_exe, args.configuration, json_dir, winmd_files)
            return 0

        started = time.perf_counter()
        if tool_exe is not None:
            tool = tool_exe
            convert_winmds(tool, json_dir, winmd_files, args.timeout_seconds)
        elif tool_dir is not None:
            tool = publish_tool(project, tool_dir, args.configuration, args.timeout_seconds)
            convert_winmds(tool, json_dir, winmd_files, args.timeout_seconds)
        else:
            with tempfile.TemporaryDirectory(prefix="winmd-to-json-tool-") as temp:
                tool = publish_tool(project, Path(temp), args.configuration, args.timeout_seconds)
                convert_winmds(tool, json_dir, winmd_files, args.timeout_seconds)

        json_count = validate_json_headers(json_dir, winmd_files)
        elapsed = time.perf_counter() - started
        print(f"OK: converted {len(winmd_files)} WinMD file(s) into {json_count} JSON file(s) in {elapsed:.2f}s")
        return 0
    except (RuntimeError, subprocess.TimeoutExpired) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
