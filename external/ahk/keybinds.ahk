; ==================================================
; Single source of truth for hardcoded global hotkeys.
; Shared by:
;   - external/ahk/main.ahk (this repo)
;   - Bro's dotfiles: windows/autohotkey/utils-script/main.ahk (via junction)
;
; ==================================================

Keybinds := Map(
  ; --- streaming scripts (registered in external/ahk/main.ahk)
  "NllsActivateMainServer", "^!+F24",
  ; --- utils-script (registered in dotfiles main.ahk)
  "ToggleMousePosOverlay", "^!+Home",
  "ClipAndOpenNvimScratch", "^\",
  "LaunchDeadLockMovementScript", "^!+F12",
  "MoveActiveWindowRight", "^!+Right",
  "MoveActiveWindowLeft", "^!+Left",
  "SmallPageScrollUp", "!PgUp",
  "SmallPageScrollDown", "!PgDn",
  "PageScrollUp", "^PgUp",
  "PageScrollDown", "^PgDn",
  "ActivateLeaderKey", "$^Space"
)

; Keychron Q3 only: source key -> key it is remapped to
KeychronQ3Remaps := Map(
  "CapsLock", "Esc",
  "Esc", "CapsLock",
  "!j", "Down",
  "!k", "Up",
  "!h", "Left",
  "!l", "Right"
)
