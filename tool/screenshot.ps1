# Captures the running Robyne window to a PNG so the flagship skin can be
# compared against docs/design/mockups pixel by pixel.
#
# Usage:
#   pwsh -File tool/screenshot.ps1 -Out build/shots/discover.png
#   pwsh -File tool/screenshot.ps1 -Out build/shots/x.png -Width 1360 -Height 900
param(
  [string]$Out = "build/shots/capture.png",
  [int]$Width = 0,
  [int]$Height = 0,
  [string]$Title = "robyne"
)

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class RobyneWin {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int ht, bool r);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int w, int ht, uint f);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint flags);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
}
'@

$proc = Get-Process -Name $Title -ErrorAction SilentlyContinue |
  Where-Object { $_.MainWindowHandle -ne 0 } |
  Select-Object -First 1

if ($null -eq $proc) {
  throw "No visible window found for process '$Title'."
}

$handle = [IntPtr]$proc.MainWindowHandle

if ($Width -gt 0 -and $Height -gt 0) {
  # HWND_TOPMOST = -1, SWP_SHOWWINDOW = 0x40. Topmost keeps the window above
  # the desktop app and the browser while PrintWindow runs; it does not need
  # the OS focus for that, which is the whole point of this path.
  # SW_RESTORE (9) first: SW_SHOWMAXIMIZED would ignore the requested size.
  [RobyneWin]::ShowWindow($handle, 9) | Out-Null
  Start-Sleep -Milliseconds 120
  [RobyneWin]::MoveWindow($handle, 0, 0, $Width, $Height, $true) | Out-Null
  [RobyneWin]::SetWindowPos($handle, [IntPtr](-1), 0, 0, $Width, $Height, 0x40) | Out-Null
  Start-Sleep -Milliseconds 700
}

[RobyneWin]::SetForegroundWindow($handle) | Out-Null
Start-Sleep -Milliseconds 250

$rect = New-Object RobyneWin+RECT
[RobyneWin]::GetWindowRect($handle, [ref]$rect) | Out-Null
$w = $rect.Right - $rect.Left
$h = $rect.Bottom - $rect.Top

$bmp = New-Object System.Drawing.Bitmap($w, $h)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$dc = $g.GetHdc()
# PW_RENDERFULLCONTENT (0x2) is required for Flutter's compositor output:
# the plain PrintWindow path returns a blank frame for DWM-composited apps.
[RobyneWin]::PrintWindow($handle, $dc, 0x2) | Out-Null
$g.ReleaseHdc($dc)
$g.Dispose()

$full = [System.IO.Path]::GetFullPath($Out)
$dir = [System.IO.Path]::GetDirectoryName($full)
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
$bmp.Save($full, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

Write-Output "saved $full (${w}x${h})"
