Add-Type @"
using System;
using System.Runtime.InteropServices;
public class ClicH {
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr e);
  public static void Click(int x, int y) {
    SetCursorPos(x, y);
    System.Threading.Thread.Sleep(120);
    mouse_event(0x0002, 0, 0, 0, IntPtr.Zero);
    System.Threading.Thread.Sleep(60);
    mouse_event(0x0004, 0, 0, 0, IntPtr.Zero);
  }
}
"@
$st = Get-Content 'D:\DSH-MMYMOE\dsh-mmy-ttslive\state.json' -Raw | ConvertFrom-Json
$L = [int]$st.left
$T = [int]$st.top
Write-Output ("window $L,$T")
[ClicH]::Click(($L + 158), ($T + 95))
Start-Sleep -Milliseconds 1200
Write-Output 'clicked history'
