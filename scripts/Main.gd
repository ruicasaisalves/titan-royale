extends Node2D
# Orquestra tudo: constrói o ecrã de criação e o HUD por código,
# cria a Arena e liga os sinais. A UI aqui é propositadamente
# simples (sem tema) — a ideia é desenhá-la depois no editor.

const TOTAL_POINTS := 6

var cfg := {
	"cls": "Bruto",
	"name": "",
	"color": Color("f4c145"),
	"hair_c": 1,
	"cloth_c": 1,
	"points": {"hp": 0, "atk": 0, "def": 0, "spd": 0},
}

var arena: Arena
var ui: CanvasLayer
var creation_root: Control
var hud_root: Control
var intro_root: Control

# refs de UI
var class_buttons := {}
var stats_label: Label
var points_left_label: Label
# seletor de estilo (aparência)
var char_preview: TextureRect
var hair_swatches := {}
var cloth_swatches := {}
var palette := {}   # cache de cores das amostras (chave "cls|kind|c")
var point_value_labels := {}

var hud_alive: Label
var hud_phase: Label
var hud_gear: Label
var hp_fill: ColorRect
var hp_label: Label
var banner_big: Label
var banner_sub: Label
var banner_box: Control
var menu_btn: Button
var coins_label: Label
var stats_menu_label: Label

func _ready() -> void:
	arena = Arena.new()
	add_child(arena)
	arena.alive_changed.connect(_on_alive_changed)
	arena.phase_changed.connect(_on_phase_changed)
	arena.show_banner.connect(_on_banner)
	arena.match_ended.connect(_on_match_ended)

	ui = CanvasLayer.new()
	add_child(ui)
	_build_creation()
	_build_hud()
	_build_intro()
	_select_class("Bruto")

func _process(_delta: float) -> void:
	# atualiza HP e equipamento do jogador (poll simples)
	if hud_root.visible and arena.player != null and arena.player.alive:
		var p = arena.player
		hp_fill.size.x = hp_fill.get_parent().size.x * clamp(p.hp / p.max_hp, 0.0, 1.0)
		hp_label.text = "%s  ·  %s" % [p.display_name, Arch.disp(p.cls)]
		hud_gear.text = _gear_text(p)

func _gear_text(p) -> String:
	var s := ""
	if p.weapons.size() > 0:
		var sum := 0
		for w in p.weapons:
			sum += int(w)
		s += Loc.t("gear_weapons", [p.weapons.size(), sum])
	if p.has_armor:
		s += Loc.t("gear_armor")
	var h := 0
	var cr := 0
	for a in p.amulets:
		if a == "heal": h += 1
		else: cr += 1
	if h > 0: s += Loc.t("gear_heal", [h])
	if cr > 0: s += Loc.t("gear_crit", [cr])
	return s

# ============ ECRÃ DE CRIAÇÃO ============
func _build_creation() -> void:
	creation_root = Control.new()
	creation_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(creation_root)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	creation_root.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var margin := MarginContainer.new()
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 20)
	panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	margin.add_child(vb)

	# título + versão (lida de Project Settings -> Application -> Config -> Version)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	title_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	vb.add_child(title_row)
	title_row.add_child(_title("TITAN ROYALE", 26, Color("f4c145")))
	var ver := _title("v" + str(ProjectSettings.get_setting("application/config/version", "0.0")), 11, Color("8a8fa3"))
	ver.size_flags_vertical = Control.SIZE_SHRINK_END
	title_row.add_child(ver)

	# estatísticas do perfil persistente (vitórias/derrotas/moedas)
	stats_menu_label = _title("", 13, Color("f4c145"))
	vb.add_child(stats_menu_label)
	_refresh_menu_stats()

	# Duas colunas lado a lado (classes | lutador) para caber nos 600px
	# de altura — uma coluna única com botões de toque ficava cortada.
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 28)
	vb.add_child(cols)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.custom_minimum_size = Vector2(290, 0)
	cols.add_child(left)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.custom_minimum_size = Vector2(340, 0)
	cols.add_child(right)

	# ---- coluna esquerda: classes ----
	left.add_child(_title(Loc.t("creation_class_title"), 12, Color("8a8fa3")))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	left.add_child(grid)
	for cls in Arch.names():
		var b := Button.new()
		b.text = Arch.disp(cls)
		b.custom_minimum_size = Vector2(140, 44)
		b.pressed.connect(_select_class.bind(cls))
		grid.add_child(b)
		class_buttons[cls] = b

	stats_label = Label.new()
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_label.custom_minimum_size = Vector2(290, 0)
	left.add_child(stats_label)

	# ---- coluna direita: o teu lutador ----
	right.add_child(_title(Loc.t("creation_fighter_title"), 12, Color("8a8fa3")))

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	right.add_child(name_row)
	var nlbl := Label.new()
	nlbl.text = Loc.t("name_label")
	name_row.add_child(nlbl)
	var line := LineEdit.new()
	line.placeholder_text = Loc.t("name_placeholder")
	line.max_length = 14
	line.custom_minimum_size = Vector2(220, 0)
	line.text_changed.connect(func(t): cfg["name"] = t.strip_edges())
	name_row.add_child(line)

	# ---- aparência: pré-visualização + cor do cabelo/roupa (por classe) ----
	var appearance_row := HBoxContainer.new()
	appearance_row.add_theme_constant_override("separation", 14)
	right.add_child(appearance_row)

	char_preview = TextureRect.new()
	char_preview.custom_minimum_size = Vector2(150, 90)
	char_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	char_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	appearance_row.add_child(char_preview)

	var swatches_col := VBoxContainer.new()
	swatches_col.add_theme_constant_override("separation", 6)
	appearance_row.add_child(swatches_col)
	swatches_col.add_child(_swatch_row(Loc.t("hair_label"), "hair"))
	swatches_col.add_child(_swatch_row(Loc.t("cloth_label"), "cloth"))

	points_left_label = Label.new()
	right.add_child(points_left_label)
	for key in ["hp", "atk", "def", "spd"]:
		right.add_child(_point_row(key))

	var hint := Label.new()
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color("8a8fa3"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(340, 0)
	hint.text = Loc.t("hint_touch") if Touch.enabled else Loc.t("hint_keyboard")
	right.add_child(hint)

	var start := Button.new()
	start.text = Loc.t("enter_arena")
	start.custom_minimum_size = Vector2(0, 50)
	start.pressed.connect(_start_game)
	right.add_child(start)

	_refresh_points()

func _title(txt: String, sz: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	return l

func _point_row(key: String) -> HBoxContainer:
	var labels := {"hp": Loc.t("stat_hp"), "atk": Loc.t("stat_atk"), "def": Loc.t("stat_def"), "spd": Loc.t("stat_spd")}
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name_l := Label.new()
	name_l.text = labels[key]
	name_l.custom_minimum_size = Vector2(120, 0)
	row.add_child(name_l)
	var minus := Button.new()
	minus.text = "-"
	minus.custom_minimum_size = Vector2(44, 44)
	minus.pressed.connect(_change_point.bind(key, -1))
	row.add_child(minus)
	var val := Label.new()
	val.text = "0"
	val.custom_minimum_size = Vector2(24, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(val)
	point_value_labels[key] = val
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(44, 44)
	plus.pressed.connect(_change_point.bind(key, 1))
	row.add_child(plus)
	return row

func _points_used() -> int:
	var pts: Dictionary = cfg["points"]
	return pts["hp"] + pts["atk"] + pts["def"] + pts["spd"]

func _change_point(key: String, d: int) -> void:
	var pts: Dictionary = cfg["points"]
	if d > 0 and _points_used() >= TOTAL_POINTS:
		return
	if d < 0 and pts[key] <= 0:
		return
	pts[key] = max(0, pts[key] + d)
	_refresh_points()

func _refresh_points() -> void:
	points_left_label.text = Loc.t("points_left", [TOTAL_POINTS - _points_used()])
	for key in point_value_labels:
		point_value_labels[key].text = str(cfg["points"][key])

# ---- aparência (cabelo/roupa) ----
const COLORS := [1, 2, 3, 4, 5, 6, 7, 8]   # cores disponíveis (c1..c8)

func _swatch_row(text: String, kind: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(58, 0)
	row.add_child(lbl)
	for c in COLORS:
		var sw := ColorRect.new()
		sw.custom_minimum_size = Vector2(24, 24)
		sw.mouse_filter = Control.MOUSE_FILTER_STOP
		var ci := int(c)
		sw.gui_input.connect(func(e): _on_color_pick(e, kind, ci))
		row.add_child(sw)
		if kind == "hair":
			hair_swatches[ci] = sw
		else:
			cloth_swatches[ci] = sw
	return row

func _on_color_pick(e: InputEvent, kind: String, c: int) -> void:
	if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
		cfg["hair_c" if kind == "hair" else "cloth_c"] = c
		_refresh_appearance()

# Cor média (célula idle) da camada de topo — para pintar a amostra da UI.
# Amostra as texturas em runtime (sem depender de ficheiros extra no export).
func _layer_avg_color(cls: String, kind: String, c: int) -> Color:
	var key := "%s|%s|%d" % [cls, kind, c]
	if palette.has(key):
		return palette[key]
	var col := Color(0.5, 0.5, 0.5)
	var p := "res://assets/heroes_layers/%s/%s_top_c%d.png" % [cls, kind, c]
	if ResourceLoader.exists(p):
		var tex: Texture2D = load(p)
		var img: Image = tex.get_image() if tex != null else null
		if img != null:
			if img.is_compressed():
				img.decompress()
			var r := 0.0
			var g := 0.0
			var b := 0.0
			var n := 0
			for y in range(0, min(40, img.get_height())):
				for x in range(0, min(100, img.get_width())):
					var px := img.get_pixel(x, y)
					if px.a > 0.3:
						r += px.r
						g += px.g
						b += px.b
						n += 1
			if n > 0:
				col = Color(r / n, g / n, b / n)
	palette[key] = col   # cache
	return col

func _refresh_appearance() -> void:
	var cls: String = cfg["cls"]
	for c in hair_swatches:
		hair_swatches[c].color = _layer_avg_color(cls, "hair", c)
		hair_swatches[c].modulate = Color.WHITE if c == int(cfg["hair_c"]) else Color(1, 1, 1, 0.4)
	for c in cloth_swatches:
		cloth_swatches[c].color = _layer_avg_color(cls, "cloth", c)
		cloth_swatches[c].modulate = Color.WHITE if c == int(cfg["cloth_c"]) else Color(1, 1, 1, 0.4)
	# a cor de destaque (aros/nome) segue a roupa escolhida
	cfg["color"] = _layer_avg_color(cls, "cloth", int(cfg["cloth_c"]))
	if char_preview != null:
		char_preview.texture = CharacterComposer.preview(cls, int(cfg["hair_c"]), int(cfg["cloth_c"]))

func _select_class(cls: String) -> void:
	cfg["cls"] = cls
	for name in class_buttons:
		class_buttons[name].modulate = Color("f4c145") if name == cls else Color.WHITE
	var a: Dictionary = Arch.DATA[cls]
	stats_label.text = Loc.t("stats_line", [
		Arch.disp(cls), Arch.role(cls), int(a["hp"]), int(a["atk"]), int(a["def"]), int(a["speed"]), int(a["range"])
	])
	# aparência guardada por classe (ou default)
	var app: Dictionary = Save.data.get("appearance", {})
	var saved = app.get(cls, {})
	cfg["hair_c"] = int(saved.get("hair_c", 1)) if saved is Dictionary else 1
	cfg["cloth_c"] = int(saved.get("cloth_c", 1)) if saved is Dictionary else 1
	_refresh_appearance()

# ============ HUD ============
func _build_hud() -> void:
	hud_root = Control.new()
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.visible = false
	ui.add_child(hud_root)

	# indicadores no topo — centrados, fonte maior
	var top_box := VBoxContainer.new()
	top_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_box.offset_top = 10
	top_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_box.add_theme_constant_override("separation", 2)
	hud_root.add_child(top_box)
	hud_alive = _hud_label(Loc.t("hud_alive", [Arena.OPPONENTS + 1]), 20, Color("ece5d3"))
	top_box.add_child(hud_alive)
	hud_phase = _hud_label(Loc.t("hud_phase", [Loc.t("phase_royale")]), 15, Color("8a8fa3"))
	top_box.add_child(hud_phase)
	hud_gear = _hud_label("", 14, Color("f4c145"))
	top_box.add_child(hud_gear)

	# barra de vida do jogador (em baixo) — mais alta, texto centrado
	var hp_bg := ColorRect.new()
	hp_bg.color = Color(0, 0, 0, 0.55)
	hp_bg.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hp_bg.offset_left = 16
	hp_bg.offset_right = -16
	hp_bg.offset_top = -46
	hp_bg.offset_bottom = -16
	hud_root.add_child(hp_bg)
	hp_fill = ColorRect.new()
	hp_fill.color = Color("6dd36a")
	hp_fill.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	hp_fill.offset_top = 0
	hp_fill.offset_bottom = 0
	hp_fill.size = Vector2(200, 30)
	hp_bg.add_child(hp_fill)
	hp_label = Label.new()
	hp_label.add_theme_font_size_override("font_size", 15)
	hp_label.add_theme_color_override("font_color", Color.WHITE)
	hp_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	hp_label.add_theme_constant_override("shadow_offset_x", 1)
	hp_label.add_theme_constant_override("shadow_offset_y", 1)
	hp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_bg.add_child(hp_label)

	# banner central
	banner_box = VBoxContainer.new()
	banner_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	banner_box.alignment = BoxContainer.ALIGNMENT_CENTER
	banner_box.visible = false
	hud_root.add_child(banner_box)
	banner_big = Label.new()
	banner_big.add_theme_font_size_override("font_size", 46)
	banner_big.add_theme_color_override("font_color", Color("f4c145"))
	banner_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_box.add_child(banner_big)
	banner_sub = Label.new()
	banner_sub.add_theme_color_override("font_color", Color("ece5d3"))
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_box.add_child(banner_sub)

	# moedas ganhas nesta partida (aparece no fim)
	coins_label = Label.new()
	coins_label.add_theme_font_size_override("font_size", 20)
	coins_label.add_theme_color_override("font_color", Color("f4c145"))
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coins_label.visible = false
	banner_box.add_child(coins_label)

	# botão de voltar ao menu — só aparece quando o jogo acaba (vitória/derrota)
	var btn_wrap := CenterContainer.new()
	btn_wrap.custom_minimum_size = Vector2(0, 30)  # folga acima do botão
	banner_box.add_child(btn_wrap)
	menu_btn = Button.new()
	menu_btn.text = Loc.t("back_to_menu")
	menu_btn.custom_minimum_size = Vector2(260, 54)
	menu_btn.add_theme_font_size_override("font_size", 20)
	menu_btn.pressed.connect(_return_to_menu)
	menu_btn.visible = false
	btn_wrap.add_child(menu_btn)

	# controlos táteis — só aparecem em ecrãs de toque (ou com FORCE_ON_DESKTOP)
	if Touch.enabled:
		_build_touch_controls()

func _build_touch_controls() -> void:
	const BOTTOM := 64.0   # acima da barra de vida (34px) com folga
	var joy := HudJoystick.new()
	_anchor_bottom(joy, 30.0, 120.0, 120.0, BOTTOM, false)
	hud_root.add_child(joy)

	var atk := HudTouchButton.new()
	atk.label = Loc.t("btn_attack")
	atk.target = "attack"
	atk.color = Color("d1453b")
	_anchor_bottom(atk, 30.0, 68.0, 68.0, BOTTOM, true)
	hud_root.add_child(atk)

	var dash := HudTouchButton.new()
	dash.label = Loc.t("btn_dash")
	dash.target = "dash"
	dash.color = Color("4fd6c9")
	_anchor_bottom(dash, 114.0, 68.0, 68.0, BOTTOM + 40.0, true)
	hud_root.add_child(dash)

# Posiciona um Control encostado ao fundo, a 'x' da esquerda ou da direita.
func _anchor_bottom(ctrl: Control, x: float, w: float, h: float, bottom: float, from_right: bool) -> void:
	if from_right:
		ctrl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		ctrl.offset_left = -(x + w)
		ctrl.offset_right = -x
	else:
		ctrl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		ctrl.offset_left = x
		ctrl.offset_right = x + w
	ctrl.offset_top = -(bottom + h)
	ctrl.offset_bottom = -bottom

func _hud_label(txt: String, sz: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l

# ============ LOGO DE ENTRADA ============
# Mostra o logo "TITAN ROYALE" (pixel-art) por cima de tudo ao arrancar,
# faz um "pop" a aparecer, segura, e desvanece para o ecrã de criação.
# Um toque/tecla salta a intro.
var _intro_tween: Tween

func _build_intro() -> void:
	intro_root = Control.new()
	intro_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro_root.mouse_filter = Control.MOUSE_FILTER_STOP  # apanha o toque para saltar
	intro_root.gui_input.connect(func(e): if _is_press(e): _end_intro())
	ui.add_child(intro_root)

	var bg := ColorRect.new()
	bg.color = Color(0.055, 0.063, 0.09)  # mesmo fundo do jogo / boot splash
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_root.add_child(bg)

	var logo := TextureRect.new()
	logo.texture = load("res://assets/ui/logo.png")
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	logo.offset_left = 140
	logo.offset_right = -140
	logo.offset_top = 110
	logo.offset_bottom = -110
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_root.add_child(logo)

	var vp := get_viewport_rect().size
	logo.pivot_offset = vp / 2
	logo.scale = Vector2(0.92, 0.92)
	intro_root.modulate.a = 0.0
	_intro_tween = create_tween()
	_intro_tween.set_trans(Tween.TRANS_SINE)
	_intro_tween.tween_property(intro_root, "modulate:a", 1.0, 0.5)
	_intro_tween.parallel().tween_property(logo, "scale", Vector2.ONE, 0.6) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_interval(1.3)
	_intro_tween.tween_property(intro_root, "modulate:a", 0.0, 0.5)
	_intro_tween.tween_callback(_end_intro)

func _end_intro() -> void:
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	if is_instance_valid(intro_root):
		intro_root.queue_free()
	intro_root = null

func _unhandled_input(event: InputEvent) -> void:
	if intro_root != null and _is_press(event):
		_end_intro()

func _is_press(e: InputEvent) -> bool:
	return (e is InputEventMouseButton and e.pressed) \
		or (e is InputEventScreenTouch and e.pressed) \
		or (e is InputEventKey and e.pressed)

func _start_game() -> void:
	# guarda a aparência escolhida (por classe) no perfil
	var app: Dictionary = Save.data.get("appearance", {})
	app[cfg["cls"]] = {"hair_c": cfg["hair_c"], "cloth_c": cfg["cloth_c"]}
	Save.data["appearance"] = app
	Save.save_profile()
	creation_root.visible = false
	hud_root.visible = true
	banner_box.visible = false
	menu_btn.visible = false
	coins_label.visible = false
	arena.setup(cfg)

# Volta ao ecrã de criação e limpa a partida atual.
func _return_to_menu() -> void:
	arena.reset_to_idle()
	hud_root.visible = false
	banner_box.visible = false
	menu_btn.visible = false
	coins_label.visible = false
	_refresh_menu_stats()
	creation_root.visible = true

# Fim de jogo: grava o resultado no perfil e mostra as moedas ganhas.
func _on_match_ended(won: bool, _place: int, coins: int) -> void:
	Save.record_match(won, _place, coins)
	coins_label.text = Loc.t("coins_earned", [coins])
	coins_label.visible = true

func _refresh_menu_stats() -> void:
	if stats_menu_label == null:
		return
	stats_menu_label.text = Loc.t("menu_stats", [
		int(Save.data.get("wins", 0)),
		int(Save.data.get("losses", 0)),
		int(Save.data.get("coins", 0)),
	])

func _on_alive_changed(n: int) -> void:
	hud_alive.text = Loc.t("hud_alive", [n])

func _on_phase_changed(name: String) -> void:
	hud_phase.text = Loc.t("hud_phase", [name])

func _on_banner(big: String, sub: String, dead: bool) -> void:
	banner_big.text = big
	banner_big.add_theme_color_override("font_color", Color("d1453b") if dead else Color("f4c145"))
	banner_sub.text = sub
	banner_box.visible = true
	# fim de jogo (jogador eliminado ou partida terminada) -> mostra o botão
	# de voltar ao menu, para se poder recomeçar; ganhe ou perca.
	menu_btn.visible = dead or arena.phase == Arena.Phase.VICTORY
	# banners transitórios desaparecem sozinhos; morte/vitória ficam
	if not dead and big == Loc.t("banner_top6_big"):
		await get_tree().create_timer(1.6).timeout
		if arena.phase == Arena.Phase.TITAN or arena.phase == Arena.Phase.TRANSITION:
			banner_box.visible = false
