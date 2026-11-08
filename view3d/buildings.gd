extends RefCounted
## Steampunk buildings, built in code from primitives and baked into one mesh per
## material (cached per kind, style and owner colour). Turning cogs, flywheels,
## smoke and lights stay live nodes (see Gear._bake).
##
## The Monarchy builds in Schönbrunn ochre and brick with verdigris copper domes,
## brass trim, gas-lit windows, smokestacks and glowing Aether tanks. The Covenant
## builds in blackened iron and bone, with green soul-furnaces and spires.
## Cities change their design with the crown land (or dark pact) they proclaim,
## and Hungary's insurgent cities have their own.
##
## Origin is the centre of the footprint on the ground; the front faces +Z.
## Sizes are in tiles; `n` is the footprint width.

const Gear = preload("res://view3d/gear.gd")

static var _cache := {}

## Palettes. Crown lands and pacts override parts of their faction's palette.
const MONARCHY := {
	"wall": Color(0.84, 0.69, 0.4), "wall2": Color(0.52, 0.28, 0.2), "base": Color(0.42, 0.4, 0.38),
	"roof": Color(0.32, 0.56, 0.48), "trim": Color(0.86, 0.66, 0.28), "dark": Color(0.18, 0.18, 0.2),
	"window": Color(1.0, 0.72, 0.32), "glow": Color(0.4, 0.85, 1.0), "accent": Color(0.78, 0.42, 0.25),
	"necro": false,
}
const COVENANT := {
	"wall": Color(0.22, 0.2, 0.24), "wall2": Color(0.32, 0.28, 0.3), "base": Color(0.16, 0.15, 0.17),
	"roof": Color(0.11, 0.1, 0.12), "trim": Color(0.82, 0.78, 0.66), "dark": Color(0.08, 0.08, 0.09),
	"window": Color(0.45, 1.0, 0.45), "glow": Color(0.45, 1.0, 0.45), "accent": Color(0.4, 0.34, 0.3),
	"necro": true,
}
const STYLES := {
	# Monarchy crown lands.
	"austria": {},
	"croatia": {"wall": Color(0.86, 0.84, 0.78), "roof": Color(0.66, 0.16, 0.14), "accent": Color(0.2, 0.3, 0.55)},
	"carniola": {"wall": Color(0.7, 0.72, 0.74), "roof": Color(0.2, 0.32, 0.6), "glow": Color(0.85, 0.9, 1.0), "accent": Color(0.75, 0.78, 0.82)},
	"bohemia": {"wall": Color(0.9, 0.88, 0.82), "roof": Color(0.2, 0.2, 0.24), "trim": Color(0.92, 0.74, 0.25), "accent": Color(0.7, 0.14, 0.14)},
	"galicia": {"wall": Color(0.62, 0.36, 0.26), "roof": Color(0.3, 0.42, 0.66), "accent": Color(0.15, 0.15, 0.16)},
	"transylvania": {"wall": Color(0.76, 0.7, 0.6), "roof": Color(0.6, 0.22, 0.14), "accent": Color(0.25, 0.35, 0.6)},
	# The Hungarian insurrection.
	"hungary": {"wall": Color(0.86, 0.82, 0.72), "roof": Color(0.22, 0.48, 0.28), "trim": Color(0.8, 0.66, 0.3), "accent": Color(0.75, 0.15, 0.13)},
	# Covenant pacts.
	"throne": {},
	"blood": {"glow": Color(1.0, 0.25, 0.2), "window": Color(1.0, 0.3, 0.2), "wall": Color(0.26, 0.14, 0.16)},
	"bone": {"wall": Color(0.62, 0.58, 0.5), "roof": Color(0.3, 0.27, 0.24)},
	"shadow": {"glow": Color(0.7, 0.45, 1.0), "window": Color(0.7, 0.45, 1.0), "wall": Color(0.16, 0.13, 0.22)},
}


## `style` is a crown land / pact / "hungary", or "" for the faction's default.
static func build(kind: String, faction: String, team: Color, style := "") -> Node3D:
	var key := "%s/%s/%s/%s" % [kind, faction, style, team.to_html()]
	if not _cache.has(key):
		_cache[key] = Gear._bake(_raw(kind, faction, team, style))
	var src: Dictionary = _cache[key]
	var root := Node3D.new()
	if src.mesh:
		var mi := MeshInstance3D.new()
		mi.mesh = src.mesh
		root.add_child(mi)
	for extra in src.live:
		root.add_child(extra.duplicate())
	return root


static func palette(faction: String, team: Color, style: String) -> Dictionary:
	var p: Dictionary = (COVENANT if faction == "covenant" else MONARCHY).duplicate()
	p.merge(STYLES.get(style, {}), true)
	p.team = team
	p.style = style
	return p


static func _raw(kind: String, faction: String, team: Color, style: String) -> Node3D:
	var P := palette(faction, team, style)
	var r := Node3D.new()
	var necro: bool = P.necro
	match kind:
		"residenz":
			_city(r, P, style if style != "" else "austria")
		"citadel":
			_citadel(r, P)
		"dwelling":
			_crypt_house(r, P) if necro else _townhouse(r, P)
		"storehouse":
			_vault(r, P) if necro else _warehouse(r, P)
		"garden":
			_blight_garden(r, P) if necro else _glasshouse(r, P)
		"library":
			_grimoire_tower(r, P) if necro else _observatory(r, P)
		"kaserne":
			_kaserne(r, P)
		"blood_pit":
			_blood_pit(r, P)
		"schiessstand":
			_range(r, P)
		"bone_range":
			_bone_range(r, P)
		"laboratorium":
			_laboratorium(r, P)
		"ossuary":
			_ossuary(r, P)
		"festungsturm":
			_gun_tower(r, P)
		"bone_spire":
			_bone_spire(r, P)
		"adlerhorst":
			_airship_mast(r, P)
		"roost":
			_roost(r, P)
		"fabrik":
			_fabrik(r, P)
		"charnel_works":
			_charnel_works(r, P)
		"orloj":
			_orloj(r, P)
		"pummerin":
			_cathedral(r, P)
		"hofburg_treasury":
			_treasury(r, P)
		"obsidian_spire":
			_obsidian_spire(r, P)
		"great_ossuary":
			_great_ossuary(r, P)
		"scaffold":
			_scaffold(r, P, 3.0)
	return r


# --- Materials ---------------------------------------------------------------------

static func m(c: Color, metal := 0.0, rough := 0.75) -> StandardMaterial3D:
	return Gear.mat(c, 0.0, metal, rough)


static func glow(c: Color, energy := 2.2) -> StandardMaterial3D:
	return Gear.mat(c, energy)


static func wall(P: Dictionary) -> Material:
	return m(P.wall, 0.0, 0.85)


static func brick(P: Dictionary) -> Material:
	return m(P.wall2, 0.0, 0.9)


static func base(P: Dictionary) -> Material:
	return m(P.base, 0.0, 0.9)


static func roof(P: Dictionary) -> Material:
	return m(P.roof, 0.45, 0.5)


static func trim(P: Dictionary) -> Material:
	return m(P.trim, 0.75, 0.35) if not P.necro else m(P.trim, 0.0, 0.7)


static func iron(P: Dictionary) -> Material:
	return m(P.dark, 0.6, 0.5)


static func team(P: Dictionary) -> Material:
	return m(P.team, 0.0, 0.7)


static func window(P: Dictionary) -> Material:
	return glow(P.window, 1.6)


# --- Primitives -------------------------------------------------------------------

static func part(r: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scale := Vector3.ONE) -> MeshInstance3D:
	return Gear.part(r, mesh, mat, pos, rot, scale)


static func box(r: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> void:
	part(r, Gear.box(size), mat, pos, rot)


static func cyl(r: Node3D, rad: float, h: float, pos: Vector3, mat: Material, top := -1.0, segs := 16, rot := Vector3.ZERO) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.bottom_radius = rad
	c.top_radius = rad if top < 0.0 else top
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	return part(r, c, mat, pos, rot)


static func sphere(r: Node3D, rad: float, pos: Vector3, mat: Material, hemi := false, squash := 1.0) -> void:
	var s := SphereMesh.new()
	s.radius = rad
	s.height = rad * (1.0 if hemi else 2.0)
	s.radial_segments = 18
	s.rings = 9
	s.is_hemisphere = hemi
	part(r, s, mat, pos, Vector3.ZERO, Vector3(1, squash, 1))


## A beam from `a` to `b` (girders, struts, lattice).
static func beam(r: Node3D, a: Vector3, b: Vector3, w: float, mat: Material) -> void:
	var mi := part(r, Gear.box(Vector3(w, a.distance_to(b), w)), mat, (a + b) * 0.5)
	var dir := (b - a).normalized()
	if absf(dir.dot(Vector3.UP)) < 0.999:
		mi.basis = Basis(Quaternion(Vector3.UP, dir))


## A wall block standing on y=0 at `pos` (bottom centre): stone plinth, cornice,
## and rows of lit windows on the front and sides.
static func block(r: Node3D, P: Dictionary, size: Vector3, pos: Vector3, rows := 1, mat: Material = null) -> void:
	box(r, size, pos + Vector3(0, size.y * 0.5, 0), mat if mat else wall(P))
	box(r, Vector3(size.x + 0.06, 0.14, size.z + 0.06), pos + Vector3(0, 0.07, 0), base(P))
	# Flat roof (hidden under any roof added on top) and a cornice band around it.
	box(r, Vector3(size.x - 0.02, 0.02, size.z - 0.02), pos + Vector3(0, size.y + 0.005, 0), roof(P))
	var cy: float = pos.y + size.y - 0.02
	for side in [-1.0, 1.0]:
		box(r, Vector3(size.x + 0.08, 0.07, 0.05), Vector3(pos.x, cy, pos.z + side * (size.z * 0.5 + 0.015)), trim(P))
		box(r, Vector3(0.05, 0.07, size.z + 0.08), Vector3(pos.x + side * (size.x * 0.5 + 0.015), cy, pos.z), trim(P))
	var win := window(P)
	for row in rows:
		var y: float = pos.y + 0.32 + (size.y - 0.42) * (row + 0.5) / rows
		var nx := maxi(1, int(size.x / 0.42))
		for i in nx:
			var x: float = pos.x - size.x * 0.5 + size.x * (i + 0.5) / nx
			box(r, Vector3(0.13, 0.2, 0.02), Vector3(x, y, pos.z + size.z * 0.5 + 0.01), win)
			box(r, Vector3(0.18, 0.03, 0.04), Vector3(x, y - 0.12, pos.z + size.z * 0.5 + 0.02), trim(P))
		var nz := maxi(1, int(size.z / 0.42))
		for i in nz:
			var z: float = pos.z - size.z * 0.5 + size.z * (i + 0.5) / nz
			for side in [-1.0, 1.0]:
				box(r, Vector3(0.02, 0.2, 0.13), Vector3(pos.x + side * (size.x * 0.5 + 0.01), y, z), win)


## A hipped roof (square frustum) over a w x d block whose top is at `y`.
static func hip_roof(r: Node3D, P: Dictionary, w: float, d: float, h: float, pos: Vector3, mat: Material = null) -> void:
	var mi := cyl(r, 0.7071, h, pos + Vector3(0, h * 0.5, 0), mat if mat else roof(P), 0.18, 4, Vector3(0, PI / 4, 0))
	mi.scale = Vector3(w, 1, d)
	# Scaling a rotated mesh skews it, so bake the 45 degree turn into the basis instead.
	mi.basis = Basis().scaled(Vector3(w, 1, d)) * Basis(Vector3.UP, PI / 4)


## A copper dome with a brass ring, a little lantern and a finial.
static func dome(r: Node3D, P: Dictionary, rad: float, pos: Vector3, mat: Material = null, onion := false) -> void:
	cyl(r, rad * 1.04, 0.08, pos + Vector3(0, 0.04, 0), trim(P))
	if onion:
		sphere(r, rad, pos + Vector3(0, rad * 0.75, 0), mat if mat else roof(P), false, 1.1)
		cyl(r, rad * 0.25, rad * 0.9, pos + Vector3(0, rad * 2.0, 0), mat if mat else roof(P), 0.0)
	else:
		sphere(r, rad, pos + Vector3(0, 0.06, 0), mat if mat else roof(P), true)
		cyl(r, rad * 0.22, rad * 0.35, pos + Vector3(0, rad + 0.2, 0), trim(P))
		cyl(r, rad * 0.06, rad * 0.6, pos + Vector3(0, rad + 0.6, 0), trim(P), 0.0)
		sphere(r, rad * 0.08, pos + Vector3(0, rad + 0.42, 0), glow(P.glow))


## A round tower with a window band, cornice and a roof (cone, dome or flat).
static func tower(r: Node3D, P: Dictionary, rad: float, h: float, pos: Vector3, top := "cone", mat: Material = null) -> void:
	cyl(r, rad, h, pos + Vector3(0, h * 0.5, 0), mat if mat else wall(P))
	cyl(r, rad * 1.08, 0.16, pos + Vector3(0, 0.08, 0), base(P))
	cyl(r, rad * 1.1, 0.07, pos + Vector3(0, h, 0), trim(P))
	var win := window(P)
	for i in 6:
		var a := TAU * i / 6.0
		box(r, Vector3(0.1, 0.18, 0.02), pos + Vector3(sin(a) * rad, h * 0.7, cos(a) * rad), win, Vector3(0, a, 0))
	cyl(r, rad * 0.99, 0.02, pos + Vector3(0, h + 0.005, 0), roof(P))
	match top:
		"cone":
			cyl(r, rad * 1.15, rad * 2.0, pos + Vector3(0, h + rad, 0), roof(P), 0.0)
		"dome":
			dome(r, P, rad, pos + Vector3(0, h, 0))
		"onion":
			dome(r, P, rad * 0.9, pos + Vector3(0, h, 0), null, true)
		"crenel":
			for i in 8:
				var a := TAU * i / 8.0
				box(r, Vector3(0.12, 0.14, 0.12), pos + Vector3(sin(a) * rad, h + 0.1, cos(a) * rad), mat if mat else wall(P))


## A brick smokestack with brass bands and live smoke.
static func stack(r: Node3D, P: Dictionary, pos: Vector3, h: float, rad := 0.13, smoking := true) -> void:
	cyl(r, rad, h, pos + Vector3(0, h * 0.5, 0), brick(P) if not P.necro else iron(P), rad * 0.8)
	for y in [0.3, 0.65]:
		cyl(r, rad * 1.05, 0.05, pos + Vector3(0, h * y, 0), trim(P))
	cyl(r, rad * 1.1, 0.12, pos + Vector3(0, h, 0), iron(P), rad * 1.25)
	if smoking:
		var smoke := Gear.smoke_plume(P.necro)
		smoke.position = pos + Vector3(0, h + 0.1, 0)
		smoke.scale = Vector3.ONE * (1.4 + rad * 4.0)
		r.add_child(smoke)


## A glass tank of glowing Aether (or souls) in a brass cage.
static func tank(r: Node3D, P: Dictionary, rad: float, h: float, pos: Vector3) -> void:
	cyl(r, rad * 0.92, h, pos + Vector3(0, h * 0.5, 0), glow(P.glow, 1.8))
	for y in [0.0, 0.5, 1.0]:
		cyl(r, rad, 0.06, pos + Vector3(0, h * y, 0), trim(P))
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4
		cyl(r, 0.025, h, pos + Vector3(sin(a) * rad, h * 0.5, cos(a) * rad), iron(P))
	cyl(r, rad * 0.6, rad * 0.6, pos + Vector3(0, h + rad * 0.3, 0), iron(P), rad * 0.2)


## A turning cog mounted on the wall at `pos`, facing `facing` (radians about Y).
static func wall_cog(r: Node3D, P: Dictionary, rad: float, pos: Vector3, facing := 0.0, speed := 0.6) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = facing
	r.add_child(holder)
	var spinner := Node3D.new()
	spinner.set_meta("spin_z", speed)
	holder.add_child(spinner)
	Gear.cog(spinner, rad, trim(P) if not P.necro else iron(P), Vector3.ZERO, Vector3(PI / 2, 0, 0), 12)


## A big spoked flywheel (steam engine), turning about the X axis.
static func flywheel(r: Node3D, P: Dictionary, rad: float, pos: Vector3, speed := 1.2) -> void:
	# The wheel stands in the XY plane, facing the camera (+Z), and turns about Z.
	var spinner := Node3D.new()
	spinner.position = pos
	spinner.set_meta("spin_z", speed)
	r.add_child(spinner)
	part(spinner, Gear.torus(rad * 0.86, rad), iron(P), Vector3.ZERO, Vector3(PI / 2, 0, 0))
	for i in 3:
		var mi := part(spinner, Gear.box(Vector3(0.05, rad * 1.75, 0.05)), trim(P), Vector3.ZERO)
		mi.rotation.z = PI * i / 3.0
	cyl(r, 0.06, 0.3, pos, iron(P), -1.0, 8, Vector3(PI / 2, 0, 0))


## Four girder legs with cross bracing, from y0 to y1, `w` wide.
static func lattice(r: Node3D, P: Dictionary, w0: float, w1: float, y0: float, y1: float, pos: Vector3, levels := 4) -> void:
	var mat := iron(P)
	var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for i in 4:
		var c: Vector2 = corners[i]
		beam(r, pos + Vector3(c.x * w0, y0, c.y * w0), pos + Vector3(c.x * w1, y1, c.y * w1), 0.05, mat)
	for l in levels:
		var t0 := float(l) / levels
		var t1 := float(l + 1) / levels
		var wa := lerpf(w0, w1, t0)
		var wb := lerpf(w0, w1, t1)
		var ya := lerpf(y0, y1, t0)
		var yb := lerpf(y0, y1, t1)
		for i in 4:
			var c0: Vector2 = corners[i]
			var c1: Vector2 = corners[(i + 1) % 4]
			beam(r, pos + Vector3(c0.x * wa, ya, c0.y * wa), pos + Vector3(c1.x * wb, yb, c1.y * wb), 0.025, mat)
			beam(r, pos + Vector3(c0.x * wb, yb, c0.y * wb), pos + Vector3(c1.x * wb, yb, c1.y * wb), 0.03, mat)


## A team-coloured banner hanging on a wall face.
static func banner(r: Node3D, P: Dictionary, pos: Vector3, h := 0.7) -> void:
	box(r, Vector3(0.32, h, 0.02), pos + Vector3(0, -h * 0.5, 0), team(P))
	box(r, Vector3(0.38, 0.04, 0.04), pos, trim(P))
	box(r, Vector3(0.12, 0.12, 0.025), pos + Vector3(0, -h * 0.45, 0.005), trim(P))


## A Tesla coil: a rod with stacked rings and a crackling sphere.
static func tesla(r: Node3D, P: Dictionary, pos: Vector3, h: float) -> void:
	cyl(r, 0.06, h, pos + Vector3(0, h * 0.5, 0), iron(P))
	for i in 4:
		var y := h * (0.45 + 0.12 * i)
		part(r, Gear.torus(0.06, 0.16 - i * 0.02), trim(P), pos + Vector3(0, y, 0))
	sphere(r, 0.14, pos + Vector3(0, h + 0.1, 0), glow(P.glow, 3.0))
	var light := OmniLight3D.new()
	light.light_color = P.glow
	light.light_energy = 1.2
	light.omni_range = 2.5
	light.position = pos + Vector3(0, h + 0.1, 0)
	light.set_meta("live", true)
	r.add_child(light)


static func pipes(r: Node3D, P: Dictionary, points: Array, rad := 0.04) -> void:
	Gear.pipe(r, points, rad, m(P.accent, 0.7, 0.4) if not P.necro else iron(P))


## A tall bone or iron spike.
static func spike(r: Node3D, P: Dictionary, pos: Vector3, h: float, rad := 0.08, lean := Vector3.ZERO) -> void:
	cyl(r, rad, h, pos + Vector3(0, h * 0.5, 0), trim(P), 0.0, 8, lean)


# --- Monarchy: cities ---------------------------------------------------------------

## The Residenz, in the design of its crown land.
static func _city(r: Node3D, P: Dictionary, land: String) -> void:
	match land:
		"croatia":
			_city_croatia(r, P)
		"carniola":
			_city_carniola(r, P)
		"bohemia":
			_city_bohemia(r, P)
		"galicia":
			_city_galicia(r, P)
		"transylvania":
			_city_transylvania(r, P)
		"hungary":
			_city_hungary(r, P)
		_:
			_city_austria(r, P)


## Austria: a Schönbrunn palace with a great verdigris dome, twin Aether tanks,
## a clock and a lattice Aether mast.
static func _city_austria(r: Node3D, P: Dictionary) -> void:
	box(r, Vector3(3.7, 0.2, 3.7), Vector3(0, 0.1, 0), base(P))
	block(r, P, Vector3(3.4, 1.0, 1.3), Vector3(0, 0.2, 0.9), 2)
	block(r, P, Vector3(1.0, 1.0, 1.9), Vector3(-1.2, 0.2, -0.5), 2)
	block(r, P, Vector3(1.0, 1.0, 1.9), Vector3(1.2, 0.2, -0.5), 2)
	hip_roof(r, P, 3.4, 1.3, 0.35, Vector3(0, 1.2, 0.9))
	hip_roof(r, P, 1.0, 1.9, 0.35, Vector3(-1.2, 1.2, -0.5))
	hip_roof(r, P, 1.0, 1.9, 0.35, Vector3(1.2, 1.2, -0.5))
	# Central drum and dome.
	tower(r, P, 0.75, 1.9, Vector3(0, 0.2, -0.2), "")
	dome(r, P, 0.82, Vector3(0, 2.1, -0.2))
	_clock(r, P, Vector3(0, 1.5, 0.56), 0.28)
	tank(r, P, 0.2, 0.9, Vector3(-1.45, 0.2, 1.45))
	tank(r, P, 0.2, 0.9, Vector3(1.45, 0.2, 1.45))
	lattice(r, P, 0.12, 0.03, 3.3, 4.6, Vector3(0, 0, -0.2), 3)
	sphere(r, 0.09, Vector3(0, 4.65, -0.2), glow(P.glow, 3.0))
	banner(r, P, Vector3(-0.6, 1.1, 1.56))
	banner(r, P, Vector3(0.6, 1.1, 1.56))
	wall_cog(r, P, 0.28, Vector3(-1.2, 0.75, 0.45), 0.0)


## Croatia: a frontier fortress, white walls and red roofs, round bastions with
## steam cannon and a chequered gate tower.
static func _city_croatia(r: Node3D, P: Dictionary) -> void:
	box(r, Vector3(3.7, 0.2, 3.7), Vector3(0, 0.1, 0), base(P))
	for c in [Vector2(-1.4, -1.4), Vector2(1.4, -1.4), Vector2(-1.4, 1.4), Vector2(1.4, 1.4)]:
		tower(r, P, 0.45, 1.3, Vector3(c.x, 0.2, c.y), "crenel")
		cyl(r, 0.07, 0.7, Vector3(c.x, 1.6, c.y) + Vector3(c.x, 0, c.y).normalized() * 0.3, iron(P), -1.0, 8, Vector3(PI / 2.6, atan2(c.x, c.y), 0))
	for s in [Vector3(0, 0, 1.4), Vector3(0, 0, -1.4)]:
		box(r, Vector3(2.4, 0.9, 0.3), s + Vector3(0, 0.65, 0), wall(P))
	for s in [Vector3(1.4, 0, 0), Vector3(-1.4, 0, 0)]:
		box(r, Vector3(0.3, 0.9, 2.4), s + Vector3(0, 0.65, 0), wall(P))
	block(r, P, Vector3(1.6, 1.6, 1.4), Vector3(0, 0.2, -0.2), 2)
	hip_roof(r, P, 1.6, 1.4, 0.6, Vector3(0, 1.8, -0.2))
	# Gate tower with the chequered shield.
	block(r, P, Vector3(0.9, 2.3, 0.8), Vector3(0, 0.2, 1.2), 3)
	hip_roof(r, P, 0.9, 0.8, 0.7, Vector3(0, 2.5, 1.2))
	for i in 9:
		box(r, Vector3(0.1, 0.1, 0.02), Vector3(-0.1 + (i % 3) * 0.1, 1.9 - (i / 3) * 0.1, 1.61), m(Color(0.75, 0.12, 0.12) if (i % 2) == 0 else Color(0.95, 0.95, 0.92)))
	stack(r, P, Vector3(0.6, 1.8, -0.5), 1.0, 0.13, false)
	banner(r, P, Vector3(-0.8, 1.4, 1.56))


## Carniola: an Idrija mine-castle: a winding headframe with a turning sheave,
## silver quicksilver tanks and blue roofs.
static func _city_carniola(r: Node3D, P: Dictionary) -> void:
	box(r, Vector3(3.7, 0.2, 3.7), Vector3(0, 0.1, 0), base(P))
	block(r, P, Vector3(2.0, 1.3, 1.6), Vector3(-0.6, 0.2, 0.5), 2)
	hip_roof(r, P, 2.0, 1.6, 0.6, Vector3(-0.6, 1.5, 0.5))
	tower(r, P, 0.4, 2.0, Vector3(-1.3, 0.2, 1.2), "onion")
	# Headframe.
	lattice(r, P, 0.55, 0.25, 0.2, 3.6, Vector3(1.0, 0, -0.7), 5)
	flywheel(r, P, 0.45, Vector3(1.0, 3.7, -0.7), 0.9)
	beam(r, Vector3(1.0, 3.7, -0.7), Vector3(0.0, 0.3, -1.4), 0.05, iron(P))
	for i in 3:
		tank(r, P, 0.22, 0.8, Vector3(0.5 + i * 0.5, 0.2, 1.3))
	box(r, Vector3(1.0, 0.5, 0.9), Vector3(1.0, 0.45, -0.7), brick(P))
	stack(r, P, Vector3(1.6, 0.2, 0.3), 2.4)
	banner(r, P, Vector3(-0.6, 1.2, 1.31))


## Bohemia: a Prague skyline: white walls, dark slate spires tipped with gold and
## an astronomical clock.
static func _city_bohemia(r: Node3D, P: Dictionary) -> void:
	box(r, Vector3(3.7, 0.2, 3.7), Vector3(0, 0.1, 0), base(P))
	block(r, P, Vector3(3.0, 1.3, 1.6), Vector3(0, 0.2, 0.6), 2)
	hip_roof(r, P, 3.0, 1.6, 0.9, Vector3(0, 1.5, 0.6))
	# Týn-like twin spires.
	for x in [-0.55, 0.55]:
		box(r, Vector3(0.7, 2.6, 0.7), Vector3(x, 1.5, -0.8), wall(P))
		cyl(r, 0.5, 1.6, Vector3(x, 3.6, -0.8), roof(P), 0.0, 4, Vector3(0, PI / 4, 0))
		for c in [Vector2(-0.3, -0.3), Vector2(0.3, -0.3), Vector2(-0.3, 0.3), Vector2(0.3, 0.3)]:
			cyl(r, 0.08, 0.6, Vector3(x + c.x, 3.1, -0.8 + c.y), roof(P), 0.0, 6)
		sphere(r, 0.07, Vector3(x, 4.45, -0.8), trim(P))
	_clock(r, P, Vector3(0, 1.0, 1.41), 0.32)
	sphere(r, 0.16, Vector3(0, 1.0, 1.43), glow(P.glow, 1.5))
	tank(r, P, 0.18, 0.7, Vector3(1.4, 0.2, 1.5))
	banner(r, P, Vector3(-1.0, 1.3, 1.41))
	banner(r, P, Vector3(1.0, 1.3, 1.41))


## Galicia: brick and blue onion domes over the Boryslav oil fields: derricks and
## a nodding pumpjack.
static func _city_galicia(r: Node3D, P: Dictionary) -> void:
	box(r, Vector3(3.7, 0.2, 3.7), Vector3(0, 0.1, 0), base(P))
	block(r, P, Vector3(2.4, 1.4, 1.5), Vector3(-0.3, 0.2, 0.3), 2, brick(P))
	hip_roof(r, P, 2.4, 1.5, 0.4, Vector3(-0.3, 1.6, 0.3))
	tower(r, P, 0.5, 1.6, Vector3(-0.3, 1.6, 0.3), "onion", brick(P))
	tower(r, P, 0.3, 1.8, Vector3(-1.4, 0.2, 1.3), "onion", brick(P))
	tower(r, P, 0.3, 1.8, Vector3(0.8, 0.2, 1.3), "onion", brick(P))
	for c in [Vector3(1.3, 0, -1.0), Vector3(-1.2, 0, -1.3)]:
		lattice(r, P, 0.32, 0.06, 0.2, 2.9, c, 4)
	# Pumpjack.
	box(r, Vector3(0.12, 0.6, 0.12), Vector3(1.4, 0.5, 0.2), iron(P))
	var beamnode := Node3D.new()
	beamnode.position = Vector3(1.4, 0.82, 0.2)
	beamnode.set_meta("nod", 0.25)
	r.add_child(beamnode)
	box(beamnode, Vector3(0.08, 0.08, 1.0), Vector3.ZERO, iron(P))
	box(beamnode, Vector3(0.14, 0.2, 0.12), Vector3(0, 0, 0.5), iron(P))
	stack(r, P, Vector3(0.3, 0.2, -1.2), 2.2)
	banner(r, P, Vector3(-0.3, 1.3, 1.06))


## Transylvania: a Saxon fortress-church: a ring wall with turrets around a tall
## church tower under a steep red roof.
static func _city_transylvania(r: Node3D, P: Dictionary) -> void:
	box(r, Vector3(3.7, 0.2, 3.7), Vector3(0, 0.1, 0), base(P))
	for i in 12:
		var a := TAU * i / 12.0
		var p := Vector3(sin(a), 0, cos(a)) * 1.6
		box(r, Vector3(0.88, 0.85, 0.22), p + Vector3(0, 0.6, 0), wall(P), Vector3(0, a, 0))
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4
		tower(r, P, 0.3, 1.3, Vector3(sin(a), 0, cos(a)) * 1.6 + Vector3(0, 0.2, 0), "cone")
	block(r, P, Vector3(1.0, 1.0, 2.0), Vector3(0, 0.2, 0.2), 1)
	hip_roof(r, P, 1.0, 2.0, 0.9, Vector3(0, 1.2, 0.2))
	block(r, P, Vector3(0.8, 2.8, 0.8), Vector3(0, 0.2, -0.9), 3)
	# The defensive gallery and the steep pyramid roof.
	box(r, Vector3(1.0, 0.3, 1.0), Vector3(0, 3.15, -0.9), m(Color(0.4, 0.28, 0.18)))
	cyl(r, 0.75, 1.4, Vector3(0, 4.0, -0.9), roof(P), 0.0, 4, Vector3(0, PI / 4, 0))
	_clock(r, P, Vector3(0, 2.6, -0.48), 0.2)
	tank(r, P, 0.15, 0.6, Vector3(0.9, 0.2, 0.9))
	stack(r, P, Vector3(-0.8, 0.2, 0.9), 1.6, 0.1, false)


## Hungary: a neo-Gothic parliament: long wings, pinnacles and a ribbed dome with
## a slender spire, roofed in green and trimmed red.
static func _city_hungary(r: Node3D, P: Dictionary) -> void:
	box(r, Vector3(3.7, 0.2, 3.7), Vector3(0, 0.1, 0), base(P))
	block(r, P, Vector3(3.5, 1.2, 1.4), Vector3(0, 0.2, 0.4), 2)
	hip_roof(r, P, 3.5, 1.4, 0.7, Vector3(0, 1.4, 0.4))
	for x in [-1.6, -0.9, 0.9, 1.6]:
		cyl(r, 0.08, 0.9, Vector3(x, 1.85, 1.1), trim(P), 0.0, 6)
	tower(r, P, 0.65, 1.3, Vector3(0, 1.4, 0.0), "")
	sphere(r, 0.75, Vector3(0, 2.7, 0.0), roof(P), true, 1.3)
	cyl(r, 0.08, 1.4, Vector3(0, 4.3, 0.0), trim(P), 0.0, 8)
	box(r, Vector3(1.4, 0.9, 1.0), Vector3(0, 0.65, -1.2), wall(P))
	banner(r, P, Vector3(-0.9, 1.25, 1.11))
	banner(r, P, Vector3(0.9, 1.25, 1.11))
	stack(r, P, Vector3(1.4, 0.2, -1.3), 1.8, 0.13, false)


static func _clock(r: Node3D, P: Dictionary, pos: Vector3, rad: float) -> void:
	cyl(r, rad * 1.1, 0.04, pos, trim(P), -1.0, 20, Vector3(PI / 2, 0, 0))
	cyl(r, rad, 0.05, pos + Vector3(0, 0, 0.01), m(Color(0.92, 0.88, 0.76)), -1.0, 20, Vector3(PI / 2, 0, 0))
	var hand := Node3D.new()
	hand.set_meta("spin_z", 0.5)
	hand.position = pos + Vector3(0, 0, 0.05)
	r.add_child(hand)
	part(hand, Gear.box(Vector3(0.03, rad * 0.8, 0.02)), iron(P), Vector3(0, rad * 0.35, 0))


# --- Monarchy: economy -------------------------------------------------------------

## Dwelling: a two-storey tenement with a copper mansard and a boiler chimney.
static func _townhouse(r: Node3D, P: Dictionary) -> void:
	block(r, P, Vector3(1.5, 1.1, 1.3), Vector3(0, 0, 0), 2)
	hip_roof(r, P, 1.5, 1.3, 0.55, Vector3(0, 1.1, 0))
	for x in [-0.35, 0.35]:
		box(r, Vector3(0.22, 0.22, 0.18), Vector3(x, 1.38, 0.5), wall(P))
		box(r, Vector3(0.12, 0.13, 0.02), Vector3(x, 1.38, 0.6), window(P))
	stack(r, P, Vector3(0.5, 1.0, -0.4), 0.7, 0.08, false)
	pipes(r, P, [Vector3(-0.78, 0.1, 0.3), Vector3(-0.78, 0.9, 0.3), Vector3(-0.5, 1.2, 0.3)])
	box(r, Vector3(0.3, 0.45, 0.04), Vector3(0, 0.36, 0.67), m(Color(0.35, 0.22, 0.14)))


## Storehouse: a riveted iron warehouse with a barrel roof and a steam crane.
static func _warehouse(r: Node3D, P: Dictionary) -> void:
	block(r, P, Vector3(1.6, 0.9, 1.2), Vector3(0, 0, 0), 1, brick(P))
	cyl(r, 0.6, 1.6, Vector3(0, 0.9, 0), roof(P), -1.0, 16, Vector3(0, 0, PI / 2)).scale = Vector3(1, 1, 0.55)
	box(r, Vector3(0.6, 0.6, 0.04), Vector3(0, 0.4, 0.62), m(Color(0.3, 0.3, 0.32), 0.6))
	cyl(r, 0.05, 1.6, Vector3(0.75, 0.8, 0.75), iron(P))
	beam(r, Vector3(0.75, 1.5, 0.75), Vector3(0.1, 1.7, 0.95), 0.05, iron(P))
	cyl(r, 0.01, 0.5, Vector3(0.1, 1.45, 0.95), iron(P))
	box(r, Vector3(0.22, 0.2, 0.22), Vector3(0.1, 1.1, 0.95), m(Color(0.5, 0.36, 0.2)))
	for c in [Vector3(-0.6, 0.12, 0.8), Vector3(-0.35, 0.12, 0.85), Vector3(-0.48, 0.34, 0.82)]:
		box(r, Vector3(0.22, 0.22, 0.22), c, m(Color(0.55, 0.4, 0.22)))
	wall_cog(r, P, 0.2, Vector3(0.55, 0.65, 0.63))


## Garden (provisions): a brass-framed glasshouse full of Aether-lit crops.
static func _glasshouse(r: Node3D, P: Dictionary) -> void:
	box(r, Vector3(1.7, 0.15, 1.5), Vector3(0, 0.075, 0), base(P))
	var glass := Gear.mat(Color(0.6, 0.85, 0.8), 0.25, 0.3, 0.1)
	box(r, Vector3(1.5, 0.55, 1.3), Vector3(0, 0.42, 0), glass)
	cyl(r, 0.65, 1.5, Vector3(0, 0.7, 0), glass, -1.0, 12, Vector3(0, 0, PI / 2)).scale = Vector3(1, 1, 1)
	for x in [-0.75, -0.25, 0.25, 0.75]:
		part(r, Gear.torus(0.62, 0.67), trim(P), Vector3(x, 0.7, 0), Vector3(0, 0, PI / 2))
	for z in [-0.4, 0.0, 0.4]:
		box(r, Vector3(1.3, 0.12, 0.2), Vector3(0, 0.22, z), m(Color(0.25, 0.4, 0.15)))
		sphere(r, 0.08, Vector3(-0.4, 0.33, z), m(Color(0.75, 0.62, 0.2)))
		sphere(r, 0.08, Vector3(0.3, 0.33, z), m(Color(0.75, 0.62, 0.2)))
	tank(r, P, 0.12, 0.5, Vector3(0.85, 0.15, 0.7))


## Library: an observatory-academy: a rotunda with a brass telescope dome.
static func _observatory(r: Node3D, P: Dictionary) -> void:
	block(r, P, Vector3(2.4, 1.0, 1.2), Vector3(0, 0, 0.6), 2)
	hip_roof(r, P, 2.4, 1.2, 0.35, Vector3(0, 1.0, 0.6))
	tower(r, P, 0.75, 1.5, Vector3(0, 0, -0.4), "")
	var top := Node3D.new()
	top.position = Vector3(0, 1.5, -0.4)
	top.set_meta("spin", 0.15)
	r.add_child(top)
	sphere(top, 0.78, Vector3.ZERO, trim(P), true)
	box(top, Vector3(0.2, 0.5, 0.9), Vector3(0, 0.45, 0.2), iron(P))
	cyl(top, 0.12, 1.1, Vector3(0, 0.75, 0.55), iron(P), 0.09, 10, Vector3(-0.8, 0, 0))
	sphere(top, 0.09, Vector3(0, 1.1, 1.0), glow(P.glow, 2.5))
	for x in [-0.8, 0.8]:
		cyl(r, 0.08, 0.95, Vector3(x, 0.5, 1.25), wall(P))
	banner(r, P, Vector3(0, 0.9, 1.21))


# --- Monarchy: military ----------------------------------------------------------------

## Kaserne: a brick barracks with a crenellated parapet, a drill yard, a boiler and
## the regiment's banners.
static func _kaserne(r: Node3D, P: Dictionary) -> void:
	box(r, Vector3(2.7, 0.08, 2.7), Vector3(0, 0.04, 0), base(P))
	block(r, P, Vector3(2.5, 1.2, 1.1), Vector3(0, 0, -0.65), 2, brick(P))
	for i in 9:
		box(r, Vector3(0.14, 0.15, 1.1), Vector3(-1.15 + i * 0.29, 1.27, -0.65), brick(P))
	block(r, P, Vector3(0.8, 1.6, 0.8), Vector3(-0.85, 0, 0.6), 2)
	hip_roof(r, P, 0.8, 0.8, 0.5, Vector3(-0.85, 1.6, 0.6))
	stack(r, P, Vector3(0.9, 0.0, -0.9), 2.0)
	tank(r, P, 0.18, 0.7, Vector3(0.9, 0.0, 0.6))
	cyl(r, 0.03, 1.8, Vector3(0.2, 0.9, 0.8), iron(P))
	box(r, Vector3(0.5, 0.32, 0.02), Vector3(0.46, 1.6, 0.8), team(P))
	banner(r, P, Vector3(-0.4, 1.05, -0.09))
	banner(r, P, Vector3(0.4, 1.05, -0.09))
	for x in [-0.2, 0.0, 0.2]:
		cyl(r, 0.02, 0.5, Vector3(x, 0.25, 0.2), iron(P))


## Schießstand: a long firing shed with targets and a rifle rack.
static func _range(r: Node3D, P: Dictionary) -> void:
	box(r, Vector3(2.7, 0.08, 2.7), Vector3(0, 0.04, 0), base(P))
	block(r, P, Vector3(2.4, 0.9, 0.9), Vector3(0, 0, -0.8), 1, brick(P))
	hip_roof(r, P, 2.5, 1.0, 0.35, Vector3(0, 0.9, -0.8))
	for x in [-0.8, 0.0, 0.8]:
		cyl(r, 0.04, 0.6, Vector3(x, 0.3, 1.0), iron(P))
		cyl(r, 0.25, 0.04, Vector3(x, 0.7, 1.0), m(Color(0.92, 0.9, 0.84)), -1.0, 16, Vector3(PI / 2, 0, 0))
		cyl(r, 0.12, 0.05, Vector3(x, 0.7, 1.01), team(P), -1.0, 16, Vector3(PI / 2, 0, 0))
	stack(r, P, Vector3(1.0, 0.9, -1.0), 0.9, 0.09, false)
	wall_cog(r, P, 0.22, Vector3(-0.9, 0.55, -0.34))


## Laboratorium: an alchemist's tower crowned by a Tesla coil, with Aether
## retorts and pipes.
static func _laboratorium(r: Node3D, P: Dictionary) -> void:
	box(r, Vector3(2.6, 0.12, 2.6), Vector3(0, 0.06, 0), base(P))
	tower(r, P, 0.65, 2.2, Vector3(-0.3, 0, -0.2), "", brick(P))
	tesla(r, P, Vector3(-0.3, 2.2, -0.2), 1.2)
	block(r, P, Vector3(1.0, 0.9, 1.0), Vector3(0.7, 0, 0.6), 1)
	hip_roof(r, P, 1.0, 1.0, 0.35, Vector3(0.7, 0.9, 0.6))
	tank(r, P, 0.22, 1.0, Vector3(0.8, 0.0, -0.8))
	tank(r, P, 0.16, 0.7, Vector3(-1.0, 0.0, 0.9))
	pipes(r, P, [Vector3(0.8, 1.0, -0.8), Vector3(0.8, 1.3, -0.8), Vector3(0.2, 1.3, -0.4)])
	pipes(r, P, [Vector3(-1.0, 0.7, 0.9), Vector3(-1.0, 0.9, 0.4), Vector3(-0.6, 0.9, 0.2)], 0.035)


## Festungsturm: a riveted gun tower with a turning turret and a steam cannon.
static func _gun_tower(r: Node3D, P: Dictionary) -> void:
	tower(r, P, 0.6, 1.8, Vector3.ZERO, "", base(P))
	for i in 8:
		var a := TAU * i / 8.0
		sphere(r, 0.03, Vector3(sin(a) * 0.6, 1.5, cos(a) * 0.6), trim(P))
	var turret := Node3D.new()
	turret.position = Vector3(0, 1.8, 0)
	turret.set_meta("spin", 0.25)
	r.add_child(turret)
	sphere(turret, 0.55, Vector3.ZERO, iron(P), true, 0.8)
	cyl(turret, 0.08, 0.9, Vector3(0, 0.25, 0.6), iron(P), 0.06, 10, Vector3(PI / 2, 0, 0))
	cyl(turret, 0.1, 0.1, Vector3(0, 0.25, 1.05), trim(P), -1.0, 10, Vector3(PI / 2, 0, 0))
	stack(turret, P, Vector3(-0.25, 0.2, -0.25), 0.5, 0.06)


## Adlerhorst: a lattice airship mast with a moored dirigible.
static func _airship_mast(r: Node3D, P: Dictionary) -> void:
	box(r, Vector3(2.6, 0.1, 2.6), Vector3(0, 0.05, 0), base(P))
	lattice(r, P, 0.45, 0.15, 0.1, 2.9, Vector3(-0.6, 0, 0), 5)
	cyl(r, 0.22, 0.2, Vector3(-0.6, 3.0, 0), trim(P))
	block(r, P, Vector3(1.0, 0.7, 1.0), Vector3(0.7, 0, 0.7), 1, brick(P))
	var ship := Node3D.new()
	ship.position = Vector3(0.4, 3.0, 0)
	r.add_child(ship)
	sphere(ship, 0.45, Vector3.ZERO, m(Color(0.72, 0.62, 0.48)), false, 1.0)
	ship.get_child(0).scale = Vector3(2.4, 0.95, 0.95)
	box(ship, Vector3(0.6, 0.18, 0.22), Vector3(0, -0.55, 0), m(Color(0.35, 0.22, 0.14)))
	box(ship, Vector3(0.3, 0.3, 0.02), Vector3(1.05, 0.0, 0), team(P))
	for z in [-0.4, 0.4]:
		box(ship, Vector3(1.6, 0.02, 0.02), Vector3(0, 0.0, z), trim(P))
	tank(r, P, 0.15, 0.6, Vector3(-0.9, 0.1, 0.9))


## Fabrik: a sawtooth-roofed works with three stacks and a giant flywheel.
static func _fabrik(r: Node3D, P: Dictionary) -> void:
	box(r, Vector3(2.8, 0.1, 2.8), Vector3(0, 0.05, 0), base(P))
	block(r, P, Vector3(2.4, 1.1, 1.8), Vector3(0, 0, -0.3), 2, brick(P))
	for i in 4:
		var x := -0.9 + i * 0.6
		box(r, Vector3(0.6, 0.35, 1.8), Vector3(x, 1.25, -0.3), roof(P), Vector3(0, 0, 0.5))
		box(r, Vector3(0.04, 0.3, 1.7), Vector3(x + 0.27, 1.25, -0.3), window(P))
	for i in 3:
		stack(r, P, Vector3(-0.8 + i * 0.8, 1.1, -1.0), 1.4 + i * 0.3)
	flywheel(r, P, 0.6, Vector3(0.9, 0.65, 0.95))
	box(r, Vector3(0.5, 0.35, 0.6), Vector3(0.4, 0.18, 0.95), iron(P))
	wall_cog(r, P, 0.25, Vector3(-0.6, 0.6, 0.62))
	tank(r, P, 0.18, 0.8, Vector3(-1.1, 0.0, 1.0))


# --- Monarchy: wonders ------------------------------------------------------------------

## Orloj: a soaring astronomical clock tower of brass and iron.
static func _orloj(r: Node3D, P: Dictionary) -> void:
	box(r, Vector3(3.6, 0.2, 3.6), Vector3(0, 0.1, 0), base(P))
	block(r, P, Vector3(1.6, 4.2, 1.6), Vector3(0, 0.2, 0), 5)
	cyl(r, 1.2, 1.6, Vector3(0, 5.2, 0), roof(P), 0.0, 4, Vector3(0, PI / 4, 0))
	for c in [Vector2(-0.8, -0.8), Vector2(0.8, -0.8), Vector2(-0.8, 0.8), Vector2(0.8, 0.8)]:
		cyl(r, 0.12, 0.8, Vector3(c.x, 4.8, c.y), roof(P), 0.0, 6)
	_clock(r, P, Vector3(0, 3.0, 0.82), 0.6)
	sphere(r, 0.22, Vector3(0, 3.0, 0.86), glow(P.glow, 2.0))
	_clock(r, P, Vector3(0, 1.8, 0.82), 0.4)
	wall_cog(r, P, 0.4, Vector3(-0.85, 2.2, 0.0), PI / 2, 0.3)
	wall_cog(r, P, 0.4, Vector3(0.85, 2.2, 0.0), -PI / 2, -0.3)
	for x in [-1.3, 1.3]:
		tank(r, P, 0.2, 1.2, Vector3(x, 0.2, 1.3))


## Pummerin: a cathedral of iron and glass with a giant bell in an open belfry.
static func _cathedral(r: Node3D, P: Dictionary) -> void:
	box(r, Vector3(3.6, 0.2, 3.6), Vector3(0, 0.1, 0), base(P))
	block(r, P, Vector3(1.6, 1.8, 3.0), Vector3(0, 0.2, 0.2), 2)
	cyl(r, 1.1, 1.0, Vector3(0, 2.5, 0.2), roof(P), 0.0, 4, Vector3(0, PI / 4, 0)).scale = Vector3(1, 1, 1)
	block(r, P, Vector3(1.0, 3.6, 1.0), Vector3(0, 0.2, -1.2), 4)
	# Open belfry with the bell.
	for c in [Vector2(-0.4, -0.4), Vector2(0.4, -0.4), Vector2(-0.4, 0.4), Vector2(0.4, 0.4)]:
		box(r, Vector3(0.12, 1.0, 0.12), Vector3(c.x, 4.3, -1.2 + c.y), iron(P))
	cyl(r, 0.32, 0.55, Vector3(0, 4.2, -1.2), trim(P), 0.16, 16)
	cyl(r, 0.8, 1.8, Vector3(0, 5.7, -1.2), roof(P), 0.0, 4, Vector3(0, PI / 4, 0))
	sphere(r, 0.1, Vector3(0, 6.65, -1.2), trim(P))
	cyl(r, 0.45, 0.04, Vector3(0, 1.4, 1.71), glow(P.window, 1.4), -1.0, 16, Vector3(PI / 2, 0, 0))
	for z in [-0.2, 0.8]:
		for x in [-1.0, 1.0]:
			beam(r, Vector3(x * 1.1, 0.2, z), Vector3(x * 0.8, 1.9, z), 0.12, base(P))


## Hofburg Treasury: a domed vault with golden doors and Aether reliquaries.
static func _treasury(r: Node3D, P: Dictionary) -> void:
	box(r, Vector3(3.6, 0.25, 3.6), Vector3(0, 0.125, 0), base(P))
	block(r, P, Vector3(3.0, 1.4, 2.4), Vector3(0, 0.25, 0), 2)
	dome(r, P, 1.0, Vector3(0, 1.65, 0), trim(P))
	box(r, Vector3(0.9, 1.0, 0.06), Vector3(0, 0.75, 1.23), trim(P))
	cyl(r, 0.3, 0.06, Vector3(0, 0.8, 1.27), m(Color(0.75, 0.6, 0.25), 0.8, 0.3), -1.0, 16, Vector3(PI / 2, 0, 0))
	for x in [-1.35, 1.35]:
		tank(r, P, 0.2, 1.1, Vector3(x, 0.25, 1.4))
	for x in [-0.9, -0.6, 0.6, 0.9]:
		cyl(r, 0.08, 1.3, Vector3(x, 0.9, 1.3), wall(P))


# --- Covenant ---------------------------------------------------------------------------

## Citadel: a black iron keep with bone buttresses, a soul furnace and spires; its
## glow follows the pact.
static func _citadel(r: Node3D, P: Dictionary) -> void:
	box(r, Vector3(3.7, 0.25, 3.7), Vector3(0, 0.125, 0), base(P))
	block(r, P, Vector3(2.4, 1.6, 2.0), Vector3(0, 0.25, 0.2), 2)
	for c in [Vector2(-1.4, -1.3), Vector2(1.4, -1.3), Vector2(-1.4, 1.3), Vector2(1.4, 1.3)]:
		tower(r, P, 0.35, 1.8, Vector3(c.x, 0.25, c.y), "cone")
	box(r, Vector3(1.0, 3.0, 1.0), Vector3(0, 1.75, -0.6), wall(P))
	cyl(r, 0.75, 2.2, Vector3(0, 4.35, -0.6), roof(P), 0.0, 4, Vector3(0, PI / 4, 0))
	sphere(r, 0.22, Vector3(0, 2.5, -0.08), glow(P.glow, 2.5))
	for x in [-1.3, -0.65, 0.65, 1.3]:
		spike(r, P, Vector3(x, 0.25, 1.35), 1.4, 0.07, Vector3(0.25, 0, 0))
	stack(r, P, Vector3(0.9, 1.85, -0.6), 1.2)
	stack(r, P, Vector3(-0.9, 1.85, -0.6), 1.2)
	match P.style:
		"bone":
			for i in 5:
				part(r, Gear.torus(0.9, 1.0), trim(P), Vector3(0, 1.0, -0.8 + i * 0.4), Vector3(0, 0, PI / 2)).scale = Vector3(1, 1.2, 0.3)
		"blood":
			cyl(r, 0.6, 0.1, Vector3(0, 0.3, 1.6), glow(P.glow, 2.0), -1.0, 20)
		"shadow":
			for i in 3:
				sphere(r, 0.12, Vector3(-0.6 + i * 0.6, 3.6, -0.6), glow(P.glow, 3.0))


## Dwelling (Covenant): a crypt-house of black stone with a coffin-shaped door.
static func _crypt_house(r: Node3D, P: Dictionary) -> void:
	block(r, P, Vector3(1.4, 0.9, 1.3), Vector3.ZERO, 1)
	cyl(r, 0.75, 1.0, Vector3(0, 1.4, 0), roof(P), 0.0, 4, Vector3(0, PI / 4, 0))
	box(r, Vector3(0.3, 0.55, 0.04), Vector3(0, 0.35, 0.67), m(Color(0.12, 0.1, 0.1)))
	spike(r, P, Vector3(0.55, 0.9, 0.5), 0.6, 0.05)
	stack(r, P, Vector3(-0.45, 0.9, -0.4), 0.6, 0.07, false)


## Storehouse (Covenant): an iron charnel vault bound with bone ribs.
static func _vault(r: Node3D, P: Dictionary) -> void:
	block(r, P, Vector3(1.6, 0.8, 1.2), Vector3.ZERO, 1)
	cyl(r, 0.6, 1.6, Vector3(0, 0.8, 0), roof(P), -1.0, 12, Vector3(0, 0, PI / 2)).scale = Vector3(1, 1, 0.55)
	for x in [-0.6, -0.2, 0.2, 0.6]:
		part(r, Gear.torus(0.6, 0.68), trim(P), Vector3(x, 0.8, 0), Vector3(0, 0, PI / 2)).scale = Vector3(1, 1, 0.6)
	box(r, Vector3(0.55, 0.55, 0.04), Vector3(0, 0.35, 0.62), iron(P))
	sphere(r, 0.07, Vector3(0, 0.45, 0.66), glow(P.glow))


## Garden (Covenant): a blight bed of glowing fungus behind iron railings.
static func _blight_garden(r: Node3D, P: Dictionary) -> void:
	box(r, Vector3(1.7, 0.12, 1.5), Vector3(0, 0.06, 0), m(Color(0.16, 0.14, 0.12)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 14:
		var p := Vector3(rng.randf_range(-0.65, 0.65), 0.12, rng.randf_range(-0.55, 0.55))
		var h := rng.randf_range(0.15, 0.4)
		cyl(r, 0.025, h, p + Vector3(0, h * 0.5, 0), m(Color(0.75, 0.72, 0.6)), -1.0, 6)
		sphere(r, rng.randf_range(0.07, 0.13), p + Vector3(0, h, 0), glow(P.glow, 1.2), true)
	for i in 8:
		var a := TAU * i / 8.0
		spike(r, P, Vector3(sin(a) * 0.85, 0.1, cos(a) * 0.75), 0.4, 0.03)


## Library (Covenant): a grimoire tower with a floating soul-lantern.
static func _grimoire_tower(r: Node3D, P: Dictionary) -> void:
	block(r, P, Vector3(2.2, 1.0, 1.2), Vector3(0, 0, 0.6), 1)
	cyl(r, 0.9, 0.9, Vector3(0, 1.45, 0.6), roof(P), 0.0, 4, Vector3(0, PI / 4, 0)).scale = Vector3(1.4, 1, 0.8)
	tower(r, P, 0.6, 2.2, Vector3(0, 0, -0.5), "cone")
	var orb := Node3D.new()
	orb.position = Vector3(0, 3.9, -0.5)
	orb.set_meta("spin", 0.8)
	r.add_child(orb)
	part(orb, Gear.torus(0.22, 0.27), trim(P), Vector3.ZERO, Vector3(PI / 2, 0, 0))
	sphere(r, 0.14, Vector3(0, 3.9, -0.5), glow(P.glow, 3.0))


## Blood Pit: an iron arena ring of spikes around a glowing pit.
static func _blood_pit(r: Node3D, P: Dictionary) -> void:
	cyl(r, 1.35, 0.5, Vector3(0, 0.25, 0), wall(P), 1.25, 24)
	cyl(r, 0.95, 0.05, Vector3(0, 0.5, 0), glow(Color(1.0, 0.2, 0.15) if P.style != "shadow" else P.glow, 1.5), -1.0, 24)
	for i in 12:
		var a := TAU * i / 12.0
		spike(r, P, Vector3(sin(a) * 1.3, 0.4, cos(a) * 1.3), 0.9, 0.06, Vector3(sin(a + PI / 2) * 0.0, 0, 0))
	box(r, Vector3(0.9, 1.3, 0.7), Vector3(0, 0.65, -1.1), wall(P))
	cyl(r, 0.6, 0.9, Vector3(0, 1.75, -1.1), roof(P), 0.0, 4, Vector3(0, PI / 4, 0))
	stack(r, P, Vector3(0.9, 0.0, -0.9), 1.6, 0.13, false)


## Bone Range: a shed framed in giant ribs with skull targets.
static func _bone_range(r: Node3D, P: Dictionary) -> void:
	box(r, Vector3(2.7, 0.08, 2.7), Vector3(0, 0.04, 0), base(P))
	block(r, P, Vector3(2.4, 0.8, 0.8), Vector3(0, 0, -0.85), 1)
	for i in 6:
		var x := -1.1 + i * 0.44
		part(r, Gear.torus(0.55, 0.62), m(P.trim), Vector3(x, 0.55, -0.2), Vector3(0, PI / 2, PI / 2)).scale = Vector3(1, 1.4, 0.4)
	for x in [-0.8, 0.0, 0.8]:
		cyl(r, 0.035, 0.6, Vector3(x, 0.3, 1.0), iron(P))
		sphere(r, 0.14, Vector3(x, 0.72, 1.0), m(P.trim))


## Ossuary: a bone tower around a green soul furnace.
static func _ossuary(r: Node3D, P: Dictionary) -> void:
	box(r, Vector3(2.6, 0.12, 2.6), Vector3(0, 0.06, 0), base(P))
	tower(r, P, 0.65, 2.0, Vector3(0, 0, -0.2), "cone")
	for i in 8:
		var a := TAU * i / 8.0
		spike(r, P, Vector3(sin(a) * 0.75, 0.0, cos(a) * 0.75 - 0.2), 1.6, 0.06)
	sphere(r, 0.3, Vector3(0.0, 0.5, 0.65), glow(P.glow, 2.2))
	stack(r, P, Vector3(0.8, 0.0, 0.7), 1.8)
	tank(r, P, 0.18, 0.8, Vector3(-0.9, 0.0, 0.8))


## Bone Spire: a spiked defensive tower with a soul-fire crown.
static func _bone_spire(r: Node3D, P: Dictionary) -> void:
	cyl(r, 0.6, 2.0, Vector3(0, 1.0, 0), wall(P), 0.35, 8)
	for i in 6:
		var a := TAU * i / 6.0
		spike(r, P, Vector3(sin(a) * 0.4, 1.7, cos(a) * 0.4), 0.9, 0.06, Vector3(cos(a) * 0.35, 0, -sin(a) * 0.35))
	sphere(r, 0.22, Vector3(0, 2.25, 0), glow(P.glow, 3.0))


## Roost: an iron perch tower with a cage for bats and drakes.
static func _roost(r: Node3D, P: Dictionary) -> void:
	box(r, Vector3(2.6, 0.1, 2.6), Vector3(0, 0.05, 0), base(P))
	lattice(r, P, 0.5, 0.2, 0.1, 2.6, Vector3(-0.5, 0, 0), 4)
	for i in 8:
		var a := TAU * i / 8.0
		cyl(r, 0.02, 0.9, Vector3(-0.5 + sin(a) * 0.4, 3.05, cos(a) * 0.4), iron(P), -1.0, 4)
	cyl(r, 0.45, 0.3, Vector3(-0.5, 3.6, 0), roof(P), 0.0, 8)
	sphere(r, 0.14, Vector3(-0.5, 3.0, 0), glow(P.glow, 2.0))
	block(r, P, Vector3(0.9, 0.7, 0.9), Vector3(0.7, 0, 0.7), 1)


## Charnel Works: a black factory with green soul-stacks and a bone flywheel.
static func _charnel_works(r: Node3D, P: Dictionary) -> void:
	box(r, Vector3(2.8, 0.1, 2.8), Vector3(0, 0.05, 0), base(P))
	block(r, P, Vector3(2.4, 1.1, 1.7), Vector3(0, 0, -0.3), 2)
	cyl(r, 1.0, 0.8, Vector3(0, 1.5, -0.3), roof(P), 0.0, 4, Vector3(0, PI / 4, 0)).scale = Vector3(1.6, 1, 1.1)
	for i in 2:
		stack(r, P, Vector3(-0.7 + i * 1.4, 1.1, -0.9), 1.8)
	flywheel(r, P, 0.55, Vector3(0.9, 0.6, 0.95))
	tank(r, P, 0.22, 0.9, Vector3(-0.9, 0.0, 0.95))


static func _obsidian_spire(r: Node3D, P: Dictionary) -> void:
	box(r, Vector3(3.6, 0.2, 3.6), Vector3(0, 0.1, 0), base(P))
	cyl(r, 1.1, 6.5, Vector3(0, 3.45, 0), m(Color(0.08, 0.06, 0.1), 0.3, 0.2), 0.05, 6)
	for i in 6:
		var a := TAU * i / 6.0
		spike(r, P, Vector3(sin(a) * 1.4, 0.2, cos(a) * 1.4), 2.4, 0.15, Vector3(cos(a) * 0.15, 0, -sin(a) * 0.15))
	for y in [1.5, 3.0, 4.5]:
		part(r, Gear.torus(0.9 - y * 0.12, 1.0 - y * 0.12), glow(P.glow, 2.0), Vector3(0, y, 0))


static func _great_ossuary(r: Node3D, P: Dictionary) -> void:
	box(r, Vector3(3.6, 0.2, 3.6), Vector3(0, 0.1, 0), base(P))
	block(r, P, Vector3(2.8, 1.8, 2.4), Vector3(0, 0.2, 0), 2, m(P.trim))
	sphere(r, 1.1, Vector3(0, 2.0, 0), m(P.trim), true, 1.1)
	sphere(r, 0.35, Vector3(0, 3.0, 0.75), m(P.trim))
	for x in [-0.12, 0.12]:
		sphere(r, 0.08, Vector3(x, 3.05, 1.06), glow(P.glow, 3.0))
	for c in [Vector2(-1.5, -1.3), Vector2(1.5, -1.3), Vector2(-1.5, 1.3), Vector2(1.5, 1.3)]:
		spike(r, P, Vector3(c.x, 0.2, c.y), 2.6, 0.12)


# --- Construction ------------------------------------------------------------------

## An iron girder scaffold for buildings going up (`h` tall over a 1-tile grid).
static func _scaffold(r: Node3D, P: Dictionary, h: float) -> void:
	var mat := iron(P)
	for x in [-0.45, 0.45]:
		for z in [-0.45, 0.45]:
			beam(r, Vector3(x, 0, z), Vector3(x, h, z), 0.04, mat)
	for y in [0.4, 1.0, 1.6, 2.2]:
		for s in [-0.45, 0.45]:
			beam(r, Vector3(-0.45, y, s), Vector3(0.45, y, s), 0.03, mat)
			beam(r, Vector3(s, y, -0.45), Vector3(s, y, 0.45), 0.03, mat)
		box(r, Vector3(0.9, 0.03, 0.25), Vector3(0, y, 0.45), m(Color(0.45, 0.32, 0.2)))
