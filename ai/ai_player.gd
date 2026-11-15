extends RefCounted
## Computer opponent. Thinks a few times a second and acts only through
## World.issue(), exactly like the human player. Tuning lives in data/ai.json:
## the difficulty sets speed and bonuses, the faction's personality sets the plan.

const DB = preload("res://sim/db.gd")
const Entity = preload("res://sim/entity.gd")
const GameMap = preload("res://sim/game_map.gd")
const Research = preload("res://sim/research.gd")

const TILE := GameMap.TILE
## Buildings keep this many free tiles around them so paths stay open.
const BUILD_MARGIN := 1
## How far (tiles) workers will travel for a resource once nearby ones run out.
const FAR_RESOURCE := 45.0
## Enemies this close to one of our cities (in tiles) count as an invasion.
const DEFENSE_RADIUS := 14.0

var w
var pid := 0
var p
var diff: Dictionary
var style: Dictionary
var think_ticks := 10
var difficulty_id := "normal"
var tick_offset := 0

var _home := Vector2.ZERO
var _next_wave_time := 0.0
var _wave_count := 0
## Units currently out on an attack wave.
var _wave: Array[int] = []
var _wave_start_hp := 0.0
var _wave_target := Vector2.ZERO

# Snapshot of our side, rebuilt every think.
var _units: Array = []
var _workers: Array = []
var _army: Array = []
var _buildings: Array = []
var _cities: Array = []
var _queued := {}
var _saving_for_age := false
## Buildings with no valid site anywhere near home (e.g. docks on a map without shore).
var _no_site := {}
## Island crossings: "" (on foot), "boarding" or "sailing".
var _wave_phase := ""
var _reach_cache := {}
var _phase_since := 0.0
## Share of the next age-up already in the bank (0..1).
var _age_progress := 0.0


func setup(world, index: int, difficulty: String) -> void:
	difficulty_id = difficulty
	w = world
	pid = index
	p = world.players[index]
	var ai: Dictionary = DB.ai
	diff = ai.difficulties.get(difficulty, ai.difficulties.normal)
	style = ai.personalities.get(p.faction, ai.personalities.values()[0])
	think_ticks = maxi(1, roundi(float(diff.think_interval) * w.TICK_RATE))
	tick_offset = index * 3 % think_ticks
	p.handicap = float(diff.handicap)
	p.tracks_fog = not bool(diff.omniscient)
	# The AI knows the map layout (like a player who has seen it before), not where units are.
	p.knows_map = true
	for e in w.entities.values():
		if e.owner == pid and w.is_city(e):
			_home = e.pos
	_next_wave_time = float(style.first_wave) * float(diff.first_wave_scale)


func _now() -> float:
	return w.tick_count * w.DT


func think() -> void:
	if p.defeated:
		return
	_snapshot()
	_proclaim_lands()
	_economy()
	_fishing()
	_housing()
	_age_up()
	_construction()
	_research()
	_train_hero()
	_train_army()
	_expand()
	_defend()
	_relics()
	_keep_loyal()
	_waves()


# --- Snapshot ---------------------------------------------------------------------------

func _snapshot() -> void:
	_units.clear()
	_workers.clear()
	_army.clear()
	_buildings.clear()
	_cities.clear()
	_queued.clear()
	for e in w.entities.values():
		if not e.alive or e.owner != pid:
			continue
		if e.kind == Entity.UNIT:
			_units.append(e)
			# Units count toward their line (army_mix names a line by its first unit).
			_count(DB.line_root(e.type_id))
			if e.is_worker():
				_workers.append(e)
			elif not e.def.get("fisher", false) and not e.def.has("capacity"):
				_army.append(e)
		elif e.kind == Entity.BUILDING:
			_buildings.append(e)
			_count(e.type_id)
			if w.is_city(e) and not e.constructing:
				_cities.append(e)
			for item in e.queue:
				if item.kind == "unit":
					_count(DB.line_root(item.type))


func _count_workers_of(type_id: String) -> int:
	return _workers.filter(func(u): return u.type_id == type_id).size()


## Proclaims each new city the next crown land on the personality's list.
func _proclaim_lands() -> void:
	if not _faction().get("crown_lands", false):
		return
	for c in _cities:
		if c.crown_land != "":
			continue
		for land in style.get("crown_land_order", []):
			if not land in p.crown_lands:
				w.issue({"type": "crown_land", "player": pid, "building": c.id, "land": land})
				return


func _count(type_id: String) -> void:
	_queued[type_id] = _queued.get(type_id, 0) + 1


func _have(type_id: String) -> int:
	return _queued.get(type_id, 0)


## An entry of a per-age table in ai.json; ages past its end use the last entry.
func _per_age(table: Array):
	return table[clampi(p.age - 1, 0, table.size() - 1)]


func _faction() -> Dictionary:
	return DB.factions[p.faction]


## Spend only if the purchase leaves enough for what we're saving up for
## (a pending age-up, and the hero once one is wanted).
func _can_spend(cost: Dictionary) -> bool:
	if not p.can_afford(cost):
		return false
	var reserve := {}
	if _saving_for_age and p.age < w.final_age():
		for k in DB.ages[p.age].cost:
			reserve[k] = reserve.get(k, 0.0) + float(DB.ages[p.age].cost[k])
	var hero_id: String = p.hero_type if p.hero_type != "" else style.get("hero", _faction().get("hero", ""))
	if hero_id != "" and int(DB.units[hero_id].get("age", 1)) <= p.age and w.hero_count(pid) == 0:
		for k in DB.units[hero_id].cost:
			reserve[k] = reserve.get(k, 0.0) + float(DB.units[hero_id].cost[k])
	for k in cost:
		if p.res[k] - float(cost[k]) < float(reserve.get(k, 0.0)):
			return false
	return true


# --- Economy ----------------------------------------------------------------------------

func _economy() -> void:
	# More workers, up to the plan for this age and the difficulty's ceiling.
	var target := mini(int(_per_age(style.workers)), int(diff.max_workers))
	var worker_type: String = _faction().worker
	# Frontier militia (Grenzer) double as workers once Croatia is ours.
	if "croatia" in p.crown_lands and _have("grenzer") < roundi(_workers.size() * float(style.get("militia_share", 0.0))):
		worker_type = "grenzer"
	for c in _cities:
		if _workers.size() + _have(worker_type) - _count_workers_of(worker_type) >= target:
			break
		if c.queue.size() < 2 and p.can_afford(DB.units[worker_type].cost):
			if w.issue({"type": "train", "player": pid, "building": c.id, "unit": worker_type}) == "":
				_count(worker_type)
	# Spread gatherers so each resource fills (but doesn't waste) its gather cap.
	var rates: Dictionary = DB.ai.est_worker_rate
	var current := {}
	var idle: Array = []
	for u in _workers:
		var o = u.orders[0] if not u.orders.is_empty() else null
		if o == null:
			idle.append(u)
		elif o.type == "gather":
			current[o.res] = current.get(o.res, 0) + 1
	var wanted := {}
	for res in rates:
		if res == "coal" and p.age < int(DB.ai.get("coal_from_age", 4)):
			wanted[res] = 0
			continue
		var full: float = p.gather_cap(res) / (float(rates[res]) * p.handicap)
		# Shift effort away from what is piling up toward what is running short.
		var bank: float = p.res[res]
		if bank > 600.0:
			full *= 0.35
		elif bank > 300.0:
			full *= 0.7
		wanted[res] = maxi(1, ceili(full))
	# Rebalance one worker per think away from an over-subscribed resource.
	for res in wanted:
		if current.get(res, 0) > wanted[res] + 1:
			for u in _workers:
				if not u.orders.is_empty() and u.orders[0].type == "gather" and u.orders[0].res == res:
					idle.append(u)
					current[res] -= 1
					break
			break
	for u in idle:
		var res := _most_needed(wanted, current)
		if _send_to_gather(u, res):
			current[res] = current.get(res, 0) + 1


func _most_needed(wanted: Dictionary, current: Dictionary) -> String:
	var best := "herbs"
	var best_gap := -INF
	for res in wanted:
		if wanted[res] <= 0:
			continue
		var gap: float = float(wanted[res] - current.get(res, 0)) / maxf(1.0, wanted[res])
		if gap > best_gap:
			best_gap = gap
			best = res
	return best


func _send_to_gather(u, res: String) -> bool:
	var base: Vector2 = _nearest_city_pos(u.pos)
	if res == "herbs":
		var garden = _open_garden(u.pos)
		if garden:
			return w.issue({"type": "gather", "player": pid, "ids": [u.id], "target": garden.id}) == ""
	if res == "timber":
		var tile: Vector2i = w.map.nearest_forest(GameMap.to_tile(base), 16)
		if tile.x < 0:
			return false
		return w.issue({"type": "gather", "player": pid, "ids": [u.id], "tile": tile}) == ""
	var node = w.nearest_resource(res, base, 18.0 * TILE, pid)
	if node == null:
		# Home deposits are gone: look further afield and set up a drop-off beside it.
		node = w.nearest_resource(res, base, FAR_RESOURCE * TILE, pid)
		if node == null:
			return false
		_ensure_dropoff_near(node)
	return w.issue({"type": "gather", "player": pid, "ids": [u.id], "target": node.id}) == ""


## Builds a storehouse next to a distant resource inside our borders (once).
func _ensure_dropoff_near(node) -> void:
	var drop = w.nearest_dropoff(pid, node.def.resource, node.pos)
	if drop and w.rect_dist(drop.rect(), node.pos) < 10.0 * TILE:
		return
	for b in _buildings:
		if b.type_id == "storehouse" and b.pos.distance_to(node.pos) < 10.0 * TILE:
			return
	if w.territory_owner(node.tile) == pid:
		_build("storehouse", node.pos, true)


## Our nearest finished herb garden with room for another gatherer.
func _open_garden(from: Vector2):
	var tending := {}
	for u in _workers:
		if not u.orders.is_empty() and u.orders[0].type == "gather" and u.orders[0].has("target"):
			tending[u.orders[0].target] = tending.get(u.orders[0].target, 0) + 1
	var best = null
	var best_d := INF
	for b in _buildings:
		if b.def.has("resource") and not b.constructing and tending.get(b.id, 0) < int(b.def.get("max_gatherers", 2)):
			var d: float = b.pos.distance_to(from)
			if d < best_d:
				best_d = d
				best = b
	return best


func _nearest_city_pos(from: Vector2) -> Vector2:
	var best := _home
	var best_d := INF
	for c in _cities:
		var d: float = c.pos.distance_to(from)
		if d < best_d:
			best_d = d
			best = c.pos
	return best


## Skiffs fish the nearest shoal; each docks keeps a few skiffs.
func _fishing() -> void:
	var skiffs: Array = _units.filter(func(u): return u.def.get("fisher", false))
	for s in skiffs:
		if s.orders.is_empty():
			var fish = w.nearest_resource("herbs", s.pos, 40.0 * TILE, pid, "naval")
			if fish:
				w.issue({"type": "gather", "player": pid, "ids": [s.id], "target": fish.id})
	var docks: Array = _buildings.filter(func(b): return b.type_id == "docks" and not b.constructing)
	if docks.is_empty() or _have("skiff") >= int(DB.ai.skiffs_per_docks) * docks.size():
		return
	if w.nearest_resource("herbs", docks[0].pos, 40.0 * TILE, pid, "naval") == null:
		return
	if docks[0].queue.size() < 2 and p.can_afford(DB.units.skiff.cost):
		w.issue({"type": "train", "player": pid, "building": docks[0].id, "unit": "skiff"})


func _housing() -> void:
	if p.pop_cap >= p.pop_limit():
		return
	if p.pop_cap - p.pop_used > 3 + _cities.size() * 2:
		return
	for b in _buildings:
		if b.type_id == "dwelling" and b.constructing:
			return
	_build("dwelling", _home, true)


# --- Ages and research --------------------------------------------------------------------

func _age_up() -> void:
	_saving_for_age = false
	_age_progress = 0.0
	if p.age >= w.final_age() or p.advancing_age:
		return
	if _workers.size() < int(_per_age(style.age_up_workers)):
		return
	var cost: Dictionary = DB.ages[p.age].cost
	# Start hoarding once the age-up is about a fifth paid for; until then keep spending.
	var progress := 1.0
	for k in cost:
		progress = minf(progress, p.res[k] / maxf(1.0, float(cost[k])))
	_age_progress = progress
	_saving_for_age = progress >= 0.22
	if not p.can_afford(cost):
		return
	for c in _cities:
		if c.queue.size() < 2 and w.issue({"type": "advance_age", "player": pid, "building": c.id}) == "":
			_saving_for_age = false
			return


## Follows the style's research plan. "military" means the upgrade line of
## whichever of our military buildings is least upgraded.
func _research() -> void:
	for step in style.research:
		var branch: String = step[0]
		var level: int = int(step[1])
		if branch == "military":
			branch = _weakest_upgrade()
			if branch == "":
				continue
		if int(p.techs.get(branch, 0)) >= level or p.researching.has(branch):
			continue
		if Research.next_level(p, branch) != level or level > Research.max_level(branch):
			continue
		var info := Research.level_info(branch, level)
		if info.age > p.age:
			continue
		var where = _research_building(branch)
		if where == null or where.queue.size() >= 1:
			continue
		if _can_spend(info.cost):
			w.issue({"type": "research", "player": pid, "building": where.id, "branch": branch})
		return


func _research_building(branch: String):
	for b in _buildings:
		if not b.constructing and branch in b.def.get("research", []):
			return b
	return null


func _weakest_upgrade() -> String:
	var best := ""
	var best_level := 99
	for b in _buildings:
		if b.constructing or b.def.get("role", "") != "military":
			continue
		for br in b.def.get("research", []):
			var lv: int = int(p.techs.get(br, 0))
			if lv < best_level and not p.researching.has(br):
				best = br
				best_level = lv
	return best


func _first_complete(type_id: String):
	for b in _buildings:
		if b.type_id == type_id and not b.constructing:
			return b
	return null


# --- Construction -------------------------------------------------------------------------

func _construction() -> void:
	var military: String = _military_building()
	var want := int(_per_age(style.military_buildings))
	if _have(military) < want and _workers.size() >= 6:
		_build(military, _home)
	elif _have("library") == 0 and _workers.size() >= int(style.library_at_workers):
		_build("library", _home)
	elif _missing_extra_building() != "":
		_build(_missing_extra_building(), _home)
	elif _workers.size() >= 8 and _have("garden") < _gardens_wanted():
		_build("garden", _nearest_city_pos(_home), true)


## First building from the personality's age plan that we don't have yet.
func _missing_extra_building() -> String:
	for step in style.get("extra_buildings", []):
		if int(step[1]) <= p.age and _have(step[0]) == 0 and _workers.size() >= 10 and not _no_site.has(step[0]):
			return step[0]
	return ""


## Enough gardens for the herb workers, once the wild herb patches near home run low.
func _gardens_wanted() -> int:
	var wild := 0.0
	for e in w.entities.values():
		if e.alive and e.kind == Entity.RESOURCE and e.def.resource == "herbs" and e.pos.distance_to(_home) < 18 * TILE:
			wild += e.amount
	var herb_workers := ceili(p.gather_cap("herbs") / (float(DB.ai.est_worker_rate.herbs) * p.handicap))
	var want := ceili(herb_workers / 2.0)
	return want if wild < 1200.0 else want / 2


func _military_building() -> String:
	for b in _faction().buildable:
		if DB.buildings[b].get("role", "") == "military":
			return b
	return ""


## Places `type_id` near `around` with a worker; returns true if a site was found.
func _build(type_id: String, around: Vector2, essential := false) -> bool:
	var def: Dictionary = DB.buildings[type_id]
	var cost: Dictionary = def.get("cost", {})
	if not (p.can_afford(cost) if essential else _can_spend(cost)):
		return false
	var site := _find_site(type_id, GameMap.to_tile(around))
	if site.x < 0:
		# Crowded at home: try around our other cities.
		for c in _cities:
			site = _find_site(type_id, GameMap.to_tile(c.pos), 3, 14)
			if site.x >= 0:
				break
	if site.x < 0:
		if DB.buildings[type_id].get("coastal", false):
			_no_site[type_id] = true
		return false
	var builder = _pick_builder(GameMap.tile_center(site))
	if builder == null:
		return false
	return w.issue({"type": "place", "player": pid, "ids": [builder.id], "building": type_id, "tile": site}) == ""


func _find_site(type_id: String, center: Vector2i, min_r := 3, max_r := 10) -> Vector2i:
	var s := int(DB.buildings[type_id].size)
	for r in range(min_r, max_r + 1):
		var candidates: Array[Vector2i] = []
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) == r:
					candidates.append(center + Vector2i(dx, dy) - Vector2i(s, s) / 2)
		# Vary the order a little so buildings don't always line up on one side.
		candidates.sort_custom(func(a, b): return (a.x * 7 + a.y * 13 + w.tick_count) % 5 < (b.x * 7 + b.y * 13 + w.tick_count) % 5)
		# Shore buildings can't keep a ring of open land around them.
		var margin := 0 if DB.buildings[type_id].get("coastal", false) else BUILD_MARGIN
		for t in candidates:
			var pad := Vector2i(margin, margin)
			if w.map.area_free(t - pad, Vector2i(s, s) + pad * 2) and w.placement_error(pid, type_id, t) == "":
				return t
	return Vector2i(-1, -1)


func _pick_builder(near: Vector2):
	var best = null
	var best_d := INF
	for u in _workers:
		var busy: bool = not u.orders.is_empty() and u.orders[0].type == "build"
		if busy:
			continue
		var d: float = u.pos.distance_to(near)
		if d < best_d:
			best_d = d
			best = u
	return best


# --- Expansion ----------------------------------------------------------------------------

func _expand() -> void:
	var city_type: String = _faction().city
	if w.city_count(pid) >= w.city_limit(pid):
		return
	var need := int(style.expand_workers[mini(_cities.size() - 1, style.expand_workers.size() - 1)]) if _cities.size() > 0 else 0
	if _workers.size() < need:
		return
	if not p.can_afford(DB.buildings[city_type].cost):
		return
	# Found the new city by the nearest unclaimed resource node.
	var best := Vector2i(-1, -1)
	var best_d := INF
	for e in w.entities.values():
		if not e.alive or e.kind != Entity.RESOURCE or w.territory_owner(e.tile) >= 0:
			continue
		var d: float = e.pos.distance_to(_home)
		# Gold is what runs out first, so new cities favour gold mines.
		if e.def.resource == "gold":
			d *= 0.6
		if d >= best_d:
			continue
		var site := _find_site(city_type, e.tile, 3, 6)
		if site.x >= 0:
			best = site
			best_d = d
	if best.x < 0:
		return
	var ids: Array = []
	for u in _workers:
		if ids.size() >= 3:
			break
		if u.orders.is_empty() or u.orders[0].type == "gather":
			ids.append(u.id)
	if not ids.is_empty():
		w.issue({"type": "place", "player": pid, "ids": ids, "building": city_type, "tile": best})


# --- Military -----------------------------------------------------------------------------

func _train_hero() -> void:
	var hero_id: String = p.hero_type if p.hero_type != "" else style.get("hero", _faction().get("hero", ""))
	if hero_id == "" or int(DB.units[hero_id].get("age", 1)) > p.age or w.hero_count(pid) > 0:
		return
	for c in _cities:
		# Heroes come first: they don't wait for the next age-up's savings.
		if c.queue.size() < 2 and p.can_afford(DB.units[hero_id].cost):
			w.issue({"type": "train", "player": pid, "building": c.id, "unit": hero_id})
			return


func _train_army() -> void:
	if _army.size() >= int(diff.army_cap):
		return
	var mix: Dictionary = style.army_mix
	for b in _buildings:
		if b.constructing or b.def.get("role", "") != "military" or b.queue.size() >= 2:
			continue
		var type := _next_army_type(mix, b)
		if type == "":
			continue
		# Keep a minimum army (the first wave's size) even while saving for the next age.
		var below_wave := _fighters(_army).size() < roundi(float(style.wave_base) * float(diff.wave_scale)) \
				and _age_progress < 0.8
		var cost: Dictionary = DB.units[DB.tier(type, p.age)].cost
		if not (p.can_afford(cost) if below_wave else _can_spend(cost)):
			continue
		if w.issue({"type": "train", "player": pid, "building": b.id, "unit": type}) == "":
			_count(type)


## The unit type furthest below its share of the army (one supply unit from Age 2).
func _next_army_type(mix: Dictionary, b) -> String:
	for t in b.def.trains:
		if DB.units[t].has("supply_radius") and int(DB.units[t].get("age", 1)) <= p.age and _have(t) == 0:
			return t
	var total := 0
	var share_sum := 0.0
	for t in mix:
		total += _have(t)
		if int(DB.units[t].get("age", 1)) <= p.age:
			share_sum += float(mix[t])
	var best := ""
	var best_gap := -INF
	for t in mix:
		if not t in b.def.trains or int(DB.units[t].get("age", 1)) > p.age:
			continue
		# Shares are renormalised over the unit types this age unlocks.
		var gap: float = float(mix[t]) / maxf(share_sum, 0.01) - float(_have(t)) / maxf(1.0, total)
		if gap > best_gap:
			best_gap = gap
			best = t
	return best


func _fighters(units: Array) -> Array:
	return units.filter(func(u): return u.can_attack())


## Shaky cities get a garrison, a charter (Monarchy) or a blood tithe (Covenant).
func _keep_loyal() -> void:
	var cfg: Dictionary = w.rules.loyalty
	var lc: Dictionary = _faction().get("loyalty", {})
	for c in _cities:
		if c.id == p.capital_id or c.loyalty > 45.0:
			continue
		if lc.get("charters", false) and not c.charter and p.age >= int(cfg.charter_age):
			w.issue({"type": "charter", "player": pid, "building": c.id})
		if lc.get("tithe", false) and c.loyalty < 35.0:
			w.issue({"type": "tithe", "player": pid, "building": c.id})
		var sent := 0
		for u in _fighters(_army):
			if sent >= 3 or _wave.has(u.id) or not u.orders.is_empty() or u.domain() != "ground":
				continue
			if u.pos.distance_to(c.pos) > float(cfg.garrison_radius) * TILE:
				w.issue({"type": "move", "player": pid, "ids": [u.id], "pos": c.pos + Vector2(0, 3 * TILE)})
				sent += 1


## Relics this AI has spotted (id -> true); it only goes after those.
var _seen_relics := {}


## AEIOU: send idle soldiers to fetch loose relics and bring them to our treasury.
func _relics() -> void:
	if not w.relics_spawned:
		return
	var holder = null
	for b in _buildings:
		if w.is_relic_holder(b):
			holder = b
	if holder == null:
		return
	var claimed := {}
	for u in _army:
		if u.relic >= 0 and (u.orders.is_empty() or u.orders[0].type != "store"):
			w.issue({"type": "store", "player": pid, "ids": [u.id], "target": holder.id})
		if not u.orders.is_empty() and u.orders[0].type == "pickup":
			claimed[u.orders[0].target] = true
	for e in w.entities.values():
		if not e.alive or not e.def.get("relic", false) or e.inside >= 0 or e.carried_by >= 0 or claimed.has(e.id):
			continue
		# Only relics we have seen (remembered once spotted): without full vision the
		# AI must scout for them like the player does.
		if not _seen_relics.has(e.id):
			if not w.is_visible_to(pid, e):
				continue
			_seen_relics[e.id] = true
		var best = null
		var best_d := INF
		for u in _fighters(_army):
			if _wave.has(u.id) or u.relic >= 0 or u.domain() == "naval" or not u.orders.is_empty():
				continue
			var d: float = u.pos.distance_to(e.pos)
			if d < best_d:
				best_d = d
				best = u
		if best:
			w.issue({"type": "pickup", "player": pid, "ids": [best.id], "target": e.id})


## Sends the army at home against enemies inside our land.
func _defend() -> void:
	var threat = null
	var threat_d := INF
	for e in w.entities.values():
		if not e.alive or e.owner < 0 or e.owner == pid or e.kind != Entity.UNIT:
			continue
		if w.territory_owner(GameMap.to_tile(e.pos)) != pid or not w.is_visible_to(pid, e):
			continue
		for c in _cities:
			var d: float = c.pos.distance_to(e.pos)
			if d < DEFENSE_RADIUS * TILE and d < threat_d:
				threat_d = d
				threat = e
	if threat == null:
		return
	var ids: Array = []
	for u in _fighters(_army):
		if _wave.has(u.id):
			continue
		var busy: bool = not u.orders.is_empty() and u.orders[0].type == "attack"
		if not busy:
			ids.append(u.id)
	if not ids.is_empty():
		w.issue({"type": "attack_move", "player": pid, "ids": ids, "pos": threat.pos})


func _waves() -> void:
	var live: Array[int] = []
	var hp := 0.0
	for id in _wave:
		var u = w.get_entity(id)
		if u and u.alive:
			live.append(id)
			hp += u.hp
	_wave = live
	if _wave_phase != "" and not _wave.is_empty():
		_ferry()
		return
	if not _wave.is_empty():
		if hp < _wave_start_hp * float(style.retreat_below):
			w.issue({"type": "move", "player": pid, "ids": _wave.duplicate(), "pos": _home})
			_end_wave()
			return
		# Keep pushing: idle wave units head for the (possibly new) target.
		var target := _attack_target()
		if target == Vector2.INF:
			_end_wave()
			return
		# Stranded on our own shore (e.g. the transport sank): ferry them again.
		if not _reachable_on_foot(target):
			var home_side := _wave.filter(func(id): return w.get_entity(id).domain() == "ground" and w.get_entity(id).pos.distance_to(_home) < 30.0 * TILE)
			if home_side.size() * 2 > _wave.size():
				_wave_target = target
				_start_ferry()
				return
		var idle: Array = []
		for id in _wave:
			var u = w.get_entity(id)
			if u.orders.is_empty() and u.inside < 0:
				idle.append(id)
		var retarget := target != _wave_target
		_wave_target = target
		if retarget:
			w.issue({"type": "attack_move", "player": pid, "ids": _wave.duplicate(), "pos": target})
		elif not idle.is_empty():
			w.issue({"type": "attack_move", "player": pid, "ids": idle, "pos": target})
		return
	if _now() < _next_wave_time:
		return
	var size := _next_wave_size()
	var ready: Array = []
	for u in _army:
		if u.orders.is_empty() or u.orders[0].type == "move":
			ready.append(u)
	if _fighters(ready).size() < size:
		return
	var target := _attack_target()
	if target == Vector2.INF:
		return
	_wave.clear()
	_wave_start_hp = 0.0
	for u in ready:
		_wave.append(u.id)
		_wave_start_hp += u.hp
	_wave_target = target
	if not _reachable_on_foot(target):
		_start_ferry()
		return
	w.issue({"type": "attack_move", "player": pid, "ids": _wave.duplicate(), "pos": target})


## Whether ground troops at home can walk to `target` (cached; terrain rarely opens up).
func _reachable_on_foot(target: Vector2) -> bool:
	var key := GameMap.to_tile(target)
	if not _reach_cache.has(key):
		var path: PackedVector2Array = w.map.find_path(_home, key)
		_reach_cache[key] = not path.is_empty() and path[path.size() - 1].distance_to(target) < 6.0 * TILE
	return _reach_cache[key]


## Flyers go straight in; ground troops board our transports.
func _start_ferry() -> void:
	var boats: Array = _units.filter(func(u): return u.def.has("capacity"))
	if boats.is_empty():
		_order_transport()
		_wave.clear()
		return
	var flyers: Array = []
	var walkers: Array = []
	for id in _wave:
		var u = w.get_entity(id)
		if u.domain() == "ground":
			walkers.append(id)
		else:
			flyers.append(id)
	if not flyers.is_empty():
		w.issue({"type": "attack_move", "player": pid, "ids": flyers, "pos": _wave_target})
	# Fill boats one after another.
	var i := 0
	for boat in boats:
		var room: int = w.cargo_space(boat)
		var group: Array = []
		while i < walkers.size() and room > 0:
			group.append(walkers[i])
			room -= int(w.get_entity(walkers[i]).def.get("pop", 1))
			i += 1
		if not group.is_empty():
			w.issue({"type": "board", "player": pid, "ids": group, "target": boat.id})
	_wave_phase = "boarding"
	_phase_since = _now()


func _ferry() -> void:
	var boats: Array = _units.filter(func(u): return u.def.has("capacity"))
	match _wave_phase:
		"boarding":
			var waiting := _wave.any(func(id): return w.get_entity(id).orders.size() > 0 and w.get_entity(id).orders[0].type == "board")
			if not waiting or _now() - _phase_since > 40.0:
				var loaded: Array = boats.filter(func(b): return not b.cargo.is_empty())
				if loaded.is_empty():
					_wave_phase = ""
					return
				w.issue({"type": "unload", "player": pid, "ids": loaded.map(func(b): return b.id), "pos": _wave_target})
				_wave_phase = "sailing"
				_phase_since = _now()
		"sailing":
			if boats.all(func(b): return b.cargo.is_empty()) or _now() - _phase_since > 90.0:
				_wave_phase = ""
				# Landed troops pick up the attack from here.
				w.issue({"type": "attack_move", "player": pid, "ids": _wave.filter(func(id): return w.get_entity(id).inside < 0), "pos": _wave_target})


func _order_transport() -> void:
	for b in _buildings:
		if b.type_id == "docks" and not b.constructing and b.queue.size() < 2 and _have("transport") < 2:
			if p.can_afford(DB.units.transport.cost):
				w.issue({"type": "train", "player": pid, "building": b.id, "unit": "transport"})
			return


func _next_wave_size() -> int:
	return roundi((float(style.wave_base) + float(style.wave_growth) * _wave_count) * float(diff.wave_scale))


func _end_wave() -> void:
	_wave.clear()
	_wave_count += 1
	_next_wave_time = _now() + float(style.wave_interval) * float(diff.wave_interval_scale)


## Nearest enemy city. Borders are public knowledge, so every city's location is known.
func _attack_target() -> Vector2:
	var best := Vector2.INF
	var best_d := INF
	for e in w.entities.values():
		if not e.alive or not w.is_city(e) or e.owner == pid or e.owner < 0:
			continue
		var d: float = e.pos.distance_to(_home)
		if d < best_d:
			best_d = d
			best = e.pos
	return best
