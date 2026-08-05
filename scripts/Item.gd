class_name Item
extends Node2D
# Objeto que aparece no chão durante a royale. Quem passar por cima
# apanha, se tiver espaço no slot (2 armas / 1 armadura / 2 amuletos).

var kind: String = "weapon"   # weapon / armor / amulet
var sub: String = ""          # heal / crit  (para amuletos)
var val: int = 0              # % de ataque (para armas)
var size: float = 12.0
var t: float = 0.0

func _draw() -> void:
	var pulse: float = 1.0 + sin(t) * 0.12
	var col: Color = Color("f4c145")
	var letter: String = "W"
	match kind:
		"weapon":
			col = Color("d1453b"); letter = "W"
		"armor":
			col = Color("5a86b4"); letter = "A"
		"amulet":
			if sub == "heal":
				col = Color("6dd36a"); letter = "+"
			else:
				col = Color("f4c145"); letter = "!"
	draw_circle(Vector2.ZERO, size * pulse, Color(col.r, col.g, col.b, 0.22))
	draw_arc(Vector2.ZERO, size * pulse, 0, TAU, 24, col, 2.0)
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(-6, 6), letter, HORIZONTAL_ALIGNMENT_CENTER, 12, 16, col)
