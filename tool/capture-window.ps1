# Launches the app with optional arguments, waits, and saves a PNG of its
# window. Used to verify screens from a script (synthetic clicks do not
# reach the Flutter window, so startup flags such as --open-first,
# --compose, --reply, --files drive the state instead).
#
#   tool\capture-window.ps1 -Exe build\windows\x64\runner\Release\convomail.exe -Out shot.png -Args @("--files")
param(
  [Parameter(Mandatory=$true)][string]$Exe,
  [Parameter(Mandatory=$true)][string]$Out,
  [int]$WaitMs = 8000,
  [string[]]$Args = @()
)
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class Win {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int cmd);
  [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr hwnd, int attr, out RECT pvAttribute, int cb);
}
"@
$p = if ($Args.Length -gt 0) { Start-Process -FilePath $Exe -ArgumentList $Args -PassThru } else { Start-Process -FilePath $Exe -PassThru }
Start-Sleep -Milliseconds $WaitMs
$p.Refresh()
$h = $p.MainWindowHandle
if ($h -eq [IntPtr]::Zero) {
  $q = Get-Process | Where-Object { $_.Name -eq $p.Name -and $_.MainWindowHandle -ne 0 } | Select-Object -First 1
  if ($q) { $h = $q.MainWindowHandle }
}
if ($h -eq [IntPtr]::Zero) { Write-Error "No window found"; exit 1 }
[Win]::ShowWindow($h, 9) | Out-Null
[Win]::SetForegroundWindow($h) | Out-Null
Start-Sleep -Milliseconds 600
$r = New-Object Win+RECT
# DWMWA_EXTENDED_FRAME_BOUNDS = 9: the visible frame without the invisible resize border.
if ([Win]::DwmGetWindowAttribute($h, 9, [ref]$r, [System.Runtime.InteropServices.Marshal]::SizeOf($r)) -ne 0) { [Win]::GetWindowRect($h, [ref]$r) | Out-Null }
$w = $r.Right - $r.Left; $hh = $r.Bottom - $r.Top
$bmp = New-Object System.Drawing.Bitmap $w, $hh
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($r.Left, $r.Top, 0, 0, $bmp.Size)
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Output "SAVED $Out ${w}x${hh}"
