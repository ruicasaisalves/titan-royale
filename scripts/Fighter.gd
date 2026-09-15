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

# direção/estado usados pela animação (a Arena preenche-os no tick)
var facing: int = 1            # 1 = direita, -1 = esquerda
var moving: bool = false

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
var dash_cd_max: float = 3.0        # recarga do dash (segundos)

# ataque especial (1 por classe) + efeitos temporários que ele ativa.
# A lógica vive na Arena; aqui guarda-se só o estado.
var special_cd: float = 0.0
var special_cd_max: float = 5.0     # recarga do especial (itens/trinkets podem reduzir)
var special_armed: bool = false     # golpe seguinte potenciado (Bruto/Assassino/Lanceiro/Necromante)
var guard_timer: float = 0.0        # Tanque: reduz dano recebido + reflete
var rage_timer: float = 0.0         # Bárbaro: +dano/velocidade (escala com vida perdida)
var poison_timer: float = 0.0       # veneno ativo nesta vítima (Necromante)
var poison_dps: float = 0.0         # dano/segundo do veneno
var poison_src = null               # necromante que aplicou o veneno (crédito do zombie)

# equipamento
var weapons: Array = []        # percentagens (1..10), até 2
var has_armor: bool = false
var amulets: Array = []        # "heal" / "crit", até 2
var amulet_heal_timer: float = 0.0

var flash: float = 0.0

# ---------- animação (sprites do pack Heroes99) ----------
# Folha por classe em res://assets/fighters/<cls>.png, grelha 8x17 (célula 100x40).
# Cada animação: [linha, coluna_inicial, n_frames, fps, loop].
const SHEET_DIR := "res://assets/fighters/"
const CELL_W := 100
const CELL_H := 40
const ART_H := 26.0            # altura aproximada da figura dentro da célula
const CHAR_H_MULT := 3.2       # altura da figura no ecrã ≈ size * este fator
const ANIMS := {
	"idle":   [0, 0, 6, 8.0, true],
	"run":    [2, 0, 8, 12.0, true],
	"attack": [5, 0, 6, 14.0, false],
	"cast":   [10, 0, 5, 12.0, false],
	"dash":   [14, 0, 8, 16.0, true],
	"die":    [13, 0, 5, 10.0, false],
}
# SpriteFrames partilhado por classe (construído uma vez, reutilizado por todos).
static var _frames_cache: Dictionary = {}
var _sprite: AnimatedSprite2D = null
var _attack_name: String = "attack"
var _attack_t: float = 0.0
# Folha composta em runtime (só o jogador; a IA usa a folha da classe).
# Tem de ser definida ANTES de add_child (antes de _ready correr).
var sheet_override: Texture2D = null

func _ready() -> void:
	var frames: SpriteFrames = _frames_from_texture(sheet_override) if sheet_override != null else _get_frames(cls)
	if frames == null:
		return
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames
	_sprite.show_behind_parent = true   # corpo por baixo do _draw (barra de vida, aros)
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel art nítida
	add_child(_sprite)
	# magos brandem cajado (animação de "casting"); os restantes golpeiam
	_attack_name = "cast" if cls in ["Necromante", "Sacerdote"] else "attack"
	_sprite.play("idle")

func _process(delta: float) -> void:
	if _sprite == null:
		return
	# escala acompanha o size (os titãs crescem ×10)
	var k: float = size * CHAR_H_MULT / ART_H
	_sprite.scale = Vector2(k, k)
	_sprite.flip_h = facing < 0
	# tint: esverdeado para zombies, clarão branco ao levar dano
	var mod: Color = Color(0.55, 0.85, 0.45) if is_zombie else Color.WHITE
	if flash > 0.0:
		mod = Color(1.7, 1.7, 1.7)
	_sprite.modulate = mod
	# escolha da animação: ataque > dash > correr > parado
	if _attack_t > 0.0:
		_attack_t -= delta
	elif dash_timer > 0.0:
		if _sprite.animation != "dash":
			_sprite.play("dash")
	else:
		var want: String = "run" if moving else "idle"
		if _sprite.animation != want:
			_sprite.play(want)

# Chamado pela Arena quando o lutador desfere um ataque.
func play_attack() -> void:
	if _sprite == null:
		return
	var d: Array = ANIMS[_attack_name]
	_attack_t = float(d[2]) / float(d[3])
	_sprite.play(_attack_name)

# Cria um "cadáver" cosmético: um sprite solto que toca a animação de morte
# (linha "die" da folha) e se auto-liberta no fim. Fica DESACOPLADO do sim — o
# lutador é removido na mesma no próprio tick; isto é só apresentação (e assim
# é seguro para o netcode futuro). Devolve o nó para a Arena o adicionar.
func make_corpse() -> Node2D:
	if _sprite == null or _sprite.sprite_frames == null:
		return null
	if not _sprite.sprite_frames.has_animation("die"):
		return null
	var c := AnimatedSprite2D.new()
	c.sprite_frames = _sprite.sprite_frames   # partilhado (mesma folha)
	c.centered = true
	c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	c.scale = _sprite.scale
	c.flip_h = _sprite.flip_h
	c.position = position
	c.z_index = int(position.y)
	c.modulate = Color(0.55, 0.85, 0.45) if is_zombie else Color.WHITE
	c.animation_finished.connect(c.queue_free)
	c.play("die")
	return c

func _get_frames(key: String) -> SpriteFrames:
	if key == "":
		return null
	if _frames_cache.has(key):
		return _frames_cache[key]
	var path: String = SHEET_DIR + key + ".png"
	if not ResourceLoader.exists(path):
		_frames_cache[key] = null
		return null
	var tex: Texture2D = load(path)
	var sf := _frames_from_texture(tex)
	_frames_cache[key] = sf
	return sf

# Constrói um SpriteFrames a partir de uma textura-folha (partilhada pela
# classe ou composta em runtime para o jogador) fatiando as ANIMS.
func _frames_from_texture(tex: Texture2D) -> SpriteFrames:
	if tex == null:
		return null
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for name in ANIMS:
		var d: Array = ANIMS[name]
		sf.add_animation(name)
		sf.set_animation_speed(name, d[3])
		sf.set_animation_loop(name, d[4])
		for i in range(d[2]):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2((d[1] + i) * CELL_W, d[0] * CELL_H, CELL_W, CELL_H)
			sf.add_frame(name, at)
	return sf

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
	# corpo: só quando não há sprite (fallback sem os assets)
	if _sprite == null:
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
