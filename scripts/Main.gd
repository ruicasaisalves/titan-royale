extends Node2D
# Orquestra tudo: constrói o ecrã de criação e o HUD por código,
# cria a Arena e liga os sinais. A UI aqui é propositadamente
# simples (sem tema) — a ideia é desenhá-la depois no editor.

var cfg := {
	"cls": "Bruto",
	"name": "",
	"color": Color("f4c145"),
	"hair_c": 1,
	"cloth_c": 1,
}

var arena: Arena
var ui: CanvasLayer
# ecrãs do menu (um visível de cada vez) + HUD + intro
var menu_root: Control
var play_root: Control
var styles_root: Control
var settings_root: Control
var hud_root: Control
var intro_root: Control

# refs de UI — menu
var stats_menu_label: Label
# refs de UI — jogar (grelha de classes + painel de descrição)
var class_buttons := {}
var desc_name: Label
var desc_role: Label
var attr_fill := {}   # {stat: ColorRect} barras de atributos
var attr_val := {}    # {stat: Label} valores
# refs de UI — estilos (setas < > por cabelo/roupa)
var char_preview: TextureRect
var styles_class_label: Label
var hair_chip: ColorRect
var cloth_chip: ColorRect
var palette := {}   # cache de cores das amostras (chave "cls|kind|c")
# brilho (overlay escuro por cima de tudo)
var brightness_overlay: ColorRect

const ATTR_KEYS := ["hp", "atk", "def", "speed", "range"]

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

func _ready() -> void:
	arena = Arena.new()
	add_child(arena)
	arena.alive_changed.connect(_on_alive_changed)
	arena.phase_changed.connect(_on_phase_changed)
	arena.show_banner.connect(_on_banner)
	arena.match_ended.connect(_on_match_ended)

	ui = CanvasLayer.new()
	add_child(ui)
	_build_menu()
	_build_play()
	_build_styles()
	_build_settings()
	_build_hud()
	_build_overlay()
	_apply_saved_settings()
	_build_intro()
	_select_class(cfg["cls"])
	_show_screen(menu_root)

func _process(_delta: float) -> void:
	if not hud_root.visible:
		return
	# atualiza HP e equipamento do jogador (poll simples)
	if arena.player != null and arena.player.alive:
		var p = arena.player
		hp_fill.size.x = hp_fill.get_parent().size.x * clamp(p.hp / p.max_hp, 0.0, 1.0)
		hp_label.text = "%s  ·  %s" % [p.display_name, Arch.disp(p.cls)]
		hud_gear.text = _gear_text(p)
	# botão de sair persistente (fica disponível mesmo depois de morrer)
	_update_exit_button()

# Mostra o botão de sair quando o jogador está fora (eliminado) ou o jogo
# terminou — persistente durante a fase dos titãs, até o jogador sair.
func _update_exit_button() -> void:
	if menu_btn == null:
		return
	var out: bool = arena.player == null or not arena.player.alive
	menu_btn.visible = hud_root.visible and (out or arena.phase == Arena.Phase.VICTORY)

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

# ============ MENU / JOGAR / ESTILOS / DEFINIÇÕES ============
const COLORS := [1, 2, 3, 4, 5, 6, 7, 8]   # cores disponíveis (c1..c8)

# Mostra um ecrã do menu e esconde os outros; refresca o ecrã alvo.
func _show_screen(target: Control) -> void:
	for s in [menu_root, play_root, styles_root, settings_root]:
		if s != null:
			s.visible = (s == target)
	if target == menu_root:
		_refresh_menu_stats()
	elif target == play_root:
		_refresh_play()
	elif target == styles_root:
		_refresh_styles()

# ---- helpers de layout ----
func _screen_root() -> Control:
	var r := Control.new()
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.visible = false
	ui.add_child(r)
	return r

# Painel central (fundo + margem) dentro de 'parent'; devolve o VBox de conteúdo.
func _panel_vbox(parent: Control) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 20)
	panel.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	margin.add_child(vb)
	return vb

func _title(txt: String, sz: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	return l

func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func _back_button() -> Button:
	var b := Button.new()
	b.text = Loc.t("back")
	b.custom_minimum_size = Vector2(90, 40)
	b.pressed.connect(_show_screen.bind(menu_root))
	return b

func _arrow_button(txt: String) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(48, 44)
	b.add_theme_font_size_override("font_size", 22)
	return b

# ---- menu principal ----
func _build_menu() -> void:
	menu_root = _screen_root()
	var vb := _panel_vbox(menu_root)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(title_row)
	title_row.add_child(_title("TITAN ROYALE", 30, Color("f4c145")))
	var ver := _title("v" + str(ProjectSettings.get_setting("application/config/version", "0.0")), 11, Color("8a8fa3"))
	ver.size_flags_vertical = Control.SIZE_SHRINK_END
	title_row.add_child(ver)

	stats_menu_label = _title("", 14, Color("f4c145"))
	stats_menu_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(stats_menu_label)
	_refresh_menu_stats()

	vb.add_child(_spacer(8))
	vb.add_child(_menu_button(Loc.t("menu_play"), "play"))
	vb.add_child(_menu_button(Loc.t("menu_styles"), "styles"))
	vb.add_child(_menu_button(Loc.t("menu_settings"), "settings"))

func _menu_button(text: String, which: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 56)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(_goto.bind(which))
	return b

# Navega para um ecrã do menu (lido no clique, quando os roots já existem).
func _goto(which: String) -> void:
	match which:
		"play": _show_screen(play_root)
		"styles": _show_screen(styles_root)
		"settings": _show_screen(settings_root)
		_: _show_screen(menu_root)

# ---- ecrã jogar ----
func _build_play() -> void:
	play_root = _screen_root()
	var vb := _panel_vbox(play_root)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	vb.add_child(head)
	head.add_child(_back_button())
	head.add_child(_title(Loc.t("choose_champion"), 20, Color("f4c145")))

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	vb.add_child(cols)

	# esquerda: grelha dos 7 Champions
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.custom_minimum_size = Vector2(300, 0)
	cols.add_child(left)
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
	var hint := Label.new()
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color("8a8fa3"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(300, 0)
	hint.text = Loc.t("champion_hint")
	left.add_child(hint)

	# direita: descrição + atributos + jogar
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.custom_minimum_size = Vector2(330, 0)
	cols.add_child(right)
	desc_name = _title("", 22, Color("ece5d3"))
	right.add_child(desc_name)
	desc_role = Label.new()
	desc_role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_role.custom_minimum_size = Vector2(330, 44)
	desc_role.add_theme_color_override("font_color", Color("8a8fa3"))
	right.add_child(desc_role)
	for key in ATTR_KEYS:
		right.add_child(_attr_row(key))
	var play_btn := Button.new()
	play_btn.text = Loc.t("enter_arena")
	play_btn.custom_minimum_size = Vector2(0, 52)
	play_btn.add_theme_font_size_override("font_size", 18)
	play_btn.pressed.connect(_start_game)
	right.add_child(play_btn)

# Uma linha de atributo: nome + barra proporcional + valor.
func _attr_row(key: String) -> HBoxContainer:
	var labels := {
		"hp": Loc.t("stat_hp"), "atk": Loc.t("stat_atk"), "def": Loc.t("stat_def"),
		"speed": Loc.t("stat_spd"), "range": Loc.t("stat_range"),
	}
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name_l := Label.new()
	name_l.text = labels[key]
	name_l.custom_minimum_size = Vector2(92, 0)
	name_l.add_theme_font_size_override("font_size", 13)
	row.add_child(name_l)
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(1, 1, 1, 0.12)
	bar_bg.custom_minimum_size = Vector2(150, 14)
	row.add_child(bar_bg)
	var fill := ColorRect.new()
	fill.color = Color("f4c145")
	fill.position = Vector2.ZERO
	fill.size = Vector2(0, 14)
	bar_bg.add_child(fill)
	attr_fill[key] = fill
	var val := Label.new()
	val.custom_minimum_size = Vector2(40, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.add_theme_font_size_override("font_size", 13)
	row.add_child(val)
	attr_val[key] = val
	return row

func _attr_max(key: String) -> float:
	var m := 0.001
	for c in Arch.DATA:
		m = max(m, float(Arch.DATA[c][key]))
	return m

func _refresh_play() -> void:
	var cls: String = cfg["cls"]
	for name in class_buttons:
		class_buttons[name].modulate = Color("f4c145") if name == cls else Color.WHITE
	if desc_name == null:
		return
	var a: Dictionary = Arch.DATA[cls]
	desc_name.text = Arch.disp(cls)
	desc_role.text = Arch.role(cls)
	for key in ATTR_KEYS:
		var ratio: float = clamp(float(a[key]) / _attr_max(key), 0.0, 1.0)
		attr_fill[key].size = Vector2(150.0 * ratio, 14)
		attr_val[key].text = str(int(a[key]))

# ---- ecrã estilos (setas < > para cabelo/roupa e Champion) ----
func _build_styles() -> void:
	styles_root = _screen_root()
	var vb := _panel_vbox(styles_root)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	vb.add_child(head)
	head.add_child(_back_button())
	head.add_child(_title(Loc.t("styles_title"), 20, Color("f4c145")))

	vb.add_child(_arrow_row_class())

	char_preview = TextureRect.new()
	char_preview.custom_minimum_size = Vector2(240, 150)
	char_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	char_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var pv := CenterContainer.new()
	pv.add_child(char_preview)
	vb.add_child(pv)

	vb.add_child(_arrow_row_color(Loc.t("hair_label"), "hair"))
	vb.add_child(_arrow_row_color(Loc.t("cloth_label"), "cloth"))

func _arrow_row_class() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var l := _arrow_button("‹")
	l.pressed.connect(_cycle_class.bind(-1))
	row.add_child(l)
	styles_class_label = _title("", 20, Color("ece5d3"))
	styles_class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	styles_class_label.custom_minimum_size = Vector2(180, 0)
	row.add_child(styles_class_label)
	var r := _arrow_button("›")
	r.pressed.connect(_cycle_class.bind(1))
	row.add_child(r)
	return row

func _arrow_row_color(text: String, kind: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(64, 0)
	row.add_child(lbl)
	var l := _arrow_button("‹")
	l.pressed.connect(_cycle_color.bind(kind, -1))
	row.add_child(l)
	var chip := ColorRect.new()
	chip.custom_minimum_size = Vector2(48, 28)
	row.add_child(chip)
	if kind == "hair":
		hair_chip = chip
	else:
		cloth_chip = chip
	var r := _arrow_button("›")
	r.pressed.connect(_cycle_color.bind(kind, 1))
	row.add_child(r)
	return row

func _cycle_class(dir: int) -> void:
	var ns := Arch.names()
	var i: int = ns.find(cfg["cls"])
	if i == -1:
		i = 0
	i = (i + dir + ns.size()) % ns.size()
	_select_class(ns[i])

func _cycle_color(kind: String, dir: int) -> void:
	var field := "hair_c" if kind == "hair" else "cloth_c"
	var i: int = COLORS.find(int(cfg[field]))
	if i == -1:
		i = 0
	i = (i + dir + COLORS.size()) % COLORS.size()
	cfg[field] = COLORS[i]
	_refresh_styles()

func _refresh_styles() -> void:
	var cls: String = cfg["cls"]
	if styles_class_label != null:
		styles_class_label.text = Arch.disp(cls)
	if hair_chip != null:
		hair_chip.color = _layer_avg_color(cls, "hair", int(cfg["hair_c"]))
	if cloth_chip != null:
		cloth_chip.color = _layer_avg_color(cls, "cloth", int(cfg["cloth_c"]))
	# a cor de destaque (aros/nome) segue a roupa escolhida
	cfg["color"] = _layer_avg_color(cls, "cloth", int(cfg["cloth_c"]))
	if char_preview != null:
		char_preview.texture = CharacterComposer.preview(cls, int(cfg["hair_c"]), int(cfg["cloth_c"]))

# Cor média (célula idle) da camada de topo — para pintar a amostra da UI.
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
	palette[key] = col
	return col

# ---- ecrã definições ----
func _build_settings() -> void:
	settings_root = _screen_root()
	var vb := _panel_vbox(settings_root)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	vb.add_child(head)
	head.add_child(_back_button())
	head.add_child(_title(Loc.t("settings_title"), 20, Color("f4c145")))

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	vb.add_child(name_row)
	var nlbl := Label.new()
	nlbl.text = Loc.t("name_label")
	nlbl.custom_minimum_size = Vector2(110, 0)
	name_row.add_child(nlbl)
	var line := LineEdit.new()
	line.placeholder_text = Loc.t("name_placeholder")
	line.max_length = 14
	line.text = str(Save.data.get("player_name", ""))
	line.custom_minimum_size = Vector2(240, 0)
	line.text_changed.connect(_on_name_changed)
	name_row.add_child(line)

	vb.add_child(_slider_row(Loc.t("setting_brightness"), float(Save.get_setting("brightness", 1.0)), 0.5, 1.0, _on_brightness))
	vb.add_child(_slider_row(Loc.t("setting_music"), float(Save.get_setting("vol_music", 1.0)), 0.0, 1.0, _on_music))
	vb.add_child(_slider_row(Loc.t("setting_sfx"), float(Save.get_setting("vol_sfx", 1.0)), 0.0, 1.0, _on_sfx))

func _slider_row(text: String, value: float, mn: float, mx: float, cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(110, 0)
	row.add_child(lbl)
	var sl := HSlider.new()
	sl.min_value = mn
	sl.max_value = mx
	sl.step = 0.05
	sl.value = value
	sl.custom_minimum_size = Vector2(240, 24)
	sl.value_changed.connect(cb)
	row.add_child(sl)
	return row

func _on_name_changed(t: String) -> void:
	cfg["name"] = t.strip_edges()
	Save.data["player_name"] = cfg["name"]
	Save.save_profile()

func _on_brightness(v: float) -> void:
	_apply_brightness(v)
	Save.set_setting("brightness", v)

func _on_music(v: float) -> void:
	_apply_bus_volume("Music", v)
	Save.set_setting("vol_music", v)

func _on_sfx(v: float) -> void:
	_apply_bus_volume("SFX", v)
	Save.set_setting("vol_sfx", v)

# ---- brilho (overlay) + volumes (buses de áudio) ----
func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 128   # por cima de tudo (menus, HUD, intro)
	add_child(layer)
	brightness_overlay = ColorRect.new()
	brightness_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	brightness_overlay.color = Color(0, 0, 0, 0.0)
	brightness_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(brightness_overlay)

func _apply_brightness(v: float) -> void:
	if brightness_overlay != null:
		brightness_overlay.color.a = clamp(1.0 - v, 0.0, 0.6)

func _ensure_bus(name: String) -> int:
	var idx := AudioServer.get_bus_index(name)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, name)
		AudioServer.set_bus_send(idx, "Master")
	return idx

func _apply_bus_volume(name: String, v: float) -> void:
	var idx := _ensure_bus(name)
	AudioServer.set_bus_mute(idx, v <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(max(v, 0.001)))

func _apply_saved_settings() -> void:
	cfg["name"] = str(Save.data.get("player_name", ""))
	_apply_brightness(float(Save.get_setting("brightness", 1.0)))
	_apply_bus_volume("Music", float(Save.get_setting("vol_music", 1.0)))
	_apply_bus_volume("SFX", float(Save.get_setting("vol_sfx", 1.0)))

# Escolhe a classe atual: guarda no cfg, carrega a aparência guardada e refresca.
func _select_class(cls: String) -> void:
	cfg["cls"] = cls
	var app: Dictionary = Save.data.get("appearance", {})
	var saved = app.get(cls, {})
	cfg["hair_c"] = int(saved.get("hair_c", 1)) if saved is Dictionary else 1
	cfg["cloth_c"] = int(saved.get("cloth_c", 1)) if saved is Dictionary else 1
	_refresh_play()
	_refresh_styles()

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

	# banner central — um CenterContainer full-rect centra mesmo o bloco no
	# ecrã (o antigo PRESET_CENTER só ancorava o canto ao centro, deixando o
	# texto deslocado). Não bloqueia toques (fase transitória "Top 6").
	var banner_center := CenterContainer.new()
	banner_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	banner_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(banner_center)
	banner_box = VBoxContainer.new()
	banner_box.alignment = BoxContainer.ALIGNMENT_CENTER
	banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_box.visible = false
	banner_center.add_child(banner_box)
	banner_big = Label.new()
	banner_big.add_theme_font_size_override("font_size", 46)
	banner_big.add_theme_color_override("font_color", Color("f4c145"))
	banner_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_big.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	banner_big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_box.add_child(banner_big)
	banner_sub = Label.new()
	banner_sub.add_theme_color_override("font_color", Color("ece5d3"))
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	banner_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_box.add_child(banner_sub)

	# moedas ganhas nesta partida (aparece no fim)
	coins_label = Label.new()
	coins_label.add_theme_font_size_override("font_size", 20)
	coins_label.add_theme_color_override("font_color", Color("f4c145"))
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coins_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coins_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coins_label.visible = false
	banner_box.add_child(coins_label)

	# botão persistente para sair para o menu — aparece quando o jogador é
	# eliminado (para poder sair durante a fase dos titãs, sem ficar preso) ou
	# quando o jogo termina. Fica no HUD (não dentro do banner), para não
	# desaparecer com os banners transitórios (ex.: "Top 6" auto-esconde-se).
	menu_btn = Button.new()
	menu_btn.text = Loc.t("back_to_menu")
	menu_btn.add_theme_font_size_override("font_size", 18)
	menu_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	menu_btn.offset_left = -246
	menu_btn.offset_right = -16
	menu_btn.offset_top = 12
	menu_btn.offset_bottom = 60
	menu_btn.visible = false
	menu_btn.pressed.connect(_return_to_menu)
	hud_root.add_child(menu_btn)

	# indicador de recargas (dash + especial), canto inferior esquerdo,
	# por cima da barra de vida — cinzento/relógio até poder ser usado
	var ability_bar = preload("res://scripts/AbilityBar.gd").new()
	ability_bar.arena = arena
	ability_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ability_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ability_bar.offset_left = 16
	ability_bar.offset_right = 150
	ability_bar.offset_top = -108
	ability_bar.offset_bottom = -54
	hud_root.add_child(ability_bar)

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

	var special := HudTouchButton.new()
	special.label = Loc.t("btn_special")
	special.target = "special"
	special.color = Color("f4c145")
	_anchor_bottom(special, 30.0, 68.0, 68.0, BOTTOM + 84.0, true)
	hud_root.add_child(special)

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
	for s in [menu_root, play_root, styles_root, settings_root]:
		if s != null:
			s.visible = false
	hud_root.visible = true
	banner_box.visible = false
	menu_btn.visible = false
	coins_label.visible = false
	arena.setup(cfg)

# Volta ao menu principal e limpa a partida atual.
func _return_to_menu() -> void:
	arena.reset_to_idle()
	hud_root.visible = false
	banner_box.visible = false
	menu_btn.visible = false
	coins_label.visible = false
	_show_screen(menu_root)

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
	# o botão de sair é gerido por _update_exit_button (persistente enquanto o
	# jogador estiver eliminado ou o jogo terminado); atualiza já para resposta
	# imediata a esta mudança de estado.
	_update_exit_button()
	# banners transitórios desaparecem sozinhos; morte/vitória ficam
	if not dead and big == Loc.t("banner_top6_big"):
		await get_tree().create_timer(1.6).timeout
		if arena.phase == Arena.Phase.TITAN or arena.phase == Arena.Phase.TRANSITION:
			banner_box.visible = false
