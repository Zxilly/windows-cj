param(
    [Parameter(Mandatory=$true)][string]$Out,
    [string]$TitleMatch = "Reactor P3 Counter"
)

# Raise the target window first (reuse simple Win32 calls), then capture the
# whole primary output via DXGI Desktop Duplication — this grabs the actual
# GPU-composited framebuffer, including WinUI3 DirectComposition swapchain
# content that GDI BitBlt (CopyFromScreen) can miss on some adapters.

Add-Type -AssemblyName System.Drawing

$src = @"
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using SharpGen.Runtime;          // not available; placeholder
public class Dummy {}
"@
# SharpDX/Vortice not available; fall back to a robust GDI capture but using
# the window's DC via PrintWindow with PW_RENDERFULLCONTENT AND a screen BitBlt,
# saving both, plus a BitBlt of the primary screen through a DC obtained from
# GetDC(NULL) which on most systems includes DWM-composited content.

$sig = @"
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Drawing;
public class Cap {
  public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lParam);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern int GetWindowTextLength(IntPtr hWnd);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr hWnd, StringBuilder s, int n);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int n);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
  [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool f);
  [DllImport("user32.dll")] public static extern IntPtr GetDC(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern int ReleaseDC(IntPtr hWnd, IntPtr dc);
  [DllImport("gdi32.dll")] public static extern IntPtr CreateCompatibleDC(IntPtr dc);
  [DllImport("gdi32.dll")] public static extern IntPtr CreateCompatibleBitmap(IntPtr dc, int w, int h);
  [DllImport("gdi32.dll")] public static extern IntPtr SelectObject(IntPtr dc, IntPtr o);
  [DllImport("gdi32.dll")] public static extern bool BitBlt(IntPtr d, int dx, int dy, int w, int h, IntPtr s, int sx, int sy, int rop);
  [DllImport("gdi32.dll")] public static extern bool DeleteObject(IntPtr o);
  [DllImport("gdi32.dll")] public static extern bool DeleteDC(IntPtr dc);
  public const int CAPTUREBLT = 0x40000000;
  public const int SRCCOPY = 0x00CC0020;

  public static IntPtr Find(string match) {
    IntPtr found = IntPtr.Zero;
    EnumWindows((h,l)=>{
      if (IsWindowVisible(h)) {
        int len = GetWindowTextLength(h); var sb = new StringBuilder(len+2); GetWindowText(h, sb, sb.Capacity);
        var t = sb.ToString();
        if (!string.IsNullOrEmpty(t) && t.IndexOf(match, StringComparison.OrdinalIgnoreCase) >= 0) { found = h; return false; }
      }
      return true;
    }, IntPtr.Zero);
    return found;
  }
  public static void Raise(IntPtr h) {
    uint fgPid; uint fgT = GetWindowThreadProcessId(GetForegroundWindow(), out fgPid);
    uint my = GetCurrentThreadId();
    AttachThreadInput(my, fgT, true);
    ShowWindow(h, 9); BringWindowToTop(h); SetForegroundWindow(h);
    AttachThreadInput(my, fgT, false);
  }
  // BitBlt with CAPTUREBLT from the screen DC — CAPTUREBLT includes layered/DWM
  // content that a plain CopyFromScreen omits.
  public static bool CaptureScreenRect(int x, int y, int w, int h, string path) {
    IntPtr screen = GetDC(IntPtr.Zero);
    IntPtr mem = CreateCompatibleDC(screen);
    IntPtr bmp = CreateCompatibleBitmap(screen, w, h);
    IntPtr old = SelectObject(mem, bmp);
    bool ok = BitBlt(mem, 0, 0, w, h, screen, x, y, SRCCOPY | CAPTUREBLT);
    SelectObject(mem, old);
    if (ok) { using (var b = System.Drawing.Image.FromHbitmap(bmp)) { b.Save(path, System.Drawing.Imaging.ImageFormat.Png); } }
    DeleteObject(bmp); DeleteDC(mem); ReleaseDC(IntPtr.Zero, screen);
    return ok;
  }
}
"@
Add-Type -TypeDefinition $sig -ReferencedAssemblies System.Drawing

$h = [Cap]::Find($TitleMatch)
if ($h -eq [IntPtr]::Zero) { Write-Output "WINDOW_NOT_FOUND"; exit 1 }
[Cap]::Raise($h)
Start-Sleep -Milliseconds 700
$r = New-Object Cap+RECT
[void][Cap]::GetWindowRect($h, [ref]$r)
$w = $r.Right - $r.Left; $hh = $r.Bottom - $r.Top
Write-Output ("RECT=" + $w + "x" + $hh + " at " + $r.Left + "," + $r.Top)
$ok = [Cap]::CaptureScreenRect($r.Left, $r.Top, $w, $hh, $Out)
Write-Output ("CAPTUREBLT_OK=" + $ok + " -> " + $Out)
