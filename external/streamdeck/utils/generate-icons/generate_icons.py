import io
import sys
from pathlib import Path

from shared import logger

try:
    import cairosvg
except OSError as e:
    print(
        f"{__file__} requires the cairo native library (cairo.dll or libcairo-2.dll) "
        "to be installed. Run `npm run setup:cairo` at repo root to install it, "
        "then restart your shell.",
        file=sys.stderr,
    )
    raise SystemExit(1) from e

from constants import ACTIVE_SUFFIX, GENERATED_PREFIX, INACTIVE_SUFFIX
from generate_icons_symlinks import sync_symlinks
from PIL import Image, ImageDraw, ImageEnhance
from place_in_manifests import place_icons_in_manifests
from resolve_outpath import ICONS_ROOT, VCDATA_ROOT, resolve_out_dir_for_category

CATEGORY_COLORS = {
    "scenes": (255, 0, 0),  # red *
    "sources": (255, 165, 0),  # orange *
    "streamerbot-actions": (0, 255, 255),  # cyan
    "websocket-msg": (173, 216, 230),  # light blue
    "system-open": (0, 100, 0),  # dark green
    "profiles": (255, 105, 180),  # pink
    "hotkeys": (0, 0, 128),  # navy
    "multi-action": (255, 255, 0),  # yellow
}

CATEGORIES_WITH_ACTIVATION = {"scenes", "sources"}
IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".gif", ".svg"}

BRIGHTNESS_FACTOR = 0.3
FRAME_PCT = 0.075
INACTIVE_THICKNESS_FACTOR = 0.65
MID_THICKNESS_FACTOR = (1 + INACTIVE_THICKNESS_FACTOR) / 2


def _save_image(img: Image.Image, path: Path):
    if path.suffix.lower() in (".jpg", ".jpeg"):
        img = img.convert("RGB")
    img.save(path)


def _load_image(path: Path) -> Image.Image:
    if path.suffix.lower() == ".svg":
        png_bytes = cairosvg.svg2png(url=str(path))
        assert png_bytes is not None, f"cairosvg failed to render {path}"
        return Image.open(io.BytesIO(png_bytes)).convert("RGBA")
    return Image.open(path).convert("RGBA")


def _dim_brightness_preserve_alpha(img: Image.Image, factor: float) -> Image.Image:
    r, g, b, a = img.split()
    rgb = Image.merge("RGB", (r, g, b))
    dimmed = ImageEnhance.Brightness(rgb).enhance(factor)
    dr, dg, db = dimmed.split()
    return Image.merge("RGBA", (dr, dg, db, a))


def _dim_color(color, factor):
    return tuple(int(c * factor) for c in color[:3]) + (255,)


def _draw_frame(img, color, thickness_w, thickness_h):
    draw = ImageDraw.Draw(img)
    w, h = img.size
    draw.rectangle([0, 0, w, thickness_h], fill=color)
    draw.rectangle([0, h - thickness_h, w, h], fill=color)
    draw.rectangle([0, 0, thickness_w, h], fill=color)
    draw.rectangle([w - thickness_w, 0, w, h], fill=color)
    return img


def process_image(path: Path, category: str, out_dir: Path):
    color = CATEGORY_COLORS[category]
    img = _load_image(path)
    w, h = img.size
    thickness_w = round(w * FRAME_PCT)
    thickness_h = round(h * FRAME_PCT)
    stem = path.stem
    ext = ".png" if path.suffix.lower() == ".svg" else path.suffix

    if category in CATEGORIES_WITH_ACTIVATION:
        active = img.copy()
        _draw_frame(active, color, thickness_w, thickness_h)
        _save_image(active, out_dir / (GENERATED_PREFIX + stem + ACTIVE_SUFFIX + ext))

        inactive = _dim_brightness_preserve_alpha(img, BRIGHTNESS_FACTOR)
        inactive_color = _dim_color(color, BRIGHTNESS_FACTOR)
        inactive_thickness_w = round(thickness_w * INACTIVE_THICKNESS_FACTOR)
        inactive_thickness_h = round(thickness_h * INACTIVE_THICKNESS_FACTOR)
        _draw_frame(
            inactive, inactive_color, inactive_thickness_w, inactive_thickness_h
        )
        _save_image(
            inactive, out_dir / (GENERATED_PREFIX + stem + INACTIVE_SUFFIX + ext)
        )
    else:
        single = img.copy()
        mid_thickness_w = round(thickness_w * MID_THICKNESS_FACTOR)
        mid_thickness_h = round(thickness_h * MID_THICKNESS_FACTOR)
        _draw_frame(single, color, mid_thickness_w, mid_thickness_h)
        _save_image(single, out_dir / (GENERATED_PREFIX + stem + ext))


def walk_categories(root: Path):
    for category_dir in root.rglob("*"):
        if category_dir.is_dir() and category_dir.name in CATEGORY_COLORS:
            for f in category_dir.iterdir():
                if not f.is_file():
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
