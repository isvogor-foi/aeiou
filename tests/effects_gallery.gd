extends SceneTree
## Visual check of the modern-age effects (view3d/effects.gd): each shot style fired
## across a stage, explosions, and the Aether bomb with its scar.
##   tools/godot --path . -s tests/effects_gallery.gd -- <out_dir>

const GameConfig = preload("res://sim/game_config.gd")
const GameMap = preload("res://sim/game_map.gd")
const DB = preload("res://sim/db.gd")

const STYLES := ["burst", "shell", "rocket", "flame", "flak"]


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for k in n:
		await process_frame


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	DB.ensure_loaded()
	for style in STYLES:
		DB.visuals.units["gallery_" + style] = {"shot": style, "burst": 6}
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
	gv.hud.visible = false
	for e in w.entities.values():
		w.kill(e)
	var y0 := 20
	# A clear grass stage (no trees over the lanes).
	for yy in range(y0 - 6, y0 + 12):
		for xx in range(2, 34):
			var t := Vector2i(xx, yy)
			w.map.terrain[w.map.idx(t)] = GameMap.GRASS
			w.map.dirty_tiles.append(t)
	w.map.rebuild_solids()
	gv.camera.distance = 12.0
	gv.center_on(Vector2(16, y0 + 2) * GameMap.TILE)
	await _frames(10)
	# Fire every style along its own lane, again and again, and catch them mid-flight.
	for round in 3:
		for i in STYLES.size():
			var from := Vector2(9, y0 + i) * GameMap.TILE
			var to := Vector2(22, y0 + i) * GameMap.TILE
			gv.effects.add_hit({"from": from, "to": to, "dtype": "ballistic", "ranged": true, "unit": "gallery_" + STYLES[i]})
		await _frames(8 if round < 2 else 6)
	await _save(out + "/fx_shots.png")
	await _frames(12)
	await _save(out + "/fx_impacts.png")
	gv.effects.add_bomb({"pos": Vector2(16, y0 + 2) * GameMap.TILE, "radius": 160.0})
	gv.camera.distance = 22.0
	gv.center_on(Vector2(16, y0) * GameMap.TILE)
	await _frames(20)
	await _save(out + "/fx_bomb.png")
	await _frames(150)
	await _save(out + "/fx_bomb_cloud.png")
	await _frames(400)
	await _save(out + "/fx_scar.png")
	quit()
