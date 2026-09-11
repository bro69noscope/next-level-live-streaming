"""Ensure the cairo native library required by cairosvg is installed.

cairosvg needs ``cairo.dll`` / ``libcairo-2.dll`` on PATH.
"""

import os
import shutil
import subprocess
import sys
from pathlib import Path

CAIRO_DLL_NAMES = ("cairo.dll", "libcairo-2.dll")  # Windows GTK and conda names
CONDA_BIN = Path(os.environ.get("USERPROFILE", "")) / "miniforge3" / "Library" / "bin"


def cairo_dll_found() -> bool:
    path_dirs = os.environ.get("PATH", "").split(os.pathsep)
    return any(
        (Path(d) / name).is_file() for d in path_dirs if d for name in CAIRO_DLL_NAMES
    )


def ensure_cairo() -> int:
    if cairo_dll_found():
        print("libcairo already present.")
        return 0

    print("libcairo-2.dll not found.")
    if shutil.which("conda") is None:
        print(
            "conda not found. Install Miniforge first:\n"
            "  winget install --id CondaForge.Miniforge3 -e\n"
            "then restart your shell and re-run `sdeck-ensure-cairo`.",
            file=sys.stderr,
        )
        return 1

    print("Installing cairo via conda-forge...")
    subprocess.run(["conda", "install", "-c", "conda-forge", "cairo", "-y"], check=True)
    print(
        f'Cairo installed. Ensure "{CONDA_BIN}" is on your PATH, then restart your shell.'
    )
    return 0


def main() -> None:
    raise SystemExit(ensure_cairo())


if __name__ == "__main__":
    main()
