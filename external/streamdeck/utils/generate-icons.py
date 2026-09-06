from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance

COLORS = {
    "scene": (255, 0, 0),
    "profile": (0, 255, 255),
}

BRIGHTNESS_FACTOR = 0.3
FRAME_PCT = 0.075
INACTIVE_THICKNESS_FACTOR = 0.65


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


def process_image(path: Path, type_: str, out_dir: Path):
    color = COLORS[type_]
    img = Image.open(path).convert("RGB")
    w, h = img.size
    thickness_w = round(w * FRAME_PCT)
    thickness_h = round(h * FRAME_PCT)

    active = img.copy()
    _draw_frame(active, color, thickness_w, thickness_h)

    inactive = ImageEnhance.Brightness(img).enhance(BRIGHTNESS_FACTOR)
    inactive_color = _dim_color(color, BRIGHTNESS_FACTOR)
    inactive_thickness_w = round(thickness_w * INACTIVE_THICKNESS_FACTOR)
    inactive_thickness_h = round(thickness_h * INACTIVE_THICKNESS_FACTOR)
    _draw_frame(inactive, inactive_color, inactive_thickness_w, inactive_thickness_h)

    stem = path.stem
    ext = path.suffix
    active.save(out_dir / f"{stem}_{type_}_active{ext}")
    inactive.save(out_dir / f"{stem}_{type_}_inactive{ext}")


def main(image_paths, type_, out_dir="."):
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    for p in image_paths:
        process_image(Path(p), type_, out_dir)


if __name__ == "__main__":
    import sys

    type_ = sys.argv[1]
    images = sys.argv[2:]
    main(images, type_)
