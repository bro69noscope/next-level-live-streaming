import os
import subprocess
from pathlib import Path

STREAMDECK_ROOT_PATH_STR = "_STREAMDECK_ROOT_PATH"


def get_streamdeck_base_path(repo_sdeck_root: Path) -> Path:
    PS_PATHS_SCRIPT = (
        repo_sdeck_root / "version-control" / "dotsource-streamdeck-paths.ps1"
    )
    value = os.environ.get(STREAMDECK_ROOT_PATH_STR)
    if value:
        return Path(value)

    result = subprocess.run(
        ["powershell", "-NoProfile", "-Command", f". '{PS_PATHS_SCRIPT}'"],
        capture_output=True,
        text=True,
        check=True,
    )
    value = result.stdout.strip()
    if not value:
        raise RuntimeError(
            f"{STREAMDECK_ROOT_PATH_STR} not set after running {PS_PATHS_SCRIPT} "
            f"(stderr: {result.stderr})"
        )

    os.environ[STREAMDECK_ROOT_PATH_STR] = value
    return Path(value)
