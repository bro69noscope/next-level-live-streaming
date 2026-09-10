import json
import re
from pathlib import Path

from constants import GENERATED_PREFIX, SDECK_MANIFEST_FILENAMES, SYMLINK_PREFIX
from shared import format_with_prettier, logger

ICON_NAME_RE = re.compile(
    rf"^({re.escape(SYMLINK_PREFIX)})?{re.escape(GENERATED_PREFIX)}"
    r"(?P<scene_name>.+)-icon__(active|inactive)$"
    # example: lnk__gen__<scene_name>-icon__active
)
ACTION_TYPE_UUID = {"scene": "com.elgato.obsstudio.scene"}


def _find_images_dirs(sdeck_root: Path, manifest_filename: str):
    for candidate in sdeck_root.rglob("*"):
        if not (candidate.is_dir() and candidate.name.lower() == "images"):
            continue
        manifest_path = candidate.parent / manifest_filename
        if not manifest_path.is_file():
            logger.warning(f"No manifest found next to {candidate}, skipping")
            continue
        yield candidate, manifest_path


def _find_scene_icons(directory: Path) -> dict[str, list[Path]]:
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


def _split_active_inactive(files: list[Path]) -> tuple[Path | None, Path | None]:
    active = next((f for f in files if "__active" in f.stem), None)
    inactive = next((f for f in files if "__inactive" in f.stem), None)
    return active, inactive


def _apply_icon_to_action(action: dict, active_path: Path, inactive_path: Path):
    if action.get("UUID") != ACTION_TYPE_UUID["scene"]:
        logger.info("not implemented yet")
        return

    states = action.get("States", [])
    if len(states) < 2:
        logger.warning(
            "Skipping scene action with unexpected States shape (expected 2, "
            f"got {len(states)}): {action!r}"
        )
        return

    states[0]["Image"] = f"Images/{active_path.name}"
    states[1]["Image"] = f"Images/{inactive_path.name}"


def find_scene_keys_in_manifest(manifest: dict) -> dict[str, dict]:
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
    scene_icons = _find_scene_icons(images_dir)
    manifest = json.loads(manifest_path.read_text())
    scene_actions = find_scene_keys_in_manifest(manifest)

    for scene_name, files in scene_icons.items():
        action = scene_actions.get(scene_name)
        if action is None:
            logger.info(f"{scene_name}: NOT in manifest ({manifest_path})")
            continue

        active_path, inactive_path = _split_active_inactive(files)
        if active_path is None or inactive_path is None:
            logger.warning(
                f"Scene {scene_name!r} missing active/inactive icon "
                f"(active={active_path}, inactive={inactive_path})"
            )
            continue

        _apply_icon_to_action(action, active_path, inactive_path)
        logger.info(f"{scene_name}: updated ({manifest_path})")

    manifest_path.write_text(json.dumps(manifest, separators=(",", ":")))
    format_with_prettier(manifest_path)


def place_icons_in_manifests(sdeck_root: Path):
    manifest_filename = SDECK_MANIFEST_FILENAMES.get(sdeck_root)
    if not manifest_filename:
        msg = (
            f"No manifest filename defined for {sdeck_root} "
            f"(expected one of {[str(k) for k in SDECK_MANIFEST_FILENAMES]})"
        )
        logger.error(msg)
        raise ValueError(msg)
    for images_dir, manifest_path in _find_images_dirs(sdeck_root, manifest_filename):
        process_manifest(images_dir, manifest_path)
