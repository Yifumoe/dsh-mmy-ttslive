$ErrorActionPreference = 'Stop'
$root = 'D:\DSH-MMYMOE\dsh-mmy-ttslive'
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$raw = [IO.File]::ReadAllText((Join-Path $root 'ui\skin-a.xaml'), [Text.Encoding]::UTF8)
$w = [Windows.Markup.XamlReader]::Parse($raw)

$img = [Windows.Media.Imaging.BitmapImage]::new()
$img.BeginInit()
$img.UriSource = [Uri]::new((Join-Path $root 'assets\avatar.jpg'))
$img.CacheOption = 'OnLoad'
$img.EndInit()
$br = [Windows.Media.ImageBrush]::new($img)
$br.Stretch = 'UniformToFill'
$w.FindName('Avatar').Fill = $br

$sampleB64 = '5Li75Lq677yM6L+Z5LiA5Y+l5piv5oiR5q2j5Zyo6K+055qE6K+d77yM5a2X5bmV5Lya6Lef552A6K+t6Z+z5LiA5q615LiA5q615b6A5YmN6LWw44CC'
$sample = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($sampleB64))
$w.FindName('Caption').Text = $sample
$w.FindName('Counter').Text = '2 / 5'
$w.Left = 320
$w.Top = 760
$w.Show()

for ($i = 0; $i -lt 14; $i++) { [Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 50 }
Start-Sleep -Milliseconds 250

$b = [System.Windows.Forms.SystemInformation]::VirtualScreen
$bmp = New-Object System.Drawing.Bitmap($b.Width, $b.Height)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($b.X, $b.Y, 0, 0, $bmp.Size)
$out = 'D:\DSH-MMYMOE\.cache\ttslive-a-probe.png'
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose()
$bmp.Dispose()
$w.Close()
Write-Output ('saved ' + $out)
