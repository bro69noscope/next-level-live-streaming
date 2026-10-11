; Used for resolving to the path in which the code calling RealPath with the path
; parameter set to A_LineFile is located. Used since code in `main.ahk` can, and is
; meant to, be executed from an external location.

RealPath(path) {
  h := DllCall("CreateFileW", "str", path, "uint", 0, "uint", 7, "ptr", 0
    , "uint", 3, "uint", 0x02000000, "ptr", 0, "ptr")
  if (h = -1)
    throw OSError()
  len := DllCall("GetFinalPathNameByHandleW", "ptr", h, "ptr", 0, "uint", 0, "uint", 0,
    "uint")
  buf := Buffer(len * 2)
  DllCall("GetFinalPathNameByHandleW", "ptr", h, "ptr", buf, "uint", len, "uint", 0)
  DllCall("CloseHandle", "ptr", h)
  return RegExReplace(StrGet(buf), "^\\\\\?\\")
}

NormalizePath(path) {
  len := DllCall("GetFullPathNameW", "str", path, "uint", 0, "ptr", 0, "ptr", 0, "uint"
  )
  buf := Buffer(len * 2)
  DllCall("GetFullPathNameW", "str", path, "uint", len, "ptr", buf, "ptr", 0, "uint")
  return StrGet(buf)
}
