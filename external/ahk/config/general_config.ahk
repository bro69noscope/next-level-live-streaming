#Include getpath.ahk

SplitPath(A_LineFile, , &_ahkConfigDir)
_ahkConfigDir := RealPath(_ahkConfigDir)
StreamingRepoPath := NormalizePath(_ahkConfigDir "\..\..\..") "\"

; at what percent of the window bottom height do we place the mouse cursor on window
; activation. (100 tends to be too low to be able to scroll most ui with mouse events.)
DefaultMousePercent := 99.7

ObsExe := "obs64.exe"
StreamerbotExe := "Streamer.bot.exe"

ObsPortableString := "Portable Mode - Profile: "
FtpPortableString := "Portable Mode - Profile: ftp"
VcamPortableString := "Portable Mode - Profile: vcam"

StreamingProgramsPath := "C:\Users\ville\myfiles\streaming-programs\"

ObsProductionRemoteDebugArgs :=
  " --remote-debugging-port=9222 --remote-allow-origins=http://localhost:9222"

ObsFtpRemoteDebugArgs :=
  " --remote-debugging-port=9223 --remote-allow-origins=http://localhost:9223"

StreamingRepoServerName := "BRO_NLLS_MAIN_SERVER"
