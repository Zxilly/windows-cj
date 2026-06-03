param(
    [string]$TitleMatch = "Reactor WinUI Gallery",
    [Parameter(Mandatory=$true)][string]$Out,
    [int]$W = 1000,
    [int]$H = 1500,
    [int]$X = 20,
    [int]$Y = 0
)

# Resize the target window taller than the screen, then PrintWindow it to a
# bitmap. PrintWindow renders the full window (including the off-screen lower
# portion) into the DC, so vertically-stacked sample cards below the visible
# fold are captured without scrolling.

Add-Type -AssemblyName System.Drawing

$sig = @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
using System.Drawing;
public class WinCap2 {
  public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lParam);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
  [DllImport("user32.dll")] public static extern int GetWindowTextLength(IntPtr hWnd);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr hWnd, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr hWnd, int x, int y, int w, int h, bool repaint);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdcBlt, uint nFlags);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
  public static string Title(IntPtr h) {
    int len = GetWindowTextLength(h); var sb = new StringBuilder(len + 2);
    GetWindowText(h, sb, sb.Capacity); return sb.ToString();
  }
  public static IntPtr Find(string match) {
    IntPtr found = IntPtr.Zero;
    EnumWindows((h, l) => {
      if (IsWindowVisible(h)) {
        string t = Title(h);
        if (!string.IsNullOrEmpty(t) && t.IndexOf(match, StringComparison.OrdinalIgnoreCase) >= 0) { found = h; return false; }
      }
      return true;
    }, IntPtr.Zero);
    return found;
  }
  public static bool PrintTo(IntPtr h, string path) {
    RECT r; if (!GetWindowRect(h, out r)) return false;
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
Add-Type -TypeDefinition $sig -ReferencedAssemblies System.Drawing

$h = [WinCap2]::Find($TitleMatch)
if ($h -eq [IntPtr]::Zero) { Write-Output "WINDOW_NOT_FOUND"; exit 1 }
[void][WinCap2]::BringWindowToTop($h)
[void][WinCap2]::SetForegroundWindow($h)
[void][WinCap2]::MoveWindow($h, $X, $Y, $W, $H, $true)
Start-Sleep -Milliseconds 900
$ok = [WinCap2]::PrintTo($h, $Out)
Write-Output ("CAPTURE_TITLE=" + [WinCap2]::Title($h))
Write-Output ("PRINTWINDOW_OK=" + $ok + " PATH=" + $Out)
