class_name Fighter
extends Node2D
# Um lutador. Guarda estado e desenha-se a si próprio.
# Não decide nada sozinho — a Arena conduz a simulação e o
# 'controller' produz a intenção. Trocar de sprite/animação
# mais tarde é só mexer no _draw() ou pôr um AnimatedSprite2D.

var cls: String = ""
var team: int = 0
var controller: Controller = null
var color: Color = Color.WHITE
var display_name: String = ""

var max_hp: float = 100.0
var hp: float = 100.0
var atk: float = 10.0
var def: float = 0.0
var speed: float = 80.0        # px/s
var attack_range: float = 24.0
var cd: float = 0.6            # segundos entre ataques
var cd_timer: float = 0.0
var size: float = 8.0
var alive: bool = true
var is_titan: bool = false
var target = null

# necromante / sacerdote
var is_necro: bool = false
var is_zombie: bool = false
var owner_fighter = null
var contender: bool = true     # false = não pode vencer nem virar titã (zombies)
var regen_pct: float = 0.0
var regen_every: float = 0.0
var regen_timer: float = 0.0

# dash
var dash_timer: float = 0.0
var dash_cd: float = 0.0

# equipamento
var weapons: Array = []        # percentagens (1..10), até 2
var has_armor: bool = false
var amulets: Array = []        # "heal" / "crit", até 2
var amulet_heal_timer: float = 0.0

var flash: float = 0.0

func atk_mult() -> float:
	var s: float = 0.0
	for w in weapons:
		s += float(w)
	return 1.0 + s / 100.0

func crit_chance() -> float:
	var n: int = 0
	for a in amulets:
		if a == "crit":
			n += 1
	return n * 0.10

func dmg_reduction() -> float:
	return 0.10 if has_armor else 0.0

func is_player() -> bool:
	return controller is PlayerController

func _draw() -> void:
	var s: float = size
	# sombra
	draw_circle(Vector2(0, s * 0.7), s * 0.6, Color(0, 0, 0, 0.25))
	if is_titan:
		draw_circle(Vector2.ZERO, s * 1.6, Color(0.61, 0.42, 1.0, 0.18))
	if is_zombie:
		draw_arc(Vector2.ZERO, s * 1.25, 0, TAU, 12, Color(0.48, 0.78, 0.31, 0.5), 1.5)
	if is_player():
		draw_arc(Vector2.ZERO, s * 1.5, 0, TAU, 16, Color("f4c145"), 2.5)
	# corpo
	draw_circle(Vector2.ZERO, s, Color.WHITE if flash > 0.0 else color)
	draw_arc(Vector2.ZERO, s, 0, TAU, 14, Color(0, 0, 0, 0.5), 1.2)
	# barra de vida por cima (só nos que não são o jogador — esse vê no HUD)
	if not is_player():
		var bw: float = max(s * 2.2, 16.0)
		var pct: float = clamp(hp / max_hp, 0.0, 1.0)
		var by: float = -s - (9.0 if is_titan else 6.0)
		draw_rect(Rect2(-bw / 2.0, by, bw, 3.0), Color(0, 0, 0, 0.55))
		var col: Color = Color("6dd36a") if pct > 0.5 else (Color("f4c145") if pct > 0.25 else Color("d1453b"))
		draw_rect(Rect2(-bw / 2.0, by, bw * pct, 3.0), col)
	else:
		var font: Font = ThemeDB.fallback_font
		draw_string(font, Vector2(-14, -s - 8.0), display_name, HORIZONTAL_ALIGNMENT_CENTER, 28, 11, Color("f4c145"))
