extends SceneTree
## Bot playthrough of the campaign's boss fights: every soldier attack-moves on the
## boss (or the objective). Prints how each fight ends. Not part of run_tests.
##   tools/godot --headless --path . -s tests/campaign_bot.gd

const World = preload("res://sim/world.gd")
const Entity = preload("res://sim/entity.gd")
const Scenario = preload("res://scenarios/scenario.gd")


func _initialize() -> void:
	_tomb()
	_empress(0)
	_empress(3)
	_buda()
	_vienna()
	_rosabelle()
	_black_thursday()
	_ice_crown()
	_long_winter()
	quit()


func _world(id: String) -> World:
	var w := World.new()
	Scenario.create(id).setup(w)
	return w


func _army(w: World) -> Array:
	var ids: Array = []
	for e in w.entities.values():
		if e.alive and e.owner == 0 and e.kind == Entity.UNIT and e.can_attack() and not e.is_worker():
			ids.append(e.id)
	return ids


func _fight(w: World, label: String, limit := 900) -> void:
	var t := 0
	while w.winner < 0 and t < limit:
		var b = w.get_entity(int(w.scenario.get("boss", -1)))
		var goal: Vector2 = b.pos if b and b.alive else w.scenario.get("marker", Vector2.ZERO)
		w.issue({"type": "attack_move", "player": 0, "ids": _army(w), "pos": goal})
		for i in 5 * World.TICK_RATE:
			w.tick()
		t += 5
	var b = w.get_entity(int(w.scenario.get("boss", -1)))
	print("%s: winner %d after %ds, boss hp %d, army left %d" % [label, w.winner, t, b.hp if b and b.alive else 0, _army(w).size()])


func _tomb() -> void:
	var w := _world("m2_tomb")
	w.get_entity(int(w.scenario.flags.houdini)).pos = w.scenario.flags.crypt
	for i in 2 * World.TICK_RATE:
		w.tick()
	_fight(w, "tomb (Grave Engine)")


func _empress(burning: int) -> void:
	var w := _world("m5_empress")
	w.ais.clear()
	var pts: Array = w.scenario.points
	for i in pts.size() - burning:
		pts[i].owner = 0
	if burning == 3:
		w.scenario.started = w.tick_count - 480 * World.TICK_RATE
	for i in 2 * World.TICK_RATE:
		w.tick()
	_fight(w, "empress, %d circles burning" % burning)


func _buda() -> void:
	var w := _world("m6_viribus")
	w.ais.clear()
	var city = w.get_entity(w.players[0].capital_id)
	for e in w.entities.values():
		if e.alive and e.def.get("relic", false):
			e.inside = city.id
	for i in 185 * World.TICK_RATE:
		w.tick()
	_fight(w, "buda (Rudolf)")


func _vienna() -> void:
	# Do-nothing defence: the garrison holds at the Hofburg.
	var w := _world("m4_vienna")
	var t := 0
	while w.winner < 0 and t < 700:
		for i in 5 * World.TICK_RATE:
			w.tick()
		t += 5
	var v = w.get_entity(int(w.scenario.flags.vienna))
	print("vienna (idle garrison): winner %d after %ds, hofburg hp %d, army left %d" % [w.winner, t, v.hp if v else 0, _army(w).size()])


func _rosabelle() -> void:
	# Each open parlour in turn, then the counting-house.
	var w := _world("m7_rosabelle")
	var t := 0
	while w.winner < 0 and t < 1500:
		var goal: Vector2 = Vector2.ZERO
		var open: Array = w.scenario.get("points", []).filter(func(pt): return pt.owner != 0)
		if not open.is_empty():
			goal = open[0].pos
		else:
			goal = w.get_entity(int(w.scenario.flags.house)).pos
		# The Emperor stays home, as a careful player would keep him.
		var army: Array = _army(w).filter(func(i): return w.get_entity(i).type_id != "archduke")
		w.issue({"type": "attack_move", "player": 0, "ids": army, "pos": goal})
		for i in 5 * World.TICK_RATE:
			w.tick()
		t += 5
	var house = w.get_entity(int(w.scenario.flags.house))
	print("rosabelle: winner %d after %ds, step %d, parlours %d, house hp %d, army left %d" % [w.winner, t, w.scenario.step,
			w.scenario.get("points", []).filter(func(pt): return pt.owner == 0).size(), house.hp if house else 0, _army(w).size()])


func _black_thursday() -> void:
	# Charter two cities, then answer each buy-out with the army.
	var w := _world("m8_black_thursday")
	var cities: Array = w.scenario.flags.cities
	for i in 2:
		print("  charter: ", w.issue({"type": "charter", "player": 0, "building": int(cities[i])}))
	var t := 0
	while w.winner < 0 and t < 800:
		var target := Vector2.INF
		for e in w.entities.values():
			if e.alive and e.owner == 1 and e.kind == Entity.UNIT and e.can_attack():
				for id in cities:
					var c = w.get_entity(int(id))
					if c and c.alive and c.owner == 0 and e.pos.distance_to(c.pos) < 13 * 32:
						target = e.pos
		var army: Array = _army(w).filter(func(i): return w.get_entity(i).type_id != "archduke")
		if target != Vector2.INF:
			w.issue({"type": "attack_move", "player": 0, "ids": army, "pos": target})
		for i in 5 * World.TICK_RATE:
			w.tick()
		t += 5
	var lost := 0
	for id in cities:
		var c = w.get_entity(int(id))
		if c == null or c.owner != 0:
			lost += 1
	print("black thursday: winner %d after %ds, crown lands lost %d, army left %d" % [w.winner, t, lost, _army(w).size()])


func _ice_crown() -> void:
	# Hold the camp through the night; at dawn march on the foundry (Hedy stays home).
	var w := _world("m9_ice_crown")
	var camp = w.get_entity(int(w.scenario.flags.camp))
	var t := 0
	while w.winner < 0 and t < 1200:
		var army: Array = _army(w).filter(func(i): return w.get_entity(i).type_id != "hedy_lamarr")
		# Hold the line between the camp and the foundry.
		var foundry = w.get_entity(int(w.scenario.flags.foundry))
		var goal: Vector2 = camp.pos + (foundry.pos - camp.pos).normalized() * 3.0 * 32 if foundry else camp.pos
		if w.scenario.step == 2:
			var b = w.get_entity(int(w.scenario.get("boss", -1)))
			goal = b.pos if b and b.alive else w.get_entity(int(w.scenario.flags.foundry)).pos
		w.issue({"type": "attack_move", "player": 0, "ids": army, "pos": goal})
		for i in 5 * World.TICK_RATE:
			w.tick()
		t += 5
	var f = w.get_entity(int(w.scenario.flags.foundry))
	print("ice crown: winner %d after %ds, step %d, foundry hp %d, army left %d" % [w.winner, t, w.scenario.step, f.hp if f and f.alive else 0, _army(w).size()])


func _long_winter() -> void:
	# Answer whichever pass the enemy is nearest; after the hold, storm the HQ.
	var w := _world("m10_long_winter")
	var t := 0
	while w.winner < 0 and t < 1200:
		var army: Array = _army(w).filter(func(i): return w.get_entity(i).type_id != "tesla")
		var goal: Vector2 = w.scenario.points[0].pos
		if w.scenario.step == 1:
			goal = w.get_entity(int(w.scenario.flags.hq)).pos
		else:
			var best := INF
			for e in w.entities.values():
				if e.alive and e.owner == 1 and e.kind == Entity.UNIT and e.can_attack():
					for pt in w.scenario.points:
						var d: float = e.pos.distance_to(pt.pos)
						if d < best:
							best = d
							goal = pt.pos
		w.issue({"type": "attack_move", "player": 0, "ids": army, "pos": goal})
		for i in 5 * World.TICK_RATE:
			w.tick()
		t += 5
	var held: int = w.scenario.points.filter(func(p): return p.owner == 0).size()
	print("long winter: winner %d after %ds, step %d, passes held %d, army left %d" % [w.winner, t, w.scenario.step, held, _army(w).size()])
