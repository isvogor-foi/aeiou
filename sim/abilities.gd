extends RefCounted
## Spells: checks, casting and autocast rules. Spell data lives in data/abilities.json;
## every cast is paid from the owner's Mana and then goes on cooldown.

const DB = preload("res://sim/db.gd")
const Entity = preload("res://sim/entity.gd")
const GameMap = preload("res://sim/game_map.gd")

const TILE := GameMap.TILE
## Autocast only looks for trouble this far beyond a spell's range (tiles).
const AUTOCAST_ALERT := 7.0


static func def(id: String) -> Dictionary:
	return DB.abilities.get(id, {})


static func is_ready(w, e, id: String) -> bool:
	return int(e.cooldowns.get(id, 0)) <= w.tick_count


static func can_pay(w, e, id: String) -> bool:
	return w.players[e.owner].res.mana >= float(def(id).mana)


## Seconds until `id` is ready again.
static func cooldown_left(w, e, id: String) -> float:
	return maxf(0.0, (int(e.cooldowns.get(id, 0)) - w.tick_count) * w.DT)


## Why `caster` can't cast `id` on `target`/`pos` right now (range aside), or "".
static func cast_error(w, caster, id: String, target) -> String:
	var a := def(id)
	if a.is_empty() or not id in caster.def.get("abilities", []):
		return "Unknown spell"
	if not is_ready(w, caster, id):
		return "%s is not ready" % a.name
	if not can_pay(w, caster, id):
		return "Not enough " + DB.resource_name("mana")
	match a.target:
		"unit_ally":
			if target == null or not target.alive or target.kind != Entity.UNIT or target.owner != caster.owner:
				return "Target a friendly unit"
		"unit_enemy":
			if target == null or not target.alive or target.kind == Entity.RESOURCE or not w.is_enemy(caster, target):
				return "Target an enemy"
			if a.has("target_domain") and (target.kind != Entity.UNIT or target.domain() != a.target_domain):
				return "%s needs a %s target" % [a.name, "ship" if a.target_domain == "naval" else a.target_domain]
	return ""


## Casts immediately (range must already be satisfied). Returns true on success.
static func cast(w, caster, id: String, target, pos: Vector2) -> bool:
	if cast_error(w, caster, id, target) != "":
		return false
	var a := def(id)
	w.players[caster.owner].res.mana -= float(a.mana)
	caster.cooldowns[id] = w.tick_count + roundi(float(a.cooldown) * w.TICK_RATE)
	var at: Vector2 = target.pos if target else (pos if a.target == "ground" else caster.pos)
	var radius := float(a.get("radius", 0.0)) * TILE
	match a.effect:
		"heal":
			for t in _targets(w, caster, a, target, at, radius, false):
				t.hp = minf(t.max_hp, t.hp + float(a.amount))
		"shield":
			for t in _targets(w, caster, a, target, at, radius, false):
				add_effect(w, t, "shield", float(a.amount), float(a.duration))
		"damage":
			var dealt := 0.0
			for t in _targets(w, caster, a, target, at, radius, true):
				dealt += w.apply_damage(caster, t, float(a.amount), a.get("dtype", "arcane"))
				if a.has("slow") and t.alive and t.kind == Entity.UNIT:
					add_effect(w, t, "slow", float(a.slow), float(a.slow_duration))
			if a.has("drain") and caster.alive:
				caster.hp = minf(caster.max_hp, caster.hp + dealt * float(a.drain))
		"pull":
			# Drag a ground target to the caster's side, then hit it.
			if target.domain() == "ground":
				var dir: Vector2 = (target.pos - caster.pos).normalized()
				var spot: Vector2 = caster.pos + dir * TILE * 0.9
				var tile: Vector2i = w.map.nearest_walkable(GameMap.to_tile(spot), 2)
				if tile.x >= 0:
					target.pos = GameMap.tile_center(tile)
					target.prev_pos = target.pos
					target.path = PackedVector2Array()
					target.path_index = 0
			w.apply_damage(caster, target, float(a.amount), a.get("dtype", "physical"))
		"grant":
			var p = w.players[caster.owner]
			for k in a.grant:
				p.res[k] += float(a.grant[k])
		"toggle_deploy":
			caster.deployed = not caster.deployed
			caster.orders.clear()
			caster.path = PackedVector2Array()
			caster.path_index = 0
		"summon":
			for i in int(a.count):
				var spot: Vector2 = caster.pos + Vector2(TILE, 0).rotated(TAU * i / float(a.count))
				var tile: Vector2i = w.map.nearest_walkable(GameMap.to_tile(spot), 4)
				var u = w.spawn_unit(a.unit, caster.owner, GameMap.tile_center(tile) if tile.x >= 0 else caster.pos)
				u.expires_tick = w.tick_count + roundi(float(a.duration) * w.TICK_RATE)
	caster.facing = (at - caster.pos).normalized() if at != caster.pos else caster.facing
	w.events.append({"type": "cast", "ability": id, "vfx": a.get("vfx", ""), "source": caster.id,
			"owner": caster.owner, "from": caster.pos, "to": at, "radius": radius})
	return true


## Units an effect lands on: the single target, or everyone of the right side in the radius.
static func _targets(w, caster, a: Dictionary, target, at: Vector2, radius: float, hostile: bool) -> Array:
	if radius <= 0.0:
		return [target] if target else [caster]
	var out: Array = []
	for e in w.entities.values():
		if not e.alive or e.kind == Entity.RESOURCE:
			continue
		if hostile != w.is_enemy(caster, e) or (not hostile and e.owner != caster.owner):
			continue
		if e.kind != Entity.UNIT and not hostile:
			continue
		if w.edge_dist_point(e, at) <= radius:
			out.append(e)
	return out


## Adds or refreshes a timed effect (the stronger one wins).
static func add_effect(w, e, type: String, amount: float, duration: float) -> void:
	var until: int = w.tick_count + roundi(duration * w.TICK_RATE)
	for fx in e.effects:
		if fx.type == type:
			fx.amount = maxf(fx.amount, amount)
			fx.until = maxi(fx.until, until)
			return
	e.effects.append({"type": type, "amount": amount, "until": until})


static func effect_amount(e, type: String) -> float:
	for fx in e.effects:
		if fx.type == type:
			return fx.amount
	return 0.0


# --- Autocast -----------------------------------------------------------------------------

## Casts the first autocast spell that has a good use right now. Returns true if it cast.
static func try_autocast(w, e) -> bool:
	for id in e.def.get("abilities", []):
		if not e.autocast.get(id, false) or not is_ready(w, e, id) or not can_pay(w, e, id):
			continue
		var a := def(id)
		var range_px := float(a.range) * TILE
		match a.target:
			"unit_ally":
				var t = _ally_in_need(w, e, a, range_px)
				if t and cast(w, e, id, t, t.pos):
					return true
			"unit_enemy":
				var t = _enemy_for(w, e, range_px)
				if t and cast(w, e, id, t, t.pos):
					return true
			"ground":
				var p = _cluster_spot(w, e, range_px, float(a.get("radius", 1.0)) * TILE)
				if p != null and cast(w, e, id, null, p):
					return true
			"self":
				if _worth_self_cast(w, e, a) and cast(w, e, id, null, e.pos):
					return true
	return false


static func _ally_in_need(w, e, a: Dictionary, range_px: float):
	var best = null
	var best_missing := 0.0
	for o in w.entities.values():
		if not o.alive or o.kind != Entity.UNIT or o.owner != e.owner or o.pos.distance_to(e.pos) > range_px:
			continue
		var missing: float = o.max_hp - o.hp
		if a.effect == "heal" and missing < float(a.amount) * 0.5:
			continue
		if a.effect == "shield" and (o.hp > o.max_hp * 0.75 or effect_amount(o, "shield") > 0.0 or w.find_enemy_near(o, AUTOCAST_ALERT * TILE) == null):
			continue
		if missing > best_missing:
			best_missing = missing
			best = o
	return best


static func _enemy_for(w, e, range_px: float):
	if not e.orders.is_empty() and e.orders[0].type == "attack":
		var t = w.get_entity(e.orders[0].target)
		if t and t.alive and t.kind == Entity.UNIT and w.edge_dist(e, t) <= range_px:
			return t
	var t = w.find_enemy_near(e, range_px)
	return t if t and t.kind == Entity.UNIT else null


## An enemy position within range with at least 3 enemies inside the blast radius.
static func _cluster_spot(w, e, range_px: float, radius: float):
	var best = null
	var best_n := 2
	for o in w.entities.values():
		if not o.alive or o.kind != Entity.UNIT or not w.is_enemy(e, o) or o.pos.distance_to(e.pos) > range_px:
			continue
		if not w.is_visible_to(e.owner, o):
			continue
		var n := 0
		for q in w.entities.values():
			if q.alive and q.kind == Entity.UNIT and w.is_enemy(e, q) and q.pos.distance_to(o.pos) <= radius:
				n += 1
		if n > best_n:
			best_n = n
			best = o.pos
	return best


static func _worth_self_cast(w, e, a: Dictionary) -> bool:
	if a.effect == "toggle_deploy":
		# Dig in when enemies come close; pack up once they're long gone.
		var near = w.find_enemy_near(e, AUTOCAST_ALERT * TILE)
		return (near != null) != e.deployed
	if w.find_enemy_near(e, AUTOCAST_ALERT * TILE) == null:
		return false
	if a.effect != "shield":
		return true
	var allies := 0
	for o in w.entities.values():
		if o.alive and o.kind == Entity.UNIT and o.owner == e.owner and o.pos.distance_to(e.pos) <= float(a.radius) * TILE:
			allies += 1
	return allies >= 4
