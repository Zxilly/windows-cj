#!/usr/bin/env python3
"""Run the reactor_p3_smoke WinUI binary via `cjv exec`, screenshot it, then stop it.

Stages the Windows App SDK bootstrap DLL + resources.pri next to the executable
(App.run sets cwd to the exe directory and bootstraps the default DLL name), then
launches the binary, waits for the window, captures a PNG of the full virtual
screen plus the app window, then terminates the process tree.
"""

from __future__ import annotations

import shutil
import subprocess
import sys
import time
from pathlib import Path

# Force UTF-8 stdout so window titles containing zero-width / non-GBK chars do
# not crash printing on a GBK console.
try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

ROOT = Path(__file__).resolve().parent
WORKSPACE = ROOT.parent
STAGE = WORKSPACE / ".generated" / "windows-app-sdk"
PS1 = ROOT / "screenshot.ps1"
LOG = ROOT / "target" / "p3_smoke_run.log"
FULL_PNG = ROOT / "target" / "p3_smoke.png"
FG_PNG = ROOT / "target" / "p3_smoke_window.png"
FG_PNG2 = ROOT / "target" / "p3_smoke_window_after.png"


def find_exe() -> Path:
    candidates = [
        ROOT / "target" / "release" / "bin" / "main.exe",
        ROOT / "target" / "release" / "bin" / "reactor_p3_smoke.exe",
        WORKSPACE / "target" / "release" / "bin" / "main.exe",
    ]
    for c in candidates:
        if c.is_file():
            return c
    for hit in (ROOT / "target").glob("**/main.exe"):
        return hit
    raise SystemExit("reactor_p3_smoke executable not found; build first")


def stage_runtime(exe_dir: Path) -> None:
    boot = STAGE / "Microsoft.WindowsAppRuntime.Bootstrap.dll"
    pri = STAGE / "resources.pri"
    if not boot.is_file():
        raise SystemExit(f"missing staged bootstrap dll: {boot}")
    shutil.copy2(boot, exe_dir / boot.name)
    if pri.is_file():
        shutil.copy2(pri, exe_dir / "resources.pri")
    print(f"staged App SDK runtime into {exe_dir}", flush=True)


def screenshot(out_full: Path, out_fg: Path) -> str:
    ps = subprocess.run(
        ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass",
         "-File", str(PS1),
         "-OutFull", str(out_full), "-OutFg", str(out_fg)],
        capture_output=True, encoding="utf-8", errors="replace",
    )
    return (ps.stdout or "") + ("\n[stderr]\n" + ps.stderr if ps.stderr else "")


def main() -> int:
    exe = find_exe()
    exe_dir = exe.parent
    print(f"exe: {exe}", flush=True)
    stage_runtime(exe_dir)

    LOG.parent.mkdir(parents=True, exist_ok=True)
    log_handle = open(LOG, "wb")  # binary: cjv/runtime may emit non-UTF8 bytes

    proc = subprocess.Popen(
        ["cjv", "exec", str(exe)],
        cwd=str(exe_dir),
        stdout=log_handle,
        stderr=subprocess.STDOUT,
    )
    print(f"launched pid={proc.pid} via cjv exec", flush=True)

    # Wait for the window to appear and XAML to lay out.
    time.sleep(10)

    early = proc.poll()
    if early is not None:
        print(f"PROCESS_EXITED_EARLY code={early}", flush=True)

    out1 = screenshot(FULL_PNG, FG_PNG)
    print("---first screenshot---", flush=True)
    print(out1, flush=True)

    # Second observation after the window has settled.
    time.sleep(2)
    out2 = screenshot(FULL_PNG, FG_PNG2)
    print("---second screenshot---", flush=True)
    print(out2, flush=True)

    # Terminate the process tree.
    try:
        subprocess.run(["taskkill", "/PID", str(proc.pid), "/T", "/F"],
                       capture_output=True)
    except Exception as exc:  # noqa: BLE001
        print(f"taskkill failed: {exc}", flush=True)
    try:
        proc.wait(timeout=10)
    except Exception:
        pass
    log_handle.close()

    print("---run log tail---", flush=True)
    try:
        text = LOG.read_bytes().decode("utf-8", errors="replace")
        print(text[-4000:] if text else "<empty log>", flush=True)
    except Exception as exc:  # noqa: BLE001
        print(f"could not read log: {exc}", flush=True)

    print(f"FULL_PNG={FULL_PNG} exists={FULL_PNG.is_file()}", flush=True)
    print(f"FG_PNG={FG_PNG} exists={FG_PNG.is_file()}", flush=True)
    print(f"FG_PNG2={FG_PNG2} exists={FG_PNG2.is_file()}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
