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
