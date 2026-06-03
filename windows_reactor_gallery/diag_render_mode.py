#!/usr/bin/env python3
"""Definitive software-vs-hardware render probe for the gallery (zero app instrumentation).

Confirms or refutes H1 (WinUI fell back to WARP software rendering) using three
independent external signals:

  1. Loaded modules of the gallery process: presence of the WARP software
     rasterizer (d3d10warp.dll) vs a GPU vendor user-mode driver
     (nv*um*.dll / igd*.dll|igc*.dll / amd*64.dll). Hardware accel => vendor UMD
     is resident; pure WARP => only d3d10warp.dll.
  2. Per-THREAD CPU during an active wheel-scroll window: identifies whether the
     ~16% CPU burned during scroll lands on a non-UI render/raster thread (the
     WARP signature) rather than the UI/message-pump thread.
  3. Best-effort per-PID GPU Engine utilization during scroll (hardware accel
     => non-zero 3D/compute engine use; WARP => ~0).
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
$IdleS = __IDLE__
$WheelSleepMs = __WHEELSLEEP__
$TicksPer = __TICKSPER__
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
$pid_ui=0; $uiThreadId=[Win]::GetWindowThreadProcessId($hwnd,[ref]$pid_ui)
$rect=New-Object Win+RECT; [void][Win]::GetWindowRect($hwnd,[ref]$rect)
$cx=[int]($rect.Left + ($rect.Right-$rect.Left)*0.62)
$cy=[int]($rect.Top  + ($rect.Bottom-$rect.Top)*0.5)
Write-Output ("TARGET ui_pid=$pid_ui ui_tid=$uiThreadId aim=$cx,$cy")

# ---- Signal 1: loaded graphics modules ----
$proc = Get-Process -Id $pid_ui
$mods = $proc.Modules | ForEach-Object { $_.ModuleName.ToLower() }
$warp = @($mods | Where-Object { $_ -eq 'd3d10warp.dll' }).Count -gt 0
$vendor = @($mods | Where-Object {
  $_ -like 'nv*um*.dll' -or $_ -like 'igd*um*.dll' -or $_ -like 'igc*.dll' -or
  $_ -like 'amdxc*.dll' -or $_ -like 'amdihk*.dll' -or $_ -like 'aticfx*.dll' -or
  $_ -like 'igd10*.dll' -or $_ -like 'ig*icd*.dll'
})
$d3d = @($mods | Where-Object { $_ -like 'd3d11*.dll' -or $_ -eq 'dxgi.dll' -or $_ -like 'd3d12*.dll' -or $_ -like 'dcomp*.dll' })
Write-Output ("MODULES warp_loaded=$warp  vendor_umd=[" + ($vendor -join ',') + "]  d3d=[" + ($d3d -join ',') + "]")

# ---- Signal 2: per-thread CPU, IDLE baseline vs realistic SCROLL ----
function ThreadSnap($p){
  $h=@{}
  (Get-Process -Id $p).Threads | ForEach-Object {
    try { $h[$_.Id] = $_.TotalProcessorTime } catch {}
  }
  return $h
}
function ThreadDiff($s0,$s1,$ms){
  $rows = New-Object System.Collections.ArrayList
  foreach($tid in $s1.Keys){
    if($s0.ContainsKey($tid)){
      $dms = ($s1[$tid] - $s0[$tid]).TotalMilliseconds
      $pct = [math]::Round(100.0*$dms/$ms,1)
      [void]$rows.Add([pscustomobject]@{ tid=$tid; pct=$pct })
    }
  }
  return $rows
}

# IDLE baseline (no input) — same duration, no wheel.
$snapI0 = ThreadSnap $pid_ui; $wI0 = Get-Date
Start-Sleep -Seconds $IdleS
$idleMs = ((Get-Date)-$wI0).TotalMilliseconds
$idleRows = ThreadDiff $snapI0 (ThreadSnap $pid_ui) $idleMs
$idleMap = @{}; $idleRows | ForEach-Object { $idleMap[$_.tid] = $_.pct }
$idleTot = [math]::Round((($idleRows | Measure-Object -Property pct -Sum).Sum),1)

# SCROLL at a realistic cadence (configurable): TicksPer wheel notches every
# WheelSleepMs. e.g. 1 tick / 60ms ~= 17 notches/sec (a brisk real scroll).
[void][Win]::SetForegroundWindow($hwnd); Start-Sleep -Milliseconds 200
$job = Start-Job -ScriptBlock {
  param($srcCode,$cx,$cy,$secs,$sleepMs,$ticksPer)
  Add-Type -TypeDefinition $srcCode
  $WD=[uint32]4294967176; $WU=[uint32]120; $MW=0x0800
  $deadline=(Get-Date).AddSeconds($secs); $down=$true; $i=0
  while((Get-Date) -lt $deadline){
    [void][Win]::SetCursorPos($cx,$cy)
    $d = if($down){$WD}else{$WU}
    for($t=0;$t -lt $ticksPer;$t++){ [Win]::mouse_event($MW,0,0,$d,[UIntPtr]::Zero) }
    $i++; if(($i % 14) -eq 0){ $down = -not $down }
    Start-Sleep -Milliseconds $sleepMs
  }
} -ArgumentList $src,$cx,$cy,$ScrollS,$WheelSleepMs,$TicksPer

$snap0 = ThreadSnap $pid_ui; $w0 = Get-Date
$gpu = New-Object System.Collections.ArrayList
$deadline=(Get-Date).AddSeconds($ScrollS)
while((Get-Date) -lt $deadline){
  try {
    $s=(Get-Counter -Counter '\GPU Engine(*)\Utilization Percentage' -ErrorAction Stop).CounterSamples |
       Where-Object { $_.Path -like "*pid_${pid_ui}_*" }
    if($s){ [void]$gpu.Add([double]($s | Measure-Object -Property CookedValue -Sum).Sum) } else { [void]$gpu.Add(0.0) }
  } catch { [void]$gpu.Add(-1.0) }
}
$elapsedMs = ((Get-Date)-$w0).TotalMilliseconds
$scrollRows = ThreadDiff $snap0 (ThreadSnap $pid_ui) $elapsedMs
Wait-Job $job | Out-Null; Remove-Job $job

Write-Output ("CADENCE ticks_per=$TicksPer every ${WheelSleepMs}ms  (~" + [math]::Round(1000.0*$TicksPer/$WheelSleepMs,0) + " notches/sec)")
Write-Output ("IDLE   total app cpu = $idleTot% of 1 core (window ${idleMs}ms)")
Write-Output ("SCROLL per-thread (idle->scroll delta), window ${elapsedMs}ms:")
$scrollRows | Sort-Object pct -Descending | Select-Object -First 8 | ForEach-Object {
  $idlePct = if($idleMap.ContainsKey($_.tid)){ $idleMap[$_.tid] } else { 0.0 }
  $delta = [math]::Round($_.pct - $idlePct,1)
  $isUi = if($_.tid -eq $uiThreadId){'<-UI/PUMP'}else{''}
  if($_.pct -gt 0.4){
    Write-Output ("   tid={0,-7} scroll={1,5}%  idle={2,5}%  delta={3,5}%  {4}" -f $_.tid,$_.pct,$idlePct,$delta,$isUi)
  }
}
$scrTot=[math]::Round((($scrollRows | Measure-Object -Property pct -Sum).Sum),1)
Write-Output ("   TOTAL app cpu during scroll = $scrTot% of 1 core  (scroll-induced = " + [math]::Round($scrTot-$idleTot,1) + "%)")
if($gpu.Count -gt 0){
  $ga=[math]::Round((($gpu|Measure-Object -Average).Average),2)
  $gm=[math]::Round((($gpu|Measure-Object -Maximum).Maximum),2)
  Write-Output ("   GPU_app during scroll: avg=$ga% max=$gm% (n=$($gpu.Count))")
}
"""


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--boot-s", type=float, default=15.0)
    ap.add_argument("--scroll-s", type=int, default=8)
    ap.add_argument("--idle-s", type=int, default=4)
    ap.add_argument("--wheel-sleep-ms", type=int, default=60, help="ms between wheel bursts")
    ap.add_argument("--ticks-per", type=int, default=1, help="wheel notches per burst")
    ap.add_argument("--page", default="")
    ap.add_argument("--exe", default="", help="run a prebuilt exe directly (e.g. windows-rs gallery.exe)")
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
        if args.page:
            subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(ROOT / "nav_select.ps1"),
                            "-Items", args.page, "-PauseMs", "1200"], capture_output=True, timeout=60)
            time.sleep(1.5)
        script = (PROBE.replace("__SCROLL__", str(args.scroll_s))
                       .replace("__IDLE__", str(args.idle_s))
                       .replace("__WHEELSLEEP__", str(args.wheel_sleep_ms))
                       .replace("__TICKSPER__", str(args.ticks_per)))
        r = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", script],
                           capture_output=True, encoding="utf-8", errors="replace",
                           timeout=args.scroll_s + args.idle_s + 120)
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
