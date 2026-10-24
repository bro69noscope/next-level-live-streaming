"""Hotkey registry: load, validate, generate the AHK include."""

import re
from pathlib import Path
from typing import cast, get_args

import json5
from src.config.settings import PROJECT_ROOT_PATH
from src.streaming_config.types import HotkeyMapping, HotkeyOwner

HOTKEYS_SOURCE = (
    PROJECT_ROOT_PATH
    / "external"
    / "common"
    / "system_hotheys"
    / "streaming_hotkeys.json5"
)
HOTKEYS_AHK_OUTPUT = (
    PROJECT_ROOT_PATH / "external" / "ahk" / "config" / "hotkeys_map.ahk"
)

_MODIFIERS = "#^!+"  # canonical order: Super, Ctrl, Alt, Shift
_IGNORED_PREFIXES = "~$*"
_ID_RE = re.compile(r"[a-z][a-z0-9_]*")
_VALID_OWNERS = frozenset(get_args(HotkeyOwner))


def _normalize(hotkey: str) -> str:
    chars = [c for c in hotkey if c not in _IGNORED_PREFIXES]
    mods = {c for c in chars if c in _MODIFIERS}
    key = "".join(c for c in chars if c not in _MODIFIERS).lower()
    return "".join(m for m in _MODIFIERS if m in mods) + key


def load_hotkeys(source: Path = HOTKEYS_SOURCE) -> list[HotkeyMapping]:
    with source.open("r", encoding="utf-8") as f:
        data = cast(
            "dict[str, list[HotkeyMapping]]",
            json5.load(f),  # pyright: ignore[reportUnknownMemberType]
        )
    return data["mappings"]


def validate_hotkeys(mappings: list[HotkeyMapping]) -> None:
    """Raise ValueError listing every id, owner, or hotkey problem found."""
    errors: list[str] = []
    seen_ids: set[str] = set()
    seen_combos: dict[str, str] = {}

    for m in mappings:
        mid = m.get("id", "")
        if not _ID_RE.fullmatch(mid):
            errors.append(f"bad or missing id in {m}")
            continue
        if mid in seen_ids:
            errors.append(f"duplicate id '{mid}'")
        seen_ids.add(mid)

        if m.get("owner") not in _VALID_OWNERS:
            errors.append(
                f"'{mid}' has invalid owner {m.get('owner')!r}; "
                f"expected one of {sorted(_VALID_OWNERS)}"
            )

        hotkey = m.get("hotkey", "")
        if not hotkey:
            errors.append(f"'{mid}' has no hotkey")
            continue
        combo = _normalize(hotkey)
        if combo in seen_combos:
            errors.append(f"hotkey clash '{hotkey}': '{mid}' vs '{seen_combos[combo]}'")
        seen_combos[combo] = mid

    if errors:
        raise ValueError("\n".join(errors))


def write_ahk_hotkeys(
    mappings: list[HotkeyMapping],
    out_path: Path = HOTKEYS_AHK_OUTPUT,
) -> tuple[Path, int]:
    """Write the AHK `HK` id->hotkey map. Returns (path, entry_count)."""
    ahk = [m for m in mappings if m["owner"] == "ahk"]
    rows = ",\n".join(f'  "{m["id"]}", "{m["hotkey"]}"' for m in ahk)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(
        "; GENERATED from streaming_hotkeys.json5 - do not edit\n"
        f"HK := Map(\n{rows}\n)\n",
        encoding="utf-8",
    )
    return out_path, len(ahk)
