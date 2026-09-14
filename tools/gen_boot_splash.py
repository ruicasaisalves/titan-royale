#!/usr/bin/env python3
"""Compoe o boot splash a partir do logo do jogo.

Uso: python3 tools/gen_boot_splash.py

O boot splash do motor mostrava o logo (1024x544) quase a toda a largura e
descentrado. Aqui centramos o logo, mais pequeno, sobre uma tela do tamanho
da janela (960x600) com o fundo escuro do jogo -> logo fica centrado e com
folga. Nao mexe em assets/ui/logo.png (arte do autor).
"""
import os
from PIL import Image

BASE = os.path.join(os.path.dirname(__file__), "..", "assets", "ui")
CANVAS = (960, 600)                 # tamanho da janela (project.godot)
BG = (14, 16, 23, 255)             # ~ Color(0.055, 0.063, 0.09)
LOGO_W_FRAC = 0.62                  # largura do logo relativa a tela


def main():
    base = os.path.abspath(BASE)
    logo = Image.open(os.path.join(base, "logo.png")).convert("RGBA")
    target_w = int(CANVAS[0] * LOGO_W_FRAC)
    scale = target_w / logo.width
    target_h = int(logo.height * scale)
    logo = logo.resize((target_w, target_h), Image.LANCZOS)

    canvas = Image.new("RGBA", CANVAS, BG)
    x = (CANVAS[0] - target_w) // 2
    y = (CANVAS[1] - target_h) // 2
    canvas.alpha_composite(logo, (x, y))

    out = os.path.join(base, "boot_splash.png")
    canvas.save(out)
    print("wrote", out, canvas.size)


if __name__ == "__main__":
    main()
