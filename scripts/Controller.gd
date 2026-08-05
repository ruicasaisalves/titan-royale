class_name Controller
extends RefCounted
# Base de todos os controladores.
# Um Fighter não sabe QUEM o controla — só recebe uma Intent.
#   AIController     -> decide sozinho
#   PlayerController -> lê o input local
#   (futuro) RemoteController -> lê a intent recebida pela rede
# Para adicionar multiplayer, basta criar RemoteController e trocar
# o controller do lutador. A simulação não muda.

func decide(_f, _arena) -> Intent:
	return Intent.new()
