extends RefCounted
## Seeded procedural maps for two players. The map is point-symmetric through its
## centre so both starts are equally fair: every tile mirrors (x, y) -> (W-1-x, H-1-y).

const DB = preload("res://sim/db.gd")
const GameMap = preload("res://sim/game_map.gd")
const Heights = preload("res://mapgen/heights.gd")

const START_INSET := 14
const START_CLEAR_RADIUS := 10

## Resource nodes around each start, as offsets from the start tile (city centre).
const START_NODES := [
	{"type": "gold_mine", "offset": Vector2i(5, 3)},
	{"type": "herb_patch", "offset": Vector2i(-7, 3)},
	{"type": "herb_patch", "offset": Vector2i(-4, 7)},
	{"type": "ley_node", "offset": Vector2i(4, -7)},
	# Just beyond the first border: the late game's coal is worth expanding for.
	{"type": "coal_seam", "offset": Vector2i(-1, 10)},
]
## Guaranteed forest blocks near each start, as rects relative to the start tile.
const START_FORESTS := [
	Rect2i(-9, -9, 5, 5),
	Rect2i(7, 6, 3, 4),
]
## Map types: "inland" has scattered lakes; "coastal" adds a shared central sea;
## "islands" splits the map with a strait so each start sits on its own landmass.
const MAP_TYPES := ["inland", "coastal", "islands"]
const SEA_RADIUS := 17.0
const STRAIT_HALF_WIDTH := 9.0
## Each start gets a channel to open water so it can build docks inside its borders.
const CHANNEL_START := Vector2i(6, 6)
const CHANNEL_RADIUS := 2.4
## Fish shoals per half of the map, beyond the two near each start on water maps.
const EXTRA_FISH := {"inland": 2, "coastal": 4, "islands": 5}

## Extra contested nodes placed on each half of the map (then mirrored).
const EXTRA_NODES := {"gold_mine": 3, "herb_patch": 2, "ley_node": 2, "coal_seam": 3}


## Fills `map` and returns {"starts": [Vector2i, Vector2i], "nodes": [{type, tile}]}.
static func generate(map, seed_value: int, size := 96, map_type := "inland") -> Dictionary:
	map.setup(size, size)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_paint_terrain(map, seed_value)

	var s0 := Vector2i(START_INSET, START_INSET)
	var s1 := _mirror(map, s0)
	_fill_disc(map, s0, START_CLEAR_RADIUS, GameMap.GRASS)
	for r in START_FORESTS:
		_fill_rect(map, Rect2i(s0 + r.position, r.size), GameMap.FOREST)

	if map_type != "inland":
		_paint_sea(map, seed_value, map_type, s0)

	var nodes: Array = []
	for n in START_NODES:
		_add_node(map, nodes, n.type, s0 + n.offset - Vector2i.ONE)
	# Keep the city footprint itself clear.
	_fill_rect(map, Rect2i(s0 - Vector2i(3, 3), Vector2i(6, 6)), GameMap.GRASS)

	if map_type != "islands":
		_ensure_connected(map, s0, s1, map_type == "coastal")
	_add_fish(map, nodes, rng, map_type, s0)

	for type in EXTRA_NODES:
		var placed := 0
		var attempts := 0
		while placed < EXTRA_NODES[type] and attempts < 400:
			attempts += 1
			var t := Vector2i(rng.randi_range(3, size - 5), rng.randi_range(3, size - 5))
			if _is_canonical(map, t) and _node_site_ok(map, nodes, t, s0, s1):
				_add_node(map, nodes, type, t)
				placed += 1

	DB.ensure_loaded()
	var forest_amount := float(DB.resources.forest.amount)
	for y in size:
		for x in size:
			var i := y * size + x
			if map.terrain[i] == GameMap.FOREST:
				map.timber[i] = forest_amount
	map.rebuild_solids()
	map.heights = Heights.build(map, seed_value)
	return {"starts": [s0, s1], "nodes": nodes}


static func _paint_sea(map, seed_value: int, map_type: String, s0: Vector2i) -> void:
	var shore := FastNoiseLite.new()
	shore.seed = seed_value + 7
	shore.frequency = 0.08
	var center := Vector2(map.width, map.height) * 0.5 - Vector2(0.5, 0.5)
	for y in map.height:
		for x in map.width:
			var t := Vector2i(x, y)
			var c := t if _is_canonical(map, t) else _mirror(map, t)
			var wobble := shore.get_noise_2d(c.x, c.y) * 3.0
			var wet := false
			if map_type == "coastal":
				wet = Vector2(t).distance_to(center) < SEA_RADIUS + wobble
			else:
				wet = absf(x + y - (map.width - 1)) < STRAIT_HALF_WIDTH + wobble
			if wet:
				map.terrain[map.idx(t)] = GameMap.WATER
	# A channel from each start to the open water (mirrored automatically).
	var from := Vector2(s0 + CHANNEL_START)
	var steps := ceili(from.distance_to(center))
	for i in steps + 1:
		var p := from.lerp(center, float(i) / steps)
		var r := ceili(CHANNEL_RADIUS)
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var t := Vector2i(roundi(p.x) + dx, roundi(p.y) + dy)
				if Vector2(t).distance_to(p) <= CHANNEL_RADIUS:
					_set_mirrored(map, t, GameMap.WATER)


## Fish shoals: two in each start's channel on water maps, plus some in open water.
static func _add_fish(map, nodes: Array, rng: RandomNumberGenerator, map_type: String, s0: Vector2i) -> void:
	var placed := 0
	if map_type != "inland":
		var center := Vector2(map.width, map.height) * 0.5
		for d in [11.0, 15.0]:
			var p := Vector2(s0 + CHANNEL_START).move_toward(center, d - 8.0)
			var t: Vector2i = map.nearest_walkable(Vector2i(p.round()), 4, "naval")
			if t.x >= 0:
				_add_fish_at(map, nodes, t)
	var attempts := 0
	while placed < int(EXTRA_FISH.get(map_type, 2)) and attempts < 600:
		attempts += 1
		var t := Vector2i(rng.randi_range(2, map.width - 3), rng.randi_range(2, map.height - 3))
		if not _is_canonical(map, t) or map.get_terrain(t) != GameMap.WATER or map.is_shore_water(t):
			continue
		var clear := true
		for n in nodes:
			if Vector2(t).distance_to(Vector2(n.tile)) < 6.0:
				clear = false
		if clear:
			_add_fish_at(map, nodes, t)
			placed += 1


static func _add_fish_at(map, nodes: Array, t: Vector2i) -> void:
	nodes.append({"type": "fish", "tile": t})
	nodes.append({"type": "fish", "tile": _mirror(map, t)})


static func _paint_terrain(map, seed_value: int) -> void:
	var water := FastNoiseLite.new()
	water.seed = seed_value
	water.frequency = 0.035
	var woods := FastNoiseLite.new()
	woods.seed = seed_value + 1
	woods.frequency = 0.09
	var rocks := FastNoiseLite.new()
	rocks.seed = seed_value + 2
	rocks.frequency = 0.15
	for y in map.height:
		for x in map.width:
			var t := Vector2i(x, y)
			var c := t if _is_canonical(map, t) else _mirror(map, t)
			var wv := water.get_noise_2d(c.x, c.y)
			var ter := GameMap.GRASS
			if wv < -0.36:
				ter = GameMap.WATER
			elif woods.get_noise_2d(c.x, c.y) > 0.27:
				ter = GameMap.FOREST
			elif rocks.get_noise_2d(c.x, c.y) > 0.5:
				ter = GameMap.ROCK
			elif wv < -0.29:
				ter = GameMap.DIRT
			map.terrain[map.idx(t)] = ter


static func _mirror(map, t: Vector2i) -> Vector2i:
	return Vector2i(map.width - 1 - t.x, map.height - 1 - t.y)


## True for the half of the map that gets generated; the other half is its mirror.
static func _is_canonical(map, t: Vector2i) -> bool:
	return map.idx(t) <= map.idx(_mirror(map, t))


## Sets a tile and its mirror.
static func _set_mirrored(map, t: Vector2i, ter: int) -> void:
	if not map.in_bounds(t):
		return
	map.terrain[map.idx(t)] = ter
	map.terrain[map.idx(_mirror(map, t))] = ter


static func _fill_disc(map, c: Vector2i, r: int, ter: int) -> void:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy <= r * r:
				_set_mirrored(map, c + Vector2i(dx, dy), ter)


static func _fill_rect(map, r: Rect2i, ter: int) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			_set_mirrored(map, Vector2i(x, y), ter)


## Adds a 2x2 node at `tile` (top-left) and its mirror, clearing ground around it.
static func _add_node(map, nodes: Array, type: String, tile: Vector2i) -> void:
	_fill_rect(map, Rect2i(tile - Vector2i.ONE, Vector2i(4, 4)), GameMap.GRASS)
	nodes.append({"type": type, "tile": tile})
	# The mirror of a 2x2 rect's top-left is offset by its size.
	nodes.append({"type": type, "tile": _mirror(map, tile) - Vector2i.ONE})


static func _node_site_ok(map, nodes: Array, t: Vector2i, s0: Vector2i, s1: Vector2i) -> bool:
	for s in [s0, s1]:
		if Vector2(t).distance_to(Vector2(s)) < 18.0:
			return false
	for n in nodes:
		if Vector2(t).distance_to(Vector2(n.tile)) < 9.0:
			return false
	for y in range(t.y - 1, t.y + 3):
		for x in range(t.x - 1, t.x + 3):
			if map.get_terrain(Vector2i(x, y)) != GameMap.GRASS:
				return false
	return true


## Carves a land corridor between the starts if water or rock separates them.
## Around a central sea the corridor goes via the two free corners instead of through it.
static func _ensure_connected(map, s0: Vector2i, s1: Vector2i, around := false) -> void:
	map.rebuild_solids()
	var p: PackedVector2Array = map.astar.get_point_path(s0, s1)
	if not p.is_empty():
		return
	if around:
		var corner := Vector2i(s0.x, s1.y)
		_carve(map, s0, corner)
		_carve(map, corner, s1)
		return
	_carve(map, s0, s1)


static func _carve(map, s0: Vector2i, s1: Vector2i) -> void:
	var steps := maxi(absi(s1.x - s0.x), absi(s1.y - s0.y))
	for i in steps + 1:
		var c := Vector2i(Vector2(s0).lerp(Vector2(s1), float(i) / steps).round())
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var t := c + Vector2i(dx, dy)
				if map.get_terrain(t) != GameMap.GRASS:
					_set_mirrored(map, t, GameMap.DIRT)
