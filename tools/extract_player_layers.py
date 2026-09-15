#!/usr/bin/env python3
"""Extrai do pack Heroes99 SÓ as camadas precisas para o seletor de estilo
do jogador, para res://assets/heroes_layers/. O jogo compõe o boneco do
jogador em runtime (cor de cabelo/roupa à escolha); os 99 da IA continuam
nas folhas já prontas em assets/fighters/.

Uso:
    python3 tools/extract_player_layers.py /caminho/para/Heroes99_v1.2

Por classe copia: skin.png, face.png, weapon_bot/top.png (fixos), e
hair_bot/top_c<c>.png + cloth_bot/top_c<c>.png para cada cor oferecida.
As cores das amostras da UI são amostradas em runtime das próprias camadas
(Main._layer_avg_color), sem ficheiros extra. As camadas fixas (pele/cara/
arma) e a ORDEM das camadas seguem tools/compose_fighters.py.
"""
import argparse
import os
import shutil

# Composição fixa por classe (igual a compose_fighters.CLASSES, sem Zombie).
CLASSES = {
    "Bruto":      dict(skin=2, face=1, hair="m2", cloth=11, weapon=1),
    "Tanque":     dict(skin=2, face=1, hair="m5", cloth=15, weapon=1),
    "Assassino":  dict(skin=2, face=1, hair="m7", cloth=8,  weapon=3),
    "Barbaro":    dict(skin=3, face=1, hair="m9", cloth=16, weapon=2),
    "Lanceiro":   dict(skin=2, face=1, hair="f3", cloth=5,  weapon=4),
    "Necromante": dict(skin=1, face=1, hair="f6", cloth=9,  weapon=5, weapon_c=3),
    "Sacerdote":  dict(skin=2, face=1, hair="f1", cloth=10, weapon=5, weapon_c=1),
}
HAIR_COLORS = [1, 2, 3, 4, 5, 6, 7, 8]
CLOTH_COLORS = [1, 2, 3, 4, 5, 6, 7, 8]

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "heroes_layers")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("pack")
    args = ap.parse_args()
    src = args.pack
    out = os.path.abspath(OUT)

    def sp(*p):
        return os.path.join(src, *p)

    def weap_path(n, part, c):
        plain = sp("weapon", f"weapon{n}", f"weapon{n}_{part}", f"weapon{n}_{part}.png")
        if os.path.exists(plain):
            return plain
        return sp("weapon", f"weapon{n}", f"weapon{n}_{part}", f"weapon{n}_c{c}_{part}.png")

    for name, s in CLASSES.items():
        d = os.path.join(out, name)
        os.makedirs(d, exist_ok=True)
        shutil.copy(sp("skin", f"skin_c{s['skin']}.png"), os.path.join(d, "skin.png"))
        shutil.copy(sp("face", f"face_c{s['face']}.png"), os.path.join(d, "face.png"))
        wc = s.get("weapon_c", 1)
        shutil.copy(weap_path(s["weapon"], "bot", wc), os.path.join(d, "weapon_bot.png"))
        shutil.copy(weap_path(s["weapon"], "top", wc), os.path.join(d, "weapon_top.png"))
        for c in HAIR_COLORS:
            for part in ("bot", "top"):
                srcp = sp("hair", s["hair"], f"{s['hair']}_{part}", f"{s['hair']}_c{c}_{part}.png")
                shutil.copy(srcp, os.path.join(d, f"hair_{part}_c{c}.png"))
        for c in CLOTH_COLORS:
            for part in ("bot", "top"):
                srcp = sp("cloth", f"cloth{s['cloth']}", f"cloth{s['cloth']}_{part}", f"cloth{s['cloth']}_c{c}_{part}.png")
                shutil.copy(srcp, os.path.join(d, f"cloth_{part}_c{c}.png"))
        print("extracted", name)
    print("done ->", out)


if __name__ == "__main__":
    main()
