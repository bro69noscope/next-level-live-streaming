#Include config\general_config.ahk

EnsureFullscreen(hwnd) {
  if WinGetMinMax(hwnd) != 1
    WinMaximize(hwnd)
}

MoveMouseToWindowBottom(hwnd, heightPercent) {
  ; per-monitor-v2: physical pixels on every monitor, also with mixed DPI
  DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")

  ; visible frame, without the invisible resize borders that WinGetPos includes
  DWMWA_EXTENDED_FRAME_BOUNDS := 9
  rect := Buffer(16)
  DllCall("dwmapi\DwmGetWindowAttribute", "ptr", hwnd, "uint",
    DWMWA_EXTENDED_FRAME_BOUNDS,
    "ptr", rect, "uint", 16)
  left := NumGet(rect, 0, "int"), top := NumGet(rect, 4, "int")
  right := NumGet(rect, 8, "int"), bottom := NumGet(rect, 12, "int") ; right, bottom: exclusive

  x := (left + right) // 2
  ; heightPercent can be a float, e.g. 99.5
  y := Min(top + Round((bottom - top) * heightPercent / 100), bottom - 1)

  ; SetCursorPos takes physical screen coordinates, MouseMove clamps on other monitors
  DllCall("SetCursorPos", "int", x, "int", y)
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

ActivateWhenReady(checkFn, opts := {}) {
  o := WithDefaults(opts, {
    timeout: 3000,
    onFound: "",
    isLaunch: false,
    activate: true,
    mousePercent: DefaultMousePercent
  })

  end := A_TickCount + o.timeout
  while (A_TickCount < end) {
    if (hwnd := checkFn()) {
      if o.activate
        WinActivate(hwnd)
      if o.isLaunch
        try ; silent failing usually means an attempt to transform an elevated window failed
          CenterIfWindowed(hwnd)
      if o.onFound
        o.onFound.Call(hwnd)
      if o.activate
        MoveMouseToWindowBottom(hwnd, o.mousePercent)
      return true
    }
    Sleep 50
  }
  return false
}

WithDefaults(opts, defaults) {
  for name, value in opts.OwnProps() {
    if !defaults.HasOwnProp(name)
      throw ValueError("Unknown option: " name)
    defaults.%name% := value
  }
  return defaults
}

ActivateOrRun(idMethod, runCommand, opts := {}) {
  o := WithDefaults(opts, {
    timeout: 3000,
    onFound: "",
    activate: true,
    mousePercent: DefaultMousePercent
  })

  hwnd := idMethod()
  if hwnd {
    if o.activate
      WinActivate(hwnd)
    if o.onFound
      o.onFound.Call(hwnd)
    if o.activate
      MoveMouseToWindowBottom(hwnd, o.mousePercent)
    return true
  }
  Run(runCommand)
  o.isLaunch := true
  return ActivateWhenReady(idMethod, o)
}
