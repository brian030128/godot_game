#!/usr/bin/env python3
"""Use SAM to segment each top doorway's OPENING (recess) so the wall foreground keeps the
stone arch/frame and cuts only the opening — pixel-accurate, no colour heuristics.

Outputs an opening mask (white = cut) that build_pngmap_room.py consumes as
<source>_openmask.png, plus a red-overlay preview for inspection.

Usage: python tools/sam/segment_doors.py
"""
import numpy as np
import torch
from PIL import Image
from segment_anything import sam_model_registry, SamPredictor

FLOOR = "assets/maps/map2s_floor.png"
CKPT = "tools/sam/sam_vit_b_01ec64.pth"
OPENMASK = "map2_openmask.png"          # build script looks for <src.stem>_openmask.png
PREVIEW = "tmp/sam_preview.png"
TILE, BAND = 32, 3
# Door centre columns (cells) — same as the room .gd TOP_OPENINGS centres.
DOOR_CENTER_COLS = [13, 25, 38]


def main():
    img = np.array(Image.open(FLOOR).convert("RGB"))
    h, w = img.shape[:2]
    band = BAND * TILE
    teal = (img[..., 1].astype(int) + img[..., 2]) / 2 - img[..., 0]

    dev = "cuda" if torch.cuda.is_available() else "cpu"
    sam = sam_model_registry["vit_b"](checkpoint=CKPT).to(dev)
    pred = SamPredictor(sam)
    pred.set_image(img)

    cut = np.zeros((h, w), bool)
    for col in DOOR_CENTER_COLS:
        cx0 = col * TILE + TILE // 2
        # refine the door centre to the brightest-teal column within +-1.5 cells
        x0, x1 = max(0, cx0 - 48), min(w, cx0 + 48)
        colprof = teal[0:band, x0:x1].mean(0)
        cx = x0 + int(np.argmax(colprof))
        # positive points: a vertical line down the recess centre (covers the full opening
        # height); negative point on the room floor below so SAM stops at the threshold.
        pos_ys = [int(band * f) for f in (0.25, 0.45, 0.65, 0.85)]
        pts = [[cx, y] for y in pos_ys] + [[cx, band + 90]]
        lbls = [1, 1, 1, 1, 0]
        box = np.array([cx - 90, 0, cx + 90, band + 24])
        masks, scores, _ = pred.predict(point_coords=np.array(pts), point_labels=np.array(lbls),
                                        box=box, multimask_output=True)
        # pick the best-scoring mask that is recess-sized and doesn't leak into the room
        box_area = 180 * (band + 24)
        best, best_score = None, -2.0
        for m, s in zip(masks, scores):
            area = int(m.sum())
            below = int(m[band + 24:].sum())
            if area < 0.08 * box_area or area > 0.95 * box_area:
                continue
            if below > 0.2 * area:
                continue
            if s > best_score:
                best, best_score = m, s
        if best is None:
            best = masks[int(np.argmax(scores))]
        cut |= best
        print(f"door col {col}: cx={cx} score={best_score:.3f} area={int(best.sum())}")

    cut[band:, :] = False  # openings live in the top band
    Image.fromarray((cut * 255).astype(np.uint8), "L").save(OPENMASK)

    prev = img.copy()
    prev[cut] = (255, 40, 40)
    Image.fromarray(prev).crop((0, 0, w, 150)).save(PREVIEW)
    print(f"wrote {OPENMASK} and {PREVIEW}")


if __name__ == "__main__":
    main()
