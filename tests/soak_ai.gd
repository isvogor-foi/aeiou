extends SceneTree
## AI vs AI soak run, headless. Prints each side's development every 2 minutes.
##   tools/godot --headless --path . -s tests/soak_ai.gd -- [minutes] [seed] [difficulty0] [difficulty1] [map_type]

const World = preload("res://sim/world.gd")
const Entity = preload("res://sim/entity.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var minutes := int(args[0]) if args.size() > 0 else 30
	var seed_value := int(args[1]) if args.size() > 1 else 77
	var w := World.new()
	var map_type: String = args[4] if args.size() > 4 else "inland"
	w.new_game(seed_value, ["monarchy", "covenant"], -1, "normal", map_type)
	if args.size() > 3:
		for i in 2:
			w.ais[i].setup(w, i, args[2 + i])
	var t0 := Time.get_ticks_msec()
	for i in minutes * 60 * World.TICK_RATE:
		w.tick()
		if w.tick_count % (120 * World.TICK_RATE) == 0:
			_report(w)
		if w.winner >= 0:
			break
	_report(w)
	print("winner: %d after %.1f min  (%.1fs real)" % [w.winner, w.tick_count * World.DT / 60.0, (Time.get_ticks_msec() - t0) / 1000.0])
	quit()


func _report(w: World) -> void:
	var line := "t=%4.1fm " % (w.tick_count * World.DT / 60.0)
	for p in w.players:
		if p.is_rebels:
			continue
		var workers := 0
		var army := 0
		var buildings := 0
		for e in w.entities.values():
			if e.alive and e.owner == p.index:
				if e.kind == Entity.UNIT:
					if e.is_worker(): workers += 1
					else: army += 1
				elif e.kind == Entity.BUILDING:
					buildings += 1
		var navy := 0
		var air := 0
		for e in w.entities.values():
			if e.alive and e.owner == p.index and e.kind == Entity.UNIT:
				if e.domain() == "naval": navy += 1
				elif e.domain() == "air": air += 1
		line += "| %s age %d cities %d wk %d army %d (air %d navy %d) bld %d pop %d/%d inc h%.1f waves %d " % [
				p.faction.left(4), p.age, w.city_count(p.index, false), workers, army, air, navy, buildings, p.pop_used, p.pop_cap,
				p.income.herbs, w.ais[p.index]._wave_count]
	print(line)
