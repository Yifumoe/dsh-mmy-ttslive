Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

$root = [System.Windows.Automation.AutomationElement]::RootElement
$cond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Button)
$all = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $cond)
$hits = @()
foreach ($b in $all) {
  $n = $b.Current.Name
  if ($n -and $n.Length -le 6) { $hits += $b }
  Write-Output ('btn: [' + $n + ']')
}
$target = $null
foreach ($b in $hits) { if ($b.Current.Name -like '*条幅*') { $target = $b; break } }
if (-not $target) { Write-Output 'no match'; exit 1 }
Write-Output ('clicking: ' + $target.Current.Name)
$target.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
Start-Sleep -Milliseconds 900
Write-Output 'invoked'
