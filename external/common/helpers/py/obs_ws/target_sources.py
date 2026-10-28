"""Typed access to config/obs_ws_target_sources.json5."""

from typing import TypedDict, cast

import json5
from src.core.constants import PROJECT_CONFIG_DIR_PATH


class ObsSourceRef(TypedDict):
    """Which OBS instance (ports.json5 "obs" key) hosts a source, and where."""

    json5_cfg_key: str
    scene: str
    source: str


class ObsWsTargetSourcesConfig(TypedDict):
    """Top-level shape of config/obs_ws_target_sources.json5."""

    instance: dict[str, ObsSourceRef]


OBS_WS_TARGET_SOURCES_CFG_PATH = PROJECT_CONFIG_DIR_PATH / "obs_ws_target_sources.json5"
with OBS_WS_TARGET_SOURCES_CFG_PATH.open(encoding="utf-8") as file:
    OBS_WS_TARGET_SOURCES = cast(
        "ObsWsTargetSourcesConfig",
        json5.load(file),  # pyright: ignore[reportUnknownMemberType]
    )["instance"]
