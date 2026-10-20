EnsureFullscreen(hwnd) {
  if WinGetMinMax(hwnd) != 1
    WinMaximize(hwnd)
}

GetTargetX(direction) {
  MonitorGet(MonitorGetPrimary(), &l, , &r)

  switch direction {
    case "right": return r
    case "center": return l
    default: throw ValueError("Unknown direction", , direction)
  }
}

GetMonitorAt(x, y) {
  loop MonitorGetCount() {
    MonitorGetWorkArea(A_Index, &l, &t, &r, &b)
    if (x >= l && x < r && y >= t && y < b)
      return A_Index
  }
  return MonitorGetPrimary()
}

CenterIfWindowed(hwnd) {
  if WinGetMinMax(hwnd) != 0
    return
  WinGetPos(&x, &y, &w, &h, hwnd)
  MonitorGetWorkArea(GetMonitorAt(x + w // 2, y + h // 2), &l, &t, &r, &b)
  WinMove(l + (r - l - w) // 2, t + (b - t - h) // 2, , , hwnd)
}

ActivateWhenReady(checkFn, timeout := 2000, onFound := "", isLaunch := false) {
  end := A_TickCount + timeout
  while (A_TickCount < end) {
    if (hwnd := checkFn()) {
      WinActivate(hwnd)
      if isLaunch
        try ; silent failing usually means an attempt to transform an elevated window failed
          CenterIfWindowed(hwnd)
      if onFound
        onFound(hwnd)
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
  return ActivateWhenReady(idMethod, timeout, onFound, isLaunch := true)
}
