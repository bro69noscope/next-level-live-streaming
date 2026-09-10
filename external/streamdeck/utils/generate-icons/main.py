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
from perf import print_summary, timed
from place_in_manifests import place_icons_in_manifests
from resolve_outpath import resolve_out_dir_for_category
from shared import PRETTIER_QUEUE, format_with_prettier, logger


def walk_categories(root: Path):
    for candidate in root.rglob("*"):
        if not (candidate.is_dir() and candidate.name in CATEGORY_COLORS_MAP):
            continue
        for f in candidate.iterdir():
            if not f.is_file():
                continue
            if f.name == ".gitkeep":
                continue
            if f.suffix.lower() not in IMAGE_EXTS:
                msg = (
                    f"skipping unsupported file: {f} (unsupported extension {f.suffix})"
                )
                logger.warning(msg)
                print(msg)
                continue
            yield f, candidate.name, candidate


def main():
    with timed("total"):
        for filepath, category, category_dir in walk_categories(SDECK_ICONS_ROOT):
            for sdeck_root in (VCDATA_SDECK_ROOT, LOCAL_SDECK_ROOT):
                with timed("resolve_out_dir_for_category"):
                    out_dir = resolve_out_dir_for_category(
                        filepath, SDECK_ICONS_ROOT, sdeck_root, category_dir
                    )
                if out_dir is None:
                    logger.debug(
                        f"no matching profile found for {filepath} under {sdeck_root}, skipping"
                    )
                    continue
                with timed("process_image"):
                    process_image(filepath, category, out_dir)

        for sdeck_root in (VCDATA_SDECK_ROOT, LOCAL_SDECK_ROOT):
            with timed("sync_symlinks"):
                sync_symlinks(SDECK_ICONS_ROOT, sdeck_root)
            with timed("place_icons_in_manifests"):
                place_icons_in_manifests(sdeck_root)

        with timed("format_with_prettier"):
            format_with_prettier(PRETTIER_QUEUE)

    print_summary()


if __name__ == "__main__":
    main()
