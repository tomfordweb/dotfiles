#!/usr/bin/env python3
"""Generate the cyberdream bokeh loop wallpaper (animated GIF for awww).

Renders soft drifting bokeh discs in palette colors over the dark base,
as a seamless loop. Colors are read from rice/palette.json.

Run (NixOS, no venv needed):
  nix-shell -p "python3.withPackages (p: [p.numpy p.pillow])" \
    --run "python3 rice/bokeh-wallpaper.py ~/Documents/Wallpaper-Bank/cyberdream-bokeh.gif"
"""

import json
import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image

REPO = Path(__file__).resolve().parent.parent
PALETTE = json.loads((REPO / "rice" / "palette.json").read_text())["colors"]

W, H = 960, 540
FRAMES = 100          # 10s loop
FPS = 10
SEED = 20260707       # deterministic — same gif every run


def hex_rgb(name):
    h = PALETTE[name]
    return np.array([int(h[i : i + 2], 16) for i in (0, 2, 4)], dtype=np.float64)


# dim ambient discs; mauve/cyan lead, pink/blue/lavender accents
DISC_COLORS = [
    ("mauve", 5), ("cyan", 4), ("blue", 3), ("lavender", 2), ("neon-pink", 2),
]


def make_discs(rng):
    discs = []
    for name, count in DISC_COLORS:
        for _ in range(count):
            discs.append({
                "color": hex_rgb(name),
                "cx": rng.uniform(0, W),
                "cy": rng.uniform(0, H),
                # big + dim (out-of-focus foreground) or small + brighter
                "r": rng.uniform(18, 40) if rng.random() < 0.5 else rng.uniform(55, 120),
                "amp_x": rng.uniform(15, 60),
                "amp_y": rng.uniform(10, 40),
                # integer cycles per loop -> seamless
                "kx": rng.choice([1, 1, 2]),
                "ky": rng.choice([1, 1, 2]),
                "phx": rng.uniform(0, 2 * math.pi),
                "phy": rng.uniform(0, 2 * math.pi),
                "kb": rng.choice([1, 2, 3]),          # brightness pulse cycles
                "phb": rng.uniform(0, 2 * math.pi),
                "base_i": rng.uniform(0.10, 0.22),
            })
    return discs


def background():
    """Subtle vertical crust->base gradient."""
    top, bottom = hex_rgb("crust"), hex_rgb("base")
    t = np.linspace(0, 1, H)[:, None, None]
    return top * (1 - t) + bottom * t


def render_frame(discs, bg, t):
    img = bg.copy() * np.ones((H, W, 3))
    for d in discs:
        cx = d["cx"] + d["amp_x"] * math.sin(2 * math.pi * d["kx"] * t + d["phx"])
        cy = d["cy"] + d["amp_y"] * math.sin(2 * math.pi * d["ky"] * t + d["phy"])
        r = d["r"]
        pulse = 0.75 + 0.25 * math.sin(2 * math.pi * d["kb"] * t + d["phb"])
        intensity = d["base_i"] * pulse

        pad = int(r * 2.2)
        x0, x1 = max(0, int(cx) - pad), min(W, int(cx) + pad)
        y0, y1 = max(0, int(cy) - pad), min(H, int(cy) + pad)
        if x0 >= x1 or y0 >= y1:
            continue
        yy, xx = np.mgrid[y0:y1, x0:x1]
        dist = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
        # bokeh disc: soft sigmoid edge + faint halo past the rim
        disc = 1.0 / (1.0 + np.exp((dist - r) / (r * 0.10)))
        halo = 0.25 * np.exp(-((dist / (r * 1.6)) ** 2))
        falloff = (disc + halo) * intensity
        img[y0:y1, x0:x1] += falloff[:, :, None] * d["color"]
    return np.clip(img, 0, 255).astype(np.uint8)


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else REPO / "cyberdream-bokeh.gif"
    out.parent.mkdir(parents=True, exist_ok=True)
    rng = random.Random(SEED)
    discs = make_discs(rng)
    bg = background()

    frames = [
        Image.fromarray(render_frame(discs, bg, i / FRAMES)) for i in range(FRAMES)
    ]
    # single global palette keeps size down and avoids per-frame flicker
    first = frames[0].quantize(colors=256, method=Image.MEDIANCUT)
    frames = [f.quantize(palette=first, dither=Image.FLOYDSTEINBERG) for f in frames]
    frames[0].save(
        out,
        save_all=True,
        append_images=frames[1:],
        duration=int(1000 / FPS),
        loop=0,
        optimize=True,
    )
    print(f"wrote {out} ({out.stat().st_size / 1e6:.1f} MB, {FRAMES} frames @ {FPS}fps)")

    preview = out.with_suffix(".preview.png")
    Image.fromarray(render_frame(discs, bg, 0.0)).save(preview)
    print(f"wrote {preview}")


if __name__ == "__main__":
    main()
