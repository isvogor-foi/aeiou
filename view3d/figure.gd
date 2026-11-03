extends RefCounted
## Realistic soldiers: the Quaternius Universal Animation Library figure (CC0,
## 1.83 m, 46 animations) dressed in code. Each outfit is one skinned mesh built in
## the figure's rest pose, every piece rigidly bound to a bone (coat to the spine,
## sleeves to the arms, boots to the shins, hats to the head, weapons to the hand),
## merged into one surface per colour and cached per outfit and team.

const Gear = preload("res://view3d/gear.gd")

const SCENE := "res://assets/quaternius/ual/AnimationLibrary_Godot_Standard.gltf"
const HEIGHT := 1.83

static var _packed: PackedScene
static var _rests := {}
static var _skin: Skin
static var _meshes := {}
static var _bodies := {}
static var _mats := {}


## A dressed figure: the animated scene with the body recoloured and the outfit attached.
static func build(outfit_id: String, team: Color) -> Node3D:
	if _packed == null:
		_packed = load(SCENE)
	var scene: Node3D = _packed.instantiate()
	var skel: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
	if _rests.is_empty():
		for i in skel.get_bone_count():
			_rests[skel.get_bone_name(i)] = [i, skel.get_bone_global_rest(i)]
		_skin = skel.create_skin_from_rest_transforms()
	var outfit: Dictionary = OUTFITS.get(outfit_id, OUTFITS.settler)
	var body: MeshInstance3D = skel.get_child(0)
	var key := "%s/%s" % [outfit_id, team.to_html()]
	if not _bodies.has(key):
		# Body and clothes are one skinned mesh: half the skinning work per soldier.
		_bodies[key] = _paint_body(body.mesh, skel, outfit, team, _dress(outfit, team))
	body.mesh = _bodies[key]
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return scene


static func mat(c: Color, metal := 0.0, rough := 0.75, glow := 0.0) -> StandardMaterial3D:
	var key := "%s/%s/%s/%s" % [c.to_html(), metal, rough, glow]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.metallic = metal
		m.roughness = rough
		if glow > 0.0:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = glow
		_mats[key] = m
	return _mats[key]


# --- Palette and outfits -----------------------------------------------------------------

const SKIN := Color(0.86, 0.68, 0.55)
const BONE := Color(0.86, 0.83, 0.74)
const WHITE := Color(0.93, 0.91, 0.86)
const BLACK := Color(0.09, 0.09, 0.1)
const RED := Color(0.7, 0.12, 0.13)
const SKY := Color(0.55, 0.68, 0.84)
const BROWN := Color(0.38, 0.25, 0.15)
const LODEN := Color(0.3, 0.36, 0.26)
const PIKE := Color(0.42, 0.46, 0.44)
const GOLD := Color(0.86, 0.68, 0.24)
const STEEL := Color(0.72, 0.74, 0.78)
const SCHOENBRUNN := Color(0.84, 0.64, 0.24)
const NIGHT := Color(0.12, 0.1, 0.14)
const BLOOD := Color(0.42, 0.06, 0.1)
const RAG := Color(0.35, 0.3, 0.24)

## coat, trousers, boots, cuffs (facings), coat: "tails"/"long"/"robe"/"dress"/"short",
## hat, belts (crossbelts), weapon, kit (backpacks), moustache, cuirass, team: where the
## team colour goes ("cuffs", "sash").
const OUTFITS := {
	"settler": {"coat": SCHOENBRUNN, "trousers": BROWN, "boots": BLACK, "cuffs": BROWN, "style": "short", "hat": "cap", "weapon": "hammer", "kit": "tool_pack", "moustache": true},
	"grenadier": {"coat": WHITE, "trousers": SKY, "boots": BLACK, "cuffs": RED, "style": "tails", "hat": "bearskin", "belts": true, "weapon": "musket_bayonet", "moustache": true},
	"musketeer": {"coat": WHITE, "trousers": SKY, "boots": BLACK, "cuffs": RED, "style": "tails", "hat": "shako", "belts": true, "weapon": "aether_musket", "kit": "aether_pack"},
	"jaeger": {"coat": PIKE, "trousers": PIKE, "boots": BLACK, "cuffs": Color(0.2, 0.36, 0.22), "style": "short", "hat": "jaeger_hat", "belts": true, "weapon": "rifle", "moustache": true},
	"standschuetze": {"coat": LODEN, "trousers": BROWN, "boots": BROWN, "cuffs": Color(0.6, 0.15, 0.12), "style": "short", "hat": "jaeger_hat", "weapon": "rifle", "moustache": true},
	"kaiserjaeger": {"coat": PIKE, "trousers": PIKE, "boots": BLACK, "cuffs": Color(0.2, 0.36, 0.22), "style": "tails", "hat": "jaeger_hat", "belts": true, "weapon": "aether_musket", "kit": "aether_pack"},
	"grenzer": {"coat": Color(0.62, 0.14, 0.12), "trousers": Color(0.2, 0.28, 0.5), "boots": BLACK, "cuffs": Color(0.2, 0.28, 0.5), "style": "short", "hat": "cap_red", "weapon": "musket", "moustache": true},
	"field_alchemist": {"coat": Color(0.24, 0.22, 0.36), "trousers": BLACK, "boots": BROWN, "cuffs": GOLD, "style": "long", "hat": "top_hat", "weapon": "aether_staff", "kit": "aether_pack", "goggles": true},
	"kuerassier": {"coat": WHITE, "trousers": WHITE, "boots": BLACK, "cuffs": RED, "style": "short", "hat": "helmet", "cuirass": true, "weapon": "sabre", "moustache": true},
	"hussar": {"coat": Color(0.2, 0.3, 0.6), "trousers": RED, "boots": BLACK, "cuffs": GOLD, "style": "short", "hat": "shako", "braid": true, "weapon": "sabre", "moustache": true},
	"rudolf": {"coat": BLACK, "trousers": BLACK, "boots": BLACK, "cuffs": GOLD, "style": "long", "hat": "top_hat", "weapon": "aether_staff", "kit": "aether_pack", "beard": true},
	"prince_eugene": {"coat": Color(0.45, 0.24, 0.16), "trousers": WHITE, "boots": BLACK, "cuffs": GOLD, "style": "tails", "hat": "bicorne", "cuirass": true, "weapon": "sabre"},
	"maria_theresa": {"coat": Color(0.6, 0.72, 0.86), "trousers": Color(0.6, 0.72, 0.86), "boots": WHITE, "cuffs": GOLD, "style": "dress", "hat": "crown", "weapon": "aether_staff", "hair": Color(0.85, 0.75, 0.6)},
	"archduke": {"coat": WHITE, "trousers": RED, "boots": BLACK, "cuffs": RED, "style": "tails", "hat": "plumed", "belts": false, "weapon": "sabre", "moustache": true, "sash": true},
	"rebel_militia": {"coat": BROWN, "trousers": RAG, "boots": BLACK, "cuffs": RAG, "style": "short", "hat": "cap", "weapon": "musket", "moustache": true},
	# Umbral Covenant: bone-pale bodies in rags, robes and iron.
	"thrall": {"skin": BONE, "coat": RAG, "trousers": RAG, "boots": RAG, "cuffs": RAG, "style": "short", "hat": "hood", "weapon": "axe", "kit": "grave_pack"},
	"risen": {"skin": BONE, "coat": RAG, "trousers": RAG, "boots": RAG, "cuffs": RAG, "style": "short", "weapon": "axe"},
	"reaver": {"skin": BONE, "coat": BLOOD, "trousers": NIGHT, "boots": NIGHT, "cuffs": NIGHT, "style": "short", "hat": "mask", "weapon": "blade"},
	"hexcaster": {"skin": BONE, "coat": NIGHT, "trousers": NIGHT, "boots": NIGHT, "cuffs": Color(0.3, 0.6, 0.35), "style": "robe", "hat": "hood_circlet", "weapon": "soul_lantern"},
	"bonebow": {"skin": BONE, "coat": Color(0.28, 0.22, 0.18), "trousers": NIGHT, "boots": NIGHT, "cuffs": NIGHT, "style": "short", "hat": "hood", "weapon": "crossbow"},
	"necromancer": {"skin": BONE, "coat": BLACK, "trousers": BLACK, "boots": BLACK, "cuffs": Color(0.3, 0.6, 0.35), "style": "robe", "hat": "hood", "weapon": "bone_staff"},
	"grave_brute": {"skin": BONE, "coat": Color(0.25, 0.24, 0.26), "trousers": NIGHT, "boots": NIGHT, "cuffs": NIGHT, "style": "short", "hat": "mask", "cuirass": true, "weapon": "axe", "kit": "grave_pack"},
	"vampire": {"skin": Color(0.88, 0.85, 0.82), "coat": BLACK, "trousers": BLACK, "boots": BLACK, "cuffs": BLOOD, "style": "tails", "hat": "", "weapon": "blade", "hair": BLACK},
	"wraith": {"skin": Color(0.55, 0.58, 0.62), "coat": Color(0.18, 0.2, 0.24), "trousers": Color(0.18, 0.2, 0.24), "boots": NIGHT, "cuffs": NIGHT, "style": "robe", "hat": "hood", "weapon": "soul_lantern"},
	"lich": {"skin": BONE, "coat": Color(0.2, 0.16, 0.26), "trousers": NIGHT, "boots": NIGHT, "cuffs": GOLD, "style": "robe", "hat": "circlet", "weapon": "bone_staff"},
	"shadow_sovereign": {"skin": BONE, "coat": NIGHT, "trousers": NIGHT, "boots": NIGHT, "cuffs": GOLD, "style": "robe", "hat": "crown_dark", "weapon": "bone_staff"},
	"blood_countess": {"skin": Color(0.9, 0.86, 0.84), "coat": BLOOD, "trousers": BLOOD, "boots": BLACK, "cuffs": BLACK, "style": "dress", "hat": "crown_dark", "weapon": "blade", "hair": BLACK},
	"bone_herald": {"skin": BONE, "coat": Color(0.25, 0.24, 0.26), "trousers": NIGHT, "boots": NIGHT, "cuffs": NIGHT, "style": "short", "hat": "horned", "cuirass": true, "weapon": "axe"},
	"ghoul_rider": {"skin": BONE, "coat": RAG, "trousers": RAG, "boots": RAG, "cuffs": RAG, "style": "short", "hat": "hood", "weapon": "blade"},
}


# --- Painting the uniform onto the body ---------------------------------------------------------

## A copy of the figure's mesh with vertex colours by body region: the uniform is
## painted on, so it bends perfectly with every animation and never clips.
static func _paint_body(src: Mesh, skel: Skeleton3D, o: Dictionary, team: Color, clothes: ArrayMesh) -> ArrayMesh:
	var names: Array = []
	for i in skel.get_bone_count():
		names.append(skel.get_bone_name(i))
	var wrist_x := absf(at("DEF-hand.R").x)
	var imp := ImporterMesh.new()
	var painted := StandardMaterial3D.new()
	painted.vertex_color_use_as_albedo = true
	painted.vertex_color_is_srgb = true
	painted.roughness = 0.8
	for s in src.get_surface_count():
		var arr := src.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var colors := PackedColorArray()
		colors.resize(verts.size())
		for i in verts.size():
			var best := 0
			for k in 4:
				if weights[i * 4 + k] > weights[i * 4 + best]:
					best = k
			colors[i] = _region_color(names[bones[i * 4 + best]], verts[i], o, team, wrist_x)
		arr[Mesh.ARRAY_COLOR] = colors
		imp.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, painted)
	for c in clothes.get_surface_count():
		imp.add_surface(Mesh.PRIMITIVE_TRIANGLES, clothes.surface_get_arrays(c), [], {}, clothes.surface_get_material(c))
	# Copying the mesh drops the LODs the importer made, so rebuild them: distant
	# soldiers then draw a fraction of the figure's 14k triangles.
	imp.generate_lods(25.0, 60.0, [])
	return imp.get_mesh()


static func _region_color(bone_name: String, p: Vector3, o: Dictionary, team: Color, wrist_x: float) -> Color:
	var skin: Color = o.get("skin", SKIN)
	var coat: Color = o.coat
	var robe: bool = o.get("style", "") in ["robe", "dress"]
	if bone_name.contains("head"):
		return skin
	if bone_name.contains("neck"):
		return skin if p.y > 1.52 else o.cuffs
	if bone_name.contains("hand") or bone_name.contains("f_") or bone_name.contains("thumb"):
		return o.get("gloves", skin)
	if bone_name.contains("forearm"):
		return o.cuffs if absf(p.x) > wrist_x - 0.08 else coat
	if bone_name.contains("upper_arm"):
		if bone_name.ends_with(".L") and absf(p.x) > 0.29 and absf(p.x) < 0.37:
			return team
		return coat
	if bone_name.contains("thigh"):
		return coat if robe else o.trousers
	if bone_name.contains("shin"):
		if p.y < 0.42:
			return o.boots
		return coat if robe else o.trousers
	if bone_name.contains("foot") or bone_name.contains("toe"):
		return o.boots
	if bone_name.contains("hips") and p.y < 0.9:
		return coat if robe else o.trousers
	if p.y > 0.9 and p.y < 0.97 and (bone_name.contains("hips") or bone_name.contains("spine.001")):
		return o.get("belt", BLACK)
	return coat


# --- Dressing --------------------------------------------------------------------------------

## Per-material vertex buffers for the merged skinned mesh.
class Acc:
	var surfaces := {}

	func add(mesh: Mesh, xf: Transform3D, bone: int, m: Material) -> void:
		for s in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			if not surfaces.has(m):
				surfaces[m] = [PackedVector3Array(), PackedVector3Array(), PackedInt32Array(), PackedFloat32Array(), PackedInt32Array()]
			var d: Array = surfaces[m]
			var base: int = d[0].size()
			for i in verts.size():
				d[0].append(xf * verts[i])
				d[1].append((xf.basis * norms[i]).normalized())
				d[2].append_array([bone, 0, 0, 0])
				d[3].append_array([1.0, 0.0, 0.0, 0.0])
			if idx.is_empty():
				for i in verts.size():
					d[4].append(base + i)
			else:
				for i in idx:
					d[4].append(base + i)

	func commit() -> ArrayMesh:
		var out := ArrayMesh.new()
		for m in surfaces:
			var d: Array = surfaces[m]
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = d[0]
			arr[Mesh.ARRAY_NORMAL] = d[1]
			arr[Mesh.ARRAY_BONES] = d[2]
			arr[Mesh.ARRAY_WEIGHTS] = d[3]
			arr[Mesh.ARRAY_INDEX] = d[4]
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			out.surface_set_material(out.get_surface_count() - 1, m)
		return out


static func bone(name: String) -> int:
	return _rests[name][0]


static func at(name: String) -> Vector3:
	return _rests[name][1].origin


## A cylinder from `a` to `b` (rest-pose positions), bound to `bone_name`.
static func limb(acc: Acc, a: Vector3, b: Vector3, r: float, m: Material, bone_name: String, r2 := -1.0) -> void:
	var c := CylinderMesh.new()
	c.top_radius = r if r2 < 0.0 else r2
	c.bottom_radius = r
	c.height = a.distance_to(b)
	c.radial_segments = 14
	c.rings = 1
	var dir := (b - a).normalized()
	var basis := Basis(Quaternion(Vector3.UP, dir)) if absf(dir.dot(Vector3.UP)) < 0.999 else (Basis() if dir.y > 0 else Basis(Vector3.RIGHT, PI))
	acc.add(c, Transform3D(basis, (a + b) * 0.5), bone(bone_name), m)


static func blob(acc: Acc, center: Vector3, size: Vector3, m: Material, bone_name: String, rot := Vector3.ZERO) -> void:
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 16
	s.rings = 8
	acc.add(s, Transform3D(Basis.from_euler(rot).scaled(size), center), bone(bone_name), m)


static func cube(acc: Acc, center: Vector3, size: Vector3, m: Material, bone_name: String, rot := Vector3.ZERO) -> void:
	var b := BoxMesh.new()
	b.size = size
	acc.add(b, Transform3D(Basis.from_euler(rot), center), bone(bone_name), m)


## Adds a node tree of mesh parts (gear / hats built elsewhere), placed by `xf`.
static func tree(acc: Acc, n: Node3D, xf: Transform3D, bone_name: String) -> void:
	_tree(acc, n, xf, bone(bone_name))
	n.free()


static func _tree(acc: Acc, n: Node, xf: Transform3D, b: int) -> void:
	for c in n.get_children():
		if not c is Node3D:
			continue
		var here: Transform3D = xf * c.transform
		if c is MeshInstance3D and c.mesh:
			acc.add(c.mesh, here, b, c.material_override if c.material_override else mat(Color.WHITE))
		_tree(acc, c, here, b)


static func _dress(o: Dictionary, team: Color) -> ArrayMesh:
	var acc := Acc.new()
	var coat := mat(o.coat)
	var trousers := mat(o.trousers)
	var boots := mat(o.boots, 0.0, 0.45)
	var cuffs := mat(o.cuffs)
	var style: String = o.get("style", "short")
	var robe := style in ["robe", "dress"]
	var hips := at("DEF-hips")
	var chest := at("DEF-spine.003")
	# Skirts: tails, long coat, robe or dress.
	match style:
		"tails":
			for side in [-1.0, 1.0]:
				cube(acc, hips + Vector3(side * 0.07, -0.2, -0.1), Vector3(0.09, 0.42, 0.03), coat, "DEF-hips", Vector3(-0.12, 0, side * 0.06))
				cube(acc, hips + Vector3(side * 0.07, -0.2, -0.085), Vector3(0.06, 0.38, 0.02), cuffs, "DEF-hips", Vector3(-0.12, 0, side * 0.06))
		"long":
			limb(acc, hips + Vector3(0, 0.05, 0), hips + Vector3(0, -0.5, 0), 0.17, coat, "DEF-hips", 0.22)
		"robe", "dress":
			limb(acc, hips + Vector3(0, 0.05, 0), Vector3(hips.x, 0.06, hips.z), 0.17, coat, "DEF-hips", 0.3 if style == "dress" else 0.24)
	# Gear across the chest.
	if o.get("belts", false):
		for side in [-1.0, 1.0]:
			cube(acc, chest + Vector3(0, -0.08, 0.13), Vector3(0.045, 0.46, 0.014), mat(WHITE), "DEF-spine.003", Vector3(-0.08, 0, side * 0.6))
	if o.get("cuirass", false):
		blob(acc, chest + Vector3(0, -0.07, 0.05), Vector3(0.36, 0.44, 0.22), mat(STEEL, 0.8, 0.3), "DEF-spine.003")
	if o.get("braid", false):
		for i in 5:
			cube(acc, chest + Vector3(0, -0.12 + i * 0.05, 0.13), Vector3(0.18, 0.012, 0.01), mat(GOLD, 0.6, 0.4), "DEF-spine.003")
	if o.get("sash", false):
		cube(acc, chest + Vector3(0, -0.08, 0.13), Vector3(0.07, 0.46, 0.014), mat(team), "DEF-spine.003", Vector3(-0.08, 0, 0.6))
	_head(acc, o)
	_hat(acc, o)
	_weapon(acc, o)
	if o.has("kit"):
		var pack: Node3D = Gear._build_raw(o.kit)
		tree(acc, pack, Transform3D(Basis().scaled(Vector3.ONE * 0.38), chest + Vector3(0, -0.06, -0.2)), "DEF-spine.003")
	return acc.commit()


static func _head(acc: Acc, o: Dictionary) -> void:
	var h := at("DEF-head")
	var face := h + Vector3(0, 0.1, 0.095)
	var dark := mat(Color(0.12, 0.1, 0.09))
	for side in [-1.0, 1.0]:
		blob(acc, face + Vector3(side * 0.035, 0.035, 0.005), Vector3(0.022, 0.016, 0.01), dark, "DEF-head")
	if o.get("moustache", false):
		for side in [-1.0, 1.0]:
			blob(acc, face + Vector3(side * 0.022, -0.03, 0.012), Vector3(0.05, 0.016, 0.02), mat(Color(0.3, 0.2, 0.12)), "DEF-head", Vector3(0, 0, side * -0.3))
	if o.get("beard", false):
		blob(acc, face + Vector3(0, -0.06, -0.005), Vector3(0.1, 0.1, 0.06), mat(Color(0.3, 0.24, 0.18)), "DEF-head")
	if o.has("hair"):
		blob(acc, h + Vector3(0, 0.16, -0.03), Vector3(0.21, 0.2, 0.23), mat(o.hair), "DEF-head")
		blob(acc, h + Vector3(0, 0.06, -0.09), Vector3(0.16, 0.18, 0.1), mat(o.hair), "DEF-head")
	if o.get("goggles", false):
		var g := Gear.goggles()
		tree(acc, g, Transform3D(Basis().scaled(Vector3.ONE * 0.17), h + Vector3(0, 0.2, 0.1)), "DEF-head")


static func _hat(acc: Acc, o: Dictionary) -> void:
	var h := at("DEF-head")
	var top := h + Vector3(0, 0.235, -0.005)
	var felt := mat(BLACK, 0.0, 0.7)
	var gold := mat(GOLD, 0.6, 0.4)
	match o.get("hat", ""):
		"bearskin":
			blob(acc, top + Vector3(0, 0.12, 0), Vector3(0.24, 0.36, 0.25), mat(Color(0.07, 0.06, 0.06), 0.0, 0.95), "DEF-head")
			cube(acc, top + Vector3(0, 0.02, 0.115), Vector3(0.09, 0.07, 0.01), gold, "DEF-head")
		"shako":
			limb(acc, top + Vector3(0, -0.04, 0), top + Vector3(0, 0.12, 0), 0.105, felt, "DEF-head", 0.115)
			cube(acc, top + Vector3(0, -0.035, 0.1), Vector3(0.17, 0.012, 0.07), felt, "DEF-head", Vector3(0.25, 0, 0))
			blob(acc, top + Vector3(0, 0.14, 0.08), Vector3(0.04, 0.05, 0.04), gold, "DEF-head")
			limb(acc, top + Vector3(0, 0.08, 0), top + Vector3(0, 0.1, 0), 0.117, gold, "DEF-head")
		"cap", "cap_red":
			blob(acc, top + Vector3(0, -0.02, 0), Vector3(0.22, 0.09, 0.23), mat(BROWN if o.hat == "cap" else RED), "DEF-head")
			cube(acc, top + Vector3(0, -0.04, 0.1), Vector3(0.14, 0.01, 0.06), mat(BLACK), "DEF-head", Vector3(0.2, 0, 0))
		"jaeger_hat":
			limb(acc, top + Vector3(0, -0.05, 0), top + Vector3(0, 0.08, 0), 0.11, mat(Color(0.2, 0.24, 0.18)), "DEF-head", 0.085)
			limb(acc, top + Vector3(0, -0.05, 0), top + Vector3(0, -0.04, 0), 0.19, mat(Color(0.2, 0.24, 0.18)), "DEF-head")
			cube(acc, top + Vector3(0.09, 0.08, -0.02), Vector3(0.015, 0.16, 0.05), mat(Color(0.15, 0.32, 0.18)), "DEF-head", Vector3(0, 0, -0.5))
		"top_hat":
			limb(acc, top + Vector3(0, -0.04, 0), top + Vector3(0, 0.2, 0), 0.1, felt, "DEF-head", 0.105)
			limb(acc, top + Vector3(0, -0.045, 0), top + Vector3(0, -0.035, 0), 0.17, felt, "DEF-head")
			limb(acc, top + Vector3(0, 0.0, 0), top + Vector3(0, 0.03, 0), 0.103, gold, "DEF-head")
		"bicorne", "plumed":
			cube(acc, top + Vector3(0, 0.02, 0), Vector3(0.38, 0.12, 0.08), felt, "DEF-head")
			blob(acc, top + Vector3(0.1, 0.06, 0.04), Vector3(0.04, 0.04, 0.02), gold, "DEF-head")
			if o.hat == "plumed":
				for i in 4:
					blob(acc, top + Vector3(-0.05 + i * 0.035, 0.1, 0), Vector3(0.05, 0.12, 0.04), mat(Color(0.25, 0.55, 0.3)), "DEF-head", Vector3(0, 0, -0.4 + i * 0.25))
		"helmet":
			blob(acc, top + Vector3(0, -0.04, 0), Vector3(0.25, 0.2, 0.27), mat(STEEL, 0.8, 0.3), "DEF-head")
			cube(acc, top + Vector3(0, 0.06, -0.02), Vector3(0.03, 0.08, 0.26), gold, "DEF-head")
			blob(acc, top + Vector3(0, 0.08, -0.08), Vector3(0.05, 0.14, 0.14), mat(BLACK), "DEF-head")
		"crown":
			limb(acc, top + Vector3(0, -0.02, 0), top + Vector3(0, 0.06, 0), 0.1, gold, "DEF-head", 0.11)
			blob(acc, top + Vector3(0, 0.08, 0), Vector3(0.05, 0.05, 0.05), mat(RED), "DEF-head")
		"crown_dark", "circlet", "hood_circlet":
			if o.hat == "hood_circlet":
				_hood(acc, o, top)
			limb(acc, top + Vector3(0, -0.07, 0), top + Vector3(0, -0.03, 0), 0.115, mat(Color(0.22, 0.22, 0.24), 0.6, 0.4), "DEF-head")
			for i in 5:
				var a := -0.9 + i * 0.45
				cube(acc, top + Vector3(sin(a) * 0.11, 0.0 if o.hat != "crown_dark" else 0.02, cos(a) * 0.11), Vector3(0.02, 0.08 if o.hat != "crown_dark" else 0.12, 0.02), mat(Color(0.22, 0.22, 0.24), 0.6, 0.4), "DEF-head")
			blob(acc, top + Vector3(0, -0.04, 0.115), Vector3(0.03, 0.03, 0.02), mat(Color(0.45, 1.0, 0.45), 0.0, 0.4, 2.5), "DEF-head")
		"hood":
			_hood(acc, o, top)
		"mask":
			blob(acc, h + Vector3(0, 0.1, 0.075), Vector3(0.17, 0.15, 0.08), mat(Color(0.25, 0.25, 0.27), 0.7, 0.4), "DEF-head")
			for side in [-1.0, 1.0]:
				blob(acc, h + Vector3(side * 0.035, 0.13, 0.115), Vector3(0.03, 0.015, 0.01), mat(Color(1.0, 0.3, 0.2), 0.0, 0.4, 2.0), "DEF-head")
		"horned":
			blob(acc, top + Vector3(0, -0.04, 0), Vector3(0.25, 0.2, 0.27), mat(Color(0.25, 0.25, 0.27), 0.7, 0.4), "DEF-head")
			for side in [-1.0, 1.0]:
				limb(acc, top + Vector3(side * 0.1, -0.02, 0), top + Vector3(side * 0.22, 0.1, 0), 0.03, mat(BONE), "DEF-head", 0.0)


static func _hood(acc: Acc, o: Dictionary, top: Vector3) -> void:
	var cloth := mat(o.coat)
	blob(acc, top + Vector3(0, -0.07, -0.03), Vector3(0.26, 0.28, 0.3), cloth, "DEF-head")
	limb(acc, top + Vector3(0, 0.04, -0.06), top + Vector3(0, 0.1, -0.16), 0.05, cloth, "DEF-head", 0.0)


## Weapons are built along the hand bone (the direction of the fingers), grip at the wrist.
static func _weapon(acc: Acc, o: Dictionary) -> void:
	var w: String = o.get("weapon", "")
	if w == "":
		return
	var hand := at("DEF-hand.R")
	var rest: Transform3D = _rests["DEF-hand.R"][1]
	var along: Vector3 = rest.basis.y.normalized()
	var up := Vector3.UP
	var grip := hand + along * 0.08
	var wood := mat(Color(0.42, 0.27, 0.15))
	var iron := mat(Color(0.25, 0.25, 0.27), 0.7, 0.4)
	var steel := mat(STEEL, 0.8, 0.3)
	var brass := mat(GOLD, 0.7, 0.35)
	match w:
		"musket", "musket_bayonet", "aether_musket", "rifle":
			limb(acc, grip - along * 0.3, grip + along * 0.25, 0.028, wood, "DEF-hand.R", 0.022)
			limb(acc, grip - along * 0.05, grip + along * 0.8, 0.012, iron, "DEF-hand.R")
			for t in [0.2, 0.45]:
				limb(acc, grip + along * t, grip + along * (t + 0.02), 0.024, brass, "DEF-hand.R")
			if w == "musket_bayonet":
				limb(acc, grip + along * 0.8, grip + along * 1.05, 0.008, steel, "DEF-hand.R", 0.0)
			if w == "aether_musket":
				blob(acc, grip + along * 0.1 + up * 0.04, Vector3(0.05, 0.05, 0.05), mat(Color(0.4, 0.85, 1.0), 0.0, 0.3, 2.5), "DEF-hand.R")
			if w == "rifle":
				limb(acc, grip + along * 0.05 + up * 0.04, grip + along * 0.3 + up * 0.04, 0.014, brass, "DEF-hand.R")
		"sabre", "blade":
			limb(acc, grip - along * 0.04, grip + along * 0.04, 0.02, brass if w == "sabre" else iron, "DEF-hand.R")
			cube(acc, grip + along * 0.05, Vector3(0.12, 0.012, 0.03), brass if w == "sabre" else iron, "DEF-hand.R")
			limb(acc, grip + along * 0.05, grip + along * 0.8, 0.012, steel, "DEF-hand.R", 0.004)
		"axe":
			limb(acc, grip - along * 0.15, grip + along * 0.55, 0.018, wood, "DEF-hand.R")
			cube(acc, grip + along * 0.5 + up * 0.06, Vector3(0.03, 0.14, 0.1), iron, "DEF-hand.R")
		"hammer":
			limb(acc, grip - along * 0.1, grip + along * 0.3, 0.014, wood, "DEF-hand.R")
			cube(acc, grip + along * 0.3, Vector3(0.05, 0.05, 0.12), iron, "DEF-hand.R")
		"aether_staff":
			limb(acc, grip - along * 0.6, grip + along * 0.7, 0.016, brass, "DEF-hand.R")
			blob(acc, grip + along * 0.76, Vector3(0.07, 0.11, 0.07), mat(Color(0.4, 0.85, 1.0), 0.0, 0.3, 2.5), "DEF-hand.R")
			limb(acc, grip + along * 0.66, grip + along * 0.7, 0.05, brass, "DEF-hand.R")
		"bone_staff":
			limb(acc, grip - along * 0.6, grip + along * 0.7, 0.018, mat(BONE), "DEF-hand.R")
			blob(acc, grip + along * 0.78, Vector3(0.1, 0.11, 0.1), mat(BONE), "DEF-hand.R")
			blob(acc, grip + along * 0.78 + Vector3(0, 0, 0.04), Vector3(0.03, 0.03, 0.03), mat(Color(0.45, 1.0, 0.45), 0.0, 0.4, 2.5), "DEF-hand.R")
		"soul_lantern":
			limb(acc, grip, grip + along * 0.12, 0.008, iron, "DEF-hand.R")
			limb(acc, grip + along * 0.12, grip + along * 0.26, 0.05, iron, "DEF-hand.R", 0.04)
			blob(acc, grip + along * 0.19, Vector3(0.07, 0.09, 0.07), mat(Color(0.45, 1.0, 0.45), 0.0, 0.4, 2.5), "DEF-hand.R")
		"crossbow":
			limb(acc, grip - along * 0.2, grip + along * 0.35, 0.02, wood, "DEF-hand.R")
			var across := along.cross(up).normalized()
			limb(acc, grip + along * 0.32 - across * 0.22, grip + along * 0.32 + across * 0.22, 0.012, mat(BONE), "DEF-hand.R")
