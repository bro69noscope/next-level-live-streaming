"""Thin CLI for validating the hotkey registry and generating hotkeys_map.ahk.

Usage:
    python generate_streaming_hotkeys.py
"""

import sys

from src.streaming_config.global_hotkeys.hotkeys import (
    HotkeyConfigError,
    load_hotkeys,
    validate_hotkeys,
    write_ahk_hotkeys,
)
from src.utils.helpers import construct_script_name
from src.utils.logging_utils import setup_logger

SCRIPT_NAME = construct_script_name(__file__)
logger = setup_logger(SCRIPT_NAME)


def main() -> None:
    """Validate the merged hotkey registry, then write the AHK include."""
    try:
        mappings = load_hotkeys()
        validate_hotkeys(mappings)
    except HotkeyConfigError as e:
        logger.error("%s", e)
        print(e, file=sys.stderr)
        sys.exit(1)

    out_path, count = write_ahk_hotkeys(mappings)
    print(f"Wrote {count} ahk hotkeys -> {out_path}")


if __name__ == "__main__":
    main()
