#!/usr/bin/env python3
"""External UI-thread responsiveness probe (zero app instrumentation).

Measures WM_NULL SendMessageTimeout round-trip latency to the gallery window
during (a) IDLE and (b) active mouse-WHEEL scrolling. WM_NULL is handled
trivially by the window proc, so the round-trip time is purely "how long until
the UI thread pumps a sent message" — i.e. UI-thread message-pump responsiveness.
If latency balloons during scroll, the UI pump is starved (would justify moving
the pump off the cjthread). If it stays low, the UI thread is responsive and the
jank lives in the WinUI ScrollPresenter/compositor layer (shared with windows-rs).
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
$IdleS = __IDLE__
$ScrollS = __SCROLL__
$src = @"
using System;
using System.Runtime.InteropServices;
public class Win {
  [DllImport("user32.dll", SetLastError=true)] public static extern IntPtr SendMessageTimeout(IntPtr h,uint m,IntPtr w,IntPtr l,uint f,uint t,out UIntPtr r);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f,uint dx,uint dy,uint d,UIntPtr e);
  public struct RECT { public int Left, Top, Right, Bottom; }
}
"@
Add-Type -TypeDefinition $src
Add-Type -AssemblyName UIAutomationClient
$WM_NULL=0; $SMTO_ABORTIFHUNG=0x2; $MOUSEEVENTF_WHEEL=0x0800

# Find the gallery window via UIA (its UIA Name matches even when the Win32
# caption does not), then take its NativeWindowHandle as the HWND.
$script:hwnd=[IntPtr]::Zero
$root=[System.Windows.Automation.AutomationElement]::RootElement
$wc=New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty,[System.Windows.Automation.ControlType]::Window)
foreach($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children,$wc)){
  if($w.Current.Name -like "*Reactor WinUI Gallery*"){ $script:hwnd=[IntPtr]$w.Current.NativeWindowHandle; break }
}
if($script:hwnd -eq [IntPtr]::Zero){ Write-Output "WINDOW_NOT_FOUND"; exit 1 }
$rect=New-Object Win+RECT; [void][Win]::GetWindowRect($script:hwnd,[ref]$rect)
$cx=[int]($rect.Left + ($rect.Right-$rect.Left)*0.62)   # content area (right of nav pane)
$cy=[int]($rect.Top  + ($rect.Bottom-$rect.Top)*0.5)
Write-Output ("TARGET hwnd=" + $script:hwnd + " rect=" + $rect.Left + "," + $rect.Top + "," + $rect.Right + "," + $rect.Bottom + " aim=" + $cx + "," + $cy)

function ProbeOnce {
  $r=[UIntPtr]::Zero
  $sw=[System.Diagnostics.Stopwatch]::StartNew()
  [void][Win]::SendMessageTimeout($script:hwnd,$WM_NULL,[IntPtr]::Zero,[IntPtr]::Zero,$SMTO_ABORTIFHUNG,2000,[ref]$r)
  $sw.Stop()
  return $sw.Elapsed.TotalMilliseconds
}

# IDLE phase
$idle=New-Object System.Collections.ArrayList
$deadline=(Get-Date).AddSeconds($IdleS)
while((Get-Date) -lt $deadline){ [void]$idle.Add((ProbeOnce)); Start-Sleep -Milliseconds 8 }

# SCROLL phase: drive real mouse wheel over the content while probing WM_NULL.
[void][Win]::SetForegroundWindow($script:hwnd)
Start-Sleep -Milliseconds 200
$scroll=New-Object System.Collections.ArrayList
$deadline=(Get-Date).AddSeconds($ScrollS)
$WHEEL_DOWN=[uint32]4294967176   # -120 as DWORD (toward user => scroll down)
$WHEEL_UP=[uint32]120
$down=$true
$i=0
while((Get-Date) -lt $deadline){
  [void][Win]::SetCursorPos($cx,$cy)
  $d = if($down){ $WHEEL_DOWN } else { $WHEEL_UP }
  [Win]::mouse_event($MOUSEEVENTF_WHEEL,0,0,$d,[UIntPtr]::Zero)
  [Win]::mouse_event($MOUSEEVENTF_WHEEL,0,0,$d,[UIntPtr]::Zero)
  [void]$scroll.Add((ProbeOnce))
  $i++; if(($i % 25) -eq 0){ $down = -not $down }   # reverse direction periodically
  Start-Sleep -Milliseconds 8
}

function Stats($a,$name){
  $s=@($a | Sort-Object)
  $n=$s.Count
  if($n -eq 0){ Write-Output "$name n=0"; return }
  $avg=($s | Measure-Object -Average).Average
  $p50=$s[[int]($n*0.5)]; $p95=$s[[int]([Math]::Min($n-1,$n*0.95))]; $max=$s[$n-1]
  $over16=@($s | Where-Object { $_ -gt 16 }).Count
  $over50=@($s | Where-Object { $_ -gt 50 }).Count
  Write-Output ("{0} n={1} avg={2:N1}ms p50={3:N1}ms p95={4:N1}ms max={5:N1}ms  >16ms={6} >50ms={7}" -f $name,$n,$avg,$p50,$p95,$max,$over16,$over50)
}
Stats $idle   "IDLE  "
Stats $scroll "SCROLL"
"""


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--boot-s", type=float, default=15.0)
    ap.add_argument("--idle-s", type=int, default=5)
    ap.add_argument("--scroll-s", type=int, default=10)
    ap.add_argument("--page", default="")
    args = ap.parse_args()

    exe = find_exe(); exe_dir = exe.parent
    stage(exe_dir)
    env = dict(os.environ); env["cjStackSize"] = "32mb"
    proc = subprocess.Popen(["cjv", "exec", str(exe)], cwd=str(exe_dir),
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=env)
    print(f"launched pid={proc.pid}; booting {args.boot_s}s", flush=True)
    try:
        time.sleep(args.boot_s)
        if args.page:
            subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(ROOT / "nav_select.ps1"),
                            "-Items", args.page, "-PauseMs", "1200"], capture_output=True, timeout=60)
            time.sleep(1.5)
        script = PROBE.replace("__IDLE__", str(args.idle_s)).replace("__SCROLL__", str(args.scroll_s))
        r = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", script],
                           capture_output=True, encoding="utf-8", errors="replace", timeout=args.idle_s + args.scroll_s + 60)
        print(r.stdout.strip(), flush=True)
        if r.stderr and r.stderr.strip():
            print("[stderr] " + r.stderr.strip()[:500], flush=True)
    finally:
        try:
            subprocess.run(["taskkill", "/IM", "main.exe", "/F"], capture_output=True)
            subprocess.run(["taskkill", "/IM", "cjv.exe", "/F"], capture_output=True)
        except Exception:
            pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
