class_name Arena
extends Node2D
# ============================================================
#  O CORAÇÃO DO JOGO. A Arena é a simulação AUTORITÁRIA:
#  corre o tick em _physics_process (passo fixo a 60 Hz, ótimo
#  para netcode determinista mais tarde), na ordem:
#    1) cada controller produz a sua Intent
#    2) aplicar movimento    3) separação
#    4) resolver ataques     5) regeneração/timers
#    6) transições de fase
#  Nada aqui sabe se um lutador é IA ou humano — só aplica Intents.
# ============================================================

signal alive_changed(n)
signal phase_changed(name)
signal player_hp_changed(pct)
signal show_banner(big, sub, dead)

enum Phase { IDLE, MELEE, TRANSITION, TITAN, VICTORY }

const ZOMBIE_COLOR := Color("5f7a3a")
# Adversários na fase royale. Baixado temporariamente de 99 para 25 para
# testar no telemóvel — sobe quando a performance estiver afinada.
const OPPONENTS := 25

var fighters: Array = []
var items: Array = []
var grid := SpatialGrid.new()
var world_size := Vector2(960, 600)

var phase: int = Phase.IDLE
var arena_tint: float = 0.0
var transition_timer: float = 0.0
var item_timer: float = 0.0
var id_counter: int = 0
var player: Fighter = null
var popups: Array = []          # {pos, text, life, col}
var running: bool = false
var _player_prev_alive: bool = true

# Temas de chão (tiles seamless em assets/arena/): cada tema define o chão
# da fase 1 (royale) e da fase 2 (titãs). Cada partida sorteia um tema.
const FLOOR_THEMES := {
	"Castelo": ["stone_floor", "plaza_grey"],
	"Areia": ["sand_light", "sand_gold"],
	"Natureza": ["grass", "grass_dark"],
}
var _floor_stage1: Texture2D = null
var _floor_stage2: Texture2D = null

func _ready() -> void:
	world_size = get_viewport_rect().size
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pick_floors()

func _pick_floors() -> void:
	var themes: Array = FLOOR_THEMES.keys()
	var theme: String = themes[randi() % themes.size()]
	var pair: Array = FLOOR_THEMES[theme]
	_floor_stage1 = load("res://assets/arena/%s.png" % pair[0])
	_floor_stage2 = load("res://assets/arena/%s.png" % pair[1])

# ---------- arranque ----------
func setup(cfg: Dictionary) -> void:
	_pick_floors()   # novo chão sorteado a cada partida
	for f in fighters:
		f.queue_free()
	for it in items:
		it.queue_free()
	fighters.clear()
	items.clear()
	popups.clear()
	id_counter = 0
	arena_tint = 0.0
	item_timer = 0.0
	_player_prev_alive = true
	phase = Phase.MELEE
	player = _make_player(cfg)
	_add_fighter(player)
	var class_names: Array = Arch.names()
	for i in range(OPPONENTS):
		var cls: String = class_names[randi() % class_names.size()]
		_add_fighter(_make_fighter(cls))
	running = true
	phase_changed.emit(Loc.t("phase_royale"))
	alive_changed.emit(contenders_alive().size())

func _add_fighter(f) -> void:
	fighters.append(f)
	add_child(f)

func _make_fighter(cls: String, ctrl: Controller = null) -> Fighter:
	var a: Dictionary = Arch.DATA[cls]
	var f := Fighter.new()
	var j: float = randf_range(0.9, 1.1)
	f.cls = cls
	f.team = id_counter
	id_counter += 1
	f.controller = ctrl if ctrl != null else AIController.new()
	f.color = a["color"]
	f.max_hp = a["hp"] * j
	f.hp = f.max_hp
	f.atk = a["atk"] * j
	f.def = a["def"]
	f.speed = a["speed"]
	f.attack_range = a["range"]
	f.cd = a["cd"]
	f.cd_timer = randf_range(0.0, a["cd"])
	f.size = a["size"]
	f.is_necro = a.get("necro", false)
	f.regen_pct = a.get("regen", 0.0)
	f.regen_every = a.get("regen_every", 0.0)
	f.position = Vector2(randf_range(40, world_size.x - 40), randf_range(50, world_size.y - 40))
	return f

func _make_player(cfg: Dictionary) -> Fighter:
	var f := _make_fighter(cfg["cls"], PlayerController.new())
	var a: Dictionary = Arch.DATA[cfg["cls"]]
	var pts: Dictionary = cfg["points"]
	# bónus de herói (+40% vida sobre a base) para 1-contra-99 ser jogável
	f.max_hp = round(a["hp"] * 1.4 + pts["hp"] * 14.0)
	f.hp = f.max_hp
	f.atk = a["atk"] + pts["atk"] * 2.0
	f.def = a["def"] + pts["def"]
	f.speed = a["speed"] + pts["spd"] * 5.4
	f.cd = max(0.27, a["cd"] * 0.6)
	f.size = max(9.0, a["size"])
	f.color = cfg["color"]
	f.display_name = cfg["name"] if cfg["name"] != "" else Loc.t("default_name")
	f.position = world_size / 2.0
	return f

func _make_zombie(victim, owner) -> Fighter:
	var f := Fighter.new()
	f.cls = "Zombie"
	f.team = owner.team
	f.controller = AIController.new()
	f.color = ZOMBIE_COLOR
	f.max_hp = max(6.0, victim.max_hp * 0.1)
	f.hp = f.max_hp
	f.atk = max(2.0, victim.atk * 0.1)
	f.def = victim.def * 0.1
	f.speed = max(50.0, victim.speed * 0.6)
	f.attack_range = 20.0
	f.cd = 0.8
	f.cd_timer = randf_range(0.0, 0.8)
	f.size = max(6.0, victim.size * 0.7)
	f.is_zombie = true
	f.owner_fighter = owner
	f.contender = false
	f.position = victim.position
	return f

# ---------- tick ----------
func _physics_process(delta: float) -> void:
	if not running:
		return
	match phase:
		Phase.MELEE:
			_combat_step(delta)
			_melee_items(delta)
			_check_top6()
		Phase.TRANSITION:
			_transition_step(delta)
		Phase.TITAN:
			_combat_step(delta)
			_check_victory()
	_update_popups(delta)
	queue_redraw()

func _combat_step(delta: float) -> void:
	_rebuild_grid()
	var intents := {}
	for f in fighters:
		if f.alive:
			intents[f] = f.controller.decide(f, self)
	# movimento
	for f in fighters:
		if f.alive:
			_apply_movement(f, intents[f], delta)
	# separação + limites do mapa
	for f in fighters:
		if not f.alive:
			continue
		_separate(f)
		f.position.x = clamp(f.position.x, 20.0, world_size.x - 20.0)
		f.position.y = clamp(f.position.y, 30.0, world_size.y - 20.0)
		f.z_index = int(f.position.y)
	# ataques — nota: um necromante pode ADICIONAR um zombie a 'fighters'
	# aqui dentro; por isso saltamos qualquer lutador sem intent (o zombie
	# novo só entra na simulação no tick seguinte).
	for f in fighters:
		if not f.alive or not intents.has(f):
			continue
		f.cd_timer -= delta
		if intents[f].attack and f.cd_timer <= 0.0:
			f.cd_timer = f.cd
			_do_attack(f)
			f.play_attack()
	# regen + timers + redesenho
	for f in fighters:
		if not f.alive:
			continue
		_regen(f, delta)
		if f.flash > 0.0:
			f.flash -= delta
		f.queue_redraw()

	alive_changed.emit(contenders_alive().size())
	if player != null and player.alive:
		player_hp_changed.emit(clamp(player.hp / player.max_hp, 0.0, 1.0))
	# morte do jogador
	if player != null and _player_prev_alive and not player.alive:
		var place: int = contenders_alive().size() + 1
		show_banner.emit(Loc.t("banner_eliminated_big"), Loc.t("banner_eliminated_sub", [place]), true)
	_player_prev_alive = (player != null and player.alive)

func _apply_movement(f, it: Intent, delta: float) -> void:
	if it.dash and f.dash_cd <= 0.0:
		f.dash_cd = 0.8
		f.dash_timer = 0.16
	var boost: float = 3.2 if f.dash_timer > 0.0 else 1.0
	f.position += it.move * f.speed * boost * delta
	# estado para a animação (direção e se está a mover-se)
	f.moving = it.move.length() > 0.01
	if absf(it.move.x) > 0.05:
		f.facing = 1 if it.move.x > 0.0 else -1
	if f.dash_timer > 0.0:
		f.dash_timer -= delta
	if f.dash_cd > 0.0:
		f.dash_cd -= delta

func _separate(f) -> void:
	var near: Array = grid.query(f.position, f.size * 2.0 + 24.0)
	for o in near:
		if o == f or not o.alive:
			continue
		var off: Vector2 = f.position - o.position
		var d: float = off.length()
		var m: float = f.size + o.size
		if d > 0.0 and d < m:
			f.position += (off / d) * 0.4

func _do_attack(f) -> void:
	if f.is_player():
		# golpe em arco: acerta em todos os inimigos ao alcance (borda-a-borda)
		var near: Array = grid.query(f.position, f.attack_range + f.size + 60.0)
		for o in near:
			if o == f or not o.alive or o.team == f.team:
				continue
			if f.position.distance_to(o.position) <= f.attack_range + f.size + o.size:
				_apply_hit(f, o)
	else:
		if f.target != null and f.target.alive and f.target.team != f.team:
			_apply_hit(f, f.target)

func _apply_hit(att, tgt) -> void:
	var dmg: float = max(1.0, att.atk * att.atk_mult() - tgt.def * 0.4) * randf_range(0.85, 1.15)
	var crit: bool = randf() < att.crit_chance()
	if crit:
		dmg *= 1.2
	dmg *= (1.0 - tgt.dmg_reduction())
	tgt.hp -= dmg
	tgt.flash = 0.1
	var pc: Color = Color("f4c145") if (crit or att.is_titan) else Color.WHITE
	_add_popup(tgt.position, str(int(round(dmg))), pc)
	var dir: Vector2 = (tgt.position - att.position).normalized()
	var k: float = 2.4 if att.is_titan else 1.3
	tgt.position += dir * k * 3.0
	if tgt.hp <= 0.0:
		tgt.alive = false
		tgt.visible = false
		# Necromante: 25% de erguer um zombie (só na royale, nunca titã)
		if att.is_necro and not att.is_zombie and phase == Phase.MELEE and randf() < 0.25:
			_add_fighter(_make_zombie(tgt, att))

func _regen(f, delta: float) -> void:
	if f.regen_pct > 0.0:
		f.regen_timer += delta
		if f.regen_timer >= f.regen_every:
			f.regen_timer = 0.0
			if f.hp < f.max_hp:
				f.hp = min(f.max_hp, f.hp + f.max_hp * f.regen_pct)
				_add_popup(f.position, "+", Color("6dd36a"))
	var heals: int = 0
	for a in f.amulets:
		if a == "heal":
			heals += 1
	if heals > 0:
		f.amulet_heal_timer += delta
		if f.amulet_heal_timer >= 10.0:
			f.amulet_heal_timer = 0.0
			f.hp = min(f.max_hp, f.hp + f.max_hp * 0.05 * heals)
			_add_popup(f.position, "+%d%%" % (5 * heals), Color("6dd36a"))

# ---------- itens ----------
func _melee_items(delta: float) -> void:
	item_timer += delta
	if item_timer >= 2.5 and items.size() < 6:
		item_timer = 0.0
		_spawn_item()
	for it in items:
		it.t += delta * 4.0
		it.queue_redraw()
	for f in fighters:
		if f.alive:
			_try_pickup(f)

func _spawn_item() -> void:
	var it := Item.new()
	var r: float = randf()
	if r < 0.40:
		it.kind = "weapon"
		it.val = 1 + randi() % 10
	elif r < 0.65:
		it.kind = "armor"
	else:
		it.kind = "amulet"
		it.sub = "heal" if randf() < 0.5 else "crit"
	it.position = Vector2(randf_range(60, world_size.x - 60), randf_range(70, world_size.y - 50))
	items.append(it)
	add_child(it)

func _try_pickup(f) -> void:
	for i in range(items.size() - 1, -1, -1):
		var it = items[i]
		if f.position.distance_to(it.position) > f.size + it.size:
			continue
		var taken: bool = false
		match it.kind:
			"weapon":
				if f.weapons.size() < 2:
					f.weapons.append(it.val)
					taken = true
			"armor":
				if not f.has_armor:
					f.has_armor = true
					taken = true
			"amulet":
				if f.amulets.size() < 2:
					f.amulets.append(it.sub)
					taken = true
		if taken:
			items.remove_at(i)
			it.queue_free()

# ---------- fases ----------
func _check_top6() -> void:
	if contenders_alive().size() <= 6:
		phase = Phase.TRANSITION
		transition_timer = 1.2
		show_banner.emit(Loc.t("banner_top6_big"), Loc.t("banner_top6_sub"), false)

func _transition_step(delta: float) -> void:
	transition_timer -= delta
	arena_tint = clamp(arena_tint + delta * 1.6, 0.0, 1.0)
	if transition_timer <= 0.0:
		_start_titans()

func _start_titans() -> void:
	# zombies deixam de existir
	for z in fighters:
		if z.is_zombie and z.alive:
			z.alive = false
			z.visible = false
	for it in items:
		it.queue_free()
	items.clear()
	var s: Array = contenders_alive()
	var c: Vector2 = world_size / 2.0
	var R: float = min(world_size.x, world_size.y) * 0.3
	for i in range(s.size()):
		var f = s[i]
		f.is_titan = true
		f.max_hp *= 10.0
		f.hp = f.max_hp
		f.atk *= 10.0
		f.size *= 2.6
		f.speed *= (0.7 if f.is_player() else 0.55)
		f.cd *= 1.3
		f.attack_range *= 1.4
		var ang: float = float(i) / float(s.size()) * TAU
		f.position = c + Vector2(cos(ang), sin(ang)) * R
		f.target = null
		f.cd_timer = randf_range(0.0, f.cd)
	phase = Phase.TITAN
	arena_tint = 1.0
	phase_changed.emit(Loc.t("phase_titans"))

func _check_victory() -> void:
	if contenders_alive().size() <= 1:
		running = false
		phase = Phase.VICTORY
		var alive_c: Array = contenders_alive()
		var w = alive_c[0] if alive_c.size() == 1 else null
		if w != null and w.is_player():
			show_banner.emit(Loc.t("banner_victory_big"), Loc.t("banner_victory_sub", [w.display_name]), false)
		else:
			show_banner.emit(Loc.t("banner_end_big"), Loc.t("banner_end_sub", [Arch.disp(w.cls)]) if w != null else "-", false)

# ---------- utilitários ----------
func contenders_alive() -> Array:
	var out: Array = []
	for f in fighters:
		if f.alive and f.contender:
			out.append(f)
	return out

func _rebuild_grid() -> void:
	grid.clear()
	for f in fighters:
		if f.alive:
			grid.insert(f)

func _add_popup(pos: Vector2, text: String, col: Color) -> void:
	popups.append({"pos": pos, "text": text, "life": 0.6, "col": col})

func _update_popups(delta: float) -> void:
	var kept: Array = []
	for p in popups:
		var pos: Vector2 = p["pos"]
		pos.y -= 40.0 * delta
		p["pos"] = pos
		p["life"] = p["life"] - delta
		if p["life"] > 0.0:
			kept.append(p)
	popups = kept

# ---------- fundo da arena ----------
func _draw() -> void:
	var t: float = arena_tint
	# chão em mosaico: fase 1 (royale) ou fase 2 (titãs), sorteados por partida
	var floor: Texture2D = _floor_stage2 if phase >= Phase.TITAN else _floor_stage1
	if floor != null:
		draw_texture_rect(floor, Rect2(Vector2.ZERO, world_size), true)
		if phase >= Phase.TITAN:
			draw_rect(Rect2(Vector2.ZERO, world_size), Color(0.078, 0.067, 0.133, 0.15))
	else:
		var floor_col: Color = Color(0.227, 0.184, 0.157).lerp(Color(0.078, 0.067, 0.133), t)
		draw_rect(Rect2(Vector2.ZERO, world_size), floor_col)
	var ring: Color = Color("f4c145")
	ring.a = 0.12 + 0.18 * t
	draw_arc(world_size / 2.0, min(world_size.x, world_size.y) * 0.42, 0, TAU, 64, ring, 2.0)
	if t > 0.3:
		draw_arc(world_size / 2.0, min(world_size.x, world_size.y) * 0.28, 0, TAU, 64, Color(0.61, 0.42, 1.0, 0.15 * t), 2.0)
	var font: Font = ThemeDB.fallback_font
	for p in popups:
		var c: Color = p["col"]
		c.a = clamp(p["life"] / 0.6, 0.0, 1.0)
		draw_string(font, p["pos"], p["text"], HORIZONTAL_ALIGNMENT_CENTER, 40, 13, c)
