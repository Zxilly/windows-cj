#!/usr/bin/env python3
"""Reliable per-process GPU engine utilization during scroll (cj vs rs).

The earlier probe sampled '\\GPU Engine(*)\\Utilization Percentage' which
enumerates *every* engine instance on the machine per sample -> one slow sample
in a multi-second window (n=1, useless). This version pre-resolves ONLY the
target process's GPU-engine instances via the .NET PerformanceCounterCategory
(fast), then samples just those explicit counter paths repeatedly while an
active wheel-scroll runs. It breaks the result down by engine type (3D / Copy /
VideoDecode / ...), so we can tell:

  * GPU ~0% during scroll  => composition is pure software (CPU rasterizer).
  * GPU  >0% on 3D engine  => GPU is used; the high dwmcorei CPU is CPU-side
                              surface (re)building / resampling, not a software
                              device fallback.
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

$hwnd=[IntPtr]::Zero
$root=[System.Windows.Automation.AutomationElement]::RootElement
$wc=New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty,[System.Windows.Automation.ControlType]::Window)
foreach($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children,$wc)){
  if($w.Current.Name -like "*Reactor WinUI Gallery*"){ $hwnd=[IntPtr]$w.Current.NativeWindowHandle; break }
}
if($hwnd -eq [IntPtr]::Zero){ Write-Output "WINDOW_NOT_FOUND"; exit 1 }
$pid_ui=0; [void][Win]::GetWindowThreadProcessId($hwnd,[ref]$pid_ui)
$rect=New-Object Win+RECT; [void][Win]::GetWindowRect($hwnd,[ref]$rect)
$cx=[int]($rect.Left + ($rect.Right-$rect.Left)*0.62)
$cy=[int]($rect.Top  + ($rect.Bottom-$rect.Top)*0.5)
Write-Output ("TARGET ui_pid=$pid_ui aim=$cx,$cy")

# Pre-resolve ONLY this process's GPU Engine instances (fast, no global enum per sample).
$cat = New-Object System.Diagnostics.PerformanceCounterCategory('GPU Engine')
$inst = $cat.GetInstanceNames() | Where-Object { $_ -like "pid_${pid_ui}_*" }
if(-not $inst){ Write-Output "NO_GPU_INSTANCES_FOR_PID (process did not register any GPU engine context)" }
$paths = $inst | ForEach-Object { "\GPU Engine($_)\Utilization Percentage" }
Write-Output ("GPU_ENGINE_INSTANCES n=" + (@($inst).Count))

# Start a realistic wheel-scroll in the background for the whole sampling window.
[void][Win]::SetForegroundWindow($hwnd); Start-Sleep -Milliseconds 200
$job = Start-Job -ScriptBlock {
  param($srcCode,$cx,$cy,$secs)
  Add-Type -TypeDefinition $srcCode
  $WD=[uint32]4294967176; $WU=[uint32]120; $MW=0x0800
  $deadline=(Get-Date).AddSeconds($secs); $down=$true; $i=0
  while((Get-Date) -lt $deadline){
    [void][Win]::SetCursorPos($cx,$cy)
    $d = if($down){$WD}else{$WU}
    [Win]::mouse_event($MW,0,0,$d,[UIntPtr]::Zero)
    $i++; if(($i % 14) -eq 0){ $down = -not $down }
    Start-Sleep -Milliseconds 60
  }
} -ArgumentList $src,$cx,$cy,$ScrollS

# Sample the per-PID engine counters repeatedly during the scroll.
$byType = @{}     # engtype -> list of per-sample summed utilization
$totals = New-Object System.Collections.ArrayList
if($paths){
  $res = Get-Counter -Counter $paths -SampleInterval 1 -MaxSamples $ScrollS -ErrorAction SilentlyContinue
  foreach($s in $res){
    $sampTotal = 0.0
    $sampByType = @{}
    foreach($cs in $s.CounterSamples){
      $v = [double]$cs.CookedValue
      $sampTotal += $v
      $et = '?'
      if($cs.Path -match 'engtype_([A-Za-z0-9]+)'){ $et = $matches[1] }
      if(-not $sampByType.ContainsKey($et)){ $sampByType[$et]=0.0 }
      $sampByType[$et] += $v
    }
    [void]$totals.Add($sampTotal)
    foreach($k in $sampByType.Keys){
      if(-not $byType.ContainsKey($k)){ $byType[$k]=New-Object System.Collections.ArrayList }
      [void]$byType[$k].Add($sampByType[$k])
    }
  }
}
Wait-Job $job | Out-Null; Remove-Job $job

if($totals.Count -gt 0){
  $avg=[math]::Round((($totals|Measure-Object -Average).Average),1)
  $max=[math]::Round((($totals|Measure-Object -Maximum).Maximum),1)
  Write-Output ("GPU_TOTAL during scroll: avg=$avg%  max=$max%  (n=$($totals.Count) samples)")
  foreach($k in ($byType.Keys | Sort-Object)){
    $a=[math]::Round((($byType[$k]|Measure-Object -Average).Average),1)
    $m=[math]::Round((($byType[$k]|Measure-Object -Maximum).Maximum),1)
    Write-Output ("   engtype=$k  avg=$a%  max=$m%")
  }
} else {
  Write-Output "GPU_TOTAL: no samples captured"
}
"""


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--boot-s", type=float, default=15.0)
    ap.add_argument("--scroll-s", type=int, default=8)
    ap.add_argument("--page", default="")
    ap.add_argument("--exe", default="", help="run a prebuilt exe directly (e.g. windows-rs gallery.exe)")
    ap.add_argument("--cjexe", default="", help="run a specific cj exe via 'cjv exec' WITHOUT staging (e.g. a framework-dependent test bin)")
    args = ap.parse_args()

    env = dict(os.environ)
    if args.cjexe:
        exe = Path(args.cjexe); exe_dir = exe.parent
        env["cjStackSize"] = "32mb"
        proc = subprocess.Popen(["cjv", "exec", str(exe)], cwd=str(exe_dir),
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=env)
    elif args.exe:
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
        if args.page:
            subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(ROOT / "nav_select.ps1"),
                            "-Items", args.page, "-PauseMs", "1200"], capture_output=True, timeout=60)
            time.sleep(1.5)
        script = PROBE.replace("__SCROLL__", str(args.scroll_s))
        r = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", script],
                           capture_output=True, encoding="utf-8", errors="replace",
                           timeout=args.scroll_s + 120)
        print(r.stdout.strip(), flush=True)
        if r.stderr and r.stderr.strip():
            print("[stderr] " + r.stderr.strip()[:1200], flush=True)
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
