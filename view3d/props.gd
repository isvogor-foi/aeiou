extends RefCounted
## Industrial resource sites built from primitives: the Aether wellhead (a riveted
## casing under a lattice derrick, glowing through gauge windows), the farmstead
## (ploughed smog-dulled crop rows with a steam pump) and the mine headframe
## (a winding tower with a turning sheave). Footprint-centred, sizes in tiles.

const Gear = preload("res://view3d/gear.gd")

const SOIL := Color(0.16, 0.12, 0.09)
const CROP := Color(0.36, 0.38, 0.18)
const CONCRETE := Color(0.34, 0.33, 0.31)


static func build(kind: String) -> Node3D:
	match kind:
		"aether_well":
			return aether_well()
		"farmstead":
			return farmstead()
		"headframe":
			return headframe()
		"coal_cart":
			return coal_cart()
	return Node3D.new()


static func _strut(parent: Node3D, a: Vector3, b: Vector3, r: float, m: Material) -> void:
	var mi := Gear.part(parent, Gear.cyl(r, a.distance_to(b)), m, (a + b) * 0.5)
	var dir := (b - a).normalized()
	if absf(dir.dot(Vector3.UP)) < 0.999:
		mi.basis = Basis(Quaternion(Vector3.UP, dir))


## A pressurised Aether wellhead under a lattice derrick.
static func aether_well() -> Node3D:
	var root := Node3D.new()
	var iron := Gear.iron()
	var brass := Gear.brass()
	var copper := Gear.copper()
	var glow := Gear.aether()
	# Riveted concrete pad.
	Gear.part(root, Gear.cyl(0.8, 0.1), Gear.mat(CONCRETE, 0.0, 0.0, 0.95), Vector3(0, 0.05, 0))
	for i in 12:
		var a := i * TAU / 12.0
		Gear.part(root, Gear.sphere(0.03), brass, Vector3(cos(a) * 0.72, 0.1, sin(a) * 0.72))
	# Wellhead casing with glowing gauge windows and brass bands.
	Gear.part(root, Gear.cyl(0.26, 0.6), iron, Vector3(0, 0.4, 0))
	Gear.part(root, Gear.cyl(0.265, 0.14), glow, Vector3(0, 0.45, 0))
	for y in [0.2, 0.36, 0.54, 0.68]:
		Gear.part(root, Gear.cyl(0.29, 0.035), brass, Vector3(0, y, 0))
	# Pressure dome and a glass globe of raw Aether.
	Gear.part(root, Gear.sphere(0.27, true), copper, Vector3(0, 0.7, 0))
	Gear.part(root, Gear.cyl(0.07, 0.16), brass, Vector3(0, 0.98, 0))
	Gear.part(root, Gear.sphere(0.13), glow, Vector3(0, 1.12, 0))
	Gear.part(root, Gear.torus(0.13, 0.16), brass, Vector3(0, 1.12, 0))
	# Valve pipes out to three handwheels.
	for i in 3:
		var a := i * TAU / 3.0 + 0.4
		var d := Vector3(cos(a), 0, sin(a))
		_strut(root, d * 0.26 + Vector3(0, 0.3, 0), d * 0.62 + Vector3(0, 0.3, 0), 0.045, copper)
		_strut(root, d * 0.62 + Vector3(0, 0.1, 0), d * 0.62 + Vector3(0, 0.42, 0), 0.05, iron)
		Gear.part(root, Gear.torus(0.07, 0.1), brass, d * 0.62 + Vector3(0, 0.45, 0))
	# Lattice derrick over the well.
	var top := Vector3(0, 2.0, 0)
	var feet: Array[Vector3] = [Vector3(-0.62, 0.1, -0.62), Vector3(0.62, 0.1, -0.62), Vector3(0.62, 0.1, 0.62), Vector3(-0.62, 0.1, 0.62)]
	for f in feet:
		_strut(root, f, top, 0.03, iron)
	for t in [0.3, 0.6]:
		for i in 4:
			var a: Vector3 = feet[i].lerp(top, t)
			var b: Vector3 = feet[(i + 1) % 4].lerp(top, t)
			_strut(root, a, b, 0.018, iron)
			var c: Vector3 = feet[(i + 1) % 4].lerp(top, t + 0.3 if t < 0.5 else t - 0.3)
			_strut(root, a, c, 0.012, iron)
	Gear.part(root, Gear.cyl(0.1, 0.08), brass, top + Vector3(0, 0.02, 0))
	Gear.part(root, Gear.sphere(0.06), Gear.mat(Color(0.5, 0.9, 1.0), 4.0), top + Vector3(0, 0.12, 0))
	var light := OmniLight3D.new()
	light.light_color = Color(0.45, 0.85, 1.0)
	light.light_energy = 0.9
	light.omni_range = 2.6
	light.shadow_enabled = false
	light.position = Vector3(0, 1.0, 0)
	root.add_child(light)
	return root


## Ploughed field with smog-dulled crop rows, an irrigation pipe and a steam pump.
static func farmstead() -> Node3D:
	var root := Node3D.new()
	var soil := Gear.mat(SOIL, 0.0, 0.0, 1.0)
	Gear.part(root, Gear.box(Vector3(1.8, 0.06, 1.8)), soil, Vector3(0, 0.03, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 7:
		var z := -0.72 + i * 0.24
		Gear.part(root, Gear.box(Vector3(1.55, 0.05, 0.1)), Gear.mat(SOIL * 1.35, 0.0, 0.0, 1.0), Vector3(-0.08, 0.075, z))
		# Crop tufts along each furrow.
		for k in 9:
			var h := rng.randf_range(0.1, 0.2)
			var c := CROP * rng.randf_range(0.8, 1.15)
			Gear.part(root, Gear.cyl(0.045, h, 0.01), Gear.mat(c, 0.0, 0.0, 0.9), Vector3(-0.78 + k * 0.17 + rng.randf_range(-0.03, 0.03), 0.1 + h * 0.5, z))
	# Iron fence posts along the edge.
	for i in 8:
		var t := -0.85 + i * (1.7 / 7.0)
		for p in [Vector3(t, 0, -0.88), Vector3(t, 0, 0.88), Vector3(-0.88, 0, t), Vector3(0.88, 0, t)]:
			Gear.part(root, Gear.cyl(0.018, 0.22), Gear.iron(), p + Vector3(0, 0.11, 0))
	# Copper irrigation pipe along one side, fed by a little steam pump.
	var pipe := Gear.part(root, Gear.cyl(0.03, 1.6), Gear.copper(), Vector3(0.0, 0.1, 0.8))
	pipe.rotation = Vector3(0, 0, PI / 2)
	var pump := Node3D.new()
	pump.position = Vector3(0.68, 0, 0.62)
	root.add_child(pump)
	Gear.part(pump, Gear.cyl(0.13, 0.32), Gear.iron(), Vector3(0, 0.22, 0))
	Gear.part(pump, Gear.sphere(0.13, true), Gear.copper(), Vector3(0, 0.38, 0))
	Gear.part(pump, Gear.cyl(0.14, 0.03), Gear.brass(), Vector3(0, 0.3, 0))
	var stack := Gear.chimney(false)
	stack.scale = Vector3.ONE * 0.35
	stack.position = Vector3(-0.08, 0.1, -0.06)
	pump.add_child(stack)
	var fly := Node3D.new()
	fly.position = Vector3(0.15, 0.25, 0)
	fly.rotation = Vector3(0, PI / 2, 0)
	fly.set_meta("spin_z", 2.5)
	pump.add_child(fly)
	Gear.part(fly, Gear.torus(0.08, 0.11), Gear.brass(), Vector3.ZERO, Vector3(PI / 2, 0, 0))
	Gear.part(fly, Gear.box(Vector3(0.2, 0.02, 0.02)), Gear.iron())
	return root


## A mine's winding tower: two A-frames carrying a turning sheave.
static func headframe() -> Node3D:
	var root := Node3D.new()
	var iron := Gear.iron()
	var h := 1.5
	for x in [-0.25, 0.25]:
		_strut(root, Vector3(x, 0, -0.3), Vector3(x, h, 0), 0.028, iron)
		_strut(root, Vector3(x, 0, 0.3), Vector3(x, h, 0), 0.028, iron)
		_strut(root, Vector3(x, h * 0.45, -0.165), Vector3(x, h * 0.45, 0.165), 0.016, iron)
	_strut(root, Vector3(-0.25, h, 0), Vector3(0.25, h, 0), 0.03, Gear.brass())
	# The sheave turns about the axle (world X): local Z after a quarter turn in Y.
	var sheave := Node3D.new()
	sheave.position = Vector3(0, h, 0)
	sheave.rotation = Vector3(0, PI / 2, 0)
	sheave.set_meta("spin_z", 1.2)
	root.add_child(sheave)
	Gear.part(sheave, Gear.torus(0.24, 0.29), Gear.brass(), Vector3.ZERO, Vector3(PI / 2, 0, 0))
	for i in 4:
		Gear.part(sheave, Gear.box(Vector3(0.48, 0.03, 0.03)), iron, Vector3.ZERO, Vector3(0, 0, i * PI / 4))
	# Cable down into the shaft.
	_strut(root, Vector3(0, h - 0.27, 0), Vector3(0, 0.1, 0), 0.008, Gear.mat(Color(0.1, 0.1, 0.1)))
	return root


## Rails and a coal tub heaped with coal.
static func coal_cart() -> Node3D:
	var root := Node3D.new()
	var iron := Gear.iron()
	for x in [-0.12, 0.12]:
		Gear.part(root, Gear.box(Vector3(0.025, 0.025, 1.1)), iron, Vector3(x, 0.03, 0))
	for i in 6:
		Gear.part(root, Gear.box(Vector3(0.36, 0.03, 0.06)), Gear.leather(), Vector3(0, 0.015, -0.5 + i * 0.2))
	Gear.part(root, Gear.box(Vector3(0.32, 0.18, 0.4)), Gear.mat(Color(0.3, 0.22, 0.16), 0.0, 0.4, 0.6), Vector3(0, 0.17, 0.1))
	Gear.part(root, Gear.sphere(0.17), Gear.mat(Color(0.08, 0.08, 0.09), 0.0, 0.0, 0.5), Vector3(0, 0.27, 0.1), Vector3.ZERO, Vector3(1, 0.5, 1.2))
	return root
