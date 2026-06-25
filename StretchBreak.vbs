' Тихий запуск StretchBreak в фоне без окна консоли (берёт путь от своего расположения)
Set fso = CreateObject("Scripting.FileSystemObject")
Set sh = CreateObject("WScript.Shell")
folder = fso.GetParentFolderName(WScript.ScriptFullName)
ps1 = folder & "\StretchBreak.ps1"
sh.Run "powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & ps1 & """", 0, False
