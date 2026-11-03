Set sh = CreateObject("WScript.Shell")
sh.CurrentDirectory = "D:\DSH-MMYMOE\dsh-mmy-ttslive"
sh.Run """D:\DSH-MMYMOE\dsh-mmy-ttslive\node_modules\electron\dist\electron.exe"" --no-sandbox ""D:\DSH-MMYMOE\dsh-mmy-ttslive\test-min.js""", 0, False
