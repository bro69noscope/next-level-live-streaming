EnsureFullscreen(hwnd) {
  if WinGetMinMax(hwnd) != 1
    WinMaximize(hwnd)
}

GetMonitorAt(x, y) {
  loop MonitorGetCount() {
    MonitorGetWorkArea(A_Index, &l, &t, &r, &b)
    if (x >= l && x < r && y >= t && y < b)
      return A_Index
  }
  return MonitorGetPrimary()
}

ActivateWhenReady(checkFn, timeout := 2000, callback := "") {
  end := A_TickCount + timeout
  while (A_TickCount < end) {
    if (hwnd := checkFn()) {
      WinActivate(hwnd)
      if callback
        callback(hwnd)
      return true
    }
    Sleep 50
  }
  return false
}

ActivateOrRun(idMethod, runCommand, timeout := 3000, onFound := "") {
  hwnd := idMethod()
  if hwnd {
    WinActivate(hwnd)
    if onFound
      onFound(hwnd)
    return true
  }
  Run(runCommand)
  return ActivateWhenReady(idMethod, timeout, onFound)
}
