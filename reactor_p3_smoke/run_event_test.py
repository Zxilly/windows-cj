#!/usr/bin/env python3
"""Validate the non-Click event round-trip: launch the reactor demo, screenshot
the initial state (feature: ON), toggle the "enable feature" CheckBox via UI
Automation (a CheckedChanged event), screenshot again (feature: OFF), then stop.

Proves CheckedChanged -> onChanged -> useState -> reconcile -> TextBlock update.
"""

from __future__ import annotations

import shutil
import subprocess
import sys
import time
from pathlib import Path

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

ROOT = Path(__file__).resolve().parent
WORKSPACE = ROOT.parent
STAGE = WORKSPACE / ".generated" / "windows-app-sdk"
PS1_SHOT = ROOT / "screenshot.ps1"
PS1_TOGGLE = ROOT / "toggle_checkbox.ps1"
LOG = ROOT / "target" / "p4b_event_run.log"
BEFORE = ROOT / "target" / "p4b_event_before.png"
AFTER = ROOT / "target" / "p4b_event_after.png"


def find_exe() -> Path:
    for c in [ROOT / "target" / "release" / "bin" / "main.exe"]:
        if c.is_file():
            return c
    for hit in (ROOT / "target").glob("**/main.exe"):
        return hit
    raise SystemExit("executable not found; build first")


def stage_runtime(exe_dir: Path) -> None:
    boot = STAGE / "Microsoft.WindowsAppRuntime.Bootstrap.dll"
    if not boot.is_file():
        raise SystemExit(f"missing staged bootstrap dll: {boot}")
    shutil.copy2(boot, exe_dir / boot.name)
    pri = STAGE / "resources.pri"
    if pri.is_file():
        shutil.copy2(pri, exe_dir / "resources.pri")


def ps(script: Path, *args: str) -> str:
    r = subprocess.run(
        ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(script), *args],
        capture_output=True, encoding="utf-8", errors="replace")
    return (r.stdout or "") + (("\n[stderr]\n" + r.stderr) if r.stderr else "")


def main() -> int:
    exe = find_exe()
    exe_dir = exe.parent
    stage_runtime(exe_dir)
    LOG.parent.mkdir(parents=True, exist_ok=True)
    log = open(LOG, "wb")
    proc = subprocess.Popen(["cjv", "exec", str(exe)], cwd=str(exe_dir), stdout=log, stderr=subprocess.STDOUT)
    print(f"launched pid={proc.pid}", flush=True)
    time.sleep(10)
    if proc.poll() is not None:
        print(f"PROCESS_EXITED_EARLY code={proc.returncode}", flush=True)

    print("--- screenshot BEFORE (expect feature: ON) ---", flush=True)
    print(ps(PS1_SHOT, "-OutFull", str(ROOT / "target" / "p4b_full_before.png"), "-OutFg", str(BEFORE)), flush=True)

    print("--- UIA toggle checkbox (CheckedChanged event) ---", flush=True)
    print(ps(PS1_TOGGLE), flush=True)
    time.sleep(1.2)

    print("--- screenshot AFTER (expect feature: OFF) ---", flush=True)
    print(ps(PS1_SHOT, "-OutFull", str(ROOT / "target" / "p4b_full_after.png"), "-OutFg", str(AFTER)), flush=True)

    try:
        subprocess.run(["taskkill", "/PID", str(proc.pid), "/T", "/F"], capture_output=True)
        proc.wait(timeout=10)
    except Exception:
        pass
    log.close()

    print("--- run log tail ---", flush=True)
    try:
        print(LOG.read_bytes().decode("utf-8", errors="replace")[-3000:], flush=True)
    except Exception as e:
        print(f"log read failed: {e}", flush=True)
    print(f"BEFORE={BEFORE} exists={BEFORE.is_file()}", flush=True)
    print(f"AFTER={AFTER} exists={AFTER.is_file()}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
