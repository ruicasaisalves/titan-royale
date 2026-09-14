extends Node
# Perfil persistente do jogador (autoload "Save"). Guarda vitórias/derrotas,
# moedas e (no futuro) upgrades comprados na loja, num ficheiro JSON em
# user:// — pasta de dados persistente por dispositivo (em Android, os dados
# privados da app; sobrevive a fechar/reabrir o jogo). É local ao aparelho:
# sincronizar entre dispositivos exigiria um backend, fora do âmbito por agora.

const PATH := "user://profile.json"

var data := {
	"wins": 0,
	"losses": 0,
	"games": 0,
	"best_place": 999,
	"coins": 0,
	"upgrades": {},   # ex.: {"hp": 2} — reservado para a loja futura
}

func _ready() -> void:
	load_profile()

func load_profile() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		data.merge(parsed, true)   # mantém chaves novas do default

func save_profile() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Não consegui gravar o perfil em %s" % PATH)
		return
	f.store_string(JSON.stringify(data))

# Regista uma partida terminada e grava. Devolve as moedas ganhas.
func record_match(won: bool, place: int, coins: int) -> int:
	data["games"] = int(data.get("games", 0)) + 1
	if won:
		data["wins"] = int(data.get("wins", 0)) + 1
	else:
		data["losses"] = int(data.get("losses", 0)) + 1
	data["best_place"] = min(int(data.get("best_place", 999)), place)
	data["coins"] = int(data.get("coins", 0)) + coins
	save_profile()
	return coins
