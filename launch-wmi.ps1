$ErrorActionPreference = 'Stop'
$exe = 'D:\DSH-MMYMOE\dsh-mmy-ttslive\node_modules\electron\dist\electron.exe'
$app = 'D:\DSH-MMYMOE\dsh-mmy-ttslive\test-min.js'
$flags = '--no-sandbox --disable-gpu --enable-logging --log-file=D:\DSH-MMYMOE\.cache\electron.log --v=1'
$cmd = '"' + $exe + '" ' + $flags + ' "' + $app + '"'
$r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $cmd; CurrentDirectory = 'D:\DSH-MMYMOE\dsh-mmy-ttslive' }
Write-Output ("ReturnValue=" + $r.ReturnValue + " ProcessId=" + $r.ProcessId)
