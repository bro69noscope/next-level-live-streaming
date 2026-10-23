#Include libs\websocket.ahk
#Include stream-apps.ahk
#Include logger.ahk
#Include config\general_config.ahk
#Include config\ports.ahk

WsLogFile := "logs\ws.log"
TrimLogFile(WsLogFile, 200000)
LogBlank(WsLogFile)

msgboxShown := false

wsCommands := Map(
  "MoveObsProductionRight", () => MoveObsProduction("right"),
  "MoveObsProductionCenter", () => MoveObsProduction("center"),
  "ActivateStreamFeedApp", () => ActivateStreamFeedApp(),
  "ActivateObsProduction", () => ActivateObsProduction(true),
  "ActivateObsPortableFtp", () => ActivateObsPortable("ftp", true)
)

NoticeError(msg) {
  global msgboxShown
  if !msgboxShown {
    MsgBox(msg, "Error", "Iconx T8")
    msgboxShown := true
  }
  LogError(msg, WsLogFile)
}

GetRelayPort() {
  try
    return GetPort("repository", "python")
  catch as e {
    NoticeError(e.Message)
    throw e
  }
}

ws := ""
Connect()

Connect() {
  global ws
  try
    ws := WebSocket("ws://127.0.0.1:" GetRelayPort() "/ahk/listen", {
      message: OnWsMessage,
      close: (*) => SetTimer(Connect, -2000)
    })
  catch as e {
    LogError("ws connect failed: " e.Message, WsLogFile)
    SetTimer(Connect, -2000)
  }
}

OnWsMessage(this, msg) {
  LogInfo("ws msg: '" msg "'", WsLogFile)
  if wsCommands.Has(msg)
    wsCommands[msg]()
  else
    LogWarn("ws unknown command: '" msg "'", WsLogFile)
}
