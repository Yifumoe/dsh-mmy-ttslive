Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

$root = [System.Windows.Automation.AutomationElement]::RootElement
$cond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Slider)
$el = $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $cond)
if (-not $el) { Write-Output 'slider not found'; exit 1 }
Write-Output ('found slider: ' + $el.Current.Name + ' value=' + $el.GetCurrentPattern([System.Windows.Automation.RangeValuePattern]::Pattern).Current.Value)
$p = $el.GetCurrentPattern([System.Windows.Automation.RangeValuePattern]::Pattern)
$p.SetValue(55)
Start-Sleep -Milliseconds 600
$el2 = $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $cond)
Write-Output ('after: ' + $el2.GetCurrentPattern([System.Windows.Automation.RangeValuePattern]::Pattern).Current.Value)
