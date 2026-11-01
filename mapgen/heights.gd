extends RefCounted
## Gently rolling ground heights (tiles), shared by the simulation (high-ground
## bonuses) and the 3D terrain. Stored per tile corner, (width + 1) x (height + 1),
## and point-symmetric like the rest of the map so neither start sits higher.

const GameMap = preload("res://sim/game_map.gd")

const TILE_HEIGHT := {
	GameMap.GRASS: 0.0, GameMap.FOREST: 0.08, GameMap.DIRT: -0.02, GameMap.ROCK: 0.5, GameMap.WATER: -0.7,
}
const HILL_AMPLITUDE := 0.55


static func build(map, seed_value: int) -> PackedFloat32Array:
	var w: int = map.width
	var h: int = map.height
	var hills := FastNoiseLite.new()
	hills.seed = seed_value + 9
	hills.frequency = 0.045
	var heights := PackedFloat32Array()
	heights.resize((w + 1) * (h + 1))
	for y in h + 1:
		for x in w + 1:
			# Average the target heights of the (up to 4) tiles sharing this corner.
			var sum := 0.0
			var n := 0
			var near_water := false
			for d in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
				var t: Vector2i = Vector2i(x, y) + d
				if map.in_bounds(t):
					var ter: int = map.get_terrain(t)
					sum += TILE_HEIGHT[ter]
					n += 1
					near_water = near_water or ter == GameMap.WATER
			var base := sum / maxi(n, 1)
			# Sample the noise at the canonical corner so the hills mirror exactly.
			var c := Vector2i(x, y)
			var m := Vector2i(w - x, h - y)
			if m.y * (w + 1) + m.x < c.y * (w + 1) + c.x:
				c = m
			var hill := (hills.get_noise_2d(c.x, c.y) * 0.5 + 0.5) * HILL_AMPLITUDE
			heights[y * (w + 1) + x] = base + (hill * 0.25 if near_water else hill)
	# One smoothing pass keeps slopes gentle.
	var smooth := heights.duplicate()
	for y in range(1, h):
		for x in range(1, w):
			var i := y * (w + 1) + x
			smooth[i] = (heights[i] * 4.0 + heights[i - 1] + heights[i + 1] + heights[i - w - 1] + heights[i + w + 1]) / 8.0
	return smooth
