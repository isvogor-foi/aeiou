extends SceneTree
## Headless test runner:  tools/godot --headless --path . -s tests/run_tests.gd
## Exits with the number of failed tests.

const DB = preload("res://sim/db.gd")
const World = preload("res://sim/world.gd")
const Entity = preload("res://sim/entity.gd")
const GameMap = preload("res://sim/game_map.gd")
const Research = preload("res://sim/research.gd")
const Abilities = preload("res://sim/abilities.gd")
const Generator = preload("res://mapgen/generator.gd")

var _failures: Array[String] = []
var _current := ""


func _initialize() -> void:
	DB.ensure_loaded()
	# Every method named test_*, in the order it appears in this file.
	var tests: Array[String] = []
	for m in (get_script() as Script).get_script_method_list():
		if String(m.name).begins_with("test_"):
			tests.append(m.name)
	for t in tests:
		_current = t
		var before := _failures.size()
		call(t)
		print(("  ok    " if _failures.size() == before else "  FAIL  ") + t)
	print("")
	if _failures.is_empty():
		print("All %d tests passed." % tests.size())
	else:
		for f in _failures:
			printerr(f)
		print("%d failure(s)." % _failures.size())
	quit(_failures.size())


func check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append("[%s] %s" % [_current, msg])


## A fresh match with the computer opponent switched off, so tests control everything.
func _world(seed_value := 1234) -> World:
	var w := World.new()
	w.new_game(seed_value, ["monarchy", "covenant"], 0)
	w.ais.clear()
	return w


func _run(w: World, seconds: float) -> void:
	for i in int(seconds * World.TICK_RATE):
		w.tick()


func _units(w: World, owner: int, type_id := "") -> Array:
	var out: Array = []
	for e in w.entities.values():
		if e.alive and e.owner == owner and e.kind == Entity.UNIT and (type_id == "" or e.type_id == type_id):
			out.append(e)
	return out


func _city(w: World, owner: int) -> Entity:
	for e in w.entities.values():
		if e.owner == owner and e.def.get("role", "") == "city":
			return e
	return null


func _clear_enemy_army(w: World) -> void:
	for e in _units(w, 1):
		if not e.is_worker():
			w.kill(e)
	w.tick()


# --- Tests ------------------------------------------------------------------------

func test_data_integrity() -> void:
	for id in DB.units:
		var u: Dictionary = DB.units[id]
		check(DB.factions.has(u.faction) or u.faction == "any", "%s has unknown faction" % id)
		check(u.armor in DB.damage.armors, "%s has unknown armor" % id)
		check(u.dtype in DB.damage.types, "%s has unknown dtype" % id)
	for id in DB.units:
		if DB.units[id].has("crown_land"):
			check(DB.crown_lands.has(DB.units[id].crown_land), "%s has unknown crown land" % id)
	for id in DB.buildings:
		for t in DB.buildings[id].get("trains", []):
			check(DB.units.has(t), "%s trains unknown %s" % [id, t])
	for fid in DB.factions:
		var f: Dictionary = DB.factions[fid]
		check(DB.buildings.has(f.city), "%s city missing" % fid)
		check(DB.units.has(f.worker), "%s worker missing" % fid)
		for b in f.buildable:
			check(DB.buildings.has(b), "%s buildable %s missing" % [fid, b])
	check(DB.ages.size() == 12, "expected 12 ages, got %d" % DB.ages.size())
	for i in DB.ages.size():
		check(int(DB.ages[i].age) == i + 1, "ages are numbered in order (%d)" % (i + 1))
	for i in 6:
		check(not DB.ages[i].get("wip", false), "ages 1-6 are finished")
	# Nothing may need an age that doesn't exist.
	for table in [DB.units, DB.buildings]:
		for id in table:
			check(int(table[id].get("age", 1)) <= DB.ages.size(), "%s needs a missing age" % id)
	for bid in DB.techs.branches:
		for level in range(1, Research.max_level(bid) + 1):
			check(Research.level_info(bid, level).age <= DB.ages.size(), "%s %d needs a missing age" % [bid, level])


func test_damage_matrix() -> void:
	for t in DB.damage.types:
		for a in DB.damage.armors:
			check(DB.damage.matrix[t].has(a), "matrix missing %s vs %s" % [t, a])
	for a in DB.damage.armors:
		for t in DB.damage.types:
			check(DB.damage.matrix.has(t), "matrix missing row %s" % t)
	# The rules the matrix is built on (see the comment in damage.json).
	check(DB.damage_mult("ballistic", "infantry") > 1.0 and DB.damage_mult("ballistic", "cavalry") > 1.0, "rifles shred infantry and cavalry")
	check(DB.damage_mult("ballistic", "armoured") < 1.0 and DB.damage_mult("ballistic", "machine") < 1.0, "armour and machines shrug off rifles")
	for a in ["armoured", "machine", "structure"]:
		check(DB.damage_mult("explosive", a) > 1.0, "explosives crack %s" % a)
	check(DB.damage_mult("aether", "undead") > 1.0, "Aether purges the dead")
	check(DB.damage_mult("soul", "infantry") > 1.0 and DB.damage_mult("soul", "undead") < 1.0, "Soul fire withers the living, not the dead")


func test_mapgen_symmetry_and_connectivity() -> void:
	for seed_value in [1, 77, 4242, 99991]:
		var m := GameMap.new()
		var layout := Generator.generate(m, seed_value)
		var sym := true
		for y in m.height:
			for x in m.width:
				if m.terrain[m.idx(Vector2i(x, y))] != m.terrain[m.idx(Vector2i(m.width - 1 - x, m.height - 1 - y))]:
					sym = false
		check(sym, "seed %d not symmetric" % seed_value)
		var path: PackedVector2Array = m.astar.get_point_path(layout.starts[0], layout.starts[1])
		check(not path.is_empty(), "seed %d starts not connected" % seed_value)
		check(layout.nodes.size() % 2 == 0 and layout.nodes.size() >= 8, "seed %d node count" % seed_value)


func test_new_game_setup() -> void:
	var w := _world()
	check(_city(w, 0) != null and _city(w, 1) != null, "both players have a city")
	check(_units(w, 0, "settler").size() == 3, "player starts with 3 acolytes")
	check(w.players[0].pop_cap == 15, "city gives 15 pop, got %d" % w.players[0].pop_cap)
	check(w.tile_visible(0, GameMap.to_tile(_city(w, 0).pos)), "own city visible")
	check(not w.tile_explored(0, GameMap.to_tile(_city(w, 1).pos)), "enemy city starts unexplored")


func test_workers_gather_gold() -> void:
	var w := _world()
	var worker: Entity = _units(w, 0, "settler")[0]
	var mine := w.nearest_resource("gold", worker.pos, 40 * GameMap.TILE)
	check(mine != null, "gold mine near start")
	var gold_before: float = w.players[0].res.gold
	w.issue({"type": "gather", "player": 0, "ids": [worker.id], "target": mine.id})
	_run(w, 60)
	check(w.players[0].res.gold > gold_before + 15, "gold increased (%.1f -> %.1f)" % [gold_before, w.players[0].res.gold])
	check(mine.amount < float(DB.resources.gold_mine.amount), "mine depleted somewhat")


func test_workers_gather_timber() -> void:
	var w := _world()
	var worker: Entity = _units(w, 0, "settler")[0]
	var tile := w.map.nearest_forest(GameMap.to_tile(worker.pos), 20)
	check(tile.x >= 0, "forest near start")
	var before: float = w.players[0].res.timber
	w.issue({"type": "gather", "player": 0, "ids": [worker.id], "tile": tile})
	_run(w, 60)
	check(w.players[0].res.timber > before + 15, "timber increased (%.1f -> %.1f)" % [before, w.players[0].res.timber])


func test_train_unit_and_pop() -> void:
	var w := _world()
	var city := _city(w, 0)
	var herbs: float = w.players[0].res.herbs
	check(w.issue({"type": "train", "player": 0, "building": city.id, "unit": "settler"}) == "", "train ok")
	check(w.players[0].res.herbs == herbs - 50, "cost paid")
	check(w.issue({"type": "train", "player": 0, "building": city.id, "unit": "grenadier"}) != "", "city can't train wardens")
	_run(w, 13)
	check(_units(w, 0, "settler").size() == 4, "acolyte trained")
	# Fill the population cap.
	w.players[0].res.herbs = 10000
	var errors := 0
	for i in 15:
		if w.issue({"type": "train", "player": 0, "building": city.id, "unit": "settler"}) != "":
			errors += 1
	check(errors > 0, "queue/pop limits enforced")


func test_place_and_construct() -> void:
	var w := _world()
	var workers := _units(w, 0, "settler")
	var city := _city(w, 0)
	var spot := city.tile + Vector2i(0, 6)
	var err := w.placement_error(0, "dwelling", spot)
	if err != "":
		spot = city.tile + Vector2i(-4, 0)
		err = w.placement_error(0, "dwelling", spot)
	check(err == "", "placement valid: " + err)
	check(w.placement_error(0, "blood_pit", spot) != "", "can't build enemy faction building")
	w.issue({"type": "place", "player": 0, "ids": [workers[0].id, workers[1].id], "building": "dwelling", "tile": spot})
	_run(w, 20)
	check(w.players[0].pop_cap == 25, "dwelling adds pop when done (cap %d)" % w.players[0].pop_cap)


## Formations: each layout gives every soldier its own spot, a line is wider than
## deep across the march, a column deeper than wide, and the troops face the march.
func test_formations() -> void:
	var w := _world()
	_clear_enemy_army(w)
	var city := _city(w, 0)
	var start: Vector2 = city.pos + Vector2(0, 4 * GameMap.TILE)
	var goal: Vector2 = start + Vector2(10 * GameMap.TILE, 0)
	for kind in World.FORMATIONS:
		var ids: Array = []
		var units: Array = []
		for i in 9:
			var u = w.spawn_unit("musketeer" if i % 2 else "grenadier", 0, start + Vector2(i % 3, i / 3) * GameMap.TILE)
			units.append(u)
			ids.append(u.id)
		var plan: Dictionary = w.formation_plan(units, goal, kind)
		var distinct := {}
		for p in plan.spots:
			distinct[Vector2i(p / 4.0)] = true
		check(distinct.size() == 9, "%s: every soldier gets its own spot (%d)" % [kind, distinct.size()])
		var xs: Array = plan.spots.map(func(p): return p.x)
		var ys: Array = plan.spots.map(func(p): return p.y)
		var along: float = xs.max() - xs.min()
		var across: float = ys.max() - ys.min()
		if kind == "line":
			check(across > along, "line: wider across the march than deep (%.0f vs %.0f)" % [across, along])
		if kind == "column":
			check(along > across, "column: deeper along the march than wide (%.0f vs %.0f)" % [along, across])
		w.issue({"type": "move", "player": 0, "ids": ids, "pos": goal, "formation": kind})
		_run(w, 25)
		var facing_ok := units.all(func(u): return u.facing.dot(Vector2.RIGHT) > 0.9)
		check(facing_ok, "%s: troops face the march on arrival" % kind)
		for u in units:
			w.kill(u)


## Cheats: fast building and training, fast research and ages.
func test_fast_cheats() -> void:
	var w := _world()
	var city := _city(w, 0)
	var p = w.players[0]
	p.res.gold = 9999.0
	p.res.herbs = 9999.0
	p.res.timber = 9999.0
	p.res.mana = 9999.0
	p.cheat_build = true
	w.issue({"type": "train", "player": 0, "building": city.id, "unit": "settler"})
	var t: float = DB.units.settler.get("train_time", 10.0)
	_run(w, float(t) / 5.0)
	check(_units(w, 0, "settler").size() == 4, "fast training: settler done in a fifth of the time")
	p.cheat_advance = true
	w.issue({"type": "advance_age", "player": 0, "building": city.id})
	_run(w, float(DB.ages[1].time) / 5.0)
	check(p.age == 2, "fast advance: next age in a fifth of the time (age %d)" % p.age)


func test_city_capture_and_conquest() -> void:
	var w := _world()
	_clear_enemy_army(w)
	var enemy_city := _city(w, 1)
	var army: Array = []
	for i in 16:
		army.append(w.spawn_unit("musketeer", 0, enemy_city.pos + Vector2(-6 * GameMap.TILE, 0)))
	army.append(w.spawn_unit("tross_wagon", 0, enemy_city.pos + Vector2(-7 * GameMap.TILE, 0)))
	w.update_fog()
	var ids := army.map(func(u): return u.id)
	w.issue({"type": "attack", "player": 0, "ids": ids, "target": enemy_city.id})
	_run(w, 90)
	check(enemy_city.alive and enemy_city.owner == 0, "enemy city captured (owner %d, hp %.0f)" % [enemy_city.owner, enemy_city.hp])
	check(enemy_city.type_id == "residenz", "captured city converts to our city type")
	_run(w, 2)
	check(w.players[1].defeated, "enemy with no cities is defeated")
	check(w.winner == 0, "player 0 wins (winner %d)" % w.winner)
	check(_units(w, 1).is_empty(), "defeated player's units are gone")


func test_city_holds_while_defended() -> void:
	var w := _world()
	var enemy_city := _city(w, 1)
	var attacker := w.spawn_unit("musketeer", 0, enemy_city.pos + Vector2(-6 * GameMap.TILE, 0))
	for i in 2:
		w.spawn_unit("reaver", 1, enemy_city.pos + Vector2(0, 3 * GameMap.TILE))
	enemy_city.hp = 1.0
	w.deal_damage(attacker, enemy_city)
	check(enemy_city.owner == 1 and enemy_city.hp == 1.0, "outnumbered attacker can't capture; city holds at 1 HP")


func test_attack_move_engages() -> void:
	var w := _world()
	var city := _city(w, 0)
	var guard := w.spawn_unit("grenadier", 0, city.pos + Vector2(0, 4 * GameMap.TILE))
	var raider := w.spawn_unit("reaver", 1, guard.pos + Vector2(8 * GameMap.TILE, 0))
	w.update_fog()
	w.issue({"type": "attack_move", "player": 0, "ids": [guard.id], "pos": raider.pos + Vector2(6 * GameMap.TILE, 0)})
	_run(w, 30)
	check(not raider.alive or raider.hp < raider.max_hp, "attack-move engaged the raider")


func test_hungary_rises() -> void:
	var w := World.new()
	w.new_game(77, ["monarchy", "covenant"], -1, "normal")
	var hu: int = w.rebels
	check(w.players[hu].faction == "hungary", "the rebel side is Hungary")
	check(w.city_count(hu) == 0, "no Hungarian city before the rising")
	w.tick_count = int(float(w.rules.hungary.rise_at) * World.TICK_RATE) - 1
	_run(w, 2)
	check(w.hungary_risen, "Hungary rose on schedule")
	check(w.city_count(hu) == 1, "Hungary holds a city")
	check(_units(w, hu).size() >= 10, "with workers and a garrison (%d)" % _units(w, hu).size())
	check(w.ais.any(func(ai): return ai.pid == hu), "Hungary has an AI")
	var city := _city(w, 0)
	var foe: Entity = _units(w, hu)[0]
	check(w.is_enemy(foe, city) and w.is_enemy(foe, _city(w, 1)), "Hungary is hostile to both sides")
	_run(w, 120)
	check(w.winner < 0 or w.winner != hu, "Hungary never wins the match")
	var off := World.new()
	off.new_game(77, ["monarchy", "covenant"], -1, "normal", "inland", {"hungary": false})
	off.tick_count = int(float(off.rules.hungary.rise_at) * World.TICK_RATE) + 40
	_run(off, 2)
	check(not off.hungary_risen, "the rising can be switched off")


## Regression: units crowding one target used to orbit a shared waypoint forever
## (the sideways separation push kept both from ever reaching it).
func test_crowd_settles_at_shared_target() -> void:
	var w := _world(4242)
	var city := _city(w, 0)
	var target := w.spawn_building("kaserne", 1, city.tile + Vector2i(8, 0), true)
	target.max_hp = 1e9
	target.hp = 1e9
	var ids: Array = []
	for i in 8:
		ids.append(w.spawn_unit("grenadier", 0, city.pos + Vector2(100 + i * 8, 150)).id)
	w.issue({"type": "attack", "player": 0, "ids": ids, "target": target.id})
	_run(w, 20)
	for id in ids:
		w.get_entity(id).moved = 0.0
	_run(w, 10)
	var moved := 0.0
	for id in ids:
		moved += w.get_entity(id).moved
	check(moved < 100.0, "attackers settle around the target (moved %d px in 10 s)" % int(moved))


func test_territory_and_placement() -> void:
	var w := _world()
	var city := _city(w, 0)
	var center := GameMap.to_tile(city.pos)
	check(w.territory_owner(center) == 0, "city tile is ours")
	check(w.territory_owner(center + Vector2i(20, 20)) == -1, "far away is neutral")
	check(w.territory_owner(GameMap.to_tile(_city(w, 1).pos)) == 1, "enemy owns its city")
	# Outside the border: plain buildings refused, cities allowed in neutral land (if spaced).
	w.players[0].res = {"gold": 9999.0, "timber": 9999.0, "herbs": 9999.0, "mana": 9999.0}
	for x in w.map.width:
		for y in w.map.height:
			w.players[0].vis[w.map.idx(Vector2i(x, y))] = 1
	var far := _find_free(w, center + Vector2i(18, 4), 4)
	check(w.placement_error(0, "dwelling", far).contains("territory"), "dwelling outside borders refused")
	check(w.placement_error(0, "residenz", far) == "", "new city in neutral land ok: " + w.placement_error(0, "residenz", far))
	var near := _find_free(w, center + Vector2i(5, 5), 4)
	check(w.placement_error(0, "residenz", near) != "", "city too close refused")
	var enemy := GameMap.to_tile(_city(w, 1).pos) + Vector2i(-6, 0)
	check(w.placement_error(0, "residenz", _find_free(w, enemy, 4)) != "", "city in enemy land refused")
	# Founding expands borders once built.
	var worker: Entity = _units(w, 0, "settler")[0]
	check(w.issue({"type": "place", "player": 0, "ids": [worker.id], "building": "residenz", "tile": far}) == "", "place city")
	_run(w, 90)
	check(w.territory_owner(far + Vector2i(2, 2)) == 0, "new city projects borders")


func _find_free(w: World, around: Vector2i, size: int) -> Vector2i:
	for r in 10:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var t := around + Vector2i(dx, dy)
				if w.map.area_free(t, Vector2i(size, size)):
					return t
	return around


func test_gather_cap_limits_income() -> void:
	var w := _world()
	var city := _city(w, 0)
	var mine := w.nearest_resource("gold", city.pos, 40 * GameMap.TILE)
	var ids: Array = []
	for i in 14:
		ids.append(w.spawn_unit("settler", 0, mine.pos + Vector2(0, 40)).id)
	w.issue({"type": "gather", "player": 0, "ids": ids, "target": mine.id})
	var before: float = w.players[0].res.gold
	_run(w, 60)
	var rate: float = (w.players[0].res.gold - before) / 60.0
	var cap: float = w.players[0].gather_cap("gold")
	check(rate <= cap * 1.05, "gold income %.2f/s within cap %.2f/s" % [rate, cap])
	check(rate >= cap * 0.6, "14 workers get close to the cap (%.2f/s)" % rate)


func test_research_and_age_gating() -> void:
	var w := _world()
	var p = w.players[0]
	p.res = {"gold": 9999.0, "timber": 9999.0, "herbs": 9999.0, "mana": 9999.0}
	var city := _city(w, 0)
	var lib := w.spawn_building("library", 0, _find_free(w, city.tile + Vector2i(6, 0), 3), true)
	var cap_before: float = p.gather_cap("gold")
	check(w.issue({"type": "research", "player": 0, "building": lib.id, "branch": "charms"}) == "", "research charms I")
	check(w.issue({"type": "research", "player": 0, "building": lib.id, "branch": "charms"}) != "", "no double research")
	_run(w, 31)
	check(p.techs.get("charms", 0) == 1, "charms I done")
	check(p.gather_cap("gold") > cap_before, "cap raised")
	check(w.issue({"type": "research", "player": 0, "building": lib.id, "branch": "charms"}).contains("Requires"), "charms II needs age 2")
	var hp_before: float = city.max_hp
	w.issue({"type": "research", "player": 0, "building": lib.id, "branch": "defense"})
	_run(w, 31)
	check(city.max_hp > hp_before, "defense raises building HP")
	check(w.issue({"type": "train", "player": 0, "building": city.id, "unit": "settler"}) == "", "still trains")
	var gold: float = p.res.gold
	w.issue({"type": "research", "player": 0, "building": lib.id, "branch": "potions"})
	w.issue({"type": "cancel_train", "player": 0, "building": lib.id, "index": 0})
	check(p.res.gold == gold and not p.researching.has("potions"), "cancel refunds and unlocks")


func test_age_up_raises_city_limit() -> void:
	var w := _world()
	var p = w.players[0]
	p.res = {"gold": 9999.0, "timber": 9999.0, "herbs": 9999.0, "mana": 9999.0}
	check(w.city_limit(0) == 2, "age 1 allows 2 cities")
	var city := _city(w, 0)
	check(w.issue({"type": "train", "player": 0, "building": _barracks(w), "unit": "tross_wagon"}) != "", "wagon locked in age 1")
	check(w.issue({"type": "advance_age", "player": 0, "building": city.id}) == "", "start age up")
	check(w.issue({"type": "advance_age", "player": 0, "building": city.id}) != "", "only one age up at a time")
	_run(w, float(DB.ages[1].time) + 1.0)
	check(p.age == 2, "reached age 2 (age %d)" % p.age)
	check(w.city_limit(0) == 3, "age 2 allows 3 cities")


## The age ladder: finished ages only by default, a per-match last age, and with
## all ages unlocked a player climbs from the first to the twelfth.
func test_age_ladder() -> void:
	check(Research.roman(4) == "IV" and Research.roman(9) == "IX" and Research.roman(12) == "XII", "roman numerals to XII")
	var w := _world()
	check(w.final_age() == DB.last_age(), "a normal match ends at the last finished age (%d)" % w.final_age())
	var p = w.players[0]
	var city := _city(w, 0)
	p.res = {"gold": 1e6, "timber": 1e6, "herbs": 1e6, "mana": 1e6, "coal": 1e6}
	p.age = w.final_age()
	check(w.issue({"type": "advance_age", "player": 0, "building": city.id}) != "", "no advancing past the last age")
	w = World.new()
	w.new_game(5, ["monarchy", "covenant"], 0, "normal", "inland", {"end_age": 3})
	check(w.final_age() == 3, "skirmish Last age caps the ladder (%d)" % w.final_age())
	w = World.new()
	w.new_game(5, ["monarchy", "covenant"], 0, "normal", "inland", {"start_age": 4, "end_age": 2})
	check(w.final_age() == 4, "the last age is never below the starting age (%d)" % w.final_age())
	# All twelve, the developer way.
	w = World.new()
	w.new_game(5, ["monarchy", "covenant"], 0, "normal", "inland", {"all_ages": true})
	w.ais.clear()
	check(w.final_age() == DB.ages.size(), "all_ages opens every age")
	p = w.players[0]
	city = _city(w, 0)
	p.res = {"gold": 1e6, "timber": 1e6, "herbs": 1e6, "mana": 1e6, "coal": 1e6}
	while p.age < DB.ages.size():
		var was: int = p.age
		check(w.issue({"type": "advance_age", "player": 0, "building": city.id}) == "", "advance from age %d" % was)
		_run(w, float(DB.ages[was].time) + 1.0)
		if p.age == was:
			check(false, "stuck in age %d" % was)
			break
	check(p.age == DB.ages.size(), "climbed to age %d" % p.age)
	check(w.issue({"type": "advance_age", "player": 0, "building": city.id}) != "", "the twelfth age is the last")


## Upgrade lines in the data: each step exists, stays in the faction and domain,
## comes in a later age, and never loops back.
func test_upgrade_line_data() -> void:
	DB.reset_lines()
	for id in DB.units:
		var next: String = DB.units[id].get("upgrades_to", "")
		if next == "":
			continue
		check(DB.units.has(next), "%s upgrades to unknown %s" % [id, next])
		if not DB.units.has(next):
			continue
		var a: Dictionary = DB.units[id]
		var b: Dictionary = DB.units[next]
		check(a.get("faction", "any") == b.get("faction", "any"), "%s -> %s changes faction" % [id, next])
		check(a.get("domain", "ground") == b.get("domain", "ground"), "%s -> %s changes domain" % [id, next])
		check(int(b.get("age", 1)) > int(a.get("age", 1)), "%s -> %s must come in a later age" % [id, next])
		check(not a.get("hero", false) and not b.get("hero", false), "heroes don't upgrade (%s)" % id)
		check(DB.line_of(id).size() < 32, "%s's line loops" % id)
		check(DB.visuals.units.has(next), "%s has no visuals" % next)


## A temporary line Musketeer -> Test Rifleman (Age 2): training gives the current
## tier, an age-up refits the soldiers in place, and queues, limits and scoped
## research follow the line.
func test_upgrade_lines() -> void:
	var rifle: Dictionary = DB.units.musketeer.duplicate(true)
	rifle.id = "test_rifleman"
	rifle.name = "Test Rifleman"
	rifle.age = 2
	rifle.hp = 90
	rifle.cost = {"gold": 70, "herbs": 40}
	DB.units["test_rifleman"] = rifle
	DB.visuals.units["test_rifleman"] = DB.visuals.units.musketeer
	DB.units.musketeer["upgrades_to"] = "test_rifleman"
	DB.reset_lines()
	check(DB.line_root("test_rifleman") == "musketeer", "line root")
	check(DB.tier("musketeer", 1) == "musketeer" and DB.tier("musketeer", 2) == "test_rifleman", "tier by age")
	check(DB.line_of("musketeer") == ["musketeer", "test_rifleman"], "line_of")
	check(Research.trainer_of("test_rifleman") == "kaserne", "later tiers keep their trainer's upgrades")

	var w := _world()
	var p = w.players[0]
	p.res = {"gold": 1e5, "timber": 1e5, "herbs": 1e5, "mana": 1e5, "coal": 1e5}
	var kaserne := _barracks(w)
	var city := _city(w, 0)
	var musk := w.spawn_unit("musketeer", 0, city.pos + Vector2(0, 5 * GameMap.TILE))
	musk.hp = musk.max_hp * 0.5
	var goal := city.pos + Vector2(6, 6) * GameMap.TILE
	w.issue({"type": "move", "player": 0, "ids": [musk.id], "pos": goal})
	check(w.issue({"type": "train", "player": 0, "building": kaserne, "unit": "test_rifleman"}) == "", "asking for a later tier is fine")
	check(w.get_entity(kaserne).queue[-1].type == "musketeer", "...but Age 1 trains the Musketeer")
	# Advance while a Musketeer is still in training.
	check(w.issue({"type": "advance_age", "player": 0, "building": city.id}) == "", "age up")
	# Tick until the age arrives, catching the refit event and the health share around it.
	var refit_event := {}
	var share_before := 0.0
	for i in int((float(DB.ages[1].time) + 1.0) * World.TICK_RATE):
		share_before = musk.hp / musk.max_hp
		w.tick()
		for ev in w.events:
			if ev.type == "refit" and ev.player == 0:
				refit_event = ev
		if p.age == 2:
			break
	check(p.age == 2, "reached Age 2")
	check(musk.alive and musk.type_id == "test_rifleman", "the Musketeer was refitted in place (%s)" % musk.type_id)
	check(absf(musk.hp / musk.max_hp - share_before) < 0.02, "health share kept (%.2f -> %.2f)" % [share_before, musk.hp / musk.max_hp])
	check(is_equal_approx(musk.max_hp, w._max_hp_for(musk)) and musk.max_hp > DB.units.musketeer.hp, "max HP from the new type")
	check(int(refit_event.get("units", {}).get("test_rifleman", 0)) >= 1, "a refit event names the new tier")
	_run(w, 2)
	var trained := _units(w, 0, "musketeer")
	check(trained.is_empty(), "no Musketeers left after the age-up (%d)" % trained.size())
	check(_units(w, 0, "test_rifleman").size() >= 2, "the queued Musketeer came out a Test Rifleman")
	var gold: float = p.res.gold
	check(w.issue({"type": "train", "player": 0, "building": kaserne, "unit": "musketeer"}) == "", "the Musketeer button still works")
	check(w.get_entity(kaserne).queue[-1].type == "test_rifleman", "...and trains the new tier")
	check(is_equal_approx(gold - p.res.gold, 70.0), "at the new tier's price (%.0f)" % (gold - p.res.gold))
	# Limits count the whole line.
	DB.units.test_rifleman["limit"] = 1
	check(w.line_count(0, "musketeer") >= 3, "line_count counts every tier")
	check(w.issue({"type": "train", "player": 0, "building": kaserne, "unit": "musketeer"}) != "", "limit applies to the line")

	DB.units.erase("test_rifleman")
	DB.visuals.units.erase("test_rifleman")
	DB.units.musketeer.erase("upgrades_to")
	DB.reset_lines()


## Every vehicle in the kit builds, bakes, and keeps its moving parts live: wheels
## on all of them, track belts on the tracked ones, a turret where there's a gun.
func test_vehicle_kit() -> void:
	const Machines = preload("res://view3d/machines.gd")
	const Vehicles = preload("res://view3d/vehicles.gd")
	for kind in Vehicles.KINDS:
		var n: Node3D = Machines.build(kind, Color(0.8, 0.2, 0.2))
		var parts: Array = n.find_children("*", "Node3D", true, false)
		var rolls := parts.filter(func(c): return c.has_meta("roll")).size()
		var treads := parts.filter(func(c): return c.has_meta("tread")).size()
		var turrets := parts.filter(func(c): return c.has_meta("turret")).size()
		check(n.get_child_count() > 0 and n.get_child(0) is MeshInstance3D, "%s bakes a hull mesh" % kind)
		var props := parts.filter(func(c): return c.has_meta("spin_z") or c.has_meta("flap")).size()
		if kind in Vehicles.GROUND or kind in Vehicles.CIVILIAN:
			check(rolls >= 2, "%s has turning wheels (%d)" % [kind, rolls])
		elif kind not in ["jet", "wraith_jet"]:
			check(props >= 1, "%s has a propeller or wings that move (%d)" % [kind, props])
		if kind in ["halftrack", "light_tank", "heavy_tank", "undead_panzer", "bone_halftrack"]:
			check(treads == 2, "%s has two track belts (%d)" % [kind, treads])
		if kind in ["armoured_car", "halftrack", "light_tank", "heavy_tank", "rocket_truck", "undead_panzer", "bone_halftrack"]:
			check(turrets == 1, "%s has a turret (%d)" % [kind, turrets])
		# A sealed turret is one mesh, not dozens of parts.
		for t in parts.filter(func(c): return c.has_meta("turret")):
			check(t.get_children().filter(func(c): return c is MeshInstance3D).size() == 1, "%s turret is baked" % kind)
		n.free()


## Era variants: "id@N" outfits apply from Age N on, latest first; every variant
## belongs to a real outfit.
func test_outfit_variants() -> void:
	const Figure = preload("res://view3d/figure.gd")
	check(Figure.variant("settler", 1) == "settler", "Age 1 settler wears the base outfit")
	check(Figure.variant("settler", 7) == "settler@7", "Age 7 settler wears overalls")
	check(Figure.variant("settler", 9) == "settler@7", "variants hold until the next one")
	check(Figure.variant("settler", 12) == "settler@10", "the latest variant wins")
	check(Figure.variant("grenadier", 12) == "grenadier", "outfits without variants never change")
	for key in Figure.OUTFITS:
		if "@" in key:
			check(Figure.OUTFITS.has(key.get_slice("@", 0)), "variant %s has a base outfit" % key)
			check(int(key.get_slice("@", 1)) in range(2, DB.ages.size() + 1), "variant %s names a real age" % key)


func _barracks(w: World) -> int:
	var city := _city(w, 0)
	var b := w.spawn_building("kaserne", 0, _find_free(w, city.tile + Vector2i(0, 6), 3), true)
	return b.id


func test_attrition_and_supply() -> void:
	var w := _world()
	_clear_enemy_army(w)
	var enemy_land := _city(w, 1).pos + Vector2(-5 * GameMap.TILE, 0)
	var lone := w.spawn_unit("settler", 0, _city(w, 1).pos + Vector2(5 * GameMap.TILE, 0))
	var escorted := w.spawn_unit("settler", 0, enemy_land + Vector2(0, 2 * GameMap.TILE))
	w.spawn_unit("tross_wagon", 0, enemy_land + Vector2(0, 3 * GameMap.TILE))
	# Keep the enemy city's turret out of it.
	_city(w, 1).def = _city(w, 1).def.duplicate()
	_city(w, 1).def.damage = 0
	_run(w, 10)
	check(lone.hp < lone.max_hp * 0.95, "unsupplied unit suffers attrition (%.0f/%.0f)" % [lone.hp, lone.max_hp])
	check(escorted.hp == escorted.max_hp, "supplied unit is spared (%.0f/%.0f)" % [escorted.hp, escorted.max_hp])


func test_herb_garden_is_renewable() -> void:
	var w := _world()
	var city := _city(w, 0)
	var garden := w.spawn_building("garden", 0, _find_free(w, city.tile + Vector2i(0, 7), 2), true)
	check(w.nearest_resource("herbs", garden.pos, 64.0, 1) != garden, "enemy can't gather our garden")
	var worker: Entity = _units(w, 0, "settler")[0]
	var before: float = w.players[0].res.herbs
	check(w.issue({"type": "gather", "player": 0, "ids": [worker.id], "target": garden.id}) == "", "gather garden")
	_run(w, 60)
	check(w.players[0].res.herbs > before + 15, "garden yields herbs (%.0f -> %.0f)" % [before, w.players[0].res.herbs])
	check(garden.alive and garden.amount < 0, "garden never runs out")


## The computer opponent, left alone, grows a working economy and an army.
func test_ai_builds_up() -> void:
	var w := World.new()
	w.new_game(1234, ["monarchy", "covenant"], 0, "normal")
	_run(w, 360)
	var ai_workers := _units(w, 1).filter(func(u): return u.is_worker()).size()
	var ai_army := _units(w, 1).filter(func(u): return not u.is_worker()).size()
	var types := {}
	for e in w.entities.values():
		if e.owner == 1 and e.kind == Entity.BUILDING:
			types[e.type_id] = true
	check(ai_workers >= 12, "AI has 12+ workers after 6 min (%d)" % ai_workers)
	check(types.has("blood_pit"), "AI built its barracks")
	check(types.has("dwelling"), "AI built housing")
	check(ai_army > 0, "AI trained an army (%d)" % ai_army)


## Against a player who does nothing, the AI eventually invades.
func test_ai_attacks_passive_player() -> void:
	var w := World.new()
	w.new_game(1234, ["monarchy", "covenant"], 0, "normal")
	var invaded := false
	for i in 12 * 60:
		_run(w, 1)
		for u in _units(w, 1):
			if w.territory_owner(GameMap.to_tile(u.pos)) == 0 and not u.is_worker():
				invaded = true
		if invaded:
			break
	check(invaded, "AI army entered our territory within 12 minutes")


func _rich(w: World, pid := 0) -> void:
	w.players[pid].res = {"gold": 9999.0, "timber": 9999.0, "herbs": 9999.0, "mana": 9999.0}


func test_spells_heal_ward_drain() -> void:
	var w := _world()
	_rich(w)
	_rich(w, 1)
	var c := _city(w, 0).pos + Vector2(0, 6 * GameMap.TILE)
	var mender := w.spawn_unit("field_alchemist", 0, c)
	var hurt := w.spawn_unit("kuerassier", 0, c + Vector2(32, 0))
	hurt.hp = 40.0
	var mana: float = w.players[0].res.mana
	check(w.issue({"type": "cast", "player": 0, "ids": [mender.id], "ability": "heal", "target": hurt.id}) == "", "cast heal")
	_run(w, 0.5)
	check(hurt.hp >= 80.0, "heal restored HP (%.0f)" % hurt.hp)
	check(w.players[0].res.mana == mana - 10.0, "heal cost 10 mana")
	check(w.issue({"type": "cast", "player": 0, "ids": [mender.id], "ability": "heal", "target": hurt.id}) != "", "heal is on cooldown")
	w.issue({"type": "cast", "player": 0, "ids": [mender.id], "ability": "ward", "target": hurt.id})
	_run(w, 0.5)
	var before := hurt.hp
	var foe := w.spawn_unit("reaver", 1, c + Vector2(64, 0))
	w.apply_damage(foe, hurt, 40.0, "aether")
	check(hurt.hp == before, "ward absorbed the hit")
	var necro := w.spawn_unit("necromancer", 1, c + Vector2(96, 0))
	necro.hp = 30.0
	w.issue({"type": "cast", "player": 1, "ids": [necro.id], "ability": "life_drain", "target": hurt.id})
	_run(w, 0.5)
	check(necro.hp > 30.0, "life drain healed the necromancer (%.0f)" % necro.hp)


func test_fireball_and_summons() -> void:
	var w := _world()
	_rich(w)
	_rich(w, 1)
	var c := _city(w, 0).pos + Vector2(0, 8 * GameMap.TILE)
	var mage := w.spawn_unit("rudolf", 0, c)
	var foes: Array = []
	for i in 3:
		foes.append(w.spawn_unit("reaver", 1, c + Vector2(5 * GameMap.TILE, i * 12)))
	w.update_fog()
	check(w.issue({"type": "cast", "player": 0, "ids": [mage.id], "ability": "fireball", "pos": foes[1].pos}) == "", "cast fireball")
	_run(w, 0.3)
	var hit := foes.filter(func(f): return not f.alive or f.hp < f.max_hp).size()
	check(hit == 3, "fireball hit all 3 grouped enemies (%d)" % hit)
	var sov := w.spawn_unit("shadow_sovereign", 1, c + Vector2(0, 6 * GameMap.TILE))
	var before := _units(w, 1, "risen").size()
	check(w.issue({"type": "cast", "player": 1, "ids": [sov.id], "ability": "summon_horde"}) == "", "summon horde")
	check(_units(w, 1, "risen").size() == before + 5, "5 risen appear")
	_run(w, 41)
	check(_units(w, 1, "risen").size() == 0, "summons expire")


func test_auras_cleave_and_charge() -> void:
	var w := _world()
	var c := _city(w, 0).pos + Vector2(0, 8 * GameMap.TILE)
	var guard := w.spawn_unit("grenadier", 0, c)
	var foe := w.spawn_unit("reaver", 1, c + Vector2(30, 0))
	w.tick()
	var hp := guard.hp
	w.apply_damage(foe, guard, 50.0, "aether")
	var plain := hp - guard.hp
	w.spawn_unit("rudolf", 0, c + Vector2(0, 40))
	w.tick()
	hp = guard.hp
	w.apply_damage(foe, guard, 50.0, "aether")
	check(hp - guard.hp < plain * 0.85, "archmage aura reduces damage (%.1f vs %.1f)" % [hp - guard.hp, plain])
	# Cleave: a brute's blow also hurts the target's neighbour.
	var brute := w.spawn_unit("grave_brute", 1, c + Vector2(0, 5 * GameMap.TILE))
	var a := w.spawn_unit("grenadier", 0, brute.pos + Vector2(20, 0))
	var b := w.spawn_unit("grenadier", 0, a.pos + Vector2(0, 20))
	w.deal_damage(brute, a)
	check(b.hp < b.max_hp, "cleave splashed the neighbour")
	# Charge: after a run-up the knight's blow is doubled.
	var knight := w.spawn_unit("kuerassier", 0, c + Vector2(-8 * GameMap.TILE, 0))
	var dummy := w.spawn_unit("musketeer", 1, c + Vector2(-2 * GameMap.TILE, 0))
	dummy.def = dummy.def.duplicate()
	dummy.def.damage = 0
	w.update_fog()
	w.issue({"type": "attack", "player": 0, "ids": [knight.id], "target": dummy.id})
	var first := 0.0
	for i in 100:
		var before_hp := dummy.hp
		w.tick()
		# Skip the once-a-second attrition tick (the dummy stands in our land).
		if w.tick_count % World.TICK_RATE != 0 and dummy.hp < before_hp:
			first = before_hp - dummy.hp
			break
	check(first > 22.0, "charge blow is stronger than a normal hit (%.1f)" % first)


func test_hero_unique_and_revive() -> void:
	var w := _world()
	_rich(w)
	var city := _city(w, 0)
	w.players[0].age = 3
	check(w.issue({"type": "train", "player": 0, "building": city.id, "unit": "rudolf"}) == "", "train hero")
	check(w.issue({"type": "train", "player": 0, "building": city.id, "unit": "rudolf"}) != "", "only one hero")
	_run(w, 46)
	var heroes := _units(w, 0, "rudolf")
	check(heroes.size() == 1, "hero trained")
	w.kill(heroes[0])
	_run(w, 1)
	check(w.players[0].hero_fallen, "hero fallen")
	check(w.issue({"type": "train", "player": 0, "building": city.id, "unit": "rudolf"}) == "", "revive hero")
	check(is_equal_approx(city.queue[0].time, 60.0), "revival takes 60s")


func test_autocast_heals_allies() -> void:
	var w := _world()
	_rich(w)
	var c := _city(w, 0).pos + Vector2(0, 6 * GameMap.TILE)
	var mender := w.spawn_unit("field_alchemist", 0, c)
	var hurt := w.spawn_unit("grenadier", 0, c + Vector2(40, 0))
	hurt.hp = 30.0
	_run(w, 2)
	check(hurt.hp > 30.0, "mender autocast heal (%.0f)" % hurt.hp)
	w.issue({"type": "autocast", "player": 0, "ids": [mender.id], "ability": "heal", "on": false})
	hurt.hp = 30.0
	_run(w, 4)
	check(hurt.hp == 30.0, "autocast can be switched off")


func _water_world(map_type: String, seed_value := 1234) -> World:
	var w := World.new()
	w.new_game(seed_value, ["monarchy", "covenant"], 0, "normal", map_type)
	w.ais.clear()
	return w


## A free 3x3 shore site inside player 0's borders, or (-1, -1).
func _dock_site(w: World) -> Vector2i:
	w.players[0].knows_map = true
	var c := GameMap.to_tile(_city(w, 0).pos)
	for r in range(2, 12):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var t := c + Vector2i(dx, dy)
				if w.placement_error(0, "docks", t) == "":
					return t
	return Vector2i(-1, -1)


func test_water_maps() -> void:
	for map_type in ["coastal", "islands"]:
		for seed_value in [3, 1234]:
			var w := _water_world(map_type, seed_value)
			var m := w.map
			var sym := true
			for y in m.height:
				for x in m.width:
					if m.terrain[m.idx(Vector2i(x, y))] != m.terrain[m.idx(Vector2i(m.width - 1 - x, m.height - 1 - y))]:
						sym = false
			check(sym, "%s/%d symmetric" % [map_type, seed_value])
			var s0 := GameMap.to_tile(_city(w, 0).pos)
			var s1 := GameMap.to_tile(_city(w, 1).pos)
			var land_path: PackedVector2Array = m.find_path(GameMap.tile_center(s0), s1)
			var connected := not land_path.is_empty() and GameMap.to_tile(land_path[land_path.size() - 1]).distance_to(s1) < 4
			check(connected == (map_type == "coastal"), "%s/%d land link between starts: %s" % [map_type, seed_value, connected])
			w.players[0].res.timber = 999.0
			w.players[0].age = 2
			check(_dock_site(w).x >= 0, "%s/%d docks can be built at home" % [map_type, seed_value])
			var fish := 0
			for e in w.entities.values():
				if e.type_id == "fish":
					fish += 1
			check(fish >= 4, "%s/%d has fish (%d)" % [map_type, seed_value, fish])


func test_air_targeting_and_flight() -> void:
	var w := _water_world("islands")
	var c := _city(w, 0).pos
	var broom := w.spawn_unit("kress_flyer", 0, c + Vector2(0, 5 * GameMap.TILE))
	var reaver := w.spawn_unit("reaver", 1, broom.pos + Vector2(20, 0))
	var bow := w.spawn_unit("bonebow", 1, broom.pos + Vector2(60, 0))
	check(not w.can_target(reaver, broom), "melee can't hit a flyer")
	check(w.can_target(bow, broom), "ranged can hit a flyer")
	var hp := broom.hp
	w.deal_damage(bow, broom)
	var with_bonus := hp - broom.hp
	var expected := 11.0 * DB.damage_mult(DB.units.bonebow.dtype, "air") * 1.5
	check(is_equal_approx(with_bonus, expected), "bonebow +50%% vs air (%.1f, expected %.1f)" % [with_bonus, expected])
	# Flyers cross the strait in a straight line.
	var far := _city(w, 1).pos
	w.issue({"type": "move", "player": 0, "ids": [broom.id], "pos": far})
	_run(w, 40)
	check(broom.pos.distance_to(far) < 2 * GameMap.TILE or not broom.alive, "broom rider flew across the water")


func test_docks_and_fishing() -> void:
	var w := _water_world("coastal")
	_rich(w)
	w.players[0].age = 2
	var site := _dock_site(w)
	check(site.x >= 0, "found a dock site")
	var inland := GameMap.to_tile(_city(w, 0).pos) + Vector2i(-6, -1)
	check(w.placement_error(0, "docks", inland) != "", "docks refused away from water")
	var docks := w.spawn_building("docks", 0, site, true)
	check(w.issue({"type": "train", "player": 0, "building": docks.id, "unit": "skiff"}) == "", "train skiff")
	_run(w, 16)
	var skiffs := _units(w, 0, "skiff")
	check(skiffs.size() == 1 and w.map.is_sailable(GameMap.to_tile(skiffs[0].pos)), "skiff launched on water")
	var fish := w.nearest_resource("herbs", skiffs[0].pos, 60 * GameMap.TILE, 0, "naval")
	check(fish != null, "fish in reach")
	var before: float = w.players[0].res.herbs
	w.issue({"type": "gather", "player": 0, "ids": [skiffs[0].id], "target": fish.id})
	_run(w, 60)
	check(w.players[0].res.herbs > before + 15, "fish landed at the docks (%.0f -> %.0f)" % [before, w.players[0].res.herbs])
	var worker: Entity = _units(w, 0, "settler")[0]
	check(w.issue({"type": "gather", "player": 0, "ids": [worker.id], "target": fish.id}) == "" and worker.orders.is_empty(), "workers can't fish")


func test_transport_crosses_strait() -> void:
	var w := _water_world("islands")
	_rich(w)
	w.players[0].age = 2
	var site := _dock_site(w)
	var docks := w.spawn_building("docks", 0, site, true)
	w.issue({"type": "train", "player": 0, "building": docks.id, "unit": "transport"})
	_run(w, 26)
	var boat: Entity = _units(w, 0, "transport")[0]
	var troops: Array = []
	for i in 4:
		troops.append(w.spawn_unit("grenadier", 0, docks.pos + Vector2(0, -2 * GameMap.TILE)))
	w.issue({"type": "board", "player": 0, "ids": troops.map(func(u): return u.id), "target": boat.id})
	_run(w, 20)
	check(boat.cargo.size() == 4, "4 wardens aboard (%d)" % boat.cargo.size())
	check(troops.all(func(u): return u.inside == boat.id), "passengers are inside")
	var enemy_land := _city(w, 1).pos + Vector2(-8 * GameMap.TILE, -8 * GameMap.TILE)
	w.issue({"type": "unload", "player": 0, "ids": [boat.id], "pos": enemy_land})
	_run(w, 60)
	check(boat.cargo.is_empty(), "cargo unloaded")
	var across := troops.filter(func(u): return u.alive and u.inside < 0 and u.pos.x + u.pos.y > w.map.width * GameMap.TILE)
	check(across.size() == 4, "wardens landed on the enemy island (%d)" % across.size())


func _second_city(w: World) -> Entity:
	var c := GameMap.to_tile(_city(w, 0).pos)
	w.players[0].knows_map = true
	_rich(w)
	var site := _find_free(w, c + Vector2i(18, 4), 4)
	var city := w.spawn_building("residenz", 0, site, true)
	w.tick()
	return city


func test_crown_lands() -> void:
	var w := _world()
	var p = w.players[0]
	check(p.crown_lands == ["austria"], "capital is Austria (%s)" % [p.crown_lands])
	var res := _city(w, 0)
	check(w.issue({"type": "train", "player": 0, "building": res.id, "unit": "grenzer"}).contains("Croatia"), "Grenzer needs Croatia")
	var city := _second_city(w)
	var cap: float = p.gather_cap("gold")
	check(w.issue({"type": "crown_land", "player": 0, "building": city.id, "land": "bohemia"}) == "", "proclaim Bohemia")
	check(p.gather_cap("gold") > cap, "Bohemia raises the Thaler cap")
	check(w.issue({"type": "crown_land", "player": 0, "building": city.id, "land": "croatia"}) != "", "a city is proclaimed once")
	var third := w.spawn_building("residenz", 0, _find_free(w, GameMap.to_tile(city.pos) + Vector2i(14, -4), 4), true)
	check(w.issue({"type": "crown_land", "player": 0, "building": third.id, "land": "bohemia"}) != "", "each land only once")
	check(w.issue({"type": "crown_land", "player": 0, "building": third.id, "land": "croatia"}) == "", "proclaim Croatia")
	check(w.issue({"type": "train", "player": 0, "building": res.id, "unit": "grenzer"}) == "", "Grenzer unlocked")
	check(w.issue({"type": "crown_land", "player": 1, "building": _city(w, 1).id, "land": "galicia"}) != "", "Covenant can't take Monarchy lands")
	check(w.players[1].crown_lands == ["throne"], "Covenant capital is the Umbral Throne")
	w.capture_city(third, 1)
	check(not "croatia" in p.crown_lands, "losing the city loses the land")


func test_grenzer_militia() -> void:
	var w := _world()
	var city := _city(w, 0)
	city.crown_land = "croatia"
	w.refresh_crown_lands(0)
	var g := w.spawn_unit("grenzer", 0, city.pos + Vector2(0, 4 * GameMap.TILE))
	check(g.is_worker() and g.can_attack(), "Grenzer gathers and fights")
	var mine := w.nearest_resource("gold", g.pos, 40 * GameMap.TILE)
	var before: float = w.players[0].res.gold
	w.issue({"type": "gather", "player": 0, "ids": [g.id], "target": mine.id})
	_run(w, 40)
	check(w.players[0].res.gold > before + 10, "Grenzer mined gold")
	var foe := w.spawn_unit("reaver", 1, city.pos + Vector2(4 * GameMap.TILE, 6 * GameMap.TILE))
	var g2 := w.spawn_unit("grenzer", 0, foe.pos + Vector2(-3 * GameMap.TILE, 0))
	w.update_fog()
	_run(w, 3)
	check(foe.hp < foe.max_hp, "idle Grenzer shot an invader")
	var hp := g2.hp
	w.apply_damage(foe, g2, 20.0, "aether")
	check(hp - g2.hp < 20.0, "home guard: less damage inside our borders (%.1f)" % (hp - g2.hp))


func test_standschuetze_high_ground() -> void:
	var w := _world()
	var m := w.map
	var high := Vector2i(-1, -1)
	var low := Vector2i(-1, -1)
	for y in range(5, m.height - 5):
		for x in range(5, m.width - 5):
			var t := Vector2i(x, y)
			if not m.is_walkable(t):
				continue
			for d in [Vector2i(6, 0), Vector2i(0, 6), Vector2i(5, 5)]:
				if m.is_walkable(t + d) and m.elevation(t) > m.elevation(t + d) + 0.15 and high.x < 0:
					high = t
					low = t + d
	check(high.x >= 0, "map has some high ground")
	var s := w.spawn_unit("standschuetze", 0, GameMap.tile_center(high))
	var foe := w.spawn_unit("reaver", 1, GameMap.tile_center(low))
	check(w.has_high_ground(s, foe), "standschütze has the high ground")
	check(not w.has_high_ground(foe, s) or not foe.def.has("passives"), "it's one-way")
	check(w.attack_range(s, foe) > 8.0 * GameMap.TILE, "+2 range from above")
	var hp := foe.hp
	w.deal_damage(s, foe)
	var from_above := hp - foe.hp
	var flat := w.spawn_unit("reaver", 1, GameMap.tile_center(high) + Vector2(20, 0))
	hp = flat.hp
	w.deal_damage(s, flat)
	check(from_above > (hp - flat.hp) * 1.2, "+30%% damage downhill (%.1f vs %.1f)" % [from_above, hp - flat.hp])


func test_war_wagon_fort() -> void:
	var w := _world()
	var c := _city(w, 0).pos + Vector2(0, 7 * GameMap.TILE)
	var wagon := w.spawn_unit("war_wagon", 0, c)
	var troops: Array = []
	for i in 3:
		troops.append(w.spawn_unit("musketeer", 0, c + Vector2(40, i * 12)))
	w.issue({"type": "board", "player": 0, "ids": troops.map(func(u): return u.id), "target": wagon.id})
	_run(w, 3)
	check(wagon.cargo.size() == 3, "3 musketeers in the wagon")
	check(w.issue({"type": "cast", "player": 0, "ids": [wagon.id], "ability": "wagenburg"}) == "", "deploy")
	check(wagon.deployed, "wagon deployed")
	var pos := wagon.pos
	w.issue({"type": "move", "player": 0, "ids": [wagon.id], "pos": pos + Vector2(200, 0)})
	var foe := w.spawn_unit("warden" if DB.units.has("warden") else "grenadier", 1, c + Vector2(4 * GameMap.TILE, 0))
	foe.owner = 1
	w.update_fog()
	_run(w, 2)
	check(wagon.pos == pos, "a deployed wagon doesn't move")
	check(foe.hp <= foe.max_hp - 25.0, "garrison fires out (%.0f dmg)" % (foe.max_hp - foe.hp))
	var hp := wagon.hp
	w.apply_damage(foe, wagon, 50.0, "aether")
	check(hp - wagon.hp < 50.0 * 1.25 * 0.7, "deployed wagon takes 40%% less")
	w.issue({"type": "unload", "player": 0, "ids": [wagon.id], "pos": wagon.pos})
	_run(w, 0.5)
	check(wagon.cargo.is_empty() and troops.all(func(u): return u.inside < 0), "garrison unloaded")


func test_viribus_unitis() -> void:
	var w := _world()
	var c := _city(w, 0).pos + Vector2(0, 7 * GameMap.TILE)
	var a := w.spawn_unit("grenadier", 0, c)
	w.tick()
	check(w.viribus_unitis(a) == 0.0, "one land: no bonus")
	w.spawn_unit("grenzer", 0, c + Vector2(30, 0))
	w.spawn_unit("uhlan", 0, c + Vector2(0, 30))
	w.spawn_unit("war_wagon", 0, c + Vector2(-30, 0))
	w.tick()
	check(is_equal_approx(w.viribus_unitis(a), 0.1), "three fighting lands: +10%% (%.2f)" % w.viribus_unitis(a))
	var r := w.spawn_unit("reaver", 1, c)
	w.tick()
	check(w.viribus_unitis(r) == 0.0, "Covenant doesn't get it")


func _late(w: World, age := 6) -> void:
	for pid in 2:
		_rich(w, pid)
		w.players[pid].res.coal = 9999.0
		w.players[pid].age = age


func test_coal_and_fabrik() -> void:
	var w := _world()
	var seams := 0
	for e in w.entities.values():
		if e.type_id == "coal_seam":
			seams += 1
	check(seams >= 4, "map has coal seams (%d)" % seams)
	_late(w, 4)
	var city := _city(w, 0)
	var fab := w.spawn_building("fabrik", 0, _find_free(w, city.tile + Vector2i(6, 0), 3), true)
	check(w.issue({"type": "train", "player": 0, "building": fab.id, "unit": "steam_walker"}) == "", "train steam walker")
	check(w.issue({"type": "train", "player": 0, "building": fab.id, "unit": "aether_colossus"}).contains("Requires"), "colossus needs age 6")
	var docks_ok := w.issue({"type": "train", "player": 0, "building": fab.id, "unit": "plague_catapult"})
	check(docks_ok != "", "can't train the other faction's units")
	var worker: Entity = _units(w, 0, "settler")[0]
	var seam := w.nearest_resource("coal", worker.pos, 60 * GameMap.TILE)
	var before: float = w.players[0].res.coal
	w.issue({"type": "gather", "player": 0, "ids": [worker.id], "target": seam.id})
	_run(w, 70)
	check(w.players[0].res.coal > before, "settler mined coal")


## Silences a city's defensive fire so a test only sees the units it set up.
func _quiet_city(w: World, pid: int) -> void:
	var city := _city(w, pid)
	city.def = city.def.duplicate()
	city.def.damage = 0


func test_siege_setup_and_clouds() -> void:
	var w := _world()
	_quiet_city(w, 0)
	var c := _city(w, 0).pos + Vector2(0, 6 * GameMap.TILE)
	var cat := w.spawn_unit("plague_catapult", 1, c)
	var near := w.spawn_unit("grenadier", 0, c + Vector2(2 * GameMap.TILE, 0))
	check(not w.issue({"type": "attack", "player": 1, "ids": [cat.id], "target": near.id}) != "", "order given")
	_run(w, 1)
	check(near.hp == near.max_hp, "no firing inside minimum range")
	# A passive target, so it doesn't charge into the catapult's minimum range.
	near.def = near.def.duplicate()
	near.def.damage = 0
	near.orders.clear()
	near.pos = c + Vector2(6 * GameMap.TILE, 0)
	near.prev_pos = near.pos
	w.update_fog()
	w.issue({"type": "attack", "player": 1, "ids": [cat.id], "target": near.id})
	_run(w, 0.5)
	check(near.hp == near.max_hp, "still setting up after half a second")
	_run(w, 3)
	check(near.hp < near.max_hp, "fires once set up")
	check(not w.areas.is_empty(), "left a poison cloud")
	var hp := near.hp
	cat.orders.clear()
	_run(w, 2)
	check(near.hp < hp or not near.alive, "the cloud keeps hurting")


func test_air_rifle_magazine() -> void:
	var w := _world()
	_quiet_city(w, 0)
	var c := _city(w, 0).pos + Vector2(0, 6 * GameMap.TILE)
	var kj := w.spawn_unit("kaiserjaeger", 0, c)
	var dummy := w.spawn_unit("bone_colossus", 1, c + Vector2(5 * GameMap.TILE, 0))
	dummy.def = dummy.def.duplicate()
	dummy.def.damage = 0
	w.update_fog()
	var shots := 0
	w.issue({"type": "attack", "player": 0, "ids": [kj.id], "target": dummy.id})
	for i in 20 * 5:
		var hp := dummy.hp
		w.tick()
		if dummy.hp < hp and w.tick_count % World.TICK_RATE != 0:
			shots += 1
	check(shots == 6, "6 shots then reload within 5s (%d)" % shots)


func test_aethership_carries_troops() -> void:
	var w := _world()
	var c := _city(w, 0).pos + Vector2(0, 6 * GameMap.TILE)
	var ship := w.spawn_unit("aethership", 0, c)
	var troops: Array = []
	for i in 3:
		troops.append(w.spawn_unit("grenadier", 0, c + Vector2(30, i * 15)))
	w.issue({"type": "board", "player": 0, "ids": troops.map(func(u): return u.id), "target": ship.id})
	_run(w, 3)
	check(ship.cargo.size() == 3, "3 aboard the airship (%d)" % ship.cargo.size())
	var dest := c + Vector2(12 * GameMap.TILE, 4 * GameMap.TILE)
	w.issue({"type": "unload", "player": 0, "ids": [ship.id], "pos": dest})
	_run(w, 12)
	check(ship.cargo.is_empty() and troops.all(func(u): return u.inside < 0 and u.pos.distance_to(dest) < 4 * GameMap.TILE), "dropped off at the destination")


func test_ram_hook_frost() -> void:
	var w := _water_world("coastal")
	_late(w, 6)
	var c := _city(w, 0).pos
	var water := GameMap.tile_center(w.map.nearest_walkable(GameMap.to_tile(c), 30, "naval"))
	var iron := w.spawn_unit("ironclad", 0, water)
	var foe_ship := w.spawn_unit("ghost_ship", 1, water + Vector2(20, 0))
	var foe_land := w.spawn_unit("grenadier", 1, c + Vector2(0, 5 * GameMap.TILE))
	check(w.issue({"type": "cast", "player": 0, "ids": [iron.id], "ability": "ram", "target": foe_land.id}).contains("ship"), "ram only hits ships")
	var hp := foe_ship.hp
	w.issue({"type": "cast", "player": 0, "ids": [iron.id], "ability": "ram", "target": foe_ship.id})
	_run(w, 1)
	check(hp - foe_ship.hp > 100.0, "ram smashed the ship (%.0f)" % (hp - foe_ship.hp))
	var abom := w.spawn_unit("abomination", 1, c + Vector2(0, 8 * GameMap.TILE))
	var victim := w.spawn_unit("grenadier", 0, abom.pos + Vector2(5 * GameMap.TILE, 0))
	w.update_fog()
	check(w.issue({"type": "cast", "player": 1, "ids": [abom.id], "ability": "hook", "target": victim.id}) == "", "hook")
	_run(w, 0.5)
	check(victim.pos.distance_to(abom.pos) < 1.5 * GameMap.TILE, "victim dragged in")
	var lich := w.spawn_unit("lich", 1, victim.pos + Vector2(20, 0))
	check(w.issue({"type": "cast", "player": 1, "ids": [lich.id], "ability": "frost_nova"}) == "", "frost nova")
	check(victim.effects.any(func(fx): return fx.type == "slow"), "victim slowed")


func test_ghost_ship_stealth() -> void:
	var w := _water_world("coastal")
	w.players[0].tracks_fog = true
	var c := _city(w, 0).pos
	var water := GameMap.tile_center(w.map.nearest_walkable(GameMap.to_tile(Vector2(w.map.width, w.map.height) * 0.5 * GameMap.TILE), 30, "naval"))
	var ghost := w.spawn_unit("ghost_ship", 1, water)
	for p in w.players:
		p.vis.fill(2)
	w.tick()
	check(w.is_visible_to(0, ghost), "visible while it hasn't settled")
	_run(w, 4)
	check(not w.is_visible_to(0, ghost), "hidden after keeping still")
	w.spawn_unit("warship", 0, water + Vector2(40, 0))
	w.tick()
	check(w.is_visible_to(0, ghost), "spotted by a nearby ship")


func test_colossus_limit_and_auras() -> void:
	var w := _world()
	_late(w, 6)
	var city := _city(w, 0)
	var fab := w.spawn_building("fabrik", 0, _find_free(w, city.tile + Vector2i(6, 0), 3), true)
	check(w.issue({"type": "train", "player": 0, "building": fab.id, "unit": "aether_colossus"}) == "", "train colossus")
	check(w.issue({"type": "train", "player": 0, "building": fab.id, "unit": "aether_colossus"}).contains("Only"), "only one colossus")
	var c := city.pos + Vector2(0, 7 * GameMap.TILE)
	var g := w.spawn_unit("grenadier", 0, c)
	var foe := w.spawn_unit("reaver", 1, c + Vector2(20, 0))
	w.tick()
	var hp := foe.hp
	w.deal_damage(g, foe)
	var plain := hp - foe.hp
	w.spawn_unit("aether_colossus", 0, c + Vector2(0, 40))
	w.tick()
	hp = foe.hp
	w.deal_damage(g, foe)
	check(hp - foe.hp > plain * 1.1, "colossus aura: +15%% (%.1f vs %.1f)" % [hp - foe.hp, plain])
	w.spawn_unit("bone_colossus", 1, c + Vector2(0, -40))
	w.tick()
	hp = foe.hp
	w.deal_damage(g, foe)
	check(hp - foe.hp < plain * 1.05, "bone colossus fear cancels it (%.1f)" % (hp - foe.hp))


func test_dark_pacts() -> void:
	var w := _world()
	_rich(w, 1)
	w.players[1].knows_map = true
	var c := GameMap.to_tile(_city(w, 1).pos)
	var site := _find_free(w, c + Vector2i(-18, -4), 4)
	var city := w.spawn_building("citadel", 1, site, true)
	w.tick()
	check(w.issue({"type": "crown_land", "player": 1, "building": city.id, "land": "croatia"}) != "", "no crown lands for the Covenant")
	check(w.issue({"type": "crown_land", "player": 1, "building": city.id, "land": "blood"}) == "", "swear the Blood Pact")
	var vamp := w.spawn_unit("vampire", 1, city.pos + Vector2(0, 3 * GameMap.TILE))
	var foe := w.spawn_unit("grenadier", 0, vamp.pos + Vector2(20, 0))
	vamp.hp = 60.0
	w.deal_damage(vamp, foe)
	check(vamp.hp > 60.0, "vampire drinks blood (%.0f)" % vamp.hp)
	check(w.players[1].mod("damage") >= 0.05, "blood pact +5%% damage")


func test_hero_choice() -> void:
	var w := _world()
	_late(w, 3)
	var city := _city(w, 0)
	check(w.issue({"type": "train", "player": 0, "building": city.id, "unit": "maria_theresa"}) == "", "choose Maria Theresa")
	check(w.issue({"type": "cancel_train", "player": 0, "building": city.id, "index": 0}) == "", "cancel")
	check(w.issue({"type": "train", "player": 0, "building": city.id, "unit": "prince_eugene"}).contains("Maria Theresa"), "the choice sticks")
	var mt := w.spawn_unit("maria_theresa", 0, city.pos + Vector2(0, 4 * GameMap.TILE))
	w.tick()
	var near := w.harvest_take(0, "gold", 1.0, mt.pos)
	var far := w.harvest_take(0, "gold", 1.0, mt.pos + Vector2(40 * GameMap.TILE, 0))
	check(near > far * 1.2, "workers near her gather faster")
	var gold: float = w.players[0].res.gold
	w.issue({"type": "cast", "player": 0, "ids": [mt.id], "ability": "theresian_reform"})
	check(w.players[0].res.gold > gold + 100.0, "Theresian Reform fills the treasury")


## A private copy of the rules with short victory timers.
func _quick_victories(w: World) -> void:
	w.rules = w.rules.duplicate(true)
	w.rules.victory.territory_hold = 2
	w.rules.victory.wonder_hold = 2
	w.rules.victory.relic_hold = 2


func test_wonders() -> void:
	var w := _world()
	_late(w, 6)
	var city := _city(w, 0)
	var site := _valid_site(w, 0, "orloj", city.tile)
	check(site.x >= 0, "can place the Orloj")
	var orloj := w.spawn_building("orloj", 0, site, false)
	var other := _valid_site(w, 0, "pummerin", city.tile)
	check(w.placement_error(0, "orloj", other).contains("already"), "one of each wonder")
	w.advance_construction(orloj, 999.0)
	check(w.players[0].mod("research_speed") > 0.0, "Orloj speeds research")
	var lib := w.spawn_building("library", 0, _find_free(w, city.tile + Vector2i(6, 0), 3), true)
	w.issue({"type": "research", "player": 0, "building": lib.id, "branch": "charms"})
	check(lib.queue[0].time < 30.0, "research takes less time (%.1f)" % lib.queue[0].time)
	var sem := w.spawn_building("semmering", 0, _find_free(w, city.tile + Vector2i(7, 7), 4), true)
	w.refresh_crown_lands(0)
	var g := w.spawn_unit("grenadier", 0, city.pos + Vector2(0, 5 * GameMap.TILE))
	_run(w, 1.1)
	check(g.speed_mult > 1.2, "Semmering: faster at home (%.2f)" % g.speed_mult)
	w.kill(sem)
	check(w.players[0].mod("rail_speed") == 0.0, "losing the wonder loses its bonus")


func test_territory_and_wonder_victory() -> void:
	var w := _world()
	_quick_victories(w)
	w.rules.victory.territory_share = 0.01
	_run(w, 4)
	check(w.winner == 0 or w.winner == 1, "someone holding 1%% of the land wins")
	var w2 := _world()
	_quick_victories(w2)
	_late(w2, 6)
	var city := _city(w2, 0)
	for i in 3:
		var id: String = ["orloj", "pummerin", "semmering"][i]
		w2.spawn_building(id, 0, _find_free(w2, city.tile + Vector2i(-10 + i * 6, 8), 4), true)
	_run(w2, 4)
	check(w2.winner == 0, "three wonders held: victory (winner %d)" % w2.winner)


func test_aeiou_relic_victory() -> void:
	var w := _world()
	_quick_victories(w)
	_late(w, 5)
	w._spawn_relics()
	var relics: Array = w.entities.values().filter(func(e): return e.def.get("relic", false))
	check(relics.size() == 5, "five relics on the map (%d)" % relics.size())
	var city := _city(w, 0)
	var treasury := w.spawn_building("hofburg_treasury", 0, _find_free(w, city.tile + Vector2i(0, 7), 4), true)
	var worker: Entity = _units(w, 0, "settler")[0]
	check(w.issue({"type": "pickup", "player": 0, "ids": [worker.id], "target": relics[0].id}) != "", "workers don't carry relics")
	var carriers: Array = []
	for r in relics:
		var g := w.spawn_unit("grenadier", 0, r.pos + Vector2(20, 0))
		carriers.append(g)
		w.issue({"type": "pickup", "player": 0, "ids": [g.id], "target": r.id})
	_run(w, 1)
	check(carriers.all(func(g): return g.relic >= 0), "all five picked up")
	w.kill(carriers[0])
	check(relics[0].carried_by == -1, "a slain carrier drops the relic")
	var g0 := w.spawn_unit("grenadier", 0, relics[0].pos)
	carriers[0] = g0
	w.issue({"type": "pickup", "player": 0, "ids": [g0.id], "target": relics[0].id})
	_run(w, 1)
	for g in carriers:
		g.pos = treasury.pos + Vector2(0, 3 * GameMap.TILE)
		w.issue({"type": "store", "player": 0, "ids": [g.id], "target": treasury.id})
	_run(w, 6)
	check(w.relics_stored(0) == 5, "five relics in the treasury (%d)" % w.relics_stored(0))
	check(w.winner == 0, "AEIOU victory (winner %d)" % w.winner)


## First site near `around` where `player` may build `type_id`, or (-1, -1).
func _valid_site(w: World, player: int, type_id: String, around: Vector2i) -> Vector2i:
	for r in range(2, 14):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var t := around + Vector2i(dx, dy)
				if w.placement_error(player, type_id, t) == "":
					return t
	return Vector2i(-1, -1)


func test_loyalty_and_revolt() -> void:
	var w := _world()
	var p = w.players[0]
	check(w.players.size() == 3 and w.players[2].is_rebels, "a Rebels side exists")
	var cap := _city(w, 0)
	_run(w, 1)
	check(cap.loyalty == 100.0, "the capital is always loyal")
	# A far-flung, freshly conquered city with an enemy army in its borders.
	var far := w.spawn_building("residenz", 0, _find_free(w, GameMap.to_tile(_city(w, 1).pos) + Vector2i(-14, -14), 4), true)
	far.loyalty = 60.0
	far.captured_tick = w.tick_count
	w.territory.dirty = true
	_run(w, 1)
	check(far.loyalty_target < 60.0, "distance and conquest lower its target (%.0f)" % far.loyalty_target)
	var labels: Array = far.loyalty_factors.map(func(f): return f[0])
	check("Far from the capital" in labels and "Recently conquered" in labels, "factors explained: %s" % [labels])
	# Passive invaders: they drain loyalty by standing there (no assault on the city).
	for i in 6:
		var r := w.spawn_unit("reaver", 1, far.pos + Vector2(0, 4 * GameMap.TILE))
		r.def = r.def.duplicate()
		r.def.damage = 0.001
		r.def.sight = 0.5
	_run(w, 25)
	check(far.owner == w.rebels, "the city revolted (owner %d, loyalty %.0f)" % [far.owner, far.loyalty])
	check(_units(w, w.rebels, "rebel_militia").size() >= 1, "rebel militia raised")
	# Garrisons help.
	var w2 := _world()
	var c2 := w2.spawn_building("residenz", 0, _find_free(w2, GameMap.to_tile(_city(w2, 0).pos) + Vector2i(16, 4), 4), true)
	_run(w2, 1)
	var bare: float = c2.loyalty_target
	for i in 4:
		w2.spawn_unit("grenadier", 0, c2.pos + Vector2(0, 3 * GameMap.TILE))
	_run(w2, 1)
	check(c2.loyalty_target > bare, "a garrison raises loyalty (%.0f -> %.0f)" % [bare, c2.loyalty_target])


func test_charters_and_tithes() -> void:
	var w := _world()
	_late(w, 5)
	var c := w.spawn_building("residenz", 0, _find_free(w, GameMap.to_tile(_city(w, 0).pos) + Vector2i(16, 4), 4), true)
	c.crown_land = "bohemia"
	w.refresh_crown_lands(0)
	var cap_plain: float = w.players[0].gather_cap("gold")
	check(w.issue({"type": "charter", "player": 0, "building": _city(w, 0).id}) != "", "no charter for the capital")
	check(w.issue({"type": "charter", "player": 0, "building": c.id}) == "", "grant a charter")
	check(w.players[0].gather_cap("gold") > cap_plain, "charter boosts the land bonus")
	c.loyalty = 10.0
	_run(w, 1)
	check(c.loyalty >= 50.0, "charter floor holds loyalty at 50")
	check(is_equal_approx(w.deposit_mult(c), 0.8), "chartered city passes on 80%%")
	check(w.issue({"type": "charter", "player": 0, "building": c.id, "on": false}).contains("soon"), "can't revoke straight away")
	# Covenant: Blood Tithe.
	var cov := _city(w, 1)
	check(w.issue({"type": "charter", "player": 1, "building": cov.id}) != "", "the Covenant grants no charters")
	var victim := w.spawn_unit("reaver", 1, cov.pos + Vector2(0, 3 * GameMap.TILE))
	cov.loyalty = 30.0
	check(w.issue({"type": "tithe", "player": 1, "building": cov.id}) == "", "pay the blood tithe")
	check(not victim.alive and cov.loyalty >= 55.0, "a soldier sacrificed, dread restored (%.0f)" % cov.loyalty)
	check(w.issue({"type": "tithe", "player": 1, "building": cov.id}) != "", "tithe has a cooldown")


## Save mid-game, load into a fresh world, and both worlds play on identically.
func test_save_load_round_trip() -> void:
	const SaveGame = preload("res://sim/save_game.gd")
	var w := World.new()
	w.new_game(77, ["monarchy", "covenant"], 0, "normal", "coastal")
	_run(w, 120)
	check(SaveGame.save(w, {"me": 0, "scenario": ""}, "test") == "", "saved")
	var meta := SaveGame.read_meta(SaveGame.slot_path("test"))
	check(meta.get("minutes", -1) == 2, "meta records 2 minutes")
	var w2 := World.new()
	var view := SaveGame.load_into(w2, SaveGame.slot_path("test"))
	check(view.get("me", -1) == 0, "view state restored")
	check(w2.entities.size() == w.entities.values().filter(func(e): return e.alive).size(), "same entities")
	check(w2.tick_count == w.tick_count and w2.players[0].res.gold == w.players[0].res.gold, "same clock and treasury")
	check(w2.ais.size() == w.ais.size(), "AI restored")
	_run(w, 60)
	_run(w2, 60)
	var summary := func(world): return [world.tick_count, world.entities.size(), roundi(world.players[0].res.gold), roundi(world.players[1].res.herbs)]
	check(summary.call(w) == summary.call(w2), "both worlds play on the same (%s vs %s)" % [summary.call(w), summary.call(w2)])
	DirAccess.remove_absolute(SaveGame.slot_path("test"))


func _scenario_world(id: String) -> World:
	const Scenario = preload("res://scenarios/scenario.gd")
	var w := World.new()
	Scenario.create(id).setup(w)
	return w


## Every scenario builds its world and runs two minutes without errors, posting objectives.
func test_scenarios_run() -> void:
	for id in ["tutorial", "m1_sarajevo", "m2_tomb", "m3_federation", "m4_vienna", "m5_empress", "m6_viribus"]:
		var w := _scenario_world(id)
		_run(w, 120)
		check(w.scenario.get("id", "") == id, "%s: state recorded" % id)
		check(not w.scenario.objectives.is_empty(), "%s: has objectives" % id)
		if id != "m1_sarajevo":
			check(w.winner < 0, "%s: still undecided after 2 minutes" % id)


## Viribus Unitis: the Covenant can't win by hoarding relics; the player holding
## them all opens the storm on Buda, and Rudolf's fall wins the campaign.
func test_viribus_relics() -> void:
	for owner in [1, 0]:
		var w := _scenario_world("m6_viribus")
		w.ais.clear()
		var city = w.get_entity(w.players[owner].capital_id)
		for e in w.entities.values():
			if e.alive and e.def.get("relic", false):
				e.inside = city.id
		_run(w, 200)
		if owner == 1:
			check(w.winner < 0, "viribus: foe hoarding all relics must not win")
		else:
			check(w.winner < 0 and w.scenario.step == 1, "viribus: holding all five relics opens the storm on Buda")
			var rudolf = w.get_entity(int(w.scenario.get("boss", -1)))
			check(rudolf != null and rudolf.alive, "viribus: Rudolf takes the field")
			if rudolf:
				w.kill(rudolf)
			_run(w, 2)
			check(w.winner == 0, "viribus: Rudolf's fall wins (winner %d)" % w.winner)


## The new chapters move through their stages when their goals are met.
func test_campaign_chapters() -> void:
	# 2. The Empty Tomb: Houdini at the crypt brings the column and the Grave Engine.
	var w := _scenario_world("m2_tomb")
	w.get_entity(int(w.scenario.flags.houdini)).pos = w.scenario.flags.crypt
	_run(w, 2)
	check(w.scenario.step == 1 and w.get_entity(int(w.scenario.get("boss", -1))) != null, "tomb: the crypt reveals the Grave Engine")
	w.kill(w.get_entity(int(w.scenario.boss)))
	_run(w, 2)
	check(w.winner == 0, "tomb: the Grave Engine's fall wins (winner %d)" % w.winner)
	# 3. The Federation: Hungary secedes on a timer; Tesla joins.
	w = _scenario_world("m3_federation")
	w.ais.clear()
	_run(w, 545)
	check(w.hungary_risen and w.scenario.flags.has("stronghold"), "federation: Hungary secedes")
	check(w.type_count(0, "tesla") == 1, "federation: Tesla comes home")
	check(w.winner < 0, "federation: not won without crown lands")
	# 4. Vienna: the Iron Emperor marches out and the Hungarians join the waves.
	w = _scenario_world("m4_vienna")
	_run(w, 150)
	var hungarians := 0
	for e in w.entities.values():
		if e.alive and e.owner == w.rebels and e.kind == Entity.UNIT:
			hungarians += 1
	check(hungarians > 0, "vienna: Hungarians attack from the flank with the second wave")
	_run(w, 130)
	check(w.type_count(0, "iron_emperor") == 1, "vienna: the Iron Emperor marches out")
	# 5. The Empress: breaking circles weakens her; her fall wins.
	w = _scenario_world("m5_empress")
	for pt in w.scenario.points:
		pt.owner = 0
	_run(w, 2)
	var empress = w.get_entity(int(w.scenario.get("boss", -1)))
	check(empress != null and empress.hp < empress.max_hp * 0.6, "empress: rises weakened with every circle broken")
	if empress:
		w.kill(empress)
	_run(w, 2)
	check(w.winner == 0, "empress: her fall wins (winner %d)" % w.winner)


## The convoy marches to the Town Hall; the mission must end one way or the other.
func test_sarajevo_playthrough() -> void:
	var w := _scenario_world("m1_sarajevo")
	var town = w.get_entity(w.players[0].capital_id)
	var ids: Array = []
	for e in w.entities.values():
		if e.owner == 0 and e.kind == Entity.UNIT and not e.is_worker():
			ids.append(e.id)
	var duke_id := int(w.scenario.flags.duke)
	var t := 0
	while w.winner < 0 and t < 600:
		# Escort first, then the Archduke follows a little behind, as a player would.
		var goal: Vector2 = w.scenario.get("marker", town.pos)
		var vip = w.get_entity(duke_id)
		var threat = w.find_enemy_near(vip, 9.0 * World.TILE) if vip else null
		var escort := ids.filter(func(i): return i != duke_id)
		if threat:
			# Protect the Archduke: the escort turns on whoever is closest to him.
			w.issue({"type": "attack", "player": 0, "ids": escort, "target": threat.id})
			w.issue({"type": "move", "player": 0, "ids": [duke_id], "pos": vip.pos + (vip.pos - goal).normalized() * 2.0 * World.TILE})
		else:
			w.issue({"type": "attack_move", "player": 0, "ids": escort, "pos": goal})
			if vip:
				w.issue({"type": "move", "player": 0, "ids": [duke_id], "pos": goal})
		_run(w, 2)
		t += 2
	check(w.winner >= 0, "the mission is decided within 10 minutes (t=%d)" % t)
	check(int(w.scenario.flags.sprung) >= 2, "ambushes were sprung (%d)" % int(w.scenario.flags.sprung))
	var duke = w.get_entity(duke_id)
	print("    sarajevo: winner %d after %ds, stops %d, ambushes %d, archduke hp %d, escort left %d/%d" % [w.winner, t,
			int(w.scenario.flags.stop), int(w.scenario.flags.sprung), duke.hp if duke else 0, _scenario_alive(w, ids) - 1, ids.size() - 1])


func test_scenario_survives_save() -> void:
	const SaveGame = preload("res://sim/save_game.gd")
	const Scenario = preload("res://scenarios/scenario.gd")
	var w := _scenario_world("m4_vienna")
	_run(w, 100)
	SaveGame.save(w, {"me": 0, "scenario": "m4_vienna"}, "test_sc")
	var w2 := World.new()
	SaveGame.load_into(w2, SaveGame.slot_path("test_sc"))
	w2.scenario_logic = Scenario.create(w2.scenario.id)
	check(int(w2.scenario.flags.wave) == int(w.scenario.flags.wave), "wave counter restored")
	_run(w, 60)
	_run(w2, 60)
	check(int(w2.scenario.flags.wave) == int(w.scenario.flags.wave) and w2.entities.size() == w.entities.size(), "scenario continues identically")
	DirAccess.remove_absolute(SaveGame.slot_path("test_sc"))


func _scenario_alive(w: World, ids: Array) -> int:
	var n := 0
	for i in ids:
		var e := w.get_entity(i)
		if e and e.alive:
			n += 1
	return n


## Plays the tutorial through its steps with real commands, as a new player would.
func test_tutorial_walkthrough() -> void:
	var w := _scenario_world("tutorial")
	var city = w.get_entity(w.players[0].capital_id)
	_run(w, 2)
	var workers := _units(w, 0).filter(func(e): return e.is_worker())
	for wk in workers:
		var res = w.nearest_resource("gold", wk.pos, 40.0 * GameMap.TILE)
		w.issue({"type": "gather", "player": 0, "ids": [wk.id], "target": res.id})
	_run(w, 3)
	check(int(w.scenario.step) == 1, "gathering completes step 1 (step %d)" % int(w.scenario.step))
	_run(w, 2)
	var spot := _valid_site(w, 0, "kaserne", city.tile + Vector2i(3, 3))
	check(w.issue({"type": "place", "player": 0, "ids": [workers[0].id, workers[1].id], "building": "kaserne", "tile": spot}) == "", "Kaserne placed with the tutorial's top-up")
	_run(w, 90)
	check(int(w.scenario.step) == 2, "the Kaserne completes step 2 (step %d)" % int(w.scenario.step))
	var kaserne = _units(w, 0, "kaserne")
	for e in w.entities.values():
		if e.type_id == "kaserne" and e.owner == 0:
			kaserne = e
	for i in 3:
		w.issue({"type": "train", "player": 0, "building": kaserne.id, "unit": "grenadier"})
	_run(w, 70)
	check(int(w.scenario.step) == 3, "three soldiers complete step 3 (step %d)" % int(w.scenario.step))
	_run(w, 2)
	check(w.issue({"type": "advance_age", "player": 0, "building": city.id}) == "", "advance age affordable")
	_run(w, 50)
	check(int(w.scenario.step) == 4, "the new age completes step 4 (step %d)" % int(w.scenario.step))
	_run(w, 2)
	var army := _units(w, 0).filter(func(e): return not e.is_worker()).map(func(e): return e.id)
	check(army.size() >= 11, "the levy arrived (%d soldiers)" % army.size())
	var citadel = w.get_entity(w.players[1].capital_id)
	w.issue({"type": "attack", "player": 0, "ids": army, "target": citadel.id})
	var t := 0
	while w.winner < 0 and t < 240:
		_run(w, 5)
		t += 5
		if OS.has_environment("ROM_DEBUG") and t % 20 == 0:
			print("  t ", t, " citadel ", citadel.hp, " owner ", citadel.owner, " alive ", citadel.alive, " army ", _scenario_alive(w, army), " dist ", int(w.get_entity(army[0]).pos.distance_to(citadel.pos) / 32) if w.get_entity(army[0]) else -1, " cities1 ", w.city_count(1, false))
	check(w.winner == 0, "capturing the citadel wins the tutorial (winner %d after %ds)" % [w.winner, t])


func test_skirmish_options() -> void:
	var w := World.new()
	w.new_game(5, ["monarchy", "covenant"], 0, "normal", "inland",
			{"map_size": "large", "start_age": 3, "resources": "deathmatch", "victories": {"wonders": false}, "explored": true})
	check(w.map.width == 128, "large map is 128 wide (%d)" % w.map.width)
	check(w.players[0].age == 3 and w.players[1].age == 3, "both start in age 3")
	check(w.players[0].res.gold >= 10000.0, "deathmatch treasury (%d)" % w.players[0].res.gold)
	check(not w.rules.victory.enabled.wonders and w.rules.victory.enabled.relics, "wonder victory off, relics on")
	check(DB.rules.victory.enabled.wonders, "options never leak into the shared rules")
	check(w.players[0].vis[0] > 0, "map starts explored")
	_run(w, 30)
	check(w.winner < 0, "plays on")


## Each completed building claims land, so building near the edge pushes the border out.
func test_buildings_expand_borders() -> void:
	var w := _world()
	_run(w, 1)
	var before := roundi(w.territory.share(0) * w.territory.grid.size())
	var city = w.get_entity(w.players[0].capital_id)
	# A dwelling just inside the edge of the city's 8-tile radius.
	var spot := _find_free(w, city.tile + Vector2i(8, 1), 2)
	check(w.territory_owner(spot) == 0, "the site is just inside the border")
	w.spawn_building("dwelling", 0, spot, true)
	_run(w, 1)
	var after := roundi(w.territory.share(0) * w.territory.grid.size())
	check(after > before, "the border grew (%d -> %d tiles)" % [before, after])


## A soldier picks up a relic and stores it in the city (no wonder needed).
func test_relic_to_city() -> void:
	var w := _world()
	var city = w.get_entity(w.players[0].capital_id)
	var relic_id: String = DB.resources.keys().filter(func(k): return DB.resources[k].get("relic", false))[0]
	var spot := _find_free(w, city.tile + Vector2i(10, 0), 1)
	var relic := w.spawn_resource(relic_id, spot)
	var soldier := w.spawn_unit("grenadier", 0, GameMap.tile_center(spot + Vector2i(0, 2)))
	w.issue({"type": "pickup", "player": 0, "ids": [soldier.id], "target": relic.id})
	_run(w, 10)
	check(soldier.relic == relic.id, "picked up")
	check(w.issue({"type": "store", "player": 0, "ids": [soldier.id], "target": city.id}) == "", "city accepts relics")
	_run(w, 15)
	check(w.relics_stored(0) == 1, "stored in the city (%d)" % w.relics_stored(0))


## Kaserne drill makes grenadiers stronger but not Jaeger (trained at the range).
func test_military_upgrades_are_scoped() -> void:
	var w := _world()
	var gren := w.spawn_unit("grenadier", 0, Vector2(100, 100))
	var jaeger := w.spawn_unit("jaeger", 0, Vector2(140, 100))
	var g0 := gren.max_hp
	var j0 := jaeger.max_hp
	var p = w.players[0]
	p.techs["drill"] = 1
	Research.recompute_mods(p)
	w._refresh_max_hp(gren)
	w._refresh_max_hp(jaeger)
	check(gren.max_hp > g0, "grenadier HP up (%d -> %d)" % [g0, gren.max_hp])
	check(is_equal_approx(jaeger.max_hp, j0), "jaeger unchanged")
	check(not "transfiguration" in DB.buildings.library.research, "library no longer upgrades soldiers")
	check("drill" in DB.buildings.kaserne.research, "kaserne offers drill")


## Hold the Line, Volley, Frenzy and Wither do what their descriptions say.
func test_roster_passives() -> void:
	var w := _world()
	var c := Vector2(30, 30) * GameMap.TILE
	var reaver := w.spawn_unit("reaver", 1, c + Vector2(400, 0))
	var gren := w.spawn_unit("grenadier", 0, c)
	_run(w, 2)
	var hp0 := gren.hp
	w.apply_damage(reaver, gren, 20.0, "blade")
	var braced := hp0 - gren.hp
	gren.stand = 0.0
	hp0 = gren.hp
	w.apply_damage(reaver, gren, 20.0, "blade")
	check(braced < hp0 - gren.hp, "a standing Grenadier takes less (%.1f vs %.1f)" % [braced, hp0 - gren.hp])
	# Volley: a lone musketeer vs one of five.
	var target := w.spawn_unit("grave_brute", 1, c + Vector2(0, 300))
	target.max_hp = 99999.0
	target.hp = 99999.0
	var lone := w.spawn_unit("musketeer", 0, c + Vector2(-600, 300))
	_run(w, 0.05)
	var before := target.hp
	w.deal_damage(lone, target)
	var single := before - target.hp
	for i in 4:
		w.spawn_unit("musketeer", 0, lone.pos + Vector2(20 * (i + 1), 0))
	_run(w, 0.05)
	before = target.hp
	w.deal_damage(lone, target)
	check(before - target.hp > single * 1.2, "Volley bonus (%.1f vs %.1f)" % [before - target.hp, single])
	# Frenzy: a wounded Reaver hits harder.
	before = target.hp
	w.deal_damage(reaver, target)
	var healthy := before - target.hp
	reaver.hp = reaver.max_hp * 0.3
	before = target.hp
	w.deal_damage(reaver, target)
	check(before - target.hp > healthy * 1.2, "Frenzy bonus")
	# Wither slows.
	var caller := w.spawn_unit("hexcaster", 1, c + Vector2(200, 200))
	w.deal_damage(caller, gren)
	check(Abilities.effect_amount(gren, "slow") > 0.0, "Wither slows")


## Steel armour, the steam tank's Full Steam, and the Plague Balloon's cloud.
func test_machines_and_boost() -> void:
	var w := _world()
	_rich(w)
	_rich(w, 1)
	var c := Vector2(30, 30) * GameMap.TILE
	var tank := w.spawn_unit("landpanzer", 0, c)
	var musk := w.spawn_unit("musketeer", 1, c + Vector2(150, 0))
	var hp0 := tank.hp
	w.apply_damage(musk, tank, 20.0, "ballistic")
	check(hp0 - tank.hp < 10.0, "steel shrugs off musket fire (%.1f)" % (hp0 - tank.hp))
	check(w.issue({"type": "cast", "player": 0, "ids": [tank.id], "ability": "full_steam", "pos": tank.pos}) == "", "Full Steam ordered")
	_run(w, 1)
	check(Abilities.effect_amount(tank, "boost") > 0.0 and Abilities.effect_amount(tank, "haste") > 0.0, "boosted")
	var balloon := w.spawn_unit("bat_swarm", 1, c + Vector2(0, 200))
	var n := w.areas.size()
	check(w.issue({"type": "cast", "player": 1, "ids": [balloon.id], "ability": "plague_drop", "pos": c}) == "", "Plague Drop ordered")
	_run(w, 2)
	check(w.areas.size() > n, "a plague cloud lingers")
