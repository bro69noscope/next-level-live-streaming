import os
from pathlib import Path


from shared import GENERATED_PREFIX, SYMLINK_PREFIX


def _walk_common_subdirs(root: Path):
    common = root / "common"
    for subdir in common.iterdir():
        if subdir.is_dir():
            yield subdir  # e.g. common/scenes, common/profiles...


def sync_symlinks(root: Path):
    for common_subdir in _walk_common_subdirs(root):
        subdir_name = common_subdir.name
        common_files = {
            f.name
            for f in common_subdir.iterdir()
            if f.is_file() and f.name.startswith(GENERATED_PREFIX)
        }

        for game_dir in root.iterdir():
            if not game_dir.is_dir() or game_dir.name in ("common", "hub"):
                continue
            target_subdir = game_dir / subdir_name
            target_subdir.mkdir(parents=True, exist_ok=True)
            if not target_subdir.exists():
                continue  # or target_subdir.mkdir(parents=True) if structure isn't guaranteed yet

            existing = {f.name: f for f in target_subdir.iterdir()}

            # add/refresh links for every common file
            for name in common_files:
                link = target_subdir / (SYMLINK_PREFIX + name)

                if link.exists() and not link.is_symlink():
                    continue  # real local file — leave it alone

                if link.is_symlink():
                    if link.resolve() == (common_subdir / name).resolve():
                        continue  # already correct
                    link.unlink()  # stale or broken symlink

                elif link.exists():
                    continue  # real local file — leave it alone

                if link.exists():
                    link.unlink()

                rel_target = os.path.relpath(common_subdir / name, target_subdir)
                link.symlink_to(rel_target)

            # prune stale links (pointed at common, but source file is gone)
            for name, f in existing.items():
                if (
                    f.is_symlink()
                    and name.startswith(SYMLINK_PREFIX)
                    and name[len(SYMLINK_PREFIX) :] not in common_files
                ):
                    try:
                        if f.resolve().parent == common_subdir:
                            f.unlink()
                    except OSError:
                        pass
