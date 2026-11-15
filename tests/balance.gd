extends SceneTree
## Balance harness: plays AI-vs-AI games and prints one JSON line per game.
##   tools/godot --headless --path . -s tests/balance.gd -- <seed_from> <count> [difficulty] [max_minutes] [map_types]
## Seeds alternate which faction is player 0 and cycle through the map types, so a
## batch covers both sides and every map. tests/balance_report.py summarises.

const World = preload("res://sim/world.gd")
const Entity = preload("res://sim/entity.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_from := int(args[0]) if args.size() > 0 else 1
	var count := int(args[1]) if args.size() > 1 else 4
	var difficulty: String = args[2] if args.size() > 2 else "normal"
	var max_minutes := float(args[3]) if args.size() > 3 else 60.0
	var maps: Array = (args[4] if args.size() > 4 else "inland,coastal,islands").split(",")
	for i in count:
		var s := seed_from + i
		print(JSON.stringify(_play(s, difficulty, max_minutes, maps[s % maps.size()])))
	quit()


func _play(seed_value: int, difficulty: String, max_minutes: float, map_type: String) -> Dictionary:
	var sides := ["monarchy", "covenant"] if seed_value % 2 == 0 else ["covenant", "monarchy"]
	var w := World.new()
	# START_AGE=7 plays the modern ladder (Ages 7-12) instead of the classic one.
	var start := int(OS.get_environment("START_AGE")) if OS.has_environment("START_AGE") else 1
	w.new_game(seed_value, sides, -1, difficulty, map_type, {"start_age": start})
	var ages := {}
	var reason := "timeout"
	var peak_units := [0, 0]
	var t0 := Time.get_ticks_msec()
	while w.winner < 0 and w.tick_count * World.DT < max_minutes * 60.0:
		w.tick()
		for ev in w.events:
			if ev.type == "age_up":
				var f: String = w.players[ev.player].faction
				if not ages.has(f):
					ages[f] = {}
				ages[f][str(ev.age)] = snappedf(w.tick_count * World.DT / 60.0, 0.1)
			elif ev.type == "victory":
				reason = ev.get("reason", "conquest")
		if w.tick_count % (30 * World.TICK_RATE) == 0:
			var counts := [0, 0]
			for e in w.entities.values():
				if e.alive and e.kind == Entity.UNIT and e.owner in [0, 1] and not e.is_worker():
					counts[e.owner] += 1
			for p in 2:
				peak_units[p] = maxi(peak_units[p], counts[p])
	var final := {}
	for p in w.players:
		if p.is_rebels:
			continue
		final[p.faction] = {"age": p.age, "cities": w.city_count(p.index, false),
				"peak_army": peak_units[p.index], "waves": w.ais[p.index]._wave_count}
	return {
		"seed": seed_value, "map": map_type, "p0": sides[0],
		"winner": w.players[w.winner].faction if w.winner >= 0 else "",
		"reason": reason, "minutes": snappedf(w.tick_count * World.DT / 60.0, 0.1),
		"ages": ages, "final": final, "real_s": snappedf((Time.get_ticks_msec() - t0) / 1000.0, 0.1),
	}
