extends Node
# ============================================================
#  Definição das classes (arquétipos).
#  Tempo em SEGUNDOS, velocidade em PIXÉIS/SEGUNDO — para
#  encaixar no ciclo baseado em delta do Godot.
# ============================================================

const DATA := {
	"Bruto": {
		"hp": 110.0, "atk": 12.0, "def": 4.0, "speed": 81.0, "range": 24.0,
		"cd": 0.63, "size": 8.5, "color": Color("c9d1e0"),
		"role": "Equilibrado. Bom para começar.",
	},
	"Tanque": {
		"hp": 240.0, "atk": 9.0, "def": 11.0, "speed": 45.0, "range": 26.0,
		"cd": 0.97, "size": 11.5, "color": Color("5a86b4"),
		"role": "Muita vida e defesa, lento e fraco a atacar.",
	},
	"Assassino": {
		"hp": 62.0, "atk": 22.0, "def": 2.0, "speed": 135.0, "range": 22.0,
		"cd": 0.43, "size": 7.5, "color": Color("d1453b"),
		"role": "Rápido e letal, mas de vidro.",
	},
	"Barbaro": {
		"hp": 150.0, "atk": 17.0, "def": 6.0, "speed": 66.0, "range": 30.0,
		"cd": 0.77, "size": 10.0, "color": Color("e08a3c"),
		"role": "Dano alto e resistência sólida.",
	},
	"Arqueiro": {
		"hp": 80.0, "atk": 15.0, "def": 3.0, "speed": 87.0, "range": 150.0,
		"cd": 1.10, "size": 8.0, "color": Color("4fd6c9"),
		"role": "Ataca de longe. Frágil ao corpo-a-corpo.",
	},
	"Necromante": {
		"hp": 95.0, "atk": 11.0, "def": 3.0, "speed": 72.0, "range": 130.0,
		"cd": 1.07, "size": 9.0, "color": Color("7ac74f"),
		"role": "25% de erguer um zombie ao matar (10% dos stats).",
		"necro": true,
	},
	"Sacerdote": {
		"hp": 70.0, "atk": 8.0, "def": 4.0, "speed": 78.0, "range": 100.0,
		"cd": 1.00, "size": 8.5, "color": Color("efe3a8"),
		"role": "Ataque/vida baixos, regenera 1% de vida / 5s.",
		"regen": 0.01, "regen_every": 5.0,
	},
}

func names() -> Array:
	return DATA.keys()
