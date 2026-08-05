class_name AIController
extends Controller
# IA simples: procura o inimigo mais próximo (respeitando equipas,
# por isso um zombie nunca ataca o seu necromante nem os irmãos),
# aproxima-se e ataca quando está ao alcance.

func decide(f, arena) -> Intent:
	var intent := Intent.new()
	var target = _find_target(f, arena)
	f.target = target
	if target == null:
		return intent
	var to: Vector2 = target.position - f.position
	var dist: float = to.length()
	if dist > f.attack_range:
		intent.move = to / max(dist, 0.001)
	else:
		intent.attack = true
	return intent

func _find_target(f, arena):
	var best = null
	var best_d: float = INF
	# 1) tentativa rápida via grelha espacial (vizinhança)
	var candidates: Array = arena.grid.query(f.position, f.attack_range + 160.0)
	for o in candidates:
		if o == f or not o.alive or o.team == f.team:
			continue
		var d: float = f.position.distance_squared_to(o.position)
		if d < best_d:
			best_d = d
			best = o
	# 2) fallback: se a vizinhança estava vazia, varre tudo (raro)
	if best == null:
		for o in arena.fighters:
			if o == f or not o.alive or o.team == f.team:
				continue
			var d2: float = f.position.distance_squared_to(o.position)
			if d2 < best_d:
				best_d = d2
				best = o
	return best
