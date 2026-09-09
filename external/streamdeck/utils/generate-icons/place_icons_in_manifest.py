"""find_scene_icons.py

Given a directory, find generated icon files named like
gen__scene_lounge-icon__active.png / __inactive.png, extract the scene
name (e.g. "scene_lounge"), and check whether that scene name appears
under a "scene" key anywhere in the manifest.
"""

import json
import re
import sys
from pathlib import Path

MANIFEST_PATH = Path(
    r"C:\Users\ville\myfiles\git-repos\woertsposzibllen4me\external\streamdeck"
    r"\version-control\vcdata\08F1CB5E-CA39-47F0-9924-8D181F508A8C.sdProfile"
    r"\Profiles\F564D696-1142-4902-BA97-8EE0DA773BB9\manifest.vcs-template.json"
)

ICON_NAME_RE = re.compile(r"^(lnk__)?gen__(?P<scene_name>.+)-icon__(active|inactive)$")
ACTION_TYPE_UUID = {"scene": "com.elgato.obsstudio.scene"}


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


def find_scene_keys_in_manifest(manifest: dict) -> set[str]:
    """Walks every action in the manifest, returns the set of all values
    found under a "scene" key inside a scene action's Settings."""
    scene_names = set()
    for controller in manifest.get("Controllers", []):
        for action in controller.get("Actions", {}).values():
            if action.get("UUID") != ACTION_TYPE_UUID["scene"]:
                continue
            settings = action.get("Settings", {})
            if "scene" in settings:
                scene_names.add(settings["scene"])
    return scene_names


def main(directory: Path):
    scene_icons = find_scene_icons(directory)
    manifest = json.loads(MANIFEST_PATH.read_text())
    manifest_scene_names = find_scene_keys_in_manifest(manifest)

    for scene_name, files in scene_icons.items():
        in_manifest = scene_name in manifest_scene_names
        status = "found in manifest" if in_manifest else "NOT in manifest"
        print(f"{scene_name}: {status}")
        for f in files:
            print(f"  {f.name}")


if __name__ == "__main__":
    main(Path(sys.argv[1]))
