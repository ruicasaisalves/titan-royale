class_name PlayerController
extends Controller
# Lê o input local (teclado, rato ou controlos táteis) e converte-o
# numa Intent. Continua a NÃO mexer no lutador — só devolve a
# intenção, exatamente como a IA. Por isso o mobile não muda a
# simulação: muda apenas de onde vem a intenção.

func decide(f, arena) -> Intent:
	var intent := Intent.new()
	var dir := Vector2.ZERO

	# 1) teclado
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0

	if Touch.enabled:
		# 2) joystick tátil (analógico: magnitude 0..1)
		if Touch.move != Vector2.ZERO:
			dir = Touch.move
	elif dir == Vector2.ZERO and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		# 3) arrastar o rato (só no desktop — no mobile o joystick manda)
		var m: Vector2 = arena.get_local_mouse_position() - f.position
		if m.length() > 6.0:
			dir = m.normalized()

	# limit_length mantém o analógico do joystick e normaliza o teclado
	intent.move = dir.limit_length(1.0)
	intent.attack = Input.is_key_pressed(KEY_SPACE) or Touch.attack
	intent.dash = Input.is_key_pressed(KEY_SHIFT) or Touch.dash
	intent.special = Input.is_key_pressed(KEY_Q) or Touch.special
	return intent
