extends Node
# ============================================================
#  Localização (autoload "Loc").
#  O jogo só está disponível em português e inglês: deteta o
#  idioma do sistema no arranque e usa "pt" para quem tem o
#  sistema em português; todos os outros jogam em "en".
#
#  Uso:
#    Loc.t("chave")               -> string no idioma atual
#    Loc.t("chave", [arg1, arg2]) -> formata com % (como printf)
# ============================================================

var lang: String = "en"

const STRINGS := {
	# ---- ecrã de criação ----
	"creation_class_title": {"pt": "1 · Escolhe a tua classe", "en": "1 · Choose your class"},
	"creation_fighter_title": {"pt": "2 · O teu lutador", "en": "2 · Your fighter"},
	"name_label": {"pt": "Nome:", "en": "Name:"},
	"name_placeholder": {"pt": "Heroi sem nome", "en": "Nameless hero"},
	"color_label": {"pt": "Cor:", "en": "Color:"},
	"hair_label": {"pt": "Cabelo:", "en": "Hair:"},
	"cloth_label": {"pt": "Roupa:", "en": "Clothes:"},
	"hint_touch": {
		"pt": "Toque: joystick a esquerda, ATACAR / DASH / ESPECIAL a direita.",
		"en": "Touch: joystick on the left, ATTACK / DASH / SPECIAL on the right.",
	},
	"hint_keyboard": {
		"pt": "WASD/setas mover · espaco atacar · shift dash · Q especial · ou arrasta o rato",
		"en": "WASD/arrows move · space attack · shift dash · Q special · or drag the mouse",
	},
	# popups dos ataques especiais
	"sp_ready": {"pt": "Especial!", "en": "Special!"},
	"sp_guard": {"pt": "Escudo!", "en": "Guard!"},
	"sp_rage": {"pt": "Furia!", "en": "Rage!"},
	"sp_poison": {"pt": "Veneno!", "en": "Poison!"},
	"sp_bless": {"pt": "Bencao!", "en": "Blessing!"},
	"btn_special": {"pt": "ESP", "en": "SP"},
	"enter_arena": {"pt": "ENTRAR NA ARENA", "en": "ENTER THE ARENA"},
	"back_to_menu": {"pt": "MENU PRINCIPAL", "en": "MAIN MENU"},
	"coins_earned": {"pt": "+%d moedas", "en": "+%d coins"},
	"menu_stats": {
		"pt": "Vitórias %d · Derrotas %d · Moedas %d",
		"en": "Wins %d · Losses %d · Coins %d",
	},

	# ---- menu principal ----
	"menu_play": {"pt": "JOGAR", "en": "PLAY"},
	"menu_styles": {"pt": "ESTILOS", "en": "STYLES"},
	"menu_settings": {"pt": "DEFINIÇÕES", "en": "SETTINGS"},
	"back": {"pt": "‹ Voltar", "en": "‹ Back"},

	# ---- ecrã jogar ----
	"choose_champion": {"pt": "Escolhe o teu Champion", "en": "Choose your champion"},
	"champion_hint": {"pt": "Toca num Champion para ver os detalhes.", "en": "Tap a champion to see its details."},

	# ---- ecrã estilos ----
	"styles_title": {"pt": "Estilos", "en": "Styles"},

	# ---- ecrã definições ----
	"settings_title": {"pt": "Definições", "en": "Settings"},
	"setting_brightness": {"pt": "Brilho", "en": "Brightness"},
	"setting_music": {"pt": "Música", "en": "Music"},
	"setting_sfx": {"pt": "Efeitos", "en": "Sound FX"},

	# ---- stats ----
	"stat_hp": {"pt": "Vida", "en": "Health"},
	"stat_atk": {"pt": "Ataque", "en": "Attack"},
	"stat_def": {"pt": "Defesa", "en": "Defense"},
	"stat_spd": {"pt": "Velocidade", "en": "Speed"},
	"stat_range": {"pt": "Alcance", "en": "Range"},

	# ---- HUD ----
	"hud_alive": {"pt": "Vivos: %d", "en": "Alive: %d"},
	"hud_phase": {"pt": "Fase: %s", "en": "Phase: %s"},
	"phase_royale": {"pt": "Royale", "en": "Royale"},
	"phase_titans": {"pt": "Titãs", "en": "Titans"},
	"gear_weapons": {"pt": "Armas x%d (+%d%%)  ", "en": "Weapons x%d (+%d%%)  "},
	"gear_armor": {"pt": "Armadura  ", "en": "Armor  "},
	"gear_heal": {"pt": "Cura x%d  ", "en": "Heal x%d  "},
	"gear_crit": {"pt": "Crit x%d", "en": "Crit x%d"},

	# ---- controlos táteis ----
	"btn_attack": {"pt": "ATACAR", "en": "ATTACK"},
	"btn_dash": {"pt": "DASH", "en": "DASH"},

	# ---- banners ----
	"banner_eliminated_big": {"pt": "Eliminado", "en": "Eliminated"},
	"banner_eliminated_sub": {"pt": "Ficaste em #%d", "en": "You placed #%d"},
	"banner_top6_big": {"pt": "Top 6", "en": "Top 6"},
	"banner_top6_sub": {"pt": "A arena desperta...", "en": "The arena awakens..."},
	"banner_victory_big": {"pt": "VITÓRIA", "en": "VICTORY"},
	"banner_victory_sub": {"pt": "%s é o último titã!", "en": "%s is the last titan!"},
	"banner_end_big": {"pt": "Fim", "en": "End"},
	"banner_end_sub": {"pt": "%s venceu", "en": "%s won"},

	# ---- outros ----
	"default_name": {"pt": "TU", "en": "YOU"},
}

func _ready() -> void:
	# get_locale_language() devolve só o código base (ex.: "pt", "en").
	lang = "pt" if OS.get_locale_language() == "pt" else "en"

func t(key: String, args: Array = []) -> String:
	var entry: Dictionary = STRINGS.get(key, {})
	var s: String = entry.get(lang, entry.get("en", key))
	if args.is_empty():
		return s
	return s % args
