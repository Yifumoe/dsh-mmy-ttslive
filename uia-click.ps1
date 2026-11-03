Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class M {
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr e);
  public const uint RDOWN = 0x0008;
  public const uint RUP = 0x0010;
  public static void RightClick(int x, int y) {
    SetCursorPos(x, y);
    mouse_event(RDOWN, 0, 0, 0, IntPtr.Zero);
    System.Threading.Thread.Sleep(80);
    mouse_event(RUP, 0, 0, 0, IntPtr.Zero);
  }
}
"@
[M]::RightClick(957, 962)
Start-Sleep -Milliseconds 700
$root = [System.Windows.Automation.AutomationElement]::RootElement
$cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, '90%')
$el = $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $cond)
if ($el) {
  Write-Output ('found: ' + $el.Current.Name + ' / ' + $el.Current.ControlType.ProgrammaticName)
  try {
    $p = $el.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
    $p.Invoke()
    Write-Output 'invoked'
  } catch {
    Write-Output ('invoke err: ' + $_.Exception.Message)
  }
} else {
  Write-Output 'not found'
  $all = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
  $names = @()
  foreach ($a in $all) { if ($a.Current.ControlType.ProgrammaticName -like '*Menu*') { $names += ($a.Current.ControlType.ProgrammaticName + ':' + $a.Current.Name) } }
  Write-Output ($names -join ' | ')
}
