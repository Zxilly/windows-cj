#!/usr/bin/env python3
"""Launch the reactor gallery via `cjv exec`, screenshot the shell, then stop it."""
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
LOG = ROOT / "target" / "gallery_run.log"
FULL = ROOT / "target" / "gallery_full.png"
FG = ROOT / "target" / "gallery_window.png"
TITLE = "Reactor WinUI Gallery"


def find_exe() -> Path:
    for c in [ROOT / "target" / "release" / "bin" / "main.exe"]:
        if c.is_file():
            return c
    for hit in (ROOT / "target").glob("**/main.exe"):
        return hit
    raise SystemExit("gallery exe not found; build first")


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
    # Stage gallery PNG assets next to the exe so card icons resolve (assetUri
    # anchors to <exeDir>/assets; the raw target/release/bin output lacks it).
    assets_src = ROOT / "assets"
    if assets_src.is_dir():
        shutil.copytree(assets_src, exe_dir / "assets", dirs_exist_ok=True)
    LOG.parent.mkdir(parents=True, exist_ok=True)
    # Give the UI cjthread a generous stack: the render loop runs with WinUI's deep
    # native layout/message-pump frames beneath it, and the default cjthread stack
    # is too small (StackOverflowError under deep navigation). See verify script.
    os.environ.setdefault("cjStackSize", "32mb")
    log = open(LOG, "wb")
    proc = subprocess.Popen(["cjv", "exec", str(exe)], cwd=str(exe_dir), stdout=log, stderr=subprocess.STDOUT)
    print(f"launched pid={proc.pid}", flush=True)
    time.sleep(13)
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
        print(LOG.read_bytes().decode("utf-8", errors="replace")[-3000:], flush=True)
    except Exception as e:
        print(f"log read failed: {e}", flush=True)
    print(f"FG={FG} exists={FG.is_file()}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
