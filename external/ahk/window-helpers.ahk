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

GetMonitorsByX() {
  mons := []
  Loop MonitorGetCount() {
    MonitorGetWorkArea(A_Index, &l)
    mons.Push({ left: l, idx: A_Index })
  }

  Loop mons.Length - 1 {
    i := A_Index + 1
    cur := mons[i]
    j := i - 1
    while (j >= 1 && mons[j].left > cur.left) {
      mons[j + 1] := mons[j]
      j--
    }
    mons[j + 1] := cur
  }
  return mons
}

PickMonitor(position) {
  mons := GetMonitorsByX()
  switch position {
    case "left": return mons[1].idx
    case "center": return mons[Ceil(mons.Length / 2)].idx
    case "right": return mons[mons.Length].idx
    default: throw ValueError("Unknown position: " position)
  }
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
