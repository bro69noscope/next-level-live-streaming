"""Constants related to connections and subprocesses."""

from typing import TypedDict, cast

import json5

from src.config.settings import PROJECT_ROOT_PATH


class EndpointConfig(TypedDict):
    """Host, port, protocol, and token for a single connection endpoint."""

    host: str
    port: int
    protocol: str


class StreamerbotEnvironmentConfig(TypedDict):
    """A Streamer.bot environment (production/ftp), with its own port integrations."""

    streamerbot: EndpointConfig
    integrations: dict[str, EndpointConfig]


class SubprocessConfig(TypedDict):
    """Port and token for an internal subprocess socket server."""

    port: int


class PySubProcessesPortsConfig(TypedDict):
    """Port configuration for Streamer.bot and managed subprocesses."""

    streamerbot: dict[str, StreamerbotEnvironmentConfig]
    subprocesses: dict[str, SubprocessConfig]


PORTS_CFG_PATH = PROJECT_ROOT_PATH / "config" / "ports.json5"
with PORTS_CFG_PATH.open(encoding="utf-8") as file:
    PORTS = cast(
        "PySubProcessesPortsConfig",
        json5.load(file),  # pyright: ignore[reportUnknownMemberType]
    )

    STREAMERBOT_WS_URL = (
        f"ws://"
        f"{PORTS['streamerbot']['production']['streamerbot']['host']}:"
        f"{PORTS['streamerbot']['production']['streamerbot']['port']}/"
    )
STOP_SUBPROCESS_MESSAGE = "stop$subprocess"
SUBPROCESSES_PORTS = {name: cfg["port"] for name, cfg in PORTS["subprocesses"].items()}
