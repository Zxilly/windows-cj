#!/usr/bin/env python3
"""Compare per-process DPI awareness + physical window size for cj vs rs gallery.

Hypothesis: cj composites the tall content at a higher rasterization scale (more
pixels) than rs, making its software composition ~4x costlier. If cj's window is
DPI-aware (renders at native physical pixels) while rs is unaware (DWM bitmap-
stretches a 96-DPI surface), cj rasterizes ~scale^2 more pixels per frame.

Reports, for the launched gallery: process DPI-awareness context, GetDpiForWindow,
and the physical GetWindowRect size.
"""
from __future__ import annotations
import argparse, os, shutil, subprocess, sys, time
from pathlib import Path

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

ROOT = Path(__file__).resolve().parent
STAGE = ROOT.parent / ".generated" / "windows-app-sdk"


def find_exe() -> Path:
    c = ROOT / "target" / "release" / "bin" / "main.exe"
    if c.is_file():
        return c
    for h in (ROOT / "target").glob("**/main.exe"):
        return h
    raise SystemExit("exe not found")


def stage(exe_dir: Path) -> None:
    shutil.copy2(STAGE / "Microsoft.WindowsAppRuntime.Bootstrap.dll", exe_dir / "Microsoft.WindowsAppRuntime.Bootstrap.dll")
    if (STAGE / "resources.pri").is_file():
        shutil.copy2(STAGE / "resources.pri", exe_dir / "resources.pri")
    if (ROOT / "assets").is_dir():
        shutil.copytree(ROOT / "assets", exe_dir / "assets", dirs_exist_ok=True)


PROBE = r"""
$ErrorActionPreference='Stop'
$src = @"
using System;
using System.Runtime.InteropServices;
public class Dpi {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetWindowThreadProcessId(IntPtr h, out int pid);
  [DllImport("user32.dll")] public static extern IntPtr GetDpiAwarenessContextForProcess(IntPtr hProcess);
  [DllImport("user32.dll")] public static extern int GetAwarenessFromDpiAwarenessContext(IntPtr ctx);
  [DllImport("user32.dll")] public static extern IntPtr GetWindowDpiAwarenessContext(IntPtr hwnd);
  [DllImport("user32.dll")] public static extern bool AreDpiAwarenessContextsEqual(IntPtr a, IntPtr b);
  [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(uint a, bool inh, int pid);
  public struct RECT { public int Left, Top, Right, Bottom; }
}
"@
Add-Type -TypeDefinition $src
Add-Type -AssemblyName UIAutomationClient
$hwnd=[IntPtr]::Zero
$root=[System.Windows.Automation.AutomationElement]::RootElement
$wc=New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty,[System.Windows.Automation.ControlType]::Window)
foreach($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children,$wc)){
  if($w.Current.Name -like "*Reactor WinUI Gallery*"){ $hwnd=[IntPtr]$w.Current.NativeWindowHandle; break }
}
if($hwnd -eq [IntPtr]::Zero){ Write-Output "WINDOW_NOT_FOUND"; exit 1 }
$pid_ui=0; [void][Dpi]::GetWindowThreadProcessId($hwnd,[ref]$pid_ui)
$dpi=[Dpi]::GetDpiForWindow($hwnd)
$r=New-Object Dpi+RECT; [void][Dpi]::GetWindowRect($hwnd,[ref]$r)
$awareName="?"
try {
  $h=[Dpi]::OpenProcess(0x1000,$false,$pid_ui)   # PROCESS_QUERY_LIMITED_INFORMATION
  $ctx=[Dpi]::GetDpiAwarenessContextForProcess($h)
  $a=[Dpi]::GetAwarenessFromDpiAwarenessContext($ctx)
  $awareName = switch($a){ 0{"UNAWARE (96, DWM-stretched)"} 1{"SYSTEM-aware"} 2{"PER-MONITOR-aware (native px)"} default{"val=$a"} }
} catch { $awareName = "query-failed: $_" }
$scale = [math]::Round($dpi/96.0,3)
# Distinguish PerMonitor v1 vs v2 (GetAwarenessFromDpiAwarenessContext returns the
# same value 2 for both). Predefined DPI_AWARENESS_CONTEXT pseudo-handles:
$wctx=[Dpi]::GetWindowDpiAwarenessContext($hwnd)
$ctxName="?"
foreach($pair in @(@(-4,"PER_MONITOR_AWARE_V2"),@(-3,"PER_MONITOR_AWARE_V1"),@(-2,"SYSTEM_AWARE"),@(-1,"UNAWARE"),@(-5,"UNAWARE_GDISCALED"))){
  if([Dpi]::AreDpiAwarenessContextsEqual($wctx,[IntPtr]$pair[0])){ $ctxName=$pair[1]; break }
}
Write-Output ("DPI pid=$pid_ui  GetDpiForWindow=$dpi (scale=${scale}x)  awareness=$awareName")
Write-Output ("WINDOW_DPI_CONTEXT = $ctxName   (v1 vs v2 matters for fractional-scale composition)")
Write-Output ("PHYS_WINDOW = " + ($r.Right-$r.Left) + " x " + ($r.Bottom-$r.Top) + " px   (logical inner ~1400x900)")
"""


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--boot-s", type=float, default=15.0)
    ap.add_argument("--exe", default="")
    args = ap.parse_args()
    env = dict(os.environ)
    if args.exe:
        exe = Path(args.exe); exe_dir = exe.parent
        proc = subprocess.Popen([str(exe)], cwd=str(exe_dir),
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=env)
    else:
        exe = find_exe(); exe_dir = exe.parent
        stage(exe_dir)
        env["cjStackSize"] = "32mb"
        proc = subprocess.Popen(["cjv", "exec", str(exe)], cwd=str(exe_dir),
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=env)
    print(f"launched pid={proc.pid}; booting {args.boot_s}s", flush=True)
    try:
        time.sleep(args.boot_s)
        r = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", PROBE],
                           capture_output=True, encoding="utf-8", errors="replace", timeout=60)
        print(r.stdout.strip(), flush=True)
        if r.stderr and r.stderr.strip():
            print("[stderr] " + r.stderr.strip()[:600], flush=True)
    finally:
        try:
            subprocess.run(["taskkill", "/PID", str(proc.pid), "/T", "/F"], capture_output=True)
            subprocess.run(["taskkill", "/IM", "main.exe", "/F"], capture_output=True)
            subprocess.run(["taskkill", "/IM", "cjv.exe", "/F"], capture_output=True)
            subprocess.run(["taskkill", "/IM", "gallery.exe", "/F"], capture_output=True)
        except Exception:
            pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
