import json
import os
from pathlib import Path

from get_streamdeck_path import get_streamdeck_base_path
from src.config.settings import PROJECT_ROOT_PATH

PRETTIER_PATH = (
    Path(os.environ["LOCALAPPDATA"]) / "nvim-data" / "mason" / "bin" / "prettier.cmd"
)


REPOSITORY_SDECK_ROOT = PROJECT_ROOT_PATH / "external" / "streamdeck"
GENERATE_ICONS_ROOT = REPOSITORY_SDECK_ROOT / "utils" / "generate-icons"
VCDATA_SDECK_ROOT = REPOSITORY_SDECK_ROOT / "version-control" / "vcdata"
LOCAL_SDECK_ROOT = get_streamdeck_base_path(
    REPOSITORY_SDECK_ROOT,
    GENERATE_ICONS_ROOT,
)
SDECK_ICONS_ROOT = VCDATA_SDECK_ROOT / "binaries" / "icons"

SDECK_MANIFEST_FILENAMES = {
    VCDATA_SDECK_ROOT: "manifest.vcs-template.json",
    LOCAL_SDECK_ROOT: "manifest.json",
}

MARKER_FORMAT = json.loads(
    (REPOSITORY_SDECK_ROOT / "shared" / "marker-format.json").read_text()
)

STREAMDECK_DEVICE_SUFFIXES = ["_4x8", "_3x5"]
SYMLINK_PREFIX = "lnk__"
GENERATED_PREFIX = "gen__"
ACTIVE_SUFFIX = "__active"
INACTIVE_SUFFIX = "__inactive"

IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".gif", ".svg"}
CATEGORY_COLORS_MAP = {
    "scenes": (255, 0, 0),  # red *
    "sources": (255, 165, 0),  # orange *
    "streamerbot-actions": (0, 255, 255),  # cyan
    "websocket-msg": (173, 216, 230),  # light blue
    "system-open": (0, 100, 0),  # dark green
    "profiles": (255, 105, 180),  # pink
    "hotkeys": (0, 0, 128),  # navy
    "multi-action": (255, 255, 0),  # yellow
}
