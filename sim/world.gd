extends RefCounted
## Authoritative game state, advanced in fixed ticks. Everything that changes the
## game goes through issue(), so the player, AI and tutorials share one path.

const DB = preload("res://sim/db.gd")
const Entity = preload("res://sim/entity.gd")
const GameMap = preload("res://sim/game_map.gd")
const PlayerState = preload("res://sim/player_state.gd")
const Research = preload("res://sim/research.gd")
const Territory = preload("res://sim/territory.gd")
const UnitAI = preload("res://sim/unit_ai.gd")
const Abilities = preload("res://sim/abilities.gd")
const Generator = preload("res://mapgen/generator.gd")
const AIPlayer = preload("res://ai/ai_player.gd")
const Loyalty = preload("res://sim/loyalty.gd")

const TICK_RATE := 20
const DT := 1.0 / TICK_RATE
const TILE := GameMap.TILE
const UNIT_RADIUS := UnitAI.UNIT_RADIUS
const FOG_INTERVAL := 4
const SCAN_INTERVAL := 5
## Cell size (px) of the spatial index used for proximity queries.
const GRID_CELL := TILE * 4.0

var map := GameMap.new()
var territory := Territory.new()
var players: Array = []
var entities: Dictionary = {}
var tick_count := 0
## Things that happened this tick, for the view (hits, deaths, completions, victory).
var events: Array = []
var winner := -1
var rules: Dictionary = {}
var fog_version := 0
## Computer opponents, one per non-human player.
var ais: Array = []
var _next_id := 1
## Spatial index of living units, rebuilt each tick: cell -> [Entity].
var _unit_grid := {}
## Living buildings, rebuilt each tick.
var _buildings: Array = []
## Living units with an aura (heroes, colossi), rebuilt each tick.
var _aura_units: Array = []
## Lingering area effects (poison clouds): [{pos, radius, dps, dtype, owner, until}].
var areas: Array = []
## Victory timers: player -> {condition: tick it started}.
var victory_since := {}
var relics_spawned := false
## Index of Hungary, the internal enemy that revolting cities join.
var rebels := -1
## Hungary has risen with its own city and AI (see rules.hungary).
var hungary_risen := false
## Difficulty the computer players were set up with (Hungary's AI uses it too).
var ai_difficulty := "normal"
## The last age of this match (skirmish "Last age", or the last playable age).
## 0 in saves made before it existed: final_age() then falls back to the data.
var max_age := 0
## Scripted scenario state (saved) and the script driving it (re-attached on load).
var scenario := {}
var scenario_logic: RefCounted = null
## How much faster the fast-build and fast-advance cheats make progress.
const CHEAT_SPEED := 10.0
var _land_tiles := 0


## `human_index` -1 makes every player a computer opponent (for tests and soak runs).
## `map_type`: "inland" (lakes), "coastal" (a shared central sea) or "islands".
## `options` (skirmish setup, all optional): map_size ("small"/"normal"/"large"),
## start_age, resources ("standard"/"high"/"deathmatch"), victories {kind: bool}, explored.
func new_game(seed_value: int, faction_ids: Array, human_index := 0, difficulty := "normal", map_type := "inland", options := {}) -> void:
	DB.ensure_loaded()
	# A private copy, so skirmish options never leak into the shared data.
	rules = DB.rules.duplicate(true)
	var sk: Dictionary = rules.skirmish
	var size := int(sk.map_sizes.get(options.get("map_size", "normal"), rules.map_size))
	var res_mult := float(sk.resources.get(options.get("resources", "standard"), 1.0))
	for k in options.get("victories", {}):
		rules.victory.enabled[k] = bool(options.victories[k])
	if options.has("hungary"):
		rules.hungary.enabled = bool(options.hungary)
	ai_difficulty = difficulty
	var last := DB.last_age(bool(options.get("all_ages", false)))
	var end := int(options.get("end_age", 0))
	max_age = clampi(end if end > 0 else last, clampi(int(options.get("start_age", 1)), 1, last), last)
	var layout := Generator.generate(map, seed_value, size, map_type)
	territory.setup(map.width, map.height)
	for i in faction_ids.size():
		var p := PlayerState.new()
		p.index = i
		p.faction = faction_ids[i]
		p.is_human = i == human_index
		p.tracks_fog = p.is_human
		# Factions own their colours (Monarchy gold, Covenant red); fall back to the slot colour.
		var fdef_color: Array = DB.factions[p.faction].get("color", rules.player_colors[i])
		p.color = DB.color_of(fdef_color)
		p.base_caps = rules.gather_caps
		p.base_pop_limit = int(rules.pop_limit)
		for k in rules.start_resources:
			p.res[k] = float(rules.start_resources[k]) * res_mult
		if res_mult > 1.0:
			p.res.coal = maxf(p.res.coal, 100.0 * res_mult)
		p.age = clampi(int(options.get("start_age", 1)), 1, max_age)
		p.vis.resize(map.width * map.height)
		if options.get("explored", false):
			p.vis.fill(1)
		players.append(p)
	for n in layout.nodes:
		spawn_resource(n.type, n.tile)
	for i in players.size():
		var p = players[i]
		var fdef: Dictionary = DB.factions[p.faction]
		var start: Vector2i = layout.starts[i]
		var city := spawn_building(fdef.city, i, start - Vector2i(2, 2), true)
		p.capital_id = city.id
		if fdef.get("crown_lands", false):
			city.crown_land = capital_land(p.faction)
		for j in int(fdef.start_workers):
			_spawn_from(city, fdef.worker)
	_add_rebels()
	for p in players:
		refresh_crown_lands(p.index)
	for p in players:
		if not p.is_human and not p.is_rebels:
			var ai := AIPlayer.new()
			ai.setup(self, p.index, difficulty)
			ais.append(ai)
	for p in players:
		refit_units(p.index)
	events = events.filter(func(ev): return ev.type != "refit")
	_update_territory()
	_update_pop()
	update_fog()
	# Label the map's connected regions now (during loading), not on the first order.
	map.region_of(Vector2i.ZERO)
	if players[0].age >= int(rules.victory.relics_spawn_age):
		_spawn_relics()


## Hungary, the internal enemy: cities that revolt join it, and mid-game it rises
## with a city of its own and an AI (see _hungary_rises). It fights everyone but
## can't win or lose the match (is_rebels).
func _add_rebels() -> void:
	var r := PlayerState.new()
	r.index = players.size()
	r.faction = "hungary"
	r.is_rebels = true
	r.tracks_fog = false
	r.color = DB.color_of(DB.factions.hungary.color)
	r.base_caps = rules.gather_caps
	r.base_pop_limit = int(rules.pop_limit)
	r.vis.resize(map.width * map.height)
	players.append(r)
	rebels = r.index


## The Hungarian rising: a city near the map centre (fair to both starts on the
## point-symmetric map), workers, a garrison and an AI that attacks every side.
func hungary_rises() -> void:
	hungary_risen = true
	var hu: Dictionary = rules.hungary
	var site := _hungary_site()
	if site.x < 0:
		return
	var city := spawn_building(DB.factions.hungary.city, rebels, site, true)
	var p = players[rebels]
	p.capital_id = city.id
	p.age = maxi(1, players[0].age - 1)
	for k in p.res:
		p.res[k] = maxf(p.res[k], 300.0)
	for i in int(hu.get("workers", 4)):
		_spawn_from(city, DB.factions.hungary.worker)
	for g in hu.get("garrison", []):
		for i in int(g[1]):
			_spawn_from(city, g[0])
	var ai := AIPlayer.new()
	ai.setup(self, rebels, ai_difficulty)
	ais.append(ai)
	territory.dirty = true
	_update_pop()
	events.append({"type": "hungary_rises", "pos": city.pos, "id": city.id})


## Free 4x4 ground nearest the map centre, preferring land no one holds.
func _hungary_site() -> Vector2i:
	var size := int(DB.buildings[DB.factions.hungary.city].size)
	var center := Vector2i(map.width / 2 - size / 2, map.height / 2 - size / 2)
	var fallback := Vector2i(-1, -1)
	for r in range(0, maxi(map.width, map.height) / 2):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var t := center + Vector2i(dx, dy)
				if not map.area_free(t - Vector2i.ONE, Vector2i(size + 2, size + 2)):
					continue
				var too_close := false
				for e in entities.values():
					if e.alive and is_city(e) and e.pos.distance_to((Vector2(t) + Vector2.ONE * size * 0.5) * TILE) < float(rules.city_min_distance) * TILE:
						too_close = true
						break
				if too_close:
					continue
				var owner := territory_owner(t + Vector2i.ONE * (size / 2))
				if owner < 0:
					return t
				if fallback.x < 0:
					fallback = t
	return fallback


# --- Spawning -----------------------------------------------------------------

func _new_entity(type_id: String, kind: int, owner: int) -> Entity:
	var e := Entity.new()
	e.id = _next_id
	_next_id += 1
	e.type_id = type_id
	e.def = DB.get_def(type_id)
	assert(not e.def.is_empty(), "Unknown type " + type_id)
	e.kind = kind
	e.owner = owner
	e.max_hp = _max_hp_for(e)
	e.hp = e.max_hp
	entities[e.id] = e
	return e


## Base HP from data, scaled by the owner's research.
func _max_hp_for(e: Entity) -> float:
	var base := float(e.def.get("hp", 1))
	if e.owner < 0:
		return base
	var p = players[e.owner]
	if e.kind == Entity.BUILDING:
		return base * (1.0 + p.mod("building_hp"))
	if e.kind == Entity.UNIT and e.can_attack() and not e.is_worker():
		return base * (1.0 + p.mod("unit_hp") + p.mod("unit_hp@" + Research.trainer_of(e.type_id)))
	return base


## Re-derives max HP after research or a change of owner, keeping the HP fraction.
func _refresh_max_hp(e: Entity) -> void:
	var frac := e.hp / e.max_hp
	e.max_hp = _max_hp_for(e)
	e.hp = e.max_hp * frac


func spawn_unit(type_id: String, owner: int, pos: Vector2) -> Entity:
	var e := _new_entity(type_id, Entity.UNIT, owner)
	for id in e.def.get("abilities", []):
		# The computer opponent lets every spell autocast; players get each spell's default.
		e.autocast[id] = Abilities.def(id).get("autocast", false) or not players[owner].is_human
	# Tiny id-based offset so units spawned on one spot can be pushed apart.
	e.pos = pos + Vector2(0.5, 0.0).rotated(e.id * 2.4)
	e.prev_pos = e.pos
	return e


func spawn_building(type_id: String, owner: int, top_left: Vector2i, complete: bool) -> Entity:
	var e := _new_entity(type_id, Entity.BUILDING, owner)
	var s := int(e.def.size)
	e.size = Vector2i(s, s)
	e.tile = top_left
	e.pos = e.rect().get_center()
	e.prev_pos = e.pos
	e.constructing = not complete
	if e.def.has("resource"):
		e.amount = -1.0
	if not complete:
		e.hp = e.max_hp * 0.1
		e.build_progress = 0.0
	else:
		territory.dirty = true
	map.occupy(e.tile, e.size, e.id)
	return e


func spawn_resource(type_id: String, top_left: Vector2i) -> Entity:
	var e := _new_entity(type_id, Entity.RESOURCE, -1)
	var s := int(e.def.size)
	e.size = Vector2i(s, s)
	e.tile = top_left
	e.pos = e.rect().get_center()
	e.prev_pos = e.pos
	e.amount = float(e.def.amount)
	if e.def.get("blocking", true):
		map.occupy(e.tile, e.size, e.id)
	return e


## Spawns a unit next to building `b`, on the side facing its rally point.
func _spawn_from(b: Entity, type_id: String) -> Entity:
	var toward: Vector2 = b.rally.get("pos", b.pos + Vector2(0, 1000))
	var spot := map.approach_tile(b.tile, b.size, toward, DB.units[type_id].get("domain", "ground"))
	return spawn_unit(type_id, b.owner, GameMap.tile_center(spot))


func kill(e: Entity) -> void:
	if not e.alive:
		return
	e.alive = false
	e.hp = 0.0
	if e.kind == Entity.BUILDING or (e.kind == Entity.RESOURCE and e.def.get("blocking", true)):
		map.vacate(e.tile, e.size)
	for id in e.cargo:
		var passenger := get_entity(id)
		if passenger:
			kill(passenger)
	if e.kind == Entity.BUILDING:
		_abandon_queue(e)
		territory.dirty = true
		if is_city(e):
			if e.crown_land != "":
				e.crown_land = ""
				refresh_crown_lands(e.owner)
		if e.def.get("role", "") == "wonder":
			refresh_crown_lands(e.owner)
		_drop_relics_in(e)
	if e.relic >= 0:
		_drop_relic(get_entity(e.relic), e.pos)
	if e.is_hero() and e.owner >= 0:
		players[e.owner].hero_fallen = true
	if e.kind == Entity.UNIT and e.owner >= 0 and e.can_attack() and not e.is_worker() and e.expires_tick == 0:
		players[e.owner].weariness += float(rules.loyalty.weariness_per_loss)
	if is_city(e) and e.owner >= 0:
		_reassign_capital(e.owner)
	events.append({"type": "died", "id": e.id, "kind": e.kind, "owner": e.owner, "pos": e.pos, "size": e.size,
			"hero": e.kind == Entity.UNIT and e.is_hero()})


## Clears a building's queue without refunds, releasing research/age locks.
func _abandon_queue(b: Entity) -> void:
	for item in b.queue:
		_release_item(b.owner, item)
	b.queue.clear()


func _release_item(owner: int, item: Dictionary) -> void:
	match item.kind:
		"tech":
			players[owner].researching.erase(item.type)
		"age":
			players[owner].advancing_age = false


# --- Combat ---------------------------------------------------------------------

## A weapon strike from `attacker` (unit or building) on `target`. `base_override`
## replaces the weapon's damage (e.g. a wagon fort firing its garrison's guns).
func deal_damage(attacker: Entity, target: Entity, base_override := -1.0, dtype_override := "") -> void:
	var base := float(attacker.def.damage) if base_override < 0.0 else base_override
	if attacker.owner >= 0:
		var p = players[attacker.owner]
		if attacker.kind == Entity.UNIT and not attacker.is_worker():
			base *= 1.0 + p.mod("damage") + p.mod("damage@" + Research.trainer_of(attacker.type_id))
		elif attacker.kind == Entity.BUILDING:
			base += p.mod("city_damage")
	var passives: Dictionary = attacker.def.get("passives", {})
	if attacker.charge_ready and passives.has("charge"):
		base *= 1.0 + float(passives.charge.bonus)
	attacker.charge_ready = false
	attacker.moved = 0.0
	base *= 1.0 + float(attacker.def.get("bonus_vs", {}).get(target.def.armor, 0.0))
	var land := territory_owner(GameMap.to_tile(attacker.pos))
	if land >= 0 and land != attacker.owner and attacker.owner >= 0:
		base *= 1.0 - players[land].mod("home_defense")
	if passives.has("home_guard") and land == attacker.owner:
		base *= 1.0 + float(passives.home_guard.damage)
	if passives.has("high_ground") and has_high_ground(attacker, target):
		base *= 1.0 + float(passives.high_ground.damage)
	if passives.has("frenzy") and attacker.hp < attacker.max_hp * float(passives.frenzy.below):
		base *= 1.0 + float(passives.frenzy.damage)
	if passives.has("volley") and _comrades_near(attacker, float(passives.volley.radius) * TILE) >= int(passives.volley.min):
		base *= 1.0 + float(passives.volley.damage)
	base *= 1.0 + Abilities.effect_amount(attacker, "boost")
	base *= 1.0 + viribus_unitis(attacker)
	if attacker.kind == Entity.UNIT and attacker.owner >= 0:
		base *= 1.0 + aura_value(attacker.owner, attacker.pos, "damage") + enemy_aura_value(attacker.owner, attacker.pos, "enemy_damage")
		if target.kind == Entity.BUILDING:
			base *= 1.0 + aura_value(attacker.owner, attacker.pos, "siege")
	attacker.still = 0.0
	var steal := float(passives.get("lifesteal", 0.0))
	var dtype: String = attacker.def.dtype if dtype_override == "" else dtype_override
	events.append({
		"type": "hit", "from": attacker.pos, "to": target.pos, "dtype": dtype, "unit": attacker.type_id,
		"ranged": float(attacker.def.range) > 1.0, "target": target.id, "source": attacker.id,
		"owners": [attacker.owner, target.owner], "siege": passives.has("cleave") and float(attacker.def.range) > 1.0,
	})
	var dealt := apply_damage(attacker, target, base, dtype)
	if passives.has("wither") and target.alive and target.kind == Entity.UNIT:
		Abilities.add_effect(self, target, "slow", float(passives.wither.slow), float(passives.wither.duration))
	if steal > 0.0 and attacker.alive:
		attacker.hp = minf(attacker.max_hp, attacker.hp + dealt * steal)
	if passives.has("cloud"):
		var cloud: Dictionary = passives.cloud
		areas.append({"pos": target.pos, "radius": float(cloud.radius) * TILE, "dps": float(cloud.dps), "dtype": dtype,
				"owner": attacker.owner, "until": tick_count + roundi(float(cloud.duration) * TICK_RATE)})
		events.append({"type": "cloud", "pos": target.pos, "radius": float(cloud.radius) * TILE, "duration": float(cloud.duration)})
	if passives.has("cleave"):
		var radius := float(passives.cleave.radius) * TILE
		for o in entities.values():
			if o != target and o.alive and o.kind == Entity.UNIT and is_enemy(attacker, o) and o.pos.distance_to(target.pos) <= radius:
				apply_damage(attacker, o, base * float(passives.cleave.share), dtype)


## Applies `amount` of `dtype` damage after armour, auras and shields. Returns damage dealt.
func apply_damage(attacker, target: Entity, amount: float, dtype: String) -> float:
	if not target.alive:
		return 0.0
	var dmg := amount * DB.damage_mult(dtype, target.def.armor)
	if target.kind == Entity.UNIT:
		dmg *= 1.0 + aura_value(target.owner, target.pos, "damage_taken")
		var tp: Dictionary = target.def.get("passives", {})
		if tp.has("home_guard") and territory_owner(GameMap.to_tile(target.pos)) == target.owner:
			dmg *= 1.0 + float(tp.home_guard.damage_taken)
		if target.deployed:
			dmg *= 1.0 + float(target.def.deployed.damage_taken)
		if tp.has("brace") and target.stand >= float(tp.brace.after):
			dmg *= 1.0 + float(tp.brace.damage_taken)
	for fx in target.effects:
		if fx.type == "shield" and fx.amount > 0.0:
			var absorbed := minf(fx.amount, dmg)
			fx.amount -= absorbed
			dmg -= absorbed
	target.hp -= dmg
	if attacker and attacker.alive and attacker.kind == Entity.UNIT:
		var steal := aura_value(attacker.owner, attacker.pos, "lifesteal")
		if steal > 0.0:
			attacker.hp = minf(attacker.max_hp, attacker.hp + dmg * steal)
	if target.hp <= 0.0:
		if is_city(target) and not target.constructing:
			_try_capture(target, attacker.owner if attacker else -1)
		else:
			kill(target)
	return dmg


## Living units of `e`'s own type and side within `radius` (Volley), itself excluded.
func _comrades_near(e: Entity, radius: float) -> int:
	var n := 0
	var lo := _cell(e.pos - Vector2(radius, radius))
	var hi := _cell(e.pos + Vector2(radius, radius))
	for cy in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			for o in _unit_grid.get(Vector2i(cx, cy), []):
				if o != e and o.alive and o.owner == e.owner and o.type_id == e.type_id and o.pos.distance_to(e.pos) <= radius:
					n += 1
	return n


## Whether `a` shoots down on `t` from noticeably higher ground (Standschütze).
func has_high_ground(a: Entity, t: Entity) -> bool:
	var hg: Dictionary = a.def.get("passives", {}).get("high_ground", {})
	if hg.is_empty():
		return false
	return map.elevation(GameMap.to_tile(a.pos)) >= map.elevation(GameMap.to_tile(t.pos)) + float(hg.rise)


## Weapon reach in pixels, including the high-ground bonus.
func attack_range(a: Entity, t: Entity) -> float:
	var r := float(a.def.range)
	if t and has_high_ground(a, t):
		r += float(a.def.passives.high_ground.range)
	return r * TILE


## Viribus Unitis: troops from several crown lands fighting side by side hit harder.
func viribus_unitis(a: Entity) -> float:
	if a.kind != Entity.UNIT or a.owner < 0:
		return 0.0
	var vu: Dictionary = DB.factions[players[a.owner].faction].get("viribus_unitis", {})
	if vu.is_empty():
		return 0.0
	var radius := float(vu.radius) * TILE
	var lands := {}
	var lo := _cell(a.pos - Vector2(radius, radius))
	var hi := _cell(a.pos + Vector2(radius, radius))
	for cy in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			var cell_units = _unit_grid.get(Vector2i(cx, cy))
			if cell_units == null:
				continue
			for o in cell_units:
				if o.alive and o.owner == a.owner and o.can_attack() and o.pos.distance_to(a.pos) <= radius:
					lands[o.def.get("crown_land", "austria")] = true
	return minf(float(vu.max), float(vu.per_land) * (lands.size() - 1))


# --- Crown lands -------------------------------------------------------------------

## The land a faction's starting city holds (Austria, the Umbral Throne).
static func capital_land(faction: String) -> String:
	for id in DB.crown_lands:
		var land: Dictionary = DB.crown_lands[id]
		if land.get("capital", false) and land.get("faction", "") == faction:
			return id
	return ""

# --- Loyalty and rebellion -------------------------------------------------------

## A city at 0 loyalty breaks away to the Rebels, raising a militia to defend itself.
func revolt(city: Entity) -> void:
	var old := city.owner
	_abandon_queue(city)
	city.owner = rebels
	city.crown_land = ""
	city.charter = false
	city.rally = {}
	city.target_id = -1
	city.loyalty = 100.0
	city.max_hp = _max_hp_for(city)
	city.hp = maxf(city.hp, city.max_hp * 0.5)
	for i in int(rules.loyalty.rebel_militia):
		_spawn_from(city, "rebel_militia")
	_reassign_capital(old)
	refresh_crown_lands(old)
	territory.dirty = true
	events.append({"type": "revolt", "id": city.id, "owner": old, "pos": city.pos})


## If a player's capital is gone, their oldest remaining city takes over.
func _reassign_capital(pid: int) -> void:
	if pid < 0 or pid >= players.size():
		return
	var p = players[pid]
	var cap := get_entity(p.capital_id)
	if cap and cap.alive and cap.owner == pid:
		return
	p.capital_id = -1
	for e in entities.values():
		if e.alive and e.owner == pid and is_city(e) and not e.constructing:
			if p.capital_id < 0 or e.id < p.capital_id:
				p.capital_id = e.id


## Re-derives a player's crown lands from their cities, and the bonuses they grant.
func refresh_crown_lands(pid: int) -> void:
	if pid < 0:
		return
	var p = players[pid]
	p.crown_lands.clear()
	p.land_mods.clear()
	for e in entities.values():
		if not e.alive or e.owner != pid or e.kind != Entity.BUILDING:
			continue
		var mods: Dictionary = {}
		if is_city(e) and e.crown_land != "":
			p.crown_lands.append(e.crown_land)
			mods = DB.crown_lands[e.crown_land].get("mods", {}).duplicate()
			if e.charter:
				for k in mods:
					mods[k] = float(mods[k]) * (1.0 + float(rules.loyalty.charter_land_bonus))
		elif e.def.get("role", "") == "wonder" and not e.constructing:
			mods = e.def.get("mods", {})
		for k in mods:
			p.land_mods[k] = p.land_mods.get(k, 0.0) + float(mods[k])
	Research.recompute_mods(p)
	territory.dirty = true


## Strength of `key` from `owner`'s hero aura at `pos` (0 if out of range or no hero).
func aura_value(owner: int, pos: Vector2, key: String) -> float:
	var total := 0.0
	for u in _aura_units:
		if not u.alive or u.owner != owner:
			continue
		var aura: Dictionary = u.def.aura
		if aura.has(key) and u.pos.distance_to(pos) <= float(aura.radius) * TILE:
			total += float(aura[key])
	return total


## Auras of `owner`'s enemies that reach `pos` (e.g. the Bone Colossus's fear).
func enemy_aura_value(owner: int, pos: Vector2, key: String) -> float:
	var total := 0.0
	for p in players:
		if p.index != owner:
			total += aura_value(p.index, pos, key)
	return total


## A city at 0 HP falls to whoever has more troops around it; until then it holds at 1 HP.
func _try_capture(city: Entity, by: int) -> void:
	city.hp = 1.0
	if by < 0 or by == city.owner:
		return
	var radius := float(rules.capture_radius) * TILE
	var attackers := 0
	var defenders := 0
	for e in entities.values():
		if not e.alive or e.kind != Entity.UNIT or not e.can_attack() or e.is_worker():
			continue
		if rect_dist(city.rect(), e.pos) > radius:
			continue
		if e.owner == by:
			attackers += 1
		elif e.owner == city.owner:
			defenders += 1
	if attackers > defenders:
		capture_city(city, by)


func capture_city(city: Entity, by: int) -> void:
	var old := city.owner
	_abandon_queue(city)
	city.owner = by
	city.type_id = DB.factions[players[by].faction].city
	city.def = DB.buildings[city.type_id]
	city.rally = {}
	city.target_id = -1
	city.crown_land = ""
	city.charter = false
	city.loyalty = float(rules.loyalty.start_captured)
	city.captured_tick = tick_count
	_reassign_capital(old)
	refresh_crown_lands(old)
	refresh_crown_lands(by)
	city.max_hp = _max_hp_for(city)
	city.hp = city.max_hp * float(rules.capture_hp)
	territory.dirty = true
	events.append({"type": "captured", "id": city.id, "from": old, "to": by, "pos": city.pos})


# --- Tick -----------------------------------------------------------------------

## Path searches allowed per tick; the rest wait a tick (spreads big orders out).
const PATH_BUDGET := 16
var _paths_left := PATH_BUDGET


func take_path_budget() -> bool:
	if _paths_left <= 0:
		return false
	_paths_left -= 1
	return true


## When true, tick() adds microseconds per section to `profile` (benchmarks only).
static var profiling := false
static var profile := {}
var _prof_t := 0


func _lap(section: String) -> void:
	if not profiling:
		return
	var now := Time.get_ticks_usec()
	profile[section] = profile.get(section, 0) + now - _prof_t
	_prof_t = now


func tick() -> void:
	if profiling:
		_prof_t = Time.get_ticks_usec()
	tick_count += 1
	_paths_left = PATH_BUDGET
	events.clear()
	var all := entities.values()
	_unit_grid.clear()
	_buildings.clear()
	_aura_units.clear()
	for e in all:
		if e.kind == Entity.UNIT:
			e.still = e.still + DT if e.pos == e.prev_pos else 0.0
			e.stand = e.stand + DT if e.pos == e.prev_pos else 0.0
		e.prev_pos = e.pos
		if not e.alive or e.inside >= 0:
			continue
		if e.kind == Entity.UNIT:
			var k := _cell(e.pos)
			if not _unit_grid.has(k):
				_unit_grid[k] = []
			_unit_grid[k].append(e)
		elif e.kind == Entity.BUILDING:
			_buildings.append(e)
		if e.kind == Entity.UNIT and e.def.has("aura"):
			_aura_units.append(e)
	_update_gather_efficiency()
	_expire_effects(all)
	for e in all:
		if e.alive and e.carried_by >= 0:
			var c := get_entity(e.carried_by)
			if c and c.alive:
				e.pos = c.pos
				e.tile = GameMap.to_tile(c.pos)
	if tick_count % 10 == 0:
		_tick_areas()
	_lap("setup")
	for e in all:
		if not e.alive or e.inside >= 0:
			continue
		if e.kind == Entity.UNIT:
			if profiling:
				var t0 := Time.get_ticks_usec()
				var key: String = "u:" + (e.orders[0].type if not e.orders.is_empty() else "idle")
				UnitAI.update(self, e)
				profile[key] = profile.get(key, 0) + Time.get_ticks_usec() - t0
				profile["n:" + key.substr(2)] = profile.get("n:" + key.substr(2), 0) + 1
			else:
				UnitAI.update(self, e)
	_lap("units")
	for e in _buildings:
		if e.alive:
			_update_building(e)
	_lap("buildings")
	_separate()
	_lap("separate")
	_update_pop()
	for ai in ais:
		if (tick_count + ai.tick_offset) % ai.think_ticks == 0:
			ai.think()
	_lap("ai")
	if territory.dirty:
		_update_territory()
	_lap("territory")
	if tick_count % FOG_INTERVAL == 0:
		update_fog()
	_lap("fog")
	if tick_count % TICK_RATE == 0:
		_attrition_and_healing()
		Loyalty.update(self)
		for p in players:
			p.update_income()
	_lap("per_second")
	for e in all:
		if not e.alive:
			entities.erase(e.id)
	if tick_count % TICK_RATE == 0:
		if scenario_logic and winner < 0:
			scenario_logic.update(self, scenario)
		var hu: Dictionary = rules.get("hungary", {})
		if hu.get("enabled", false) and not hungary_risen and winner < 0 and tick_count * DT >= float(hu.rise_at):
			hungary_rises()
		_check_victory()
	_lap("victory")


## Poison clouds hurt enemy units inside them twice a second, then fade.
func _tick_areas() -> void:
	areas = areas.filter(func(a): return a.until > tick_count)
	for a in areas:
		for k in _unit_grid:
			for u in _unit_grid[k]:
				if u.alive and u.owner != a.owner and u.owner >= 0 and u.domain() != "air" and u.pos.distance_to(a.pos) <= a.radius:
					apply_damage(null, u, float(a.dps) * 0.5, a.dtype)


## Drops finished or used-up effects, and dismisses summons whose time is up.
func _expire_effects(all: Array) -> void:
	for e in all:
		if not e.alive:
			continue
		if e.expires_tick > 0 and tick_count >= e.expires_tick:
			kill(e)
			continue
		if not e.effects.is_empty():
			e.effects = e.effects.filter(func(fx): return fx.until > tick_count and fx.amount > 0.0)


func _update_building(b: Entity) -> void:
	if b.constructing:
		return
	UnitAI.update_tower(self, b)
	if b.queue.is_empty():
		return
	var item: Dictionary = b.queue[0]
	var p = players[b.owner] if b.owner >= 0 else null
	var fast: bool = p != null and (p.cheat_build if item.kind == "unit" else p.cheat_advance)
	item.progress += DT / float(item.time) * (CHEAT_SPEED if fast else 1.0)
	if item.progress < 1.0:
		return
	b.queue.pop_front()
	_release_item(b.owner, item)
	match item.kind:
		"unit":
			# An age reached during training delivers the new tier.
			var u := _spawn_from(b, DB.tier(item.type, players[b.owner].age) if b.owner >= 0 else item.type)
			_apply_rally(b, u)
			events.append({"type": "trained", "id": u.id, "owner": u.owner})
		"tech":
			_complete_research(players[b.owner], item.type)
		"age":
			_complete_age(players[b.owner])


func _complete_research(p, branch_id: String) -> void:
	var level := Research.next_level(p, branch_id)
	p.techs[branch_id] = level
	Research.recompute_mods(p)
	for e in entities.values():
		if e.alive and e.owner == p.index:
			_refresh_max_hp(e)
	if Research.branch(branch_id).effects.has("border_radius"):
		territory.dirty = true
	events.append({"type": "researched", "player": p.index, "branch": branch_id, "level": level,
			"name": Research.level_info(branch_id, level).name})


func _complete_age(p) -> void:
	p.age = mini(p.age + 1, final_age())
	refit_units(p.index)
	if p.age >= int(rules.get("victory", {}).get("relics_spawn_age", 99)) and not relics_spawned:
		_spawn_relics()
	events.append({"type": "age_up", "player": p.index, "age": p.age, "name": DB.ages[p.age - 1].name})


func _apply_rally(b: Entity, u: Entity) -> void:
	if b.rally.is_empty():
		return
	var order := {"type": "move", "pos": b.rally.pos}
	if u.is_worker():
		var target = get_entity(b.rally.get("target", -1))
		if target and is_gatherable(target, u.owner):
			order = _gather_order(target, Vector2i(-1, -1))
		elif b.rally.has("tile") and map.timber_at(b.rally.tile) > 0.0:
			order = _gather_order(null, b.rally.tile)
	u.orders.append(order)


func advance_construction(b: Entity, dt: float) -> void:
	var t := float(b.def.build_time)
	if b.owner >= 0 and players[b.owner].cheat_build:
		dt *= CHEAT_SPEED
	b.build_progress += dt / t
	b.hp = minf(b.max_hp, b.hp + b.max_hp * 0.9 * dt / t)
	if b.build_progress >= 1.0:
		b.build_progress = 1.0
		b.constructing = false
		territory.dirty = true
		if b.def.get("role", "") == "wonder":
			refresh_crown_lands(b.owner)
			events.append({"type": "wonder", "id": b.id, "owner": b.owner, "name": b.def.name})
		events.append({"type": "built", "id": b.id, "owner": b.owner})


func _update_pop() -> void:
	for p in players:
		p.pop_used = 0
		p.pop_cap = 0
	for e in entities.values():
		if not e.alive or e.owner < 0:
			continue
		var p = players[e.owner]
		if e.kind == Entity.UNIT:
			p.pop_used += int(e.def.get("pop", 1))
		elif e.kind == Entity.BUILDING:
			if not e.constructing:
				p.pop_cap += int(e.def.get("pop_provided", 0))
			for item in e.queue:
				if item.kind == "unit":
					p.pop_used += int(DB.units[item.type].get("pop", 1))
	for p in players:
		p.pop_cap = mini(p.pop_cap, p.pop_limit())


# --- Economy --------------------------------------------------------------------

## Scales this tick's harvesting so each player's income stays under their gather caps,
## based on how much their workers tried to harvest last tick.
func _update_gather_efficiency() -> void:
	for p in players:
		for res in p.gather_demand:
			var demand: float = p.gather_demand[res]
			p.gather_eff[res] = 1.0 if demand <= 0.0 else minf(1.0, p.gather_cap(res) * DT / demand)
			p.gather_demand[res] = 0.0


## How much a worker at `pos` harvests this tick at base `rate`/s, after research,
## auras (Maria Theresa) and caps.
func harvest_take(owner: int, res: String, rate: float, pos := Vector2.INF) -> float:
	var p = players[owner]
	var bonus: float = p.mod("gather_rate") + (p.mod("herb_rate") if res == "herbs" else 0.0)
	if pos != Vector2.INF:
		bonus += aura_value(owner, pos, "gather")
	var nominal: float = rate * (1.0 + bonus) * p.handicap * DT
	p.gather_demand[res] += nominal
	return nominal * p.gather_eff[res]


# --- Territory ------------------------------------------------------------------

func is_city(e: Entity) -> bool:
	return e.kind == Entity.BUILDING and e.def.get("role", "") == "city"


## Borders: cities project their radius (growing with the buildings around them),
## and every other completed building claims a smaller patch of its own.
func _update_territory() -> void:
	var cfg: Dictionary = rules.get("borders", {})
	var built: Array = entities.values().filter(func(e): return e.alive and e.kind == Entity.BUILDING \
			and not e.constructing and e.owner >= 0)
	var sources: Array = []
	for e in built:
		var bonus: float = players[e.owner].mod("border_radius")
		var center: Vector2 = e.rect().get_center() / TILE
		if is_city(e):
			var base := float(e.def.border_radius) + bonus
			var reach := (base + float(cfg.get("city_growth_reach", 3.0))) * TILE
			var near := 0
			for o in built:
				if o != e and o.owner == e.owner and not is_city(o) and o.pos.distance_to(e.pos) <= reach:
					near += 1
			var growth := minf(float(cfg.get("city_growth_max", 3.0)), near * float(cfg.get("city_growth_per_building", 0.25)))
			sources.append({"owner": e.owner, "center": center, "radius": base + growth})
		elif not cfg.is_empty():
			var role: String = e.def.get("role", "")
			var r := float(cfg.get("tower", 5.0)) if role == "tower" else (float(cfg.get("wonder", 6.0)) if role == "wonder" else float(cfg.get("building", 3.0)))
			sources.append({"owner": e.owner, "center": center, "radius": r + bonus * 0.5})
	territory.compute(sources)


func territory_owner(t: Vector2i) -> int:
	return territory.owner_at(t)


## Once a second: units in enemy land wither unless supplied; units at home heal.
func _attrition_and_healing() -> void:
	for k in _unit_grid:
		for e in _unit_grid[k]:
			if not e.alive or e.owner < 0:
				continue
			var land := territory_owner(GameMap.to_tile(e.pos))
			e.speed_mult = 1.0 + (players[e.owner].mod("rail_speed") if land == e.owner and e.domain() == "ground" else 0.0)
			if land == e.owner:
				var regen: float = players[e.owner].mod("regen")
				if regen > 0.0:
					e.hp = minf(e.max_hp, e.hp + regen)
			elif land >= 0 and not is_supplied(e):
				e.hp -= e.max_hp * (float(rules.attrition) + players[land].mod("attrition"))
				if e.hp <= 0.0:
					kill(e)


func is_supplied(e: Entity) -> bool:
	var reach := 8.0 * TILE
	var lo := _cell(e.pos - Vector2(reach, reach))
	var hi := _cell(e.pos + Vector2(reach, reach))
	for cy in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			var cell_units = _unit_grid.get(Vector2i(cx, cy))
			if cell_units == null:
				continue
			for o in cell_units:
				if o.alive and o.owner == e.owner and o.def.has("supply_radius") \
						and o.pos.distance_to(e.pos) <= float(o.def.supply_radius) * TILE:
					return true
	return false


# --- Collision and fog ----------------------------------------------------------

## Soft collision: overlapping ground units push each other apart.
func _separate() -> void:
	# Cells just larger than the push distance, so neighbouring cells suffice.
	var cell := TILE * 0.75
	var grid := {}
	for k in _unit_grid:
		for e in _unit_grid[k]:
			if not e.alive:
				continue
			var c := Vector2i(floori(e.pos.x / cell), floori(e.pos.y / cell))
			if grid.has(c):
				grid[c].append(e)
			else:
				grid[c] = [e]
	# Each pair once: within a cell, then against four "forward" neighbour cells.
	# The distance test is inlined: most pairs are too far apart to push, and
	# skipping the call for them is most of this function's cost in a crowd.
	var sep2 := _SEPARATION * _SEPARATION
	for c in grid:
		var a: Array = grid[c]
		var n := a.size()
		for i in n:
			var ai: Entity = a[i]
			for j in range(i + 1, n):
				if ai.pos.distance_squared_to(a[j].pos) < sep2:
					_push_apart(ai, a[j])
		for off in _FORWARD:
			var b = grid.get(c + off)
			if b != null:
				for x: Entity in a:
					for y: Entity in b:
						if x.pos.distance_squared_to(y.pos) < sep2:
							_push_apart(x, y)


const _FORWARD: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]
const _SEPARATION := UNIT_RADIUS * 1.8


func _push_apart(e: Entity, o: Entity) -> void:
	var d := o.pos - e.pos
	var dist_sq := d.length_squared()
	if dist_sq >= _SEPARATION * _SEPARATION:
		return
	# Flyers, ships and ground troops don't jostle each other.
	if e.domain() != o.domain():
		return
	var dist := sqrt(dist_sq)
	if dist < 0.01:
		d = Vector2.RIGHT.rotated(e.id)
		dist = 1.0
	var e_moving := _is_moving(e)
	var o_moving := _is_moving(o)
	var push := (d / dist) * (_SEPARATION - dist) * 0.5
	# Slightly sideways only when both are walking, so units meeting head-on slide
	# past instead of locking up. Between standing units a sideways push would
	# just set them orbiting each other.
	if e_moving and o_moving:
		push = push.rotated(0.4)
	# Units on the move barely yield; standing units step aside for them.
	var e_share := 0.2 if e_moving else 1.0
	var o_share := 0.2 if o_moving else 1.0
	var total := e_share + o_share
	_nudge(o, push * (o_share / total))
	_nudge(e, -push * (e_share / total))


func _is_moving(e: Entity) -> bool:
	return e.path_index < e.path.size()


func _nudge(e: Entity, v: Vector2) -> void:
	var np := e.pos + v
	if map.is_passable(GameMap.to_tile(np), e.domain()):
		e.pos = np


func update_fog() -> void:
	var sticky: bool = rules.get("explored_stays_visible", false)
	for p in players:
		if not p.tracks_fog:
			continue
		var vis: PackedByteArray = p.vis
		if not sticky:
			for i in vis.size():
				if vis[i] == 2:
					vis[i] = 1
		# Units bunched on one tile with the same sight only need revealing once.
		var done := {}
		for e in entities.values():
			if not e.alive or e.owner != p.index or e.inside >= 0:
				continue
			var r := float(e.def.get("sight", 4))
			if e.kind == Entity.BUILDING:
				r = 3.0 if e.constructing else r + e.size.x * 0.5
			var t := GameMap.to_tile(e.pos)
			var key := Vector3i(t.x, t.y, int(r * 2.0))
			# With explored land staying visible, a unit that hasn't changed tile (or
			# sight) since its last reveal can't uncover anything new.
			if sticky and e.fog_key == key:
				continue
			e.fog_key = key
			if done.has(key):
				continue
			done[key] = true
			_reveal(vis, t, r)
		p.vis = vis
	fog_version += 1


func _reveal(vis: PackedByteArray, c: Vector2i, r: float) -> void:
	var ri := ceili(r)
	var r2 := r * r
	for dy in range(-ri, ri + 1):
		var y := c.y + dy
		if y < 0 or y >= map.height:
			continue
		for dx in range(-ri, ri + 1):
			var x := c.x + dx
			if x >= 0 and x < map.width and dx * dx + dy * dy <= r2:
				vis[y * map.width + x] = 2


## Conquest: a player with no completed city is out, and everything they own crumbles.
func _check_victory() -> void:
	var alive_players: Array = []
	if winner >= 0:
		return
	if not rules.get("victory", {}).get("enabled", {}).get("conquest", true):
		# Scripted scenarios decide defeat themselves.
		for p in players:
			if not p.defeated and not p.is_rebels:
				alive_players.append(p.index)
		_check_alternative_victories(alive_players)
		return
	for p in players:
		if p.defeated or p.is_rebels:
			continue
		if city_count(p.index, false) > 0:
			alive_players.append(p.index)
			continue
		p.defeated = true
		for e in entities.values():
			if e.owner == p.index:
				kill(e)
		events.append({"type": "defeated", "player": p.index})
	if alive_players.size() == 1 and winner < 0:
		winner = alive_players[0]
		events.append({"type": "victory", "player": winner, "reason": "conquest"})
	if winner < 0:
		_check_alternative_victories(alive_players)


## Territory, Wonder and AEIOU victories: meet the condition and hold it long enough.
func _check_alternative_victories(alive_players: Array) -> void:
	var v: Dictionary = rules.get("victory", {})
	if v.is_empty():
		return
	if _land_tiles == 0:
		for t in map.terrain:
			if t != GameMap.WATER:
				_land_tiles += 1
	for pid in alive_players:
		var held: Dictionary = victory_since.get(pid, {})
		var owned := 0
		for o in territory.grid:
			if o == pid + 1:
				owned += 1
		var on: Dictionary = v.get("enabled", {})
		var met := {
			"territory": float(owned) / maxf(1.0, _land_tiles) >= float(v.territory_share),
			"wonders": wonder_count(pid) >= int(v.wonders_needed),
			"relics": relics_stored(pid) >= 5,
		}
		var holds := {"territory": float(v.territory_hold), "wonders": float(v.wonder_hold), "relics": float(v.relic_hold)}
		for kind in met:
			if not met[kind] or not on.get(kind, true):
				held.erase(kind)
				continue
			if not held.has(kind):
				held[kind] = tick_count
				events.append({"type": "victory_countdown", "player": pid, "reason": kind, "seconds": holds[kind]})
			elif (tick_count - held[kind]) * DT >= holds[kind]:
				winner = pid
				events.append({"type": "victory", "player": pid, "reason": kind})
				for p in players:
					if p.index != pid and not p.is_rebels:
						p.defeated = true
				return
		victory_since[pid] = held


func wonder_count(pid: int) -> int:
	var n := 0
	for e in entities.values():
		if e.alive and e.owner == pid and e.kind == Entity.BUILDING and e.def.get("role", "") == "wonder" and not e.constructing:
			n += 1
	return n


## Where relics can be kept: any city (its treasury) or a treasury wonder.
func is_relic_holder(e: Entity) -> bool:
	return e != null and e.kind == Entity.BUILDING and not e.constructing \
			and (e.def.get("relic_holder", false) or is_city(e))


func relics_stored(pid: int) -> int:
	var n := 0
	for e in entities.values():
		if e.alive and e.def.get("relic", false) and e.inside >= 0:
			var holder := get_entity(e.inside)
			if holder and holder.alive and holder.owner == pid:
				n += 1
	return n


# --- Relics (AEIOU victory) ----------------------------------------------------------

## Five relics appear: one at the centre and two mirrored pairs, away from both starts.
func _spawn_relics() -> void:
	relics_spawned = true
	var ids: Array = DB.resources.keys().filter(func(k): return DB.resources[k].get("relic", false))
	var center := Vector2i(map.width / 2, map.height / 2)
	var spots: Array = [map.nearest_walkable(center, 10)]
	var rng := RandomNumberGenerator.new()
	rng.seed = tick_count
	var attempts := 0
	while spots.size() < ids.size() and attempts < 500:
		attempts += 1
		var t := Vector2i(rng.randi_range(8, map.width - 9), rng.randi_range(8, map.height - 9))
		var mirror := Vector2i(map.width - 1 - t.x, map.height - 1 - t.y)
		if not map.is_walkable(t) or not map.is_walkable(mirror) or territory_owner(t) >= 0 or territory_owner(mirror) >= 0:
			continue
		if spots.any(func(s): return Vector2(s).distance_to(Vector2(t)) < 12.0):
			continue
		spots.append(t)
		spots.append(mirror)
	for i in mini(ids.size(), spots.size()):
		spawn_resource(ids[i], spots[i])
	events.append({"type": "relics", "count": mini(ids.size(), spots.size())})


func pick_up_relic(u: Entity, r: Entity) -> void:
	if r.carried_by >= 0 or r.inside >= 0 or u.relic >= 0:
		return
	r.carried_by = u.id
	u.relic = r.id
	events.append({"type": "relic_taken", "owner": u.owner, "name": r.def.name})


func store_relic(u: Entity, holder: Entity) -> void:
	var r := get_entity(u.relic)
	if r == null:
		u.relic = -1
		return
	u.relic = -1
	r.carried_by = -1
	r.inside = holder.id
	r.pos = holder.pos
	events.append({"type": "relic_stored", "owner": holder.owner, "name": r.def.name})


func _drop_relic(r, at: Vector2) -> void:
	if r == null:
		return
	var carrier := get_entity(r.carried_by)
	if carrier:
		carrier.relic = -1
	r.carried_by = -1
	r.inside = -1
	r.pos = at
	r.tile = GameMap.to_tile(at)


## A destroyed relic holder spills its relics on the ground.
func _drop_relics_in(holder: Entity) -> void:
	for e in entities.values():
		if e.alive and e.def.get("relic", false) and e.inside == holder.id:
			_drop_relic(e, holder.pos + Vector2(randf_range(-40, 40), randf_range(-40, 40)))


# --- Queries --------------------------------------------------------------------

## The last age players can reach in this match.
func final_age() -> int:
	return max_age if max_age > 0 else DB.last_age()


func get_entity(id: int) -> Entity:
	return entities.get(id)


func is_enemy(a: Entity, b: Entity) -> bool:
	return a.owner >= 0 and b.owner >= 0 and a.owner != b.owner


func city_count(player: int, include_sites := true) -> int:
	var n := 0
	for e in entities.values():
		if e.alive and e.owner == player and is_city(e) and (include_sites or not e.constructing):
			n += 1
	return n


## Water tiles touching the edge of a footprint.
func _shore_tiles(top_left: Vector2i, s: int) -> int:
	var n := 0
	for y in range(top_left.y - 1, top_left.y + s + 1):
		for x in range(top_left.x - 1, top_left.x + s + 1):
			var inside := x >= top_left.x and x < top_left.x + s and y >= top_left.y and y < top_left.y + s
			if not inside and map.is_sailable(Vector2i(x, y)):
				n += 1
	return n


# --- Transports ------------------------------------------------------------------

func cargo_space(t: Entity) -> int:
	var used := 0
	for id in t.cargo:
		var u := get_entity(id)
		if u:
			used += int(u.def.get("pop", 1))
	return int(t.def.get("capacity", 0)) - used


func load_unit(t: Entity, u: Entity) -> void:
	u.inside = t.id
	u.orders.clear()
	UnitAI.reset_path(u)
	u.pos = t.pos
	u.prev_pos = u.pos
	t.cargo.append(u.id)
	events.append({"type": "boarded", "id": u.id, "transport": t.id, "owner": u.owner})


## Puts every passenger ashore on open tiles near the transport, then sends them toward `toward`.
func unload_all(t: Entity, toward: Vector2) -> void:
	var land := map.nearest_walkable(GameMap.to_tile(t.pos), 4)
	var placed := 0
	for id in t.cargo:
		var u := get_entity(id)
		if u == null:
			continue
		u.inside = -1
		var spot := map.nearest_walkable(land + Vector2i(placed % 3 - 1, placed / 3 - 1), 4)
		u.pos = GameMap.tile_center(spot if spot.x >= 0 else land)
		u.prev_pos = u.pos
		placed += 1
	t.cargo.clear()
	events.append({"type": "unloaded", "id": t.id, "owner": t.owner})


## Units of `type_id` alive or in training for `player`.
func type_count(player: int, type_id: String) -> int:
	var n := 0
	for e in entities.values():
		if not e.alive or e.owner != player:
			continue
		if e.type_id == type_id:
			n += 1
		elif e.kind == Entity.BUILDING:
			for item in e.queue:
				if item.type == type_id:
					n += 1
	return n


## Units of `type_id`'s whole upgrade line, alive or in training (for "limit").
func line_count(player: int, type_id: String) -> int:
	var root := DB.line_root(type_id)
	var n := 0
	for e in entities.values():
		if not e.alive or e.owner != player:
			continue
		if e.kind == Entity.UNIT and DB.line_root(e.type_id) == root:
			n += 1
		elif e.kind == Entity.BUILDING:
			for item in e.queue:
				if item.kind == "unit" and DB.line_root(item.type) == root:
					n += 1
	return n


## Refits every soldier of `pid` whose line has a tier for the player's age (Rise of
## Nations style: free and at once). Keeps the unit's id, orders, health share,
## cooldowns and cargo; the view rebuilds its model from the new type.
func refit_units(pid: int) -> void:
	var age: int = players[pid].age
	var done := {}
	for e in entities.values():
		if not e.alive or e.owner != pid or e.kind != Entity.UNIT or e.is_hero():
			continue
		var to := DB.tier(e.type_id, age)
		if to != e.type_id:
			_refit(e, to)
			done[to] = int(done.get(to, 0)) + 1
	if not done.is_empty():
		events.append({"type": "refit", "player": pid, "units": done})


func _refit(e: Entity, to: String) -> void:
	var share := e.hp / maxf(1.0, e.max_hp)
	e.type_id = to
	e.def = DB.units[to]
	e._domain = ""
	e.max_hp = _max_hp_for(e)
	e.hp = maxf(1.0, e.max_hp * share)
	e.ammo = -1
	e.reload_left = 0.0
	for id in e.def.get("abilities", []):
		if not e.autocast.has(id):
			e.autocast[id] = Abilities.def(id).get("autocast", false) or not players[e.owner].is_human


## Heroes alive or in training for `player`.
func hero_count(player: int) -> int:
	var n := 0
	for e in entities.values():
		if not e.alive or e.owner != player:
			continue
		if e.kind == Entity.UNIT and e.is_hero():
			n += 1
		elif e.kind == Entity.BUILDING:
			for item in e.queue:
				if item.kind == "unit" and DB.units[item.type].get("hero", false):
					n += 1
	return n


func city_limit(player: int) -> int:
	return 1 + players[player].age


func tile_visible(player: int, t: Vector2i) -> bool:
	return map.in_bounds(t) and (not players[player].tracks_fog or players[player].vis[map.idx(t)] == 2)


func tile_explored(player: int, t: Vector2i) -> bool:
	return map.in_bounds(t) and (not players[player].tracks_fog or players[player].vis[map.idx(t)] > 0)


func is_visible_to(player: int, e: Entity) -> bool:
	if e.owner == player:
		return true
	if is_hidden_by_stealth(player, e):
		return false
	if not players[player].tracks_fog:
		return true
	if e.kind == Entity.UNIT:
		return tile_visible(player, GameMap.to_tile(e.pos))
	for y in e.size.y:
		for x in e.size.x:
			if tile_visible(player, e.tile + Vector2i(x, y)):
				return true
	return false


## Stealthy units (Ghost Ship) vanish once they've kept still for a while, unless
## one of `player`'s units is close enough to spot them.
func is_hidden_by_stealth(player: int, e: Entity) -> bool:
	var st: Dictionary = e.def.get("passives", {}).get("stealth", {})
	if st.is_empty() or e.still < float(st.still):
		return false
	var detect := float(st.detect) * TILE
	for k in _unit_grid:
		for u in _unit_grid[k]:
			if u.alive and u.owner == player and u.pos.distance_to(e.pos) <= detect:
				return false
	return true


## Gap between the outlines of two entities, in pixels.
func edge_dist(a: Entity, b: Entity) -> float:
	var a_unit := a.kind == Entity.UNIT
	var b_unit := b.kind == Entity.UNIT
	if a_unit and b_unit:
		return a.pos.distance_to(b.pos) - 2.0 * UNIT_RADIUS
	if a_unit:
		return rect_dist(b.rect(), a.pos) - UNIT_RADIUS
	if b_unit:
		return rect_dist(a.rect(), b.pos) - UNIT_RADIUS
	var ra := a.rect()
	var rb := b.rect()
	var dx := maxf(0.0, maxf(ra.position.x - rb.end.x, rb.position.x - ra.end.x))
	var dy := maxf(0.0, maxf(ra.position.y - rb.end.y, rb.position.y - ra.end.y))
	return sqrt(dx * dx + dy * dy)


## Gap between an entity's outline and a point, in pixels.
func edge_dist_point(e: Entity, p: Vector2) -> float:
	if e.kind == Entity.UNIT:
		return maxf(0.0, e.pos.distance_to(p) - UNIT_RADIUS)
	return rect_dist(e.rect(), p)


static func rect_dist(r: Rect2, p: Vector2) -> float:
	return p.distance_to(p.clamp(r.position, r.end))


## Nearest enemy (unit preferred over building) within `radius` of `e`'s outline.
func find_enemy_near(e: Entity, radius: float) -> Entity:
	var best: Entity = null
	var best_score := INF
	var reach := radius + e.size.x * TILE
	# Units: edge distance <= radius implies centre distance <= radius + both radii.
	var lim: float = radius + TILE + e.size.x * TILE
	var lim2 := lim * lim
	var lo := _cell(e.pos - Vector2(reach, reach))
	var hi := _cell(e.pos + Vector2(reach, reach))
	for cy in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			var cell_units = _unit_grid.get(Vector2i(cx, cy))
			if cell_units == null:
				continue
			for o in cell_units:
				# Cheap rejects (comrades, out of reach) before the full scoring.
				if o.owner == e.owner or o.pos.distance_squared_to(e.pos) > lim2:
					continue
				var score := _enemy_score(e, o, radius)
				if score < best_score:
					best_score = score
					best = o
	for o in _buildings:
		# Cheap rejects first: our own side, and anything clearly out of reach.
		if o.owner == e.owner or o.owner < 0:
			continue
		var r2: float = reach + o.size.x * TILE
		if o.pos.distance_squared_to(e.pos) > r2 * r2:
			continue
		var score := _enemy_score(e, o, radius)
		if score < best_score:
			best_score = score
			best = o
	return best


## Whether `a` can strike `t` at all: melee only reaches its own domain (flyers can
## also dive on ground troops); ranged attacks and buildings reach everything.
func can_target(a: Entity, t: Entity) -> bool:
	if t.kind != Entity.UNIT or a.kind != Entity.UNIT:
		return true
	if float(a.def.range) > 1.0:
		return true
	var ad := a.domain()
	var td := t.domain()
	return ad == td or (ad == "air" and td == "ground")


## Lower is a better target; INF when `o` isn't a valid target within `radius`.
func _enemy_score(e: Entity, o: Entity, radius: float) -> float:
	if not o.alive or not is_enemy(e, o) or o.inside >= 0 or not can_target(e, o):
		return INF
	var d := edge_dist(e, o)
	if d > radius or not is_visible_to(e.owner, o):
		return INF
	# Prefer things that can fight back, then the closest.
	return d + (0.0 if o.kind == Entity.UNIT and o.can_attack() else 4.0 * TILE)


func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / GRID_CELL), floori(p.y / GRID_CELL))


## Nearest finished drop-off for `res`; ships can only unload at docks.
func nearest_dropoff(owner: int, res: String, from: Vector2, domain := "ground") -> Entity:
	var best: Entity = null
	var best_d := INF
	for e in entities.values():
		if e.alive and e.owner == owner and e.kind == Entity.BUILDING and not e.constructing \
				and res in e.def.get("dropoff", []) and (domain != "naval" or e.def.get("naval_dropoff", false)):
			var d := rect_dist(e.rect(), from)
			if d < best_d:
				best_d = d
				best = e
	return best


## Nearest gatherable source of `res`: neutral nodes, plus `owner`'s own fields (herb gardens).
func nearest_resource(res: String, from: Vector2, max_dist: float, owner := -1, domain := "ground") -> Entity:
	var best: Entity = null
	var best_d := max_dist
	for e in entities.values():
		if e.alive and is_gatherable(e, owner) and e.def.resource == res and e.def.get("domain", "ground") == domain:
			var d: float = e.pos.distance_to(from)
			if d < best_d:
				best_d = d
				best = e
	return best


func is_gatherable(e: Entity, by_owner: int) -> bool:
	if e.kind == Entity.RESOURCE:
		return not e.def.get("relic", false)
	return e.kind == Entity.BUILDING and e.def.has("resource") and e.owner == by_owner and not e.constructing


## Why `type_id` can't be placed at `top_left` by `player`, or "" if it can.
func placement_error(player: int, type_id: String, top_left: Vector2i) -> String:
	var def: Dictionary = DB.buildings.get(type_id, {})
	var p = players[player]
	if def.is_empty() or not type_id in DB.factions[p.faction].buildable:
		return "Cannot build that"
	if int(def.get("age", 1)) > p.age:
		return "Requires " + DB.ages[int(def.age) - 1].name
	var s := int(def.size)
	var founding_city: bool = def.get("role", "") == "city"
	if founding_city and city_count(player) >= city_limit(player):
		return "City limit reached (%d) - advance the age for more" % city_limit(player)
	for y in s:
		for x in s:
			var t := top_left + Vector2i(x, y)
			if not p.knows_map and not tile_explored(player, t):
				return "Area unexplored"
			var land := territory_owner(t)
			if founding_city and land >= 0 and land != player:
				return "Cannot found a city in foreign territory"
			if not founding_city and land != player:
				return "Must build inside your territory"
	if not map.area_free(top_left, Vector2i(s, s)):
		return "Blocked"
	if def.get("coastal", false) and _shore_tiles(top_left, s) < 2:
		return "Must be built on the shore"
	if def.has("limit") and type_count(player, type_id) >= int(def.limit):
		return "You already have the " + def.name
	if founding_city:
		var center := Rect2(Vector2(top_left) * TILE, Vector2(s, s) * TILE).get_center()
		for e in entities.values():
			if e.alive and is_city(e) and e.pos.distance_to(center) < float(rules.city_min_distance) * TILE:
				return "Too close to another city"
	var lack: String = p.missing(def.get("cost", {}))
	if lack != "":
		return "Not enough " + DB.resource_name(lack)
	return ""


# --- Commands -------------------------------------------------------------------

## Applies a command dict {type, player, ...}. Returns an error message or "".
func issue(cmd: Dictionary) -> String:
	var pid: int = cmd.player
	var queue: bool = cmd.get("queue", false)
	match cmd.type:
		"move", "attack_move":
			var units := _own_units(pid, cmd.ids)
			var kind := String(cmd.get("formation", ""))
			if kind != "" and units.size() > 1 and units[0].domain() == "ground":
				var plan := formation_plan(units, cmd.pos, kind)
				for i in units.size():
					_give(units[i], {"type": cmd.type, "pos": plan.spots[i], "face": plan.face}, queue)
			else:
				var spots := _formation(units.size(), cmd.pos, units[0].domain() if not units.is_empty() else "ground")
				for i in units.size():
					_give(units[i], {"type": cmd.type, "pos": spots[i]}, queue)
		"attack":
			var target := get_entity(cmd.target)
			if target == null or not target.alive:
				return ""
			for u in _own_units(pid, cmd.ids):
				if u.can_attack() and is_enemy(u, target) and can_target(u, target):
					_give(u, {"type": "attack", "target": target.id}, queue)
		"gather":
			var target := get_entity(cmd.get("target", -1))
			var tile: Vector2i = cmd.get("tile", Vector2i(-1, -1))
			if target and not is_gatherable(target, pid):
				return ""
			if target == null and map.timber_at(tile) <= 0.0:
				return ""
			for u in _own_units(pid, cmd.ids):
				if _can_gather(u, target):
					var order := _gather_order(target, tile)
					order.rate *= float(u.def.get("gather_mult", 1.0))
					_give(u, order, queue)
		"build":
			var site := get_entity(cmd.target)
			if site == null or site.owner != pid or not site.constructing:
				return ""
			for u in _own_units(pid, cmd.ids):
				if u.is_worker():
					_give(u, {"type": "build", "target": site.id}, queue)
		"place":
			return _place(pid, cmd)
		"train":
			return _train(pid, cmd)
		"research":
			return _research(pid, cmd)
		"advance_age":
			return _advance_age(pid, cmd)
		"cancel_train":
			var b := get_entity(cmd.building)
			var i: int = cmd.get("index", -1)
			if b and b.owner == pid and i >= 0 and i < b.queue.size():
				var item: Dictionary = b.queue[i]
				players[pid].refund(item.cost)
				_release_item(pid, item)
				b.queue.remove_at(i)
				_update_pop()
		"rally":
			for id in cmd.ids:
				var b := get_entity(id)
				if b and b.owner == pid and b.kind == Entity.BUILDING:
					b.rally = {"pos": cmd.pos, "target": cmd.get("target", -1)}
					if cmd.has("tile"):
						b.rally.tile = cmd.tile
		"stop":
			for u in _own_units(pid, cmd.ids):
				u.orders.clear()
				UnitAI.reset_path(u)
		"cast":
			return _cast(pid, cmd)
		"crown_land":
			return _proclaim(pid, cmd)
		"charter":
			return _charter(pid, cmd)
		"tithe":
			return _tithe(pid, cmd)
		"pickup":
			var r := get_entity(cmd.target)
			if r == null or not r.def.get("relic", false):
				return ""
			for u in _own_units(pid, cmd.ids):
				if not u.is_worker() and u.domain() != "naval":
					_give(u, {"type": "pickup", "target": r.id}, queue)
					return ""
			return "Send a soldier to carry the relic"
		"store":
			var holder := get_entity(cmd.target)
			if holder == null or holder.owner != pid or not is_relic_holder(holder):
				return "Relics are kept in your cities or treasury"
			for u in _own_units(pid, cmd.ids):
				if u.relic >= 0:
					_give(u, {"type": "store", "target": holder.id}, queue)
		"board":
			var t := get_entity(cmd.target)
			if t == null or t.owner != pid or not t.def.has("capacity"):
				return ""
			for u in _own_units(pid, cmd.ids):
				if u.domain() == "ground" and u != t and not u.def.has("capacity"):
					_give(u, {"type": "board", "target": t.id}, queue)
		"unload":
			for u in _own_units(pid, cmd.ids):
				if u.def.has("capacity"):
					_give(u, {"type": "unload", "pos": cmd.pos}, queue)
		"autocast":
			for u in _own_units(pid, cmd.ids):
				if cmd.ability in u.def.get("abilities", []):
					u.autocast[cmd.ability] = bool(cmd.on)
	return ""


## Federal Charter (Monarchy, Age of the Congress): a chartered city's loyalty can't
## fall below the floor and its land bonus grows, but it passes on less income.
func _charter(pid: int, cmd: Dictionary) -> String:
	var city := get_entity(cmd.building)
	var p = players[pid]
	var cfg: Dictionary = rules.loyalty
	if city == null or city.owner != pid or not is_city(city) or city.constructing:
		return "Choose one of your cities"
	if not DB.factions[p.faction].get("loyalty", {}).get("charters", false):
		return "Your realm grants no charters"
	if city.id == p.capital_id:
		return "The capital needs no charter"
	var on: bool = cmd.get("on", true)
	if on:
		if p.age < int(cfg.charter_age):
			return "Requires " + DB.ages[int(cfg.charter_age) - 1].name
		if city.charter:
			return ""
		if charter_count(pid) >= city_count(pid, false) - 1:
			return "No more charters (one per city besides the capital)"
		city.charter = true
		city.charter_tick = tick_count
	else:
		if not city.charter:
			return ""
		if (tick_count - city.charter_tick) * DT < float(cfg.charter_lock):
			return "A charter can't be revoked so soon"
		city.charter = false
	refresh_crown_lands(pid)
	events.append({"type": "charter", "player": pid, "id": city.id, "on": on})
	return ""


func charter_count(pid: int) -> int:
	var n := 0
	for e in entities.values():
		if e.alive and e.owner == pid and is_city(e) and e.charter:
			n += 1
	return n


## Blood Tithe (Covenant): sacrifice the nearest soldier by a city to restore its Dread.
func _tithe(pid: int, cmd: Dictionary) -> String:
	var city := get_entity(cmd.building)
	var p = players[pid]
	var cfg: Dictionary = rules.loyalty
	if city == null or city.owner != pid or not is_city(city):
		return "Choose one of your cities"
	if not DB.factions[p.faction].get("loyalty", {}).get("tithe", false):
		return "Your realm takes no tithes"
	if tick_count < city.tithe_ready_tick:
		return "The tithe was paid recently"
	var victim: Entity = null
	var best := float(cfg.tithe_radius) * TILE
	for e in entities.values():
		if e.alive and e.owner == pid and e.kind == Entity.UNIT and e.can_attack() and not e.is_worker() and not e.is_hero():
			var d: float = e.pos.distance_to(city.pos)
			if d <= best:
				best = d
				victim = e
	if victim == null:
		return "No soldier nearby to sacrifice"
	kill(victim)
	city.loyalty = minf(100.0, city.loyalty + float(cfg.tithe_gain))
	city.tithe_ready_tick = tick_count + roundi(float(cfg.tithe_cooldown) * TICK_RATE)
	events.append({"type": "tithe", "player": pid, "id": city.id, "pos": city.pos})
	return ""


## Income multiplier for resources delivered to `drop` (chartered cities keep a share).
func deposit_mult(drop: Entity) -> float:
	return 1.0 + float(rules.loyalty.charter_income) if drop.charter else 1.0


## Proclaims a city one of the faction's crown lands (each land once).
func _proclaim(pid: int, cmd: Dictionary) -> String:
	var city := get_entity(cmd.building)
	var land: String = cmd.land
	var p = players[pid]
	if city == null or city.owner != pid or not is_city(city) or city.constructing:
		return "Choose one of your cities"
	if not DB.factions[p.faction].get("crown_lands", false) or not DB.crown_lands.has(land) \
			or DB.crown_lands[land].get("faction", "") != p.faction:
		return "Unknown crown land"
	if DB.crown_lands[land].get("capital", false) or city.crown_land != "":
		return "This city is already proclaimed"
	if land in p.crown_lands:
		return "%s is already proclaimed" % DB.crown_lands[land].name
	city.crown_land = land
	refresh_crown_lands(pid)
	events.append({"type": "proclaimed", "player": pid, "id": city.id, "land": land})
	return ""


## Orders the first ready caster among `ids` to cast; it walks into range first.
func _cast(pid: int, cmd: Dictionary) -> String:
	var id: String = cmd.ability
	var a := Abilities.def(id)
	var target := get_entity(cmd.get("target", -1))
	var pos: Vector2 = cmd.get("pos", Vector2.ZERO)
	var best: Entity = null
	var err := "No unit can cast that"
	for u in _own_units(pid, cmd.ids):
		if not id in u.def.get("abilities", []):
			continue
		err = Abilities.cast_error(self, u, id, target)
		if err == "" and (best == null or u.pos.distance_to(pos) < best.pos.distance_to(pos)):
			best = u
	if best == null:
		return err
	if a.target == "self":
		Abilities.cast(self, best, id, null, best.pos)
		return ""
	_give(best, {"type": "cast", "ability": id, "target": target.id if target else -1, "pos": pos}, cmd.get("queue", false))
	return ""


## Workers gather on land; fishing boats only fish.
func _can_gather(u: Entity, target) -> bool:
	if u.def.get("fisher", false):
		return target != null and target.def.get("domain", "ground") == "naval"
	return u.is_worker() and (target == null or target.def.get("domain", "ground") == "ground")


func _gather_order(target, tile: Vector2i) -> Dictionary:
	if target:
		return {"type": "gather", "res": target.def.resource, "target": target.id,
				"rate": float(target.def.gather_rate)}
	return {"type": "gather", "res": "timber", "tile": tile,
			"rate": float(DB.resources.forest.gather_rate)}


func _place(pid: int, cmd: Dictionary) -> String:
	var type_id: String = cmd.building
	var top_left: Vector2i = cmd.tile
	var err := placement_error(pid, type_id, top_left)
	if err != "":
		return err
	var workers: Array = []
	for u in _own_units(pid, cmd.ids):
		if u.is_worker():
			workers.append(u)
	if workers.is_empty():
		return "Needs a worker"
	players[pid].pay(DB.buildings[type_id].get("cost", {}))
	var site := spawn_building(type_id, pid, top_left, false)
	# Push anyone standing on the new footprint out of the way.
	for e in entities.values():
		if e.kind == Entity.UNIT and e.alive and site.rect().grow(UNIT_RADIUS * 0.5).has_point(e.pos):
			var t := map.approach_tile(site.tile, site.size, e.pos)
			e.pos = GameMap.tile_center(t)
			e.prev_pos = e.pos
			UnitAI.reset_path(e)
	for u in workers:
		_give(u, {"type": "build", "target": site.id}, cmd.get("queue", false))
	return ""


## Shared checks for anything queued in a building. Returns an error or "".
func _queue_check(pid: int, b: Entity, cost: Dictionary) -> String:
	if b.queue.size() >= int(rules.queue_limit):
		return "Queue is full"
	var lack: String = players[pid].missing(cost)
	if lack != "":
		return "Not enough " + DB.resource_name(lack)
	return ""


func _train(pid: int, cmd: Dictionary) -> String:
	var b := get_entity(cmd.building)
	var type_id: String = cmd.unit
	if b == null or b.owner != pid or b.constructing or not DB.units.has(type_id) \
			or not (type_id in b.def.get("trains", []) or DB.line_root(type_id) in b.def.get("trains", [])):
		return "Cannot train that here"
	var p = players[pid]
	# A building trains the current tier of the line, whichever tier was asked for.
	var first: Dictionary = DB.units[DB.line_root(type_id)]
	if int(first.get("age", 1)) > p.age:
		return "Requires " + DB.ages[int(first.age) - 1].name
	type_id = DB.tier(DB.line_root(type_id), p.age)
	var udef: Dictionary = DB.units[type_id]
	if udef.get("hero", false) and hero_count(pid) > 0:
		return "Your hero is already in the field"
	if udef.get("hero", false) and p.hero_type != "" and p.hero_type != type_id:
		return "Your chosen hero is " + DB.units[p.hero_type].name
	if not udef.get("faction", "any") in [p.faction, "any"]:
		return "Cannot train that here"
	if udef.has("limit") and line_count(pid, type_id) >= int(udef.limit):
		return "Only %d %s at a time" % [int(udef.limit), udef.name]
	if udef.has("crown_land") and not udef.crown_land in p.crown_lands:
		return "Requires the crown land of " + DB.crown_lands[udef.crown_land].name
	var err := _queue_check(pid, b, udef.cost)
	if err != "":
		return err
	if p.pop_used + int(udef.get("pop", 1)) > p.pop_cap:
		return "Population limit reached" if p.pop_cap >= p.pop_limit() else "Need more housing - build a dwelling"
	p.pay(udef.cost)
	p.pop_used += int(udef.get("pop", 1))
	if udef.get("hero", false):
		p.hero_type = type_id
	var time := float(udef.train_time)
	if udef.get("hero", false) and p.hero_fallen:
		time = float(udef.get("revive_time", time))
	b.queue.append({"kind": "unit", "type": type_id, "progress": 0.0, "time": time, "cost": udef.cost})
	return ""


func _research(pid: int, cmd: Dictionary) -> String:
	var b := get_entity(cmd.building)
	var branch_id: String = cmd.branch
	if b == null or b.owner != pid or b.constructing or not branch_id in b.def.get("research", []):
		return "Cannot research that here"
	var p = players[pid]
	if p.researching.has(branch_id):
		return "Already researching"
	var level := Research.next_level(p, branch_id)
	if level > Research.max_level(branch_id):
		return "Fully researched"
	var info := Research.level_info(branch_id, level)
	if info.age > p.age:
		return "Requires " + DB.ages[info.age - 1].name
	var err := _queue_check(pid, b, info.cost)
	if err != "":
		return err
	p.pay(info.cost)
	p.researching[branch_id] = true
	b.queue.append({"kind": "tech", "type": branch_id, "progress": 0.0, "time": info.time / (1.0 + p.mod("research_speed")), "cost": info.cost})
	return ""


func _advance_age(pid: int, cmd: Dictionary) -> String:
	var b := get_entity(cmd.building)
	if b == null or b.owner != pid or b.constructing or not b.def.get("advances_age", false):
		return "Cannot advance here"
	var p = players[pid]
	if p.age >= final_age():
		return "Already in the final age"
	if p.advancing_age:
		return "Already advancing"
	var next: Dictionary = DB.ages[p.age]
	var err := _queue_check(pid, b, next.cost)
	if err != "":
		return err
	p.pay(next.cost)
	p.advancing_age = true
	b.queue.append({"kind": "age", "type": "age_%d" % next.age, "progress": 0.0,
			"time": float(next.time) / (1.0 + p.mod("research_speed")), "cost": next.cost})
	return ""


func _own_units(pid: int, ids: Array) -> Array:
	var out: Array = []
	for id in ids:
		var e := get_entity(id)
		if e and e.alive and e.owner == pid and e.kind == Entity.UNIT:
			out.append(e)
	return out


func _give(u: Entity, order: Dictionary, queue: bool) -> void:
	if not queue:
		u.orders.clear()
		UnitAI.reset_path(u)
	u.orders.append(order)


const FORMATIONS := ["line", "column", "square", "wedge", "loose"]


## A formation for `units` around `target`, facing the way the group travels:
## {spots: [Vector2] (one per unit, same order), face: Vector2}. Melee fill the
## front rows and ranged the back; within a row units keep their left-to-right
## order so their paths don't cross.
func formation_plan(units: Array, target: Vector2, kind: String) -> Dictionary:
	var n := units.size()
	var c := Vector2.ZERO
	for u in units:
		c += u.pos
	c /= maxf(1.0, n)
	var face := target - c
	face = face.normalized() if face.length() > TILE * 0.5 else Vector2.DOWN
	var right := Vector2(-face.y, face.x)
	var gap := TILE * (1.7 if kind == "loose" else 1.0)
	# Slots in formation space: x across (right), y back from the front.
	var slots: Array = []
	match kind:
		"column":
			var cols := 2 if n <= 10 else 3
			for i in n:
				slots.append(Vector2(i % cols - (mini(cols, n) - 1) * 0.5, i / cols))
		"square":
			var side := 2
			while 4 * (side - 1) < n:
				side += 1
			var ring: Array = []
			for i in side:
				ring.append(Vector2(i, 0))
			for i in range(1, side):
				ring.append(Vector2(side - 1, i))
			for i in range(side - 2, -1, -1):
				ring.append(Vector2(i, side - 1))
			for i in range(side - 2, 0, -1):
				ring.append(Vector2(0, i))
			for i in n:
				slots.append(ring[i] - Vector2((side - 1) * 0.5, 0))
		"wedge":
			var row := 0
			while slots.size() < n:
				for j in row + 1:
					if slots.size() < n:
						slots.append(Vector2(j - row * 0.5, row))
				row += 1
		_:
			# Line (wide and shallow) or loose (a spread-out grid).
			var cols := clampi(ceili(sqrt(n * (4.0 if kind == "line" else 1.5))), 1, n)
			var rows := ceili(float(n) / cols)
			for r in rows:
				var in_row := mini(cols, n - r * cols)
				for j in in_row:
					slots.append(Vector2(j - (in_row - 1) * 0.5, r))
	var depth := 0.0
	for s in slots:
		depth = maxf(depth, s.y)
	# Group slots by row, front first; units by reach, melee first.
	var by_row := {}
	for i in slots.size():
		var key := snappedf(slots[i].y, 0.01)
		if not by_row.has(key):
			by_row[key] = []
		by_row[key].append(i)
	var rows_sorted: Array = by_row.keys()
	rows_sorted.sort()
	var order := units.duplicate()
	order.sort_custom(func(a, b): return float(a.def.get("range", 1.0)) < float(b.def.get("range", 1.0)))
	var spots: Array = []
	spots.resize(n)
	var used := {}
	var next := 0
	for key in rows_sorted:
		var row_slots: Array = by_row[key]
		row_slots.sort_custom(func(a, b): return slots[a].x < slots[b].x)
		var row_units: Array = order.slice(next, next + row_slots.size())
		next += row_slots.size()
		row_units.sort_custom(func(a, b): return (a.pos - c).dot(right) < (b.pos - c).dot(right))
		for k in row_units.size():
			var s: Vector2 = slots[row_slots[k]]
			var p := target + right * s.x * gap - face * (s.y - depth * 0.5) * gap
			var t := GameMap.to_tile(p)
			if not map.in_bounds(t) or not map.is_passable(t, "ground") or used.has(t):
				# Blocked (a building, water) or taken: the nearest free tile instead.
				t = _free_tile_near(t if map.in_bounds(t) else GameMap.to_tile(target), used)
				p = GameMap.tile_center(t)
			used[t] = true
			spots[units.find(row_units[k])] = p
	return {"spots": spots, "face": face}


func _free_tile_near(t: Vector2i, used: Dictionary) -> Vector2i:
	for r in range(0, 8):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := t + Vector2i(dx, dy)
				if map.in_bounds(c) and map.is_passable(c, "ground") and not used.has(c):
					return c
	return t


## Destination points for a group move: the target, then nearby walkable tiles.
func _formation(count: int, target: Vector2, domain := "ground") -> Array:
	var spots: Array = [target]
	if count <= 1:
		return spots
	var center := GameMap.to_tile(target)
	var r := 1
	while spots.size() < count and r < 10:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r or spots.size() >= count:
					continue
				var t := center + Vector2i(dx, dy)
				if map.is_passable(t, domain):
					spots.append(GameMap.tile_center(t))
		r += 1
	while spots.size() < count:
		spots.append(target)
	return spots
