extends RefCounted
## Builds 3D models for entity types from data/visuals.json: loads and caches
## scenes, scales them to tiles, hides unused equipment, attaches weapons, tints.

const Figure = preload("res://view3d/figure.gd")
const DB = preload("res://sim/db.gd")
const Procedural = preload("res://view3d/procedural.gd")

static var _scenes := {}
static var _aabbs := {}
static var _tinted := {}
static var _retextured := {}
## Per player: KayKit team-colour name and team colour (set by the game view).
static var team_names: Array = []
static var team_colors: Array = []
static var team_factions: Array = []


static func scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	return _scenes[path]


static func team_name(owner: int) -> String:
	if owner >= 0 and owner < team_names.size():
		return team_names[owner]
	var names: Array = DB.visuals.team_colors
	return names[owner] if owner >= 0 and owner < names.size() else "blue"


static func team_color(owner: int) -> Color:
	if owner >= 0 and owner < team_colors.size():
		return team_colors[owner]
	return DB.color_of(DB.rules.player_colors[maxi(owner, 0)])


static func set_teams(players: Array) -> void:
	team_names = players.map(func(p): return DB.factions[p.faction].get("team_model", "blue"))
	team_colors = players.map(func(p): return p.color)
	team_factions = players.map(func(p): return p.faction)


static func resolve(path: String, owner: int) -> String:
	return path.replace("{team}", team_name(owner))


## Bounds of a scene's meshes in its own root space (cached per path).
static func aabb_of(path: String) -> AABB:
	if not _aabbs.has(path):
		var inst := scene(path).instantiate()
		_aabbs[path] = _bounds(inst, Transform3D.IDENTITY)
		inst.free()
	return _aabbs[path]


static func _bounds(n: Node, xf: Transform3D) -> AABB:
	var here: Transform3D = xf * (n.transform if n is Node3D else Transform3D.IDENTITY)
	var out := AABB()
	var first := true
	if n is MeshInstance3D and n.mesh:
		out = here * n.get_aabb()
		first = false
	for c in n.get_children():
		var a := _bounds(c, here)
		if a.size != Vector3.ZERO:
			out = a if first else out.merge(a)
			first = false
	return out


## A unit model scaled to its data height, with equipment and animations prepared.
## People and wagons are drawn at this fraction of their data height, so the
## buildings dominate the map. Ships and flyers keep their size.
const GROUND_UNIT_SCALE := 0.75


static func unit_scale(type_id: String) -> float:
	var d: Dictionary = DB.units.get(type_id, {})
	return GROUND_UNIT_SCALE if d.get("domain", "ground") == "ground" else 1.0


static func make_unit(type_id: String, owner: int) -> Node3D:
	var v: Dictionary = DB.visuals.units.get(type_id, {})
	var root := Node3D.new()
	root.scale = Vector3.ONE * unit_scale(type_id)
	if v.is_empty():
		return root
	if v.has("procedural"):
		var built := Procedural.build(v.procedural, team_color(owner))
		built.scale = Vector3.ONE * float(v.get("scale", 1.0))
		root.add_child(built)
		return root
	var model: Node3D
	var s: float
	if v.has("figure"):
		# A realistic figure dressed in code (view3d/figure.gd).
		model = Figure.build(v.figure, team_color(owner))
		s = float(v.height) / Figure.HEIGHT
	else:
		var path := resolve(v.model, owner)
		model = scene(path).instantiate() as Node3D
		var box := aabb_of(path)
		s = float(v.height) / maxf(box.size.y, 0.01)
	model.scale = Vector3.ONE * s
	root.add_child(model)
	if v.has("mount"):
		# Riders sit on a procedural horse.
		root.add_child(Procedural.build(v.mount, team_color(owner)))
		model.position.y = float(v.get("saddle", 0.75))
	for part in v.get("hide", []):
		var n := model.find_child(part, true, false)
		if n:
			n.visible = false
	if v.has("texture"):
		retexture(model, v.texture)
	var attach: Dictionary = v.get("attach", {})
	if not attach.is_empty():
		var skel := _find_skeleton(model)
		for bone in attach:
			if skel and skel.find_bone(bone) >= 0:
				var ba := BoneAttachment3D.new()
				ba.bone_name = bone
				skel.add_child(ba)
				# One spec or a list of them (e.g. a hat and goggles on the head).
				var specs: Array = attach[bone] if attach[bone] is Array else [attach[bone]]
				for spec in specs:
					ba.add_child(_attachment(spec))
	for prop in v.get("props", []):
		root.add_child(Procedural.build(prop, Color.WHITE))
	for extra in v.get("extra", []):
		var x := scene(extra.model).instantiate() as Node3D
		x.position = Vector3(extra.offset[0], extra.offset[1], extra.offset[2])
		x.scale = Vector3.ONE * float(extra.get("scale", 1.0)) * s
		root.add_child(x)
	if v.has("tint"):
		tint(model, DB.color_of(v.tint))
	_prepare_anims(model, v.get("anims", {}))
	return root


## An attachment spec: a scene path, "proc:<kind>", or {proc|model, offset, rotation (deg), scale}.
static func _attachment(spec) -> Node3D:
	var d: Dictionary = spec if spec is Dictionary else {"model": spec}
	var src: String = d.get("model", "")
	if src.begins_with("proc:"):
		d.proc = src.substr(5)
	var n: Node3D = Procedural.build(d.proc, Color.WHITE) if d.has("proc") else scene(src).instantiate()
	if d.has("offset"):
		n.position = Vector3(d.offset[0], d.offset[1], d.offset[2])
	if d.has("rotation"):
		n.rotation_degrees = Vector3(d.rotation[0], d.rotation[1], d.rotation[2])
	n.scale = Vector3.ONE * float(d.get("scale", 1.0))
	return n


## Swaps the albedo texture of every textured surface (e.g. recoloured uniforms).
static func retexture(n: Node, path: String) -> void:
	if n is MeshInstance3D and n.mesh:
		for i in n.mesh.get_surface_count():
			var mat: Material = n.get_active_material(i)
			if mat is StandardMaterial3D and mat.albedo_texture:
				var key := [mat.get_instance_id(), path]
				if not _retextured.has(key):
					var m := mat.duplicate() as StandardMaterial3D
					m.albedo_texture = load(path)
					_retextured[key] = m
				n.set_surface_override_material(i, _retextured[key])
	for c in n.get_children():
		retexture(c, path)


static func _find_skeleton(n: Node) -> Skeleton3D:
	var found := n.find_children("*", "Skeleton3D", true, false)
	return found[0] if not found.is_empty() else null


static func _prepare_anims(model: Node, anims: Dictionary) -> void:
	var ap := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null:
		return
	for key in ["idle", "walk", "work"]:
		var name: String = anims.get(key, "")
		if name != "" and ap.has_animation(name):
			ap.get_animation(name).loop_mode = Animation.LOOP_LINEAR


static func anim_player(root: Node) -> AnimationPlayer:
	return root.find_child("AnimationPlayer", true, false) as AnimationPlayer


## A building or resource model scaled to fit `tiles` x `tiles`, origin at the footprint centre.
static func make_footprint_model(v: Dictionary, owner: int, tiles: int) -> Node3D:
	var root := Node3D.new()
	if v.get("procedural", "") == "crystal":
		root.add_child(_crystal(DB.color_of(v.get("color", [0.5, 0.8, 1.0]))))
		return root
	if v.has("procedural"):
		root.add_child(Procedural.build(v.procedural, team_color(owner)))
		return root
	var path := resolve(v.model, owner)
	var model := scene(path).instantiate() as Node3D
	var box := aabb_of(path)
	var span := maxf(box.size.x, box.size.z)
	var s := float(tiles) * float(v.get("fit", 0.9)) / maxf(span, 0.01)
	# Tall models (castles) are capped so they don't tower over the map.
	var max_height := float(v.get("max_height", tiles * 1.2))
	s = minf(s, max_height / maxf(box.size.y, 0.01))
	model.scale = Vector3.ONE * s
	model.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z) * s
	root.add_child(model)
	for prop in v.get("props", []):
		var n := Procedural.build(prop.proc, team_color(owner))
		n.position = Vector3(prop.offset[0], prop.offset[1], prop.offset[2])
		root.add_child(n)
	if v.has("tint"):
		tint(model, DB.color_of(v.tint))
	elif v.has("faction_tint") and owner >= 0 and owner < team_factions.size() and v.faction_tint.has(team_factions[owner]):
		tint(model, DB.color_of(v.faction_tint[team_factions[owner]]))
	return root


## Multiplies the albedo of every surface under `n` (materials are duplicated once per colour).
static func tint(n: Node, color: Color) -> void:
	if n is MeshInstance3D and n.mesh:
		for i in n.mesh.get_surface_count():
			var mat: Material = n.get_active_material(i)
			if mat is StandardMaterial3D:
				var key := [mat.get_instance_id(), color]
				if not _tinted.has(key):
					var m := mat.duplicate() as StandardMaterial3D
					m.albedo_color = m.albedo_color * color
					_tinted[key] = m
				n.set_surface_override_material(i, _tinted[key])
	for c in n.get_children():
		tint(c, color)


## Replaces every surface's material (e.g. the placement ghost).
static func override_material(n: Node, mat: Material) -> void:
	if n is GeometryInstance3D:
		n.material_override = mat
	for c in n.get_children():
		override_material(c, mat)


## All (mesh, transform) pairs in a scene, for MultiMesh scattering.
static func mesh_parts(path: String) -> Array:
	var inst := scene(path).instantiate()
	var out: Array = []
	_collect_parts(inst, Transform3D.IDENTITY, out)
	inst.free()
	return out


static func _collect_parts(n: Node, xf: Transform3D, out: Array) -> void:
	var here: Transform3D = xf * (n.transform if n is Node3D else Transform3D.IDENTITY)
	if n is MeshInstance3D and n.mesh:
		out.append({"mesh": n.mesh, "xf": here})
	for c in n.get_children():
		_collect_parts(c, here, out)


static func _crystal(color: Color) -> Node3D:
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.lightened(0.2)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.2
	mat.roughness = 0.2
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.85
	var spikes := [[0.0, 0.0, 1.5, 0.3, 0.0], [0.35, 0.15, 0.9, 0.18, 0.4], [-0.3, 0.25, 0.8, 0.16, -0.35], [0.1, -0.35, 0.7, 0.15, 0.3]]
	for s in spikes:
		var m := CylinderMesh.new()
		m.top_radius = 0.0
		m.bottom_radius = s[3]
		m.height = s[2]
		m.radial_segments = 6
		m.rings = 1
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = mat
		mi.position = Vector3(s[0], s[2] * 0.5 - 0.1, s[1])
		mi.rotation = Vector3(s[4], 0.0, s[4] * 0.5)
		root.add_child(mi)
	var base := CylinderMesh.new()
	base.top_radius = 0.75
	base.bottom_radius = 0.9
	base.height = 0.15
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.32, 0.33, 0.38)
	var bi := MeshInstance3D.new()
	bi.mesh = base
	bi.material_override = bmat
	root.add_child(bi)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.6
	light.omni_range = 3.5
	light.position = Vector3(0, 1.0, 0)
	root.add_child(light)
	root.set_meta("spin", true)
	return root
