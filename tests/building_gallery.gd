extends SceneTree
## Visual check of every building: spawns them in rows on a cleared map and saves
## close-ups. tools/godot --path . -s tests/building_gallery.gd -- <out_dir>

const GameConfig = preload("res://sim/game_config.gd")
const DB = preload("res://sim/db.gd")
const GameMap = preload("res://sim/game_map.gd")
const Entity = preload("res://sim/entity.gd")

const MONARCHY := ["residenz", "dwelling", "storehouse", "garden", "library", "kaserne", "schiessstand", "laboratorium", "festungsturm", "adlerhorst", "fabrik", "orloj", "pummerin", "hofburg_treasury"]
const COVENANT := ["citadel", "dwelling", "storehouse", "garden", "library", "blood_pit", "bone_range", "ossuary", "bone_spire", "roost", "charnel_works", "obsidian_spire", "great_ossuary"]
const LANDS := ["austria", "croatia", "carniola", "bohemia", "galicia", "transylvania"]


func _initialize() -> void:
	_run.call_deferred()


func _shot(gv, path: String, at: Vector2, dist: float, yaw := 0.0) -> void:
	gv.camera.distance = dist
	gv.camera.set_heading(yaw)
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
	# A clear, dry stage: the band of rows whose ground is highest.
	var best_y := 10
	var best_low := -INF
	for y in range(4, w.map.height - 40):
		var low := INF
		for yy in range(y, y + 32):
			for xx in range(4, 80, 2):
				low = minf(low, w.map.heights[yy * (w.map.width + 1) + xx])
		if low > best_low:
			best_low = low
			best_y = y
	var y0 := best_y + 4
	for yy in range(best_y, best_y + 32):
		for xx in range(4, 80):
			var t := Vector2i(xx, yy)
			w.map.terrain[w.map.idx(t)] = GameMap.GRASS
			w.map.dirty_tiles.append(t)
	w.map.rebuild_solids()
	_row(w, MONARCHY, 0, Vector2i(10, y0))
	_row(w, COVENANT, 1, Vector2i(10, y0 + 10))
	var x := 10
	for land in LANDS:
		var c = w.spawn_building("residenz", 0, Vector2i(x, y0 + 20), true)
		c.crown_land = land
		x += 6
	var h = w.spawn_building("residenz", w.rebels, Vector2i(x, y0 + 20), true)
	for i in 3:
		await process_frame
	await _shot(gv, out + "/g_lands_a.png", Vector2(18, y0 + 22), 13.0)
	await _shot(gv, out + "/g_lands_b.png", Vector2(36, y0 + 22), 13.0)
	await _shot(gv, out + "/g_mon_a.png", Vector2(18, y0 + 2), 14.0)
	await _shot(gv, out + "/g_mon_b.png", Vector2(38, y0 + 2), 14.0)
	await _shot(gv, out + "/g_mon_c.png", Vector2(60, y0 + 2), 14.0)
	await _shot(gv, out + "/g_cov_a.png", Vector2(18, y0 + 12), 14.0)
	await _shot(gv, out + "/g_cov_b.png", Vector2(38, y0 + 12), 14.0)
	await _shot(gv, out + "/g_cov_c.png", Vector2(60, y0 + 12), 14.0)
	quit()


func _row(w, types: Array, owner: int, at: Vector2i) -> void:
	var x := at.x
	for t in types:
		var s := int(DB.buildings[t].size)
		w.spawn_building(t, owner, Vector2i(x, at.y), true)
		x += s + 2
