#!/usr/bin/env python3
"""Run one reactor minimal example via `cjv exec main.exe <name>`, screenshot, stop.

Usage: python run_minimal.py <example_name> [title_match]
"""
from __future__ import annotations
import os, shutil, subprocess, sys, time
from pathlib import Path

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

ROOT = Path(__file__).resolve().parent
WORKSPACE = ROOT.parent
STAGE = WORKSPACE / ".generated" / "windows-app-sdk"
PS1 = WORKSPACE / "reactor_p3_smoke" / "screenshot.ps1"

NAME = sys.argv[1] if len(sys.argv) > 1 else "counter"
TITLE = sys.argv[2] if len(sys.argv) > 2 else "windows_reactor"
FULL = ROOT / "target" / f"min_{NAME}_full.png"
FG = ROOT / "target" / f"min_{NAME}.png"
LOG = ROOT / "target" / f"min_{NAME}.log"


def find_exe() -> Path:
    for c in [ROOT / "target" / "release" / "bin" / "main.exe"]:
        if c.is_file():
            return c
    for hit in (ROOT / "target").glob("**/main.exe"):
        return hit
    raise SystemExit("minimal exe not found; build first")


def main() -> int:
    exe = find_exe()
    exe_dir = exe.parent
    boot = STAGE / "Microsoft.WindowsAppRuntime.Bootstrap.dll"
    if not boot.is_file():
        raise SystemExit(f"missing staged bootstrap dll: {boot}")
    shutil.copy2(boot, exe_dir / boot.name)
    pri = STAGE / "resources.pri"
    if pri.is_file():
        shutil.copy2(pri, exe_dir / "resources.pri")
    LOG.parent.mkdir(parents=True, exist_ok=True)
    # The reactor UI cjthread needs a generous stack (WinUI native layout/pump
    # frames run beneath the render loop); the default cjthread stack is too small.
    os.environ.setdefault("cjStackSize", "32mb")
    log = open(LOG, "wb")
    proc = subprocess.Popen(["cjv", "exec", str(exe), NAME], cwd=str(exe_dir),
                            stdout=log, stderr=subprocess.STDOUT)
    print(f"launched pid={proc.pid} example={NAME}", flush=True)
    time.sleep(11)
    if proc.poll() is not None:
        print(f"PROCESS_EXITED_EARLY code={proc.returncode}", flush=True)
    r = subprocess.run(
        ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(PS1),
         "-OutFull", str(FULL), "-OutFg", str(FG), "-TitleMatch", TITLE],
        capture_output=True, encoding="utf-8", errors="replace")
    print((r.stdout or "") + (("\n[stderr]\n" + r.stderr) if r.stderr else ""), flush=True)
    try:
        subprocess.run(["taskkill", "/PID", str(proc.pid), "/T", "/F"], capture_output=True)
        proc.wait(timeout=10)
    except Exception:
        pass
    log.close()
    print("--- run log tail ---", flush=True)
    try:
        print(LOG.read_bytes().decode("utf-8", errors="replace")[-2500:], flush=True)
    except Exception as e:
        print(f"log read failed: {e}", flush=True)
    print(f"FG={FG} exists={FG.is_file()}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
