class_name HudJoystick
extends Control
# Joystick virtual. O dedo que tocar dentro da zona fica "preso" ao
# joystick pelo seu índice de toque (multi-touch real). Escreve a direção
# em Touch.move com magnitude 0..1 (analógico).
#
# Usa make_input_local(): converte a posição do toque para o espaço de
# coordenadas DESTE widget, o que funciona seja qual for o stretch do
# ecrã ou a transformação do CanvasLayer — sem isso, num telemóvel com
# o viewport esticado, o toque podia "cair" fora da zona.

var radius: float = 60.0
var knob_radius: float = 26.0
var _touch_index: int = -1
var _knob: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(radius * 2.0, radius * 2.0)

func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	var ev: InputEvent = make_input_local(event)
	var pos: Vector2 = ev.position
	var c: Vector2 = size / 2.0
	if ev is InputEventScreenTouch:
		if ev.pressed and _touch_index == -1:
			if (pos - c).length() <= radius * 1.4:
				_touch_index = ev.index
				_update(pos)
		elif not ev.pressed and ev.index == _touch_index:
			_release()
	elif ev is InputEventScreenDrag and ev.index == _touch_index:
		_update(pos)

func _update(pos: Vector2) -> void:
	var off: Vector2 = pos - size / 2.0
	if off.length() > radius:
		off = off.normalized() * radius
	_knob = off
	Touch.move = off / radius
	queue_redraw()

func _release() -> void:
	_touch_index = -1
	_knob = Vector2.ZERO
	Touch.move = Vector2.ZERO
	queue_redraw()

func _draw() -> void:
	var c: Vector2 = size / 2.0
	draw_circle(c, radius, Color(1, 1, 1, 0.07))
	draw_arc(c, radius, 0, TAU, 24, Color(1, 1, 1, 0.28), 2.0)
	var k: Color = Color(0.957, 0.757, 0.271, 0.9 if _touch_index != -1 else 0.6)
	draw_circle(c + _knob, knob_radius, k)
	draw_arc(c + _knob, knob_radius, 0, TAU, 16, Color(0, 0, 0, 0.35), 1.5)
