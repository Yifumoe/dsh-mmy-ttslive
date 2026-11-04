# dsh-mmy-ttslive - WPF caption window (pure ASCII source; Chinese comes from XAML or base64)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
try {
  Add-Type -TypeDefinition 'using System.Runtime.InteropServices; public class MmyDpi { [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); }' -ErrorAction Stop
} catch {}
try { [void][MmyDpi]::SetProcessDPIAware() } catch {}

$root = $PSScriptRoot
function Zh([string]$b64) { [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b64)) }

function Log-Line([string]$msg) {
  try {
    $lf = Join-Path $PSScriptRoot '.cache\ttslive.log'
    [IO.File]::AppendAllText($lf, ((Get-Date).ToString('HH:mm:ss') + ' ' + $msg + "`r`n"), (New-Object Text.UTF8Encoding($false)))
  } catch {}
}

$L = @{
  skinA   = (Zh 'QSDpgJrmoI/mnaHluYU=')
  skinB   = (Zh 'QiDmgqzmta7ljaE=')
  center  = (Zh '5bGF5Lit')
  exit    = (Zh '6YCA5Ye6')
  opacity = (Zh '6YCP5piO5bqm')
  history = (Zh '5Y6G5Y+y6K6w5b2V')
  show    = (Zh '5pi+56S656qX5Y+j')
  close   = (Zh '5YWz6Zet')
  left    = (Zh '5Ymp')
  sec     = (Zh '56eS')
  idle    = (Zh '5a2Q6Z2Z5Lit')
  idlePrefix = (Zh '5bey5pS26LW3IMK3IOmdmem7mA==')
}

$stateFile = Join-Path $root 'state.json'
$script:state = @{ skin = 'a'; left = $null; top = $null; opacity = 0.92; w = $null; h = $null }
if (Test-Path $stateFile) {
  try {
    $s = [IO.File]::ReadAllText($stateFile, [Text.Encoding]::UTF8) | ConvertFrom-Json
    if ($s.skin) { $script:state.skin = [string]$s.skin }
    if ($null -ne $s.left) { $script:state.left = [double]$s.left }
    if ($null -ne $s.top) { $script:state.top = [double]$s.top }
    if ($null -ne $s.opacity) { $script:state.opacity = [double]$s.opacity }
  } catch {}
}
$script:skin = $script:state.skin
$script:opacity = [double]$script:state.opacity
if ($script:opacity -le 0 -or $script:opacity -gt 1) { $script:opacity = 0.92 }

$portFile = Join-Path $root '.cache\ttslive-port.txt'
$script:port = 7788
if (Test-Path $portFile) {
  try { $script:port = [int](([IO.File]::ReadAllText($portFile)).Trim()) } catch {}
}

$avatarPath = Join-Path $root 'assets\avatar.jpg'
$script:avatarBmp = $null
if (Test-Path $avatarPath) {
  $bmp = New-Object Windows.Media.Imaging.BitmapImage
  $bmp.BeginInit()
  $bmp.UriSource = [Uri]::new($avatarPath)
  $bmp.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
  $bmp.EndInit()
  $bmp.Freeze()
  $script:avatarBmp = $bmp
}

function Save-State {
  if (-not $script:win) { return }
  $o = [ordered]@{
    skin    = $script:skin
    left    = [math]::Round([double]$script:win.Left, 1)
    top     = [math]::Round([double]$script:win.Top, 1)
    opacity = [math]::Round([double]$script:opacity, 2)
    w       = [math]::Round([double]$script:win.Width, 0)
    h       = [math]::Round([double]$script:win.Height, 0)
  }
  $json = $o | ConvertTo-Json -Compress
  [IO.File]::WriteAllText($stateFile, $json, (New-Object Text.UTF8Encoding($false)))
}

function Place-Window($win) {
  # WPF 的 Left/Top 是 DIP，WinForms Screen.WorkingArea 是物理像素；
  # 125% 缩放下差 1.25 倍，会把窗口算到屏幕外（2026-11-04 踩到）。
  $wa = [System.Windows.SystemParameters]::WorkArea
  $ww = [double]$win.Width
  $wh = [double]$win.Height
  if ($null -ne $script:state.left -and $null -ne $script:state.top) {
    $l = [double]$script:state.left
    $t = [double]$script:state.top
    if ($l -lt $wa.X) { $l = $wa.X }
    if ($t -lt $wa.Y) { $t = $wa.Y }
    if (($l + $ww) -gt $wa.Right) { $l = [math]::Max($wa.X, $wa.Right - $ww) }
    if (($t + $wh) -gt $wa.Bottom) { $t = [math]::Max($wa.Y, $wa.Bottom - $wh - 8) }
    $win.Left = $l
    $win.Top = $t
  } else {
    $win.Left = $wa.X + [math]::Max(0, ($wa.Width - $ww) / 2)
    $win.Top = $wa.Bottom - $wh - 80
  }
}

# Background alpha only -- text stays fully opaque.
function Apply-Opacity {
  $w = $script:win
  if (-not $w) { return }
  $bg = $w.FindName('Bg')
  if (-not $bg) { Log-Line 'opacity: Bg border not found'; return }
  if ($script:skin -eq 'b') { $r = 0xF7; $g = 0xFB; $b = 0xFD } else { $r = 0xF4; $g = 0xF9; $b = 0xFC }
  $a = [byte][math]::Round(255 * $script:opacity)
  $brush = New-Object Windows.Media.SolidColorBrush
  $brush.Color = [Windows.Media.Color]::FromArgb($a, [byte]$r, [byte]$g, [byte]$b)
  $brush.Freeze()
  $bg.Background = $brush
}

function Set-Live([bool]$on) {
  $w = $script:win
  if (-not $w) { return }
  $dot = $w.FindName('LiveDot')
  if (-not $dot) { $dot = $w.FindName('LiveDotB') }
  if ($dot) {
    if ($on) { $dot.Fill = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromArgb(255, 0xC2, 0x26, 0x3F)) }
    else { $dot.Fill = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromArgb(255, 0xB8, 0xC6, 0xCF)) }
  }
}

function Has-ButtonAncestor($src) {
  try {
    $n = $src
    for ($i = 0; $i -lt 10 -and $n; $i++) {
      if ($n -is [System.Windows.Controls.Button]) { return $true }
      $n = [System.Windows.Media.VisualTreeHelper]::GetParent($n)
    }
  } catch {}
  return $false
}

function Hide-Window {
  if ($script:win) { $script:win.Hide() }
}

function Show-Window {
  if (-not $script:win) { return }
  $script:win.Show()
  $script:win.Topmost = $true
  try { $script:win.Activate() } catch {}
}

function Exit-App {
  try { if ($script:tray) { $script:tray.Visible = $false; $script:tray.Dispose() } } catch {}
  try { if ($script:win) { $script:win.Close() } } catch {}
  [System.Windows.Threading.Dispatcher]::CurrentDispatcher.InvokeShutdown()
}

function Show-History {
  Log-Line 'history: invoked'
  try {
    $h = Invoke-RestMethod -Uri ('http://127.0.0.1:' + $script:port + '/history?limit=20') -TimeoutSec 2
  } catch {
    Log-Line ('history: http fail ' + $_.Exception.Message)
    return
  }
  Log-Line ('history: items=' + @($h.items).Count)
  $lines = @()
  foreach ($it in $h.items) { $lines += ('[{0}/{1}]  {2}' -f $it.index, $it.total, $it.text) }
  $xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        Width="720" Height="560" WindowStartupLocation="CenterScreen" Topmost="True"
        FontFamily="Microsoft YaHei UI" UseLayoutRounding="True" SnapsToDevicePixels="True">
  <Border Background="#F7FBFD" BorderBrush="#28698A59" BorderThickness="1">
    <Grid>
      <Grid.RowDefinitions>
        <RowDefinition Height="46"/>
        <RowDefinition Height="*"/>
      </Grid.RowDefinitions>
      <Border x:Name="Head" Grid.Row="0" Background="#EFF6FA" BorderBrush="#28698A29" BorderThickness="0,0,0,1">
        <Grid Margin="18,0,12,0">
          <TextBlock x:Name="TxtTitle" Text="HISTORY" VerticalAlignment="Center" FontSize="14" FontWeight="SemiBold" Foreground="#0D4F68"/>
          <Button x:Name="BtnX" Content="&#x2715;" HorizontalAlignment="Right" VerticalAlignment="Center" Width="28" Height="24" Background="Transparent" BorderThickness="0" Foreground="#476173" FontSize="13"/>
        </Grid>
      </Border>
      <TextBox x:Name="TbHist" Grid.Row="1" IsReadOnly="True" TextWrapping="Wrap" BorderThickness="0" Background="Transparent" Foreground="#203849" FontSize="16" Padding="18,14,10,14" VerticalScrollBarVisibility="Auto"/>
    </Grid>
  </Border>
</Window>
'@
  $script:histWin = [Windows.Markup.XamlReader]::Parse($xaml)
  $script:histWin.FindName('TxtTitle').Text = $L.history
  $script:histWin.FindName('TbHist').Text = ($lines -join "`r`n`r`n")
  $script:histWin.FindName('Head').Add_MouseLeftButtonDown({ try { $script:histWin.DragMove() } catch {} })
  $script:histWin.FindName('BtnX').Add_Click({ try { $script:histWin.Close() } catch {} })
  $script:histWin.Show()
}

function Find-Child($el, [string]$name) {
  if ($null -eq $el) { return $null }
  try { if ($el.Name -eq $name) { return $el } } catch {}
  try {
    if ($el -is [System.Windows.Controls.Border] -and $el.Child) { return (Find-Child $el.Child $name) }
  } catch {}
  try {
    if ($el -is [System.Windows.Controls.ContentControl] -and $el.Content -is [System.Windows.UIElement]) {
      $r = Find-Child $el.Content $name
      if ($r) { return $r }
    }
  } catch {}
  try {
    if ($el -is [System.Windows.Controls.Panel]) {
      foreach ($c in $el.Children) {
        $r = Find-Child $c $name
        if ($r) { return $r }
      }
    }
  } catch {}
  return $null
}

function Build-Panel($win) {
  $raw = [IO.File]::ReadAllText((Join-Path $root 'ui\menu.xaml'), [Text.Encoding]::UTF8)
  $panel = [Windows.Markup.XamlReader]::Parse($raw)
  $script:panelXaml = $panel
  $panel.Visibility = 'Collapsed'

  $bg = $win.Content
  $grid = $null
  if ($bg -is [System.Windows.Controls.Border]) { $grid = $bg.Child }
  if (-not $grid) { $grid = $bg }
  if ($grid -is [System.Windows.Controls.Grid]) {
    $rc = [math]::Max(1, $grid.RowDefinitions.Count)
    $cc = [math]::Max(1, $grid.ColumnDefinitions.Count)
    [System.Windows.Controls.Grid]::SetRowSpan($panel, $rc)
    [System.Windows.Controls.Grid]::SetColumnSpan($panel, $cc)
    [void]$grid.Children.Add($panel)
  } else {
    Log-Line 'panel: no grid to host'
    return
  }

  $null = 0

  $bA = Find-Child $panel 'BtnSkinA'
  if ($bA) { $bA.Add_Click({ Switch-Skin 'a' }) }
  $bB = Find-Child $panel 'BtnSkinB'
  if ($bB) { $bB.Add_Click({ Switch-Skin 'b' }) }
  $bH = Find-Child $panel 'BtnHistory'
  if ($bH) { $bH.Add_Click({ if ($script:panelXaml) { $script:panelXaml.Visibility = 'Collapsed' }; try { Show-History } catch { Log-Line ('history err: ' + $_.Exception.Message) } }) }
  $bC = Find-Child $panel 'BtnCenter'
  if ($bC) {
    $bC.Add_Click({
        if ($script:panelXaml) { $script:panelXaml.Visibility = 'Collapsed' }
        $script:state.left = $null
        $script:state.top = $null
        Place-Window $script:win
        Save-State
      })
  }
  $bX = Find-Child $panel 'BtnExit'
  if ($bX) { $bX.Add_Click({ Exit-App }) }

  $sl = Find-Child $panel 'OpacitySlider'
  if ($sl) {
    $sl.Value = [math]::Round($script:opacity * 100)
    $sl.Add_ValueChanged({
        try {
          $v = [double]$this.Value
          $script:opacity = $v / 100.0
          Apply-Opacity
          $t = Find-Child $script:panelXaml 'TxtOpacity'
          if ($t) { $t.Text = ([int][math]::Round($v)).ToString() + '%' }
          if ($script:saveTimer) { $script:saveTimer.Stop(); $script:saveTimer.Start() }
        } catch {
          Log-Line ('slider err: ' + $_.Exception.Message)
        }
      })
  }

  $win.Add_MouseRightButtonUp({
      Log-Line ('rightclick panel=' + $(if ($script:panelXaml) { $script:panelXaml.Visibility } else { 'null' }))
      if (-not $script:panelXaml) { return }
      if ($script:panelXaml.Visibility -eq 'Visible') { $script:panelXaml.Visibility = 'Collapsed' }
      else {
        $s2 = Find-Child $script:panelXaml 'OpacitySlider'
        if ($s2) { $s2.Value = [math]::Round($script:opacity * 100) }
        $script:panelXaml.Visibility = 'Visible'
        Log-Line ('panel visible =' + $script:panelXaml.Visibility + ' size=' + $script:panelXaml.ActualWidth + 'x' + $script:panelXaml.ActualHeight + ' parent=' + $script:panelXaml.Parent.GetType().Name)
      }
    })
}

function Create-Window([string]$skinName) {
  $xamlPath = Join-Path $root ('ui\skin-' + $skinName + '.xaml')
  $raw = [IO.File]::ReadAllText($xamlPath, [Text.Encoding]::UTF8)
  $win = [Windows.Markup.XamlReader]::Parse($raw)

  if ($script:state.w -and $script:state.h) {
    try {
      $win.Width = [double]$script:state.w
      $win.Height = [double]$script:state.h
    } catch {}
  }
  $script:saveTimer = New-Object Windows.Threading.DispatcherTimer
  $script:saveTimer.Interval = [TimeSpan]::FromMilliseconds(400)
  $script:saveTimer.Add_Tick({
      try { $script:saveTimer.Stop(); Save-State } catch {}
    })

  if ($script:avatarBmp) {
    foreach ($an in @('Avatar', 'AvatarB', 'IdleAvatarB')) {
      $av = $win.FindName($an)
      if ($av) {
        $brush = New-Object Windows.Media.ImageBrush($script:avatarBmp)
        $brush.Stretch = 'UniformToFill'
        $av.Fill = $brush
      }
    }
  }

  Place-Window $win
  Log-Line ('win L=' + $win.Left + ' T=' + $win.Top + ' W=' + $win.Width + ' H=' + $win.Height)
  Build-Panel $win

  $win.Add_MouseLeftButtonDown({
      if ($script:panelXaml -and $script:panelXaml.Visibility -eq 'Visible') { return }
      if (Has-ButtonAncestor $_.OriginalSource) { return }
      try {
        # within 7px of an edge: resize handles it, do not drag the window
        $pt = $_.GetPosition($win)
        $edge = 7.0
        if ($pt.X -le $edge -or $pt.Y -le $edge) { return }
        if ($pt.X -ge ([double]$win.ActualWidth - $edge)) { return }
        if ($pt.Y -ge ([double]$win.ActualHeight - $edge)) { return }
        $script:win.DragMove()
        Save-State
      } catch {}
    })

  # 8-way edge resize using screen coords (Thumb loses capture when window moves)
  $win.Add_PreviewMouseLeftButtonDown({
      try {
        if ($script:panelXaml -and $script:panelXaml.Visibility -eq 'Visible') { return }
        if (Has-ButtonAncestor $_.OriginalSource) { return }
        $p = $_.GetPosition($win)
        $edge = 7.0
        $aw = [double]$win.ActualWidth
        $ah = [double]$win.ActualHeight
        $mode = ''
        if ($p.Y -le $edge) { $mode += 'N' }
        if ($p.Y -ge ($ah - $edge)) { $mode += 'S' }
        if ($p.X -le $edge) { $mode += 'W' }
        if ($p.X -ge ($aw - $edge)) { $mode += 'E' }
        if (-not $mode) { return }
        if ($script:idle) { Set-Idle $false }
        $c = [System.Windows.Forms.Cursor]::Position
        $script:rzMode = $mode
        $script:rzStart = @{}
        $script:rzStart.x = [double]$win.Left
        $script:rzStart.y = [double]$win.Top
        $script:rzStart.w = [double]$win.Width
        $script:rzStart.h = [double]$win.Height
        $script:rzStart.cx = [int]$c.X
        $script:rzStart.cy = [int]$c.Y
        $null = $win.CaptureMouse()
        $_.Handled = $true
      } catch { Log-Line ('rz down err: ' + $_.Exception.Message) }
    })
  $win.Add_PreviewMouseMove({
      try {
        if (-not $script:rzMode) { return }
        # Guard: if the left button was released outside the window we never got
        # MouseUp, so rzMode would stick and every later move would resize.
        if ([System.Windows.Input.Mouse]::LeftButton -ne [System.Windows.Input.MouseButtonState]::Pressed) {
          $script:rzMode = ''
          Log-Line 'rz abort: button no longer pressed'
          return
        }
        $c = [System.Windows.Forms.Cursor]::Position
        $s = $script:rzStart
        $dx = [double]([int]$c.X - [int]$s.cx)
        $dy = [double]([int]$c.Y - [int]$s.cy)
        $minW = 420.0
        $minH = 64.0
        $nw = [double]$s.w
        $nh = [double]$s.h
        $nl = [double]$s.x
        $nt = [double]$s.y
        if ($script:rzMode -match 'E') { $nw = [math]::Max($minW, [double]$s.w + $dx) }
        if ($script:rzMode -match 'W') { $nw = [math]::Max($minW, [double]$s.w - $dx); $nl = [double]$s.x + ([double]$s.w - $nw) }
        if ($script:rzMode -match 'S') { $nh = [math]::Max($minH, [double]$s.h + $dy) }
        if ($script:rzMode -match 'N') { $nh = [math]::Max($minH, [double]$s.h - $dy); $nt = [double]$s.y + ([double]$s.h - $nh) }
        $win.Width = $nw
        $win.Height = $nh
        $win.Left = $nl
        $win.Top = $nt
        $script:skinH = $nh
        $script:baseH = $nh
        $_.Handled = $true
      } catch {}
    })
  $win.Add_PreviewMouseLeftButtonUp({
      try {
        if (-not $script:rzMode) { return }
        $script:rzMode = ''
        $null = $win.ReleaseMouseCapture()
        $script:state.w = [math]::Round([double]$win.Width, 0)
        $script:state.h = [math]::Round([double]$win.Height, 0)
        $script:state.left = [math]::Round([double]$win.Left, 1)
        $script:state.top = [math]::Round([double]$win.Top, 1)
        Save-State
        Log-Line ('rz end w=' + $script:state.w + ' h=' + $script:state.h)
        $_.Handled = $true
      } catch { Log-Line ('rz up err: ' + $_.Exception.Message) }
    })
  $btnMin = $win.FindName('BtnMin')
  if ($btnMin) { $btnMin.Add_Click({ Hide-Window }) }
  $btnClose = $win.FindName('BtnClose')
  if ($btnClose) { $btnClose.Add_Click({ Exit-App }) }

  if ([double]$win.Height -gt 0) {
    $script:skinH = [double]$win.Height
    $script:baseH = [double]$win.Height
  }
  $win.Topmost = $true
  $win.ShowActivated = $false
  if ($null -eq $script:mX) { $script:mX = -9999.0; $script:mY = -9999.0 }
  # only expand the idle strip when the mouse really moves inside the window
  $win.Add_MouseMove({
      try {
        $p = $_.GetPosition($script:win)
        $dx = [math]::Abs($p.X - $script:mX)
        $dy = [math]::Abs($p.Y - $script:mY)
        $script:mX = $p.X
        $script:mY = $p.Y
        if ($script:idle -and ($dx + $dy) -gt 6) { Set-Idle $false }
      } catch {}
    })
  return $win
}

function Switch-Skin([string]$name) {
  if ($name -eq $script:skin) { return }
  $script:rzMode = ''
  if ($script:win) {
    $script:state.left = [math]::Round([double]$script:win.Left, 1)
    $script:state.top = [math]::Round([double]$script:win.Top, 1)
  }
  $script:skin = $name
  $old = $script:win
  $oldBottom = 0
  if ($old) { $oldBottom = [double]$old.Top + [double]$old.Height }
  $new = Create-Window $name
  if ($old -and $oldBottom -gt 0) {
    $new.Top = [math]::Max(0, $oldBottom - [double]$new.Height)
    $script:state.top = $new.Top
  }
  $script:win = $new
  $new.Show()
  Apply-Opacity
  if ($old) { $old.Close() }
  Save-State
  # keep since across skin switch
}

function Set-Idle([bool]$on) {
  if ($script:idle -eq $on) { return }
  $w = $script:win
  if (-not $w) { return }
  if ($on -and $script:panelXaml -and $script:panelXaml.Visibility -eq 'Visible') { return }
  try {
    $bottom = [double]$w.Top + [double]$w.Height
    $target = if ($on) { 34.0 } else { [double]$script:skinH }
    $bodyGrid = $w.FindName('BodyGrid')
    if ($bodyGrid) {
      if ($on) { $bodyGrid.Margin = '16,0,16,0' } else { $bodyGrid.Margin = '26,14,26,12' }
    }
    $footRow = $w.FindName('FootRow')
    if ($footRow) { if ($on) { $footRow.Height = 0 } else { $footRow.Height = 26 } }
    $headRow = $w.FindName('HeadRow')
    if ($headRow) { if ($on) { $headRow.Height = 0 } else { $headRow.Height = 22 } }
    $av = $w.FindName('Avatar')
    if ($av) {
      if ($on) { $av.Width = 24; $av.Height = 24; $av.Margin = '10,0,0,0' }
      else { $av.Width = 54; $av.Height = 54; $av.Margin = '24,0,0,0' }
    }
    $nr = $w.FindName('NameRowA')
    if ($nr) { if ($on) { $nr.Visibility = 'Collapsed' } else { $nr.Visibility = 'Visible' } }
    $ac = $w.FindName('AvatarCol')
    if ($ac) {
      if ($on) { $ac.Width = (New-Object System.Windows.GridLength 44) }
      else { $ac.Width = (New-Object System.Windows.GridLength 86) }
    }
    $axr = $w.FindName('AxisRow')
    if ($axr) { if ($on) { $axr.Visibility = 'Collapsed' } else { $axr.Visibility = 'Visible' } }
    $axd = $w.FindName('AxisRowDef')
    if ($axd) { if ($on) { $axd.Height = 0 } else { $axd.Height = 24 } }
    foreach ($bn in @('BtnMin', 'BtnClose')) {
      $bel = $w.FindName($bn)
      if ($bel) { if ($on) { $bel.Visibility = 'Collapsed' } else { $bel.Visibility = 'Visible' } }
    }
    $lb = $w.FindName('LiveBox')
    if ($lb) { if ($on) { $lb.Visibility = 'Collapsed' } else { $lb.Visibility = 'Visible' } }
    foreach ($n in @('HeadB', 'Counter', 'CounterB', 'Progress', 'ProgressB')) {
      $el = $w.FindName($n)
      if ($el) { if ($on) { $el.Visibility = 'Collapsed' } else { $el.Visibility = 'Visible' } }
    }
    if ($target -le 0) { return }
    $script:idle = $on
    if ($on) { $script:idleSw = [System.Diagnostics.Stopwatch]::StartNew() } else { $script:idleSw = $null }
    Log-Line ('idle -> ' + $on + ' h=' + $target + ' skinH=' + $script:skinH)
    $wa2 = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $w.Height = $target
    $w.Top = $bottom - $target
    if (($w.Top + $target) -gt [double]$wa2.Bottom) { $w.Top = [double]$wa2.Bottom - $target }
    if ($w.Top -lt [double]$wa2.Top) { $w.Top = [double]$wa2.Top }
    foreach ($n in @('CaptionPrev', 'CaptionNext')) {
      $el = $w.FindName($n)
      if ($el) { if ($on) { $el.Visibility = 'Collapsed' } else { $el.Visibility = 'Visible' } }
    }
    $body = $w.FindName('CaptionB')
    if (-not $body) { $body = $w.FindName('Caption') }
    $idleRow = $w.FindName('IdleRow')
    if (-not $idleRow) { $idleRow = $w.FindName('IdleRowB') }
    if ($idleRow) {
      if ($on) {
        $tail = [string]$script:lastText
        if ([string]::IsNullOrWhiteSpace($tail)) { $tail = $L.idle }
        if ($tail.Length -gt 46) { $tail = ([char]0x2026) + $tail.Substring($tail.Length - 46) }
        $it = $w.FindName('IdleText')
        if (-not $it) { $it = $w.FindName('IdleTextB') }
        if ($it) { $it.Text = $tail }
        $ic = $w.FindName('IdleCounter')
        if (-not $ic) { $ic = $w.FindName('IdleCounterB') }
        if ($ic) {
          if ($script:total -gt 0) { $ic.Text = ('{0:00} / {1:00}' -f [int]$script:index, [int]$script:total) }
          else { $ic.Text = '' }
        }
        $idleRow.Visibility = 'Visible'
        if ($body) { $body.Visibility = 'Collapsed' }
      } else {
        $idleRow.Visibility = 'Collapsed'
        if ($body) { $body.Visibility = 'Visible' }
      }
    }
    if ($body -and -not $idleRow) {
      if ($on) {
        if (-not $script:bodyFont) { $script:bodyFont = [double]$body.FontSize }
        $t = [string]$script:lastText
        if ($t.Length -gt 42) { $t = ([char]0x2026) + $t.Substring($t.Length - 42) }
        if ([string]::IsNullOrWhiteSpace($t)) { $t = $L.idle }
        $body.Text = $t
        $body.FontSize = 13
        $body.TextWrapping = 'NoWrap'
        $body.TextTrimming = 'CharacterEllipsis'
        $body.TextAlignment = 'Center'
        $body.VerticalAlignment = 'Center'
        $body.Visibility = 'Visible'
      } else {
        if ($script:bodyFont) { $body.FontSize = $script:bodyFont }
        $body.Text = [string]$script:lastText
        $body.TextWrapping = 'Wrap'
        $body.TextAlignment = 'Left'
        $body.VerticalAlignment = 'Center'
        $body.Visibility = 'Visible'
      }
    }
    foreach ($n in @('CaptionPrev', 'CaptionNext')) {
      $el = $w.FindName($n)
      if ($el -and -not $on) { $el.Visibility = 'Visible' }
    }
    if (-not $on) { $script:state.top = [math]::Round([double]$w.Top, 1); Save-State }
  } catch { Log-Line ('idle err: ' + $_.Exception.Message) }
}

function Fmt-Time([double]$t) {
  if ($t -lt 0) { $t = 0 }
  $m = [int][math]::Floor($t / 60)
  $sec = $t - $m * 60
  return ('{0:00}:{1:00.0}' -f $m, $sec)
}

$script:breaks = @()
$script:axFill = $null
$script:axCursor = $null

function Init-Wave {
  $w = $script:win
  if (-not $w) { return }
  $wave = $w.FindName('Wave')
  if (-not $wave) { return }
  $wave.Children.Clear()
  $hs = @(6, 12, 8, 17, 10, 14, 7, 19, 9, 13, 6, 11, 8, 15, 7, 16, 9, 12)
  $i = 0
  foreach ($h in $hs) {
    $r = New-Object System.Windows.Shapes.Rectangle
    $r.Width = 3
    $r.Height = $h
    $r.Margin = New-Object System.Windows.Thickness(0, 0, 2, 0)
    $r.VerticalAlignment = 'Center'
    $alpha = 0x58 + (($i % 5) * 0x20)
    if ($alpha -gt 0xC0) { $alpha = 0xC0 }
    $r.Fill = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb($alpha, 0x17, 0x6B, 0x91))
    [void]$wave.Children.Add($r)
    $i++
  }
}

function Init-Axis {
  $w = $script:win
  if (-not $w) { return }
  $ax = $w.FindName('Axis')
  if (-not $ax) { return }
  $ax.Children.Clear()
  $script:axFill = $null
  $script:axCursor = $null
  $avail = [double]$ax.ActualWidth
  if ($avail -lt 20) { $avail = 20 }

  $base = New-Object System.Windows.Shapes.Rectangle
  $base.Height = 1
  $base.Width = $avail
  $base.Fill = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(0x38, 0x28, 0x69, 0x8A))
  [System.Windows.Controls.Canvas]::SetTop($base, 11)
  [void]$ax.Children.Add($base)

  foreach ($b in $script:breaks) {
    $p = [double]$b
    if ($p -lt 0.02 -or $p -gt 0.98) { continue }
    $tk = New-Object System.Windows.Shapes.Rectangle
    $tk.Width = 1
    $tk.Height = 10
    $tk.Fill = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(0xC8, 0x28, 0x69, 0x8A))
    [System.Windows.Controls.Canvas]::SetLeft($tk, [math]::Round($p * ($avail - 1), 1))
    [System.Windows.Controls.Canvas]::SetTop($tk, 6)
    [void]$ax.Children.Add($tk)
  }

  $fill = New-Object System.Windows.Shapes.Rectangle
  $fill.Height = 2
  $fill.Width = 0
  $fill.Fill = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(0xFF, 0x17, 0x6B, 0x91))
  [System.Windows.Controls.Canvas]::SetTop($fill, 11)
  [void]$ax.Children.Add($fill)
  $script:axFill = $fill

  $cur = New-Object System.Windows.Shapes.Rectangle
  $cur.Width = 2
  $cur.Height = 12
  $cur.Fill = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(0xFF, 0x17, 0x6B, 0x91))
  [System.Windows.Controls.Canvas]::SetTop($cur, 6)
  [void]$ax.Children.Add($cur)
  $script:axCursor = $cur
}

function Update-Progress {
  $w = $script:win
  if (-not $w) { return }
  $bar = $w.FindName('Progress')
  if (-not $bar) { $bar = $w.FindName('ProgressB') }
  $cnt = $w.FindName('Counter')
  if (-not $cnt) { $cnt = $w.FindName('CounterB') }
  $tm = $w.FindName('TimeText')
  $spd = $w.FindName('SpeedText')
  $ax = $w.FindName('Axis')

  $dur = [double]$script:duration
  $elapsed = 0.0
  if ($script:sw) { $elapsed = $script:sw.Elapsed.TotalSeconds }
  if ($dur -gt 0 -and $script:live -and $elapsed -gt $dur) { $elapsed = $dur }
  $ratio = 0.0
  if ($dur -gt 0) {
    $ratio = [math]::Min(1.0, $elapsed / $dur)
    if (-not $script:live) { $ratio = 1.0 }
  }

  if ($ax -and $script:axFill) {
    $avail = [double]$ax.ActualWidth
    if ($avail -lt 20) { $avail = 20 }
    $script:axFill.Width = [math]::Round($ratio * $avail, 1)
    if ($script:axCursor) {
      [System.Windows.Controls.Canvas]::SetLeft($script:axCursor, [math]::Round($ratio * ($avail - 2), 1))
      if ($script:live) { $script:axCursor.Visibility = 'Visible' } else { $script:axCursor.Visibility = 'Collapsed' }
    }
  }

  if ($tm) {
    if ($dur -gt 0) { $tm.Text = ((Fmt-Time $elapsed) + ' / ' + (Fmt-Time $dur)) }
    else { $tm.Text = ((Fmt-Time 0) + ' / ' + (Fmt-Time 0)) }
  }
  if ($spd) { $spd.Text = ('{0:0.00}x' -f [double]$script:speed) }

  if ($cnt) {
    if ($script:total -gt 0) { $cnt.Text = ('{0:00} / {1:00}' -f [int]$script:index, [int]$script:total) }
    else { $cnt.Text = '' }
  }

  if ($bar) {
    $avail = [double]$w.ActualWidth - 80
    if ($avail -lt 60) { $avail = 60 }
    if ($dur -gt 0) { $bar.Width = $ratio * $avail }
    else {
      $tot = [int]$script:total
      $idx = [int]$script:index
      if ($tot -gt 0) {
        $bar.Width = ([math]::Max(0, [math]::Min(1.0, ([double]$idx / [double]$tot)))) * $avail
      }
    }
  }
}

function Show-Caption($data) {
  $w = $script:win
  if (-not $w) { return }
  $cap = $w.FindName('Caption')
  if (-not $cap) { $cap = $w.FindName('CaptionB') }
  if ($cap) { $cap.Text = [string]$data.text }

  $pv = $w.FindName('CaptionPrev')
  if ($pv) { $pv.Text = [string]$data.prev }
  $nx = $w.FindName('CaptionNext')
  if ($nx) { $nx.Text = [string]$data.next }

  $script:total = [int]$data.total
  $script:index = [int]$data.index
  $script:duration = [double]$data.duration
  $script:lastText = [string]$data.text
  $script:breaks = @()
  if ($null -ne $data.breaks) { $script:breaks = @($data.breaks) }
  $script:speed = 1.12
  if ($null -ne $data.speed) { $script:speed = [double]$data.speed }
  $script:sw = [System.Diagnostics.Stopwatch]::StartNew()
  $script:live = $true
  try { $script:idleTimer.Stop() } catch {}
  Set-Idle $false
  Log-Line ('caption# ' + $script:index + '/' + $script:total + ' dur=' + $script:duration + ' seq=' + $data.seq + ' pid=' + $PID + ' sw=' + ($null -ne $script:sw))
  Set-Live $true
  try {
    $w.UpdateLayout()
    Init-Wave
    Init-Axis
  } catch { Log-Line ('axis init err: ' + $_.Exception.Message) }
  Update-Progress
  if (-not $w.IsVisible) { } # keep hidden if the user minimised it
$script:lastShown = [DateTime]::Now
  # Size to content in one step: no intermediate shrink, so it does not flicker.
  try {
    $wa = [System.Windows.SystemParameters]::WorkArea
    $baseH = [double]$script:baseH
    if ($baseH -le 0) { $baseH = 118.0 }
    $w.UpdateLayout()
    $root = $w.Content
    $need = 0.0
    if ($root) {
      $root.Measure((New-Object System.Windows.Size([double]$w.ActualWidth, [double]::PositiveInfinity)))
      $need = [double]$root.DesiredSize.Height
    }
    $nh = [math]::Max($baseH, $need + 2)
    $maxH = [double]$wa.Height - 40
    if ($nh -gt $maxH) { $nh = $maxH }
    if ([math]::Abs($nh - [double]$w.Height) -gt 0.5) {
      $bottom = [double]$w.Top + [double]$w.Height
      $newTop = $bottom - $nh
      if ($newTop -lt ([double]$wa.Top + 4)) {
        $newTop = [double]$wa.Top + 4
        $nh = $bottom - $newTop
      }
      $w.Height = $nh
      $w.Top = $newTop
      Log-Line ('caption size h=' + [math]::Round($nh, 1) + ' need=' + [math]::Round($need, 1))
    }
  } catch { Log-Line ('caption size err: ' + $_.Exception.Message) }
}

# --- tray icon -------------------------------------------------------------
$script:tray = $null
function Init-Tray {
  $ni = New-Object System.Windows.Forms.NotifyIcon
  try {
    $bmp = New-Object System.Drawing.Bitmap($avatarPath)
    $hIcon = $bmp.GetHicon()
    $ni.Icon = [System.Drawing.Icon]::FromHandle($hIcon)
  } catch {
    $ni.Icon = [System.Drawing.SystemIcons]::Application
  }
  $ni.Text = 'dsh-mmy-ttslive'
  $ni.Visible = $true
  $ni.Add_MouseDoubleClick({ Show-Window })
  $cm = New-Object System.Windows.Forms.ContextMenuStrip
  $itShow = $cm.Items.Add($L.show)
  $itShow.Add_Click({ Show-Window })
  $itHist = $cm.Items.Add($L.history)
  $itHist.Add_Click({ Show-History })
  [void]$cm.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
  $itExit = $cm.Items.Add($L.close)
  $itExit.Add_Click({ Exit-App })
  $ni.ContextMenuStrip = $cm
  $script:tray = $ni
}

# --- boot ------------------------------------------------------------------
$script:win = Create-Window $script:skin
$script:win.Show()
Apply-Opacity
Init-Tray
$script:since = 0
try {
  $st = Invoke-RestMethod -Uri ('http://127.0.0.1:' + $script:port + '/state') -TimeoutSec 1
  if ($st.seq) { $script:since = [int]$st.seq }
} catch {}
try {
  $h = Invoke-RestMethod -Uri ('http://127.0.0.1:' + $script:port + '/history?limit=1') -TimeoutSec 1
  $arr = @($h.items)
  if ($arr.Count -gt 0) {
    $last = $arr[$arr.Count - 1]
    if ($last.text) { $script:lastText = [string]$last.text }
  }
} catch {}
$script:duration = 0.0
$script:index = 0
$script:total = 0
$script:live = $false
$script:captionAt = $null
$script:sw = $null
$script:idle = $false
$script:bodyFont = 0.0
$script:idleTimer = New-Object Windows.Threading.DispatcherTimer
$script:idleTimer.Interval = [TimeSpan]::FromSeconds(3)
$script:idleTimer.Add_Tick({ try {
    $script:idleTimer.Stop()
    if ($script:live) { return }
    # keep expanded while the mouse is over the window (avoids collapse/expand flicker)
    if ($script:win -and $script:win.IsMouseOver) { $script:idleTimer.Start(); return }
    Set-Idle $true
  } catch {} })
$script:lastShown = [DateTime]::Now
$script:idleSw = $null
$script:idleTick = New-Object Windows.Threading.DispatcherTimer
$script:idleTick.Interval = [TimeSpan]::FromMilliseconds(500)
$script:idleTick.Add_Tick({ try {
    if (-not $script:idle -or -not $script:idleSw -or -not $script:win) { return }
    $h = $script:win.FindName('IdleHint')
    if (-not $h) { $h = $script:win.FindName('IdleHintB') }
    if ($h) { $h.Text = ($L.idlePrefix + (' {0:0.0}s' -f $script:idleSw.Elapsed.TotalSeconds)) }
  } catch {} })
$script:idleTick.Start()

# 心跳：say.js 靠这个文件判断「服务活着但窗口被关了」，好重新拉起
$script:aliveFile = Join-Path $root '.cache\window-alive.txt'
$script:aliveTimer = New-Object Windows.Threading.DispatcherTimer
$script:aliveTimer.Interval = [TimeSpan]::FromSeconds(5)
$script:aliveTimer.Add_Tick({ try { [IO.File]::WriteAllText($script:aliveFile, [DateTime]::Now.ToString('o')) } catch {} })
$script:aliveTimer.Start()
try { [IO.File]::WriteAllText($script:aliveFile, [DateTime]::Now.ToString('o')) } catch {}
Set-Live $false

$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(220)
$timer.Add_Tick({
    try {
      $uri = 'http://127.0.0.1:' + $script:port + '/next?since=' + $script:since
      $r = Invoke-RestMethod -Uri $uri -TimeoutSec 1
      if ($r.has) {
        $script:since = [int]$r.seq
        if ([string]::IsNullOrWhiteSpace([string]$r.text) -or (-not $r.live)) {
          # Playback finished: keep the last line on screen, just dim the LIVE dot.
          if ($script:live) {
            $script:live = $false
            Update-Progress
            try { $script:idleTimer.Stop(); $script:idleTimer.Start() } catch {}
          }
          Set-Live $false
        } else {
          Show-Caption $r
        }
      }
      if ($script:live -and $script:sw -and ([double]$script:duration) -gt 0) {
        if ($script:sw.Elapsed.TotalSeconds -gt (([double]$script:duration) + 1.5)) {
          $script:live = $false
          Log-Line ('auto-done elapsed=' + [math]::Round($script:sw.Elapsed.TotalSeconds,2))
          Update-Progress
          if (-not $script:idleTimer.IsEnabled) { $script:idleTimer.Start() }
        }
      }
      if (-not $script:live -and -not $script:idle -and $script:idleTimer -and -not $script:idleTimer.IsEnabled) {
        $script:idleTimer.Start()
      }
      if ($script:live) { Update-Progress }
    } catch {
      try {
        $logFile = Join-Path $root '.cache\ttslive.log'
        $line = ((Get-Date).ToString('HH:mm:ss') + ' tick: ' + $_.Exception.Message + "`r`n")
        [IO.File]::AppendAllText($logFile, $line, (New-Object Text.UTF8Encoding($false)))
      } catch {}
    }
  })
$timer.Start()

[System.Windows.Threading.Dispatcher]::Run() | Out-Null
