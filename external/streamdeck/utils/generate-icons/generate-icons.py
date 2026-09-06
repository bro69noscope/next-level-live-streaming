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

from PIL import Image, ImageDraw, ImageEnhance

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


def _load_image(path: Path) -> Image.Image:
    if path.suffix.lower() == ".svg":
        png_bytes = cairosvg.svg2png(url=str(path))
        assert png_bytes is not None, f"cairosvg failed to render {path}"
        return Image.open(io.BytesIO(png_bytes)).convert("RGB")
    return Image.open(path).convert("RGB")


def _dim_color(color, factor):
    return tuple(int(c * factor) for c in color)


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
        active.save(out_dir / f"generated_{stem}_active{ext}")

        inactive = ImageEnhance.Brightness(img).enhance(BRIGHTNESS_FACTOR)
        inactive_color = _dim_color(color, BRIGHTNESS_FACTOR)
        inactive_thickness_w = round(thickness_w * INACTIVE_THICKNESS_FACTOR)
        inactive_thickness_h = round(thickness_h * INACTIVE_THICKNESS_FACTOR)
        _draw_frame(
            inactive, inactive_color, inactive_thickness_w, inactive_thickness_h
        )
        inactive.save(out_dir / f"generated_{stem}_inactive{ext}")
    else:
        single = img.copy()
        mid_thickness_w = round(thickness_w * MID_THICKNESS_FACTOR)
        mid_thickness_h = round(thickness_h * MID_THICKNESS_FACTOR)
        _draw_frame(single, color, mid_thickness_w, mid_thickness_h)
        single.save(out_dir / f"generated_{stem}{ext}")


def walk_categories(root: Path):
    for category_dir in root.rglob("*"):
        if category_dir.is_dir() and category_dir.name in CATEGORY_COLORS:
            for f in category_dir.iterdir():
                if not f.is_file() or f.stem.startswith("generated_"):
                    continue
                if f.suffix.lower() not in IMAGE_EXTS:
                    print(f"skipping unsupported file: {f}")
                    continue
                yield f, category_dir.name, category_dir


def main(root_dir):
    root = Path(root_dir)
    for path, category, out_dir in walk_categories(root):
        process_image(path, category, out_dir)


if __name__ == "__main__":
    main(sys.argv[1])
