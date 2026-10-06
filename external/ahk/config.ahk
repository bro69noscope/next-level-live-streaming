SplitPath(A_LineFile, , &_ahkDir)
StreamingRepoPath := _ahkDir "\..\..\"

ObsExe := "obs64.exe"
StreamerbotExe := "Streamer.bot.exe"
FtpPortableString := "Portable Mode - Profile: ftp"
VcamPortableString := "Portable Mode - Profile: vcam"

StreamingProgramsPath := "C:\Users\ville\myfiles\streaming-programs\"

ObsProductionRemoteDebugArgs :=
  " --remote-debugging-port=9222 --remote-allow-origins=http://localhost:9222"

ObsFtpRemoteDebugArgs :=
  " --remote-debugging-port=9223 --remote-allow-origins=http://localhost:9223"

StreamingRepoServerName := "MY SERVER"
