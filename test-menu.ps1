Add-Type -AssemblyName PresentationFramework
$w = New-Object System.Windows.Window
$w.Width = 200
$w.Height = 100
$mi = New-Object System.Windows.Controls.MenuItem
$mi.Header = 'x'
$mi.Tag = 70
$mi.Add_Click({
    try {
      $v = $this.Tag
      [IO.File]::WriteAllText('D:\DSH-MMYMOE\.cache\menu-test.txt', ('tag=' + $v))
    } catch {
      [IO.File]::WriteAllText('D:\DSH-MMYMOE\.cache\menu-test.txt', ('err=' + $_.Exception.Message))
    }
  })
$w.Content = $mi
$w.Show()
$args2 = New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent)
$mi.RaiseEvent($args2)
Start-Sleep -Milliseconds 300
$w.Close()
