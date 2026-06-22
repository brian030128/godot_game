#!/usr/bin/env python3
"""Overlay both detection pipelines on the floor for visual curation.

  green  = Pipeline 1 (SAM auto-mask)   tmp/obstacles_sam.json
  red    = Pipeline 2 (my own boxes)    tools/sam/obstacles_manual.json (labelled)

Also draws the 32px tile grid faintly so boxes can be read in cell coords.
Usage: python tools/sam/preview_obstacles.py
"""
import json
import os

from PIL import Image, ImageDraw

FLOOR = "assets/maps/map2s_floor.png"
SAM = "tmp/obstacles_sam.json"
MANUAL = "tools/sam/obstacles_manual.json"
OUT = "tmp/obstacles_combined_preview.png"
TILE = 32


def main():
    im = Image.open(FLOOR).convert("RGB")
    dr = ImageDraw.Draw(im)
    w, h = im.size

    for gx in range(0, w, TILE * 4):
        dr.line([(gx, 0), (gx, h)], fill=(70, 70, 90), width=1)
    for gy in range(0, h, TILE * 4):
        dr.line([(0, gy), (w, gy)], fill=(70, 70, 90), width=1)

    if os.path.exists(SAM):
        for d in json.load(open(SAM)):
            dr.rectangle(d["box"], outline=(80, 255, 80), width=3)

    for d in json.load(open(MANUAL)):
        dr.rectangle(d["box"], outline=(255, 60, 60), width=3)
        dr.text((d["box"][0] + 2, d["box"][1] + 2), d.get("label", ""), fill=(255, 230, 120))

    im.save(OUT)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
