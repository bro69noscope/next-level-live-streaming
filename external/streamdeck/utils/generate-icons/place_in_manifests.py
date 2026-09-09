import json
import os
import re
import subprocess
from pathlib import Path

from shared import logger

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


def find_images_dirs(root: Path):
    """Recursively finds every "images" directory under root, yielding
    (images_dir, manifest_path) pairs — manifest_path is the
    manifest.vcs-template.json sitting alongside that images dir."""
    for images_dir in root.rglob("images"):
        if not images_dir.is_dir():
            continue
        manifest_path = images_dir.parent / "manifest.vcs-template.json"
        if not manifest_path.is_file():
            logger.warning(f"No manifest found next to {images_dir}, skipping")
            continue
        yield images_dir, manifest_path


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
        actions = controller.get("Actions") or {}
        for action in actions.values():
            if action.get("UUID") != ACTION_TYPE_UUID["scene"]:
                continue
            settings = action.get("Settings", {})
            if "scene" in settings:
                scene_actions[settings["scene"]] = action
    return scene_actions


def process_manifest(images_dir: Path, manifest_path: Path):
    scene_icons = find_scene_icons(images_dir)
    manifest = json.loads(manifest_path.read_text())
    scene_actions = find_scene_keys_in_manifest(manifest)

    for scene_name, files in scene_icons.items():
        action = scene_actions.get(scene_name)
        if action is None:
            logger.info(f"{scene_name}: NOT in manifest ({manifest_path})")
            continue

        active_path, inactive_path = split_active_inactive(files)
        if active_path is None or inactive_path is None:
            logger.warning(
                f"Scene {scene_name!r} missing active/inactive icon "
                f"(active={active_path}, inactive={inactive_path})"
            )
            continue

        apply_icon_to_action(action, active_path, inactive_path)
        logger.info(f"{scene_name}: updated ({manifest_path})")

    manifest_path.write_text(json.dumps(manifest, separators=(",", ":")))
    format_with_prettier(manifest_path)


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


def place_icons_in_manifests(root_dir: Path):
    for images_dir, manifest_path in find_images_dirs(root_dir):
        process_manifest(images_dir, manifest_path)
