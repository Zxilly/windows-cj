#!/usr/bin/env python3
"""Build and publish the winmd-to-json self-contained executable."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path
from typing import Sequence


PROJECT_ROOT = Path(__file__).resolve().parents[1]
PROJECT_FILE = PROJECT_ROOT / "winmd-to-json.csproj"
DEFAULT_OUTPUT_DIR = PROJECT_ROOT / "bin"


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--configuration",
        default="Release",
        help="Build configuration passed to dotnet publish.",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=DEFAULT_OUTPUT_DIR,
        help="Output directory for the published executable.",
    )
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    if not PROJECT_FILE.exists():
        print(f"FAIL: csproj not found: {PROJECT_FILE}", file=sys.stderr)
        return 2

    output_dir = args.output_dir if args.output_dir.is_absolute() else PROJECT_ROOT / args.output_dir
    command = [
        "dotnet",
        "publish",
        str(PROJECT_FILE),
        "-c",
        args.configuration,
        "-o",
        str(output_dir),
    ]
    print(f"Publishing {PROJECT_FILE} (Configuration={args.configuration})...")
    print("+ " + subprocess.list2cmdline(command))
    result = subprocess.run(command, cwd=PROJECT_ROOT)
    if result.returncode != 0:
        print(f"FAIL: dotnet publish failed with exit code {result.returncode}", file=sys.stderr)
        return result.returncode

    expected_exe = output_dir / "winmd-to-json.exe"
    if not expected_exe.exists():
        print(f"FAIL: expected published exe not found: {expected_exe}", file=sys.stderr)
        return 1

    print(f"OK: {expected_exe}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
