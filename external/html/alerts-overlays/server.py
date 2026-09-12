"""cant use use local file setting on obs, it dont work good."""  # noqa: INP001

from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import override

from external.common.helpers.py.obs_ws.client import (
    ObsWebSocketError,
    refresh_browser_source,
)
from external.common.helpers.py.obs_ws.target_sources import (
    ALERTS_OVERLAYS_OBS_WS_TARGET_SOURCES,
)
from src.config.settings import PROJECT_ROOT_PATH
from src.connection.constants import ALERTS_OVERLAYS_STATIC, PORTS

SCRIPT_DIR = Path(__file__).resolve().parent

EXTERNAL_MOUNTS: dict[str, Path] = {
    "mounted_config": PROJECT_ROOT_PATH / "config",
    "mounted_node_modules": PROJECT_ROOT_PATH / "node_modules",
    "mounted_js_helpers": PROJECT_ROOT_PATH
    / "external"
    / "common"
    / "helpers"
    / "js"
    / "dist",
}


class ScopedHandler(SimpleHTTPRequestHandler):
    """Serves SCRIPT_DIR, with EXTERNAL_MOUNTS transparently mapped in."""

    @override
    def translate_path(self, path: str) -> str:
        clean_path = path.split("?", 1)[0]
        for mount_name, real_dir in EXTERNAL_MOUNTS.items():
            prefix = f"/{mount_name}/"
            if clean_path.startswith(prefix):
                rel = clean_path[len(prefix) :]
                return str((real_dir / rel).resolve())
        return super().translate_path(path)


def _build_urls() -> dict[str, str]:
    base = f"http://localhost:{ALERTS_OVERLAYS_STATIC['port']}"
    return {
        env: f"{base}/{rel_path}?env={env}"
        for env, rel_path in ALERTS_OVERLAYS_STATIC["served_paths"].items()
    }


def _refresh_obs_alert_sources() -> None:
    """Reload the alerts browser source in every running OBS instance."""
    print("OBS alert sources (config/obs_ws_target_sources.json5):")
    for env, source in ALERTS_OVERLAYS_OBS_WS_TARGET_SOURCES.items():
        instance_key = source["obs_instance_key_in_ports_json5"]
        source_name = source["browser_source_name_in_obs"]
        obs = PORTS["obs"][instance_key]
        target = f"{source_name} in obs.{instance_key} @ {obs['host']}:{obs['port']}"
        try:
            refresh_browser_source(obs["host"], obs["port"], source_name)
        except OSError as e:
            print(f"  {env:12s} {target}  [SKIPPED: OBS not reachable: {e}]")
        except ObsWebSocketError as e:
            print(f"  {env:12s} {target}  [FAILED: {e}]")
        else:
            print(f"  {env:12s} {target}  [REFRESHED]")
    print()


def main() -> None:
    """Print server info and serve forever."""
    urls = _build_urls()

    print(f"Repo root:  {PROJECT_ROOT_PATH}")
    print(f"Serving:    {SCRIPT_DIR} on port {ALERTS_OVERLAYS_STATIC['port']}")
    print("Mounts:")
    for mount_name, real_dir in EXTERNAL_MOUNTS.items():
        status = "OK" if real_dir.exists() else "MISSING"
        print(f"  /{mount_name}/  ->  {real_dir}  [{status}]")
    print()
    for env, url in urls.items():
        print(f"  {env:12s} {url}")
    print()

    handler = partial(ScopedHandler, directory=str(SCRIPT_DIR))
    server = ThreadingHTTPServer(
        (ALERTS_OVERLAYS_STATIC["host"], ALERTS_OVERLAYS_STATIC["port"]), handler
    )
    _refresh_obs_alert_sources()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down.")
        server.server_close()


if __name__ == "__main__":
    main()
