#!/usr/bin/env python3
"""Identify the hot thread during the janky page_content scroll (zero app instrumentation).

The Button control page drops to ~25fps and one NON-UI thread burns ~72% of a
core with GPU~0 (CPU-side rasterization signature). This probe drives a
continuous scroll, finds the hottest thread, reads its Win32 start address via
NtQueryInformationThread(ThreadQuerySetWin32StartAddress), and maps that address
to the owning module. The owning DLL tells us whether the bottleneck is a native
WinUI render thread (shared with windows-rs) or a Cangjie runtime thread
(a cj-specific defect).
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
  [DllImport("kernel32.dll")] public static extern IntPtr OpenThread(uint acc, bool inh, uint tid);
  [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
  [DllImport("ntdll.dll")] public static extern int NtQueryInformationThread(IntPtr h, int cls, ref IntPtr buf, int len, IntPtr ret);
  public struct RECT { public int Left, Top, Right, Bottom; }
  // ThreadQuerySetWin32StartAddress = 9
  public static long StartAddr(uint tid){
    IntPtr h = OpenThread(0x0040, false, tid);              // THREAD_QUERY_INFORMATION
    if(h == IntPtr.Zero){ h = OpenThread(0x0800, false, tid); } // THREAD_QUERY_LIMITED_INFORMATION
    if(h == IntPtr.Zero){ return 0; }
    IntPtr val = IntPtr.Zero;
    int st = NtQueryInformationThread(h, 9, ref val, IntPtr.Size, IntPtr.Zero);
    CloseHandle(h);
    if(st != 0){ return -1; }
    return val.ToInt64();
  }
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
$pid_ui=0; $uiTid=[Win]::GetWindowThreadProcessId($hwnd,[ref]$pid_ui)
$rect=New-Object Win+RECT; [void][Win]::GetWindowRect($hwnd,[ref]$rect)
$cx=[int]($rect.Left+($rect.Right-$rect.Left)*0.62); $cy=[int]($rect.Top+($rect.Bottom-$rect.Top)*0.5)
Write-Output "TARGET ui_pid=$pid_ui ui_tid=$uiTid"

# Build a module map [base, base+size) -> name for address resolution.
$proc = Get-Process -Id $pid_ui
$modules = @()
foreach($m in $proc.Modules){
  $modules += [pscustomobject]@{ name=$m.ModuleName; base=$m.BaseAddress.ToInt64(); size=$m.ModuleMemorySize }
}
function ResolveMod([long]$addr){
  foreach($m in $modules){ if($addr -ge $m.base -and $addr -lt ($m.base + $m.size)){ return ("{0}+0x{1:X}" -f $m.name,($addr-$m.base)) } }
  return ("0x{0:X} (unmapped/JIT/cj-heap)" -f $addr)
}

function Snap($p){ $h=@{}; (Get-Process -Id $p).Threads | ForEach-Object { try{ $h[$_.Id]=$_.TotalProcessorTime }catch{} }; return $h }

# Continuous scroll driver.
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
    $i++; if(($i % 12) -eq 0){ $down = -not $down }
    Start-Sleep -Milliseconds 55
  }
} -ArgumentList $src,$cx,$cy,$ScrollS

$s0 = Snap $pid_ui; $w0 = Get-Date
Start-Sleep -Seconds $ScrollS
$ms = ((Get-Date)-$w0).TotalMilliseconds
$s1 = Snap $pid_ui
Wait-Job $job | Out-Null; Remove-Job $job

$rows = New-Object System.Collections.ArrayList
foreach($tid in $s1.Keys){
  if($s0.ContainsKey($tid)){
    $dms = ($s1[$tid]-$s0[$tid]).TotalMilliseconds
    if($dms -gt 5){
      $pct=[math]::Round(100.0*$dms/$ms,1)
      $addr=[Win]::StartAddr([uint32]$tid)
      $mod = if($addr -gt 0){ ResolveMod $addr } elseif($addr -eq 0){ "<open failed>" } else { "<query failed>" }
      $isUi = if($tid -eq $uiTid){'<-UI'}else{''}
      [void]$rows.Add([pscustomobject]@{ tid=$tid; pct=$pct; mod=$mod; tag=$isUi })
    }
  }
}
Write-Output "HOT THREADS during scroll (button page), window ${ms}ms:"
$rows | Sort-Object pct -Descending | Select-Object -First 10 | ForEach-Object {
  Write-Output ("   tid={0,-7} cpu={1,5}%  start={2} {3}" -f $_.tid,$_.pct,$_.mod,$_.tag)
}
"""


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--boot-s", type=float, default=15.0)
    ap.add_argument("--scroll-s", type=int, default=8)
    ap.add_argument("--page", default="Basic Input|Button")
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
        script = PROBE.replace("__SCROLL__", str(args.scroll_s))
        r = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", script],
                           capture_output=True, encoding="utf-8", errors="replace",
                           timeout=args.scroll_s + 120)
        print(r.stdout.strip(), flush=True)
        if r.stderr and r.stderr.strip():
            print("[stderr] " + r.stderr.strip()[:1500], flush=True)
    finally:
        try:
            subprocess.run(["taskkill", "/IM", "main.exe", "/F"], capture_output=True)
            subprocess.run(["taskkill", "/IM", "cjv.exe", "/F"], capture_output=True)
        except Exception:
            pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
