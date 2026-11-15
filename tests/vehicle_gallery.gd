extends SceneTree
## Visual check of the vehicle kit (view3d/vehicles.gd): every vehicle parked in a
## row, then driving off while shooting at a target to one side (wheels and tracks
## turn, turrets swing round, hulls rumble).
##   tools/godot --path . -s tests/vehicle_gallery.gd -- <out_dir>
## The vehicles have no unit data until their ages are built, so this script lends
## each one a temporary unit definition.

const GameConfig = preload("res://sim/game_config.gd")
const GameMap = preload("res://sim/game_map.gd")
const DB = preload("res://sim/db.gd")
const Vehicles = preload("res://view3d/vehicles.gd")



func _initialize() -> void:
	_run.call_deferred()


func _shot(gv, path: String, at: Vector2, dist: float, frames := 8) -> void:
	gv.camera.distance = dist
	gv.center_on(at * GameMap.TILE)
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	DB.ensure_loaded()
	for kind in Vehicles.KINDS:
		var d: Dictionary = DB.units.landpanzer.duplicate(true)
		d.id = "gallery_" + kind
		d.name = kind.capitalize()
		d.faction = "covenant" if kind in Vehicles.CONCERN else "monarchy"
		d.speed = 2.2
		d.range = 5.0
		d.erase("abilities")
		DB.units[d.id] = d
		var air: bool = kind in Vehicles.AIR
		d.domain = "air" if air else "ground"
		DB.visuals.units[d.id] = {"procedural": kind, "scale": 1.0, "rumble": 0.0 if air else 1.0}
		if air:
			DB.visuals.units[d.id].merge({"fly_height": 2.2, "bank": kind != "zeppelin" and kind != "corpse_zeppelin",
					"circle": 0.0 if "zeppelin" in kind else 0.7})
	GameConfig.map_seed = 4242
	var gv = load("res://view3d/game3d.tscn").instantiate()
	gv.edge_scroll = false
	gv.input_enabled = false
	root.add_child(gv)
	await process_frame
	var w = gv.world
	w.ais.clear()
	# No cities on the stage: without this, conquest would end the match at once.
	w.rules.victory.enabled.conquest = false
	gv.reveal_all = true
	gv.hud.visible = false
	for e in w.entities.values():
		w.kill(e)
	# A flat grass stage.
	var y0 := 20
	for yy in range(y0 - 4, y0 + 16):
		for xx in range(2, 44):
			var t := Vector2i(xx, yy)
			w.map.terrain[w.map.idx(t)] = GameMap.GRASS
			w.map.dirty_tiles.append(t)
	w.map.rebuild_solids()
	# Ground vehicles in the first row, aircraft in a second.
	var ids: Array = []
	for row in [Vehicles.GROUND, Vehicles.AIR]:
		var x := 6.0
		for kind in row:
			var owner := 1 if kind in Vehicles.CONCERN else 0
			var u = w.spawn_unit("gallery_" + kind, owner, Vector2(x, y0 + (0 if row == Vehicles.GROUND else 5)) * GameMap.TILE)
			u.facing = Vector2.DOWN
			ids.append(u.id)
			x += 2.2 if row == Vehicles.GROUND else 3.0
	gv.paused = true
	for i in 3:
		await process_frame
	await _shot(gv, out + "/v_parked_a.png", Vector2(10.0, y0), 6.0)
	await _shot(gv, out + "/v_parked_b.png", Vector2(16.5, y0), 6.0)
	await _shot(gv, out + "/v_parked_c.png", Vector2(23.0, y0), 6.0)
	await _shot(gv, out + "/v_parked_d.png", Vector2(29.0, y0), 6.0)
	# Aircraft fly 2.2 up, so from the tilted camera they show about 3 tiles up-screen.
	await _shot(gv, out + "/v_air_a.png", Vector2(10.0, y0 + 2), 7.0)
	await _shot(gv, out + "/v_air_b.png", Vector2(17.5, y0 + 2), 7.0)
	await _shot(gv, out + "/v_air_c.png", Vector2(24.5, y0 + 2), 7.0)
	await _shot(gv, out + "/v_overview.png", Vector2(18.0, y0 + 3), 14.0)
	# Drive south while shooting at a target off to the east: turrets swing round.
	var dummy = w.spawn_unit("bone_golem", 1, Vector2(34, y0 + 4) * GameMap.TILE)
	dummy.hp = 1e6
	dummy.max_hp = 1e6
	gv.paused = false
	for id in ids:
		var u = w.get_entity(id)
		w.issue({"type": "move", "player": u.owner, "ids": [id], "pos": u.pos + Vector2(0, 9) * GameMap.TILE})
	var t0 := Time.get_ticks_msec()
	for i in 90:
		await process_frame
		if i % 10 == 0:
			for id in ids:
				gv.entity_views.on_attack(id, dummy.pos)
	await _shot(gv, out + "/v_driving.png", Vector2(18.0, y0 + 7), 14.0, 1)
	await _shot(gv, out + "/v_driving_close.png", Vector2(19.0, y0 + 11), 7.0, 30)
	print("drove for %.1fs" % ((Time.get_ticks_msec() - t0) / 1000.0))
	# The moving parts really moved: wheel angles, tread offsets and turret yaw.
	for i in ids.size():
		var r: Dictionary = gv.entity_views.views[ids[i]]
		var rolls: Array = r.animated.filter(func(n): return n.has_meta("roll")).map(func(n): return snappedf(n.rotation.x, 0.01))
		var treads: Array = r.animated.filter(func(n): return n.has_meta("tread")).map(func(n): return snappedf(float(n.get_meta("_scroll", 0.0)), 0.01))
		var turrets: Array = r.animated.filter(func(n): return n.has_meta("turret")).map(func(n): return snappedf(n.rotation.y, 0.01))
		print("%-13s wheels %s treads %s turret %s" % [Vehicles.KINDS[i], rolls.slice(0, 3), treads, turrets])
	quit()
