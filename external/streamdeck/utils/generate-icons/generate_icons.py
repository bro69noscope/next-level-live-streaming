import io
import sys
from pathlib import Path

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

from constants import (
    ACTIVE_SUFFIX,
    CATEGORY_COLORS_MAP,
    GENERATED_PREFIX,
    INACTIVE_SUFFIX,
)
from PIL import Image, ImageDraw, ImageEnhance

CATEGORIES_WITH_ACTIVATION = {"scenes", "sources"}

BRIGHTNESS_FACTOR = 0.3
FRAME_PCT = 0.075
INACTIVE_THICKNESS_FACTOR = 0.65
MID_THICKNESS_FACTOR = (1 + INACTIVE_THICKNESS_FACTOR) / 2
MAX_ICON_DIMENSION = 256


def _save_image(img: Image.Image, path: Path):
    if path.suffix.lower() in (".jpg", ".jpeg"):
        img = img.convert("RGB")
    img.save(path)


def _resize_to_max(img: Image.Image, max_dim: int) -> Image.Image:
    w, h = img.size
    if max(w, h) <= max_dim:
        return img
    scale = max_dim / max(w, h)
    return img.resize((round(w * scale), round(h * scale)), Image.Resampling.LANCZOS)


def _load_image(path: Path) -> Image.Image:
    if path.suffix.lower() == ".svg":
        png_bytes = cairosvg.svg2png(url=str(path))
        assert png_bytes is not None, f"cairosvg failed to render {path}"
        img = Image.open(io.BytesIO(png_bytes)).convert("RGBA")
    else:
        img = Image.open(path).convert("RGBA")
    return _resize_to_max(img, MAX_ICON_DIMENSION)


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
    color = CATEGORY_COLORS_MAP[category]
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
