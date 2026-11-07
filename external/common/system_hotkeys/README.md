Central registry of every hotkey bound system-wide across the apps here: ahk, obs, streamdeck,
bro_dotfiles .. etc.

- `hotkeys.manual.json5`: hand-edited. Comments are preserved.
- `hotkeys.generated.json5`: written by scripts only. Never edit by hand.

Both are merged and checked for id and hotkey clashes by:
`python -m src.scripts.generate_streaming_hotkeys`, which writes:
`external/ahk/config/hotkeys_map.ahk` (the `HK` map for owners `ahk` and `bro_dotfiles`).
