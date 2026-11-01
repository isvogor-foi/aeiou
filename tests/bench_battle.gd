## Benchmark: 100 v 100 attack-move battle, tick timings.
##   tools/godot --headless --path . -s tests/bench_battle.gd
extends SceneTree
const World = preload("res://sim/world.gd")
func _initialize():
	var w = World.new()
	w.new_game(5, ["monarchy","covenant"], 0)
	var c0 = Vector2(30, 48) * 32
	var c1 = Vector2(66, 48) * 32
	var a = []; var b = []
	for i in 100:
		var off = Vector2((i % 10) * 20, (i / 10) * 20)
		a.append(w.spawn_unit(["grenadier","musketeer"][i % 2], 0, w.map.tile_center(w.map.nearest_walkable(w.map.to_tile(c0 + off)))).id)
		b.append(w.spawn_unit(["reaver","hexcaster"][i % 2], 1, w.map.tile_center(w.map.nearest_walkable(w.map.to_tile(c1 + off)))).id)
	w.issue({"type":"attack_move","player":0,"ids":a,"pos":c1})
	w.issue({"type":"attack_move","player":1,"ids":b,"pos":c0})
	var t0 = Time.get_ticks_usec()
	var worst = 0
	for i in 1200:
		var s = Time.get_ticks_usec()
		w.tick()
		worst = max(worst, Time.get_ticks_usec() - s)
	var alive = [0,0]
	for e in w.entities.values():
		if e.kind == 0 and e.owner >= 0: alive[e.owner] += 1
	print("avg tick ms: ", (Time.get_ticks_usec()-t0)/1200.0/1000.0, " worst ms: ", worst/1000.0, " alive ", alive)
	quit()
