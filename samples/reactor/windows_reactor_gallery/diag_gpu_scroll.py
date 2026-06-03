#!/usr/bin/env python3
"""External GPU-vs-CPU scroll probe (zero app instrumentation).

Distinguishes the two remaining scroll-jank hypotheses without touching the app:

  H1  WinUI fell back to WARP software rendering
      => during scroll the gallery process uses ~0% GPU and high CPU
         (rendering happens on a CPU render thread, not the GPU).
  H2  Hardware-accelerated but GPU-bound (heavy visual tree / backdrop)
      => during scroll the gallery process + dwm.exe use significant GPU.

It samples per-PID GPU Engine utilization and per-PID CPU% during an IDLE
window and during an active mouse-WHEEL scroll window, then reports the deltas.
The wheel is driven from a background PowerShell job so counter sampling on the
main thread stays correlated with real scrolling.
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
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f,uint dx,uint dy,uint d,UIntPtr e);
  [DllImport("user32.dll")] public static extern int GetWindowThreadProcessId(IntPtr h, out int pid);
  public struct RECT { public int Left, Top, Right, Bottom; }
}
"@
Add-Type -TypeDefinition $src
Add-Type -AssemblyName UIAutomationClient

# Locate the gallery window via UIA, derive its real UI process id + content aim point.
$hwnd=[IntPtr]::Zero
$root=[System.Windows.Automation.AutomationElement]::RootElement
$wc=New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty,[System.Windows.Automation.ControlType]::Window)
foreach($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children,$wc)){
  if($w.Current.Name -like "*Reactor WinUI Gallery*"){ $hwnd=[IntPtr]$w.Current.NativeWindowHandle; break }
}
if($hwnd -eq [IntPtr]::Zero){ Write-Output "WINDOW_NOT_FOUND"; exit 1 }
$pid_ui=0; [void][Win]::GetWindowThreadProcessId($hwnd,[ref]$pid_ui)
$dwm = Get-Process -Name dwm -ErrorAction SilentlyContinue | Select-Object -First 1
$pid_dwm = if($dwm){ $dwm.Id } else { -1 }
$rect=New-Object Win+RECT; [void][Win]::GetWindowRect($hwnd,[ref]$rect)
$cx=[int]($rect.Left + ($rect.Right-$rect.Left)*0.62)
$cy=[int]($rect.Top  + ($rect.Bottom-$rect.Top)*0.5)
$ncpu=[Environment]::ProcessorCount
Write-Output ("TARGET ui_pid=$pid_ui dwm_pid=$pid_dwm ncpu=$ncpu aim=$cx,$cy rect=" + $rect.Left + "," + $rect.Top + "," + $rect.Right + "," + $rect.Bottom)

# Sum per-PID GPU Engine utilization (across all engines for that pid).
function GpuPct([int]$p){
  try {
    $s = Get-Counter -Counter '\GPU Engine(*)\Utilization Percentage' -ErrorAction Stop
    $sel = $s.CounterSamples | Where-Object { $_.Path -like "*pid_${p}_*" }
    if(-not $sel){ return 0.0 }
    return [double]($sel | Measure-Object -Property CookedValue -Sum).Sum
  } catch { return -1.0 }
}

# CPU% for a pid over an interval, normalized to a single core (so >100% means
# more than one core busy). Uses TotalProcessorTime deltas.
function CpuSampler([int]$p){
  $proc = Get-Process -Id $p -ErrorAction SilentlyContinue
  if(-not $proc){ return $null }
  return @{ proc=$proc; t0=$proc.TotalProcessorTime; w0=(Get-Date) }
}
function CpuPct($ctx){
  if(-not $ctx){ return -1.0 }
  $ctx.proc.Refresh()
  $dt = ($ctx.proc.TotalProcessorTime - $ctx.t0).TotalMilliseconds
  $dw = ((Get-Date) - $ctx.w0).TotalMilliseconds
  if($dw -le 0){ return 0.0 }
  return [math]::Round(100.0*$dt/$dw,1)
}

function Phase($label,$secs,$drive){
  $gpuUi=New-Object System.Collections.ArrayList
  $gpuDwm=New-Object System.Collections.ArrayList
  $job=$null
  if($drive){
    [void][Win]::SetForegroundWindow($hwnd); Start-Sleep -Milliseconds 200
    $job = Start-Job -ScriptBlock {
      param($srcCode,$cx,$cy,$secs)
      Add-Type -TypeDefinition $srcCode
      $WHEEL_DOWN=[uint32]4294967176; $WHEEL_UP=[uint32]120; $MOUSEEVENTF_WHEEL=0x0800
      $deadline=(Get-Date).AddSeconds($secs); $down=$true; $i=0
      while((Get-Date) -lt $deadline){
        [void][Win]::SetCursorPos($cx,$cy)
        $d = if($down){$WHEEL_DOWN}else{$WHEEL_UP}
        [Win]::mouse_event($MOUSEEVENTF_WHEEL,0,0,$d,[UIntPtr]::Zero)
        [Win]::mouse_event($MOUSEEVENTF_WHEEL,0,0,$d,[UIntPtr]::Zero)
        $i++; if(($i % 22) -eq 0){ $down = -not $down }
        Start-Sleep -Milliseconds 10
      }
    } -ArgumentList $src,$cx,$cy,$secs
  }
  $cpuUiCtx = CpuSampler $pid_ui
  $cpuDwmCtx = if($pid_dwm -ge 0){ CpuSampler $pid_dwm } else { $null }
  $deadline=(Get-Date).AddSeconds($secs)
  while((Get-Date) -lt $deadline){
    [void]$gpuUi.Add((GpuPct $pid_ui))
    if($pid_dwm -ge 0){ [void]$gpuDwm.Add((GpuPct $pid_dwm)) }
  }
  $cpuUi = CpuPct $cpuUiCtx
  $cpuDwm = CpuPct $cpuDwmCtx
  if($job){ Wait-Job $job | Out-Null; Remove-Job $job }
  function Avg($a){ if($a.Count -eq 0){return 0}; return [math]::Round((($a|Measure-Object -Average).Average),1) }
  function Mx($a){ if($a.Count -eq 0){return 0}; return [math]::Round((($a|Measure-Object -Maximum).Maximum),1) }
  Write-Output ("{0} samples={1}  GPU_app avg={2}% max={3}%  GPU_dwm avg={4}% max={5}%  CPU_app={6}%(of 1core)  CPU_dwm={7}%" -f `
    $label,$gpuUi.Count,(Avg $gpuUi),(Mx $gpuUi),(Avg $gpuDwm),(Mx $gpuDwm),$cpuUi,$cpuDwm)
}

Phase "IDLE  " $IdleS $false
Phase "SCROLL" $ScrollS $true
"""


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--boot-s", type=float, default=15.0)
    ap.add_argument("--idle-s", type=int, default=4)
    ap.add_argument("--scroll-s", type=int, default=8)
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
                           capture_output=True, encoding="utf-8", errors="replace",
                           timeout=args.idle_s + args.scroll_s + 90)
        print(r.stdout.strip(), flush=True)
        if r.stderr and r.stderr.strip():
            print("[stderr] " + r.stderr.strip()[:800], flush=True)
    finally:
        try:
            subprocess.run(["taskkill", "/IM", "main.exe", "/F"], capture_output=True)
            subprocess.run(["taskkill", "/IM", "cjv.exe", "/F"], capture_output=True)
        except Exception:
            pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
