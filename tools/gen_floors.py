#!/usr/bin/env python3
"""Gera os tiles de chao da arena (seamless, 64x64) em assets/arena/.

Uso: python3 tools/gen_floors.py

Escreve: plaza_grey, sand_light, sand_gold, grass, grass_dark.
(stone_floor.png foi o primeiro tile e mantem-se; ver historico.)
As folhas sao tileaveis: o ruido de baixa frequencia usa vetores de onda
inteiros (periodicos no tile) e o grao e ruido por-pixel (seamless).
"""
import os
import random
import numpy as np
from PIL import Image

T = 64
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "arena")


def tileable_noise(seed, waves=6, kmax=4):
    r = np.random.default_rng(seed)
    xs, ys = np.meshgrid(np.arange(T), np.arange(T))
    acc = np.zeros((T, T))
    for _ in range(waves):
        kx = r.integers(1, kmax + 1)
        ky = r.integers(0, kmax + 1)
        if r.random() < 0.5:
            ky = -ky
        ph = r.random() * 2 * np.pi
        amp = 1.0 / (abs(kx) + abs(ky) + 1)
        acc += amp * np.sin(2 * np.pi * (kx * xs + ky * ys) / T + ph)
    acc -= acc.min()
    acc /= (acc.max() + 1e-9)
    return acc * 2 - 1


def grain(seed, amp):
    r = np.random.default_rng(seed + 999)
    return (r.random((T, T)) * 2 - 1) * amp


def soil(base, patch_col, low_amp, grain_amp, seed, patch_str=0.5, specks=None):
    n = tileable_noise(seed)
    g = grain(seed, grain_amp)
    base = np.array(base, float)
    patch = np.array(patch_col, float)
    img = np.zeros((T, T, 3))
    for c in range(3):
        img[:, :, c] = base[c] + (patch[c] - base[c]) * np.clip((-n) * patch_str, 0, 1) + n * low_amp + g
    if specks:
        r = np.random.default_rng(seed + 7)
        for _ in range(specks[0]):
            x = r.integers(0, T)
            y = r.integers(0, T)
            img[y, x, :] += specks[1]
    return Image.fromarray(np.clip(img, 0, 255).astype("uint8"), "RGB").convert("RGBA")


def tiled_slabs(seed=11, cell=32, mort=2, base=(142, 143, 148), mortar=(84, 85, 92)):
    """Lajes grandes cinzentas com juntas e bisel (praca/castelo)."""
    r = random.Random(seed)
    img = Image.new("RGBA", (T, T), (0, 0, 0, 255))
    px = img.load()

    def slab_col(cx, cy):
        rr = random.Random(cx * 7919 + cy * 104729 + seed)
        j = rr.randint(-10, 8)
        return (base[0] + j, base[1] + j, base[2] + j)

    for y in range(T):
        for x in range(T):
            if (x % cell) < mort or (y % cell) < mort:
                c = mortar
                n = r.randint(-6, 6)
                px[x, y] = (max(0, min(255, c[0] + n)), max(0, min(255, c[1] + n)), max(0, min(255, c[2] + n)), 255)
            else:
                c = slab_col(x // cell, y // cell)
                lx, ly = x % cell, y % cell
                bev = 0
                if lx < 3 or ly < 3:
                    bev += 10
                if lx > cell - 4 or ly > cell - 4:
                    bev -= 12
                n = r.randint(-6, 6) + bev
                px[x, y] = (max(0, min(255, c[0] + n)), max(0, min(255, c[1] + n)), max(0, min(255, c[2] + n)), 255)
    for _ in range(8):
        x = r.randint(0, T - 1)
        y = r.randint(0, T - 1)
        d = r.randint(-24, -12)
        rr, gg, bb, aa = px[x, y]
        px[x, y] = (max(0, rr + d), max(0, gg + d), max(0, bb + d), 255)
    return img


TILES = {
    "plaza_grey": lambda: tiled_slabs(seed=11),
    "sand_light": lambda: soil((222, 205, 158), (232, 216, 171), 8, 6, seed=1, patch_str=0.35),
    "sand_gold": lambda: soil((205, 180, 120), (220, 196, 138), 10, 7, seed=5, patch_str=0.5, specks=(40, np.array([-18, -16, -12]))),
    "grass": lambda: soil((92, 140, 66), (74, 120, 52), 10, 8, seed=3, patch_str=0.55),
    "grass_dark": lambda: soil((70, 116, 54), (52, 96, 44), 9, 7, seed=9, patch_str=0.6, specks=(30, np.array([18, 26, 10]))),
}


def main():
    out = os.path.abspath(OUT)
    os.makedirs(out, exist_ok=True)
    for name, fn in TILES.items():
        p = os.path.join(out, name + ".png")
        fn().save(p)
        print("wrote", p)


if __name__ == "__main__":
    main()
