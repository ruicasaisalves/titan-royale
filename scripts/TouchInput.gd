extends Node
# ============================================================
#  Estado partilhado dos controlos táteis (autoload "Touch").
#  Os widgets (HudJoystick, HudTouchButton) escrevem aqui;
#  o PlayerController lê e junta com o teclado numa Intent.
#  Assim a simulação continua a não saber de onde vem o input.
# ============================================================

# Põe a true para testares os controlos táteis no PC com o rato.
const FORCE_ON_DESKTOP := false

var enabled: bool = false
var move: Vector2 = Vector2.ZERO   # direção do joystick, magnitude 0..1
var attack: bool = false
var dash: bool = false

func _ready() -> void:
	# 'mobile' garante Android/iOS mesmo que a deteção de ecrã táctil falhe
	enabled = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available() or FORCE_ON_DESKTOP

func reset() -> void:
	move = Vector2.ZERO
	attack = false
	dash = false
