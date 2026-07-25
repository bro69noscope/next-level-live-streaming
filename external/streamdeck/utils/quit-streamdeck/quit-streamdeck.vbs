Set objFSO = CreateObject("Scripting.FileSystemObject")
scriptDir = objFSO.GetParentFolderName(WScript.ScriptFullName)
ps1Path = scriptDir & "\quit-streamdeck.ps1"

Set objShell = CreateObject("WScript.Shell")
objShell.Run _
    "powershell.exe " & _
    "-WindowStyle Hidden " & _
    "-ExecutionPolicy Bypass " & _
    "-File """ & ps1Path & """", _
    0, False
