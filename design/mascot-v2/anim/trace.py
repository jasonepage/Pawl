#!/usr/bin/env python3
"""Trace the flat color regions of the reference kitty into SVG paths (512 viewBox).
Mapping: bow center (1023,780) r 438 in the image -> (256,188) r 107."""
import numpy as np, cv2, json, pathlib
from PIL import Image

img = np.array(Image.open("/mnt/user-data/attachments/48710e8f-0a7f-5c09-ab98-f8e278efe66a/857c96b0-image.png").convert("RGB")).astype(int)
K = 107/438.0
def M(x, y): return (256 + (x-1023)*K, 188 + (y-780)*K)

COLORS = {"gold": (203,159,36), "dark": (175,131,32), "cream": (240,224,192), "ring": (128,96,16), "lid": (177,135,37), "ink": (26,23,20)}

def trace(color, tol=60, region=None, minarea=400, eps=1.2):
    m = (np.abs(img - np.array(color)).sum(2) < tol).astype(np.uint8)
    if region:
        x0,y0,x1,y1 = region; mm = np.zeros_like(m); mm[y0:y1, x0:x1] = m[y0:y1, x0:x1]; m = mm
    m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, np.ones((5,5), np.uint8))
    m = cv2.morphologyEx(m, cv2.MORPH_OPEN, np.ones((3,3), np.uint8))
    cs, _ = cv2.findContours(m, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    paths = []
    for c in cs:
        if cv2.contourArea(c) < minarea: continue
        c = cv2.approxPolyDP(c, eps, True)[:,0,:]
        pts = [M(x, y) for x, y in c]
        d = "M" + " L".join(f"{x:.1f} {y:.1f}" for x, y in pts) + " Z"
        paths.append(d)
    return paths

out = {}
out["brows"] = trace(COLORS["cream"], region=(700,480,1350,620))
out["mustache"] = trace(COLORS["cream"], region=(700,900,1350,1060))
out["eyewhite_l"] = trace(COLORS["cream"], region=(640,620,960,880))
out["eyewhite_r"] = trace(COLORS["cream"], region=(1080,620,1400,880))
out["ring_l"] = trace(COLORS["ring"], region=(640,600,960,900), minarea=200)
out["ring_r"] = trace(COLORS["ring"], region=(1080,600,1400,900), minarea=200)
out["lid_l"] = trace(COLORS["lid"], tol=40, region=(640,600,960,900))
out["lid_r"] = trace(COLORS["lid"], tol=40, region=(1080,600,1400,900))
out["pupil_l"] = trace(COLORS["ink"], region=(640,620,960,880))
out["pupil_r"] = trace(COLORS["ink"], region=(1080,620,1400,880))
out["innerear"] = trace(COLORS["dark"], tol=40, region=(560,240,1480,620))
out["stemdark"] = trace(COLORS["dark"], tol=40, region=(850,1150,1300,1800))
out["body"] = trace(COLORS["gold"], tol=70, region=(540,240,1500,1800), eps=1.5)   # head + ears + stem (one blob) plus dark parts filled later
for k, v in out.items(): print(k, len(v), [len(p) for p in v])
pathlib.Path("traced.json").write_text(json.dumps(out))
