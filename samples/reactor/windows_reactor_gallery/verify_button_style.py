#!/usr/bin/env python3
"""Launch the gallery, navigate to the Button sample page via UI Automation,
screenshot it, then inspect the run log for the ButtonStyleVariant (prop 112)
E_NOINTERFACE that the canonical-PIID IMap fix is meant to eliminate."""
from __future__ import annotations
import re, shutil, subprocess, sys, time
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
CAP = ROOT / "capture_window.ps1"
NAV = ROOT / "nav_select.ps1"
LOG = ROOT / "target" / "button_style_run.log"
FULL = ROOT / "target" / "button_style_full.png"
FG = ROOT / "target" / "button_style_window.png"
PW = ROOT / "target" / "button_style_window_printwindow.png"
TITLE = "Reactor WinUI Gallery"


def find_exe() -> Path:
    cand = ROOT / "target" / "release" / "bin" / "main.exe"
    if cand.is_file():
        return cand
    for hit in (ROOT / "target").glob("**/main.exe"):
        return hit
    raise SystemExit("gallery exe not found; build first")


def ps(*args) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", *args],
        capture_output=True, encoding="utf-8", errors="replace")


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
    log = open(LOG, "wb")
    proc = subprocess.Popen(["cjv", "exec", str(exe)], cwd=str(exe_dir),
                            stdout=log, stderr=subprocess.STDOUT)
    print(f"launched pid={proc.pid}", flush=True)
    time.sleep(9)
    if proc.poll() is not None:
        print(f"PROCESS_EXITED_EARLY code={proc.returncode}", flush=True)

    # Navigate: Basic Input (category) -> Button (leaf sample page). Selecting the
    # Button leaf is what drives applyButtonStyle for the accent/subtle/textLink
    # samples that exercise Application.Resources -> IMap<Object,Object>.
    r = ps("-File", str(NAV), "-TitleMatch", TITLE,
           "-Items", "Basic Input|Button", "-PauseMs", "1800")
    print("--- nav ---", flush=True)
    print((r.stdout or "") + (("\n[stderr]\n" + r.stderr) if r.stderr else ""), flush=True)
    time.sleep(1.5)

    # Capture the Button page as a tall window so the vertically-stacked sample
    # cards (Basic / Accent / Subtle / Text-link) are all in frame without
    # scrolling — the accent "Confirm" button is the visual proof the style
    # applied (blue accent fill) vs failed (plain default button).
    r = ps("-File", str(CAP), "-TitleMatch", TITLE, "-Out", str(PW),
           "-W", "1040", "-H", "1560", "-X", "10", "-Y", "0")
    print("--- capture ---", flush=True)
    print((r.stdout or "") + (("\n[stderr]\n" + r.stderr) if r.stderr else ""), flush=True)

    try:
        subprocess.run(["taskkill", "/PID", str(proc.pid), "/T", "/F"], capture_output=True)
        proc.wait(timeout=10)
    except Exception:
        pass
    log.close()

    text = ""
    try:
        text = LOG.read_bytes().decode("utf-8", errors="replace")
    except Exception as e:
        print(f"log read failed: {e}", flush=True)

    print("--- run log tail ---", flush=True)
    print(text[-4000:], flush=True)

    # Diagnostic scan: any setProp failure, prop 112, or E_NOINTERFACE noise.
    print("--- error scan ---", flush=True)
    patterns = [r"setProp", r"\b112\b", r"E_NOINTERFACE", r"0x80004002",
                r"不支持此接口", r"failed"]
    hits = []
    for ln in text.splitlines():
        if any(re.search(p, ln) for p in patterns):
            hits.append(ln)
    if hits:
        for ln in hits:
            print("  HIT: " + ln, flush=True)
    else:
        print("  (no setProp/112/E_NOINTERFACE/failed lines found)", flush=True)

    style_112 = [ln for ln in hits if re.search(r"setProp", ln) and "112" in ln]
    print(f"BUTTON_STYLE_112_ERRORS={len(style_112)}", flush=True)
    print(f"PRINTWINDOW={PW} exists={PW.is_file()}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
