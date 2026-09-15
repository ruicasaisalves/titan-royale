class_name Intent
extends RefCounted
# A "intenção" de um lutador num tick: para onde se quer mover,
# se quer atacar e se quer usar o dash. Os controladores produzem
# isto; a simulação (Arena) aplica-o de forma IDÊNTICA venha de
# uma IA, do jogador local, ou (no futuro) de um jogador remoto.

var move: Vector2 = Vector2.ZERO
var attack: bool = false
var dash: bool = false
var special: bool = false   # usar o ataque especial da classe (1 por classe)
