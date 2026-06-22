#!/usr/bin/env python3
"""Pipeline 1 - open-source object detection.

Run SAM's automatic mask generator over the PNG-skinned floor (map2s_floor.png) and
distil it down to the *raised interior objects* a player should collide with (teddy
bear, spools, cages, candle clusters, the central mechanism), as opposed to the floor,
the painted rug, the stitch lines, the wall band, or the teal door glow.

SAM has no class labels, so "is this an obstacle" is a set of geometric/photometric
filters on each mask:

  * inside the interior (not the wall band, not touching the image border = wall/bg)
  * compact: solidity (mask_area / bbox_area) high enough to be a *thing*, not a
    sprawling rug or a spidery stitch line
  * sized like a prop: between MIN_AREA and MAX_AREA px (rug/floor are bigger)
  * not teal door-glow (those bright openings read as masks too)
  * raised/contrasting against the local floor (objects are lighter/bumpier)

Outputs (consumed by the curation step, not the game directly):
  tmp/obstacles_sam.json     - [{box:[x0,y0,x1,y1], area, solidity, score}]
  tmp/obstacles_sam_preview.png - green boxes over the floor for eyeballing

Usage: python tools/sam/detect_obstacles.py
"""
import json
import os

import numpy as np
import torch
from PIL import Image, ImageDraw
from segment_anything import sam_model_registry, SamAutomaticMaskGenerator

FLOOR = "assets/maps/map2s_floor.png"
CKPT = "tools/sam/sam_vit_b_01ec64.pth"
OUT_JSON = "tmp/obstacles_sam.json"
OUT_PREVIEW = "tmp/obstacles_sam_preview.png"

TILE, BAND = 32, 3
BAND_PX = BAND * TILE  # wall band thickness in px

# Prop-sized: smaller than the rug/floor, bigger than a stray speck.
MIN_AREA = 1200
MAX_AREA = 90000
MIN_SOLIDITY = 0.45      # mask fills >=45% of its bbox -> a blob, not a line/rug
MAX_ASPECT = 4.0         # reject long thin stitch seams
BORDER_TOL = 8           # masks touching this close to the edge are wall/background


def teal_ratio(rgb_crop):
    """Fraction-ish teal score: door glow is high in G+B, low in R and bright."""
    r = rgb_crop[..., 0].astype(int)
    g = rgb_crop[..., 1].astype(int)
    b = rgb_crop[..., 2].astype(int)
    teal = ((g + b) / 2 - r)
    bright = (g + b) / 2
    return float(((teal > 35) & (bright > 90)).mean())


def texture_energy(gray, seg):
    """Mean gradient magnitude inside the mask. Smooth floor patches score low;
    detailed props (fur, wicker, candles, gears) score high. cv2-free (numpy grad)."""
    gy, gx = np.gradient(gray.astype(np.float32))
    mag = np.hypot(gx, gy)
    vals = mag[seg]
    return float(vals.mean()) if vals.size else 0.0


# Floor patches are smooth; a real prop's interior gradient energy clears this.
MIN_TEXTURE = 11.0


def main():
    os.makedirs("tmp", exist_ok=True)
    img = np.array(Image.open(FLOOR).convert("RGB"))
    h, w = img.shape[:2]

    dev = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"device={dev}")
    sam = sam_model_registry["vit_b"](checkpoint=CKPT).to(dev)
    gen = SamAutomaticMaskGenerator(
        sam,
        points_per_side=48,          # dense sampling -> small props get hit
        pred_iou_thresh=0.86,
        stability_score_thresh=0.90,
        # min_mask_region_area omitted: its postprocess needs cv2; we area-filter below.
    )
    masks = gen.generate(img)
    print(f"raw masks: {len(masks)}")

    gray = np.array(Image.fromarray(img).convert("L"))
    kept = []
    for m in masks:
        seg = m["segmentation"]
        x0, y0, bw, bh = m["bbox"]
        x1, y1 = x0 + bw, y0 + bh
        area = int(seg.sum())

        if area < MIN_AREA or area > MAX_AREA:
            continue
        # touching the image border -> wall band / background, not an interior prop
        if x0 <= BORDER_TOL or y0 <= BORDER_TOL or x1 >= w - BORDER_TOL or y1 >= h - BORDER_TOL:
            continue
        # centroid must be off the wall band on every side
        cx, cy = x0 + bw / 2, y0 + bh / 2
        if cx < BAND_PX or cx > w - BAND_PX or cy < BAND_PX or cy > h - BAND_PX:
            # allow if the blob is mostly interior (big props lean on the band)
            interior = seg[BAND_PX:h - BAND_PX, BAND_PX:w - BAND_PX].sum()
            if interior < 0.6 * area:
                continue
        solidity = area / float(bw * bh)
        if solidity < MIN_SOLIDITY:
            continue
        aspect = max(bw, bh) / max(1.0, min(bw, bh))
        if aspect > MAX_ASPECT:
            continue
        crop = img[y0:y1, x0:x1]
        if teal_ratio(crop) > 0.30:   # door glow / bright teal pool
            continue
        # raised object vs. flat floor patch: gradient/texture energy must clear a floor
        tex = texture_energy(gray, seg)
        if tex < MIN_TEXTURE:
            continue

        kept.append({
            "box": [int(x0), int(y0), int(x1), int(y1)],
            "area": area,
            "solidity": round(solidity, 3),
            "texture": round(tex, 2),
            "score": round(float(m["predicted_iou"]), 3),
        })

    # Drop boxes almost entirely contained in a bigger kept box (nested over-seg).
    kept.sort(key=lambda d: d["area"], reverse=True)
    final = []
    for d in kept:
        bx = d["box"]
        contained = False
        for e in final:
            ex = e["box"]
            ix0, iy0 = max(bx[0], ex[0]), max(bx[1], ex[1])
            ix1, iy1 = min(bx[2], ex[2]), min(bx[3], ex[3])
            inter = max(0, ix1 - ix0) * max(0, iy1 - iy0)
            if inter > 0.8 * d["area"]:
                contained = True
                break
        if not contained:
            final.append(d)

    with open(OUT_JSON, "w") as f:
        json.dump(final, f, indent=2)

    prev = Image.fromarray(img).convert("RGB")
    dr = ImageDraw.Draw(prev)
    for d in final:
        dr.rectangle(d["box"], outline=(80, 255, 80), width=3)
    prev.save(OUT_PREVIEW)
    print(f"kept {len(final)} obstacle candidates -> {OUT_JSON}, {OUT_PREVIEW}")


if __name__ == "__main__":
    main()
