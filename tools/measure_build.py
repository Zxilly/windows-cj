# /// script
# requires-python = ">=3.10"
# dependencies = ["psutil"]
# ///
"""Measure wall time and peak cjc/cjc-frontend memory for a cjpm build.

Samples the resident set of every cjc/cjc-frontend process spawned by the build
every ~400ms (matching the measure_impl.ps1 sampling cadence) and reports the
peak single-process RSS plus the wall-clock duration. Always uses dev_perf_ci.

Usage::

    python tools/measure_build.py -- cjpm build -m windows_sys -j 8
    python tools/measure_build.py --label off -- cjpm build -m windows_sys -j 8
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
import threading
import time
from pathlib import Path

import psutil

ROOT = Path(__file__).resolve().parents[1]
TOOLCHAIN = "dev_perf_ci"
SAMPLE_INTERVAL_SECONDS = 0.4
TARGET_PROCESS_NAMES = {"cjc", "cjc.exe", "cjc-frontend", "cjc-frontend.exe"}


def stdx_static_path() -> str | None:
    existing = os.environ.get("CANGJIE_STDX_PATH_STATIC")
    if existing and (Path(existing) / "stdx").exists():
        return existing
    stdx_root = Path.home() / ".cjv" / "stdx"
    if not stdx_root.exists():
        return None
    candidates = [stdx_root / "tmp_build" / "static", *sorted(stdx_root.glob("*/static"))]
    for candidate in candidates:
        if (candidate / "stdx").exists():
            return str(candidate)
    return None


def command_env() -> dict[str, str]:
    env = os.environ.copy()
    env["cjHeapSize"] = "32GB"
    stdx = stdx_static_path()
    if stdx is not None:
        env["CANGJIE_STDX_PATH_STATIC"] = stdx
    return env


class PeakSampler(threading.Thread):
    def __init__(self) -> None:
        super().__init__(daemon=True)
        self._stop = threading.Event()
        self.peak_rss = 0
        self.peak_process = ""
        self.samples = 0

    def run(self) -> None:
        while not self._stop.is_set():
            for proc in psutil.process_iter(["name"]):
                name = proc.info.get("name") or ""
                if name.lower() not in {n.lower() for n in TARGET_PROCESS_NAMES}:
                    continue
                try:
                    rss = proc.memory_info().rss
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    continue
                if rss > self.peak_rss:
                    self.peak_rss = rss
                    self.peak_process = name
            self.samples += 1
            self._stop.wait(SAMPLE_INTERVAL_SECONDS)

    def stop(self) -> None:
        self._stop.set()


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Measure wall time + peak cjc RSS for a cjpm build.")
    parser.add_argument("--label", default="", help="Label printed with the result line.")
    parser.add_argument(
        "--cwd",
        default=None,
        help="Working directory for the build (e.g. an independent consumer module). Default: repo root.",
    )
    parser.add_argument(
        "command",
        nargs=argparse.REMAINDER,
        help="Command to run after `--` (e.g. cjpm build -m windows_sys -j 8).",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    command = list(args.command)
    if command and command[0] == "--":
        command = command[1:]
    if not command:
        print("ERROR: no command supplied after --", file=sys.stderr)
        return 1
    full_command = ["cjv", "run", TOOLCHAIN, *command]
    cwd = Path(args.cwd).resolve() if args.cwd else ROOT
    print(f"+ {subprocess.list2cmdline(full_command)}  (cwd={cwd})", flush=True)

    sampler = PeakSampler()
    sampler.start()
    start = time.monotonic()
    result = subprocess.run(full_command, cwd=cwd, env=command_env())
    elapsed = time.monotonic() - start
    sampler.stop()
    sampler.join(timeout=2.0)

    peak_gb = sampler.peak_rss / (1024**3)
    label = f"[{args.label}] " if args.label else ""
    print(
        f"\n{label}RESULT wall={elapsed:.1f}s "
        f"peak_cjc_rss={peak_gb:.2f}GB (process={sampler.peak_process or 'n/a'}, "
        f"samples={sampler.samples}, exit={result.returncode})",
        flush=True,
    )
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
