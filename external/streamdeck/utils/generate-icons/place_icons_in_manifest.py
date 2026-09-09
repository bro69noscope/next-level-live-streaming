"""find_scene_icons.py

Given a directory, find generated icon files named like
gen__scene_lounge-icon__active.png / __inactive.png, extract the scene
name (e.g. "scene_lounge"), and check whether that scene name appears
under a "scene" key anywhere in the manifest.
"""

import json
import os
import re
import subprocess
import sys
from pathlib import Path

from src.utils.logging_utils import setup_logger

LOG_DIR = Path(__file__).resolve().parent / "logs"
logger = setup_logger("place_icons_in_manifest", log_dir=LOG_DIR)

MANIFEST_PATH = Path(
    r"C:\Users\ville\myfiles\git-repos\woertsposzibllen4me\external\streamdeck"
    r"\version-control\vcdata\08F1CB5E-CA39-47F0-9924-8D181F508A8C.sdProfile"
    r"\Profiles\F564D696-1142-4902-BA97-8EE0DA773BB9\manifest.vcs-template.json"
)

ICON_NAME_RE = re.compile(r"^(lnk__)?gen__(?P<scene_name>.+)-icon__(active|inactive)$")
ACTION_TYPE_UUID = {"scene": "com.elgato.obsstudio.scene"}


PRETTIER_PATH = (
    Path(os.environ["LOCALAPPDATA"]) / "nvim-data" / "mason" / "bin" / "prettier.cmd"
)


def format_with_prettier(path: Path):
    subprocess.run(
        [str(PRETTIER_PATH), "--write", str(path)],
        check=True,
        cwd=path.parent,
    )


def find_scene_icons(directory: Path) -> dict[str, list[Path]]:
    """Returns {scene_name: [matching files]} for every gen__..-icon__(in)active
    file found directly in `directory`."""
    found: dict[str, list[Path]] = {}
    for f in directory.iterdir():
        if not f.is_file():
            continue
        m = ICON_NAME_RE.match(f.stem)
        if not m:
            continue
        scene_name = m.group("scene_name")
        found.setdefault(scene_name, []).append(f)
    return found


def find_scene_keys_in_manifest(manifest: dict) -> dict[str, dict]:
    """Walks every action in the manifest, returns {scene_name: action}
    for every scene action found."""
    scene_actions: dict[str, dict] = {}
    for controller in manifest.get("Controllers", []):
        for action in controller.get("Actions", {}).values():
            if action.get("UUID") != ACTION_TYPE_UUID["scene"]:
                continue
            settings = action.get("Settings", {})
            if "scene" in settings:
                scene_actions[settings["scene"]] = action
    return scene_actions


def split_active_inactive(files: list[Path]) -> tuple[Path | None, Path | None]:
    active = next((f for f in files if "__active" in f.stem), None)
    inactive = next((f for f in files if "__inactive" in f.stem), None)
    return active, inactive


def apply_icon_to_action(action: dict, active_path: Path, inactive_path: Path):
    """Sets or replaces the Image key on both states of a scene action.
    State 0 = active, State 1 = inactive."""
    if action.get("UUID") != ACTION_TYPE_UUID["scene"]:
        logger.info("not implemented yet")
        return

    states = action.get("States", [])
    if len(states) < 2:
        logger.warning(
            "Skipping action with unexpected States shape (expected 2, "
            f"got {len(states)}): {action!r}"
        )
        return

    states[0]["Image"] = f"Images/{active_path.name}"
    states[1]["Image"] = f"Images/{inactive_path.name}"


def main(directory: Path):
    scene_icons = find_scene_icons(directory)
    manifest = json.loads(MANIFEST_PATH.read_text())
    scene_actions = find_scene_keys_in_manifest(manifest)

    for scene_name, files in scene_icons.items():
        action = scene_actions.get(scene_name)
        if action is None:
            print(f"{scene_name}: NOT in manifest")
            continue

        active_path, inactive_path = split_active_inactive(files)
        if active_path is None or inactive_path is None:
            logger.warning(
                f"Scene {scene_name!r} missing active/inactive icon "
                f"(active={active_path}, inactive={inactive_path})"
            )
            continue

        apply_icon_to_action(action, active_path, inactive_path)
        print(f"{scene_name}: updated")

    MANIFEST_PATH.write_text(json.dumps(manifest, separators=(",", ":")))
    format_with_prettier(MANIFEST_PATH)


if __name__ == "__main__":
    main(Path(sys.argv[1]))
