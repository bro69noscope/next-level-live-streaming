import json
import re
from pathlib import Path

from constants import ACTIVE_SUFFIX, INACTIVE_SUFFIX, STREAMDECK_DEVICE_SUFFIXES
from place_in_manifests import find_scene_keys_in_manifest
from shared import logger
from src.config.settings import PROJECT_ROOT_PATH

STREAMDECK_ROOT = PROJECT_ROOT_PATH / "external" / "streamdeck"
VCDATA_ROOT = STREAMDECK_ROOT / "version-control" / "vcdata"
ICONS_ROOT = VCDATA_ROOT / "binaries" / "icons"
COMMON_DIR_NAME = "common"


_suffix_alternation = "|".join(re.escape(s) for s in STREAMDECK_DEVICE_SUFFIXES)
HOME_MARKER_RE = re.compile(
    rf"^(?P<profile>.+(?:{_suffix_alternation}))--home-marker\.json$"
)


def _game_from_home_marker(sdprofile_dir: Path) -> str | None:
    for f in sdprofile_dir.iterdir():
        if f.is_file():
            m = HOME_MARKER_RE.match(f.name)
            if m:
                return m.group("profile")
    return None


def _find_manifests_for_profile(vcdata_root: Path, profile: str):
    for sdprofile_dir in vcdata_root.glob("*.sdProfile"):
        if _game_from_home_marker(sdprofile_dir) != profile:
            continue
        for manifest_path in sdprofile_dir.rglob("manifest.vcs-template.json"):
            yield manifest_path


def _profile_from_icon_path(icon_path: Path, icons_root: Path) -> str:
    rel = icon_path.relative_to(icons_root)
    profile = rel.parts[0]
    if not any(suffix in profile for suffix in STREAMDECK_DEVICE_SUFFIXES):
        logger.error(
            f"profile {profile!r} missing a known device suffix "
            f"{STREAMDECK_DEVICE_SUFFIXES} (from {icon_path})"
        )
    return profile


def _action_name_from_stem(stem: str) -> str | None:
    if stem.endswith("-icon"):
        return stem[: -len("-icon")]
    return None


def _action_name_from_generated_stem(stem: str) -> str | None:
    for suffix in (ACTIVE_SUFFIX, INACTIVE_SUFFIX):
        if stem.endswith(suffix):
            stem = stem[: -len(suffix)]
            break
    return _action_name_from_stem(stem)


def resolve_images_dir(
    action_name: str, profile_name: str, vcdata_root: Path
) -> Path | None:
    for manifest_path in _find_manifests_for_profile(vcdata_root, profile_name):
        manifest = json.loads(manifest_path.read_text())
        scene_names = find_scene_keys_in_manifest(manifest)
        if action_name in scene_names:
            images_dir = manifest_path.parent / "images"
            images_dir.mkdir(exist_ok=True)
            return images_dir
    return None


def resolve_out_dir(
    icon_path: Path, icons_root: Path, vcdata_root: Path
) -> Path | None:
    action_name = _action_name_from_stem(icon_path.stem)
    if action_name is None:
        logger.error(f"  {icon_path.name}: no action_name extracted from stem")
        raise ValueError(f"Cannot extract action_name from stem {icon_path.stem}")

    profile_name = _profile_from_icon_path(icon_path, icons_root)
    logger.info(
        f"  {icon_path.name}: action_name={action_name!r}, profile={profile_name!r}"
    )
    return resolve_images_dir(action_name, profile_name, vcdata_root)


def resolve_out_dir_for_category(
    icon_path: Path, icons_root: Path, vcdata_root: Path, category_dir: Path
) -> Path | None:
    if category_dir.parent.name == COMMON_DIR_NAME:
        out_dir = category_dir / "generated"
        out_dir.mkdir(exist_ok=True)
        return out_dir
    return resolve_out_dir(icon_path, icons_root, vcdata_root)
