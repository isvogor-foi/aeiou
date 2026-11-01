extends RefCounted
## Flags and heraldry, painted procedurally: the Habsburg imperial banner (black
## double-headed eagle on gold), the Austrian Empire's black-over-gold, Austria's
## red-white-red, the crown lands (Croatian
## chequy, Bohemian white-over-red, the Tyrolean eagle) and the Covenant's banner.
## Used on buildings, as the rally flag, in the HUD and on the title screen.

const W := 96
const H := 64

const GOLD := Color(0.96, 0.78, 0.16)
const BLACK := Color(0.07, 0.07, 0.08)
const RED := Color(0.78, 0.1, 0.14)
const WHITE := Color(0.96, 0.95, 0.92)

static var _textures := {}
static var _material_cache := {}


## `scale` paints a larger copy (e.g. for the title-screen emblem).
static func texture(kind: String, scale := 1) -> ImageTexture:
	var key := "%s@%d" % [kind, scale]
	if not _textures.has(key):
		_textures[key] = ImageTexture.create_from_image(paint(kind, scale))
	return _textures[key]


static func paint(kind: String, scale := 1) -> Image:
	var w := W * scale
	var h := H * scale
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	match kind:
		"habsburg":
			img.fill(GOLD)
			eagle(img, Vector2(w * 0.5, h * 0.56), h * 0.6, BLACK, true)
			_border(img, BLACK, 2 * scale)
		"austria":
			_bands(img, [RED, WHITE, RED])
		"empire":
			# The Austrian Empire (1804-): black over gold.
			_bands(img, [BLACK, GOLD])
		"croatia":
			# The šahovnica: a red-white chequerboard.
			var n := 5
			var cw := float(w) / n
			var ch := float(h) / n
			for y in h:
				for x in w:
					var red := (int(x / cw) + int(y / ch)) % 2 == 0
					img.set_pixel(x, y, RED if red else WHITE)
		"bohemia":
			_bands(img, [WHITE, RED])
			_lion(img, Vector2(w * 0.3, h * 0.75), h * 0.18)
		"tyrol":
			img.fill(WHITE)
			eagle(img, Vector2(w * 0.5, h * 0.52), h * 0.4, RED, false)
			_border(img, RED, 2 * scale)
		"rebel":
			img.fill(WHITE)
			_tri(img, Vector2(0, h), Vector2(w, 0), Vector2(w, h * 0.3), Color(0.5, 0.5, 0.5))
		"hungary":
			_bands(img, [RED, WHITE, Color(0.2, 0.5, 0.25)])
		"throne":
			img.fill(Color(0.1, 0.05, 0.12))
			_tri(img, Vector2(w * 0.3, h * 0.7), Vector2(w * 0.7, h * 0.7), Vector2(w * 0.5, h * 0.2), Color(0.6, 0.55, 0.65))
			_border(img, Color(0.55, 0.95, 0.4), 2 * scale)
		"blood":
			img.fill(Color(0.35, 0.03, 0.06))
			_disc(img, Vector2(w * 0.5, h * 0.55), h * 0.2, Color(0.8, 0.05, 0.1))
			_tri(img, Vector2(w * 0.4, h * 0.5), Vector2(w * 0.6, h * 0.5), Vector2(w * 0.5, h * 0.18), Color(0.8, 0.05, 0.1))
		"bone":
			img.fill(Color(0.18, 0.15, 0.13))
			for side in [-1.0, 1.0]:
				_tri(img, Vector2(w * 0.5 + side * w * 0.3, h * 0.15), Vector2(w * 0.5 + side * w * 0.22, h * 0.15), Vector2(w * 0.5 - side * w * 0.28, h * 0.85), Color(0.9, 0.87, 0.78))
		"shadow":
			img.fill(Color(0.05, 0.05, 0.08))
			_disc(img, Vector2(w * 0.5, h * 0.5), h * 0.3, Color(0.3, 0.25, 0.45))
			_disc(img, Vector2(w * 0.58, h * 0.45), h * 0.27, Color(0.05, 0.05, 0.08))
		"covenant":
			img.fill(Color(0.16, 0.07, 0.2))
			_disc(img, Vector2(w * 0.5, h * 0.45), h * 0.22, Color(0.85, 0.82, 0.72))
			_disc(img, Vector2(w * 0.43, h * 0.43), h * 0.06, Color(0.1, 0.04, 0.12))
			_disc(img, Vector2(w * 0.57, h * 0.43), h * 0.06, Color(0.1, 0.04, 0.12))
			img.fill_rect(Rect2i(int(w * 0.44), int(h * 0.62), int(w * 0.12), int(h * 0.1)), Color(0.85, 0.82, 0.72))
			_border(img, Color(0.45, 0.95, 0.4), 2 * scale)
		_:
			img.fill(GOLD)
	return img


static func _bands(img: Image, colors: Array) -> void:
	var band := float(img.get_height()) / colors.size()
	for i in colors.size():
		img.fill_rect(Rect2i(0, int(i * band), img.get_width(), ceili(band)), colors[i])


static func _border(img: Image, c: Color, t: int) -> void:
	img.fill_rect(Rect2i(0, 0, img.get_width(), t), c)
	img.fill_rect(Rect2i(0, img.get_height() - t, img.get_width(), t), c)


static func _disc(img: Image, at: Vector2, r: float, c: Color) -> void:
	for y in range(maxi(0, int(at.y - r)), mini(img.get_height(), int(at.y + r) + 1)):
		for x in range(maxi(0, int(at.x - r)), mini(img.get_width(), int(at.x + r) + 1)):
			if Vector2(x, y).distance_to(at) <= r:
				img.set_pixel(x, y, c)


static func _tri(img: Image, a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	var lo := Vector2(minf(a.x, minf(b.x, c.x)), minf(a.y, minf(b.y, c.y)))
	var hi := Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.y, maxf(b.y, c.y)))
	for y in range(maxi(0, int(lo.y)), mini(img.get_height(), int(hi.y) + 1)):
		for x in range(maxi(0, int(lo.x)), mini(img.get_width(), int(hi.x) + 1)):
			var p := Vector2(x + 0.5, y + 0.5)
			var d1 := (p - b).cross(a - b)
			var d2 := (p - c).cross(b - c)
			var d3 := (p - a).cross(c - a)
			if not ((d1 < 0 or d2 < 0 or d3 < 0) and (d1 > 0 or d2 > 0 or d3 > 0)):
				img.set_pixel(x, y, col)


## A stylised heraldic eagle (two-headed and crowned when `double`), size ~ its height.
static func eagle(img: Image, at: Vector2, size: float, col: Color, double: bool) -> void:
	var s := size
	# Body and tail.
	_disc(img, at, s * 0.2, col)
	_tri(img, at + Vector2(-s * 0.18, s * 0.1), at + Vector2(s * 0.18, s * 0.1), at + Vector2(0, s * 0.55), col)
	# Spread wings: stacked feather triangles on each side.
	for side in [-1.0, 1.0]:
		for i in 4:
			var y := -s * 0.25 + i * s * 0.14
			_tri(img, at + Vector2(side * s * 0.12, y), at + Vector2(side * s * (0.95 - i * 0.12), y - s * 0.12),
					at + Vector2(side * s * 0.12, y + s * 0.2), col)
		# Legs.
		_tri(img, at + Vector2(side * s * 0.06, s * 0.15), at + Vector2(side * s * 0.3, s * 0.4), at + Vector2(side * s * 0.16, s * 0.42), col)
	# Neck(s) and head(s), beaks in gold (or white on red eagles).
	var beak := GOLD if col == BLACK else WHITE
	var heads: Array = [-1.0, 1.0] if double else [1.0]
	for side in heads:
		var head: Vector2 = at + Vector2(side * s * (0.22 if double else 0.08), -s * 0.48)
		_tri(img, at + Vector2(side * s * 0.02, -s * 0.12), at + Vector2(side * s * 0.12, -s * 0.12), head, col)
		_disc(img, head, s * 0.1, col)
		_tri(img, head + Vector2(side * s * 0.06, -s * 0.03), head + Vector2(side * s * 0.2, 0), head + Vector2(side * s * 0.06, s * 0.05), beak)
	if double:
		# The imperial crown floating between the heads.
		var crown := at + Vector2(0, -s * 0.72)
		_tri(img, crown + Vector2(-s * 0.13, s * 0.08), crown + Vector2(s * 0.13, s * 0.08), crown + Vector2(0, -s * 0.12), col)
		_disc(img, crown + Vector2(0, -s * 0.14), s * 0.035, col)


## Bohemia's crowned white lion, simplified to a rampant silhouette.
static func _lion(img: Image, at: Vector2, s: float) -> void:
	_disc(img, at + Vector2(0, -s * 0.3), s * 0.35, WHITE)
	_tri(img, at + Vector2(-s * 0.3, -s * 0.2), at + Vector2(s * 0.3, -s * 0.2), at + Vector2(0, s * 0.6), WHITE)
	_disc(img, at + Vector2(s * 0.2, -s * 0.85), s * 0.25, WHITE)


# --- 3D flags -----------------------------------------------------------------------

static func _cloth_material(kind: String) -> ShaderMaterial:
	if not _material_cache.has(kind):
		var m := ShaderMaterial.new()
		m.shader = load("res://view3d/shaders/flag.gdshader")
		m.set_shader_parameter("flag_tex", texture(kind))
		_material_cache[kind] = m
	return _material_cache[kind]


## A flagpole `height` tall with a waving flag of `kind` at the top (in world tiles).
static func make(kind: String, height := 1.6, width := 0.75) -> Node3D:
	var root := Node3D.new()
	var pole := CylinderMesh.new()
	pole.top_radius = 0.025
	pole.bottom_radius = 0.035
	pole.height = height
	pole.radial_segments = 6
	pole.rings = 1
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.3, 0.22, 0.14)
	var pmi := MeshInstance3D.new()
	pmi.mesh = pole
	pmi.material_override = pole_mat
	pmi.position.y = height * 0.5
	root.add_child(pmi)
	var knob := SphereMesh.new()
	knob.radius = 0.05
	knob.height = 0.1
	var knob_mat := StandardMaterial3D.new()
	knob_mat.albedo_color = GOLD
	knob_mat.metallic = 0.7
	var kmi := MeshInstance3D.new()
	kmi.mesh = knob
	kmi.material_override = knob_mat
	kmi.position.y = height + 0.04
	root.add_child(kmi)
	# The cloth: a subdivided plane hanging off the pole, rippled by the shader.
	var cloth := PlaneMesh.new()
	cloth.size = Vector2(width, width * H / W)
	cloth.subdivide_width = 10
	cloth.subdivide_depth = 2
	cloth.orientation = PlaneMesh.FACE_Z
	var cmi := MeshInstance3D.new()
	cmi.mesh = cloth
	var mat := _cloth_material(kind).duplicate() as ShaderMaterial
	mat.set_shader_parameter("phase", randf() * TAU)
	cmi.material_override = mat
	cmi.position = Vector3(width * 0.5 + 0.03, height - width * H / W * 0.5 - 0.02, 0)
	cmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(cmi)
	root.set_meta("flag", kind)
	return root
