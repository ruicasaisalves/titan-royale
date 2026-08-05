class_name PlayerController
extends Controller
# Lê o input local e converte-o numa Intent. Repara que NÃO mexe
# diretamente no lutador — só devolve a intenção, tal como a IA.

func decide(f, arena) -> Intent:
	var intent := Intent.new()
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	# arrastar o rato também move
	if dir == Vector2.ZERO and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var m: Vector2 = arena.get_local_mouse_position() - f.position
		if m.length() > 6.0:
			dir = m
	if dir != Vector2.ZERO:
		intent.move = dir.normalized()
	intent.attack = Input.is_key_pressed(KEY_SPACE)
	intent.dash = Input.is_key_pressed(KEY_SHIFT)
	return intent
