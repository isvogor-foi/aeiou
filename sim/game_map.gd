extends RefCounted
## Tile grid: terrain, timber per forest tile, building/resource occupancy and
## pathfinding for each movement domain: "ground" (open land), "naval" (water)
## and "air" (anywhere, straight lines).

const TILE := 32
enum { GRASS, WATER, FOREST, ROCK, DIRT }

var width := 0
var height := 0
var terrain := PackedByteArray()
var timber := PackedFloat32Array()
## Id of the building/resource covering each tile, or -1.
var occupant := PackedInt32Array()
var astar := AStarGrid2D.new()
var naval_astar := AStarGrid2D.new()
## Ground height per tile corner, (width + 1) x (height + 1), in tiles (see mapgen/heights.gd).
var heights := PackedFloat32Array()
## Tiles whose terrain changed since the view last consumed them (forest cut down).
var dirty_tiles: Array[Vector2i] = []
var version := 0


func setup(w: int, h: int) -> void:
	width = w
	height = h
	terrain.resize(w * h)
	terrain.fill(GRASS)
	timber.resize(w * h)
	timber.fill(0.0)
	occupant.resize(w * h)
	occupant.fill(-1)
	for grid in [astar, naval_astar]:
		grid.region = Rect2i(0, 0, w, h)
		grid.cell_size = Vector2.ONE
		grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		grid.jumping_enabled = true
		grid.update()


func rebuild_solids() -> void:
	for y in height:
		for x in width:
			var t := Vector2i(x, y)
			astar.set_point_solid(t, not is_walkable(t))
			naval_astar.set_point_solid(t, not is_sailable(t))


func idx(t: Vector2i) -> int:
	return t.y * width + t.x


func in_bounds(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < width and t.y < height


func get_terrain(t: Vector2i) -> int:
	return terrain[idx(t)] if in_bounds(t) else ROCK


func is_open_ground(t: Vector2i) -> bool:
	var ter := get_terrain(t)
	return ter == GRASS or ter == DIRT


func is_walkable(t: Vector2i) -> bool:
	return in_bounds(t) and occupant[idx(t)] == -1 and is_open_ground(t)


## Height of the ground at a tile's centre.
func elevation(t: Vector2i) -> float:
	if heights.is_empty() or not in_bounds(t):
		return 0.0
	var w := width + 1
	var i := t.y * w + t.x
	return (heights[i] + heights[i + 1] + heights[i + w] + heights[i + w + 1]) * 0.25


func is_sailable(t: Vector2i) -> bool:
	return in_bounds(t) and terrain[idx(t)] == WATER


func is_passable(t: Vector2i, domain := "ground") -> bool:
	match domain:
		"air":
			return in_bounds(t)
		"naval":
			return is_sailable(t)
	return is_walkable(t)


## A water tile with open land next to it (where transports land and docks stand).
func is_shore_water(t: Vector2i) -> bool:
	if not is_sailable(t):
		return false
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if is_walkable(t + d):
			return true
	return false


func set_terrain(t: Vector2i, ter: int) -> void:
	terrain[idx(t)] = ter
	astar.set_point_solid(t, not is_walkable(t))
	naval_astar.set_point_solid(t, not is_sailable(t))
	dirty_tiles.append(t)
	version += 1


static func to_tile(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori(p.y / TILE))


static func tile_center(t: Vector2i) -> Vector2:
	return Vector2(t) * TILE + Vector2(TILE, TILE) * 0.5


func area_free(top_left: Vector2i, size: Vector2i) -> bool:
	for y in size.y:
		for x in size.x:
			if not is_walkable(top_left + Vector2i(x, y)):
				return false
	return true


func occupy(top_left: Vector2i, size: Vector2i, id: int) -> void:
	for y in size.y:
		for x in size.x:
			var t := top_left + Vector2i(x, y)
			if in_bounds(t):
				occupant[idx(t)] = id
				astar.set_point_solid(t, true)


func vacate(top_left: Vector2i, size: Vector2i) -> void:
	for y in size.y:
		for x in size.x:
			var t := top_left + Vector2i(x, y)
			if in_bounds(t):
				occupant[idx(t)] = -1
				astar.set_point_solid(t, not is_walkable(t))


func timber_at(t: Vector2i) -> float:
	return timber[idx(t)] if in_bounds(t) and terrain[idx(t)] == FOREST else 0.0


## Removes up to `amount` timber; a cleared tile becomes walkable dirt.
func take_timber(t: Vector2i, amount: float) -> float:
	var i := idx(t)
	var taken := minf(amount, timber[i])
	timber[i] -= taken
	if timber[i] <= 0.0:
		set_terrain(t, DIRT)
	return taken


## Nearest walkable tile to `t` (itself if walkable), searching outward in rings.
func nearest_walkable(t: Vector2i, max_r := 12, domain := "ground") -> Vector2i:
	if is_passable(t, domain):
		return t
	for r in range(1, max_r + 1):
		var best := Vector2i(-1, -1)
		var best_d := INF
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := t + Vector2i(dx, dy)
				if is_passable(c, domain):
					var d := float(dx * dx + dy * dy)
					if d < best_d:
						best_d = d
						best = c
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)


## Closest walkable tile bordering the rect, as seen from `from`.
func approach_tile(top_left: Vector2i, size: Vector2i, from: Vector2, domain := "ground") -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for y in range(top_left.y - 1, top_left.y + size.y + 1):
		for x in range(top_left.x - 1, top_left.x + size.x + 1):
			var inside := x >= top_left.x and x < top_left.x + size.x \
					and y >= top_left.y and y < top_left.y + size.y
			var t := Vector2i(x, y)
			if inside or not is_passable(t, domain):
				continue
			var d := tile_center(t).distance_squared_to(from)
			if d < best_d:
				best_d = d
				best = t
	if best.x < 0:
		best = nearest_walkable(top_left + size / 2, 16, domain)
	return best


## Nearest forest tile with timber that has a walkable neighbour (so workers can reach it).
func nearest_forest(t: Vector2i, max_r := 8) -> Vector2i:
	for r in range(0, max_r + 1):
		var best := Vector2i(-1, -1)
		var best_d := INF
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := t + Vector2i(dx, dy)
				if timber_at(c) > 0.0 and _has_walkable_neighbour(c):
					var d := float(dx * dx + dy * dy)
					if d < best_d:
						best_d = d
						best = c
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)


func _has_walkable_neighbour(t: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if (dx != 0 or dy != 0) and is_walkable(t + Vector2i(dx, dy)):
				return true
	return false


## True if a straight walk from a to b crosses only walkable tiles.
func line_clear(a: Vector2, b: Vector2, domain := "ground") -> bool:
	if domain == "air":
		return true
	var steps := ceili(a.distance_to(b) / (TILE * 0.5))
	for i in range(1, steps + 1):
		if not is_passable(to_tile(a.lerp(b, float(i) / steps)), domain):
			return false
	return true


## Waypoints (tile centres) from `from` toward `goal`. If the goal is blocked or
## unreachable, the path ends at the closest reachable tile.
func find_path(from: Vector2, goal: Vector2i, domain := "ground") -> PackedVector2Array:
	var out := PackedVector2Array()
	var here := to_tile(from)
	if domain == "air":
		if in_bounds(goal) and goal != here:
			out.append(tile_center(goal))
		return out
	var start := nearest_walkable(here, 6, domain)
	var end := nearest_walkable(goal, 12, domain)
	if start.x < 0 or end.x < 0:
		return out
	if start != here:
		out.append(tile_center(start))
	var grid: AStarGrid2D = naval_astar if domain == "naval" else astar
	var ids := grid.get_id_path(start, end, true)
	for i in range(1, ids.size()):
		out.append(tile_center(ids[i]))
	return out


## Nearest water tile beside open land, searching outward from `t` (for unloading).
func nearest_shore(t: Vector2i, max_r := 20) -> Vector2i:
	for r in range(0, max_r + 1):
		var best := Vector2i(-1, -1)
		var best_d := INF
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := t + Vector2i(dx, dy)
				if is_shore_water(c):
					var d := float(dx * dx + dy * dy)
					if d < best_d:
						best_d = d
						best = c
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)
