#Include window-helpers.ahk
#Include config\general_config.ahk

FindObsWindow(portable_profile := "") {
  for win in WinGetList("ahk_exe" ObsExe) {
    try
      title := WinGetTitle(win)
    catch
      continue

    if !portable_profile {
      if !InStr(title, ObsPortableString)
        return win
    }
    else if InStr(title, ObsPortableString portable_profile)
      return win
  }
  return 0
}

MoveObsProduction(direction, activate) {
  hwnd := FindObsWindow()

  if !hwnd {
    ToolTip "No production Obs window found to move."
    SetTimer(() => ToolTip(), -2000)
    return
  }

  SetWinDelay 0

  if WinGetMinMax(hwnd) != 0
    WinRestore(hwnd)

  WinGetPos(, , &w, &h, hwnd)
  MonitorGetWorkArea(PickMonitor(direction), &mLeft, &mTop)

  WinMove(mLeft, mTop, w, h, hwnd)
  EnsureFullscreen(hwnd)

  if activate
    WinActivate(hwnd)
}

MoveObsFtp(direction, activate) {
  hwnd := FindObsWindow("ftp")

  if !hwnd {
    ToolTip "No Ftp Obs window found to move."
    SetTimer(() => ToolTip(), -2000)
    return
  }

  SetWinDelay 0

  if WinGetMinMax(hwnd) != 0
    WinRestore(hwnd)

  WinGetPos(, , &w, &h, hwnd)
  MonitorGetWorkArea(PickMonitor(direction), &mLeft, &mTop)

  WinMove(mLeft, mTop, w, h, hwnd)
  EnsureFullscreen(hwnd)

  if activate
    WinActivate(hwnd)
}


ActivateStreamFeedApp(launchPosition := "left", activate := true) {
  idMethod := () => WinExist("Activity Feed ahk_exe StreamFeedApp.exe")
  hwnd := idMethod()

  Reposition(hwnd) {
    if WinGetMinMax(hwnd) != 1
      WinRestore(hwnd)

    MonitorGetWorkArea(PickMonitor(launchPosition), &mLeft, &mTop, &mRight, &mBottom)
    WinMove(mLeft, mTop, mRight - mLeft, mBottom - mTop, hwnd)
    EnsureFullscreen(hwnd)
    if activate
      WinActivate(hwnd)
  }

  if hwnd {
    if activate
      WinActivate(hwnd)
  }
  else {
    Run("dotnet run", StreamingRepoPath "external\StreamFeedApp", "Min")
    ActivateWhenReady(idMethod, 8000, Reposition, , activate)
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

ActivateObsProduction(moveChat := false, activate := true) {
  hwnd := 0
  FindObsWindow() {
    for win in WinGetList("ahk_exe obs64.exe ahk_class Qt6111QWindowIcon") {
      if !WinExist("ahk_id " win)
        continue
      try
        title := WinGetTitle(win)
      catch
        continue
      if !InStr(title, ObsPortableString)
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
    if activate
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
    ActivateWhenReady(idMethod, 7000, MinMaxOnCreation, , activate)
  }
}

ActivateObsPortable(profile, moveChat := false, activate := true) {
  idMethod := () => FindObsWindow(profile)

  hwnd := idMethod()
  if hwnd {
    if activate
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
    ActivateWhenReady(idMethod, 3000, , , activate)
  }
  else if profile == "vcam" {
    dir := StreamingProgramsPath "obs-studio-portable-vcam\obs-studio\bin\64bit"

    exe := dir . "\obs64.exe"

    Run('"' exe '"', dir)
    ActivateWhenReady(idMethod, 3000, , , activate)
  }
  else
    MsgBox "No Obs portable profile specified and no matching window found."
}
