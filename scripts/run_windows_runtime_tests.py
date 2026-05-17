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


SUMMARY_COUNT_RE = re.compile(r"\b(PASSED|FAILED|ERROR):\s*(\d+)\b")
SUMMARY_NAMES = ("PASSED", "FAILED", "ERROR")


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
    matches = SUMMARY_COUNT_RE.findall(output)
    if not matches:
        return None
    counts = {name: 0 for name in SUMMARY_NAMES}
    for name, value in matches:
        counts[name] = int(value)
    return counts


def executed_test_count(counts: dict[str, int]) -> int:
    return counts.get("PASSED", 0) + counts.get("FAILED", 0) + counts.get("ERROR", 0)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--skip-build", action="store_true", help="Run the existing unittest binary.")
    parser.add_argument("--timeout-seconds", type=int, default=120, help="External process-tree watchdog.")
    parser.add_argument("--filter", help="Forward a unittest filter to the binary.")
    parser.add_argument("extra_args", nargs=argparse.REMAINDER, help="Additional unittest arguments after --.")
    args = parser.parse_args()

    env = os.environ.copy()
    env["cjHeapSize"] = "32GB"

    if not args.skip_build:
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

    test_args = ["cjv", "exec", str(BINARY), "--no-color", "--progress-brief"]
    if args.filter:
        test_args.append(f"--filter={args.filter}")
    if args.extra_args:
        extra_args = args.extra_args[1:] if args.extra_args[0] == "--" else args.extra_args
        if any(arg.startswith("--timeout-each") for arg in extra_args):
            print("do not pass --timeout-each here; use --timeout-seconds for the external watchdog", file=sys.stderr)
            return 2
        test_args.extend(extra_args)

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
        if args.filter:
            print(f"filtered runtime run matched zero tests: {args.filter}", file=sys.stderr)
        else:
            print("runtime run executed zero tests", file=sys.stderr)
        return 3
    return result


if __name__ == "__main__":
    raise SystemExit(main())
