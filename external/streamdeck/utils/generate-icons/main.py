from pathlib import Path

from constants import (
    CATEGORY_COLORS_MAP,
    IMAGE_EXTS,
    LOCAL_SDECK_ROOT,
    SDECK_ICONS_ROOT,
    VCDATA_SDECK_ROOT,
)
from generate_icons import process_image
from generate_symlinks import sync_symlinks
from place_in_manifests import place_icons_in_manifests
from resolve_outpath import resolve_out_dir_for_category
from shared import logger


def walk_categories(root: Path):
    for item in root.rglob("*"):
        if item.is_dir() and item.name in CATEGORY_COLORS_MAP:
            category_dir = item
            for f in category_dir.iterdir():
                if not f.is_file():
                    continue
                if f.name == ".gitkeep":
                    continue
                if f.suffix.lower() not in IMAGE_EXTS:
                    msg = (
                        f"skipping unsupported file: {f} "
                        f"(unsupported extension {f.suffix})"
                    )
                    logger.warning(msg)
                    print(msg)
                    continue
                yield f, category_dir.name, category_dir


def main():
    for filepath, category, category_dir in walk_categories(SDECK_ICONS_ROOT):
        for sdeck_root in (VCDATA_SDECK_ROOT, LOCAL_SDECK_ROOT):
            out_dir = resolve_out_dir_for_category(
                filepath, SDECK_ICONS_ROOT, sdeck_root, category_dir
            )
            if out_dir is None:
                logger.info(
                    f"no matching profile found for {filepath} under {sdeck_root}, skipping"
                )
                continue
            process_image(filepath, category, out_dir)

    for sdeck_root in (VCDATA_SDECK_ROOT, LOCAL_SDECK_ROOT):
        sync_symlinks(SDECK_ICONS_ROOT, sdeck_root)
        place_icons_in_manifests(sdeck_root)


if __name__ == "__main__":
    main()
