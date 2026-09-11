import json
import re
from pathlib import Path

from .constants import (
    ACTIVE_SUFFIX,
    INACTIVE_SUFFIX,
    MARKER_FORMAT,
    STREAMDECK_DEVICE_SUFFIXES,
)
from .shared import KnownBadProfile

_known_bad_profiles: set[str] = set()


def _build_home_marker_regex():
    literal = MARKER_FORMAT["pattern"].replace("{type}", MARKER_FORMAT["home_type"])
    pattern = re.escape(literal).replace(r"\{name\}", r"(?P<profile>.+)")
    return re.compile(f"^{pattern}$")


HOME_MARKER_RE = _build_home_marker_regex()


def _profile_name_from_home_marker(sdprofile_dir: Path) -> str | None:
    for f in sdprofile_dir.iterdir():
        if f.is_file():
            m = HOME_MARKER_RE.match(f.name)
            if m:
                return m.group("profile")


def _profile_from_icon_path(icon_path: Path, icons_root: Path) -> str:
    rel = icon_path.relative_to(icons_root)
    profile = rel.parts[0]

    if profile in _known_bad_profiles:
        raise KnownBadProfile(profile)

    if not any(suffix in profile for suffix in STREAMDECK_DEVICE_SUFFIXES):
        _known_bad_profiles.add(profile)
        raise ValueError(
            f"profile {profile!r} missing a known device suffix "
            f"{STREAMDECK_DEVICE_SUFFIXES} (from {icon_path})"
        )
    return profile


def action_name_from_stem(stem: str) -> str | None:
    if stem.endswith("-icon"):
        return stem[: -len("-icon")]
    return None


def action_name_from_generated_stem(stem: str) -> str | None:
    for suffix in (ACTIVE_SUFFIX, INACTIVE_SUFFIX):
        if stem.endswith(suffix):
            stem = stem[: -len(suffix)]
            break
    return action_name_from_stem(stem)


def profile_name_from_uuid(
    profile_uuid: str, sdeck_root: Path, manifest_filename: str
) -> str | None:
    target = profile_uuid.lower()
    for sdprofile_dir in sdeck_root.glob("*.sdProfile"):
        if sdprofile_dir.name.split(".")[0].lower() != target:
            continue
        home_manifest_path = sdprofile_dir / manifest_filename
        if not home_manifest_path.is_file():
            return None
        home_manifest = json.loads(home_manifest_path.read_text())
        return home_manifest.get("Name")
    return None
