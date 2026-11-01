extends RefCounted
## National borders. Each completed city projects influence in a radius; every
## tile belongs to the strongest claim (radius minus distance) or to no one.

const GameMap = preload("res://sim/game_map.gd")

var width := 0
var height := 0
## Per tile: 0 = neutral, otherwise owner index + 1.
var grid := PackedByteArray()
var version := 0
var dirty := true


func setup(w: int, h: int) -> void:
	width = w
	height = h
	grid.resize(w * h)
	grid.fill(0)


func owner_at(t: Vector2i) -> int:
	if t.x < 0 or t.y < 0 or t.x >= width or t.y >= height:
		return -1
	return grid[t.y * width + t.x] - 1


## `sources` is [{owner, center (tile-space Vector2), radius}].
func compute(sources: Array) -> void:
	grid.fill(0)
	var best := PackedFloat32Array()
	best.resize(width * height)
	best.fill(-1.0)
	for s in sources:
		var c: Vector2 = s.center
		var r: float = s.radius
		var ri := ceili(r)
		for y in range(floori(c.y) - ri, floori(c.y) + ri + 1):
			if y < 0 or y >= height:
				continue
			for x in range(floori(c.x) - ri, floori(c.x) + ri + 1):
				if x < 0 or x >= width:
					continue
				var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
				var strength := r - d
				var i := y * width + x
				if strength >= 0.0 and strength > best[i]:
					best[i] = strength
					grid[i] = s.owner + 1
	version += 1
	dirty = false


## Share of the map owned by `player`, 0..1.
func share(player: int) -> float:
	var n := 0
	for v in grid:
		if v == player + 1:
			n += 1
	return float(n) / grid.size()
