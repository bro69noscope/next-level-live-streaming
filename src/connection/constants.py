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

    streamerbot_ws: EndpointConfig
    integrations: dict[str, EndpointConfig]


class SubprocessConfig(TypedDict):
    """Port and token for an internal subprocess socket server."""

    port: int


class RepositoryStaticEntry(TypedDict):
    """A static file server entry under repository (e.g. browser_overlays_static)."""

    host: str
    port: int
    paths: dict[str, str]


class RepositoryConfig(TypedDict):
    """Config for repo-level dev tooling servers (static file servers, etc.)."""

    browser_overlays_static: RepositoryStaticEntry


class PySubProcessesPortsConfig(TypedDict):
    """Port configuration for Streamer.bot and managed subprocesses."""

    streamerbot: dict[str, StreamerbotEnvironmentConfig]
    subprocesses: dict[str, SubprocessConfig]
    repository: RepositoryConfig


PORTS_CFG_PATH = PROJECT_ROOT_PATH / "config" / "ports.json5"
with PORTS_CFG_PATH.open(encoding="utf-8") as file:
    PORTS = cast(
        "PySubProcessesPortsConfig",
        json5.load(file),  # pyright: ignore[reportUnknownMemberType]
    )

    STREAMERBOT_WS_URL = (
        f"ws://"
        f"{PORTS['streamerbot']['production']['streamerbot_ws']['host']}:"
        f"{PORTS['streamerbot']['production']['streamerbot_ws']['port']}/"
    )
STOP_SUBPROCESS_MESSAGE = "stop$subprocess"
SUBPROCESSES_PORTS = {name: cfg["port"] for name, cfg in PORTS["subprocesses"].items()}
BROWSER_OVERLAYS_STATIC = PORTS["repository"]["browser_overlays_static"]
