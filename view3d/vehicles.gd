extends RefCounted
## Vehicles of the modern ages (7-12): cars, lorries, halftracks, tanks; Monarchy
## and Concern. Built from primitives like machines.gd, facing +Z, about one tile
## long, and baked into one mesh per material, except the parts that move:
##   "roll"   a wheel (or road wheel): turns with the distance driven (meta = radius)
##   "tread"  a track belt: its tread pattern scrolls while driving (meta = speed)
##   "turret" a turret: turns to its last target, then back to the front (meta = speed)
## Each moving part is baked on its own, so it is one node, not dozens.
## entity_views.gd animates them; visuals.json "rumble" shakes the hull while driving.

const Gear = preload("res://view3d/gear.gd")

static var _wheels := {}
static var _tread: ShaderMaterial


## Every vehicle kind (machines.gd routes these here; galleries and tests list them).
const KINDS := ["staff_car", "armoured_car", "motorcycle", "lorry", "halftrack", "light_tank", "hearse", "corpse_truck"]


## The unbaked vehicle `kind` in team colour `team` (machines.gd bakes and caches it).
static func raw(kind: String, team: Color) -> Node3D:
	match kind:
		"staff_car":
			return staff_car(team)
		"armoured_car":
			return armoured_car(team)
		"motorcycle":
			return motorcycle(team)
		"lorry":
			return lorry(team)
		"halftrack":
			return halftrack(team)
		"light_tank":
			return light_tank(team)
		"hearse":
			return hearse(team)
		"corpse_truck":
			return corpse_truck(team)
	return Node3D.new()


static func m(c: Color, metal := 0.0, rough := 0.6) -> StandardMaterial3D:
	return Gear.mat(c, 0.0, metal, rough)


# --- Moving parts ---------------------------------------------------------------------

## A wheel turning about X at `at`: tyre, rim and hub (or spokes), baked once per look.
static func wheel(root: Node3D, at: Vector3, r: float, w: float, spokes := false, bony := false) -> Node3D:
	var key := "%s/%s/%s/%s" % [r, w, spokes, bony]
	if not _wheels.has(key):
		var raw := Node3D.new()
		var tyre := m(Color(0.1, 0.1, 0.1), 0.0, 0.9) if not bony else m(Color(0.16, 0.15, 0.14), 0.3, 0.7)
		var rim := m(Color(0.25, 0.25, 0.27), 0.6, 0.45) if not bony else m(Color(0.85, 0.8, 0.68))
		Gear.part(raw, Gear.cyl(r, w), tyre, Vector3.ZERO, Vector3(0, 0, PI / 2))
		Gear.part(raw, Gear.cyl(r * 0.68, w + 0.01), rim, Vector3.ZERO, Vector3(0, 0, PI / 2))
		if spokes:
			for i in 6:
				Gear.part(raw, Gear.box(Vector3(w * 0.4, r * 1.25, r * 0.08)), Gear.brass() if not bony else rim,
						Vector3.ZERO, Vector3(TAU * i / 12.0, 0, 0))
		# A tread mark on the tyre makes the turning visible.
		for i in 4:
			Gear.part(raw, Gear.box(Vector3(w + 0.012, r * 0.16, r * 0.1)), rim,
					Vector3(0, cos(TAU * i / 4.0) * r * 0.92, sin(TAU * i / 4.0) * r * 0.92), Vector3(TAU * i / 4.0, 0, 0))
		Gear.part(raw, Gear.cyl(r * 0.22, w + 0.03), Gear.brass() if not bony else tyre, Vector3.ZERO, Vector3(0, 0, PI / 2))
		_wheels[key] = Gear._bake(raw).mesh
		raw.free()
	var pivot := Node3D.new()
	pivot.position = at
	pivot.set_meta("roll", r)
	var mi := MeshInstance3D.new()
	mi.mesh = _wheels[key]
	pivot.add_child(mi)
	root.add_child(pivot)
	return pivot


static func _tread_material() -> ShaderMaterial:
	if _tread:
		return _tread
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
instance uniform float scroll = 0.0;
uniform vec3 dark = vec3(0.09, 0.09, 0.1);
uniform vec3 light = vec3(0.24, 0.24, 0.25);
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	float link = step(0.45, fract((lp.z + scroll) * 14.0));
	ALBEDO = mix(dark, light, link);
	METALLIC = 0.45;
	ROUGHNESS = 0.75;
}
"""
	_tread = ShaderMaterial.new()
	_tread.shader = sh
	return _tread


## A track belt along Z at side `x` (centred at `z`), with live road wheels inside it.
static func track(root: Node3D, x: float, length: float, h: float, bony := false, z := 0.0) -> void:
	var belt := Node3D.new()
	belt.position = Vector3(x, h * 0.5, z)
	belt.set_meta("tread", 1.0)
	var mat := _tread_material()
	if bony:
		mat = mat.duplicate()
		mat.set_shader_parameter("light", Vector3(0.62, 0.58, 0.48))
	Gear.part(belt, Gear.box(Vector3(0.2, h, length - h)), mat)
	for end in [-1.0, 1.0]:
		Gear.part(belt, Gear.cyl(h * 0.5, 0.2), mat, Vector3(0, 0, end * (length - h) * 0.5), Vector3(0, 0, PI / 2))
	root.add_child(belt)
	for i in 5:
		var zz := z + lerpf(-(length - h) * 0.42, (length - h) * 0.42, i / 4.0)
		wheel(root, Vector3(x + signf(x) * 0.02, h * 0.42, zz), h * 0.36, 0.2, false, bony)
	Gear.part(root, Gear.box(Vector3(0.24, 0.03, length * 1.02)), m(Color(0.16, 0.16, 0.17), 0.4, 0.7), Vector3(x, h + 0.05, z))


## An empty turret pivot at `at`: fill it with parts, then seal() it.
static func turret(root: Node3D, at: Vector3, speed := 3.0) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = at
	pivot.set_meta("turret", speed)
	root.add_child(pivot)
	return pivot


## Bakes a moving part's children into one mesh, keeping it a single node.
static func seal(pivot: Node3D) -> void:
	var baked: Dictionary = Gear._bake(pivot)
	for c in pivot.get_children():
		pivot.remove_child(c)
		c.free()
	if baked.mesh:
		var mi := MeshInstance3D.new()
		mi.mesh = baked.mesh
		pivot.add_child(mi)
	for extra in baked.live:
		pivot.add_child(extra)


## Exhaust smoke from a pipe at `at` (soul-green for the Concern).
static func exhaust(root: Node3D, at: Vector3, necro := false) -> void:
	Gear.part(root, Gear.cyl(0.025, 0.12), m(Color(0.2, 0.2, 0.22), 0.6, 0.5), at, Vector3(PI / 2, 0, 0))
	var chim := Gear.chimney(necro)
	for c in chim.get_children():
		if c is GPUParticles3D:
			var smoke: GPUParticles3D = c.duplicate()
			smoke.position = at + Vector3(0, 0.04, -0.06)
			smoke.scale = Vector3.ONE * 0.35
			root.add_child(smoke)
	chim.free()


static func headlights(root: Node3D, x: float, y: float, z: float, necro := false) -> void:
	var lamp := Gear.mat(Color(1.0, 0.92, 0.65) if not necro else Color(0.5, 1.0, 0.5), 2.2)
	for s in [-1.0, 1.0]:
		Gear.part(root, Gear.cyl(0.045, 0.05), Gear.brass() if not necro else Gear.iron(), Vector3(s * x, y, z), Vector3(PI / 2, 0, 0))
		Gear.part(root, Gear.sphere(0.036), lamp, Vector3(s * x, y, z + 0.022))


## A seated crewman from the waist up: Monarchy in field grey with a team armband,
## the Concern's dead with a skull and a hat. `hat` is "helmet", "cap" or "top".
static func crew(root: Node3D, at: Vector3, team: Color, hat := "helmet", undead := false) -> void:
	var cloth := m(Color(0.38, 0.4, 0.36)) if not undead else m(Color(0.1, 0.1, 0.11))
	var skin := m(Color(0.86, 0.7, 0.58)) if not undead else m(Color(0.86, 0.82, 0.7))
	Gear.part(root, Gear.cyl(0.06, 0.16, 0.05), cloth, at + Vector3(0, 0.08, 0))
	Gear.part(root, Gear.cyl(0.062, 0.035), Gear.mat(team), at + Vector3(0, 0.11, 0))
	Gear.part(root, Gear.sphere(0.05), skin, at + Vector3(0, 0.21, 0))
	if undead:
		for s in [-1.0, 1.0]:
			Gear.part(root, Gear.sphere(0.012), Gear.soul(), at + Vector3(s * 0.018, 0.22, 0.043))
	match hat:
		"helmet":
			Gear.part(root, Gear.sphere(0.058, true), m(Color(0.3, 0.33, 0.28), 0.4, 0.5), at + Vector3(0, 0.225, 0))
			Gear.part(root, Gear.cyl(0.07, 0.012), m(Color(0.3, 0.33, 0.28), 0.4, 0.5), at + Vector3(0, 0.226, 0))
		"cap":
			Gear.part(root, Gear.cyl(0.055, 0.04, 0.06), cloth, at + Vector3(0, 0.255, 0))
			Gear.part(root, Gear.box(Vector3(0.07, 0.008, 0.04)), m(Color(0.08, 0.08, 0.08)), at + Vector3(0, 0.24, 0.05))
			Gear.part(root, Gear.cyl(0.056, 0.012), Gear.brass(), at + Vector3(0, 0.248, 0))
		"top":
			Gear.part(root, Gear.cyl(0.04, 0.1), m(Color(0.06, 0.06, 0.07)), at + Vector3(0, 0.3, 0))
			Gear.part(root, Gear.cyl(0.065, 0.01), m(Color(0.06, 0.06, 0.07)), at + Vector3(0, 0.25, 0))


## A light machine gun on a pintle (in a turret or on a mount).
static func machine_gun(parent: Node3D, at: Vector3, necro := false) -> void:
	var gun := m(Color(0.14, 0.14, 0.15), 0.6, 0.45)
	Gear.part(parent, Gear.box(Vector3(0.05, 0.06, 0.18)), gun, at)
	Gear.part(parent, Gear.cyl(0.016, 0.26), gun, at + Vector3(0, 0.01, 0.2), Vector3(PI / 2, 0, 0))
	Gear.part(parent, Gear.cyl(0.03, 0.12), gun if not necro else Gear.soul(), at + Vector3(0, 0.01, 0.12), Vector3(PI / 2, 0, 0))


# --- Monarchy -------------------------------------------------------------------------

## Austro-Daimler staff car: long bonnet with a brass radiator, open cab with an
## officer and driver, folded hood, spare wheel, and a pennant in team colours.
static func staff_car(team: Color) -> Node3D:
	var root := Node3D.new()
	var paint := m(Color(0.16, 0.2, 0.17), 0.4, 0.35)
	var black := m(Color(0.07, 0.07, 0.08), 0.3, 0.5)
	var seat := Gear.leather()
	for z in [-0.36, 0.36]:
		for s in [-1.0, 1.0]:
			wheel(root, Vector3(s * 0.26, 0.15, z), 0.15, 0.08, true)
	# Chassis, running boards, wings.
	Gear.part(root, Gear.box(Vector3(0.44, 0.08, 1.1)), black, Vector3(0, 0.2, 0))
	for s in [-1.0, 1.0]:
		Gear.part(root, Gear.box(Vector3(0.1, 0.025, 0.42)), black, Vector3(s * 0.27, 0.17, 0))
		for z in [-0.36, 0.36]:
			Gear.part(root, Gear.box(Vector3(0.12, 0.025, 0.36)), paint, Vector3(s * 0.26, 0.31, z), Vector3(-0.15 * signf(z), 0, 0))
	# Bonnet and radiator.
	Gear.part(root, Gear.box(Vector3(0.36, 0.2, 0.42)), paint, Vector3(0, 0.34, 0.3))
	Gear.part(root, Gear.box(Vector3(0.34, 0.24, 0.04)), Gear.brass(), Vector3(0, 0.36, 0.52))
	Gear.part(root, Gear.box(Vector3(0.28, 0.18, 0.045)), m(Color(0.15, 0.13, 0.1), 0.5, 0.5), Vector3(0, 0.36, 0.53))
	headlights(root, 0.16, 0.42, 0.55)
	# Tub with seats, windscreen and the folded hood.
	Gear.part(root, Gear.box(Vector3(0.44, 0.2, 0.58)), paint, Vector3(0, 0.34, -0.2))
	Gear.part(root, Gear.box(Vector3(0.4, 0.06, 0.5)), seat, Vector3(0, 0.44, -0.2))
	Gear.part(root, Gear.box(Vector3(0.38, 0.14, 0.015)), m(Color(0.6, 0.75, 0.85), 0.0, 0.1), Vector3(0, 0.53, 0.08), Vector3(-0.2, 0, 0))
	Gear.part(root, Gear.cyl(0.07, 0.42), m(Color(0.22, 0.2, 0.16)), Vector3(0, 0.5, -0.5), Vector3(0, 0, PI / 2))
	Gear.part(root, Gear.cyl(0.14, 0.07), black, Vector3(0.0, 0.36, -0.56), Vector3(PI / 2, 0, 0))
	Gear.part(root, Gear.torus(0.1, 0.14), black, Vector3(0.0, 0.36, -0.58), Vector3(PI / 2, 0, 0))
	crew(root, Vector3(0.1, 0.4, 0.0), team, "helmet")
	crew(root, Vector3(-0.1, 0.4, -0.28), team, "cap")
	# Fender pennant in team colours, a brass stripe along the side.
	Gear.part(root, Gear.cyl(0.006, 0.2), Gear.brass(), Vector3(0.22, 0.42, 0.5))
	Gear.part(root, Gear.box(Vector3(0.005, 0.07, 0.11)), Gear.mat(team), Vector3(0.22, 0.48, 0.45))
	for s in [-1.0, 1.0]:
		Gear.part(root, Gear.box(Vector3(0.01, 0.02, 0.98)), Gear.brass(), Vector3(s * 0.225, 0.4, 0.05))
	exhaust(root, Vector3(0.14, 0.16, -0.58))
	return root


## Austro-Daimler armoured car: riveted sloped hull on four wheels, a domed turret
## with a machine gun, vision slits and a team band.
static func armoured_car(team: Color) -> Node3D:
	var root := Node3D.new()
	var plate := m(Color(0.33, 0.35, 0.3), 0.55, 0.45)
	var dark := m(Color(0.2, 0.21, 0.19), 0.5, 0.5)
	for z in [-0.36, 0.38]:
		for s in [-1.0, 1.0]:
			wheel(root, Vector3(s * 0.3, 0.17, z), 0.17, 0.1)
	Gear.part(root, Gear.box(Vector3(0.52, 0.3, 1.1)), plate, Vector3(0, 0.4, 0))
	Gear.part(root, Gear.box(Vector3(0.5, 0.06, 0.34)), plate, Vector3(0, 0.52, 0.5), Vector3(-0.5, 0, 0))
	Gear.part(root, Gear.box(Vector3(0.5, 0.06, 0.28)), plate, Vector3(0, 0.5, -0.52), Vector3(0.45, 0, 0))
	Gear.part(root, Gear.box(Vector3(0.54, 0.04, 1.0)), dark, Vector3(0, 0.56, 0))
	for s in [-1.0, 1.0]:
		Gear.part(root, Gear.box(Vector3(0.14, 0.03, 0.3)), dark, Vector3(s * 0.3, 0.37, 0.38))
		Gear.part(root, Gear.box(Vector3(0.14, 0.03, 0.3)), dark, Vector3(s * 0.3, 0.37, -0.36))
		for y in [0.3, 0.5]:
			for i in 8:
				Gear.part(root, Gear.sphere(0.014), Gear.brass(), Vector3(s * 0.262, y, lerpf(-0.48, 0.48, i / 7.0)))
	Gear.part(root, Gear.box(Vector3(0.22, 0.025, 0.012)), m(Color(0.05, 0.05, 0.05)), Vector3(0, 0.5, 0.56))
	headlights(root, 0.19, 0.42, 0.56)
	var t := turret(root, Vector3(0, 0.58, -0.04), 4.0)
	Gear.part(t, Gear.cyl(0.19, 0.12), plate, Vector3(0, 0.06, 0))
	Gear.part(t, Gear.sphere(0.19, true), plate, Vector3(0, 0.12, 0), Vector3.ZERO, Vector3(1, 0.7, 1))
	Gear.part(t, Gear.cyl(0.195, 0.04), Gear.mat(team), Vector3(0, 0.1, 0))
	Gear.part(t, Gear.box(Vector3(0.1, 0.02, 0.02)), m(Color(0.05, 0.05, 0.05)), Vector3(0, 0.15, 0.17))
	machine_gun(t, Vector3(0, 0.1, 0.18))
	seal(t)
	exhaust(root, Vector3(-0.18, 0.24, -0.56))
	return root


## Motorcycle with a sidecar: rider, and a gunner with a machine gun in the car.
static func motorcycle(team: Color) -> Node3D:
	var root := Node3D.new()
	var paint := m(Color(0.25, 0.27, 0.22), 0.4, 0.45)
	var black := m(Color(0.07, 0.07, 0.08), 0.4, 0.5)
	wheel(root, Vector3(0, 0.12, 0.3), 0.12, 0.05, true)
	wheel(root, Vector3(0, 0.12, -0.26), 0.12, 0.05, true)
	wheel(root, Vector3(0.3, 0.1, -0.05), 0.1, 0.05, true)
	# Frame, tank, engine and handlebars.
	Gear.part(root, Gear.box(Vector3(0.06, 0.05, 0.52)), black, Vector3(0, 0.22, 0.02), Vector3(0.12, 0, 0))
	Gear.part(root, Gear.box(Vector3(0.1, 0.08, 0.18)), paint, Vector3(0, 0.3, 0.1))
	Gear.part(root, Gear.cyl(0.06, 0.1), Gear.iron(), Vector3(0, 0.18, 0.0), Vector3(0, 0, PI / 2))
	Gear.part(root, Gear.cyl(0.012, 0.24), black, Vector3(0, 0.38, 0.24), Vector3(0, 0, PI / 2))
	Gear.part(root, Gear.cyl(0.01, 0.22), black, Vector3(0, 0.27, 0.27), Vector3(-0.35, 0, 0))
	Gear.part(root, Gear.box(Vector3(0.08, 0.03, 0.12)), Gear.leather(), Vector3(0, 0.3, -0.1))
	Gear.part(root, Gear.box(Vector3(0.07, 0.03, 0.16)), paint, Vector3(0, 0.26, -0.27))
	Gear.part(root, Gear.sphere(0.03), Gear.mat(Color(1.0, 0.92, 0.65), 2.2), Vector3(0, 0.34, 0.34))
	crew(root, Vector3(0, 0.27, -0.06), team, "helmet")
	# Sidecar tub with the gunner.
	Gear.part(root, Gear.box(Vector3(0.04, 0.03, 0.3)), black, Vector3(0.16, 0.12, -0.04))
	Gear.part(root, Gear.sphere(0.13), paint, Vector3(0.3, 0.2, 0.0), Vector3.ZERO, Vector3(0.9, 0.6, 1.6))
	Gear.part(root, Gear.cyl(0.09, 0.02), black, Vector3(0.3, 0.27, -0.03))
	crew(root, Vector3(0.3, 0.2, -0.06), team, "helmet")
	machine_gun(root, Vector3(0.3, 0.36, 0.08))
	exhaust(root, Vector3(-0.06, 0.12, -0.34))
	return root


## Supply lorry: cab, bonnet, and a canvas-covered bed on six wheels (twin at the back).
static func lorry(team: Color) -> Node3D:
	var root := Node3D.new()
	var paint := m(Color(0.3, 0.32, 0.26), 0.3, 0.55)
	var black := m(Color(0.07, 0.07, 0.08), 0.3, 0.5)
	var canvas := m(Color(0.52, 0.5, 0.38), 0.0, 0.95)
	for s in [-1.0, 1.0]:
		wheel(root, Vector3(s * 0.27, 0.15, 0.48), 0.15, 0.09)
		wheel(root, Vector3(s * 0.28, 0.15, -0.3), 0.15, 0.12)
		wheel(root, Vector3(s * 0.28, 0.15, -0.58), 0.15, 0.12)
	Gear.part(root, Gear.box(Vector3(0.48, 0.08, 1.5)), black, Vector3(0, 0.24, 0))
	Gear.part(root, Gear.box(Vector3(0.38, 0.2, 0.3)), paint, Vector3(0, 0.38, 0.6))
	Gear.part(root, Gear.box(Vector3(0.36, 0.18, 0.03)), m(Color(0.15, 0.13, 0.1), 0.5, 0.5), Vector3(0, 0.38, 0.76))
	headlights(root, 0.17, 0.44, 0.75)
	Gear.part(root, Gear.box(Vector3(0.5, 0.34, 0.3)), paint, Vector3(0, 0.48, 0.32))
	Gear.part(root, Gear.box(Vector3(0.46, 0.12, 0.012)), m(Color(0.6, 0.75, 0.85), 0.0, 0.1), Vector3(0, 0.58, 0.475))
	Gear.part(root, Gear.box(Vector3(0.54, 0.03, 0.34)), paint, Vector3(0, 0.66, 0.32))
	crew(root, Vector3(0.1, 0.4, 0.34), team, "cap")
	# Bed: sides, canvas hoops, a team stripe on the tilt.
	Gear.part(root, Gear.box(Vector3(0.56, 0.12, 0.84)), paint, Vector3(0, 0.34, -0.26))
	# Canvas tilt: straight sides, a low rounded roof, hoops showing through.
	Gear.part(root, Gear.box(Vector3(0.54, 0.24, 0.82)), canvas, Vector3(0, 0.52, -0.26))
	Gear.part(root, Gear.cyl(0.27, 0.82), canvas, Vector3(0, 0.64, -0.26), Vector3(PI / 2, 0, 0), Vector3(1, 1, 0.32))
	for z in [-0.6, -0.26, 0.08]:
		Gear.part(root, Gear.box(Vector3(0.56, 0.025, 0.025)), m(Color(0.42, 0.4, 0.3), 0.0, 0.9), Vector3(0, 0.66, z))
	for s in [-1.0, 1.0]:
		Gear.part(root, Gear.box(Vector3(0.01, 0.06, 0.5)), Gear.mat(team), Vector3(s * 0.272, 0.55, -0.26))
	exhaust(root, Vector3(0.2, 0.22, -0.72))
	return root


## Halftrack: steered front wheels, tracks at the back, an open troop bay and a
## machine gun on a swivel mount.
static func halftrack(team: Color) -> Node3D:
	var root := Node3D.new()
	var plate := m(Color(0.32, 0.34, 0.28), 0.5, 0.5)
	var dark := m(Color(0.2, 0.21, 0.19), 0.5, 0.5)
	for s in [-1.0, 1.0]:
		wheel(root, Vector3(s * 0.28, 0.15, 0.46), 0.15, 0.1)
		track(root, s * 0.28, 0.8, 0.26, false, -0.18)
	Gear.part(root, Gear.box(Vector3(0.48, 0.24, 1.3)), plate, Vector3(0, 0.38, -0.02))
	Gear.part(root, Gear.box(Vector3(0.36, 0.16, 0.36)), plate, Vector3(0, 0.44, 0.48), Vector3(-0.35, 0, 0))
	Gear.part(root, Gear.box(Vector3(0.34, 0.2, 0.04)), m(Color(0.15, 0.13, 0.1), 0.5, 0.5), Vector3(0, 0.4, 0.66))
	headlights(root, 0.16, 0.46, 0.64)
	# Open bay walls and benches.
	for s in [-1.0, 1.0]:
		Gear.part(root, Gear.box(Vector3(0.03, 0.16, 0.8)), plate, Vector3(s * 0.235, 0.58, -0.22))
		Gear.part(root, Gear.box(Vector3(0.1, 0.04, 0.7)), Gear.leather(), Vector3(s * 0.17, 0.5, -0.22))
	Gear.part(root, Gear.box(Vector3(0.48, 0.16, 0.03)), plate, Vector3(0, 0.58, -0.62))
	Gear.part(root, Gear.box(Vector3(0.48, 0.2, 0.03)), dark, Vector3(0, 0.6, 0.18), Vector3(-0.2, 0, 0))
	crew(root, Vector3(0.1, 0.48, 0.28), team, "helmet")
	for z in [-0.1, -0.36]:
		crew(root, Vector3(-0.12, 0.48, z), team, "helmet")
	Gear.part(root, Gear.box(Vector3(0.49, 0.04, 0.3)), Gear.mat(team), Vector3(0, 0.47, -0.45))
	var t := turret(root, Vector3(0.08, 0.66, -0.3), 5.0)
	Gear.part(t, Gear.box(Vector3(0.2, 0.12, 0.02)), dark, Vector3(0, 0.06, 0.14))
	machine_gun(t, Vector3(0, 0.06, 0.08))
	seal(t)
	exhaust(root, Vector3(-0.18, 0.28, 0.5))
	return root


## Light tank: low riveted hull on tracks, a small turret with a short gun.
static func light_tank(team: Color) -> Node3D:
	var root := Node3D.new()
	var plate := m(Color(0.34, 0.36, 0.3), 0.55, 0.45)
	var dark := m(Color(0.21, 0.22, 0.2), 0.5, 0.5)
	for s in [-1.0, 1.0]:
		track(root, s * 0.36, 1.2, 0.26)
	Gear.part(root, Gear.box(Vector3(0.52, 0.22, 1.1)), plate, Vector3(0, 0.38, 0))
	Gear.part(root, Gear.box(Vector3(0.52, 0.05, 0.3)), plate, Vector3(0, 0.46, 0.55), Vector3(-0.5, 0, 0))
	Gear.part(root, Gear.box(Vector3(0.8, 0.03, 1.16)), dark, Vector3(0, 0.3, 0))
	for s in [-1.0, 1.0]:
		for i in 7:
			Gear.part(root, Gear.sphere(0.013), Gear.brass(), Vector3(s * 0.262, 0.44, lerpf(-0.48, 0.48, i / 6.0)))
	headlights(root, 0.2, 0.44, 0.6)
	var t := turret(root, Vector3(0, 0.49, 0.02), 2.5)
	Gear.part(t, Gear.box(Vector3(0.34, 0.16, 0.42)), plate, Vector3(0, 0.08, 0))
	Gear.part(t, Gear.box(Vector3(0.3, 0.04, 0.38)), dark, Vector3(0, 0.18, -0.02))
	Gear.part(t, Gear.cyl(0.07, 0.03), dark, Vector3(0.06, 0.21, -0.08))
	Gear.part(t, Gear.box(Vector3(0.35, 0.04, 0.43)), Gear.mat(team), Vector3(0, 0.12, 0))
	Gear.part(t, Gear.cyl(0.032, 0.42), dark, Vector3(0, 0.09, 0.4), Vector3(PI / 2, 0, 0))
	Gear.part(t, Gear.cyl(0.05, 0.08), dark, Vector3(0, 0.09, 0.22), Vector3(PI / 2, 0, 0))
	seal(t)
	exhaust(root, Vector3(0.16, 0.36, -0.58))
	exhaust(root, Vector3(-0.16, 0.36, -0.58))
	return root


# --- The Concern ----------------------------------------------------------------------

## The Concern's hearse: a long black car with a glass casket bay glowing with a
## coffin of souls, bone trim, a skull mascot and an undead driver in a top hat.
static func hearse(team: Color) -> Node3D:
	var root := Node3D.new()
	var lacquer := m(Color(0.05, 0.05, 0.06), 0.5, 0.25)
	var bone := m(Color(0.85, 0.8, 0.68))
	for z in [-0.4, 0.38]:
		for s in [-1.0, 1.0]:
			wheel(root, Vector3(s * 0.26, 0.15, z), 0.15, 0.08, true, true)
	Gear.part(root, Gear.box(Vector3(0.44, 0.08, 1.24)), lacquer, Vector3(0, 0.2, 0))
	Gear.part(root, Gear.box(Vector3(0.36, 0.2, 0.36)), lacquer, Vector3(0, 0.34, 0.42))
	Gear.part(root, Gear.box(Vector3(0.32, 0.22, 0.04)), Gear.iron(), Vector3(0, 0.36, 0.61))
	Gear.part(root, Gear.sphere(0.04), bone, Vector3(0, 0.49, 0.58))
	headlights(root, 0.15, 0.42, 0.62, true)
	Gear.part(root, Gear.box(Vector3(0.44, 0.24, 0.28)), lacquer, Vector3(0, 0.42, 0.12))
	crew(root, Vector3(0.08, 0.4, 0.12), team, "top", true)
	# Glass casket bay with a glowing coffin, bone pillars and a roof rail.
	Gear.part(root, Gear.box(Vector3(0.44, 0.08, 0.66)), lacquer, Vector3(0, 0.3, -0.3))
	Gear.part(root, Gear.box(Vector3(0.4, 0.26, 0.6)), m(Color(0.25, 0.4, 0.3), 0.2, 0.1), Vector3(0, 0.47, -0.3))
	Gear.part(root, Gear.box(Vector3(0.18, 0.08, 0.46)), Gear.soul(), Vector3(0, 0.42, -0.3))
	Gear.part(root, Gear.box(Vector3(0.46, 0.05, 0.68)), lacquer, Vector3(0, 0.62, -0.28))
	for s in [-1.0, 1.0]:
		for z in [-0.6, 0.0]:
			Gear.part(root, Gear.cyl(0.02, 0.3), bone, Vector3(s * 0.21, 0.47, z))
		Gear.part(root, Gear.box(Vector3(0.012, 0.03, 1.1)), Gear.mat(team), Vector3(s * 0.222, 0.27, 0.0))
	for x in [-0.15, 0.0, 0.15]:
		Gear.part(root, Gear.sphere(0.03), bone, Vector3(x, 0.67, -0.28))
	exhaust(root, Vector3(0.14, 0.16, -0.64), true)
	return root


## The Concern's corpse-truck: an iron cage of the bound dead on a flatbed, soul
## lamps and a bone-plated cab.
static func corpse_truck(team: Color) -> Node3D:
	var root := Node3D.new()
	var iron := m(Color(0.12, 0.12, 0.13), 0.55, 0.5)
	var bone := m(Color(0.85, 0.8, 0.68))
	for s in [-1.0, 1.0]:
		wheel(root, Vector3(s * 0.27, 0.15, 0.48), 0.15, 0.09, false, true)
		wheel(root, Vector3(s * 0.28, 0.15, -0.3), 0.15, 0.12, false, true)
		wheel(root, Vector3(s * 0.28, 0.15, -0.58), 0.15, 0.12, false, true)
	Gear.part(root, Gear.box(Vector3(0.48, 0.08, 1.5)), iron, Vector3(0, 0.24, 0))
	Gear.part(root, Gear.box(Vector3(0.38, 0.2, 0.3)), iron, Vector3(0, 0.38, 0.6))
	for i in 4:
		Gear.part(root, Gear.cyl(0.012, 0.3), bone, Vector3(-0.12 + i * 0.08, 0.38, 0.76), Vector3(PI / 2, 0, 0))
	headlights(root, 0.17, 0.44, 0.75, true)
	Gear.part(root, Gear.box(Vector3(0.5, 0.34, 0.3)), iron, Vector3(0, 0.48, 0.32))
	Gear.part(root, Gear.box(Vector3(0.46, 0.12, 0.012)), m(Color(0.2, 0.3, 0.22), 0.0, 0.1), Vector3(0, 0.58, 0.475))
	for s in [-1.0, 1.0]:
		Gear.part(root, Gear.box(Vector3(0.012, 0.25, 0.26)), bone, Vector3(s * 0.255, 0.48, 0.32))
	crew(root, Vector3(0.1, 0.4, 0.34), team, "top", true)
	# The cage: bars, a roof, three of the dead inside, two soul lamps.
	Gear.part(root, Gear.box(Vector3(0.56, 0.05, 0.84)), iron, Vector3(0, 0.3, -0.26))
	for s in [-1.0, 1.0]:
		for i in 6:
			Gear.part(root, Gear.cyl(0.01, 0.34), iron, Vector3(s * 0.27, 0.48, lerpf(-0.64, 0.12, i / 5.0)))
	Gear.part(root, Gear.box(Vector3(0.58, 0.03, 0.86)), iron, Vector3(0, 0.66, -0.26))
	for z in [-0.5, -0.26, -0.02]:
		Gear.part(root, Gear.cyl(0.05, 0.22, 0.04), m(Color(0.25, 0.24, 0.2)), Vector3(0.0, 0.43, z))
		Gear.part(root, Gear.sphere(0.045), bone, Vector3(0.0, 0.58, z))
	for s in [-1.0, 1.0]:
		Gear.part(root, Gear.sphere(0.04), Gear.soul(), Vector3(s * 0.25, 0.72, -0.62))
		Gear.part(root, Gear.box(Vector3(0.012, 0.04, 0.6)), Gear.mat(team), Vector3(s * 0.282, 0.33, -0.26))
	exhaust(root, Vector3(0.2, 0.22, -0.72), true)
	return root
