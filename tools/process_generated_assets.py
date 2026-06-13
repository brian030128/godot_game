from __future__ import annotations

from pathlib import Path

from PIL import Image
from statistics import median


ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = ROOT / "assets" / "generated_raw"
SPRITES_DIR = ROOT / "assets" / "sprites"
TILES_DIR = ROOT / "assets" / "tiles"
PROPS_DIR = ROOT / "assets" / "props"

MAGENTA = (255, 0, 255)


def remove_magenta(img: Image.Image, threshold: int = 50) -> Image.Image:
    rgba = img.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            if abs(r - MAGENTA[0]) <= threshold and g <= threshold and abs(b - MAGENTA[2]) <= threshold:
                pixels[x, y] = (0, 0, 0, 0)
            else:
                pixels[x, y] = (r, g, b, a)
    return rgba


def split_grid(img: Image.Image, rows: int, cols: int) -> list[Image.Image]:
    cell_w = img.width // cols
    cell_h = img.height // rows
    cells: list[Image.Image] = []
    for row in range(rows):
        for col in range(cols):
            left = col * cell_w
            top = row * cell_h
            cells.append(img.crop((left, top, left + cell_w, top + cell_h)))
    return cells


def crop_square_cells(img: Image.Image, cols: int) -> list[Image.Image]:
    cell_w = img.width // cols
    square = min(cell_w, img.height)
    top = max((img.height - square) // 2, 0)
    cells: list[Image.Image] = []
    for col in range(cols):
        left = col * cell_w + max((cell_w - square) // 2, 0)
        cells.append(img.crop((left, top, left + square, top + square)))
    return cells


def trim_alpha(img: Image.Image, padding: int = 0) -> Image.Image:
    rgba = img.convert("RGBA")
    bbox = rgba.getbbox()
    if bbox is None:
        return rgba
    left = max(bbox[0] - padding, 0)
    top = max(bbox[1] - padding, 0)
    right = min(bbox[2] + padding, rgba.width)
    bottom = min(bbox[3] + padding, rgba.height)
    return rgba.crop((left, top, right, bottom))


def crop_largest_component(img: Image.Image, padding: int = 0, alpha_threshold: int = 1) -> Image.Image:
    rgba = img.convert("RGBA")
    alpha = rgba.getchannel("A")
    width, height = rgba.size
    visited = [[False] * width for _ in range(height)]
    best_bbox: tuple[int, int, int, int] | None = None
    best_area = 0

    for y in range(height):
        for x in range(width):
            if visited[y][x] or alpha.getpixel((x, y)) < alpha_threshold:
                continue

            stack = [(x, y)]
            visited[y][x] = True
            area = 0
            min_x = max_x = x
            min_y = max_y = y

            while stack:
                cx, cy = stack.pop()
                area += 1
                min_x = min(min_x, cx)
                min_y = min(min_y, cy)
                max_x = max(max_x, cx)
                max_y = max(max_y, cy)

                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if 0 <= nx < width and 0 <= ny < height and not visited[ny][nx] and alpha.getpixel((nx, ny)) >= alpha_threshold:
                        visited[ny][nx] = True
                        stack.append((nx, ny))

            if area > best_area:
                best_area = area
                best_bbox = (min_x, min_y, max_x + 1, max_y + 1)

    if best_bbox is None:
        return rgba

    left = max(best_bbox[0] - padding, 0)
    top = max(best_bbox[1] - padding, 0)
    right = min(best_bbox[2] + padding, width)
    bottom = min(best_bbox[3] + padding, height)
    return rgba.crop((left, top, right, bottom))


def fit_to_canvas(
    img: Image.Image,
    canvas_size: tuple[int, int],
    *,
    bottom_align: bool = True,
    margin: int = 2,
    target_height: int | None = None,
) -> Image.Image:
    canvas_w, canvas_h = canvas_size
    if target_height is not None:
        scale = target_height / img.height
        max_scale = min((canvas_w - margin * 2) / img.width, (canvas_h - margin * 2) / img.height)
        scale = min(scale, max_scale)
    else:
        scale = min((canvas_w - margin * 2) / img.width, (canvas_h - margin * 2) / img.height)
    scale = max(scale, 0.01)
    resized = img.resize(
        (max(1, round(img.width * scale)), max(1, round(img.height * scale))),
        Image.Resampling.NEAREST,
    )
    canvas = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    x = (canvas_w - resized.width) // 2
    y = canvas_h - resized.height - margin if bottom_align else (canvas_h - resized.height) // 2
    canvas.alpha_composite(resized, (x, max(y, margin)))
    return canvas


def save_prompt(path: Path, text: str) -> None:
    path.write_text(text.strip() + "\n", encoding="utf-8")


def process_player() -> None:
    raw = Image.open(RAW_DIR / "player_raw.png")
    cleaned = remove_magenta(raw)
    trimmed_frames = [crop_largest_component(frame, padding=2) for frame in split_grid(cleaned, 4, 4)]
    target_height = min(int(median([frame.height for frame in trimmed_frames])), 44)
    frames = [
        fit_to_canvas(frame, (48, 48), target_height=target_height)
        for frame in trimmed_frames
    ]
    sheet = Image.new("RGBA", (48 * 4, 48 * 4), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        col = index % 4
        row = index // 4
        sheet.alpha_composite(frame, (col * 48, row * 48))
    sheet.save(SPRITES_DIR / "character.png")


def process_tiles() -> None:
    raw = Image.open(RAW_DIR / "tiles_raw.png").convert("RGBA")
    tiles = [tile.resize((32, 32), Image.Resampling.NEAREST) for tile in crop_square_cells(raw, 4)]
    atlas = Image.new("RGBA", (32 * 4, 32), (0, 0, 0, 0))
    for index, tile in enumerate(tiles):
        atlas.alpha_composite(tile, (index * 32, 0))
    atlas.save(TILES_DIR / "tiles_atlas.png")


def process_props() -> None:
    raw = Image.open(RAW_DIR / "props_raw.png")
    cleaned = remove_magenta(raw)
    names_and_sizes = [
        ("bookshelf", (64, 96)),
        ("plant", (48, 64)),
        ("table", (64, 48)),
        ("crates", (64, 64)),
    ]
    for (name, size), cell in zip(names_and_sizes, split_grid(cleaned, 2, 2), strict=True):
        final = fit_to_canvas(trim_alpha(cell, padding=2), size)
        final.save(PROPS_DIR / f"{name}.png")


def main() -> None:
    SPRITES_DIR.mkdir(parents=True, exist_ok=True)
    TILES_DIR.mkdir(parents=True, exist_ok=True)
    PROPS_DIR.mkdir(parents=True, exist_ok=True)
    process_player()
    process_tiles()
    process_props()


if __name__ == "__main__":
    main()
