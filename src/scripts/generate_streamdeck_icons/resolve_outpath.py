import json
from pathlib import Path

from .place_in_manifests import (
    find_profile_switch_keys_in_manifest,
    find_scene_keys_in_manifest,
)
from .resolve_action_names import (
    _profile_from_icon_path,
    _profile_name_from_home_marker,
    action_name_from_stem,
)
from .shared import KnownBadProfile, logger

_known_bad_profiles: set[str] = set()


def _find_manifests_for_profile(sdeck_root: Path, profile_name: str):
    for sdprofile_dir in sdeck_root.glob("*.sdProfile"):
        if _profile_name_from_home_marker(sdprofile_dir) != profile_name:
            continue
        for manifest_path in sdprofile_dir.rglob("manifest.vcs-template.json"):
            yield manifest_path


def resolve_profile_switch_images_dirs(
    action_name: str, sdeck_root: Path, manifest_filename: str
) -> list[Path]:
    out_dirs = []
    for manifest_path in sdeck_root.rglob(manifest_filename):
        manifest = json.loads(manifest_path.read_text())
        profile_actions = find_profile_switch_keys_in_manifest(
            manifest, sdeck_root, manifest_filename
        )
        if action_name in profile_actions:
            images_dir = manifest_path.parent / "images"
            images_dir.mkdir(exist_ok=True)
            out_dirs.append(images_dir)
    return out_dirs


def resolve_images_dir(
    action_name: str, profile_name: str, sdeck_root: Path
) -> Path | None:
    for manifest_path in _find_manifests_for_profile(sdeck_root, profile_name):
        manifest = json.loads(manifest_path.read_text())
        scene_names = find_scene_keys_in_manifest(manifest)
        if action_name in scene_names:
            images_dir = manifest_path.parent / "images"
            images_dir.mkdir(exist_ok=True)
            return images_dir
    return None


def resolve_out_dir(icon_path: Path, icons_root: Path, sdeck_root: Path) -> Path | None:
    action_name = action_name_from_stem(icon_path.stem)
    if action_name is None:
        logger.error(f"  {icon_path.name}: no action_name extracted from stem")
        raise ValueError(f"Cannot extract action_name from stem {icon_path.stem}")

    try:
        profile_name = _profile_from_icon_path(icon_path, icons_root)
    except KnownBadProfile:
        return None
    except ValueError as e:
        logger.error(str(e))
        return None

    logger.debug(
        f"  {icon_path.name}: action_name={action_name!r}, profile={profile_name!r}"
    )
    return resolve_images_dir(action_name, profile_name, sdeck_root)


def resolve_out_dir_for_category(
    icon_path: Path, icons_root: Path, sdeck_root: Path, category_dir: Path
) -> Path | None:
    if category_dir.parent.name == "common":
        out_dir = category_dir / "generated"
        out_dir.mkdir(exist_ok=True)
        return out_dir
    return resolve_out_dir(icon_path, icons_root, sdeck_root)
