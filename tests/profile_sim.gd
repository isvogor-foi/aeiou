extends SceneTree
## Profiles World.tick by section in an AI-vs-AI game, every 5 game minutes.
##   tools/godot --headless --path . -s tests/profile_sim.gd -- [minutes] [seed] [map_size]

const World = preload("res://sim/world.gd")
const Entity = preload("res://sim/entity.gd")
const Prof = preload("res://sim/prof.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var minutes := int(args[0]) if args.size() > 0 else 30
	var seed_value := int(args[1]) if args.size() > 1 else 77
	var size: String = args[2] if args.size() > 2 else "normal"
	var w := World.new()
	w.new_game(seed_value, ["monarchy", "covenant"], -1, "hard", "inland", {"map_size": size})
	World.profiling = true
	Prof.enabled = true
	var t0 := Time.get_ticks_msec()
	for m in range(5, minutes + 1, 5):
		World.profile = {}
		Prof.data = {}
		var s0 := Time.get_ticks_usec()
		for i in 5 * 60 * World.TICK_RATE:
			w.tick()
			if w.winner >= 0:
				break
		var total := float(Time.get_ticks_usec() - s0)
		var units := 0
		for e in w.entities.values():
			if e.alive and e.kind == Entity.UNIT:
				units += 1
		var parts: Array = []
		for k in World.profile:
			parts.append("%s %.2f" % [k, World.profile[k] / 6000.0 / 1000.0])
		var fparts: Array = []
		for k in Prof.data:
			if not k.begins_with("#"):
				fparts.append("%s %.2fms (%d/tick)" % [k, Prof.data[k] / 6000.0 / 1000.0, Prof.data["#" + k] / 6000])
		print("        funcs: " + ",  ".join(fparts))
		print("t=%2dm  units %3d  ents %4d  ms/tick %.2f  |  %s" % [m, units, w.entities.size(), total / 6000.0 / 1000.0, ",  ".join(parts)])
		if w.winner >= 0:
			break
	print("winner %d after %.1f min, %.1fs real" % [w.winner, w.tick_count * World.DT / 60.0, (Time.get_ticks_msec() - t0) / 1000.0])
	quit()
