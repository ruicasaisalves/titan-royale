class_name CharacterComposer
extends RefCounted
# Compõe em runtime a folha de sprite do JOGADOR a partir das camadas em
# res://assets/heroes_layers/<Classe>/ (extraídas do pack Heroes99 por
# tools/extract_player_layers.py). O jogador escolhe a cor do cabelo e da
# roupa; os 99 da IA continuam nas folhas prontas em assets/fighters/.
#
# Ordem das camadas (baixo->cima), igual a tools/compose_fighters.py:
#   weapon_bot, skin, face, hair_bot, cloth_bot, hair_top, cloth_top, weapon_top
# Folha 800x680 (grelha 8x17, célula 100x40) — mesmo layout que Fighter fatia.

const DIR := "res://assets/heroes_layers/"
const SHEET := Vector2i(800, 680)

# Cache por (classe|cabelo|roupa) para não recompor a mesma combinação.
static var _cache: Dictionary = {}

static func compose(cls: String, hair_c: int, cloth_c: int) -> Texture2D:
	var key := "%s|%d|%d" % [cls, hair_c, cloth_c]
	if _cache.has(key):
		return _cache[key]
	var dir := DIR + cls + "/"
	if not ResourceLoader.exists(dir + "skin.png"):
		_cache[key] = null   # sem camadas -> Fighter usa a folha da classe
		return null
	var base := Image.create(SHEET.x, SHEET.y, false, Image.FORMAT_RGBA8)
	base.fill(Color(0, 0, 0, 0))
	var order := [
		"weapon_bot", "skin", "face",
		"hair_bot_c%d" % hair_c, "cloth_bot_c%d" % cloth_c,
		"hair_top_c%d" % hair_c, "cloth_top_c%d" % cloth_c,
		"weapon_top",
	]
	for n in order:
		var p: String = dir + str(n) + ".png"
		if not ResourceLoader.exists(p):
			continue
		var tex: Texture2D = load(p)
		if tex == null:
			continue
		var img: Image = tex.get_image()
		if img == null:
			continue
		if img.is_compressed():
			img.decompress()   # importado com compressão VRAM -> RGBA legível
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		base.blend_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i(0, 0))
	var out := ImageTexture.create_from_image(base)
	_cache[key] = out
	return out

# Textura do frame "idle" (célula 0,0) para a pré-visualização do menu.
static func preview(cls: String, hair_c: int, cloth_c: int) -> Texture2D:
	var at := AtlasTexture.new()
	at.atlas = compose(cls, hair_c, cloth_c)
	at.region = Rect2(0, 0, 100, 40)
	return at
