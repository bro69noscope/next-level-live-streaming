#Requires AutoHotkey v2.0
#SingleInstance Force

SetTimer Timeout, -2000

Timeout() {
  MsgBox "Timed out waiting for Streamer.bot window."
  ExitApp
}

before := Map()

for hwnd in WinGetList("ahk_exe Streamer.bot.exe") {
  before[hwnd] := true
}

loop {
  Sleep 50

  for hwnd in WinGetList("ahk_exe Streamer.bot.exe") {
    if !before.Has(hwnd) {
      WinActivate(hwnd)
      Sleep 20
      Send "{Tab}" ; to focus the input field
      ExitApp
    }
  }
}
