#!/usr/bin/env python3
"""Clean render check for the Materials (#3/#4) and DatePicker (#1/#2) pages:
launch, navigate to each, tall-capture. No in-page interaction."""
from __future__ import annotations
import shutil, subprocess, sys, time
from pathlib import Path

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

ROOT = Path(__file__).resolve().parent
WORKSPACE = ROOT.parent
STAGE = WORKSPACE / ".generated" / "windows-app-sdk"
CAP = ROOT / "capture_window.ps1"
NAV = ROOT / "nav_select.ps1"
TGT = ROOT / "target"
TITLE = "Reactor WinUI Gallery"


def find_exe() -> Path:
    cand = ROOT / "target" / "release" / "bin" / "main.exe"
    if cand.is_file():
        return cand
    for hit in (ROOT / "target").glob("**/main.exe"):
        return hit
    raise SystemExit("gallery exe not found")


def ps(*args) -> str:
    r = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", *args],
                       capture_output=True, encoding="utf-8", errors="replace")
    return (r.stdout or "") + (("\n[stderr]\n" + r.stderr) if r.stderr else "")


def main() -> int:
    exe = find_exe()
    exe_dir = exe.parent
    boot = STAGE / "Microsoft.WindowsAppRuntime.Bootstrap.dll"
    shutil.copy2(boot, exe_dir / boot.name)
    pri = STAGE / "resources.pri"
    if pri.is_file():
        shutil.copy2(pri, exe_dir / "resources.pri")
    TGT.mkdir(parents=True, exist_ok=True)
    log = open(TGT / "pages_run.log", "wb")
    proc = subprocess.Popen(["cjv", "exec", str(exe)], cwd=str(exe_dir), stdout=log, stderr=subprocess.STDOUT)
    print(f"launched pid={proc.pid}", flush=True)
    time.sleep(9)

    for items, name in [("Date and Time|DatePicker", "datepicker"),
                        ("Design Guidance|Materials", "materials")]:
        print(f"--- nav {items} ---", flush=True)
        print(ps("-File", str(NAV), "-TitleMatch", TITLE, "-Items", items, "-PauseMs", "1600"), flush=True)
        time.sleep(1.2)
        out = str(TGT / f"fix_{name}_page.png")
        print(ps("-File", str(CAP), "-TitleMatch", TITLE, "-Out", out, "-W", "1040", "-H", "1560"), flush=True)

    try:
        subprocess.run(["taskkill", "/PID", str(proc.pid), "/T", "/F"], capture_output=True)
        proc.wait(timeout=10)
    except Exception:
        pass
    log.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
