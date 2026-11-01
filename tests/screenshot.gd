extends SceneTree
## Visual smoke test: plays a scripted opening and saves screenshots.
##   tools/godot --path . -s tests/screenshot.gd -- <out_dir>

const GameConfig = preload("res://sim/game_config.gd")
const Entity = preload("res://sim/entity.gd")
const GameMap = preload("res://sim/game_map.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	GameConfig.map_seed = 4242
	var gv = load("res://view3d/game3d.tscn").instantiate()
	gv.edge_scroll = false
	gv.input_enabled = false
	root.add_child(gv)
	await _frames(5)
	var w = gv.world
	var workers: Array = []
	var city = null
	for e in w.entities.values():
		if e.owner == 0 and e.is_worker():
			workers.append(e)
		if e.owner == 0 and e.def.get("role", "") == "city":
			city = e
	var mine = w.nearest_resource("gold", city.pos, 40 * 32)
	w.issue({"type": "gather", "player": 0, "ids": [workers[0].id, workers[1].id], "target": mine.id})
	var forest: Vector2i = w.map.nearest_forest(GameMap.to_tile(city.pos), 20)
	w.issue({"type": "gather", "player": 0, "ids": [workers[2].id], "tile": forest})
	w.issue({"type": "train", "player": 0, "building": city.id, "unit": "settler"})
	gv.selection.assign([workers[0].id, workers[1].id, workers[2].id])
	gv.speed_index = 3
	await _frames(240)
	_save(out_dir + "/01_opening.png")

	# Place a barracks, then show a skirmish near our city.
	var spot: Vector2i = city.tile + Vector2i(6, -1)
	print("place: ", w.issue({"type": "place", "player": 0, "ids": [workers[2].id], "building": "kaserne", "tile": spot}))
	for i in 4:
		w.spawn_unit("grenadier" if i < 2 else "musketeer", 0, city.pos + Vector2(-140 + i * 30, 120))
		w.spawn_unit("reaver" if i < 2 else "hexcaster", 1, city.pos + Vector2(-140 + i * 30, 300))
	gv.selection.assign([city.id])
	gv.center_on(city.pos + Vector2(0, 120))
	await _frames(90)
	_save(out_dir + "/02_skirmish.png")
	print("fps: ", Engine.get_frames_per_second())

	# Research at a library, advance the age, found a second city.
	var p = w.players[0]
	p.res = {"gold": 5000.0, "timber": 5000.0, "herbs": 5000.0, "mana": 5000.0}
	var lib = w.spawn_building("library", 0, city.tile + Vector2i(-6, 4), true)
	print("research: ", w.issue({"type": "research", "player": 0, "building": lib.id, "branch": "defense"}))
	print("age: ", w.issue({"type": "advance_age", "player": 0, "building": city.id}))
	var site: Vector2i = city.tile + Vector2i(14, 10)
	for y in range(site.y - 6, site.y + 12):
		for x in range(site.x - 6, site.x + 12):
			if w.map.in_bounds(Vector2i(x, y)):
				p.vis[w.map.idx(Vector2i(x, y))] = 1
	for i in 8:
		if w.placement_error(0, "residenz", site) == "":
			break
		site += Vector2i(1, 1)
	print("city: ", w.issue({"type": "place", "player": 0, "ids": [workers[0].id, workers[1].id], "building": "residenz", "tile": site}))
	await _frames(400)
	gv.selection.assign([lib.id])
	gv.center_on(lib.pos + Vector2(100, 0))
	await _frames(5)
	_save(out_dir + "/03_library.png")

	gv.reveal_all = true
	gv.camera.distance = 42.0
	gv.center_on(Vector2(32, 32) * 32)
	await _frames(10)
	_save(out_dir + "/04_overview.png")
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _save(path: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
