Add-Type -AssemblyName System.Windows.Forms
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class SwiftPhotoWindow {
 [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr window, out RECT rect);
 [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr window, int x, int y, int width, int height, bool repaint);
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr window, int command);
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr window);
}
'@
$emulatorProcess = Get-Process | Where-Object {
    $_.ProcessName -like 'qemu-system-*' -and $_.MainWindowHandle -ne 0
} | Select-Object -First 1
if (!$emulatorProcess) { throw 'Jendela emulator tidak ditemukan.' }
$emulatorHandle = $emulatorProcess.MainWindowHandle
[SwiftPhotoWindow]::ShowWindow($emulatorHandle, 9) | Out-Null
$emulatorRect = New-Object SwiftPhotoWindow+RECT
[SwiftPhotoWindow]::GetWindowRect($emulatorHandle, [ref]$emulatorRect) | Out-Null
$screenArea = [System.Windows.Forms.Screen]::FromHandle($emulatorHandle).WorkingArea
$emulatorRatio = ($emulatorRect.Right - $emulatorRect.Left) / [double]($emulatorRect.Bottom - $emulatorRect.Top)
$targetHeight = $screenArea.Height - 16
$targetWidth = [int]($targetHeight * $emulatorRatio)
if ($targetWidth -gt ($screenArea.Width - 16)) {
    $targetWidth = $screenArea.Width - 16
    $targetHeight = [int]($targetWidth / $emulatorRatio)
}
$targetX = $screenArea.Left + [int](($screenArea.Width - $targetWidth) / 2)
$targetY = $screenArea.Top + [int](($screenArea.Height - $targetHeight) / 2)
[SwiftPhotoWindow]::MoveWindow($emulatorHandle, $targetX, $targetY, $targetWidth, $targetHeight, $true) | Out-Null
[SwiftPhotoWindow]::SetForegroundWindow($emulatorHandle) | Out-Null
