param([string]$Id = 'BtnHistory')
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$root = [System.Windows.Automation.AutomationElement]::RootElement
$cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::AutomationIdProperty, $Id)
$el = $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $cond)
if ($el) {
  try {
    $p = $el.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
    $p.Invoke()
    Write-Output ('invoked ' + $Id)
  } catch {
    Write-Output ('invoke fail: ' + $_.Exception.Message)
  }
} else {
  Write-Output ('not found ' + $Id)
}
