extends SceneTree
## Renders the README screenshot: a late-age Monarchy city and a battle beside it.
##   tools/godot --path . -s tests/readme_screenshot.gd -- docs/images/screenshot.png

const GameConfig = preload("res://sim/game_config.gd")
const Entity = preload("res://sim/entity.gd")
const DB = preload("res://sim/db.gd")
const GameMap = preload("res://sim/game_map.gd")

const BUILDINGS := ["kaserne", "fabrik", "laboratorium", "festungsturm", "adlerhorst", "dwelling", "dwelling", "library", "orloj", "festungsturm"]
const ARMY := [["kaiserjaeger", 8], ["grenadier", 6], ["landpanzer", 2], ["steam_walker", 2], ["kuerassier", 4]]
const FOES := [["reaver", 8], ["grave_brute", 3], ["bone_juggernaut", 1], ["abomination", 2], ["bonebow", 5]]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://screenshot.png"
	GameConfig.scenario = ""
	GameConfig.map_seed = 4242
	GameConfig.start_age = 5
	GameConfig.difficulty = "easy"
	GameConfig.reveal = "revealed"
	var gv = load("res://view3d/game3d.tscn").instantiate()
	gv.edge_scroll = false
	gv.input_enabled = false
	root.add_child(gv)
	await _frames(5)
	var w = gv.world
	w.ais.clear()
	var city: Entity = w.get_entity(w.players[0].capital_id)
	var toward: Vector2 = (w.get_entity(w.players[1].capital_id).pos - city.pos).normalized()
	# A built-up city: any free ground in widening rings (the borders follow the buildings).
	var placed := 0
	for r in range(5, 14):
		for k in 16:
			if placed >= BUILDINGS.size():
				break
			var a := TAU * k / 16.0 + r * 0.7
			var t: Vector2i = city.tile + Vector2i(roundi(cos(a) * r), roundi(sin(a) * r))
			var id: String = BUILDINGS[placed]
			var s := int(DB.buildings[id].size)
			if w.map.area_free(t - Vector2i.ONE, Vector2i(s + 2, s + 2)):
				w.spawn_building(id, 0, t, true)
				placed += 1
	# The battle on open ground near the city: the walkable spot with the most land around it.
	var front := _open_ground(w, city.pos + toward * 15.0 * 32.0)
	var side := toward.orthogonal()
	var mine: Array = []
	var theirs: Array = []
	var i := 0
	for g in ARMY:
		for n in g[1]:
			mine.append(w.spawn_unit(g[0], 0, front - toward * (150.0 + i * 24.0) + side * (n - g[1] / 2.0) * 30.0).id)
		i += 1
	i = 0
	for g in FOES:
		for n in g[1]:
			theirs.append(w.spawn_unit(g[0], 1, front + toward * (150.0 + i * 24.0) + side * (n - g[1] / 2.0) * 30.0).id)
		i += 1
	w.issue({"type": "attack_move", "player": 0, "ids": mine, "pos": front + toward * 150.0})
	w.issue({"type": "attack_move", "player": 1, "ids": theirs, "pos": front - toward * 150.0})
	gv.selection.assign(mine.slice(0, 8))
	gv.center_on(city.pos.lerp(front, 0.5))
	gv.camera.distance = 32.0
	gv.camera.update_transform()
	# Long enough for the start-of-match banner to fade and the lines to meet.
	await _frames(270)
	root.get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()


func _frames(n: int) -> void:
	for k in n:
		await process_frame


## The walkable tile near `around` (pixels) with the most walkable ground within 4 tiles.
func _open_ground(w, around: Vector2) -> Vector2:
	var c := GameMap.to_tile(around)
	var best := c
	var best_n := -1
	for dy in range(-6, 7, 2):
		for dx in range(-6, 7, 2):
			var t := c + Vector2i(dx, dy)
			var n := 0
			for y in range(-4, 5):
				for x in range(-4, 5):
					if w.map.in_bounds(t + Vector2i(x, y)) and w.map.is_walkable(t + Vector2i(x, y)):
						n += 1
			if n > best_n:
				best_n = n
				best = t
	return GameMap.tile_center(best)
