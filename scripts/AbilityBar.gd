extends Control
# Indicador de recargas: mostra a prontidão do DASH e do ESPECIAL com um
# "relógio" radial — cinzento + varrimento enquanto recarrega, aceso quando
# está pronto a usar. Lê o estado diretamente do jogador (poll por frame),
# por isso não precisa de sinais nem sabe da simulação.

var arena = null   # Main preenche isto ao construir a HUD

const DASH_COL := Color("4fd6c9")
const SPEC_COL := Color("f4c145")
const R := 22.0        # raio de cada chip
const GAP := 16.0      # espaço entre chips

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if arena == null or arena.player == null or not arena.player.alive:
		return
	var p = arena.player
	_chip(Vector2(R, R), DASH_COL, "»", p.dash_cd, p.dash_cd_max, "shift")
	_chip(Vector2(R * 3.0 + GAP, R), SPEC_COL, "★", p.special_cd, p.special_cd_max, "Q")

# Desenha um chip: anel + varrimento do que falta recarregar + glifo + tecla.
func _chip(c: Vector2, col: Color, glyph: String, cd: float, cd_max: float, key: String) -> void:
	var is_ready: bool = cd <= 0.0
	var ring: Color = col if is_ready else Color(col.r, col.g, col.b, 0.35)
	draw_circle(c, R, Color(0, 0, 0, 0.5))
	# varrimento radial (relógio) do tempo que falta
	if not is_ready and cd_max > 0.0:
		var frac: float = clamp(cd / cd_max, 0.0, 1.0)
		var pts := PackedVector2Array()
		pts.append(c)
		var start: float = -PI / 2.0
		var steps: int = max(2, int(ceil(frac * 26.0)))
		for i in range(steps + 1):
			var a: float = start + TAU * frac * (float(i) / steps)
			pts.append(c + Vector2(cos(a), sin(a)) * R)
		draw_colored_polygon(pts, Color(0.08, 0.08, 0.1, 0.72))
	draw_arc(c, R, 0.0, TAU, 28, ring, 2.5)
	var font: Font = ThemeDB.fallback_font
	var gcol: Color = col if is_ready else Color(1, 1, 1, 0.45)
	draw_string(font, c + Vector2(-R, 6.0), glyph, HORIZONTAL_ALIGNMENT_CENTER, R * 2.0, 18, gcol)
	# tecla (só no desktop; no tátil os botões já a substituem)
	if not Touch.enabled:
		draw_string(font, c + Vector2(-R, R + 12.0), key, HORIZONTAL_ALIGNMENT_CENTER, R * 2.0, 10, Color(0.7, 0.72, 0.8))
