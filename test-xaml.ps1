Add-Type -AssemblyName PresentationFramework
foreach ($f in @('skin-a.xaml','skin-b.xaml')) {
  try {
    $x = [System.Windows.Markup.XamlReader]::Parse((Get-Content -Raw -Encoding UTF8 (Join-Path 'D:\DSH-MMYMOE\dsh-mmy-ttslive\ui' $f)))
    $g = $x.FindName('Grip')
    "$f OK grip=$($g.GetType().Name) w=$($g.Width) opacity=$($g.Opacity)"
    $x.Close()
  } catch { "$f FAIL: $($_.Exception.Message)" }
}
