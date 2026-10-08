#Include window-helpers.ahk
#Include config.ahk

MoveObsProduction(direction := "right") {
  hwnd := 0
  for win in WinGetList("ahk_exe obs64.exe") {
    title := WinGetTitle(win)
    if !InStr(title, "Portable Mode") {
      hwnd := win
      break
    }
  }

  if !hwnd {
    ToolTip "No production Obs window found to move."
    SetTimer(() => ToolTip(), -2000)
    return
  }

  targetX := direction = "right" ? 2560 : direction = "center" ? 0 : x

  WinGetPos(&x, &y, &w, &h, hwnd)
  WinMove(targetX, y, w, h, hwnd)
  EnsureFullscreen(hwnd)
  WinActivate(hwnd)
}

ActivateStreamFeedApp() {
  idMethod := () => WinExist("Activity Feed ahk_exe StreamFeedApp.exe")
  hwnd := idMethod()
  Reposition(hwnd) {
    if WinGetMinMax(hwnd) != 1
      WinRestore(hwnd)

    targetX := -2300
    monIdx := GetMonitorAt(targetX, 0)
    MonitorGetWorkArea(monIdx, &mLeft, &mTop, &mRight, &mBottom)

    width := (mRight - mLeft) // 1
    height := mBottom - mTop
    WinMove(mRight - width, mTop, width, height, hwnd)
    EnsureFullscreen(hwnd)
    WinActivate(hwnd)
  }
  if hwnd {
    Reposition(hwnd)
  }
  else {
    Run("dotnet run", StreamingRepoPath "external\StreamFeedApp", "Min")
    ActivateWhenReady(idMethod, 3000, Reposition)
  }
}

ActivateStreamFeedAppDebug() {
  idMethod := () => WinExist(
    "DevTools - appassets.local/stream-feed.html ahk_exe msedgewebview2.exe")
  hwnd := idMethod()
  if hwnd
    WinActivate(hwnd)
  else {
    hwnd2 := WinExist("Activity Feed ahk_exe StreamFeedApp.exe")
    if hwnd2 {
      WinActivate
      Send "{F12}"
      ActivateWhenReady(idMethod, 3000)
    }
  }
}

ActivateObsProduction(moveChat := false) {
  hwnd := 0
  FindObsWindow() {
    for win in WinGetList("ahk_exe obs64.exe ahk_class Qt6111QWindowIcon") {
      if !WinExist("ahk_id " win)
        continue
      try
        title := WinGetTitle(win)
      catch
        continue
      if !InStr(title, "Portable Mode")
        return win
    }
    return 0
  }
  idMethod := () => FindObsWindow()

  MinMaxOnCreation(hwnd) {
    ; fixes weird false maximized state
    WinMinimize(hwnd)
    WinMaximize(hwnd)
  }

  hwnd := idMethod()
  if hwnd {
    WinActivate(hwnd)

    if not moveChat
      return

    if WinExist("Chat ahk_exe Streamer.bot.exe") {
      WinGetPos(&x, &y, &w, &h, hwnd)
      chat := WinExist("Chat ahk_exe Streamer.bot.exe")
      WinActivate(chat)
      WinMove(x + 20, y + 110, 800, 1230, chat)
    }
  } else {
    dir := "C:\Program Files\obs-studio\bin\64bit"
    exe := dir . "\obs64.exe"
    Run('"' exe '"' ObsProductionRemoteDebugArgs, dir)
    ActivateWhenReady(idMethod, 7000, MinMaxOnCreation)
  }
}

ActivateObsPortable(profile := "", moveChat := false) {
  FindObsPortableWindow(profile := "") {
    for win in WinGetList("ahk_exe obs64.exe") {
      title := WinGetTitle(win)
      if InStr(title, "Portable Mode" . (profile ? " - Profile: " profile : ""))
        return win
    }
    return 0
  }
  idMethod := () => FindObsPortableWindow(profile)

  hwnd := idMethod()
  if hwnd {
    WinActivate(hwnd)

    if not moveChat
      return

    if WinExist("Chat ahk_exe Streamer.bot.exe") {
      WinGetPos(&x, &y, &w, &h, hwnd)
      chat := WinExist("Chat ahk_exe Streamer.bot.exe")
      WinActivate(chat)
      WinMove(x + 20, y + 110, 800, 1230, chat)
    }
  }
  else if profile == "ftp" {
    dir := StreamingProgramsPath "obs-studio-portable-ftp\obs-studio\bin\64bit"

    exe := dir . "\obs64.exe"

    Run('"' exe '" ' ObsFtpRemoteDebugArgs, dir)
    ActivateWhenReady(idMethod, 3000)
  }
  else if profile == "vcam" {
    dir := StreamingProgramsPath "obs-studio-portable-vcam\obs-studio\bin\64bit"

    exe := dir . "\obs64.exe"

    Run('"' exe '"', dir)
    ActivateWhenReady(idMethod, 3000)
  }
  else
    MsgBox "No Obs portable profile specified and no matching window found."
}
