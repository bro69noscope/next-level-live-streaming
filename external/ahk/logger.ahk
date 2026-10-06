LogLevels := Map("DEBUG", 1, "INFO", 2, "WARN", 3, "ERROR", 4)
LogMinLevel := "INFO"

LogLevel(level, msg, logFile) {
  if LogLevels[level] < LogLevels[LogMinLevel]
    return
  ts := FormatTime(, "yyyy-MM-dd HH:mm:ss")
  try FileAppend(ts " [" level "] " msg "`n", logFile)
}

LogBlank(logFile) {
  try FileAppend("`n", logFile)
}

LogDebug(msg, logFile) => LogLevel("DEBUG", msg, logFile)
LogInfo(msg, logFile) => LogLevel("INFO", msg, logFile)
LogWarn(msg, logFile) => LogLevel("WARN", msg, logFile)
LogError(msg, logFile) => LogLevel("ERROR", msg, logFile)

TrimLogFile(path, maxBytes) {
  if !FileExist(path) || FileGetSize(path) <= maxBytes
    return

  content := FileRead(path)
  half := StrLen(content) // 2
  cut := InStr(content, "`n", , half)
  trimmed := cut ? SubStr(content, cut + 1) : SubStr(content, half)

  FileDelete(path)
  FileAppend(trimmed, path)
}
