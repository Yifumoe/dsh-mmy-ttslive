Add-Type -AssemblyName PresentationFramework
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class MM {
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr e);
  public static void RightClick(int x, int y) {
    SetCursorPos(x, y);
    mouse_event(0x0008, 0, 0, 0, IntPtr.Zero);
    System.Threading.Thread.Sleep(80);
    mouse_event(0x0010, 0, 0, 0, IntPtr.Zero);
  }
}
"@
$stateFile = 'D:\DSH-MMYMOE\dsh-mmy-ttslive\state.json'
$st = Get-Content $stateFile -Raw | ConvertFrom-Json
$x = [int]$st.left + 300
$y = [int]$st.top + 60
Write-Output ("right-click at $x,$y")
[MM]::RightClick($x, $y)
Start-Sleep -Milliseconds 900
$shot = 'D:\DSH-MMYMOE\.cache\ttslive-panel.png'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'D:\DSH-MMYMOE\dsh-mmy-ttslive\shot.ps1' $shot
Write-Output 'shot done'
