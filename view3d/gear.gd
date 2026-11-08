extends RefCounted
## Steampunk-meets-Aether kit for the soldiers, built from smooth, high-segment
## primitives: brass goggles, top hats with cog bands, Aether backpacks with copper
## pipes and glowing vials, brass pauldrons, Aether staffs, and for the Covenant
## soul lanterns and grave packs glowing necrotic green.
## Attached to skeleton bones via visuals.json "attach" ({"proc": "<kind>", ...}).

const SEG := 20

static var _mats := {}


static func mat(color: Color, emissive := 0.0, metallic := 0.0, rough := 0.6) -> StandardMaterial3D:
	var key := "%s/%s/%s/%s" % [color.to_html(), emissive, metallic, rough]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.metallic = metallic
		m.roughness = rough
		if emissive > 0.0:
			m.emission_enabled = true
			m.emission = color
			m.emission_energy_multiplier = emissive
		_mats[key] = m
	return _mats[key]


static func brass() -> StandardMaterial3D:
	return mat(Color(0.86, 0.66, 0.28), 0.0, 0.75, 0.35)


static func copper() -> StandardMaterial3D:
	return mat(Color(0.78, 0.42, 0.25), 0.0, 0.7, 0.4)


static func iron() -> StandardMaterial3D:
	return mat(Color(0.22, 0.22, 0.24), 0.0, 0.6, 0.5)


static func leather() -> StandardMaterial3D:
	return mat(Color(0.36, 0.22, 0.13), 0.0, 0.0, 0.8)


static func aether() -> StandardMaterial3D:
	return mat(Color(0.4, 0.85, 1.0), 2.5)


static func soul() -> StandardMaterial3D:
	return mat(Color(0.45, 1.0, 0.45), 2.5)


static var _baked := {}


## The kit piece `kind`, with its static parts baked into one mesh (one draw per
## material) and cached; moving parts (turning cogs) and smoke stay separate nodes.
static func build(kind: String) -> Node3D:
	if not _baked.has(kind):
		_baked[kind] = _bake(_build_raw(kind))
	var src: Dictionary = _baked[kind]
	var root := Node3D.new()
	if src.mesh:
		var mi := MeshInstance3D.new()
		mi.mesh = src.mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	for extra in src.live:
		root.add_child(extra.duplicate())
	return root


## Splits a freshly built kit piece into a merged static mesh and its live parts.
static func _bake(raw: Node3D) -> Dictionary:
	var by_mat := {}
	var live: Array = []
	_collect(raw, Transform3D.IDENTITY, by_mat, live)
	var mesh: ArrayMesh = null
	if not by_mat.is_empty():
		mesh = ArrayMesh.new()
		for m in by_mat:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for item in by_mat[m]:
				st.append_from(item[0], 0, item[1])
			st.set_material(m)
			st.commit(mesh)
	return {"mesh": mesh, "live": live}


static func _collect(n: Node, xf: Transform3D, by_mat: Dictionary, live: Array) -> void:
	for c in n.get_children():
		if not c is Node3D:
			continue
		var here: Transform3D = xf * c.transform
		if c.has_meta("spin_z") or c.has_meta("spin") or c.has_meta("nod") or c is GPUParticles3D or c is Light3D:
			var keep: Node3D = c.duplicate()
			keep.transform = here
			live.append(keep)
			continue
		if c is MeshInstance3D and c.mesh:
			var m: Material = c.material_override
			if not by_mat.has(m):
				by_mat[m] = []
			by_mat[m].append([c.mesh, here])
		_collect(c, here, by_mat, live)


static func _build_raw(kind: String) -> Node3D:
	match kind:
		"goggles":
			return goggles()
		"top_hat":
			return top_hat()
		"aether_pack":
			return aether_pack()
		"pauldron":
			return pauldron()
		"aether_staff":
			return aether_staff()
		"soul_lantern":
			return soul_lantern()
		"grave_pack":
			return grave_pack()
		"tool_pack":
			return tool_pack()
		"necro_circlet":
			return necro_circlet()
		"chimney":
			return chimney(false)
		"soul_chimney":
			return chimney(true)
		"wall_cog":
			return wall_cog()
		"aether_lamp":
			return lamp(false)
		"soul_lamp":
			return lamp(true)
		"pipes":
			return pipes()
	return Node3D.new()


# --- Primitives ---------------------------------------------------------------------

static func part(parent: Node3D, mesh: Mesh, m: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scale := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	mi.scale = scale
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func cyl(r: float, h: float, top := -1.0) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r if top < 0.0 else top
	c.bottom_radius = r
	c.height = h
	c.radial_segments = SEG
	c.rings = 1
	return c


static func sphere(r: float, hemi := false) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = SEG
	s.rings = SEG / 2
	s.is_hemisphere = hemi
	return s


static func torus(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = SEG
	t.ring_segments = 8
	return t


static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


## A cog: a ring with teeth, lying in the XZ plane.
static func cog(parent: Node3D, r: float, m: Material, pos: Vector3, rot := Vector3.ZERO, teeth := 10) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation = rot
	parent.add_child(g)
	part(g, torus(r * 0.55, r), m)
	part(g, cyl(r * 0.25, r * 0.35), m)
	for i in teeth:
		var a := TAU * i / teeth
		part(g, box(Vector3(r * 0.32, r * 0.35, r * 0.3)), m, Vector3(cos(a) * r * 1.05, 0, sin(a) * r * 1.05), Vector3(0, -a, 0))
	return g


## A bent pipe through `points`, as cylinder segments with collars at the joints.
static func pipe(parent: Node3D, points: Array, r: float, m: Material) -> void:
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var mid := (a + b) * 0.5
		var seg := part(parent, cyl(r, a.distance_to(b)), m, mid)
		var dir := (b - a).normalized()
		if absf(dir.dot(Vector3.UP)) < 0.999:
			seg.basis = Basis(Quaternion(Vector3.UP, dir))
		part(parent, sphere(r * 1.25), m, b)


# --- Kit ------------------------------------------------------------------------------

## Brass goggles: two rimmed lenses on a leather strap (sit on the forehead).
static func goggles() -> Node3D:
	var root := Node3D.new()
	for side in [-1.0, 1.0]:
		var at := Vector3(side * 0.17, 0, 0)
		part(root, torus(0.09, 0.14), brass(), at, Vector3(PI / 2, 0, 0))
		part(root, cyl(0.1, 0.03), mat(Color(0.95, 0.75, 0.35), 0.6, 0.3, 0.1), at + Vector3(0, 0, 0.01), Vector3(PI / 2, 0, 0))
	part(root, box(Vector3(0.12, 0.05, 0.05)), brass(), Vector3(0, 0, 0))
	part(root, torus(0.42, 0.47), leather(), Vector3(0, 0, -0.38), Vector3(0, 0, 0), Vector3(1.0, 0.25, 1.0))
	return root


## A tall black top hat with a brass band, a cog, and goggles on the brim.
static func top_hat() -> Node3D:
	var root := Node3D.new()
	var felt := mat(Color(0.08, 0.07, 0.08), 0.0, 0.0, 0.7)
	part(root, cyl(0.3, 0.62, 0.32), felt, Vector3(0, 0.36, 0))
	part(root, cyl(0.55, 0.05), felt, Vector3(0, 0.05, 0))
	part(root, cyl(0.315, 0.1), brass(), Vector3(0, 0.15, 0))
	cog(root, 0.11, brass(), Vector3(0.1, 0.2, 0.3), Vector3(PI / 2, 0, 0), 8)
	var g := goggles()
	g.position = Vector3(0, 0.12, 0.34)
	g.scale = Vector3.ONE * 0.8
	root.add_child(g)
	return root


## An Aether backpack: a riveted brass tank with domed caps, copper pipes running
## over the shoulders, glowing vials and a pressure gauge.
static func aether_pack() -> Node3D:
	var root := Node3D.new()
	part(root, cyl(0.24, 0.62), copper(), Vector3(0, 0, 0))
	part(root, sphere(0.24, true), brass(), Vector3(0, 0.31, 0))
	part(root, sphere(0.24, true), brass(), Vector3(0, -0.31, 0), Vector3(PI, 0, 0))
	for y in [-0.18, 0.0, 0.18]:
		part(root, torus(0.24, 0.27), brass(), Vector3(0, y, 0))
	# The glowing core window and three vials.
	part(root, cyl(0.1, 0.36), aether(), Vector3(0, 0, 0.17), Vector3(0, 0, 0), Vector3(1, 1, 0.6))
	for i in 3:
		var x := -0.16 + i * 0.16
		part(root, cyl(0.045, 0.2), aether(), Vector3(x, -0.42, 0.12))
		part(root, cyl(0.05, 0.04), brass(), Vector3(x, -0.3, 0.12))
	# Pressure gauge.
	part(root, cyl(0.09, 0.04), brass(), Vector3(0.2, 0.2, 0.15), Vector3(PI / 2, 0, 0))
	part(root, cyl(0.075, 0.045), mat(Color(0.95, 0.93, 0.85)), Vector3(0.2, 0.2, 0.16), Vector3(PI / 2, 0, 0))
	part(root, box(Vector3(0.01, 0.06, 0.01)), iron(), Vector3(0.2, 0.22, 0.19), Vector3(0, 0, 0.6))
	# Pipes over both shoulders.
	for side in [-1.0, 1.0]:
		pipe(root, [Vector3(side * 0.14, 0.38, 0.05), Vector3(side * 0.2, 0.55, 0.15), Vector3(side * 0.24, 0.5, 0.42)], 0.035, copper())
	# Straps.
	for side in [-1.0, 1.0]:
		part(root, box(Vector3(0.06, 0.7, 0.04)), leather(), Vector3(side * 0.16, 0.05, 0.27))
	return root


## A tradesman's pack for settlers: a satchel with a rolled blanket, a hammer and a cog.
static func tool_pack() -> Node3D:
	var root := Node3D.new()
	var canvas := mat(Color(0.55, 0.45, 0.3), 0.0, 0.0, 0.9)
	part(root, box(Vector3(0.42, 0.42, 0.22)), canvas, Vector3.ZERO)
	part(root, cyl(0.1, 0.48), mat(Color(0.6, 0.18, 0.15)), Vector3(0, 0.28, 0), Vector3(0, 0, PI / 2))
	part(root, box(Vector3(0.05, 0.4, 0.05)), leather(), Vector3(0.24, 0.1, 0.05), Vector3(0, 0, -0.3))
	part(root, box(Vector3(0.14, 0.07, 0.08)), iron(), Vector3(0.3, 0.3, 0.05), Vector3(0, 0, -0.3))
	cog(root, 0.09, brass(), Vector3(-0.1, -0.05, 0.12), Vector3(PI / 2, 0, 0), 8)
	return root


## A domed brass shoulder plate with rivets.
static func pauldron() -> Node3D:
	var root := Node3D.new()
	part(root, sphere(0.2, true), brass(), Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.7, 1.0))
	part(root, torus(0.19, 0.22), copper(), Vector3(0, 0.01, 0))
	for i in 6:
		var a := TAU * i / 6.0
		part(root, sphere(0.025), iron(), Vector3(cos(a) * 0.13, 0.1, sin(a) * 0.13))
	return root


## An Aether staff: a brass rod, a cog head and a glowing crystal.
static func aether_staff() -> Node3D:
	# Built around the grip (origin), a third of the way up the rod.
	var root := Node3D.new()
	var body := Node3D.new()
	body.position = Vector3(0, -0.5, 0)
	root.add_child(body)
	_staff_parts(body)
	return root


static func _staff_parts(root: Node3D) -> void:
	part(root, cyl(0.035, 1.6), brass(), Vector3(0, 0.6, 0))
	for y in [0.0, 0.5, 1.0]:
		part(root, torus(0.035, 0.06), copper(), Vector3(0, y, 0))
	cog(root, 0.16, brass(), Vector3(0, 1.42, 0), Vector3(PI / 2, 0, 0), 10)
	var crystal := CylinderMesh.new()
	crystal.top_radius = 0.0
	crystal.bottom_radius = 0.09
	crystal.height = 0.3
	crystal.radial_segments = 6
	part(root, crystal, aether(), Vector3(0, 1.62, 0))
	part(root, crystal, aether(), Vector3(0, 1.42, 0), Vector3(PI, 0, 0), Vector3(1, 0.6, 1))


## A Covenant soul lantern: an iron cage around a green flame, on a short chain.
static func soul_lantern() -> Node3D:
	var root := Node3D.new()
	for i in 4:
		part(root, torus(0.025, 0.045), iron(), Vector3(0, -0.06 * i, 0), Vector3(0, i * PI / 2, PI / 2))
	var cage := Node3D.new()
	cage.position = Vector3(0, -0.42, 0)
	root.add_child(cage)
	part(cage, cyl(0.12, 0.05), iron(), Vector3(0, 0.15, 0))
	part(cage, cyl(0.12, 0.05), iron(), Vector3(0, -0.15, 0))
	for i in 6:
		var a := TAU * i / 6.0
		part(cage, cyl(0.012, 0.3), iron(), Vector3(cos(a) * 0.11, 0, sin(a) * 0.11))
	part(cage, sphere(0.08), soul(), Vector3.ZERO)
	part(cage, cyl(0.03, 0.08, 0.0), iron(), Vector3(0, 0.22, 0))
	return root


## A coffin-shaped grave pack with ribs and green vials of bottled souls.
static func grave_pack() -> Node3D:
	var root := Node3D.new()
	var wood := mat(Color(0.22, 0.14, 0.1), 0.0, 0.0, 0.85)
	var coffin := CylinderMesh.new()
	coffin.top_radius = 0.2
	coffin.bottom_radius = 0.28
	coffin.height = 0.7
	coffin.radial_segments = 6
	part(root, coffin, wood, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 1.0, 0.45))
	for y in [-0.2, 0.05, 0.28]:
		part(root, box(Vector3(0.5, 0.04, 0.2)), iron(), Vector3(0, y, 0))
	for i in 3:
		var x := -0.14 + i * 0.14
		part(root, cyl(0.045, 0.22), soul(), Vector3(x, 0.45, 0.04))
		part(root, cyl(0.05, 0.04), iron(), Vector3(x, 0.57, 0.04))
	part(root, sphere(0.07), mat(Color(0.9, 0.87, 0.78)), Vector3(0, 0.05, 0.14))
	return root


## The Covenant casters' iron circlet: spikes around a soul-green gem.
static func necro_circlet() -> Node3D:
	var root := Node3D.new()
	part(root, torus(0.42, 0.5), iron(), Vector3.ZERO)
	for i in 7:
		var a := TAU * i / 7.0
		var spike := CylinderMesh.new()
		spike.top_radius = 0.0
		spike.bottom_radius = 0.06
		spike.height = 0.32 if i % 2 == 0 else 0.2
		spike.radial_segments = 8
		part(root, spike, iron(), Vector3(cos(a) * 0.46, spike.height * 0.5, sin(a) * 0.46))
	part(root, sphere(0.09), soul(), Vector3(0, 0.08, 0.5))
	return root



# --- Building props (sizes in tiles) ----------------------------------------------------

## A free-standing brick chimney with a brass cap and rising smoke (green for the Covenant).
static func chimney(necro: bool) -> Node3D:
	var root := Node3D.new()
	var brick := mat(Color(0.48, 0.25, 0.2) if not necro else Color(0.2, 0.18, 0.2), 0.0, 0.0, 0.9)
	part(root, box(Vector3(0.24, 1.3, 0.24)), brick, Vector3(0, 0.65, 0))
	part(root, box(Vector3(0.3, 0.08, 0.3)), brick, Vector3(0, 1.3, 0))
	part(root, cyl(0.1, 0.16, 0.13), brass() if not necro else iron(), Vector3(0, 1.42, 0))
	for y in [0.35, 0.8]:
		part(root, box(Vector3(0.26, 0.04, 0.26)), brass() if not necro else iron(), Vector3(0, y, 0))
	var smoke := GPUParticles3D.new()
	smoke.amount = 10
	smoke.lifetime = 3.5
	smoke.position = Vector3(0, 1.5, 0)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.2, 1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.25
	pm.initial_velocity_max = 0.4
	pm.gravity = Vector3(0.05, 0.02, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 1.6))
	var gt := CurveTexture.new()
	gt.curve = grow
	pm.scale_curve = gt
	var fade := Gradient.new()
	var tint := Color(0.75, 0.75, 0.75) if not necro else Color(0.45, 0.9, 0.5)
	fade.set_color(0, Color(tint, 0.55))
	fade.set_color(1, Color(tint, 0.0))
	var ft := GradientTexture1D.new()
	ft.gradient = fade
	pm.color_ramp = ft
	smoke.process_material = pm
	var puff := sphere(0.12)
	var pmat := StandardMaterial3D.new()
	pmat.vertex_color_use_as_albedo = true
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.material = pmat
	smoke.draw_pass_1 = puff
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(smoke)
	return root


## A big brass cog standing against a wall, slowly turning.
static func wall_cog() -> Node3D:
	var root := Node3D.new()
	var spinner := Node3D.new()
	spinner.set_meta("spin_z", 0.6)
	root.add_child(spinner)
	cog(spinner, 0.32, brass(), Vector3.ZERO, Vector3(PI / 2, 0, 0), 12)
	cog(root, 0.16, copper(), Vector3(0.38, -0.2, 0.02), Vector3(PI / 2, 0, 0), 8)
	return root


## A street lamp glowing with Aether (blue) or bottled souls (green).
static func lamp(necro: bool) -> Node3D:
	var root := Node3D.new()
	part(root, cyl(0.025, 0.7), iron(), Vector3(0, 0.35, 0))
	part(root, cyl(0.06, 0.05), iron(), Vector3(0, 0.02, 0))
	part(root, cyl(0.07, 0.04), brass() if not necro else iron(), Vector3(0, 0.72, 0))
	part(root, cyl(0.055, 0.14), soul() if necro else aether(), Vector3(0, 0.81, 0))
	part(root, cyl(0.0, 0.08, 0.0), iron(), Vector3(0, 0.92, 0)).mesh = cyl(0.08, 0.06, 0.0)
	return root


## A run of brass pipes along the ground with a valve wheel.
static func pipes() -> Node3D:
	var root := Node3D.new()
	pipe(root, [Vector3(-0.6, 0.05, 0), Vector3(0.0, 0.05, 0), Vector3(0.0, 0.5, 0), Vector3(0.4, 0.5, 0)], 0.045, copper())
	pipe(root, [Vector3(-0.6, 0.15, 0.1), Vector3(0.3, 0.15, 0.1)], 0.035, brass())
	part(root, torus(0.06, 0.1), iron(), Vector3(0.0, 0.3, 0.06), Vector3(PI / 2, 0, 0))
	return root
