class_name SpatialGrid
extends RefCounted
# Particionamento espacial. Em vez de comparar cada lutador com
# TODOS os outros (100x100 = 10.000/tick, e 500x500 = 250.000/tick),
# só olhamos para as células vizinhas. É isto que te deixa escalar
# dos 100 para as centenas sem a simulação engasgar.

var cell_size: float = 100.0
var _cells: Dictionary = {}

func clear() -> void:
	_cells.clear()

func _key(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / cell_size)), int(floor(p.y / cell_size)))

func insert(f) -> void:
	var k := _key(f.position)
	if not _cells.has(k):
		_cells[k] = []
	_cells[k].append(f)

func query(pos: Vector2, radius: float) -> Array:
	var out: Array = []
	var r: int = int(ceil(radius / cell_size))
	var c := _key(pos)
	for x in range(c.x - r, c.x + r + 1):
		for y in range(c.y - r, c.y + r + 1):
			var k := Vector2i(x, y)
			if _cells.has(k):
				out.append_array(_cells[k])
	return out
