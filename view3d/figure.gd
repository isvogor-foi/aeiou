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
# Dieselpunk field kit: pike-grey wool, oiled greatcoats, rubber and gunmetal.
const FIELD := Color(0.36, 0.38, 0.35)
const FIELD_DARK := Color(0.24, 0.26, 0.24)
const GREATCOAT := Color(0.31, 0.3, 0.27)
const OILSKIN := Color(0.2, 0.17, 0.13)
const RUBBER := Color(0.08, 0.08, 0.08)
const GUNMETAL := Color(0.3, 0.32, 0.33)
const AETHER_GLOW := Color(0.4, 0.85, 1.0)
const SOUL_GLOW := Color(0.45, 1.0, 0.45)

## coat, trousers, boots, cuffs (facings), coat: "tails"/"long"/"robe"/"dress"/"short",
## hat, belts (crossbelts), weapon, kit (backpacks), moustache, cuirass, team: where the
## team colour goes ("cuffs", "sash").
const OUTFITS := {
	# Monarchy: dieselpunk field kit. Team colour on collar tabs, armband and helmet stripe.
	"settler": {"coat": OILSKIN, "trousers": FIELD_DARK, "boots": BLACK, "cuffs": BROWN, "style": "short", "hat": "cap", "goggles": true, "apron": true, "weapon": "wrench", "kit": "tool_pack", "moustache": true},
	"grenadier": {"coat": GREATCOAT, "trousers": FIELD_DARK, "boots": BLACK, "cuffs": FIELD_DARK, "style": "great", "hat": "stahlhelm", "gasmask": true, "plates": true, "tanks": "aether", "belts": true, "weapon": "musket_bayonet"},
	"musketeer": {"coat": FIELD, "trousers": FIELD_DARK, "boots": BLACK, "cuffs": FIELD_DARK, "style": "great", "hat": "stahlhelm", "gasmask": true, "tanks": "aether", "belts": true, "weapon": "aether_musket"},
	"jaeger": {"coat": Color(0.22, 0.27, 0.21), "trousers": FIELD_DARK, "boots": BLACK, "cuffs": Color(0.2, 0.36, 0.22), "style": "short", "hat": "jaeger_hat", "goggles": true, "belts": true, "weapon": "rifle", "moustache": true},
	"standschuetze": {"coat": LODEN, "trousers": BROWN, "boots": BROWN, "cuffs": Color(0.6, 0.15, 0.12), "style": "short", "hat": "jaeger_hat", "goggles": true, "weapon": "rifle", "moustache": true},
	"kaiserjaeger": {"coat": Color(0.22, 0.27, 0.21), "trousers": FIELD_DARK, "boots": BLACK, "cuffs": Color(0.2, 0.36, 0.22), "style": "great", "hat": "stahlhelm", "gasmask": true, "plates": true, "tanks": "aether", "belts": true, "weapon": "aether_musket"},
	"grenzer": {"coat": Color(0.42, 0.14, 0.12), "trousers": FIELD_DARK, "boots": BLACK, "cuffs": Color(0.2, 0.28, 0.5), "style": "short", "hat": "cap_red", "goggles": true, "plates": true, "belts": true, "weapon": "musket", "moustache": true},
	"field_alchemist": {"coat": Color(0.2, 0.19, 0.26), "trousers": BLACK, "boots": BROWN, "cuffs": GOLD, "style": "long", "hat": "top_hat", "gasmask": true, "tanks": "aether", "weapon": "aether_staff"},
	"kuerassier": {"coat": FIELD_DARK, "trousers": FIELD_DARK, "boots": BLACK, "cuffs": RED, "style": "short", "hat": "pickel", "gasmask": true, "cuirass": true, "plates": true, "weapon": "sabre"},
	"hussar": {"coat": Color(0.2, 0.32, 0.22), "trousers": Color(0.4, 0.12, 0.12), "boots": BLACK, "cuffs": GOLD, "style": "short", "hat": "shako", "goggles": true, "braid": true, "plates": true, "weapon": "sabre", "moustache": true},
	"rudolf": {"coat": BLACK, "trousers": BLACK, "boots": BLACK, "cuffs": GOLD, "style": "long", "hat": "top_hat", "goggles": true, "tanks": "aether", "weapon": "aether_staff", "beard": true},
	"prince_eugene": {"coat": Color(0.35, 0.2, 0.14), "trousers": FIELD_DARK, "boots": BLACK, "cuffs": GOLD, "style": "great", "hat": "bicorne", "cuirass": true, "plates": true, "weapon": "sabre"},
	"maria_theresa": {"coat": Color(0.5, 0.6, 0.72), "trousers": Color(0.5, 0.6, 0.72), "boots": WHITE, "cuffs": GOLD, "style": "dress", "hat": "crown", "tanks": "aether", "weapon": "aether_staff", "hair": Color(0.85, 0.75, 0.6)},
	"archduke": {"coat": WHITE, "trousers": RED, "boots": BLACK, "cuffs": RED, "style": "tails", "hat": "plumed", "belts": false, "weapon": "sabre", "moustache": true, "sash": true},
	"iron_emperor": {"coat": GUNMETAL, "trousers": FIELD_DARK, "boots": BLACK, "cuffs": GOLD, "style": "great", "hat": "helmet_gold", "gasmask": true, "cuirass": true, "plates": true, "tanks": "aether", "weapon": "flamethrower", "gloves": STEEL},
	"tesla": {"coat": Color(0.16, 0.16, 0.2), "trousers": Color(0.16, 0.16, 0.2), "boots": BLACK, "cuffs": WHITE, "style": "long", "goggles": true, "tanks": "aether", "weapon": "gauntlet", "moustache": true, "hair": BLACK},
	"houdini": {"coat": BLACK, "trousers": BLACK, "boots": BLACK, "cuffs": WHITE, "style": "short", "goggles": true, "weapon": "pistol", "hair": Color(0.2, 0.15, 0.1), "belts": false},
	"radetzky": {"coat": GREATCOAT, "trousers": RED, "boots": BLACK, "cuffs": GOLD, "style": "great", "hat": "plumed", "plates": true, "weapon": "sabre", "moustache": true, "sash": true, "skin": Color(0.88, 0.76, 0.66)},
	"jelacic": {"coat": Color(0.45, 0.12, 0.1), "trousers": FIELD_DARK, "boots": BLACK, "cuffs": GOLD, "style": "short", "hat": "kalpak", "braid": true, "plates": true, "goggles": true, "weapon": "sabre", "moustache": true},
	"rudolf_sovereign": {"skin": Color(0.78, 0.76, 0.74), "coat": BLACK, "trousers": BLACK, "boots": BLACK, "cuffs": SOUL_GLOW, "style": "long", "hat": "crown_dark", "vials": true, "struts": true, "weapon": "bone_staff", "moustache": true, "hair": Color(0.25, 0.18, 0.12), "sash": true},
	"pale_empress": {"skin": Color(0.84, 0.86, 0.9), "coat": Color(0.92, 0.94, 0.96), "trousers": Color(0.92, 0.94, 0.96), "boots": WHITE, "cuffs": SOUL_GLOW, "style": "dress", "hat": "stars", "vials": true, "weapon": "", "hair": Color(0.32, 0.2, 0.12)},
	"lich_general": {"skin": BONE, "coat": Color(0.18, 0.14, 0.24), "trousers": NIGHT, "boots": NIGHT, "cuffs": GOLD, "style": "robe", "hat": "crown_dark", "cuirass": true, "plates": true, "vials": true, "jaw": true, "weapon": "bone_staff"},
	# Crown-land troops.
	"bombardier": {"coat": OILSKIN, "trousers": BLACK, "boots": BROWN, "cuffs": Color(0.75, 0.78, 0.82), "style": "great", "hat": "stahlhelm", "gasmask": true, "plates": true, "tanks": "fire", "weapon": "flamethrower"},
	"vampire_hunter": {"coat": Color(0.16, 0.12, 0.1), "trousers": Color(0.22, 0.2, 0.18), "boots": BLACK, "cuffs": Color(0.75, 0.75, 0.78), "style": "long", "hat": "top_hat", "goggles": true, "gasmask": true, "weapon": "crossbow", "belts": true},
	"uhlan": {"coat": Color(0.15, 0.2, 0.34), "trousers": FIELD_DARK, "boots": BLACK, "cuffs": Color(0.8, 0.15, 0.15), "style": "short", "hat": "shako", "goggles": true, "plates": true, "weapon": "sabre", "moustache": true, "belts": true},
	# Hungarian insurrection: brown attila coats, red-white-green, scavenged kit.
	"honved": {"coat": Color(0.34, 0.24, 0.16), "trousers": Color(0.2, 0.26, 0.4), "boots": BLACK, "cuffs": Color(0.75, 0.15, 0.13), "style": "great", "hat": "stahlhelm", "goggles": true, "braid": true, "weapon": "musket", "moustache": true},
	"kaszas": {"coat": Color(0.62, 0.6, 0.52), "trousers": Color(0.62, 0.6, 0.52), "boots": BLACK, "cuffs": Color(0.24, 0.5, 0.26), "style": "short", "hat": "kalpak", "gasmask": true, "weapon": "axe", "moustache": true},
	"rebel_militia": {"coat": BROWN, "trousers": RAG, "boots": BLACK, "cuffs": RAG, "style": "short", "hat": "cap", "goggles": true, "weapon": "musket", "moustache": true},
	# Umbral Covenant: necro-industrial. Bone-pale bodies held together by iron jaw
	# braces, bone exoskeleton struts, and soul-green vials and tanks.
	"thrall": {"skin": BONE, "coat": RAG, "trousers": RAG, "boots": RAG, "cuffs": RAG, "style": "short", "hat": "hood", "jaw": true, "struts": true, "weapon": "axe", "kit": "grave_pack"},
	"risen": {"skin": BONE, "coat": RAG, "trousers": RAG, "boots": RAG, "cuffs": RAG, "style": "short", "jaw": true, "struts": true, "weapon": "axe"},
	"reaver": {"skin": BONE, "coat": BLOOD, "trousers": NIGHT, "boots": NIGHT, "cuffs": NIGHT, "style": "short", "hat": "mask", "plates": true, "struts": true, "vials": true, "weapon": "blade"},
	"hexcaster": {"skin": BONE, "coat": NIGHT, "trousers": NIGHT, "boots": NIGHT, "cuffs": SOUL_GLOW, "style": "robe", "hat": "hood_circlet", "jaw": true, "vials": true, "weapon": "soul_lantern"},
	"bonebow": {"skin": BONE, "coat": Color(0.24, 0.19, 0.16), "trousers": NIGHT, "boots": NIGHT, "cuffs": NIGHT, "style": "short", "hat": "hood", "jaw": true, "struts": true, "weapon": "crossbow"},
	"necromancer": {"skin": BONE, "coat": BLACK, "trousers": BLACK, "boots": BLACK, "cuffs": SOUL_GLOW, "style": "robe", "hat": "hood", "jaw": true, "vials": true, "tanks": "soul", "weapon": "bone_staff"},
	"grave_brute": {"skin": BONE, "coat": Color(0.25, 0.24, 0.26), "trousers": NIGHT, "boots": NIGHT, "cuffs": NIGHT, "style": "short", "hat": "mask", "cuirass": true, "plates": true, "struts": true, "tanks": "soul", "weapon": "axe"},
	"vampire": {"skin": Color(0.88, 0.85, 0.82), "coat": BLACK, "trousers": BLACK, "boots": BLACK, "cuffs": BLOOD, "style": "great", "hat": "", "vials": true, "weapon": "blade", "hair": BLACK},
	"wraith": {"skin": Color(0.55, 0.58, 0.62), "coat": Color(0.18, 0.2, 0.24), "trousers": Color(0.18, 0.2, 0.24), "boots": NIGHT, "cuffs": NIGHT, "style": "robe", "hat": "hood", "jaw": true, "vials": true, "weapon": "soul_lantern"},
	"lich": {"skin": BONE, "coat": Color(0.2, 0.16, 0.26), "trousers": NIGHT, "boots": NIGHT, "cuffs": GOLD, "style": "robe", "hat": "circlet", "jaw": true, "vials": true, "struts": true, "weapon": "bone_staff"},
	"shadow_sovereign": {"skin": BONE, "coat": NIGHT, "trousers": NIGHT, "boots": NIGHT, "cuffs": GOLD, "style": "robe", "hat": "crown_dark", "vials": true, "tanks": "soul", "weapon": "bone_staff"},
	"blood_countess": {"skin": Color(0.9, 0.86, 0.84), "coat": BLOOD, "trousers": BLOOD, "boots": BLACK, "cuffs": BLACK, "style": "dress", "hat": "crown_dark", "vials": true, "weapon": "blade", "hair": BLACK},
	"bone_herald": {"skin": BONE, "coat": Color(0.25, 0.24, 0.26), "trousers": NIGHT, "boots": NIGHT, "cuffs": NIGHT, "style": "short", "hat": "horned", "cuirass": true, "plates": true, "struts": true, "jaw": true, "weapon": "axe"},
	# Monsters: big figures in the soldiers' style.
	"abomination": {"skin": Color(0.58, 0.62, 0.5), "coat": Color(0.58, 0.62, 0.5), "trousers": RAG, "boots": RAG, "cuffs": Color(0.2, 0.2, 0.21), "style": "short", "bulk": 1.15, "plates": true, "stitches": true, "jaw": true, "vials": true, "apron": true, "weapon": "hook"},
	"bone_golem": {"skin": BONE, "coat": Color(0.3, 0.27, 0.24), "trousers": Color(0.3, 0.27, 0.24), "boots": Color(0.2, 0.2, 0.21), "cuffs": BONE, "style": "short", "ribs": true, "jaw": true, "struts": true, "weapon": "axe"},
	"bone_colossus": {"skin": BONE, "coat": Color(0.3, 0.27, 0.24), "trousers": Color(0.3, 0.27, 0.24), "boots": Color(0.2, 0.2, 0.21), "cuffs": BONE, "style": "short", "ribs": true, "jaw": true, "struts": true, "hat": "horned", "tanks": "soul", "vials": true, "weapon": "axe"},
	"prague_golem": {"skin": Color(0.5, 0.36, 0.26), "coat": Color(0.5, 0.36, 0.26), "trousers": Color(0.46, 0.33, 0.24), "boots": Color(0.4, 0.29, 0.21), "cuffs": Color(0.46, 0.33, 0.24), "style": "short", "bulk": 1.2, "bulk_style": "stone", "rune": true, "weapon": "fist", "belt": Color(0.3, 0.2, 0.12)},
	"aether_colossus": {"skin": SKIN, "coat": GUNMETAL, "trousers": GUNMETAL, "boots": BLACK, "cuffs": GOLD, "style": "short", "bulk": 1.15, "bulk_style": "plate", "hat": "diving", "cuirass": true, "plates": true, "tanks": "aether", "weapon": "flamethrower", "gloves": STEEL},
	"ghoul_rider": {"skin": BONE, "coat": RAG, "trousers": RAG, "boots": RAG, "cuffs": RAG, "style": "short", "hat": "hood", "jaw": true, "struts": true, "weapon": "blade"},
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
	if o.has("gloves_leather") and (bone_name.contains("hand") or bone_name.contains("f_") or bone_name.contains("thumb")):
		return OILSKIN
	if bone_name.contains("head"):
		return skin
	if bone_name.contains("neck"):
		return skin if p.y > 1.52 else team
	if bone_name.contains("hand") or bone_name.contains("f_") or bone_name.contains("thumb"):
		return o.get("gloves", skin)
	if bone_name.contains("forearm"):
		return o.cuffs if absf(p.x) > wrist_x - 0.08 else coat
	if bone_name.contains("upper_arm"):
		if absf(p.x) > 0.29 and absf(p.x) < 0.37:
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
		"great":
			# Knee-length trench greatcoat with a wide collar and two rows of brass buttons.
			limb(acc, hips + Vector3(0, 0.06, 0), hips + Vector3(0, -0.56, -0.01), 0.17, coat, "DEF-hips", 0.25)
			limb(acc, hips + Vector3(0, 0.0, 0), hips + Vector3(0, 0.03, 0), 0.178, mat(OILSKIN, 0.0, 0.6), "DEF-hips")
			var neck := at("DEF-neck")
			limb(acc, neck + Vector3(0, -0.04, -0.01), neck + Vector3(0, 0.03, -0.02), 0.1, coat, "DEF-spine.003", 0.12)
			for side in [-1.0, 1.0]:
				for i in 4:
					blob(acc, chest + Vector3(side * 0.06, -0.15 + i * 0.065, 0.135), Vector3(0.022, 0.022, 0.012), mat(GOLD, 0.7, 0.35), "DEF-spine.003")
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
	if o.has("bulk"):
		_bulk(acc, o)
	_diesel(acc, o, team)
	_head(acc, o)
	_hat(acc, o, team)
	_weapon(acc, o)
	if o.has("kit") and not o.has("tanks"):
		var pack: Node3D = Gear._build_raw(o.kit)
		tree(acc, pack, Transform3D(Basis().scaled(Vector3.ONE * 0.38), chest + Vector3(0, -0.06, -0.2)), "DEF-spine.003")
	return acc.commit()


## Hulking monsters: muscle (or stone, or plate) masses bound to the bones so they
## move with every animation, plus stitched seams on flesh golems.
static func _bulk(acc: Acc, o: Dictionary) -> void:
	var k: float = o.bulk
	var kind: String = o.get("bulk_style", "flesh")
	var chest := at("DEF-spine.003")
	var hips := at("DEF-hips")
	var body_m := mat(o.coat, 0.0, 0.7) if kind == "flesh" else (mat(o.coat, 0.0, 0.95) if kind == "stone" else mat(o.coat, 0.7, 0.45))
	var legs_m := mat(o.trousers, 0.0, 0.75) if kind != "plate" else mat(o.trousers, 0.7, 0.45)
	var rivet := mat(GOLD, 0.7, 0.35)
	if kind == "flesh":
		blob(acc, chest + Vector3(0, -0.04, 0.03), Vector3(0.4, 0.3, 0.27) * k, body_m, "DEF-spine.003")
		blob(acc, hips + Vector3(0, 0.14, 0.07), Vector3(0.36, 0.3, 0.3) * k, body_m, "DEF-spine.001")
		for side in ["L", "R"]:
			var ua := at("DEF-upper_arm." + side)
			var fa := at("DEF-forearm." + side)
			blob(acc, ua.lerp(fa, 0.35), Vector3(0.14, 0.2, 0.14) * k, body_m, "DEF-upper_arm." + side)
			blob(acc, fa.lerp(at("DEF-hand." + side), 0.4), Vector3(0.12, 0.16, 0.12) * k, body_m, "DEF-forearm." + side)
			var th := at("DEF-thigh." + side)
			blob(acc, th.lerp(at("DEF-shin." + side), 0.45), Vector3(0.15, 0.24, 0.15) * k, legs_m, "DEF-thigh." + side)
	else:
		# Stone slabs or riveted armour blocks, slightly askew.
		cube(acc, chest + Vector3(0, -0.05, 0.04), Vector3(0.4, 0.3, 0.26) * k, body_m, "DEF-spine.003", Vector3(0.05, 0, 0.03))
		cube(acc, hips.lerp(chest, 0.45) + Vector3(0, 0, 0.03), Vector3(0.32, 0.18, 0.22) * k, body_m, "DEF-spine.001", Vector3(-0.04, 0, -0.03))
		for side in ["L", "R"]:
			var sx := -1.0 if side == "L" else 1.0
			var ua := at("DEF-upper_arm." + side)
			var fa := at("DEF-forearm." + side)
			var hd := at("DEF-hand." + side)
			cube(acc, ua + Vector3(0, 0.03, 0), Vector3(0.2, 0.14, 0.2) * k, body_m, "DEF-upper_arm." + side, Vector3(0, 0, sx * 0.2))
			cube(acc, ua.lerp(fa, 0.55), Vector3(0.12, 0.16, 0.12) * k, body_m, "DEF-upper_arm." + side)
			cube(acc, fa.lerp(hd, 0.45), Vector3(0.13, 0.17, 0.13) * k, body_m, "DEF-forearm." + side)
			cube(acc, hd, Vector3(0.12, 0.1, 0.12) * k, body_m, "DEF-hand." + side)
			var th := at("DEF-thigh." + side)
			var sh := at("DEF-shin." + side)
			cube(acc, th.lerp(sh, 0.45), Vector3(0.15, 0.24, 0.16) * k, legs_m, "DEF-thigh." + side)
			cube(acc, sh.lerp(at("DEF-foot." + side), 0.45), Vector3(0.13, 0.22, 0.14) * k, legs_m, "DEF-shin." + side)
			if kind == "plate":
				for y in [-0.06, 0.06]:
					blob(acc, chest + Vector3(sx * 0.15 * k, y - 0.05, 0.17 * k), Vector3(0.025, 0.025, 0.015), rivet, "DEF-spine.003")
			else:
				# Glowing cracks in the clay.
				cube(acc, chest + Vector3(sx * 0.08, -0.08 + sx * 0.04, 0.175 * k), Vector3(0.012, 0.12, 0.01), mat(Color(1.0, 0.65, 0.25), 0.0, 0.3, 2.5), "DEF-spine.003", Vector3(0, 0, sx * 0.5))
	if o.get("stitches", false):
		var thread := mat(Color(0.1, 0.08, 0.07))
		for i in 7:
			cube(acc, chest + Vector3(-0.02 + (i % 2) * 0.04, -0.2 + i * 0.05, 0.17 * k), Vector3(0.08, 0.012, 0.012), thread, "DEF-spine.003", Vector3(0, 0, 0.6 if i % 2 == 0 else -0.6))
		for side in ["L", "R"]:
			var ua := at("DEF-upper_arm." + side)
			for i in 3:
				cube(acc, ua + Vector3(0, -0.04 - i * 0.05, 0.1 * k), Vector3(0.012, 0.012, 0.06), thread, "DEF-upper_arm." + side)
	if o.get("rune", false):
		var h := at("DEF-head")
		cube(acc, h + Vector3(0, 0.17, 0.11), Vector3(0.1, 0.035, 0.02), mat(Color(1.0, 0.7, 0.3), 0.0, 0.3, 3.0), "DEF-head")
		for side in [-1.0, 1.0]:
			blob(acc, h + Vector3(side * 0.035, 0.12, 0.1), Vector3(0.03, 0.02, 0.01), mat(Color(1.0, 0.7, 0.3), 0.0, 0.3, 2.5), "DEF-head")


## Dieselpunk and necro-industrial kit: armour plates, back tanks with hoses,
## leather aprons, soul vials and bone exoskeleton struts.
static func _diesel(acc: Acc, o: Dictionary, team: Color) -> void:
	var chest := at("DEF-spine.003")
	var hips := at("DEF-hips")
	var steel := mat(GUNMETAL, 0.75, 0.4)
	var brass := mat(GOLD, 0.7, 0.35)
	var covenant: bool = o.get("skin", SKIN) == BONE or o.has("jaw") or o.has("vials")
	if o.get("plates", false):
		# Riveted shoulder plates (team-colour edge) and a chest plate.
		var plate := mat(Color(0.2, 0.2, 0.21), 0.7, 0.45) if covenant else steel
		for side in ["L", "R"]:
			var sh := at("DEF-upper_arm." + side)
			var sx := -1.0 if side == "L" else 1.0
			sx = signf(sh.x) if absf(sh.x) > 0.01 else sx
			blob(acc, sh + Vector3(sx * 0.03, 0.04, 0), Vector3(0.16, 0.09, 0.17), plate, "DEF-upper_arm." + side, Vector3(0, 0, sx * -0.35))
			blob(acc, sh + Vector3(sx * 0.03, 0.025, 0), Vector3(0.165, 0.05, 0.175), mat(team) if not covenant else mat(BONE), "DEF-upper_arm." + side, Vector3(0, 0, sx * -0.35))
		if not o.get("cuirass", false):
			cube(acc, chest + Vector3(0, -0.05, 0.12), Vector3(0.24, 0.2, 0.035), plate, "DEF-spine.003", Vector3(-0.1, 0, 0))
			for x in [-0.09, 0.09]:
				for y in [-0.13, 0.03]:
					blob(acc, chest + Vector3(x, y, 0.14), Vector3(0.018, 0.018, 0.01), brass if not covenant else mat(BONE), "DEF-spine.003")
	if o.get("apron", false):
		cube(acc, hips + Vector3(0, -0.12, 0.13), Vector3(0.26, 0.42, 0.02), mat(Color(0.3, 0.2, 0.12), 0.0, 0.7), "DEF-hips", Vector3(-0.08, 0, 0))
		cube(acc, chest + Vector3(0, -0.05, 0.13), Vector3(0.2, 0.2, 0.02), mat(Color(0.3, 0.2, 0.12), 0.0, 0.7), "DEF-spine.003")
	if o.has("tanks"):
		var glow: Color = {"aether": AETHER_GLOW, "soul": SOUL_GLOW, "fire": Color(1.0, 0.5, 0.15)}.get(o.tanks, AETHER_GLOW)
		var shell := steel if o.tanks != "soul" else mat(Color(0.2, 0.2, 0.21), 0.7, 0.45)
		var back := chest + Vector3(0, -0.12, -0.2)
		for side in [-1.0, 1.0]:
			var c := back + Vector3(side * 0.075, 0, 0)
			limb(acc, c + Vector3(0, -0.17, 0), c + Vector3(0, 0.17, 0), 0.062, shell, "DEF-spine.003")
			blob(acc, c + Vector3(0, 0.17, 0), Vector3(0.124, 0.07, 0.124), shell, "DEF-spine.003")
			# Glowing gauge window and brass bands.
			limb(acc, c + Vector3(0, -0.06, 0), c + Vector3(0, 0.08, 0), 0.064, mat(glow, 0.0, 0.3, 2.2), "DEF-spine.003")
			for y in [-0.12, 0.12]:
				limb(acc, c + Vector3(0, y, 0), c + Vector3(0, y + 0.025, 0), 0.068, brass, "DEF-spine.003")
		cube(acc, back + Vector3(0, 0.02, 0.07), Vector3(0.22, 0.04, 0.03), mat(OILSKIN), "DEF-spine.003")
		# A ribbed hose over the shoulder to the mask, or down to the weapon hand.
		var to := at("DEF-head") + Vector3(0, 0.02, 0.12) if o.get("gasmask", false) else at("DEF-upper_arm.R") + Vector3(0, -0.05, 0.05)
		var from := back + Vector3(0.075, 0.2, 0)
		var mid := (from + to) * 0.5 + Vector3(0.06, 0.08, 0)
		for seg in [[from, mid], [mid, to]]:
			limb(acc, seg[0], seg[1], 0.022, mat(RUBBER, 0.0, 0.6), "DEF-spine.003")
	if o.get("vials", false):
		# A bandolier of glowing soul vials across the chest.
		cube(acc, chest + Vector3(0, -0.08, 0.13), Vector3(0.05, 0.48, 0.014), mat(OILSKIN), "DEF-spine.003", Vector3(-0.08, 0, -0.6))
		for i in 4:
			var t := -0.15 + i * 0.09
			var v := chest + Vector3(t * 0.75, -0.08 - t * 0.55, 0.15)
			limb(acc, v + Vector3(0, -0.035, 0), v + Vector3(0, 0.035, 0), 0.016, mat(SOUL_GLOW, 0.0, 0.3, 2.5), "DEF-spine.003")
			limb(acc, v + Vector3(0, 0.035, 0), v + Vector3(0, 0.05, 0), 0.018, mat(Color(0.2, 0.2, 0.21), 0.7, 0.45), "DEF-spine.003")
	if o.get("ribs", false) or (o.get("jaw", false) and not o.get("plates", false) and not o.get("cuirass", false) and not o.get("vials", false) and not o.has("bulk")):
		# The dead's ribcage bared through torn rags, ribs wired together in iron.
		var rib := mat(BONE, 0.0, 0.6)
		for i in 4:
			var y := -0.14 + i * 0.065
			var wdt := 0.24 - absf(i - 1.5) * 0.03
			cube(acc, chest + Vector3(0, y, 0.135), Vector3(wdt, 0.026, 0.03), rib, "DEF-spine.003")
		limb(acc, chest + Vector3(0, -0.17, 0.15), chest + Vector3(0, 0.06, 0.15), 0.014, mat(Color(0.2, 0.2, 0.21), 0.7, 0.45), "DEF-spine.003")
	if o.get("struts", false):
		# Bone exoskeleton: a spine rod and leg braces bolted on with iron.
		var bone_m := mat(BONE, 0.0, 0.6)
		var bolt := mat(Color(0.2, 0.2, 0.21), 0.7, 0.45)
		limb(acc, hips + Vector3(0, 0.0, -0.15), chest + Vector3(0, 0.1, -0.16), 0.026, bone_m, "DEF-spine.003")
		for i in 4:
			blob(acc, hips.lerp(chest, 0.2 + i * 0.25) + Vector3(0, 0, -0.15), Vector3(0.09, 0.03, 0.04), bone_m, "DEF-spine.003")
		for side in ["L", "R"]:
			var th := at("DEF-thigh." + side)
			var kn := at("DEF-shin." + side)
			var ft := at("DEF-foot." + side)
			var sx := signf(th.x) if absf(th.x) > 0.01 else 1.0
			var off := Vector3(sx * 0.1, 0, 0.01)
			limb(acc, th + off + Vector3(0, -0.05, 0), kn + off, 0.024, bone_m, "DEF-thigh." + side)
			limb(acc, kn + off, ft + off + Vector3(0, 0.08, 0), 0.02, bone_m, "DEF-shin." + side)
			blob(acc, kn + off, Vector3(0.07, 0.07, 0.07), bolt, "DEF-shin." + side)
			blob(acc, kn + off + Vector3(sx * 0.03, 0, 0), Vector3(0.025, 0.025, 0.025), mat(SOUL_GLOW, 0.0, 0.3, 2.5), "DEF-shin." + side)


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
	if o.get("gasmask", false):
		# Rubber face mask, round glowing lenses with brass rims, a forward filter can.
		var rubber := mat(RUBBER, 0.0, 0.55)
		blob(acc, h + Vector3(0, 0.08, 0.055), Vector3(0.2, 0.2, 0.15), rubber, "DEF-head")
		var lens := mat(Color(1.0, 0.7, 0.3) if o.get("tanks", "") == "fire" else AETHER_GLOW, 0.0, 0.2, 2.0)
		for side in [-1.0, 1.0]:
			var e := face + Vector3(side * 0.042, 0.03, 0.03)
			limb(acc, e - Vector3(0, 0, 0.012), e + Vector3(0, 0, 0.008), 0.034, mat(GOLD, 0.7, 0.35), "DEF-head")
			blob(acc, e + Vector3(0, 0, 0.01), Vector3(0.05, 0.05, 0.016), lens, "DEF-head")
		limb(acc, face + Vector3(0, -0.04, 0.02), face + Vector3(0, -0.085, 0.1), 0.04, mat(GUNMETAL, 0.75, 0.4), "DEF-head", 0.034)
		for t in [0.3, 0.7]:
			var r := face + Vector3(0, -0.04, 0.02).lerp(Vector3(0, -0.085, 0.1), t)
			limb(acc, r, r + Vector3(0, -0.005, 0.01), 0.044, mat(GOLD, 0.7, 0.35), "DEF-head")
	if o.get("jaw", false):
		# Iron jaw brace bolted to the skull, glowing at the hinges.
		var iron_m := mat(Color(0.2, 0.2, 0.21), 0.75, 0.4)
		blob(acc, face + Vector3(0, -0.06, -0.005), Vector3(0.17, 0.08, 0.13), iron_m, "DEF-head")
		for i in 4:
			cube(acc, face + Vector3(-0.045 + i * 0.03, -0.04, 0.055), Vector3(0.012, 0.035, 0.012), mat(BONE), "DEF-head")
		# Riveted iron plate over one eye, a soul-green lens glaring through.
		blob(acc, face + Vector3(0.04, 0.035, 0.0), Vector3(0.075, 0.07, 0.03), iron_m, "DEF-head")
		blob(acc, face + Vector3(0.04, 0.035, 0.016), Vector3(0.035, 0.035, 0.012), mat(SOUL_GLOW, 0.0, 0.3, 3.0), "DEF-head")
		for side in [-1.0, 1.0]:
			limb(acc, face + Vector3(side * 0.07, -0.05, -0.04), face + Vector3(side * 0.075, 0.03, -0.06), 0.012, iron_m, "DEF-head")
			blob(acc, face + Vector3(side * 0.075, 0.03, -0.06), Vector3(0.025, 0.025, 0.025), mat(SOUL_GLOW, 0.0, 0.3, 2.5), "DEF-head")
		for side in [-1.0, 1.0]:
			blob(acc, face + Vector3(side * 0.035, 0.035, 0.01), Vector3(0.024, 0.018, 0.01), mat(SOUL_GLOW, 0.0, 0.3, 2.0), "DEF-head")
	if o.get("goggles", false) and not o.get("gasmask", false) and not o.get("hat", "") in ["stahlhelm", "pickel"]:
		var g := Gear.goggles()
		tree(acc, g, Transform3D(Basis().scaled(Vector3.ONE * 0.17), h + Vector3(0, 0.2, 0.1)), "DEF-head")


static func _hat(acc: Acc, o: Dictionary, team: Color) -> void:
	var h := at("DEF-head")
	var top := h + Vector3(0, 0.235, -0.005)
	var felt := mat(BLACK, 0.0, 0.7)
	var gold := mat(GOLD, 0.6, 0.4)
	match o.get("hat", ""):
		"diving":
			# Brass diving-suit helmet: a round dome, a glowing porthole visor, bolts and a collar.
			var shell := mat(GOLD, 0.7, 0.35)
			blob(acc, h + Vector3(0, 0.12, 0.0), Vector3(0.36, 0.36, 0.36), shell, "DEF-head")
			limb(acc, h + Vector3(0, -0.06, 0), h + Vector3(0, 0.0, 0), 0.2, mat(GUNMETAL, 0.75, 0.4), "DEF-head")
			limb(acc, h + Vector3(0, 0.12, 0.16), h + Vector3(0, 0.12, 0.19), 0.1, mat(GUNMETAL, 0.75, 0.4), "DEF-head")
			blob(acc, h + Vector3(0, 0.12, 0.19), Vector3(0.16, 0.16, 0.03), mat(AETHER_GLOW, 0.0, 0.2, 2.5), "DEF-head")
			for side in [-1.0, 1.0]:
				blob(acc, h + Vector3(side * 0.17, 0.12, 0.0), Vector3(0.08, 0.08, 0.04), mat(AETHER_GLOW, 0.0, 0.2, 1.5), "DEF-head", Vector3(0, PI / 2, 0))
			limb(acc, h + Vector3(0, 0.3, 0), h + Vector3(0, 0.36, 0), 0.05, mat(GUNMETAL, 0.75, 0.4), "DEF-head")
		"stahlhelm", "pickel":
			# Steel trench helmet: a deep dome over a flared skirt, team stripe, brass eagle, vent bolts.
			var shell := mat(Color(0.3, 0.32, 0.3), 0.55, 0.5)
			blob(acc, top + Vector3(0, -0.035, -0.005), Vector3(0.27, 0.2, 0.29), shell, "DEF-head")
			limb(acc, top + Vector3(0, -0.075, -0.005), top + Vector3(0, -0.125, -0.02), 0.137, shell, "DEF-head", 0.165)
			limb(acc, top + Vector3(0, -0.02, -0.005), top + Vector3(0, 0.0, -0.005), 0.131, mat(team), "DEF-head", 0.125)
			blob(acc, top + Vector3(0, -0.04, 0.135), Vector3(0.04, 0.04, 0.012), mat(GOLD, 0.7, 0.35), "DEF-head")
			for side in [-1.0, 1.0]:
				limb(acc, top + Vector3(side * 0.12, -0.05, 0.0), top + Vector3(side * 0.145, -0.05, 0.0), 0.016, mat(GUNMETAL, 0.75, 0.4), "DEF-head")
			if o.hat == "pickel":
				limb(acc, top + Vector3(0, 0.05, -0.005), top + Vector3(0, 0.17, -0.005), 0.022, mat(GOLD, 0.7, 0.35), "DEF-head", 0.0)
			if o.get("goggles", false):
				var g := Gear.goggles()
				tree(acc, g, Transform3D(Basis().scaled(Vector3.ONE * 0.17), top + Vector3(0, -0.05, 0.13)), "DEF-head")
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
		"helmet_gold":
			blob(acc, top + Vector3(0, -0.04, 0), Vector3(0.25, 0.2, 0.27), gold, "DEF-head")
			cube(acc, top + Vector3(0, 0.07, -0.02), Vector3(0.03, 0.1, 0.26), mat(STEEL, 0.8, 0.3), "DEF-head")
			blob(acc, top + Vector3(0, 0.1, -0.1), Vector3(0.06, 0.16, 0.16), mat(WHITE), "DEF-head")
		"kalpak":
			limb(acc, top + Vector3(0, -0.05, 0), top + Vector3(0, 0.1, 0), 0.115, mat(Color(0.12, 0.1, 0.08), 0.0, 0.95), "DEF-head", 0.105)
			blob(acc, top + Vector3(0.0, 0.16, 0.06), Vector3(0.05, 0.16, 0.05), mat(WHITE), "DEF-head", Vector3(-0.3, 0, 0))
			blob(acc, top + Vector3(0, 0.08, 0.1), Vector3(0.05, 0.05, 0.02), gold, "DEF-head")
		"stars":
			# Empress Elisabeth's diamond stars in her hair, glowing with the dead light.
			blob(acc, top + Vector3(0, -0.05, -0.1), Vector3(0.24, 0.16, 0.2), mat(o.get("hair", BROWN)), "DEF-head")
			for i in 7:
				var a := -1.2 + i * 0.4
				blob(acc, top + Vector3(sin(a) * 0.12, -0.02 + absf(sin(a)) * 0.02, cos(a) * 0.1 - 0.04), Vector3(0.035, 0.035, 0.01), mat(Color(0.8, 1.0, 0.85), 0.0, 0.2, 3.0), "DEF-head")
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
		"hook":
			# A butcher's chain hook.
			var hk := mat(Color(0.25, 0.25, 0.27), 0.7, 0.4)
			limb(acc, grip - along * 0.05, grip + along * 0.45, 0.02, hk, "DEF-hand.R")
			var across := along.cross(up).normalized()
			limb(acc, grip + along * 0.45, grip + along * 0.55 + across * 0.08, 0.02, hk, "DEF-hand.R")
			limb(acc, grip + along * 0.55 + across * 0.08, grip + along * 0.5 + across * 0.16, 0.017, hk, "DEF-hand.R", 0.0)
		"fist":
			pass
		"wrench":
			var wr := mat(GUNMETAL, 0.75, 0.4)
			limb(acc, grip - along * 0.1, grip + along * 0.32, 0.016, wr, "DEF-hand.R")
			var across := along.cross(up).normalized()
			cube(acc, grip + along * 0.34 + across * 0.035, Vector3(0.03, 0.03, 0.1), wr, "DEF-hand.R")
			cube(acc, grip + along * 0.34 - across * 0.035, Vector3(0.03, 0.03, 0.1), wr, "DEF-hand.R")
			limb(acc, grip + along * 0.25, grip + along * 0.28, 0.022, mat(GOLD, 0.7, 0.35), "DEF-hand.R")
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
		"flamethrower":
			limb(acc, grip - along * 0.15, grip + along * 0.55, 0.035, steel, "DEF-hand.R", 0.03)
			limb(acc, grip + along * 0.5, grip + along * 0.6, 0.045, brass, "DEF-hand.R")
			blob(acc, grip + along * 0.64, Vector3(0.05, 0.05, 0.05), mat(Color(1.0, 0.55, 0.15), 0.0, 0.4, 3.0), "DEF-hand.R")
			for t in [0.1, 0.3]:
				limb(acc, grip + along * t, grip + along * (t + 0.04), 0.042, brass, "DEF-hand.R")
		"gauntlet":
			blob(acc, grip - along * 0.02, Vector3(0.11, 0.13, 0.11), mat(GOLD, 0.7, 0.35), "DEF-hand.R")
			for t in [0.0, 0.05, 0.1]:
				limb(acc, grip - along * (0.12 + t), grip - along * (0.14 + t), 0.055, mat(Color(0.78, 0.42, 0.25), 0.7, 0.4), "DEF-hand.R")
			blob(acc, grip + along * 0.06, Vector3(0.06, 0.06, 0.06), mat(Color(0.5, 0.85, 1.0), 0.0, 0.3, 3.0), "DEF-hand.R")
		"pistol":
			limb(acc, grip - along * 0.02, grip + along * 0.22, 0.014, iron, "DEF-hand.R")
			cube(acc, grip, Vector3(0.03, 0.08, 0.05), wood, "DEF-hand.R")
		"crossbow":
			limb(acc, grip - along * 0.2, grip + along * 0.35, 0.02, wood, "DEF-hand.R")
			var across := along.cross(up).normalized()
			limb(acc, grip + along * 0.32 - across * 0.22, grip + along * 0.32 + across * 0.22, 0.012, mat(BONE), "DEF-hand.R")
