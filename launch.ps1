# Idempotent launcher for the caption overlay (server + WPF window).
# Safe to call repeatedly: only starts what is missing.
$root = 'D:\DSH-MMYMOE\dsh-mmy-ttslive'
$node = 'D:\Program Files\nodejs\node.exe'
$pwsh7 = Join-Path $env:LOCALAPPDATA 'Microsoft\PowerShell\7\pwsh.exe'
$ps = 'powershell.exe'
if (Test-Path $pwsh7) { $ps = $pwsh7 }
$log  = Join-Path $root '.cache\launch.log'

function Log([string]$m) {
  try {
    $dir = Split-Path $log
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    ('{0} {1}' -f (Get-Date -Format 'HH:mm:ss'), $m) | Add-Content -Path $log -Encoding UTF8
  } catch {}
}

$health = $false
try {
  $r = Invoke-WebRequest -Uri 'http://127.0.0.1:7788/health' -TimeoutSec 1 -UseBasicParsing
  if ($r.StatusCode -eq 200) { $health = $true }
} catch {}

if (-not $health) {
  try {
    Start-Process -FilePath $node -ArgumentList 'server.js' -WorkingDirectory $root -WindowStyle Hidden
    Log 'started server.js'
  } catch { Log ('server start failed: ' + $_.Exception.Message) }
  Start-Sleep -Milliseconds 700
} else {
  Log 'server already up'
}

$ui = Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='pwsh.exe'" -ErrorAction SilentlyContinue |
  Where-Object { $_.CommandLine -match 'ttslive\.ps1' -and $_.CommandLine -notmatch 'launch\.ps1|Get-CimInstance' }

if (-not $ui) {
  try {
    Start-Process -FilePath $ps -WindowStyle Hidden -ArgumentList @(
      '-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden',
      '-File', (Join-Path $root 'ttslive.ps1')
    )
    Log ('started ttslive.ps1 via ' + $ps)
  } catch { Log ('window start failed: ' + $_.Exception.Message) }
} else {
  Log ('window already up pid=' + ($ui | Select-Object -First 1).ProcessId)
}
