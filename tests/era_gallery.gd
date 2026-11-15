extends SceneTree
## Visual check of the modern-age uniforms (view3d/figure.gd, ages 7-12): every new
## outfit in rows, then the era variants (worker and heroes) in Age 1, 7 and 10.
##   tools/godot --path . -s tests/era_gallery.gd -- <out_dir>
## The new outfits have no unit data until their ages are built, so each gets a
## temporary unit definition.

const GameConfig = preload("res://sim/game_config.gd")
const GameMap = preload("res://sim/game_map.gd")
const DB = preload("res://sim/db.gd")

const MONARCHY := ["rifleman", "sturmtrupp", "sanitaeter", "gebirgsjaeger", "radio_spotter", "paratrooper", "rocket_trooper",
		"flame_trooper", "atom_trooper", "arctic_trooper", "tank_crew", "pilot"]
const CONCERN := ["debt_bound", "tommy_ghoul", "gas_trooper", "wireless_medium", "frost_dead"]
const ERA := ["settler", "archduke", "tesla"]
const ERA_COVENANT := ["thrall"]


func _initialize() -> void:
	_run.call_deferred()


func _shot(gv, path: String, at: Vector2, dist: float) -> void:
	gv.camera.distance = dist
	gv.center_on(at * GameMap.TILE)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	DB.ensure_loaded()
	for id in MONARCHY + CONCERN:
		var d: Dictionary = DB.units.musketeer.duplicate(true)
		d.id = "gallery_" + id
		d.name = id.capitalize()
		d.faction = "covenant" if id in CONCERN else "monarchy"
		DB.units[d.id] = d
		DB.visuals.units[d.id] = {"figure": id, "height": 1.2, "anims": DB.visuals.units.musketeer.anims}
	GameConfig.map_seed = 4242
	var gv = load("res://view3d/game3d.tscn").instantiate()
	gv.edge_scroll = false
	gv.input_enabled = false
	root.add_child(gv)
	await process_frame
	var w = gv.world
	w.ais.clear()
	w.rules.victory.enabled.conquest = false
	gv.reveal_all = true
	gv.paused = true
	gv.hud.visible = false
	for e in w.entities.values():
		w.kill(e)
	var y0 := 20
	for yy in range(y0 - 4, y0 + 14):
		for xx in range(2, 44):
			var t := Vector2i(xx, yy)
			w.map.terrain[w.map.idx(t)] = GameMap.GRASS
			w.map.dirty_tiles.append(t)
	w.map.rebuild_solids()
	var rows := [[MONARCHY, 0, ""], [CONCERN, 1, ""], [ERA, 0, ""], [ERA_COVENANT, 1, ""]]
	for r in rows.size():
		var x := 6.0
		for id in rows[r][0]:
			var type: String = id if r >= 2 else "gallery_" + id
			var u = w.spawn_unit(type, rows[r][1], Vector2(x if r != 3 else 6.0 + 1.6 * ERA.size(), y0 + r * 3) * GameMap.TILE)
			u.facing = Vector2.DOWN
			x += 1.6
	for i in 3:
		await process_frame
	await _shot(gv, out + "/e_monarchy_a.png", Vector2(9.5, y0), 6.0)
	await _shot(gv, out + "/e_monarchy_b.png", Vector2(17.5, y0), 6.0)
	await _shot(gv, out + "/e_monarchy_c.png", Vector2(22.5, y0), 6.0)
	await _shot(gv, out + "/e_concern.png", Vector2(9.5, y0 + 3), 6.0)
	# The era variants: Age 1, then the players advance (the views rebuild themselves).
	for age in [1, 7, 10]:
		for p in w.players:
			p.age = age
		for i in 3:
			await process_frame
		await _shot(gv, out + "/e_era_age%d.png" % age, Vector2(8.5, y0 + 7), 5.0)
	quit()
