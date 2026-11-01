extends RefCounted
## City loyalty (the Covenant calls it Dread), updated once a second. Each city
## drifts toward a target built from the factors below; enemy troops inside its
## borders drain it directly. At 0 the city revolts to the Rebels. Tuning lives in
## rules.json "loyalty"; each faction's flavour in factions/*.json "loyalty".

const DB = preload("res://sim/db.gd")
const Entity = preload("res://sim/entity.gd")
const GameMap = preload("res://sim/game_map.gd")

const TILE := GameMap.TILE


static func update(w) -> void:
	var cfg: Dictionary = w.rules.loyalty
	for p in w.players:
		p.weariness = maxf(0.0, p.weariness * (1.0 - float(cfg.weariness_decay)))
	for city in w.entities.values():
		if not city.alive or not w.is_city(city) or city.constructing or city.owner < 0:
			continue
		var p = w.players[city.owner]
		var lc: Dictionary = DB.factions[p.faction].get("loyalty", {})
		if lc.is_empty():
			continue
		if city.id == p.capital_id:
			city.loyalty = 100.0
			city.loyalty_target = 100.0
			city.loyalty_factors = [["Capital", 100.0]]
			continue
		var enemies := _enemies_inside(w, city)
		if enemies > 0:
			city.last_enemy_tick = w.tick_count
		var factors := _factors(w, city, p, cfg, lc)
		var target := 0.0
		for f in factors:
			target += f[1]
		target = clampf(target, 0.0, 100.0)
		city.loyalty_target = target
		city.loyalty_factors = factors
		var before: float = city.loyalty
		city.loyalty = move_toward(city.loyalty, target, float(cfg.drift))
		city.loyalty -= minf(float(cfg.max_enemy_drain), enemies * float(cfg.enemy_drain))
		if city.charter:
			city.loyalty = maxf(city.loyalty, float(cfg.charter_floor))
		city.loyalty = clampf(city.loyalty, 0.0, 100.0)
		if before > float(cfg.warning) and city.loyalty <= float(cfg.warning):
			w.events.append({"type": "unrest", "id": city.id, "owner": city.owner, "pos": city.pos, "label": lc.label})
		if city.loyalty <= 0.0:
			w.revolt(city)


## [label, contribution] pairs that add up to the city's target loyalty.
static func _factors(w, city, p, cfg: Dictionary, lc: Dictionary) -> Array:
	var out: Array = [["Base", float(cfg.base)]]
	var capital = w.get_entity(p.capital_id)
	if capital:
		var tiles: float = city.pos.distance_to(capital.pos) / TILE
		var far := tiles - float(cfg.distance_free)
		if far > 0.0:
			out.append(["Far from the capital", -minf(float(cfg.max_distance_penalty), far * float(cfg.per_tile_far))])
	var over: int = w.city_count(p.index, false) - w.city_limit(p.index)
	if over > 0:
		out.append(["Too many cities", -over * float(cfg.over_limit)])
	if city.captured_tick >= 0 and (w.tick_count - city.captured_tick) * w.DT < float(cfg.recent_capture_time):
		out.append(["Recently conquered", -float(cfg.recent_capture)])
	if p.weariness > 0.5:
		out.append(["War-weariness", -minf(float(cfg.max_weariness), p.weariness)])
	var garrison := 0
	var hero := false
	var library := false
	var wonder := false
	var g_radius := float(cfg.garrison_radius) * TILE
	var c_radius := float(cfg.culture_radius) * TILE
	for e in w.entities.values():
		if not e.alive or e.owner != city.owner:
			continue
		var d: float = e.pos.distance_to(city.pos)
		if e.kind == Entity.UNIT:
			if e.can_attack() and not e.is_worker() and d <= g_radius:
				garrison += 1
			if e.is_hero() and d <= float(cfg.hero_radius) * TILE:
				hero = true
		elif e.kind == Entity.BUILDING and not e.constructing and d <= c_radius:
			library = library or e.def.has("research")
			wonder = wonder or e.def.get("role", "") == "wonder"
	if garrison > 0:
		out.append(["Garrison", minf(float(cfg.max_garrison), garrison * float(lc.get("garrison", 3)))])
	if lc.get("culture", false):
		if library:
			out.append(["Library nearby", float(cfg.library)])
		if wonder:
			out.append(["Wonder nearby", float(cfg.wonder)])
	if hero:
		out.append(["Hero visiting", float(cfg.hero)])
	if (w.tick_count - city.last_enemy_tick) * w.DT >= float(cfg.peace_time):
		out.append(["Peace", float(cfg.peace)])
	if p.mod("loyalty") > 0.0:
		out.append(["Medicine", p.mod("loyalty")])
	return out


## Enemy soldiers standing in this city's borders.
static func _enemies_inside(w, city) -> int:
	var n := 0
	for e in w.entities.values():
		if e.alive and e.kind == Entity.UNIT and e.inside < 0 and w.is_enemy(city, e) and e.can_attack() and not e.is_worker():
			if w.territory_owner(GameMap.to_tile(e.pos)) == city.owner and e.pos.distance_to(city.pos) <= 12.0 * TILE:
				n += 1
	return n
