"""Typed access to config/obs_ws_target_sources.json5."""

from typing import TypedDict, cast

import json5
from src.config.settings import PROJECT_ROOT_PATH


class ObsSourceRef(TypedDict):
    """Which OBS instance (ports.json5 "obs" key) hosts a source, and its name."""

    obs_instance_key_in_ports_json5: str
    browser_source_name_in_obs: str


class ObsWsTargetSourcesConfig(TypedDict):
    """Top-level shape of config/obs_ws_target_sources.json5."""

    alerts_overlays: dict[str, ObsSourceRef]


OBS_WS_TARGET_SOURCES_CFG_PATH = (
    PROJECT_ROOT_PATH / "config" / "obs_ws_target_sources.json5"
)
with OBS_WS_TARGET_SOURCES_CFG_PATH.open(encoding="utf-8") as file:
    OBS_WS_TARGET_SOURCES = cast(
        "ObsWsTargetSourcesConfig",
        json5.load(file),  # pyright: ignore[reportUnknownMemberType]
    )

ALERTS_OVERLAYS_OBS_WS_TARGET_SOURCES = OBS_WS_TARGET_SOURCES["alerts_overlays"]
