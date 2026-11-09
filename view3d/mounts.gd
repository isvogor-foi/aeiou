extends RefCounted
## Cavalry mounts and wagons built from smooth primitives (Gear), baked by
## Machines.build (one mesh per material, cached per team colour). Legs that swing
## carry meta "gallop", pavises that fold out "deploy", spinning parts "spin_z".
## All face +Z; one world unit = one tile.
##
## horse        light cavalry: a properly shaped horse with a leather breastplate,
##              brass chamfron, team saddlecloth and Aether saddlebags
## horse_heavy  heavy cavalry: the same horse in dieselpunk barding (steel
##              chamfron with a gas-mask muzzle, crinet, peytral, flank plates)
## bone_horse   the Covenant's skeletal steed: bone frame, iron-bolted skull,
##              soul-fire core in the ribcage
## supply_tractor  Monarchy supply wagon: a small steam traction engine towing a
##              tarpaulin cart of crates, barrels and Aether canisters
## bone_wagon   Covenant supply: a bone-framed cart on spiked iron wheels, pushed
##              by a soul furnace, loaded with coffins and green vats
## war_wagon    Hussite war wagon reborn: a riveted armoured steam wagon on six
##              wheels whose team-coloured pavises fold out into a Wagenburg
## steam_walker a two-legged riveted boiler mech with a rotary gun

const Gear = preload("res://view3d/gear.gd")

const COAT := Color(0.33, 0.21, 0.13)
const COAT_DARK := Color(0.17, 0.11, 0.08)
const HAIR := Color(0.09, 0.07, 0.06)
const HOOF := Color(0.12, 0.11, 0.1)
const LEATHER := Color(0.3, 0.19, 0.11)
const STEEL := Color(0.36, 0.38, 0.4)
const BONE := Color(0.84, 0.81, 0.71)
const SOUL := Color(0.45, 1.0, 0.45)
const AETHER := Color(0.4, 0.85, 1.0)


static func build(kind: String, team: Color) -> Node3D:
	match kind:
		"horse":
			return horse(team, false)
		"horse_heavy":
			return horse(team, true)
		"bone_horse":
			return bone_horse(team)
		"supply_tractor":
			return supply_tractor(team)
		"bone_wagon":
			return bone_wagon(team)
		"war_wagon":
			return war_wagon(team)
		"steam_walker":
			return steam_walker(team)
	return Node3D.new()


# --- Helpers ----------------------------------------------------------------------

static func m(c: Color, metal := 0.0, rough := 0.7, glow := 0.0) -> StandardMaterial3D:
	return Gear.mat(c, glow, metal, rough)


## A tapered cylinder from `a` to `b`.
static func limb(parent: Node3D, a: Vector3, b: Vector3, r: float, mat: Material, r2 := -1.0) -> MeshInstance3D:
	var mi := Gear.part(parent, Gear.cyl(r, a.distance_to(b), r2), mat, (a + b) * 0.5)
	var dir := (b - a).normalized()
	if absf(dir.dot(Vector3.UP)) < 0.999:
		mi.basis = Basis(Quaternion(Vector3.UP, dir))
	elif dir.y < 0.0:
		mi.basis = Basis(Vector3.RIGHT, PI)
	return mi


## An ellipsoid of full size `size`.
static func blob(parent: Node3D, center: Vector3, size: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	return Gear.part(parent, Gear.sphere(0.5), mat, center, rot, size)


static func box(parent: Node3D, center: Vector3, size: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	return Gear.part(parent, Gear.box(size), mat, center, rot)


static func wheel(parent: Node3D, center: Vector3, r: float, width: float, rim: Material, hub: Material, spokes := 8) -> void:
	Gear.part(parent, Gear.cyl(r, width), rim, center, Vector3(0, 0, PI / 2))
	Gear.part(parent, Gear.cyl(r * 0.78, width * 1.05), m(Color(0.1, 0.09, 0.08)), center, Vector3(0, 0, PI / 2))
	for i in spokes:
		var a := i * PI / spokes
		box(parent, center, Vector3(width * 0.6, r * 1.55, 0.025), hub, Vector3(a, 0, 0))
	Gear.part(parent, Gear.cyl(r * 0.22, width * 1.3), hub, center, Vector3(0, 0, PI / 2))


# --- Horses ------------------------------------------------------------------------

## A jointed horse leg hanging from `top` (shoulder or hip): forearm/gaskin,
## knee or hock, cannon, fetlock and hoof. Swings as a whole ("gallop").
static func _leg(root: Node3D, top: Vector3, phase: float, front: bool, coat: Material, hoof: Material, armour: Material) -> void:
	var hip := Node3D.new()
	hip.position = top
	hip.set_meta("gallop", phase)
	root.add_child(hip)
	var knee := Vector3(0, -0.3, 0.03 if front else -0.06)
	var fetlock := Vector3(0, -0.56, 0.0 if front else -0.02)
	limb(hip, Vector3(0, 0.04, 0), knee, 0.075, coat, 0.048)
	blob(hip, knee, Vector3(0.075, 0.08, 0.08), coat)
	limb(hip, knee, fetlock, 0.036, coat, 0.032)
	blob(hip, fetlock, Vector3(0.06, 0.06, 0.07), coat)
	# Feathered fetlock hair and the hoof.
	limb(hip, fetlock + Vector3(0, -0.02, 0.0), fetlock + Vector3(0, -0.07, 0.02), 0.042, hoof, 0.05)
	if armour:
		limb(hip, knee + Vector3(0, -0.02, 0.025), knee + Vector3(0, -0.2, 0.03), 0.042, armour, 0.038)


static func horse(team: Color, heavy: bool) -> Node3D:
	var root := Node3D.new()
	var coat := m(COAT if not heavy else COAT_DARK, 0.0, 0.55)
	var hair := m(HAIR, 0.0, 0.9)
	var hoof := m(HOOF, 0.0, 0.5)
	var leather := m(LEATHER, 0.0, 0.6)
	var brass := Gear.brass()
	var steel := m(STEEL, 0.75, 0.4)
	var cloth := m(team.darkened(0.35), 0.0, 0.85)
	# Body: barrel, deep chest, rounded rump and the withers.
	blob(root, Vector3(0, 0.74, 0.0), Vector3(0.36, 0.4, 0.95), coat)
	blob(root, Vector3(0, 0.76, 0.36), Vector3(0.34, 0.42, 0.4), coat)
	blob(root, Vector3(0, 0.79, -0.36), Vector3(0.37, 0.4, 0.42), coat)
	blob(root, Vector3(0, 0.9, 0.28), Vector3(0.2, 0.16, 0.3), coat)
	# Shoulders and haunches, so the legs grow out of muscle, not sticks.
	for x in [-1.0, 1.0]:
		blob(root, Vector3(x * 0.12, 0.7, 0.36), Vector3(0.16, 0.34, 0.24), coat, Vector3(0.3, 0, 0))
		blob(root, Vector3(x * 0.13, 0.72, -0.4), Vector3(0.17, 0.36, 0.3), coat, Vector3(-0.2, 0, 0))
	# Arched neck, head and muzzle.
	limb(root, Vector3(0, 0.84, 0.46), Vector3(0, 1.18, 0.66), 0.13, coat, 0.085)
	blob(root, Vector3(0, 1.03, 0.52), Vector3(0.16, 0.34, 0.2), coat, Vector3(-0.6, 0, 0))
	var skull := Vector3(0, 1.24, 0.72)
	blob(root, skull, Vector3(0.15, 0.15, 0.2), coat)
	limb(root, skull + Vector3(0, -0.01, 0.04), skull + Vector3(0, -0.17, 0.25), 0.07, coat, 0.052)
	blob(root, skull + Vector3(0, -0.18, 0.26), Vector3(0.1, 0.08, 0.1), m(Color(0.12, 0.09, 0.08), 0.0, 0.6))
	for x in [-1.0, 1.0]:
		limb(root, skull + Vector3(x * 0.045, 0.06, -0.03), skull + Vector3(x * 0.055, 0.16, -0.01), 0.022, coat, 0.004)
		blob(root, skull + Vector3(x * 0.07, 0.01, 0.04), Vector3(0.025, 0.03, 0.03), m(Color(0.04, 0.03, 0.03), 0.0, 0.2))
	# Mane down the crest and a forelock; a full tail.
	for i in 6:
		var t := i / 5.0
		var p := Vector3(0, 0.9, 0.42).lerp(Vector3(0, 1.3, 0.66), t)
		blob(root, p + Vector3(0, 0.03, -0.04), Vector3(0.05, 0.12, 0.1), hair, Vector3(-0.6, 0, 0))
	blob(root, skull + Vector3(0, 0.08, 0.06), Vector3(0.05, 0.07, 0.06), hair)
	limb(root, Vector3(0, 0.9, -0.66), Vector3(0, 0.66, -0.78), 0.045, hair, 0.07)
	limb(root, Vector3(0, 0.66, -0.78), Vector3(0, 0.36, -0.8), 0.07, hair, 0.035)
	# Legs: diagonal pairs swing together.
	var guard := steel if heavy else null
	for x in [-1.0, 1.0]:
		_leg(root, Vector3(x * 0.11, 0.66, 0.36), x, true, coat, hoof, guard)
		_leg(root, Vector3(x * 0.12, 0.7, -0.38), -x, false, coat, hoof, guard)
	# Tack: bridle and reins, saddlecloth in the team colour, saddle.
	limb(root, skull + Vector3(-0.075, -0.1, 0.12), skull + Vector3(0.075, -0.1, 0.12), 0.012, leather)
	limb(root, skull + Vector3(0, -0.12, 0.18), Vector3(0, 1.0, 0.18), 0.008, leather)
	# Saddlecloth draped over the barrel: a pad on top and short skirts down the sides.
	blob(root, Vector3(0, 0.93, 0.0), Vector3(0.39, 0.06, 0.42), cloth)
	for x in [-1.0, 1.0]:
		box(root, Vector3(x * 0.185, 0.84, 0.0), Vector3(0.02, 0.18, 0.36), cloth, Vector3(0, 0, x * -0.25))
		box(root, Vector3(x * 0.2, 0.76, 0.0), Vector3(0.022, 0.025, 0.37), Gear.brass(), Vector3(0, 0, x * -0.25))
	blob(root, Vector3(0, 0.98, 0.0), Vector3(0.24, 0.08, 0.32), leather)
	blob(root, Vector3(0, 1.0, 0.13), Vector3(0.12, 0.08, 0.06), leather)
	blob(root, Vector3(0, 1.0, -0.13), Vector3(0.2, 0.08, 0.06), leather)
	for x in [-1.0, 1.0]:
		limb(root, Vector3(x * 0.19, 0.94, 0.02), Vector3(x * 0.2, 0.62, 0.04), 0.008, leather)
		limb(root, Vector3(x * 0.2, 0.62, 0.04), Vector3(x * 0.2, 0.6, 0.1), 0.025, brass)
	if not heavy:
		# Light cavalry: leather breastplate with a brass medallion, a brass
		# chamfron disc, and saddlebags with a glowing Aether canister.
		limb(root, Vector3(-0.17, 0.8, 0.38), Vector3(0.17, 0.8, 0.38), 0.03, leather)
		blob(root, Vector3(0, 0.8, 0.55), Vector3(0.08, 0.08, 0.03), brass)
		blob(root, skull + Vector3(0, 0.0, 0.1), Vector3(0.07, 0.1, 0.04), brass, Vector3(-0.6, 0, 0))
		for x in [-1.0, 1.0]:
			box(root, Vector3(x * 0.2, 0.86, -0.24), Vector3(0.08, 0.16, 0.18), leather)
		limb(root, Vector3(0.24, 0.8, -0.32), Vector3(0.24, 0.94, -0.32), 0.035, m(AETHER, 0.0, 0.3, 2.0))
		limb(root, Vector3(0.24, 0.94, -0.32), Vector3(0.24, 0.96, -0.32), 0.04, brass)
	else:
		# Heavy barding: steel chamfron and a gas-mask muzzle with a filter can,
		# riveted crinet down the neck, peytral over the chest, flank plates and
		# a team-coloured caparison edge.
		blob(root, skull + Vector3(0, 0.0, 0.05), Vector3(0.17, 0.17, 0.2), steel)
		limb(root, skull + Vector3(0, 0.0, 0.08), skull + Vector3(0, -0.15, 0.27), 0.077, steel, 0.06)
		limb(root, skull + Vector3(0, -0.17, 0.27), skull + Vector3(0, -0.24, 0.33), 0.045, m(Color(0.25, 0.27, 0.28), 0.7, 0.45))
		limb(root, skull + Vector3(0, -0.19, 0.29), skull + Vector3(0, -0.2, 0.3), 0.05, brass)
		for x in [-1.0, 1.0]:
			blob(root, skull + Vector3(x * 0.075, 0.02, 0.06), Vector3(0.045, 0.045, 0.02), m(AETHER, 0.0, 0.2, 2.2))
		blob(root, skull + Vector3(0, 0.1, 0.02), Vector3(0.03, 0.05, 0.03), brass)
		for i in 4:
			var t := i / 3.0
			var p := Vector3(0, 0.95, 0.47).lerp(Vector3(0, 1.22, 0.66), t)
			blob(root, p, Vector3(0.2 - t * 0.04, 0.12, 0.12), steel, Vector3(-0.6, 0, 0))
		blob(root, Vector3(0, 0.76, 0.48), Vector3(0.4, 0.4, 0.26), steel)
		blob(root, Vector3(0, 0.62, 0.53), Vector3(0.34, 0.12, 0.12), m(team, 0.0, 0.8))
		for x in [-1.0, 1.0]:
			blob(root, Vector3(x * 0.16, 0.78, -0.4), Vector3(0.1, 0.36, 0.42), steel)
			blob(root, Vector3(x * 0.165, 0.63, -0.4), Vector3(0.08, 0.1, 0.44), m(team, 0.0, 0.8))
			for z in [0.4, 0.56]:
				blob(root, Vector3(x * 0.15, 0.82, z), Vector3(0.025, 0.025, 0.025), brass)
	return root


static func bone_horse(team: Color) -> Node3D:
	var root := Node3D.new()
	var bone := m(BONE, 0.0, 0.6)
	var iron := m(Color(0.2, 0.2, 0.21), 0.75, 0.4)
	var soul := m(SOUL, 0.0, 0.3, 2.5)
	var rag := m(Color(0.12, 0.1, 0.11), 0.0, 0.9)
	# Spine, pelvis and a ribcage of hoops around a soul-fire core.
	limb(root, Vector3(0, 0.88, -0.5), Vector3(0, 0.92, 0.4), 0.035, bone)
	blob(root, Vector3(0, 0.84, -0.42), Vector3(0.3, 0.16, 0.26), bone)
	for i in 6:
		var z := 0.3 - i * 0.11
		Gear.part(root, Gear.torus(0.13 - absf(i - 2.0) * 0.008, 0.16 - absf(i - 2.0) * 0.008), bone, Vector3(0, 0.76, z), Vector3(PI / 2, 0, 0), Vector3(1.0, 1.0, 1.25))
	limb(root, Vector3(0, 0.58, 0.32), Vector3(0, 0.6, -0.26), 0.025, bone)
	blob(root, Vector3(0, 0.76, 0.02), Vector3(0.16, 0.16, 0.24), soul)
	var core := OmniLight3D.new()
	core.light_color = SOUL
	core.light_energy = 0.6
	core.omni_range = 1.6
	core.position = Vector3(0, 0.76, 0.02)
	root.add_child(core)
	# Neck vertebrae and the skull, bolted together with iron.
	for i in 5:
		var t := i / 4.0
		blob(root, Vector3(0, 0.92, 0.42).lerp(Vector3(0, 1.2, 0.64), t), Vector3(0.07, 0.07, 0.08), bone)
	var skull := Vector3(0, 1.24, 0.72)
	blob(root, skull, Vector3(0.14, 0.13, 0.18), bone)
	limb(root, skull + Vector3(0, -0.01, 0.04), skull + Vector3(0, -0.15, 0.24), 0.055, bone, 0.035)
	limb(root, skull + Vector3(0, -0.07, 0.02), skull + Vector3(0, -0.2, 0.2), 0.03, bone, 0.02)
	for x in [-1.0, 1.0]:
		blob(root, skull + Vector3(x * 0.06, 0.02, 0.05), Vector3(0.04, 0.035, 0.03), soul)
		limb(root, skull + Vector3(x * 0.05, 0.05, -0.05), skull + Vector3(x * 0.08, 0.2, -0.12), 0.02, iron, 0.0)
	box(root, skull + Vector3(0, 0.06, 0.06), Vector3(0.1, 0.03, 0.14), iron, Vector3(-0.5, 0, 0))
	# Bone legs with iron knee bolts.
	for x in [-1.0, 1.0]:
		for front in [true, false]:
			var hip := Node3D.new()
			hip.position = Vector3(x * 0.11, 0.7, 0.32 if front else -0.38)
			hip.set_meta("gallop", x if front else -x)
			root.add_child(hip)
			var knee := Vector3(0, -0.3, 0.03 if front else -0.06)
			limb(hip, Vector3(0, 0.05, 0), knee, 0.03, bone, 0.024)
			blob(hip, knee, Vector3(0.06, 0.06, 0.06), iron)
			limb(hip, knee, Vector3(0, -0.62, 0.0), 0.02, bone, 0.018)
			limb(hip, Vector3(0, -0.6, 0.0), Vector3(0, -0.66, 0.03), 0.04, iron, 0.045)
	# Tattered black caparison in the team colour's shadow, and a bone saddle.
	box(root, Vector3(0, 0.96, -0.02), Vector3(0.44, 0.025, 0.5), m(team.darkened(0.55), 0.0, 0.9))
	for x in [-1.0, 1.0]:
		box(root, Vector3(x * 0.22, 0.82, -0.02), Vector3(0.02, 0.28, 0.46), rag)
	blob(root, Vector3(0, 0.99, 0.0), Vector3(0.22, 0.07, 0.3), m(Color(0.25, 0.2, 0.18), 0.0, 0.7))
	limb(root, Vector3(0, 0.9, -0.52), Vector3(0, 0.55, -0.72), 0.02, bone, 0.01)
	return root


# --- Wagons --------------------------------------------------------------------------

## A small steam traction engine (boiler, funnel, big rear wheels) towing a
## tarpaulin cart of crates, barrels and Aether canisters.
static func supply_tractor(team: Color) -> Node3D:
	var root := Node3D.new()
	var iron := m(Color(0.24, 0.25, 0.27), 0.7, 0.45)
	var brass := Gear.brass()
	var copper := Gear.copper()
	var wood := m(Color(0.36, 0.25, 0.15), 0.0, 0.8)
	var tarp := m(Color(0.34, 0.33, 0.25), 0.0, 0.95)
	# Tractor at the front.
	var t := Vector3(0, 0, 0.45)
	limb(root, t + Vector3(0, 0.42, -0.25), t + Vector3(0, 0.42, 0.3), 0.17, iron)
	blob(root, t + Vector3(0, 0.42, 0.31), Vector3(0.34, 0.34, 0.06), iron)
	for z in [-0.15, 0.05, 0.25]:
		limb(root, t + Vector3(0, 0.42, z), t + Vector3(0, 0.42, z + 0.025), 0.178, brass)
	limb(root, t + Vector3(0, 0.55, 0.22), t + Vector3(0, 0.95, 0.24), 0.045, iron, 0.055)
	limb(root, t + Vector3(0, 0.95, 0.24), t + Vector3(0, 1.0, 0.24), 0.07, brass)
	blob(root, t + Vector3(0, 0.6, -0.1), Vector3(0.12, 0.1, 0.12), copper)
	box(root, t + Vector3(0, 0.36, -0.32), Vector3(0.36, 0.3, 0.16), iron)
	blob(root, t + Vector3(0, 0.42, 0.34), Vector3(0.08, 0.08, 0.03), m(AETHER, 0.0, 0.3, 2.5))
	box(root, t + Vector3(0, 0.6, -0.3), Vector3(0.38, 0.04, 0.12), m(team))
	wheel(root, t + Vector3(-0.24, 0.26, -0.22), 0.26, 0.09, iron, brass, 10)
	wheel(root, t + Vector3(0.24, 0.26, -0.22), 0.26, 0.09, iron, brass, 10)
	wheel(root, t + Vector3(-0.16, 0.15, 0.22), 0.15, 0.07, iron, brass)
	wheel(root, t + Vector3(0.16, 0.15, 0.22), 0.15, 0.07, iron, brass)
	var funnel := Gear.smoke_plume(false)
	funnel.position = t + Vector3(0, 1.02, 0.24)
	funnel.scale = Vector3.ONE * 0.8
	root.add_child(funnel)
	# The towed cart.
	var c := Vector3(0, 0, -0.42)
	limb(root, t + Vector3(0, 0.25, -0.38), c + Vector3(0, 0.3, 0.3), 0.02, iron)
	box(root, c + Vector3(0, 0.32, 0), Vector3(0.5, 0.06, 0.62), wood)
	for x in [-0.25, 0.25]:
		box(root, c + Vector3(x, 0.42, 0), Vector3(0.03, 0.16, 0.62), wood)
	box(root, c + Vector3(-0.08, 0.47, 0.12), Vector3(0.22, 0.2, 0.2), wood)
	box(root, c + Vector3(-0.08, 0.47, 0.12), Vector3(0.23, 0.03, 0.21), iron)
	limb(root, c + Vector3(0.12, 0.35, 0.12), c + Vector3(0.12, 0.58, 0.12), 0.08, m(Color(0.4, 0.27, 0.15), 0.0, 0.7))
	for y in [0.4, 0.53]:
		limb(root, c + Vector3(0.12, y, 0.12), c + Vector3(0.12, y + 0.015, 0.12), 0.083, iron)
	for x in [-0.12, 0.0, 0.12]:
		limb(root, c + Vector3(x, 0.35, -0.16), c + Vector3(x, 0.55, -0.16), 0.045, m(AETHER, 0.0, 0.3, 1.8))
		limb(root, c + Vector3(x, 0.55, -0.16), c + Vector3(x, 0.58, -0.16), 0.05, brass)
	# Tarpaulin hooped over the back half.
	limb(root, c + Vector3(0, 0.48, -0.06), c + Vector3(0, 0.48, -0.31), 0.25, tarp)
	box(root, c + Vector3(0, 0.36, -0.18), Vector3(0.5, 0.02, 0.26), tarp)
	wheel(root, c + Vector3(-0.29, 0.18, 0), 0.18, 0.06, iron, wood)
	wheel(root, c + Vector3(0.29, 0.18, 0), 0.18, 0.06, iron, wood)
	return root


## Covenant supply: a bone-framed cart on spiked iron wheels, pushed along by a
## soul furnace, loaded with coffins and vats of green ichor.
static func bone_wagon(team: Color) -> Node3D:
	var root := Node3D.new()
	var bone := m(BONE, 0.0, 0.6)
	var iron := m(Color(0.18, 0.18, 0.2), 0.75, 0.4)
	var dark := m(Color(0.16, 0.13, 0.12), 0.0, 0.8)
	var soul := m(SOUL, 0.0, 0.3, 2.2)
	box(root, Vector3(0, 0.32, 0), Vector3(0.56, 0.06, 1.1), dark)
	# Rib-bone sides.
	for i in 6:
		var z := -0.45 + i * 0.18
		for x in [-1.0, 1.0]:
			limb(root, Vector3(x * 0.27, 0.33, z), Vector3(x * 0.33, 0.62, z), 0.02, bone, 0.012)
	for x in [-1.0, 1.0]:
		limb(root, Vector3(x * 0.32, 0.58, -0.5), Vector3(x * 0.32, 0.58, 0.5), 0.018, bone)
	# Cargo: two coffins and a vat.
	box(root, Vector3(-0.12, 0.42, -0.12), Vector3(0.18, 0.12, 0.5), m(Color(0.22, 0.14, 0.1), 0.0, 0.8), Vector3(0, 0.05, 0))
	box(root, Vector3(0.12, 0.42, -0.2), Vector3(0.18, 0.12, 0.45), m(Color(0.22, 0.14, 0.1), 0.0, 0.8), Vector3(0, -0.06, 0))
	limb(root, Vector3(0, 0.35, 0.28), Vector3(0, 0.6, 0.28), 0.13, iron)
	limb(root, Vector3(0, 0.58, 0.28), Vector3(0, 0.62, 0.28), 0.11, soul)
	# Soul furnace at the back with a green plume.
	limb(root, Vector3(0, 0.3, -0.6), Vector3(0, 0.62, -0.6), 0.14, iron, 0.12)
	blob(root, Vector3(0, 0.45, -0.46), Vector3(0.12, 0.1, 0.04), soul)
	limb(root, Vector3(0, 0.62, -0.6), Vector3(0, 0.9, -0.62), 0.04, iron, 0.05)
	var plume := Gear.smoke_plume(true)
	plume.position = Vector3(0, 0.92, -0.62)
	plume.scale = Vector3.ONE * 0.8
	root.add_child(plume)
	blob(root, Vector3(0, 0.34, 0.6), Vector3(0.18, 0.16, 0.2), bone)
	for x in [-1.0, 1.0]:
		blob(root, Vector3(x * 0.045, 0.37, 0.69), Vector3(0.035, 0.03, 0.02), soul)
	box(root, Vector3(0, 0.36, 0.55), Vector3(0.58, 0.04, 0.06), m(team.darkened(0.3)))
	for z in [-0.35, 0.35]:
		for x in [-1.0, 1.0]:
			wheel(root, Vector3(x * 0.32, 0.2, z), 0.2, 0.06, iron, bone, 6)
			for i in 6:
				var a := i * TAU / 6.0
				limb(root, Vector3(x * 0.32, 0.2 + sin(a) * 0.2, z + cos(a) * 0.2), Vector3(x * 0.32, 0.2 + sin(a) * 0.27, z + cos(a) * 0.27), 0.012, bone, 0.0)
	return root


## Hussite war wagon, dieselpunk: a riveted armoured box on six wheels with
## firing slits, a funnel and team-coloured pavises that fold out ("deploy").
static func war_wagon(team: Color) -> Node3D:
	var root := Node3D.new()
	var plate := m(Color(0.27, 0.28, 0.27), 0.65, 0.5)
	var iron := m(Color(0.2, 0.2, 0.22), 0.7, 0.45)
	var brass := Gear.brass()
	var paint := m(team.darkened(0.15), 0.2, 0.6)
	box(root, Vector3(0, 0.5, 0), Vector3(0.78, 0.46, 1.5), plate)
	box(root, Vector3(0, 0.76, 0), Vector3(0.7, 0.06, 1.4), plate)
	box(root, Vector3(0, 0.5, 0.78), Vector3(0.72, 0.4, 0.06), plate, Vector3(-0.35, 0, 0))
	# Rivets along the seams and dark firing slits.
	for z in range(-6, 7):
		for x in [-1.0, 1.0]:
			blob(root, Vector3(x * 0.395, 0.7, z * 0.11), Vector3(0.025, 0.025, 0.025), brass)
			blob(root, Vector3(x * 0.395, 0.3, z * 0.11), Vector3(0.025, 0.025, 0.025), iron)
	for z in [-0.45, 0.0, 0.45]:
		for x in [-1.0, 1.0]:
			box(root, Vector3(x * 0.395, 0.56, z), Vector3(0.02, 0.05, 0.2), m(Color(0.05, 0.05, 0.05)))
	# Commander's cupola with a gun, funnel with smoke.
	limb(root, Vector3(0, 0.78, 0.25), Vector3(0, 0.95, 0.25), 0.15, plate, 0.13)
	limb(root, Vector3(0, 0.95, 0.25), Vector3(0, 0.98, 0.25), 0.14, brass)
	limb(root, Vector3(0, 0.88, 0.35), Vector3(0, 0.88, 0.7), 0.03, iron)
	limb(root, Vector3(0.2, 0.78, -0.5), Vector3(0.2, 1.15, -0.52), 0.05, iron, 0.06)
	var plume := Gear.smoke_plume(false)
	plume.position = Vector3(0.2, 1.17, -0.52)
	plume.scale = Vector3.ONE * 0.8
	root.add_child(plume)
	for z in [-0.5, 0.0, 0.5]:
		for x in [-1.0, 1.0]:
			wheel(root, Vector3(x * 0.42, 0.22, z), 0.22, 0.08, iron, brass)
	# Pavises fold down and out when it digs in as a Wagenburg.
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * 0.42, 0.78, 0)
		pivot.set_meta("deploy", side)
		root.add_child(pivot)
		box(pivot, Vector3(side * 0.03, -0.2, 0), Vector3(0.05, 0.42, 1.36), paint)
		box(pivot, Vector3(side * 0.06, -0.2, 0), Vector3(0.02, 0.06, 1.3), brass)
		for z in [-0.45, 0.0, 0.45]:
			blob(pivot, Vector3(side * 0.06, -0.2, z), Vector3(0.05, 0.05, 0.05), brass)
	return root


## Two-legged riveted boiler mech with a rotary Aether gun; legs swing ("gallop").
static func steam_walker(team: Color) -> Node3D:
	var root := Node3D.new()
	var plate := m(Color(0.3, 0.31, 0.32), 0.7, 0.45)
	var iron := m(Color(0.2, 0.2, 0.22), 0.7, 0.45)
	var brass := Gear.brass()
	var copper := Gear.copper()
	var glow := m(AETHER, 0.0, 0.3, 2.5)
	# Boiler body: a riveted drum lying fore-aft, a cab on top.
	limb(root, Vector3(0, 1.05, -0.35), Vector3(0, 1.05, 0.3), 0.3, plate)
	blob(root, Vector3(0, 1.05, 0.3), Vector3(0.6, 0.6, 0.2), plate)
	for z in [-0.25, 0.0, 0.25]:
		limb(root, Vector3(0, 1.05, z), Vector3(0, 1.05, z + 0.03), 0.31, brass)
	blob(root, Vector3(0, 1.05, 0.4), Vector3(0.16, 0.16, 0.04), glow)
	box(root, Vector3(0, 1.42, -0.05), Vector3(0.42, 0.24, 0.42), plate)
	box(root, Vector3(0, 1.45, 0.17), Vector3(0.3, 0.06, 0.02), glow)
	box(root, Vector3(0, 1.56, -0.05), Vector3(0.46, 0.04, 0.46), m(team))
	limb(root, Vector3(-0.14, 1.3, -0.3), Vector3(-0.14, 1.85, -0.34), 0.05, iron, 0.06)
	var plume := Gear.smoke_plume(false)
	plume.position = Vector3(-0.14, 1.87, -0.34)
	plume.scale = Vector3.ONE * 0.9
	root.add_child(plume)
	limb(root, Vector3(0.2, 1.2, -0.3), Vector3(0.28, 0.95, -0.2), 0.03, copper)
	# Rotary gun on the right.
	var gun := Vector3(0.38, 1.0, 0.1)
	box(root, gun, Vector3(0.12, 0.16, 0.2), iron)
	var barrels := Node3D.new()
	barrels.position = gun + Vector3(0, 0, 0.35)
	barrels.set_meta("spin_z", 6.0)
	root.add_child(barrels)
	for i in 5:
		var a := i * TAU / 5.0
		limb(barrels, Vector3(cos(a) * 0.04, sin(a) * 0.04, -0.25), Vector3(cos(a) * 0.04, sin(a) * 0.04, 0.2), 0.016, iron)
	limb(barrels, Vector3(0, 0, -0.05), Vector3(0, 0, -0.02), 0.07, brass)
	# Legs: thigh piston, reverse knee, splayed iron foot.
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.27, 0.85, 0)
		hip.set_meta("gallop", side * 0.6)
		root.add_child(hip)
		blob(hip, Vector3.ZERO, Vector3(0.18, 0.18, 0.18), brass)
		var knee := Vector3(0, -0.4, 0.14)
		limb(hip, Vector3.ZERO, knee, 0.07, plate, 0.06)
		limb(hip, Vector3(side * 0.06, -0.05, -0.05), knee + Vector3(side * 0.06, 0, -0.02), 0.025, copper)
		blob(hip, knee, Vector3(0.12, 0.12, 0.12), iron)
		var ankle := Vector3(0, -0.8, -0.02)
		limb(hip, knee, ankle, 0.055, plate, 0.045)
		box(hip, ankle + Vector3(0, -0.03, 0.06), Vector3(0.2, 0.05, 0.34), iron)
		for x in [-0.07, 0.07]:
			box(hip, ankle + Vector3(x, -0.03, 0.22), Vector3(0.05, 0.04, 0.1), iron)
	return root
