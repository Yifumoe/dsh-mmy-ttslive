Add-Type -AssemblyName PresentationFramework
$h = Invoke-RestMethod -Uri 'http://127.0.0.1:7788/history?limit=20' -TimeoutSec 3
$hw = New-Object System.Windows.Window
$hw.Width = 720
$hw.Height = 560
$hw.WindowStartupLocation = 'CenterScreen'
$hw.Topmost = $true
$hw.FontFamily = 'Microsoft YaHei UI'
$hw.Background = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromArgb(255, 0xEF, 0xF6, 0xFA))
$tb = New-Object System.Windows.Controls.TextBox
$tb.IsReadOnly = $true
$tb.TextWrapping = 'Wrap'
$tb.BorderThickness = 0
$tb.Background = [Windows.Media.Brushes]::Transparent
$tb.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromArgb(255, 0x20, 0x38, 0x49))
$tb.FontSize = 16
$tb.LineHeight = 27
$tb.Padding = New-Object System.Windows.Thickness 16
$tb.VerticalScrollBarVisibility = 'Auto'
$lines = @()
foreach ($it in $h.items) { $lines += ('[{0}/{1}]  {2}' -f $it.index, $it.total, $it.text) }
$tb.Text = ($lines -join "`r`n`r`n")
$hw.Content = $tb
$hw.Show()
Start-Sleep -Seconds 12
