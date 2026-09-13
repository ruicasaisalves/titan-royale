#!/usr/bin/env python3
"""Compoe as folhas de sprite dos lutadores a partir do pack Heroes99.

O pack (comprado, com licenca comercial) NAO esta no repositorio. Passa a
pasta extraida do pack e este script empilha as camadas por classe e escreve
as folhas em assets/fighters/<Classe>.png.

Uso:
    python3 tools/compose_fighters.py /caminho/para/Heroes99_v1.2

Ordem das camadas (baixo->cima): weapon_bot, skin, face, hair_bot,
cloth_bot, hair_top, cloth_top, weapon_top.  Folha 800x680, grelha 8x17
(celula 100x40).  Para afinar o visual de uma classe, edita CLASSES.

Cores cloth: 1=verm 2=azul 3=verde 4=roxo 5=castanho 6=dourado 7=preto 8=branco
Armas: 1=espada 2=machado 3=adaga 4=lanca 5=cajado
"""
import argparse
import os
from PIL import Image

# Chave interna da classe -> composicao. (Zombie e tingido de verde em engine.)
CLASSES = {
    "Bruto":      dict(skin=2, face=1, hair="m2", hair_c=3, cloth=11, cloth_bot_c=8, cloth_top_c=8, weapon=1),
    "Tanque":     dict(skin=2, face=1, hair="m5", hair_c=2, cloth=15, cloth_bot_c=2, cloth_top_c=2, weapon=1),
    "Assassino":  dict(skin=2, face=1, hair="m7", hair_c=1, cloth=8,  cloth_bot_c=1, cloth_top_c=1, weapon=3),
    "Barbaro":    dict(skin=3, face=1, hair="m9", hair_c=4, cloth=16, cloth_bot_c=5, cloth_top_c=5, weapon=2),
    "Arqueiro":   dict(skin=2, face=1, hair="f3", hair_c=3, cloth=5,  cloth_bot_c=3, cloth_top_c=3, weapon=4),
    "Necromante": dict(skin=1, face=1, hair="f6", hair_c=7, cloth=9,  cloth_bot_c=7, cloth_top_c=7, weapon=5, weapon_c=3),
    "Sacerdote":  dict(skin=2, face=1, hair="f1", hair_c=6, cloth=10, cloth_bot_c=8, cloth_top_c=6, weapon=5, weapon_c=1),
    "Zombie":     dict(skin=5, face=1, hair="m3", hair_c=5, cloth=16, cloth_bot_c=5, cloth_top_c=5, weapon=0),
}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("pack", help="pasta extraida do pack (ex.: .../Heroes99_v1.2)")
    ap.add_argument("-o", "--out", default=os.path.join(os.path.dirname(__file__), "..", "assets", "fighters"))
    args = ap.parse_args()
    src = args.pack
    out = os.path.abspath(args.out)

    def L(path):
        return Image.open(os.path.join(src, path)).convert("RGBA")

    def skin(c):
        return L(f"skin/skin_c{c}.png")

    def face(c):
        return L(f"face/face_c{c}.png")

    def hair(style, c, part):
        return L(f"hair/{style}/{style}_{part}/{style}_c{c}_{part}.png")

    def cloth(n, c, part):
        return L(f"cloth/cloth{n}/cloth{n}_{part}/cloth{n}_c{c}_{part}.png")

    def weap(n, part, c=1):
        plain = f"weapon/weapon{n}/weapon{n}_{part}/weapon{n}_{part}.png"
        if os.path.exists(os.path.join(src, plain)):
            return L(plain)
        return L(f"weapon/weapon{n}/weapon{n}_{part}/weapon{n}_c{c}_{part}.png")

    def compose(spec):
        base = Image.new("RGBA", (800, 680), (0, 0, 0, 0))
        if spec.get("weapon"):
            base.alpha_composite(weap(spec["weapon"], "bot", spec.get("weapon_c", 1)))
        base.alpha_composite(skin(spec["skin"]))
        if spec.get("face"):
            base.alpha_composite(face(spec["face"]))
        if spec.get("hair"):
            base.alpha_composite(hair(spec["hair"], spec["hair_c"], "bot"))
        if spec.get("cloth"):
            base.alpha_composite(cloth(spec["cloth"], spec["cloth_bot_c"], "bot"))
        if spec.get("hair"):
            base.alpha_composite(hair(spec["hair"], spec["hair_c"], "top"))
        if spec.get("cloth"):
            base.alpha_composite(cloth(spec["cloth"], spec["cloth_top_c"], "top"))
        if spec.get("weapon"):
            base.alpha_composite(weap(spec["weapon"], "top", spec.get("weapon_c", 1)))
        return base

    os.makedirs(out, exist_ok=True)
    for name, spec in CLASSES.items():
        p = os.path.join(out, f"{name}.png")
        compose(spec).save(p)
        print("wrote", p)


if __name__ == "__main__":
    main()
