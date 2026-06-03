#!/usr/bin/env python3
"""High-FPS visible-frame probe for scroll smoothness (zero app instrumentation).

A single mouse-wheel notch on a modern WinUI ScrollView triggers a smooth,
animated, decelerating scroll lasting ~150-250ms. If rendering is smooth that
animation delivers a fresh frame every refresh interval (~16ms @60Hz / ~8ms
@120Hz); if it stutters, frames arrive in lurches with long gaps.

This probe captures a thin VERTICAL screen strip over the content area at ~3ms
cadence (GDI CopyFromScreen, fast), hashes each capture, and timestamps every
hash CHANGE = one delivered visible frame. It fires N single-notch flicks and,
for each, reports the inter-frame gap distribution during the motion window.
Long gaps (>33ms ~ a dropped frame at 30fps) are the objective jank signal.
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
$Trials = __TRIALS__
$CaptureMs = __CAPMS__
$src = @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Diagnostics;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class Cap {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f,uint dx,uint dy,uint d,UIntPtr e);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h,IntPtr a,int x,int y,int cx,int cy,uint f);
  public struct RECT { public int Left, Top, Right, Bottom; }

  public static void Resize(IntPtr hwnd, int cx, int cy){
    SetWindowPos(hwnd, IntPtr.Zero, 40, 40, cx, cy, 0x0004 /*NOZORDER*/ | 0x0010 /*NOACTIVATE*/);
  }

  public static string Run(IntPtr hwnd, int trials, int capMs){
    RECT r; GetWindowRect(hwnd, out r);
    int w = r.Right - r.Left, h = r.Bottom - r.Top;
    int sx = r.Left + (int)(w*0.60);     // strip x: content area, right of nav pane
    int sy = r.Top  + (int)(h*0.22);
    int sw = 6, sh = (int)(h*0.55);      // tall thin vertical strip
    int cx = r.Left + (int)(w*0.62), cy = r.Top + (int)(h*0.5);
    uint WHEEL=0x0800; uint DOWN=4294967176; uint UP=120;  // -120 / +120
    SetForegroundWindow(hwnd); System.Threading.Thread.Sleep(250);

    var bmp = new Bitmap(sw, sh, PixelFormat.Format32bppArgb);
    var g = Graphics.FromImage(bmp);
    Func<int> grab = () => {
      g.CopyFromScreen(sx, sy, 0, 0, new Size(sw, sh), CopyPixelOperation.SourceCopy);
      var bd = bmp.LockBits(new Rectangle(0,0,sw,sh), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
      int n = bd.Stride * sh; byte[] buf = new byte[n];
      Marshal.Copy(bd.Scan0, buf, 0, n); bmp.UnlockBits(bd);
      int hash = 17; for(int i=0;i<n;i+=16){ hash = hash*31 + buf[i]; } return hash;
    };

    var sb = new System.Text.StringBuilder();
    var allGaps = new List<double>();
    int allFrames = 0; bool downDir = true;
    for(int t=0; t<trials; t++){
      // settle, baseline
      System.Threading.Thread.Sleep(350);
      SetCursorPos(cx, cy);
      var changes = new List<double>();
      int prev = grab();
      var sw_ = Stopwatch.StartNew();
      // fire ONE notch (alternate direction so we never hit a scroll extent)
      uint d = downDir ? DOWN : UP; downDir = !downDir;
      mouse_event(WHEEL,0,0,d,UIntPtr.Zero);
      while(sw_.Elapsed.TotalMilliseconds < capMs){
        int cur = grab();
        if(cur != prev){ changes.Add(sw_.Elapsed.TotalMilliseconds); prev = cur; }
      }
      sw_.Stop();
      // gaps between consecutive delivered frames, within the motion window only
      // (motion window = first change .. last change).
      if(changes.Count >= 2){
        var gaps = new List<double>();
        for(int i=1;i<changes.Count;i++){ gaps.Add(changes[i]-changes[i-1]); allGaps.Add(changes[i]-changes[i-1]); }
        allFrames += changes.Count;
        gaps.Sort();
        double motion = changes[changes.Count-1]-changes[0];
        double p50 = gaps[gaps.Count/2];
        double mx = gaps[gaps.Count-1];
        int over33 = 0, over20 = 0; foreach(var x in gaps){ if(x>33)over33++; if(x>20)over20++; }
        sb.AppendLine(String.Format("  trial {0,2}: frames={1,3} motion={2,5:F0}ms gap_p50={3,4:F1} gap_max={4,5:F1}  >20ms={5} >33ms={6}",
          t+1, changes.Count, motion, p50, mx, over20, over33));
      } else {
        sb.AppendLine(String.Format("  trial {0,2}: frames={1} (no/low motion captured)", t+1, changes.Count));
      }
    }
    // aggregate
    if(allGaps.Count>0){
      allGaps.Sort();
      double p50=allGaps[allGaps.Count/2], p95=allGaps[(int)(allGaps.Count*0.95)], mx=allGaps[allGaps.Count-1];
      int o33=0,o20=0,o50=0; foreach(var x in allGaps){ if(x>50)o50++; if(x>33)o33++; if(x>20)o20++; }
      sb.AppendLine(String.Format("AGGREGATE frames={0} gaps={1}  p50={2:F1}ms p95={3:F1}ms max={4:F1}ms  >20ms={5} >33ms={6} >50ms={7}",
        allFrames, allGaps.Count, p50, p95, mx, o20, o33, o50));
      sb.AppendLine(String.Format("  interpretation: a smooth 60Hz scroll => gap_p50~16ms and ~0 gaps>33ms; many >33ms gaps = real dropped frames"));
    }
    return sb.ToString();
  }
}
"@
Add-Type -TypeDefinition $src -ReferencedAssemblies System.Drawing,System.Windows.Forms
Add-Type -AssemblyName UIAutomationClient

$hwnd=[IntPtr]::Zero
$root=[System.Windows.Automation.AutomationElement]::RootElement
$wc=New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty,[System.Windows.Automation.ControlType]::Window)
foreach($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children,$wc)){
  if($w.Current.Name -like "*Reactor WinUI Gallery*"){ $hwnd=[IntPtr]$w.Current.NativeWindowHandle; break }
}
if($hwnd -eq [IntPtr]::Zero){ Write-Output "WINDOW_NOT_FOUND"; exit 1 }
__RESIZE__
Write-Output ([Cap]::Run($hwnd, $Trials, $CaptureMs))
"""


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--boot-s", type=float, default=15.0)
    ap.add_argument("--trials", type=int, default=10)
    ap.add_argument("--capture-ms", type=int, default=320)
    ap.add_argument("--page", default="")
    ap.add_argument("--backdrop", default="", help="none|mica|micaalt|acrylic — switch via Materials page before measuring")
    ap.add_argument("--exe", default="", help="run a prebuilt exe directly (e.g. the windows-rs gallery.exe) instead of cjv")
    ap.add_argument("--cjexe", default="", help="run a specific cj exe via 'cjv exec' WITHOUT staging (e.g. a renamed page-heap-free copy)")
    ap.add_argument("--resize", default="", help="WxH physical px: SetWindowPos the window before measuring (isolate size vs scale)")
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
        if args.backdrop:
            # Switch the live window backdrop at runtime via the Materials page's
            # backdrop switcher (no rebuild needed), then continue to the target.
            label = {"none": "None (solid)", "mica": "Mica", "micaalt": "Mica Alt",
                     "acrylic": "Acrylic"}.get(args.backdrop.lower(), "None (solid)")
            subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(ROOT / "nav_select.ps1"),
                            "-Items", "Design Guidance|Materials", "-PauseMs", "1200"], capture_output=True, timeout=60)
            time.sleep(1.0)
            sel = (
                "Add-Type -AssemblyName UIAutomationClient,UIAutomationTypes;"
                "$root=[System.Windows.Automation.AutomationElement]::RootElement;"
                "$wc=New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty,[System.Windows.Automation.ControlType]::Window);"
                "$win=$null; foreach($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children,$wc)){ if($w.Current.Name -like '*Reactor WinUI Gallery*'){ $win=$w; break } };"
                "if($win){ $nc=New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty,'" + label + "');"
                "$it=$win.FindFirst([System.Windows.Automation.TreeScope]::Descendants,$nc);"
                "if($it){ $p=$it.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern); $p.Select(); Write-Output 'SELECTED' } else { Write-Output 'ITEM_NOT_FOUND' } } else { Write-Output 'WIN_NOT_FOUND' }"
            )
            rsel = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", sel],
                                  capture_output=True, encoding="utf-8", errors="replace", timeout=30)
            print(f"backdrop->{label}: {rsel.stdout.strip()}", flush=True)
            time.sleep(1.5)
        if args.page:
            subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(ROOT / "nav_select.ps1"),
                            "-Items", args.page, "-PauseMs", "1200"], capture_output=True, timeout=60)
            time.sleep(1.5)
        resize_ps = ""
        if args.resize:
            wpx, hpx = args.resize.lower().split("x")
            resize_ps = f"[Cap]::Resize($hwnd, {int(wpx)}, {int(hpx)}); Start-Sleep -Milliseconds 1200"
        script = (PROBE.replace("__TRIALS__", str(args.trials))
                       .replace("__CAPMS__", str(args.capture_ms))
                       .replace("__RESIZE__", resize_ps))
        r = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", script],
                           capture_output=True, encoding="utf-8", errors="replace",
                           timeout=args.trials * (args.capture_ms/1000 + 0.5) + 120)
        print(r.stdout.strip(), flush=True)
        if r.stderr and r.stderr.strip():
            print("[stderr] " + r.stderr.strip()[:1500], flush=True)
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
