# Idempotent launcher for the caption overlay (server + WPF window).
# Safe to call repeatedly: only starts what is missing.
# Paths are relative to this script; override node.exe with TTSLIVE_NODE.
$root = $PSScriptRoot
$log  = Join-Path $root '.cache\launch.log'

function Log([string]$m) {
  try {
    $dir = Split-Path $log
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    ('{0} {1}' -f (Get-Date -Format 'HH:mm:ss'), $m) | Add-Content -Path $log -Encoding UTF8
  } catch {}
}

# node.exe: TTSLIVE_NODE first, then PATH, then the old hard-coded location.
$node = $env:TTSLIVE_NODE
if (-not $node -or -not (Test-Path $node)) {
  $cmd = Get-Command node.exe -ErrorAction SilentlyContinue
  if ($cmd) { $node = $cmd.Source }
}
if (-not $node -or -not (Test-Path $node)) {
  $fallback = 'D:\Program Files\nodejs\node.exe'
  if (Test-Path $fallback) { $node = $fallback }
}
if (-not $node) {
  Log 'node.exe not found; set TTSLIVE_NODE or put node in PATH'
  exit 1
}

$pwsh7 = Join-Path $env:LOCALAPPDATA 'Microsoft\PowerShell\7\pwsh.exe'
$ps = 'powershell.exe'
if (Test-Path $pwsh7) { $ps = $pwsh7 }

# Probe the port the server wrote last time, then fall back to 7788.
$port = 7788
$portFile = Join-Path $root '.cache\ttslive-port.txt'
if (Test-Path $portFile) {
  $raw = ([IO.File]::ReadAllText($portFile)).Trim()
  if ($raw -match '^\d+$') { $port = [int]$raw }
}

$health = $false
try {
  $r = Invoke-WebRequest -Uri ('http://127.0.0.1:' + $port + '/health') -TimeoutSec 1 -UseBasicParsing
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
