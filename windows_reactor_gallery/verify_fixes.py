#!/usr/bin/env python3
"""Verify the per-control split + audit bug fixes render at runtime: navigate to
the three fixed pages (Flyout #6, Materials #3/#4, DatePicker #1/#2), capture
each, and exercise the new button.flyout() popup end-to-end via a UIA click."""
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
SHOT = WORKSPACE / "reactor_p3_smoke" / "screenshot.ps1"
CLICK = WORKSPACE / "reactor_p3_smoke" / "click_increment.ps1"
CAP = ROOT / "capture_window.ps1"
NAV = ROOT / "nav_select.ps1"
TGT = ROOT / "target"
LOG = TGT / "fixes_run.log"
TITLE = "Reactor WinUI Gallery"


def find_exe() -> Path:
    cand = ROOT / "target" / "release" / "bin" / "main.exe"
    if cand.is_file():
        return cand
    for hit in (ROOT / "target").glob("**/main.exe"):
        return hit
    raise SystemExit("gallery exe not found; build first")


def ps(*args) -> str:
    r = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", *args],
                       capture_output=True, encoding="utf-8", errors="replace")
    return (r.stdout or "") + (("\n[stderr]\n" + r.stderr) if r.stderr else "")


def nav(items: str):
    print(f"--- nav {items} ---", flush=True)
    print(ps("-File", str(NAV), "-TitleMatch", TITLE, "-Items", items, "-PauseMs", "1600"), flush=True)
    time.sleep(1.2)


def capture(name: str):
    out = str(TGT / f"fix_{name}.png")
    print(f"--- capture {name} ---", flush=True)
    print(ps("-File", str(CAP), "-TitleMatch", TITLE, "-Out", out, "-W", "1040", "-H", "1560"), flush=True)


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
    TGT.mkdir(parents=True, exist_ok=True)
    log = open(LOG, "wb")
    proc = subprocess.Popen(["cjv", "exec", str(exe)], cwd=str(exe_dir), stdout=log, stderr=subprocess.STDOUT)
    print(f"launched pid={proc.pid}", flush=True)
    time.sleep(9)

    # #6 Flyout page: render + interactive popup (exercises button.flyout()).
    nav("Dialogs and Flyouts|Flyout")
    capture("flyout_page")
    print("--- invoke 'Click for flyout' ---", flush=True)
    print(ps("-File", str(CLICK), "-TitleMatch", TITLE, "-ButtonName", "Click for flyout", "-Times", "1"), flush=True)
    time.sleep(1.0)
    # Full-screen grab to catch the popup (flyouts open in a separate layer).
    print(ps("-File", str(SHOT), "-OutFull", str(TGT / "fix_flyout_popup_full.png"),
             "-OutFg", str(TGT / "fix_flyout_popup.png"), "-TitleMatch", TITLE), flush=True)

    # #3/#4 Materials page: render (backdrop switch wired via setBackdrop).
    nav("Design Guidance|Materials")
    capture("materials_page")

    # #1/#2 DatePicker page: render.
    nav("Date and Time|DatePicker")
    capture("datepicker_page")

    try:
        subprocess.run(["taskkill", "/PID", str(proc.pid), "/T", "/F"], capture_output=True)
        proc.wait(timeout=10)
    except Exception:
        pass
    log.close()
    print("--- run log tail ---", flush=True)
    try:
        print(LOG.read_bytes().decode("utf-8", errors="replace")[-2000:], flush=True)
    except Exception as e:
        print(f"log read failed: {e}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
