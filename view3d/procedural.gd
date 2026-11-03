extends RefCounted
## Low-poly models built from primitives, for things the asset packs don't have:
## flyers, ships, fish shoals and the pier. All face +Z, sizes in tiles.
## Parts tagged with meta "flap" (wings) or "spin" are animated by EntityViews.
## Soldiers' steampunk kit lives in gear.gd.

const Gear = preload("res://view3d/gear.gd")
const Machines = preload("res://view3d/machines.gd")

static var _mats := {}


static func mat(color: Color, emissive := 0.0, alpha := 1.0) -> StandardMaterial3D:
	var key := "%s/%s/%s" % [color.to_html(), emissive, alpha]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(color, alpha)
		m.roughness = 0.85
		if emissive > 0.0:
			m.emission_enabled = true
			m.emission = color
			m.emission_energy_multiplier = emissive
		if alpha < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats[key] = m
	return _mats[key]


static func build(kind: String, team: Color) -> Node3D:
	match kind:
		"griffin":
			return _griffin()
		"double_eagle":
			return _double_eagle()
		"musket":
			return _musket(false, true)
		"aether_musket":
			return _musket(true, false)
		"rifle":
			return _musket(false, false, 1.25)
		"bearskin":
			return _hat("bearskin")
		"shako":
			return _hat("shako")
		"tyrol_hat":
			return _hat("tyrol")
		"bicorne":
			return _hat("bicorne")
		"crown":
			return _hat("crown")
		"war_wagon":
			return _war_wagon(team)
		"glider":
			return _glider()
		"steam_walker":
			return _steam_walker(team)
		"mortar":
			return _mortar(team)
		"catapult":
			return _catapult(team)
		"horse":
			return _horse(false)
		"bone_horse":
			return _horse(true)
		"aethership":
			return _aethership(team)
		"ironclad":
			return _ironclad(team)
		"ghost_ship":
			return _ghost_ship()
		"clock_face":
			return _clock_face()
		"viaduct":
			return _viaduct(team)
		"smokestack":
			var st := Node3D.new()
			_part(st, _cyl(0.22, 3.2, 10), mat(Color(0.45, 0.25, 0.2)), Vector3(0, 1.6, 0))
			_part(st, _cyl(0.27, 0.2, 10), mat(Color(0.2, 0.2, 0.2)), Vector3(0, 3.2, 0))
			return st
		"relic_crown":
			return _relic("crown")
		"relic_lance":
			return _relic("lance")
		"relic_bowl":
			return _relic("bowl")
		"relic_horn":
			return _relic("horn")
		"relic_orb":
			return _relic("orb")
		"drake":
			return _drake()
		"bats":
			return _bats()
		"skiff":
			return _ship(1.1, 0.45, 1, team, false)
		"transport":
			return _ship(2.0, 0.85, 1, team, true)
		"warship":
			return _ship(2.4, 0.75, 2, team, false, true)
		"fish":
			return _fish_shoal()
		"pier":
			return _pier()
		"landpanzer", "juggernaut", "gyrocopter", "plague_balloon", "siege_crawler", "corpse_crawler":
			return Machines.build(kind, team)
		"goggles", "top_hat", "aether_pack", "pauldron", "aether_staff", "soul_lantern", "grave_pack", "tool_pack", "necro_circlet", "chimney", "soul_chimney", "wall_cog", "aether_lamp", "soul_lamp", "pipes":
			return Gear.build(kind)
	return Node3D.new()


static func _part(parent: Node3D, mesh: Mesh, m: Material, pos: Vector3, rot := Vector3.ZERO, scale := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	mi.scale = scale
	parent.add_child(mi)
	return mi


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func _sphere(r: float, segs := 10) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segs
	s.rings = segs / 2
	return s


static func _cone(r: float, h: float, segs := 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	return c


static func _cyl(r: float, h: float, segs := 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	return c


## A wing pivoting at the body: a flat tapered panel extending sideways (side = 1 or -1).
static func _wing(parent: Node3D, side: float, span: float, chord: float, m: Material, at: Vector3) -> void:
	var pivot := Node3D.new()
	pivot.position = at
	pivot.set_meta("flap", side)
	parent.add_child(pivot)
	_part(pivot, _box(Vector3(span, 0.04, chord)), m, Vector3(side * span * 0.5, 0, 0))
	_part(pivot, _box(Vector3(span * 0.6, 0.035, chord * 0.6)), m, Vector3(side * span * 1.1, 0, -chord * 0.15))


static func _griffin() -> Node3D:
	var root := Node3D.new()
	var fur := mat(Color(0.72, 0.55, 0.32))
	var feathers := mat(Color(0.95, 0.93, 0.88))
	var beak := mat(Color(0.95, 0.75, 0.2))
	var body := CapsuleMesh.new()
	body.radius = 0.22
	body.height = 0.9
	_part(root, body, fur, Vector3(0, 0, -0.05), Vector3(PI / 2, 0, 0))
	_part(root, _sphere(0.2), feathers, Vector3(0, 0.12, 0.42))
	_part(root, _cone(0.07, 0.22), beak, Vector3(0, 0.1, 0.64), Vector3(PI / 2, 0, 0))
	for side in [-1.0, 1.0]:
		_part(root, _cone(0.05, 0.16), feathers, Vector3(side * 0.09, 0.32, 0.38))
		_part(root, _cyl(0.05, 0.3), fur, Vector3(side * 0.13, -0.25, 0.15))
		_part(root, _cyl(0.05, 0.3), fur, Vector3(side * 0.13, -0.25, -0.3))
		_wing(root, side, 0.55, 0.42, feathers, Vector3(side * 0.18, 0.12, 0.05))
	_part(root, _cone(0.08, 0.5), fur, Vector3(0, 0.0, -0.62), Vector3(-PI / 2 - 0.3, 0, 0))
	return root


static func _drake() -> Node3D:
	var root := Node3D.new()
	var bone := mat(Color(0.86, 0.83, 0.74))
	var membrane := mat(Color(0.45, 0.2, 0.55), 0.3, 0.75)
	var eyes := mat(Color(0.5, 1.0, 0.4), 3.0)
	var body := CapsuleMesh.new()
	body.radius = 0.26
	body.height = 1.1
	_part(root, body, bone, Vector3(0, 0, -0.1), Vector3(PI / 2, 0, 0))
	_part(root, _cyl(0.09, 0.55), bone, Vector3(0, 0.22, 0.55), Vector3(PI / 2 - 0.6, 0, 0))
	_part(root, _box(Vector3(0.24, 0.18, 0.42)), bone, Vector3(0, 0.42, 0.85))
	for side in [-1.0, 1.0]:
		_part(root, _cone(0.04, 0.28), bone, Vector3(side * 0.08, 0.6, 0.72), Vector3(-0.5, 0, side * 0.3))
		_part(root, _sphere(0.035, 6), eyes, Vector3(side * 0.09, 0.46, 1.02))
		_wing(root, side, 0.8, 0.6, membrane, Vector3(side * 0.22, 0.15, 0.1))
	_part(root, _cone(0.1, 0.9), bone, Vector3(0, -0.05, -0.95), Vector3(-PI / 2 - 0.15, 0, 0))
	return root


static func _bats() -> Node3D:
	var root := Node3D.new()
	var fur := mat(Color(0.2, 0.15, 0.22))
	var wing := mat(Color(0.32, 0.18, 0.35), 0.0, 0.9)
	var swarm := Node3D.new()
	swarm.set_meta("spin", 2.5)
	root.add_child(swarm)
	for i in 6:
		var a := TAU * i / 6.0
		var bat := Node3D.new()
		bat.position = Vector3(cos(a) * 0.35, sin(a * 3.0) * 0.12, sin(a) * 0.35)
		bat.rotation.y = -a
		swarm.add_child(bat)
		_part(bat, _sphere(0.07, 6), fur, Vector3.ZERO)
		for side in [-1.0, 1.0]:
			_wing(bat, side, 0.14, 0.1, wing, Vector3(side * 0.05, 0, 0))
	return root


## A hull with `masts` masts; sails in the team colour.
static func _ship(length: float, beam: float, masts: int, team: Color, cargo := false, armed := false) -> Node3D:
	var root := Node3D.new()
	var wood := mat(Color(0.45, 0.3, 0.18))
	var dark := mat(Color(0.3, 0.2, 0.12))
	var sail := mat(team.lerp(Color.WHITE, 0.25))
	_part(root, _box(Vector3(beam, 0.28, length)), wood, Vector3(0, 0.0, 0))
	_part(root, _box(Vector3(beam * 0.7, 0.24, length * 0.25)), wood, Vector3(0, 0.0, length * 0.55), Vector3(0, PI / 4, 0), Vector3(1, 1, 1))
	_part(root, _box(Vector3(beam * 0.9, 0.06, length * 0.92)), dark, Vector3(0, 0.15, 0))
	_part(root, _box(Vector3(beam * 0.8, 0.22, length * 0.2)), wood, Vector3(0, 0.25, -length * 0.38))
	for i in masts:
		var z := 0.0 if masts == 1 else lerpf(-length * 0.2, length * 0.22, float(i))
		var h := 1.1 + length * 0.2
		_part(root, _cyl(0.035, h), dark, Vector3(0, 0.15 + h * 0.5, z))
		_part(root, _box(Vector3(beam * 1.25, h * 0.55, 0.03)), sail, Vector3(0, 0.25 + h * 0.6, z + 0.04))
	if cargo:
		for i in 3:
			_part(root, _box(Vector3(0.28, 0.24, 0.28)), dark, Vector3((i - 1) * 0.3, 0.3, length * 0.18))
	if armed:
		for side in [-1.0, 1.0]:
			for z in [-0.4, 0.3]:
				_part(root, _cyl(0.05, 0.4), dark, Vector3(side * beam * 0.55, 0.2, z * length * 0.5), Vector3(0, 0, PI / 2))
	return root


static func _fish_shoal() -> Node3D:
	var root := Node3D.new()
	var ripple := mat(Color(0.75, 0.9, 1.0), 0.4, 0.45)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.48
	_part(root, torus, ripple, Vector3(0, 0.02, 0), Vector3.ZERO, Vector3(1, 0.15, 1))
	var school := Node3D.new()
	school.set_meta("spin", 0.8)
	root.add_child(school)
	var scales := mat(Color(0.75, 0.82, 0.9))
	for i in 5:
		var a := TAU * i / 5.0
		var fish := CapsuleMesh.new()
		fish.radius = 0.04
		fish.height = 0.22
		_part(school, fish, scales, Vector3(cos(a) * 0.28, 0.03, sin(a) * 0.28), Vector3(PI / 2, -a, 0))
	return root


static func _pier() -> Node3D:
	var root := Node3D.new()
	var plank := mat(Color(0.55, 0.38, 0.22))
	var post := mat(Color(0.35, 0.24, 0.14))
	_part(root, _box(Vector3(2.8, 0.12, 2.8)), plank, Vector3(0, 0.35, 0))
	for x in [-1.25, 0.0, 1.25]:
		for z in [-1.25, 0.0, 1.25]:
			_part(root, _cyl(0.07, 1.2), post, Vector3(x, -0.2, z))
	_part(root, _box(Vector3(1.1, 0.8, 0.9)), post, Vector3(-0.7, 0.8, -0.8))
	_part(root, _box(Vector3(0.9, 0.5, 0.5)), plank, Vector3(-0.7, 1.45, -0.8), Vector3(0, 0, 0.0))
	for i in 3:
		_part(root, _box(Vector3(0.32, 0.3, 0.32)), post, Vector3(0.6 + (i % 2) * 0.36, 0.56 + (i / 2) * 0.3, 0.7))
	_part(root, _cyl(0.05, 1.6), post, Vector3(1.1, 1.15, -1.1))
	return root


static func _musket(aether: bool, bayonet: bool, length := 1.0) -> Node3D:
	var root := Node3D.new()
	var wood := mat(Color(0.42, 0.26, 0.14))
	var steel := mat(Color(0.55, 0.57, 0.6))
	var brass := mat(Color(0.8, 0.62, 0.25))
	var l := 1.5 * length
	_part(root, _box(Vector3(0.09, 0.45, 0.14)), wood, Vector3(0, -0.25, 0.02))
	_part(root, _box(Vector3(0.07, l * 0.55, 0.08)), wood, Vector3(0, l * 0.25, 0))
	_part(root, _cyl(0.025, l * 0.8), steel, Vector3(0, l * 0.38, 0.05))
	_part(root, _box(Vector3(0.1, 0.06, 0.1)), brass, Vector3(0, 0.05, 0.03))
	if bayonet:
		_part(root, _cone(0.02, 0.35), steel, Vector3(0, l * 0.78 + 0.17, 0.08))
	if aether:
		_part(root, _sphere(0.06, 8), mat(Color(0.45, 0.85, 1.0), 3.0), Vector3(0, l * 0.78, 0.05))
		_part(root, _cyl(0.05, 0.18), brass, Vector3(0, l * 0.45, 0.1))
	return root


## Period headgear, sitting on top of the (big) KayKit head.
static func _hat(style: String) -> Node3D:
	var root := Node3D.new()
	var black := mat(Color(0.08, 0.08, 0.09))
	var gold := mat(Color(0.85, 0.68, 0.22))
	match style:
		"bearskin":
			var fur := CapsuleMesh.new()
			fur.radius = 0.36
			fur.height = 1.1
			_part(root, fur, black, Vector3(0, 0.5, 0))
			_part(root, _box(Vector3(0.3, 0.22, 0.04)), gold, Vector3(0, 0.25, 0.35))
		"shako":
			_part(root, _cyl(0.36, 0.5), black, Vector3(0, 0.25, 0))
			_part(root, _box(Vector3(0.62, 0.05, 0.3)), black, Vector3(0, 0.0, 0.25))
			_part(root, _sphere(0.08, 8), gold, Vector3(0, 0.42, 0.33))
		"tyrol":
			var loden := mat(Color(0.25, 0.32, 0.2))
			var crown := CylinderMesh.new()
			crown.top_radius = 0.18
			crown.bottom_radius = 0.34
			crown.height = 0.45
			_part(root, crown, loden, Vector3(0, 0.25, 0))
			_part(root, _cyl(0.55, 0.05), loden, Vector3(0, 0.03, 0))
			_part(root, _box(Vector3(0.04, 0.45, 0.12)), mat(Color(0.9, 0.9, 0.85)), Vector3(0.3, 0.45, -0.05), Vector3(0, 0, -0.4))
		"bicorne":
			_part(root, _box(Vector3(0.95, 0.32, 0.22)), black, Vector3(0, 0.18, 0))
			_part(root, _sphere(0.07, 8), gold, Vector3(0.25, 0.28, 0.12))
		"crown":
			var band := CylinderMesh.new()
			band.top_radius = 0.34
			band.bottom_radius = 0.3
			band.height = 0.22
			band.radial_segments = 12
			_part(root, band, gold, Vector3(0, 0.11, 0))
			for i in 6:
				var a := TAU * i / 6.0
				_part(root, _cone(0.06, 0.2), gold, Vector3(cos(a) * 0.3, 0.3, sin(a) * 0.3))
			_part(root, _sphere(0.12, 8), mat(Color(0.75, 0.1, 0.15)), Vector3(0, 0.3, 0))
			_part(root, _box(Vector3(0.05, 0.22, 0.05)), gold, Vector3(0, 0.48, 0))
	return root


## The Hussite war wagon: armoured box on four wheels, team-coloured pavises.
## Side boards (meta "deploy") swing out when it deploys into a Wagenburg.
static func _war_wagon(team: Color) -> Node3D:
	var root := Node3D.new()
	var wood := mat(Color(0.45, 0.3, 0.17))
	var dark := mat(Color(0.28, 0.18, 0.1))
	var paint := mat(team.darkened(0.2))
	_part(root, _box(Vector3(0.8, 0.45, 1.5)), wood, Vector3(0, 0.45, 0))
	_part(root, _box(Vector3(0.85, 0.08, 1.55)), dark, Vector3(0, 0.7, 0))
	for x in [-0.42, 0.42]:
		for z in [-0.5, 0.5]:
			_part(root, _cyl(0.2, 0.08, 10), dark, Vector3(x, 0.2, z), Vector3(0, 0, PI / 2))
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * 0.42, 0.7, 0)
		pivot.set_meta("deploy", side)
		root.add_child(pivot)
		_part(pivot, _box(Vector3(0.06, 0.55, 1.4)), paint, Vector3(side * 0.03, 0.27, 0))
		_part(pivot, _box(Vector3(0.07, 0.1, 1.42)), dark, Vector3(side * 0.03, 0.5, 0))
	_part(root, _cyl(0.025, 0.7), dark, Vector3(0, 0.45, 1.05), Vector3(PI / 2, 0, 0))
	return root


## Black two-headed eagle with golden beaks and crown.
static func _double_eagle() -> Node3D:
	var root := Node3D.new()
	var feathers := mat(Color(0.1, 0.1, 0.11))
	var gold := mat(Color(0.95, 0.75, 0.2))
	var red := mat(Color(0.75, 0.12, 0.12))
	var body := CapsuleMesh.new()
	body.radius = 0.22
	body.height = 0.8
	_part(root, body, feathers, Vector3(0, 0, -0.05), Vector3(PI / 2, 0, 0))
	for side in [-1.0, 1.0]:
		_part(root, _cyl(0.06, 0.3), feathers, Vector3(side * 0.12, 0.2, 0.3), Vector3(0.5, 0, side * 0.5))
		_part(root, _sphere(0.12), feathers, Vector3(side * 0.2, 0.35, 0.42))
		_part(root, _cone(0.05, 0.16), gold, Vector3(side * 0.24, 0.33, 0.56), Vector3(PI / 2, 0, -side * 0.3))
		_part(root, _sphere(0.025, 6), red, Vector3(side * 0.28, 0.38, 0.5))
		_wing(root, side, 0.6, 0.45, feathers, Vector3(side * 0.18, 0.1, 0.0))
	_part(root, _cyl(0.1, 0.12, 6), gold, Vector3(0, 0.52, 0.42))
	var tail := CylinderMesh.new()
	tail.top_radius = 0.2
	tail.bottom_radius = 0.02
	tail.height = 0.45
	_part(root, tail, feathers, Vector3(0, -0.02, -0.55), Vector3(PI / 2, 0, 0))
	return root


## Wilhelm Kress-style kite glider the Kress Flyer hangs beneath.
static func _glider() -> Node3D:
	var root := Node3D.new()
	var frame := mat(Color(0.45, 0.3, 0.16))
	var cloth := mat(Color(0.95, 0.9, 0.75))
	var brass := mat(Color(0.8, 0.62, 0.25))
	_part(root, _box(Vector3(2.4, 0.03, 0.7)), cloth, Vector3(0, 1.45, 0.1))
	_part(root, _box(Vector3(0.9, 0.03, 0.45)), cloth, Vector3(0, 1.45, -0.9))
	_part(root, _cyl(0.025, 1.3), frame, Vector3(0, 1.45, -0.3), Vector3(PI / 2, 0, 0))
	for x in [-0.25, 0.25]:
		_part(root, _cyl(0.015, 1.1), frame, Vector3(x, 0.9, 0.1))
	_part(root, _cyl(0.08, 0.25), brass, Vector3(0, 1.4, 0.55), Vector3(PI / 2, 0, 0))
	_part(root, _sphere(0.07, 8), mat(Color(0.45, 0.85, 1.0), 3.0), Vector3(0, 1.4, 0.7))
	return root


# --- Ages 4-6 ------------------------------------------------------------------------

static func _brass() -> StandardMaterial3D:
	var m := mat(Color(0.78, 0.6, 0.28))
	m.metallic = 0.7
	m.roughness = 0.4
	return m


## Two-legged steam engine: boiler body, smoke stack, rotary gun; legs swing ("gallop").
static func _steam_walker(team: Color) -> Node3D:
	var root := Node3D.new()
	var iron := mat(Color(0.3, 0.3, 0.33))
	var brass := _brass()
	var glow := mat(Color(0.45, 0.85, 1.0), 3.0)
	_part(root, _cyl(0.32, 0.7, 10), iron, Vector3(0, 1.0, 0), Vector3(PI / 2, 0, 0))
	_part(root, _box(Vector3(0.5, 0.35, 0.5)), brass, Vector3(0, 1.25, -0.1))
	_part(root, _cyl(0.07, 0.5), iron, Vector3(0.15, 1.6, -0.2))
	_part(root, _sphere(0.1, 8), glow, Vector3(0, 1.0, 0.38))
	_part(root, _box(Vector3(0.62, 0.08, 0.3)), mat(team), Vector3(0, 1.36, 0.05))
	for i in 4:
		var a := TAU * i / 4.0
		_part(root, _cyl(0.03, 0.55), iron, Vector3(0.3 + cos(a) * 0.05, 1.0 + sin(a) * 0.05, 0.45), Vector3(PI / 2, 0, 0))
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.25, 0.8, 0)
		hip.set_meta("gallop", side)
		root.add_child(hip)
		_part(hip, _box(Vector3(0.12, 0.45, 0.12)), iron, Vector3(0, -0.22, 0))
		_part(hip, _box(Vector3(0.1, 0.4, 0.1)), brass, Vector3(0, -0.6, 0.06))
		_part(hip, _box(Vector3(0.22, 0.06, 0.32)), iron, Vector3(0, -0.8, 0.08))
	return root


## Škoda siege mortar on a wheeled carriage.
static func _mortar(team: Color) -> Node3D:
	var root := Node3D.new()
	var iron := mat(Color(0.25, 0.27, 0.28))
	var wood := mat(Color(0.45, 0.3, 0.17))
	_part(root, _box(Vector3(0.7, 0.2, 1.1)), wood, Vector3(0, 0.3, 0))
	for x in [-0.4, 0.4]:
		for z in [-0.35, 0.35]:
			_part(root, _cyl(0.2, 0.08, 10), iron, Vector3(x, 0.2, z), Vector3(0, 0, PI / 2))
	_part(root, _cyl(0.2, 0.75, 10), iron, Vector3(0, 0.75, 0.15), Vector3(-0.8, 0, 0))
	_part(root, _cyl(0.24, 0.12, 10), _brass(), Vector3(0, 1.05, 0.42), Vector3(-0.8, 0, 0))
	_part(root, _box(Vector3(0.72, 0.06, 0.2)), mat(team), Vector3(0, 0.42, -0.5))
	return root


## Plague catapult: frame, throwing arm and a bucket of something green.
static func _catapult(team: Color) -> Node3D:
	var root := Node3D.new()
	var wood := mat(Color(0.35, 0.25, 0.18))
	var bone := mat(Color(0.85, 0.82, 0.72))
	_part(root, _box(Vector3(0.8, 0.15, 1.3)), wood, Vector3(0, 0.25, 0))
	for x in [-0.42, 0.42]:
		for z in [-0.45, 0.45]:
			_part(root, _cyl(0.18, 0.08, 8), bone, Vector3(x, 0.18, z), Vector3(0, 0, PI / 2))
		_part(root, _box(Vector3(0.08, 0.7, 0.08)), wood, Vector3(x, 0.65, 0.1))
	_part(root, _box(Vector3(0.1, 0.1, 1.3)), wood, Vector3(0, 0.95, -0.15), Vector3(0.5, 0, 0))
	_part(root, _sphere(0.18, 8), mat(Color(0.45, 0.85, 0.25), 1.5), Vector3(0, 1.3, -0.7))
	_part(root, _box(Vector3(0.82, 0.06, 0.15)), mat(team), Vector3(0, 0.36, 0.6))
	return root


## A horse (or a skeletal one) whose legs swing while it moves ("gallop").
static func _horse(bony: bool) -> Node3D:
	var root := Node3D.new()
	var coat := mat(Color(0.86, 0.83, 0.74)) if bony else mat(Color(0.42, 0.27, 0.15))
	var dark := mat(Color(0.2, 0.14, 0.1)) if not bony else mat(Color(0.3, 0.9, 0.35), 2.0)
	var body := CapsuleMesh.new()
	body.radius = 0.22 if not bony else 0.16
	body.height = 1.1
	_part(root, body, coat, Vector3(0, 0.75, 0), Vector3(PI / 2, 0, 0))
	_part(root, _cyl(0.1, 0.5), coat, Vector3(0, 1.0, 0.55), Vector3(0.7, 0, 0))
	_part(root, _box(Vector3(0.16, 0.18, 0.4)), coat, Vector3(0, 1.15, 0.78), Vector3(0.4, 0, 0))
	_part(root, _box(Vector3(0.05, 0.25, 0.4)), dark, Vector3(0, 1.15, 0.45), Vector3(0.6, 0, 0))
	if bony:
		for side in [-0.06, 0.06]:
			_part(root, _sphere(0.035, 6), dark, Vector3(side, 1.2, 0.95))
	for x in [-0.14, 0.14]:
		for z in [-0.38, 0.38]:
			var hip := Node3D.new()
			hip.position = Vector3(x, 0.62, z)
			hip.set_meta("gallop", 1.0 if (x > 0) == (z > 0) else -1.0)
			root.add_child(hip)
			_part(hip, _cyl(0.05 if not bony else 0.035, 0.6), coat, Vector3(0, -0.3, 0))
	_part(root, _cyl(0.04, 0.45), dark, Vector3(0, 0.85, -0.65), Vector3(-0.5, 0, 0))
	_part(root, _box(Vector3(0.36, 0.08, 0.4)), mat(Color(0.5, 0.1, 0.1)) if not bony else dark, Vector3(0, 0.98, -0.05))
	return root


## Lohner Aethership: striped envelope, gondola, spinning propellers.
static func _aethership(team: Color) -> Node3D:
	var root := Node3D.new()
	var envelope := CapsuleMesh.new()
	envelope.radius = 0.55
	envelope.height = 2.6
	_part(root, envelope, mat(Color(0.12, 0.12, 0.13)), Vector3(0, 1.2, 0), Vector3(PI / 2, 0, 0))
	_part(root, _box(Vector3(1.12, 0.12, 1.6)), mat(team), Vector3(0, 1.2, 0))
	_part(root, _box(Vector3(0.4, 0.3, 1.0)), _brass(), Vector3(0, 0.45, 0))
	for side in [-1.0, 1.0]:
		_part(root, _box(Vector3(0.04, 0.5, 0.4)), mat(team), Vector3(side * 0.3, 1.45, -1.25))
		var prop := Node3D.new()
		prop.position = Vector3(side * 0.35, 0.5, -0.55)
		prop.set_meta("spin_z", 14.0)
		root.add_child(prop)
		_part(prop, _box(Vector3(0.5, 0.06, 0.03)), mat(Color(0.3, 0.22, 0.15)), Vector3.ZERO)
	_part(root, _sphere(0.08, 8), mat(Color(0.45, 0.85, 1.0), 3.0), Vector3(0, 0.3, 0.45))
	return root


## Steam ironclad: low armoured hull, gun turret, funnel.
static func _ironclad(team: Color) -> Node3D:
	var root := Node3D.new()
	var iron := mat(Color(0.28, 0.29, 0.31))
	_part(root, _box(Vector3(0.8, 0.3, 2.4)), iron, Vector3(0, 0.0, 0))
	_part(root, _cone(0.4, 0.5, 4), iron, Vector3(0, 0.0, 1.35), Vector3(PI / 2, PI / 4, 0))
	_part(root, _box(Vector3(0.7, 0.18, 1.2)), mat(Color(0.35, 0.3, 0.25)), Vector3(0, 0.22, -0.2))
	_part(root, _cyl(0.25, 0.22, 10), iron, Vector3(0, 0.38, 0.5))
	_part(root, _cyl(0.05, 0.6), iron, Vector3(0, 0.42, 0.85), Vector3(PI / 2, 0, 0))
	_part(root, _cyl(0.1, 0.55), mat(Color(0.15, 0.15, 0.15)), Vector3(0, 0.6, -0.3))
	_part(root, _box(Vector3(0.82, 0.05, 0.25)), mat(team), Vector3(0, 0.16, -1.0))
	return root


## Ghost ship: pale wreck with tattered, glowing sails.
static func _ghost_ship() -> Node3D:
	var root := Node3D.new()
	var wood := mat(Color(0.3, 0.35, 0.33), 0.0, 0.75)
	var sail := mat(Color(0.55, 1.0, 0.7), 0.8, 0.45)
	_part(root, _box(Vector3(0.75, 0.28, 2.2)), wood, Vector3(0, 0.0, 0))
	for z in [-0.4, 0.45]:
		_part(root, _cyl(0.03, 1.5), wood, Vector3(0, 0.85, z))
		_part(root, _box(Vector3(0.9, 0.8, 0.03)), sail, Vector3(0, 1.0, z + 0.05))
	_part(root, _sphere(0.08, 6), mat(Color(0.5, 1.0, 0.5), 3.0), Vector3(0, 0.35, 1.05))
	return root


## The Orloj's astronomical dial, mounted on the clock tower.
static func _clock_face() -> Node3D:
	var root := Node3D.new()
	_part(root, _cyl(0.55, 0.05, 20), mat(Color(0.2, 0.35, 0.6)), Vector3.ZERO, Vector3(PI / 2, 0, 0))
	_part(root, _cyl(0.6, 0.03, 20), _brass(), Vector3(0, 0, -0.01), Vector3(PI / 2, 0, 0))
	_part(root, _cyl(0.35, 0.06, 16), mat(Color(0.85, 0.7, 0.3)), Vector3(0, 0, 0.02), Vector3(PI / 2, 0, 0))
	var hand := Node3D.new()
	hand.set_meta("spin_z", 0.4)
	hand.position.z = 0.06
	root.add_child(hand)
	_part(hand, _box(Vector3(0.05, 0.5, 0.02)), mat(Color(0.95, 0.85, 0.4), 1.0), Vector3(0, 0.2, 0))
	_part(root, _sphere(0.07, 8), mat(Color(0.95, 0.85, 0.4), 1.5), Vector3(0, 0, 0.08))
	return root


## Semmering viaduct: stone arches carrying rails and a little locomotive.
static func _viaduct(team: Color) -> Node3D:
	var root := Node3D.new()
	var stone := mat(Color(0.75, 0.68, 0.55))
	_part(root, _box(Vector3(3.8, 0.25, 0.8)), stone, Vector3(0, 1.55, 0))
	for i in 4:
		var x := -1.4 + i * 0.95
		_part(root, _box(Vector3(0.35, 1.5, 0.75)), stone, Vector3(x, 0.75, 0))
	for z in [-0.18, 0.18]:
		_part(root, _box(Vector3(3.8, 0.05, 0.05)), mat(Color(0.3, 0.3, 0.32)), Vector3(0, 1.7, z))
	var loco := Node3D.new()
	loco.position = Vector3(0.6, 1.95, 0)
	root.add_child(loco)
	_part(loco, _cyl(0.2, 0.7, 10), mat(Color(0.1, 0.1, 0.1)), Vector3(0, 0, 0), Vector3(0, 0, PI / 2))
	_part(loco, _box(Vector3(0.35, 0.4, 0.42)), mat(team), Vector3(-0.45, 0.05, 0))
	_part(loco, _cyl(0.07, 0.3), mat(Color(0.1, 0.1, 0.1)), Vector3(0.25, 0.3, 0))
	return root


## The five AEIOU relics, gleaming and slowly turning.
static func _relic(kind: String) -> Node3D:
	var root := Node3D.new()
	var spin := Node3D.new()
	spin.set_meta("spin", 1.2)
	spin.position.y = 0.5
	root.add_child(spin)
	var gold := mat(Color(1.0, 0.82, 0.3), 1.2)
	var gem := mat(Color(0.9, 0.15, 0.25), 2.0)
	match kind:
		"crown":
			var band := CylinderMesh.new()
			band.top_radius = 0.22
			band.bottom_radius = 0.2
			band.height = 0.16
			_part(spin, band, gold, Vector3.ZERO)
			_part(spin, _sphere(0.18, 10), gem, Vector3(0, 0.12, 0), Vector3.ZERO, Vector3(1, 0.7, 1))
			_part(spin, _box(Vector3(0.04, 0.2, 0.04)), gold, Vector3(0, 0.3, 0))
		"lance":
			_part(spin, _cyl(0.03, 1.0), gold, Vector3(0, 0.1, 0))
			_part(spin, _cone(0.08, 0.3), mat(Color(0.8, 0.8, 0.85), 1.0), Vector3(0, 0.75, 0))
		"bowl":
			var b := CylinderMesh.new()
			b.top_radius = 0.28
			b.bottom_radius = 0.12
			b.height = 0.2
			_part(spin, b, mat(Color(0.65, 0.4, 0.25), 0.6), Vector3.ZERO)
			_part(spin, _cyl(0.06, 0.15), gold, Vector3(0, -0.15, 0))
		"horn":
			_part(spin, _cone(0.07, 1.0, 10), mat(Color(0.95, 0.93, 0.85), 0.8), Vector3(0, 0.2, 0))
		"orb":
			_part(spin, _sphere(0.2, 12), gold, Vector3.ZERO)
			_part(spin, _box(Vector3(0.04, 0.22, 0.04)), gold, Vector3(0, 0.3, 0))
			_part(spin, _box(Vector3(0.14, 0.04, 0.04)), gold, Vector3(0, 0.33, 0))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.4)
	light.light_energy = 1.2
	light.omni_range = 2.5
	light.position.y = 0.8
	root.add_child(light)
	return root
