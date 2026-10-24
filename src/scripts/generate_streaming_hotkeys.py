"""Thin CLI for validating the hotkey registry and generating hotkeys_map.ahk.

Usage:
    python generate_streaming_hotkeys.py
"""

import sys

from src.streaming_config.global_hotkeys.hotkeys import (
    HOTKEYS_SOURCE,
    load_hotkeys,
    validate_hotkeys,
    write_ahk_hotkeys,
)


def main() -> None:
    """Validate streaming_hotkeys.json5, then write the AHK include."""
    if not HOTKEYS_SOURCE.exists():
        print(f"Source file not found: {HOTKEYS_SOURCE}", file=sys.stderr)
        sys.exit(1)

    mappings = load_hotkeys()

    try:
        validate_hotkeys(mappings)
    except ValueError as e:
        print(e, file=sys.stderr)
        sys.exit(1)

    out_path, count = write_ahk_hotkeys(mappings)
    print(f"Wrote {count} ahk hotkeys -> {out_path}")


if __name__ == "__main__":
    main()
