from pathlib import Path

from constants import CATEGORY_COLORS, IMAGE_EXTS
from generate_icons import process_image
from generate_symlinks import sync_symlinks
from place_in_manifests import place_icons_in_manifests
from resolve_outpath import ICONS_ROOT, VCDATA_ROOT, resolve_out_dir_for_category
from shared import logger


def walk_categories(root: Path):
    for category_dir in root.rglob("*"):
        if category_dir.is_dir() and category_dir.name in CATEGORY_COLORS:
            for f in category_dir.iterdir():
                if not f.is_file():
                    continue
                if f.name == ".gitkeep":
                    continue
                if f.suffix.lower() not in IMAGE_EXTS:
                    print(f"skipping unsupported file: {f}")
                    continue
                yield f, category_dir.name, category_dir


def main():
    for path, category, category_dir in walk_categories(ICONS_ROOT):
        out_dir = resolve_out_dir_for_category(
            path, ICONS_ROOT, VCDATA_ROOT, category_dir
        )
        if out_dir is None:
            logger.info(f"no matching profile found for {path}, skipping")
            continue
        process_image(path, category, out_dir)
    sync_symlinks(ICONS_ROOT, VCDATA_ROOT)
    place_icons_in_manifests(VCDATA_ROOT)


if __name__ == "__main__":
    main()
