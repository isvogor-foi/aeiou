extends RefCounted
## Small flat icons for the HUD (resources, status, commands), drawn in code from
## a few signed-distance shapes with 4x4 supersampling, and cached.

const SIZE := 32
const SS := 4

static var _cache := {}


static func get_icon(name: String) -> Texture2D:
	if not _cache.has(name):
		_cache[name] = _render(_shapes(name))
	return _cache[name]


## Each shape: [kind, params..., color]. Coordinates are 0..1 across the icon.
static func _shapes(name: String) -> Array:
	var gold := Color(0.96, 0.78, 0.25)
	var dark_gold := Color(0.70, 0.52, 0.12)
	var wood := Color(0.55, 0.36, 0.18)
	var wood_end := Color(0.80, 0.62, 0.38)
	var steel := Color(0.82, 0.84, 0.88)
	var white := Color(0.93, 0.91, 0.86)
	match name:
		"gold":
			return [["circle", 0.5, 0.5, 0.40, dark_gold], ["circle", 0.5, 0.5, 0.31, gold],
					["box", 0.5, 0.5, 0.05, 0.16, dark_gold], ["box", 0.5, 0.36, 0.13, 0.04, dark_gold]]
		"timber":
			return [["capsule", 0.18, 0.62, 0.78, 0.62, 0.14, wood], ["circle", 0.78, 0.62, 0.13, wood_end],
					["capsule", 0.26, 0.36, 0.84, 0.36, 0.14, wood.lightened(0.1)], ["circle", 0.84, 0.36, 0.13, wood_end]]
		"herbs":
			var wheat := Color(0.86, 0.74, 0.32)
			return [["capsule", 0.5, 0.92, 0.5, 0.35, 0.04, Color(0.55, 0.62, 0.25)],
					["capsule", 0.5, 0.18, 0.5, 0.30, 0.08, wheat], ["capsule", 0.36, 0.34, 0.44, 0.46, 0.08, wheat],
					["capsule", 0.64, 0.34, 0.56, 0.46, 0.08, wheat], ["capsule", 0.36, 0.54, 0.44, 0.64, 0.08, wheat],
					["capsule", 0.64, 0.54, 0.56, 0.64, 0.08, wheat]]
		"mana":
			return [["poly", [Vector2(0.5, 0.08), Vector2(0.86, 0.45), Vector2(0.5, 0.94), Vector2(0.14, 0.45)], Color(0.30, 0.75, 0.95)],
					["poly", [Vector2(0.5, 0.08), Vector2(0.86, 0.45), Vector2(0.5, 0.45)], Color(0.62, 0.92, 1.0)]]
		"coal":
			return [["poly", [Vector2(0.18, 0.62), Vector2(0.32, 0.28), Vector2(0.62, 0.18), Vector2(0.86, 0.42), Vector2(0.78, 0.80), Vector2(0.36, 0.86)], Color(0.20, 0.20, 0.22)],
					["poly", [Vector2(0.32, 0.28), Vector2(0.62, 0.18), Vector2(0.55, 0.42)], Color(0.48, 0.48, 0.52)]]
		"pop":
			return [["circle", 0.5, 0.28, 0.16, white], ["capsule", 0.5, 0.62, 0.5, 0.80, 0.24, white]]
		"crown":
			return [["poly", [Vector2(0.12, 0.30), Vector2(0.32, 0.52), Vector2(0.5, 0.22), Vector2(0.68, 0.52), Vector2(0.88, 0.30), Vector2(0.80, 0.78), Vector2(0.20, 0.78)], gold],
					["box", 0.5, 0.80, 0.30, 0.05, dark_gold]]
		"city":
			return [["box", 0.5, 0.66, 0.34, 0.22, white], ["box", 0.22, 0.38, 0.06, 0.08, white],
					["box", 0.5, 0.38, 0.06, 0.08, white], ["box", 0.78, 0.38, 0.06, 0.08, white],
					["box", 0.5, 0.74, 0.08, 0.14, Color(0.25, 0.22, 0.2)]]
		"idle":
			return [["capsule", 0.25, 0.80, 0.70, 0.30, 0.05, wood_end],
					["capsule", 0.50, 0.14, 0.88, 0.48, 0.07, steel], ["circle", 0.20, 0.25, 0.0, steel]]
		"menu":
			return [["box", 0.5, 0.28, 0.32, 0.05, white], ["box", 0.5, 0.5, 0.32, 0.05, white], ["box", 0.5, 0.72, 0.32, 0.05, white]]
		"pause":
			return [["box", 0.36, 0.5, 0.08, 0.28, white], ["box", 0.64, 0.5, 0.08, 0.28, white]]
		"play":
			return [["poly", [Vector2(0.30, 0.20), Vector2(0.80, 0.5), Vector2(0.30, 0.80)], white]]
		"stop":
			return [["box", 0.5, 0.5, 0.26, 0.26, Color(0.85, 0.35, 0.3)]]
		"attack":
			return [["capsule", 0.18, 0.18, 0.78, 0.78, 0.05, steel], ["capsule", 0.82, 0.18, 0.22, 0.78, 0.05, steel],
					["capsule", 0.62, 0.78, 0.78, 0.62, 0.05, gold], ["capsule", 0.38, 0.78, 0.22, 0.62, 0.05, gold]]
		"build":
			return [["capsule", 0.30, 0.86, 0.62, 0.40, 0.06, wood_end], ["box", 0.64, 0.30, 0.22, 0.10, steel]]
		"back":
			return [["poly", [Vector2(0.14, 0.5), Vector2(0.48, 0.18), Vector2(0.48, 0.82)], white], ["box", 0.64, 0.5, 0.22, 0.09, white]]
		"unload":
			return [["poly", [Vector2(0.5, 0.86), Vector2(0.18, 0.50), Vector2(0.82, 0.50)], white], ["box", 0.5, 0.30, 0.10, 0.20, white]]
		"research":
			return [["box", 0.5, 0.22, 0.08, 0.12, Color(0.75, 0.85, 0.9)], ["circle", 0.5, 0.62, 0.26, Color(0.75, 0.85, 0.9)],
					["circle", 0.5, 0.66, 0.19, Color(0.40, 0.85, 0.55)]]
		"ledger":
			# Cameralism: a stack of Thaler.
			return [["box", 0.5, 0.80, 0.30, 0.08, dark_gold], ["box", 0.5, 0.79, 0.28, 0.05, gold],
					["box", 0.5, 0.62, 0.30, 0.08, dark_gold], ["box", 0.5, 0.61, 0.28, 0.05, gold],
					["box", 0.5, 0.44, 0.30, 0.08, dark_gold], ["box", 0.5, 0.43, 0.28, 0.05, gold],
					["circle", 0.5, 0.24, 0.16, dark_gold], ["circle", 0.5, 0.24, 0.12, gold]]
		"fort":
			# Fortification: a shield with the Habsburg bars.
			return [["poly", [Vector2(0.18, 0.14), Vector2(0.82, 0.14), Vector2(0.80, 0.55), Vector2(0.5, 0.92), Vector2(0.20, 0.55)], steel],
					["poly", [Vector2(0.24, 0.20), Vector2(0.76, 0.20), Vector2(0.74, 0.53), Vector2(0.5, 0.84), Vector2(0.26, 0.53)], Color(0.80, 0.12, 0.15)],
					["box", 0.5, 0.42, 0.24, 0.07, white]]
		"medicine":
			# Medicine: a flask with a red cross.
			return [["box", 0.5, 0.20, 0.08, 0.12, Color(0.75, 0.85, 0.9)], ["circle", 0.5, 0.62, 0.28, Color(0.75, 0.85, 0.9)],
					["circle", 0.5, 0.64, 0.22, white], ["box", 0.5, 0.64, 0.15, 0.05, Color(0.85, 0.15, 0.15)],
					["box", 0.5, 0.64, 0.05, 0.15, Color(0.85, 0.15, 0.15)]]
		"spell":
			return [["poly", _star(0.5, 0.5, 0.42, 0.18), Color(0.70, 0.55, 1.0)], ["circle", 0.5, 0.5, 0.10, white]]
		"deploy":
			return [["box", 0.5, 0.62, 0.36, 0.16, wood], ["circle", 0.28, 0.80, 0.10, Color(0.2, 0.2, 0.2)], ["circle", 0.72, 0.80, 0.10, Color(0.2, 0.2, 0.2)]]
	return [["circle", 0.5, 0.5, 0.3, white]]


static func _star(cx: float, cy: float, r1: float, r2: float) -> Array:
	var pts: Array = []
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		var r := r1 if i % 2 == 0 else r2
		pts.append(Vector2(cx + cos(a) * r, cy + sin(a) * r))
	return pts


static func _render(shapes: Array) -> ImageTexture:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in SIZE:
		for x in SIZE:
			var acc := Color(0, 0, 0, 0)
			for sy in SS:
				for sx in SS:
					var p := Vector2((x + (sx + 0.5) / SS) / SIZE, (y + (sy + 0.5) / SS) / SIZE)
					var c := Color(0, 0, 0, 0)
					for s in shapes:
						if _inside(s, p):
							c = s[s.size() - 1]
					acc += Color(c.r * c.a, c.g * c.a, c.b * c.a, c.a)
			var n := float(SS * SS)
			acc = Color(acc.r / n, acc.g / n, acc.b / n, acc.a / n)
			if acc.a > 0.0:
				img.set_pixel(x, y, Color(acc.r / acc.a, acc.g / acc.a, acc.b / acc.a, acc.a))
	return ImageTexture.create_from_image(img)


static func _inside(s: Array, p: Vector2) -> bool:
	match s[0]:
		"circle":
			return p.distance_to(Vector2(s[1], s[2])) <= s[3]
		"box":
			return absf(p.x - s[1]) <= s[3] and absf(p.y - s[2]) <= s[4]
		"capsule":
			var a := Vector2(s[1], s[2])
			var b := Vector2(s[3], s[4])
			return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) <= s[5]
		"poly":
			return Geometry2D.is_point_in_polygon(p, PackedVector2Array(s[1]))
	return false
