from pathlib import Path

from constants import SYMLINK_PREFIX


def _walk_common_subdirs(root: Path):
    common = root / "common"
    for subdir in common.iterdir():
        if subdir.is_dir():
            yield subdir


def sync_symlinks(root: Path):
    for common_subdir in _walk_common_subdirs(root):
        subdir_name = common_subdir.name
        common_generated = common_subdir / "generated"
        if not common_generated.is_dir():
            continue

        common_files = {f.name for f in common_generated.iterdir() if f.is_file()}

        for game_dir in root.iterdir():
            if not game_dir.is_dir() or game_dir.name in ("common", "hub"):
                continue

            target_subdir = game_dir / subdir_name / "generated"
            target_subdir.mkdir(parents=True, exist_ok=True)

            existing = {f.name: f for f in target_subdir.iterdir()}

            # add/refresh links for every common generated file
            for name in common_files:
                link = target_subdir / (SYMLINK_PREFIX + name)

                if link.exists() and not link.is_symlink():
                    continue  # real local file — leave it alone

                if link.is_symlink():
                    if link.resolve() == (common_generated / name).resolve():
                        continue  # already correct
                    link.unlink()  # stale or broken symlink

                link.symlink_to((common_generated / name).resolve())

            # prune stale links (pointed at common, but source file is gone)
            for name, f in existing.items():
                if (
                    f.is_symlink()
                    and name.startswith(SYMLINK_PREFIX)
                    and name[len(SYMLINK_PREFIX) :] not in common_files
                ):
                    try:
                        if f.resolve().parent == common_generated:
                            f.unlink()
                    except OSError:
                        pass
