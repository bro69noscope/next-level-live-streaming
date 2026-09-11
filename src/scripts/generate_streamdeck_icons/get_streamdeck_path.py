import json
import subprocess
from pathlib import Path

from .perf import timed

_CACHE_FILENAME = ".streamdeck-base-path.json"


def _cache_path(generate_icons_root: Path) -> Path:
    return generate_icons_root / _CACHE_FILENAME


def get_streamdeck_base_path(repo_sdeck_root: Path, generate_icons_root: Path) -> Path:
    cache_file = _cache_path(generate_icons_root)
    if cache_file.is_file():
        with timed("get_streamdeck_base_path (cache)"):
            data = json.loads(cache_file.read_text())
            return Path(data["sdeck_base_path"])

    ps_paths_script = (
        repo_sdeck_root / "version-control" / "dotsource-streamdeck-paths.ps1"
    )

    with timed("get_streamdeck_base_path (powershell)"):
        result = subprocess.run(
            [
                "powershell",
                "-NoProfile",
                "-Command",
                f". '{ps_paths_script}'; Write-Output $env:_STREAMDECK_ROOT_PATH",
            ],
            capture_output=True,
            text=True,
            check=True,
        )

    value = result.stdout.strip()
    if not value:
        raise RuntimeError(
            f"Failed to resolve sdeck base path from {ps_paths_script} "
            f"(stderr: {result.stderr})"
        )

    cache_file.write_text(json.dumps({"sdeck_base_path": value}))
    return Path(value)
