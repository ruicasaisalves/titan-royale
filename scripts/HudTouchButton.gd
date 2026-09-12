class_name HudTouchButton
extends Control
# Botão tátil multi-touch: fica premido enquanto o dedo que lhe tocou
# estiver em baixo (segue-o pelo índice de toque). Escreve em
# Touch.attack ou Touch.dash conforme o 'target'.
# Usa make_input_local() pelo mesmo motivo do joystick (ver lá).

var label: String = "A"
var target: String = "attack"   # "attack" | "dash"
var radius: float = 34.0
var color: Color = Color("d1453b")
var _touch_index: int = -1
var is_down: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(radius * 2.0, radius * 2.0)

func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch):
		return
	var ev: InputEvent = make_input_local(event)
	var pos: Vector2 = ev.position
	var c: Vector2 = size / 2.0
	if ev.pressed and _touch_index == -1:
		if (pos - c).length() <= radius * 1.25:
			_touch_index = ev.index
			_set_down(true)
	elif not ev.pressed and ev.index == _touch_index:
		_touch_index = -1
		_set_down(false)

func _set_down(v: bool) -> void:
	is_down = v
	if target == "attack":
		Touch.attack = v
	else:
		Touch.dash = v
	queue_redraw()

func _draw() -> void:
	var c: Vector2 = size / 2.0
	var bg: Color = color
	bg.a = 0.85 if is_down else 0.32
	draw_circle(c, radius, bg)
	draw_arc(c, radius, 0, TAU, 24, color, 2.0)
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(c.x - radius, c.y + 5.0), label, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 13, Color.WHITE)
