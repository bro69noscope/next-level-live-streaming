#Requires AutoHotkey v2.0
#SingleInstance Force
#Include ..\..\config\ports.ahk
#Include ..\..\config\hotkeys_map.ahk

try
  sbUrl := "http://127.0.0.1:"
    . GetPort("streamerbot", "ftp", "streamerbot_http")
    . "/DoAction"
catch as e {
  MsgBox(e.Message, "ports.json5", "Iconx")
  return
}

SB_ACTION_NAME := "set relevant window capture"

Hotkey(HK["hk_capture_win_by_title"], (*) => CaptureWindow(WinExist("A"), 0))
Hotkey(HK["hk_capture_win_by_exe"], (*) => CaptureWindow(WinExist("A"), 2))

CaptureWindow(hwnd, prio) {
  if !hwnd {
    MsgBox "No active window found."
    return
  }

  exe := WinGetProcessName(hwnd)

  if (exe = "ApplicationFrameHost.exe")
    prio := 0

  body := '
  (
  {
    "action": {"name": @action},
    "args": {
      "title": @title,
      "class": @class,
      "exe": @exe,
      "priority": @prio
    }
  }
  )'
  body := StrReplace(body, "@action", JsonStr(SB_ACTION_NAME))
  body := StrReplace(body, "@title", JsonStr(WinGetTitle(hwnd)))
  body := StrReplace(body, "@class", JsonStr(WinGetClass(hwnd)))
  body := StrReplace(body, "@exe", JsonStr(exe))
  body := StrReplace(body, "@prio", prio)

  try {
    http := ComObject("WinHttp.WinHttpRequest.5.1")
    http.Open("POST", sbUrl, false)
    http.SetRequestHeader("Content-Type", "application/json")
    http.Send(body)
  } catch as e {
    MsgBox("Streamer.bot request failed", e.Message)
  }
}

JsonStr(s) => '"' . JsonEsc(s) . '"'

JsonEsc(s) {
  s := StrReplace(s, "\", "\\")
  s := StrReplace(s, '"', '\"')
  s := StrReplace(s, "`r", "\r")
  s := StrReplace(s, "`n", "\n")
  s := StrReplace(s, "`t", "\t")
  return s
}
