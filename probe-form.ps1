Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$out = 'D:\DSH-MMYMOE\.cache\psform.log'
[System.IO.File]::WriteAllText($out, 'begin')
$f = New-Object System.Windows.Forms.Form
$f.Text = 'ttslive-probe'
$f.Width = 420
$f.Height = 200
$f.TopMost = $true
$f.BackColor = [System.Drawing.Color]::FromArgb(30, 44, 58)
$l = New-Object System.Windows.Forms.Label
$l.Text = 'hello from winforms'
$l.ForeColor = [System.Drawing.Color]::White
$l.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 14)
$l.AutoSize = $true
$l.Location = New-Object System.Drawing.Point(20, 40)
$f.Controls.Add($l)
$f.Show()
[System.IO.File]::AppendAllText($out, "`nshown")
for ($i = 0; $i -lt 30; $i++) {
  [System.Windows.Forms.Application]::DoEvents()
  Start-Sleep -Milliseconds 100
}
[System.IO.File]::AppendAllText($out, "`nlooped")
$f.Close()
[System.IO.File]::AppendAllText($out, "`nclosed")
