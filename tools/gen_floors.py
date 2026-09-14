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


def lava(base, glow, seed, width, strength, grain_amp=6, core=None):
    """Rocha com fendas incandescentes (fendas = curvas de nivel 0 do ruido)."""
    n = tileable_noise(seed, waves=7)
    g = grain(seed, grain_amp)
    vein = np.exp(-(n / width) ** 2) * strength
    img = np.zeros((T, T, 3))
    base = np.array(base, float)
    glow = np.array(glow, float)
    for c in range(3):
        img[:, :, c] = base[c] + g + glow[c] * vein
    if core is not None:
        coremask = np.exp(-(n / (width * 0.4)) ** 2) * strength
        core = np.array(core, float)
        for c in range(3):
            img[:, :, c] += core[c] * coremask
    return Image.fromarray(np.clip(img, 0, 255).astype("uint8"), "RGB").convert("RGBA")


def magic(base, patch, glow, seed, width, strength, stars, star_col, grain_amp=5):
    """Solo arcano: nebulosa (blend por ruido) + veios brilhantes + estrelas."""
    n = tileable_noise(seed, waves=6)
    n2 = tileable_noise(seed + 50, waves=8)
    g = grain(seed, grain_amp)
    img = np.zeros((T, T, 3))
    base = np.array(base, float)
    patch = np.array(patch, float)
    glow = np.array(glow, float)
    blend = np.clip((n + 1) / 2, 0, 1)
    vein = np.exp(-(n2 / width) ** 2) * strength
    for c in range(3):
        img[:, :, c] = base[c] + (patch[c] - base[c]) * blend + g + glow[c] * vein
    im = Image.fromarray(np.clip(img, 0, 255).astype("uint8"), "RGB").convert("RGBA")
    px = im.load()
    r = np.random.default_rng(seed + 7)
    for _ in range(stars):
        x = int(r.integers(0, T))
        y = int(r.integers(0, T))
        px[x, y] = (star_col[0], star_col[1], star_col[2], 255)
    return im


TILES = {
    "plaza_grey": lambda: tiled_slabs(seed=11),
    "sand_light": lambda: soil((222, 205, 158), (232, 216, 171), 8, 6, seed=1, patch_str=0.35),
    "sand_gold": lambda: soil((205, 180, 120), (220, 196, 138), 10, 7, seed=5, patch_str=0.5, specks=(40, np.array([-18, -16, -12]))),
    "grass": lambda: soil((92, 140, 66), (74, 120, 52), 10, 8, seed=3, patch_str=0.55),
    "grass_dark": lambda: soil((70, 116, 54), (52, 96, 44), 9, 7, seed=9, patch_str=0.6, specks=(30, np.array([18, 26, 10]))),
    "lava_1": lambda: lava((52, 44, 42), (210, 80, 18), seed=2, width=0.07, strength=0.55),
    "lava_2": lambda: lava((34, 26, 24), (240, 110, 20), seed=4, width=0.11, strength=1.0, core=(80, 60, 10)),
    "magic_1": lambda: magic((38, 32, 66), (72, 48, 116), (120, 90, 220), seed=6, width=0.06, strength=0.5, stars=18, star_col=(210, 210, 255)),
    "magic_2": lambda: magic((44, 28, 92), (120, 64, 180), (150, 120, 255), seed=8, width=0.09, strength=0.9, stars=34, star_col=(230, 220, 255)),
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
