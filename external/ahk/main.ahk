#Requires AutoHotkey v2.0
#SingleInstance Force
#WinActivateForce
SetWorkingDir A_ScriptDir
Persistent

DirExist("logs") || DirCreate("logs")

#Include libs\websocket.ahk
#Include logger.ahk
#Include window-helpers.ahk
#Include stream-apps.ahk
#Include ws-client.ahk
