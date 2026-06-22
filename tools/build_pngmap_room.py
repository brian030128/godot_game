#!/usr/bin/env python3
"""Build the runtime art for the map.png-skinned room (rooms/room_06).

From a single source image (the beautiful flattened map, default ``map.png``) this
produces the two sprites the room scene uses:

  assets/maps/pngmap_floor.png       - the source fit to the room's pixel size; the
                                       visible floor + walls (Foundation, drawn behind).
  assets/maps/pngmap_walls_top.png   - just the TOP wall band (door holes cut). Drawn by
                                       a depth-sorting node (wall_foreground.gd): it
                                       occludes the player only when they are behind/in
                                       it (stepping into a top doorway), and draws behind
                                       them when they stand in front of it — so a tall
                                       sprite walking up to the top wall is NOT swallowed.
  assets/maps/pngmap_walls_rest.png  - the left/right/bottom bands (entry hole cut),
                                       drawn always above the player. These walls only
                                       ever overlap the player's feet/side, which reads
                                       correctly as "in front of the wall".

Both wall PNGs are the SAME pixels as the source, so style/position stay perfectly
consistent.

The numbers below (grid size, wall-band thickness, door-opening columns) are the
single source of truth shared with rooms/room_06.gd's _layout(): the grid drives
collision + nav + door anchors, and the same columns punch the overlay's holes, so
collision, occlusion, and the visible walls all line up.

Run:  python tools/build_pngmap_room.py
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "map.png"
OUT_FLOOR = ROOT / "assets" / "maps" / "pngmap_floor.png"
OUT_WALLS_TOP = ROOT / "assets" / "maps" / "pngmap_walls_top.png"
OUT_WALLS_REST = ROOT / "assets" / "maps" / "pngmap_walls_rest.png"

TILE = 32
COLS, ROWS = 54, 28          # room is COLS*TILE x ROWS*TILE = 1728 x 896
BAND = 3                     # wall band thickness, in tiles (all four sides)

# Door openings as inclusive tile-column ranges (must match room_06.gd _layout()).
TOP_OPENINGS = [(13, 15), (25, 27), (38, 40)]   # three exits in the top band
BOTTOM_OPENINGS = [(25, 27)]                     # single entry in the bottom band


def fit_to_room(img: Image.Image) -> Image.Image:
    return img.convert("RGBA").resize((COLS * TILE, ROWS * TILE), Image.LANCZOS)


def build_walls(floor: Image.Image) -> Image.Image:
    """Keep alpha only on the wall band; erase interior and the door openings."""
    w, h = floor.size
    band = BAND * TILE
    walls = floor.copy()
    px = walls.load()

    def in_band(x: int, y: int) -> bool:
        return x < band or x >= w - band or y < band or y >= h - band

    # 1) erase the whole interior (everything that isn't the border band)
    for y in range(h):
        for x in range(w):
            if not in_band(x, y):
                r, g, b, _ = px[x, y]
                px[x, y] = (r, g, b, 0)

    # 2) punch the door openings through the band (full band depth) so the glowing
    #    doorways show and the player passes through un-occluded.
    def clear_rect(x0: int, x1: int, y0: int, y1: int) -> None:
        for y in range(y0, y1):
            for x in range(x0, x1):
                r, g, b, _ = px[x, y]
                px[x, y] = (r, g, b, 0)

    for c0, c1 in TOP_OPENINGS:
        clear_rect(c0 * TILE, (c1 + 1) * TILE, 0, band)
    for c0, c1 in BOTTOM_OPENINGS:
        clear_rect(c0 * TILE, (c1 + 1) * TILE, h - band, h)
    return walls


def split_top_rest(walls: Image.Image) -> tuple[Image.Image, Image.Image]:
    """Split the wall overlay along the top-band line: pixels in the top band go to
    `top` (depth-sorted), the rest (left/right/bottom) go to `rest` (always on top)."""
    w, h = walls.size
    band = BAND * TILE
    top = walls.copy()
    rest = walls.copy()
    tp = top.load()
    rp = rest.load()
    for y in range(h):
        in_top = y < band
        for x in range(w):
            if in_top:
                r, g, b, _ = rp[x, y]
                rp[x, y] = (r, g, b, 0)   # clear top band from `rest`
            else:
                r, g, b, _ = tp[x, y]
                tp[x, y] = (r, g, b, 0)   # clear everything below the top band from `top`
    return top, rest


def main() -> None:
    if not SRC.exists():
        raise SystemExit(f"source image not found: {SRC}")
    floor = fit_to_room(Image.open(SRC))
    OUT_FLOOR.parent.mkdir(parents=True, exist_ok=True)
    floor.save(OUT_FLOOR)
    top, rest = split_top_rest(build_walls(floor))
    top.save(OUT_WALLS_TOP)
    rest.save(OUT_WALLS_REST)
    print(f"wrote {OUT_FLOOR.relative_to(ROOT)}  ({floor.size[0]}x{floor.size[1]})")
    print(f"wrote {OUT_WALLS_TOP.relative_to(ROOT)}  (top band, depth-sorted)")
    print(f"wrote {OUT_WALLS_REST.relative_to(ROOT)}  (left/right/bottom, always on top)")


if __name__ == "__main__":
    main()
