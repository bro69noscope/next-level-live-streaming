import os
from pathlib import Path

from constants import GENERATED_PREFIX, SYMLINK_PREFIX
from resolve_action_names import action_name_from_generated_stem
from resolve_outpath import (
    resolve_images_dir,
    resolve_profile_switch_images_dirs,
)


def _walk_common_subdirs(root: Path):
    common = root / "common"
    for subdir in common.iterdir():
        if subdir.is_dir():
            yield subdir


def _create_symlink(src_file: Path, out_dir: Path):
    link = out_dir / (SYMLINK_PREFIX + src_file.name)

    if link.exists() and not link.is_symlink():
        return  # real local file — leave it alone

    if link.is_symlink():
        if link.resolve() == src_file.resolve():
            return  # already correct
        link.unlink()  # stale or broken symlink

    link.symlink_to(src_file.resolve())


def sync_symlinks(icons_root: Path, vcdata_root: Path, manifest_filename: str):
    for common_subdir in _walk_common_subdirs(icons_root):
        common_generated = common_subdir / "generated"
        os.makedirs(common_generated, exist_ok=True)

        for src_file in common_generated.iterdir():
            if not src_file.is_file():
                continue
            action_name = action_name_from_generated_stem(
                src_file.stem.replace(GENERATED_PREFIX, "", 1)
            )
            if action_name is None:
                continue

            if action_name.startswith("profile_"):
                out_dirs = resolve_profile_switch_images_dirs(
                    action_name, vcdata_root, manifest_filename
                )
                for out_dir in out_dirs:
                    _create_symlink(src_file, out_dir)
                continue

            for dir in icons_root.iterdir():
                if not dir.is_dir() or dir.name in ("common", "hub"):
                    continue
                out_dir = resolve_images_dir(action_name, dir.name, vcdata_root)
                if out_dir is None:
                    continue
                _create_symlink(src_file, out_dir)
