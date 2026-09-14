#!/usr/bin/env python3
"""Gera o logo pixel-art "TITAN ROYALE" em assets/ui/logo.png.

Uso: python3 tools/gen_logo.py

Fonte bitmap 5x7 feita a mao, engordada (dilatacao) e com cantos arredondados
para um look "chunky". Depois:
  - volume 3D: extrusao vermelha em diagonal + contorno escuro + brilho no topo;
  - perspetiva: keystone que estreita o topo e alarga o fundo, dando a sensacao
    de o logo se aproximar (mais perto de nos) em baixo.
Amarelo/vermelho do jogo, fundo transparente (assenta no fundo escuro do menu
e do boot splash). Tudo em blocos, escala por vizinho-mais-proximo.
"""
import os
import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui")

# Fonte bitmap "bold" 7x9 (tracos de 2 celulas, contadores/buracos abertos
# para as letras ficarem gordas mas legiveis). '1' = pixel cheio.
FONT = {
    "T": ["1111111", "1111111", "0011100", "0011100", "0011100", "0011100", "0011100", "0011100", "0011100"],
    "I": ["1111111", "1111111", "0011100", "0011100", "0011100", "0011100", "0011100", "1111111", "1111111"],
    "A": ["0011100", "0111110", "1100011", "1100011", "1111111", "1111111", "1100011", "1100011", "1100011"],
    "N": ["1100011", "1110011", "1111011", "1101111", "1100111", "1100011", "1100011", "1100011", "1100011"],
    "R": ["1111100", "1111110", "1100011", "1100011", "1111110", "1111100", "1101100", "1100110", "1100011"],
    "O": ["0111110", "1111111", "1100011", "1100011", "1100011", "1100011", "1100011", "1111111", "0111110"],
    "Y": ["1100011", "1100011", "0110110", "0011100", "0011100", "0011100", "0011100", "0011100", "0011100"],
    "L": ["1100000", "1100000", "1100000", "1100000", "1100000", "1100000", "1100000", "1111111", "1111111"],
    "E": ["1111111", "1111111", "1100000", "1111110", "1111110", "1100000", "1100000", "1111111", "1111111"],
    " ": ["0000000", "0000000", "0000000", "0000000", "0000000", "0000000", "0000000", "0000000", "0000000"],
}

GW, GH = 7, 9          # dimensoes do glifo em celulas
GAP = 2                # espaco entre letras (celulas)
LINE_GAP = 3           # espaco entre as duas linhas (celulas)
DEPTH = 3              # profundidade da extrusao 3D (celulas)
PAD = 3                # margem (celulas)
SCALE = 14             # pixels por celula (look pixelado)
TOP_F = 0.66           # largura relativa no topo (keystone); 1.0 = fundo cheio

# Cores
YELLOW = (244, 193, 69, 255)      # face (f4c145)
YELLOW_HI = (255, 224, 130, 255)  # brilho no topo da face
RED = (209, 69, 59, 255)          # lado da extrusao (d1453b)
RED_DARK = (150, 42, 38, 255)     # extrusao mais funda
OUTLINE = (34, 22, 16, 255)       # contorno escuro


def shift_valid(m, dy, dx):
    """Mascara que anula o wrap-around do np.roll nas bordas."""
    v = np.ones_like(m)
    if dy > 0:
        v[:dy, :] = False
    elif dy < 0:
        v[dy:, :] = False
    if dx > 0:
        v[:, :dx] = False
    elif dx < 0:
        v[:, dx:] = False
    return v


def shifted(m, dy, dx):
    return np.roll(np.roll(m, dy, 0), dx, 1) & shift_valid(m, dy, dx)


def dilate(m):
    """Dilata a mascara 1 celula em 8 direcoes."""
    out = m.copy()
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            out |= shifted(m, dy, dx)
    return out


def round_corners(m):
    """Corta os cantos convexos (2 vizinhos ortogonais adjacentes vazios)."""
    up, dn = shifted(m, -1, 0), shifted(m, 1, 0)
    lf, rt = shifted(m, 0, -1), shifted(m, 0, 1)
    corner = m & (((~up) & (~lf)) | ((~up) & (~rt)) | ((~dn) & (~lf)) | ((~dn) & (~rt)))
    return m & ~corner


def word_mask(word):
    """Mascara booleana (celulas) de uma palavra, ja engordada e arredondada."""
    w = len(word) * GW + (len(word) - 1) * GAP
    m = np.zeros((GH, w), bool)
    x = 0
    for ch in word:
        g = FONT[ch]
        for r in range(GH):
            for c in range(GW):
                if g[r][c] == "1":
                    m[r, x + c] = True
        x += GW + GAP
    # a fonte ja e "bold"; so arredonda os cantos convexos (sem fechar buracos)
    m = round_corners(m)
    return m


def place(canvas_mask, sub, top, left):
    canvas_mask[top:top + sub.shape[0], left:left + sub.shape[1]] |= sub


def keystone(img, top_f, bot_f):
    """Warp trapezoidal: cada linha e escalada em x (estreita no topo,
    larga no fundo), centrada. Sampling nearest mantem os blocos nitidos."""
    h, w = img.shape[:2]
    out = np.zeros_like(img)
    cx = (w - 1) / 2.0
    for y in range(h):
        f = top_f + (bot_f - top_f) * (y / max(h - 1, 1))
        xs = np.rint((np.arange(w) - cx) / f + cx).astype(int)
        ok = (xs >= 0) & (xs < w)
        out[y, ok] = img[y, xs[ok]]
    return out


def main():
    l1 = word_mask("TITAN")
    l2 = word_mask("ROYALE")
    inner_w = max(l1.shape[1], l2.shape[1])
    lh = l1.shape[0]  # altura da linha (ja engordada)
    inner_h = lh + LINE_GAP + lh

    margin = PAD + DEPTH + 1
    W = inner_w + margin * 2
    H = inner_h + margin * 2

    face = np.zeros((H, W), bool)
    place(face, l1, margin, margin + (inner_w - l1.shape[1]) // 2)
    place(face, l2, margin + lh + LINE_GAP, margin + (inner_w - l2.shape[1]) // 2)

    outline = dilate(face) & ~face

    img = np.zeros((H, W, 4), np.uint8)  # transparente

    # 1) extrusao 3D: copias deslocadas, da mais funda para a mais rasa
    for d in range(DEPTH, 0, -1):
        sh = shifted(face, d, d) & ~face
        img[sh] = RED if d == 1 else RED_DARK
    sh_o = shifted(outline, DEPTH, DEPTH) & ~face & ~shifted(face, 1, 1)
    img[sh_o] = RED_DARK

    # 2) contorno escuro à volta da face
    img[outline] = OUTLINE

    # 3) face amarela + brilho na linha de cima de cada glifo
    img[face] = YELLOW
    hi = face & ~shifted(face, 1, 0)
    img[hi] = YELLOW_HI

    # escala por vizinho-mais-proximo (blocos) e depois keystone (perspetiva)
    im = Image.fromarray(img, "RGBA").resize((W * SCALE, H * SCALE), Image.NEAREST)
    warped = keystone(np.asarray(im), TOP_F, 1.0)
    im = Image.fromarray(warped, "RGBA")

    os.makedirs(os.path.abspath(OUT), exist_ok=True)
    p = os.path.join(os.path.abspath(OUT), "logo.png")
    im.save(p)
    print("wrote", p, im.size)


if __name__ == "__main__":
    main()
