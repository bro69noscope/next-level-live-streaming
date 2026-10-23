#Include general_config.ahk

PortsFile := StreamingRepoPath "config\ports.json5"

; Returns the port as a string. Example: GetPort("repository", "python") returns "50000".
; Each key is searched in order, and the port must be a direct property of the last block.
GetPort(keys*) {
  if !FileExist(PortsFile)
    throw Error("file not found: " . PortsFile)

  pattern := "s)"
  path := ""
  for key in keys {
    last := (A_Index = keys.Length)
    pattern .= "\b" . key . "\s*:\s*\{" . (last ? "[^{}]*?" : ".*?")
    path .= (A_Index > 1 ? "." : "") . key
  }
  pattern .= "\bport\s*:\s*(\d+)"

  if !RegExMatch(FileRead(PortsFile), pattern, &m)
    throw Error(path . " port not found in " . PortsFile)
  return m[1]
}
