param(
    [Parameter(Mandatory=$true)][string]$OutFull,
    [Parameter(Mandatory=$true)][string]$OutFg,
    [string]$TitleMatch = "Reactor P3 Counter"
)

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

# Full virtual-screen capture (taken last, after the target is raised).
$vs = [System.Windows.Forms.SystemInformation]::VirtualScreen

$sig = @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
using System.Drawing;
public class WinApiCap {
  public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lParam);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
  [DllImport("user32.dll")] public static extern int GetWindowTextLength(IntPtr hWnd);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr hWnd, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr after, int x, int y, int cx, int cy, uint flags);
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr hWnd, int x, int y, int w, int h, bool repaint);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
  [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
  [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdcBlt, uint nFlags);
  [DllImport("user32.dll")] public static extern IntPtr GetDC(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern int ReleaseDC(IntPtr hWnd, IntPtr dc);
  [DllImport("gdi32.dll")] public static extern IntPtr CreateCompatibleDC(IntPtr dc);
  [DllImport("gdi32.dll")] public static extern IntPtr CreateCompatibleBitmap(IntPtr dc, int w, int h);
  [DllImport("gdi32.dll")] public static extern IntPtr SelectObject(IntPtr dc, IntPtr o);
  [DllImport("gdi32.dll")] public static extern bool BitBlt(IntPtr d, int dx, int dy, int w, int h, IntPtr s, int sx, int sy, int rop);
  [DllImport("gdi32.dll")] public static extern bool DeleteObject(IntPtr o);
  [DllImport("gdi32.dll")] public static extern bool DeleteDC(IntPtr dc);
  // BitBlt with SRCCOPY|CAPTUREBLT from the screen DC captures layered / DWM /
  // WinUI3 DirectComposition content that a plain CopyFromScreen omits on some
  // adapters. Returns true on success and saves a PNG.
  public static bool CaptureScreenRectBlt(int x, int y, int w, int h, string path) {
    IntPtr screen = GetDC(IntPtr.Zero);
    IntPtr mem = CreateCompatibleDC(screen);
    IntPtr bmp = CreateCompatibleBitmap(screen, w, h);
    IntPtr old = SelectObject(mem, bmp);
    bool ok = BitBlt(mem, 0, 0, w, h, screen, x, y, unchecked((int)0x00CC0020) | unchecked((int)0x40000000));
    SelectObject(mem, old);
    if (ok) { using (var b = System.Drawing.Image.FromHbitmap(bmp)) { b.Save(path, System.Drawing.Imaging.ImageFormat.Png); } }
    DeleteObject(bmp); DeleteDC(mem); ReleaseDC(IntPtr.Zero, screen);
    return ok;
  }

  static readonly IntPtr HWND_TOP = IntPtr.Zero;
  static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
  static readonly IntPtr HWND_NOTOPMOST = new IntPtr(-2);
  const uint SWP_NOSIZE = 0x0001, SWP_NOMOVE = 0x0002, SWP_SHOWWINDOW = 0x0040;
  const int SW_RESTORE = 9, SW_SHOW = 5;

  public static string Title(IntPtr h) {
    int len = GetWindowTextLength(h);
    var sb = new StringBuilder(len + 2);
    GetWindowText(h, sb, sb.Capacity);
    return sb.ToString();
  }
  public static List<IntPtr> Find(string match) {
    var list = new List<IntPtr>();
    EnumWindows((h, l) => {
      if (IsWindowVisible(h)) {
        string t = Title(h);
        if (!string.IsNullOrEmpty(t) && t.IndexOf(match, StringComparison.OrdinalIgnoreCase) >= 0) list.Add(h);
      }
      return true;
    }, IntPtr.Zero);
    return list;
  }
  public static List<string> AllTitles() {
    var list = new List<string>();
    EnumWindows((h, l) => {
      if (IsWindowVisible(h)) { string t = Title(h); if (!string.IsNullOrEmpty(t)) list.Add(t); }
      return true;
    }, IntPtr.Zero);
    return list;
  }
  // Force the target window to the foreground using the AttachThreadInput trick
  // to bypass the foreground lock, then make it topmost briefly.
  public static void Raise(IntPtr h) {
    uint fgPid; uint fgThread = GetWindowThreadProcessId(GetForegroundWindow(), out fgPid);
    uint myThread = GetCurrentThreadId();
    AttachThreadInput(myThread, fgThread, true);
    ShowWindow(h, SW_RESTORE);
    BringWindowToTop(h);
    SetForegroundWindow(h);
    SetWindowPos(h, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW);
    SetWindowPos(h, HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW);
    AttachThreadInput(myThread, fgThread, false);
  }
  // Capture via PrintWindow (PW_RENDERFULLCONTENT = 2), works for occluded windows.
  public static bool PrintTo(IntPtr h, string path) {
    RECT r;
    if (!GetWindowRect(h, out r)) return false;
    int w = r.Right - r.Left, hgt = r.Bottom - r.Top;
    if (w <= 0 || hgt <= 0) return false;
    using (var bmp = new Bitmap(w, hgt))
    using (var g = Graphics.FromImage(bmp)) {
      IntPtr hdc = g.GetHdc();
      bool ok = PrintWindow(h, hdc, 2);
      g.ReleaseHdc(hdc);
      if (ok) { bmp.Save(path, System.Drawing.Imaging.ImageFormat.Png); }
      return ok;
    }
  }
}
"@
Add-Type -TypeDefinition $sig -ReferencedAssemblies System.Drawing, System.Windows.Forms

# Diagnostic: dump all visible window titles.
foreach ($t in [WinApiCap]::AllTitles()) { Write-Output ("VISIBLE_WINDOW=" + $t) }

$targets = [WinApiCap]::Find($TitleMatch)
$h = [IntPtr]::Zero
if ($targets.Count -gt 0) {
    $h = $targets[0]
    [WinApiCap]::Raise($h)
    Start-Sleep -Milliseconds 400
    # Nudge the window size to force a WinUI layout + composition pass, in case
    # the first frame did not flush content after the deferred render.
    $r0 = New-Object WinApiCap+RECT
    if ([WinApiCap]::GetWindowRect($h, [ref]$r0)) {
        $x = $r0.Left; $y = $r0.Top
        $w0 = $r0.Right - $r0.Left; $h0 = $r0.Bottom - $r0.Top
        [void][WinApiCap]::MoveWindow($h, 60, 60, 900, 640, $true)
        Start-Sleep -Milliseconds 500
        [void][WinApiCap]::MoveWindow($h, 60, 60, 901, 641, $true)
        Start-Sleep -Milliseconds 700
    }
} else {
    $h = [WinApiCap]::GetForegroundWindow()
}
Write-Output ("CAPTURE_TITLE=" + [WinApiCap]::Title($h))

# Screen-region capture of the (now raised) target window. Use BitBlt with
# CAPTUREBLT (not CopyFromScreen) so WinUI3 DirectComposition content is included
# in the grab; plain CopyFromScreen yields a blank client area for WinUI3 windows
# on some adapters (e.g. virtual/remote displays).
$r = New-Object WinApiCap+RECT
if ([WinApiCap]::GetWindowRect($h, [ref]$r)) {
    $w = $r.Right - $r.Left
    $hgt = $r.Bottom - $r.Top
    if ($w -gt 0 -and $hgt -gt 0) {
        $ok = [WinApiCap]::CaptureScreenRectBlt($r.Left, $r.Top, $w, $hgt, $OutFg)
        if (-not $ok) {
            # Fallback to CopyFromScreen if BitBlt failed.
            $b2 = New-Object System.Drawing.Bitmap $w, $hgt
            $g2 = [System.Drawing.Graphics]::FromImage($b2)
            $g2.CopyFromScreen($r.Left, $r.Top, 0, 0, $b2.Size)
            $b2.Save($OutFg, [System.Drawing.Imaging.ImageFormat]::Png)
            $g2.Dispose(); $b2.Dispose()
        }
        Write-Output ("FOREGROUND_RECT=" + $w + "x" + $hgt)
        Write-Output ("FG_CAPTUREBLT_OK=" + $ok)
        Write-Output ("FG_SAVED=" + $OutFg)
    }
}

# Also try PrintWindow into a sibling file (robust against occlusion).
$pwPath = [System.IO.Path]::ChangeExtension($OutFg, $null) + "_printwindow.png"
$pwPath = $pwPath.Replace("._printwindow.png", "_printwindow.png")
try {
    $ok = [WinApiCap]::PrintTo($h, $pwPath)
    Write-Output ("PRINTWINDOW_OK=" + $ok + " PATH=" + $pwPath)
} catch {
    Write-Output ("PRINTWINDOW_ERR=" + $_.Exception.Message)
}

# Full-screen capture last (target is raised on top now).
$bmp = New-Object System.Drawing.Bitmap $vs.Width, $vs.Height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($vs.X, $vs.Y, 0, 0, $bmp.Size)
$bmp.Save($OutFull, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Output ("FULL_SAVED=" + $OutFull)
