extends SceneTree
## Visual check of the soldiers: spawns every dressed infantry figure in rows on a
## cleared map and saves close-ups. tools/godot --path . -s tests/unit_gallery.gd -- <out_dir>

const GameConfig = preload("res://sim/game_config.gd")
const GameMap = preload("res://sim/game_map.gd")

const MONARCHY := ["settler", "grenadier", "musketeer", "jaeger", "kaiserjaeger", "grenzer", "standschuetze", "field_alchemist", "bombardier", "vampire_hunter"]
const HEROES := ["rudolf", "prince_eugene", "maria_theresa", "iron_emperor", "tesla", "radetzky", "jelacic", "honved", "kaszas"]
const MOUNTED := ["kuerassier", "hussar", "uhlan", "jelacic", "ghoul_rider"]
const VEHICLES := ["tross_wagon", "bone_cart", "war_wagon", "steam_walker", "skoda_mortar", "plague_catapult", "landpanzer", "bone_juggernaut", "abomination", "bone_golem"]
const MONSTERS := ["abomination", "bone_golem", "prague_golem", "bone_colossus", "aether_colossus"]
const COVENANT := ["thrall", "risen", "reaver", "hexcaster", "bonebow", "necromancer", "grave_brute", "vampire", "wraith", "lich"]


func _initialize() -> void:
	_run.call_deferred()


func _shot(gv, path: String, at: Vector2, dist: float) -> void:
	gv.camera.distance = dist
	gv.center_on(at * GameMap.TILE)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	GameConfig.map_seed = 4242
	var gv = load("res://view3d/game3d.tscn").instantiate()
	gv.edge_scroll = false
	gv.input_enabled = false
	root.add_child(gv)
	await process_frame
	var w = gv.world
	gv.reveal_all = true
	gv.paused = true
	gv.hud.visible = false
	for e in w.entities.values():
		w.kill(e)
	# The driest flat band of the map as the stage.
	var best_y := 10
	var best_low := -INF
	for y in range(4, w.map.height - 20):
		var low := INF
		for yy in range(y, y + 18):
			for xx in range(4, 40, 2):
				low = minf(low, w.map.heights[yy * (w.map.width + 1) + xx])
		if low > best_low:
			best_low = low
			best_y = y
	for yy in range(best_y, best_y + 18):
		for xx in range(4, 40):
			var t := Vector2i(xx, yy)
			w.map.terrain[w.map.idx(t)] = GameMap.GRASS
			w.map.dirty_tiles.append(t)
	w.map.rebuild_solids()
	var y0 := best_y + 2
	var rows := [[MONARCHY, 0], [HEROES, 0], [COVENANT, 1], [MOUNTED, 0], [VEHICLES, 0], [MONSTERS, 0]]
	for r in rows.size():
		var x := 8.0 if r != 5 else 11.0
		for id in rows[r][0]:
			var u = w.spawn_unit(id, rows[r][1], Vector2(x, y0 + r * 3 + (1 if r == 5 else 0)) * GameMap.TILE)
			u.facing = Vector2.DOWN
			x += 1.6 if r < 3 else (2.4 if r < 5 else 4.0)
	for i in 3:
		await process_frame
	for r in rows.size():
		await _shot(gv, out + "/u_row%d_a.png" % r, Vector2(11.5, y0 + r * 3), 6.5)
		await _shot(gv, out + "/u_row%d_b.png" % r, Vector2(19.5, y0 + r * 3), 6.5)
		if r == 5:
			await _shot(gv, out + "/u_monsters.png", Vector2(19, y0 + r * 3), 14.0)
			await _shot(gv, out + "/u_monsters_close.png", Vector2(13, y0 + r * 3), 7.0)
		if r >= 3:
			await _shot(gv, out + "/u_row%d_c.png" % r, Vector2(27.5, y0 + r * 3), 6.5)
	await _shot(gv, out + "/u_overview.png", Vector2(16, y0 + 3), 16.0)
	quit()
