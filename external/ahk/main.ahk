#Requires AutoHotkey v2.0
#SingleInstance Force
#WinActivateForce
SetWorkingDir A_ScriptDir
Persistent

DirExist("logs") || DirCreate("logs")

#Include libs\websocket.ahk
#Include logger.ahk
#Include window-helpers.ahk
#Include keybinds.ahk
#Include stream-apps.ahk
#Include ws-client.ahk
#Include scripts\capture-window-obs\main.ahk

Hotkey(HK["nlls_hk__activate_main_server"], (*) => ActivateNllsMainServer())
