extends RefCounted
## Steam and necro machines, built from smooth primitives (see gear.gd) and baked
## into one mesh per material, cached per kind and owner colour. Rotors ("spin")
## and smoke stay live nodes. All face +Z, about one tile long.

const Gear = preload("res://view3d/gear.gd")

static var _cache := {}


static func build(kind: String, team: Color) -> Node3D:
	var key := "%s/%s" % [kind, team.to_html()]
	if not _cache.has(key):
		_cache[key] = Gear._bake(_raw(kind, team))
	var src: Dictionary = _cache[key]
	var root := Node3D.new()
	if src.mesh:
		var mi := MeshInstance3D.new()
		mi.mesh = src.mesh
		root.add_child(mi)
	for extra in src.live:
		root.add_child(extra.duplicate())
	return root


static func _raw(kind: String, team: Color) -> Node3D:
	match kind:
		"landpanzer":
			return landpanzer(team)
		"juggernaut":
			return juggernaut(team)
		"gyrocopter":
			return gyrocopter(team)
		"plague_balloon":
			return plague_balloon(team)
		"siege_crawler":
			return siege_crawler(team)
		"corpse_crawler":
			return corpse_crawler(team)
		"aether_train":
			return aether_train(team)
	return Node3D.new()


static func m(c: Color, metal := 0.0, rough := 0.6) -> StandardMaterial3D:
	return Gear.mat(c, 0.0, metal, rough)


# --- Shared parts -----------------------------------------------------------------------

## Two track units with road wheels, idlers and link plates (length along Z).
static func tracks(root: Node3D, width: float, length: float, h: float, bony := false) -> void:
	var tread := m(Color(0.16, 0.16, 0.17), 0.4, 0.7)
	var wheel := m(Color(0.32, 0.32, 0.34), 0.6, 0.5) if not bony else m(Color(0.85, 0.8, 0.68))
	for side in [-1.0, 1.0]:
		var x: float = side * width * 0.5
		Gear.part(root, Gear.box(Vector3(0.2, h, length - h)), tread, Vector3(x, h * 0.5, 0))
		for z in [-1.0, 1.0]:
			Gear.part(root, Gear.cyl(h * 0.5, 0.2), tread, Vector3(x, h * 0.5, z * (length - h) * 0.5), Vector3(0, 0, PI / 2))
		for i in 5:
			var zz := lerpf(-(length - h) * 0.42, (length - h) * 0.42, i / 4.0)
			Gear.part(root, Gear.cyl(h * 0.36, 0.22), wheel, Vector3(x, h * 0.42, zz), Vector3(0, 0, PI / 2))
			Gear.part(root, Gear.cyl(h * 0.12, 0.24), Gear.brass() if not bony else tread, Vector3(x, h * 0.42, zz), Vector3(0, 0, PI / 2))
		for i in 9:
			var zz := lerpf(-(length - h) * 0.5, (length - h) * 0.5, i / 8.0)
			Gear.part(root, Gear.box(Vector3(0.22, 0.03, 0.06)), wheel, Vector3(x, h + 0.01, zz))
		# Mudguard along the top.
		Gear.part(root, Gear.box(Vector3(0.24, 0.03, length * 1.02)), tread, Vector3(x, h + 0.05, 0))


static func rivets(root: Node3D, from: Vector3, to: Vector3, n: int, mat_r: Material) -> void:
	for i in n:
		Gear.part(root, Gear.sphere(0.018), mat_r, from.lerp(to, i / float(maxi(1, n - 1))))


## A smokestack with a flared crown and live smoke.
static func stack(root: Node3D, at: Vector3, h: float, necro := false) -> void:
	var iron := m(Color(0.2, 0.2, 0.22), 0.5)
	Gear.part(root, Gear.cyl(0.055, h), iron, at + Vector3(0, h * 0.5, 0))
	Gear.part(root, Gear.cyl(0.085, 0.07, 0.06), Gear.brass() if not necro else iron, at + Vector3(0, h, 0))
	var chim := Gear.chimney(necro)
	for c in chim.get_children():
		if c is GPUParticles3D:
			var smoke: GPUParticles3D = c.duplicate()
			smoke.position = at + Vector3(0, h + 0.05, 0)
			smoke.scale = Vector3.ONE * 0.6
			root.add_child(smoke)
	chim.free()


# --- Monarchy ---------------------------------------------------------------------------------

## Landpanzer: riveted steam tank, domed turret with a long cannon, twin stacks.
static func landpanzer(team: Color) -> Node3D:
	var root := Node3D.new()
	var hull := m(Color(0.34, 0.36, 0.3), 0.55, 0.45)
	var dark := m(Color(0.22, 0.23, 0.2), 0.5, 0.5)
	tracks(root, 0.86, 1.36, 0.3)
	Gear.part(root, Gear.box(Vector3(0.66, 0.26, 1.2)), hull, Vector3(0, 0.42, -0.02))
	# Sloped glacis and rear deck.
	Gear.part(root, Gear.box(Vector3(0.66, 0.06, 0.34)), hull, Vector3(0, 0.5, 0.6), Vector3(-0.55, 0, 0))
	Gear.part(root, Gear.box(Vector3(0.7, 0.05, 1.28)), dark, Vector3(0, 0.56, -0.02))
	for side in [-1.0, 1.0]:
		rivets(root, Vector3(side * 0.335, 0.5, -0.55), Vector3(side * 0.335, 0.5, 0.55), 8, Gear.brass())
		rivets(root, Vector3(side * 0.335, 0.34, -0.55), Vector3(side * 0.335, 0.34, 0.55), 8, Gear.brass())
	# Boiler and stacks at the back.
	Gear.part(root, Gear.cyl(0.17, 0.5), Gear.copper(), Vector3(0, 0.72, -0.42), Vector3(0, 0, PI / 2))
	for x in [-0.12, 0.12]:
		Gear.part(root, Gear.torus(0.17, 0.19), Gear.brass(), Vector3(x, 0.72, -0.42), Vector3(0, 0, PI / 2))
	stack(root, Vector3(-0.16, 0.8, -0.56), 0.42)
	stack(root, Vector3(0.16, 0.8, -0.56), 0.36)
	# Turret: drum, dome, brass rim, team band, hatch, cannon with a muzzle brake.
	Gear.part(root, Gear.cyl(0.27, 0.2), hull, Vector3(0, 0.68, 0.08))
	Gear.part(root, Gear.sphere(0.27, true), hull, Vector3(0, 0.78, 0.08), Vector3.ZERO, Vector3(1, 0.55, 1))
	Gear.part(root, Gear.torus(0.26, 0.29), Gear.brass(), Vector3(0, 0.6, 0.08))
	Gear.part(root, Gear.cyl(0.275, 0.06), Gear.mat(team), Vector3(0, 0.72, 0.08))
	Gear.part(root, Gear.cyl(0.08, 0.04), Gear.brass(), Vector3(0.08, 0.92, 0.0))
	Gear.part(root, Gear.cyl(0.05, 0.78), dark, Vector3(0, 0.74, 0.55), Vector3(PI / 2, 0, 0))
	Gear.part(root, Gear.cyl(0.075, 0.12), dark, Vector3(0, 0.74, 0.96), Vector3(PI / 2, 0, 0))
	Gear.part(root, Gear.torus(0.05, 0.075), Gear.brass(), Vector3(0, 0.74, 0.3), Vector3(PI / 2, 0, 0))
	# Aether vents and a headlamp.
	for x in [-0.22, 0.22]:
		Gear.part(root, Gear.box(Vector3(0.1, 0.03, 0.06)), Gear.aether(), Vector3(x, 0.57, -0.2))
	Gear.part(root, Gear.sphere(0.05), Gear.mat(Color(1.0, 0.92, 0.6), 2.0), Vector3(0.24, 0.5, 0.66))
	return root


## Škoda Siege Crawler: tracked mortar platform with a boiler.
static func siege_crawler(team: Color) -> Node3D:
	var root := Node3D.new()
	var hull := m(Color(0.3, 0.32, 0.28), 0.55, 0.45)
	tracks(root, 0.86, 1.3, 0.28)
	Gear.part(root, Gear.box(Vector3(0.66, 0.16, 1.18)), hull, Vector3(0, 0.36, 0))
	Gear.part(root, Gear.cyl(0.3, 0.1), Gear.brass(), Vector3(0, 0.48, 0.12))
	# The mortar: a fat barrel on trunnions, pointing up and forward.
	for x in [-0.2, 0.2]:
		Gear.part(root, Gear.box(Vector3(0.06, 0.3, 0.16)), hull, Vector3(x, 0.66, 0.12))
	# Barrel tilted forward and up; rings and the muzzle band follow its axis.
	var tilt := 0.7
	var axis := Vector3(0, cos(tilt), sin(tilt))
	var mid := Vector3(0, 0.86, 0.22)
	Gear.part(root, Gear.cyl(0.17, 0.7, 0.15), m(Color(0.2, 0.2, 0.22), 0.6), mid, Vector3(tilt, 0, 0))
	for t in [-0.18, 0.0, 0.18]:
		Gear.part(root, Gear.torus(0.155, 0.185), Gear.brass(), mid + axis * t, Vector3(tilt, 0, 0))
	Gear.part(root, Gear.torus(0.13, 0.17), Gear.brass(), mid + axis * 0.35, Vector3(tilt, 0, 0))
	Gear.part(root, Gear.cyl(0.16, 0.38), Gear.copper(), Vector3(0, 0.56, -0.42), Vector3(0, 0, PI / 2))
	stack(root, Vector3(0.18, 0.6, -0.5), 0.36)
	Gear.part(root, Gear.box(Vector3(0.68, 0.06, 0.14)), Gear.mat(team), Vector3(0, 0.46, -0.58))
	return root


## Kress Gyrocopter: brass fuselage, open cockpit, spinning rotors, bomb rack.
static func gyrocopter(team: Color) -> Node3D:
	var root := Node3D.new()
	var wood := m(Color(0.5, 0.33, 0.2), 0.0, 0.7)
	var body := CapsuleMesh.new()
	body.radius = 0.16
	body.height = 0.8
	body.radial_segments = Gear.SEG
	Gear.part(root, body, Gear.brass(), Vector3(0, 0.3, 0.05), Vector3(PI / 2, 0, 0))
	Gear.part(root, Gear.cyl(0.04, 0.7, 0.02), wood, Vector3(0, 0.34, -0.6), Vector3(PI / 2, 0, 0))
	Gear.part(root, Gear.sphere(0.12), m(Color(0.6, 0.85, 1.0), 0.0, 0.1), Vector3(0, 0.42, 0.18), Vector3.ZERO, Vector3(1, 0.7, 1.2))
	Gear.part(root, Gear.box(Vector3(0.36, 0.03, 0.14)), Gear.mat(team), Vector3(0, 0.3, -0.25))
	# Skids.
	for side in [-1.0, 1.0]:
		Gear.part(root, Gear.cyl(0.018, 0.7), Gear.copper(), Vector3(side * 0.18, 0.02, 0.05), Vector3(PI / 2, 0, 0))
		for z in [-0.15, 0.25]:
			Gear.part(root, Gear.cyl(0.015, 0.2), Gear.copper(), Vector3(side * 0.13, 0.1, z), Vector3(0, 0, side * 0.5))
	# Bombs.
	for x in [-0.08, 0.08]:
		Gear.part(root, Gear.sphere(0.055), Gear.aether(), Vector3(x, 0.12, 0.1))
	# Mast and main rotor.
	Gear.part(root, Gear.cyl(0.03, 0.22), Gear.copper(), Vector3(0, 0.55, 0.05))
	var rotor := Node3D.new()
	rotor.position = Vector3(0, 0.67, 0.05)
	rotor.set_meta("spin", 14.0)
	root.add_child(rotor)
	Gear.part(rotor, Gear.cyl(0.05, 0.05), Gear.brass())
	for i in 3:
		var a := TAU * i / 3.0
		Gear.part(rotor, Gear.box(Vector3(0.62, 0.012, 0.07)), wood, Vector3(cos(a) * 0.33, 0, sin(a) * 0.33), Vector3(0, -a, 0))
	# Tail rotor.
	var tail := Node3D.new()
	tail.position = Vector3(0.05, 0.36, -0.92)
	tail.rotation = Vector3(0, 0, PI / 2)
	tail.set_meta("spin", 18.0)
	root.add_child(tail)
	Gear.part(tail, Gear.box(Vector3(0.24, 0.01, 0.04)), wood)
	return root


# --- Covenant -----------------------------------------------------------------------------------

## Bone Juggernaut: tracked iron hull armoured in bone, skull ram, soul furnace.
static func juggernaut(team: Color) -> Node3D:
	var root := Node3D.new()
	var iron := m(Color(0.18, 0.17, 0.19), 0.5, 0.55)
	var bone := m(Color(0.86, 0.82, 0.7), 0.0, 0.7)
	tracks(root, 0.88, 1.36, 0.3, true)
	Gear.part(root, Gear.box(Vector3(0.68, 0.3, 1.18)), iron, Vector3(0, 0.44, 0))
	# Bone ribs arching over the hull.
	for i in 5:
		var z := -0.45 + i * 0.22
		Gear.part(root, Gear.torus(0.3, 0.36), bone, Vector3(0, 0.55, z), Vector3(0, 0, 0), Vector3(1.0, 0.8, 0.35))
	# Spikes along the sides.
	for side in [-1.0, 1.0]:
		for i in 4:
			var spike := CylinderMesh.new()
			spike.top_radius = 0.0
			spike.bottom_radius = 0.04
			spike.height = 0.18
			spike.radial_segments = 10
			Gear.part(root, spike, bone, Vector3(side * 0.42, 0.5, -0.4 + i * 0.27), Vector3(0, 0, -side * PI / 2))
	# Skull ram at the front.
	Gear.part(root, Gear.sphere(0.2), bone, Vector3(0, 0.46, 0.66), Vector3.ZERO, Vector3(1, 0.9, 0.8))
	for x in [-0.07, 0.07]:
		Gear.part(root, Gear.sphere(0.05), Gear.soul(), Vector3(x, 0.5, 0.8))
	Gear.part(root, Gear.box(Vector3(0.22, 0.06, 0.1)), bone, Vector3(0, 0.34, 0.74))
	# Soul furnace and green-smoking stacks.
	Gear.part(root, Gear.cyl(0.2, 0.3), iron, Vector3(0, 0.75, -0.3))
	Gear.part(root, Gear.cyl(0.14, 0.32), Gear.soul(), Vector3(0, 0.75, -0.3))
	Gear.part(root, Gear.torus(0.2, 0.23), bone, Vector3(0, 0.9, -0.3))
	stack(root, Vector3(-0.2, 0.6, -0.52), 0.42, true)
	stack(root, Vector3(0.2, 0.6, -0.52), 0.36, true)
	Gear.part(root, Gear.box(Vector3(0.7, 0.05, 0.12)), Gear.mat(team), Vector3(0, 0.6, 0.38))
	return root


## Corpse Crawler: tracked bone engine with a throwing arm and a green bucket.
static func corpse_crawler(team: Color) -> Node3D:
	var root := Node3D.new()
	var iron := m(Color(0.2, 0.19, 0.2), 0.5)
	var bone := m(Color(0.86, 0.82, 0.7))
	tracks(root, 0.86, 1.3, 0.28, true)
	Gear.part(root, Gear.box(Vector3(0.66, 0.16, 1.16)), iron, Vector3(0, 0.36, 0))
	for x in [-0.25, 0.25]:
		Gear.part(root, Gear.box(Vector3(0.07, 0.6, 0.07)), bone, Vector3(x, 0.72, 0.1))
	Gear.part(root, Gear.cyl(0.04, 0.6), iron, Vector3(0, 1.0, 0.1), Vector3(0, 0, PI / 2))
	Gear.part(root, Gear.box(Vector3(0.08, 0.08, 1.2)), bone, Vector3(0, 1.0, -0.15), Vector3(0.5, 0, 0))
	Gear.part(root, Gear.sphere(0.16, true), iron, Vector3(0, 1.3, -0.65), Vector3(PI, 0, 0))
	Gear.part(root, Gear.sphere(0.13), Gear.soul(), Vector3(0, 1.3, -0.65))
	Gear.part(root, Gear.sphere(0.12), bone, Vector3(0, 0.55, 0.62))
	Gear.part(root, Gear.box(Vector3(0.68, 0.05, 0.12)), Gear.mat(team), Vector3(0, 0.46, 0.5))
	return root


## Plague Balloon: stitched gas-bag, ropes, bone gondola with plague bottles.
static func plague_balloon(team: Color) -> Node3D:
	var root := Node3D.new()
	var skin := m(Color(0.42, 0.45, 0.32), 0.0, 0.9)
	var bone := m(Color(0.85, 0.8, 0.68))
	Gear.part(root, Gear.sphere(0.42), skin, Vector3(0, 0.95, 0), Vector3.ZERO, Vector3(1.0, 0.8, 1.45))
	for z in [-0.35, 0.0, 0.35]:
		Gear.part(root, Gear.torus(0.4, 0.43), m(Color(0.3, 0.25, 0.2)), Vector3(0, 0.95, z), Vector3(PI / 2, 0, 0), Vector3(1.0, 1.0, 0.8))
	Gear.part(root, Gear.box(Vector3(0.3, 0.04, 0.5)), Gear.mat(team), Vector3(0, 1.3, 0))
	# Ropes and the gondola.
	for x in [-0.15, 0.15]:
		for z in [-0.2, 0.2]:
			Gear.part(root, Gear.cyl(0.008, 0.45), bone, Vector3(x * 1.2, 0.45, z * 1.2), Vector3(z * 0.4, 0, -x * 0.4))
	Gear.part(root, Gear.box(Vector3(0.32, 0.14, 0.44)), m(Color(0.3, 0.22, 0.16)), Vector3(0, 0.2, 0))
	for i in 3:
		Gear.part(root, Gear.cyl(0.035, 0.12), Gear.soul(), Vector3(-0.1 + i * 0.1, 0.3, 0.14))
	Gear.part(root, Gear.sphere(0.07), bone, Vector3(0, 0.22, 0.24))
	var prop := Node3D.new()
	prop.position = Vector3(0, 0.25, -0.3)
	prop.rotation = Vector3(PI / 2, 0, 0)
	prop.set_meta("spin", 12.0)
	root.add_child(prop)
	Gear.part(prop, Gear.box(Vector3(0.3, 0.01, 0.05)), bone)
	return root



## Tesla's armoured Aether locomotive with its tender: boiler, cab, cowcatcher,
## coupled driving wheels, a glowing Aether lamp and a smoking stack.
static func aether_train(team: Color) -> Node3D:
	var root := Node3D.new()
	var iron := m(Color(0.16, 0.17, 0.19), 0.6, 0.45)
	var green := m(Color(0.16, 0.3, 0.22), 0.4, 0.5)
	# Frame and wheels.
	Gear.part(root, Gear.box(Vector3(0.5, 0.08, 1.9)), iron, Vector3(0, 0.22, -0.1))
	for side in [-1.0, 1.0]:
		for i in 4:
			var z := 0.55 - i * 0.28
			Gear.part(root, Gear.cyl(0.13, 0.05), m(Color(0.6, 0.12, 0.1), 0.4, 0.5), Vector3(side * 0.27, 0.15, z), Vector3(0, 0, PI / 2))
			Gear.part(root, Gear.cyl(0.04, 0.06), Gear.brass(), Vector3(side * 0.28, 0.15, z), Vector3(0, 0, PI / 2))
		Gear.part(root, Gear.box(Vector3(0.02, 0.03, 0.9)), m(Color(0.7, 0.72, 0.75), 0.8, 0.3), Vector3(side * 0.31, 0.15, 0.13))
		for i in 2:
			Gear.part(root, Gear.cyl(0.09, 0.05), iron, Vector3(side * 0.27, 0.1, -0.62 - i * 0.28), Vector3(0, 0, PI / 2))
	# Boiler with brass bands, smokestack, steam dome, Aether lamp.
	Gear.part(root, Gear.cyl(0.2, 0.9), green, Vector3(0, 0.46, 0.35), Vector3(PI / 2, 0, 0))
	for z in [0.05, 0.35, 0.65]:
		Gear.part(root, Gear.torus(0.2, 0.22), Gear.brass(), Vector3(0, 0.46, z), Vector3(PI / 2, 0, 0))
	Gear.part(root, Gear.cyl(0.2, 0.04), iron, Vector3(0, 0.46, 0.81), Vector3(PI / 2, 0, 0))
	stack(root, Vector3(0, 0.62, 0.62), 0.32)
	Gear.part(root, Gear.sphere(0.09, true), Gear.brass(), Vector3(0, 0.65, 0.3))
	Gear.part(root, Gear.sphere(0.07), Gear.aether(), Vector3(0, 0.56, 0.84))
	# Cowcatcher.
	var wedge := CylinderMesh.new()
	wedge.top_radius = 0.0
	wedge.bottom_radius = 0.24
	wedge.height = 0.24
	wedge.radial_segments = 3
	Gear.part(root, wedge, iron, Vector3(0, 0.18, 0.9), Vector3(PI / 2, 0, 0), Vector3(1.0, 1.0, 0.6))
	# Cab with a team-colour band and armoured roof.
	Gear.part(root, Gear.box(Vector3(0.52, 0.42, 0.38)), green, Vector3(0, 0.5, -0.24))
	Gear.part(root, Gear.box(Vector3(0.58, 0.05, 0.46)), iron, Vector3(0, 0.73, -0.24))
	Gear.part(root, Gear.box(Vector3(0.53, 0.06, 0.39)), Gear.mat(team), Vector3(0, 0.4, -0.24))
	for x in [-0.27, 0.27]:
		Gear.part(root, Gear.box(Vector3(0.01, 0.12, 0.14)), Gear.aether(), Vector3(x, 0.56, -0.2))
	# Tender with coal and an Aether turret.
	Gear.part(root, Gear.box(Vector3(0.5, 0.3, 0.5)), iron, Vector3(0, 0.38, -0.72))
	Gear.part(root, Gear.box(Vector3(0.44, 0.06, 0.44)), m(Color(0.08, 0.08, 0.08)), Vector3(0, 0.55, -0.72))
	Gear.part(root, Gear.cyl(0.12, 0.1), iron, Vector3(0, 0.62, -0.72))
	Gear.part(root, Gear.cyl(0.025, 0.35), Gear.brass(), Vector3(0, 0.66, -0.55), Vector3(PI / 2, 0, 0))
	return root
