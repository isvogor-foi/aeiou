extends Node3D
## 3D ground built from the GameMap: a gently rolling heightfield (cosmetic only;
## gameplay stays on the tile grid), lakes, scattered trees and rocks, territory
## borders and the placement footprint (both drawn by the terrain shader).
## One world unit = one tile.

const DB = preload("res://sim/db.gd")
const GameMap = preload("res://sim/game_map.gd")
const Models = preload("res://view3d/models.gd")
const Entity = preload("res://sim/entity.gd")

const WATER_LEVEL := -0.2
const _FOLIAGE := preload("res://view3d/shaders/foliage.gdshader")

var world
var map
## Corner heights, (width + 1) x (height + 1).
var heights := PackedFloat32Array()
var material: ShaderMaterial
var territory_tint_tex: ImageTexture

var _color_img: Image
var _color_tex: ImageTexture
var _territory_img: Image
var _territory_tex: ImageTexture
var _tint_img: Image
var _territory_version := -1
## Paving per tile (0..1): cobbles under and around buildings, kept in the
## colour texture's alpha.
var _pave := PackedFloat32Array()
## tile index -> [[MultiMesh, instance index], ...] for trees standing on that tile.
var _tree_instances := {}


func setup(w) -> void:
	world = w
	map = w.map
	_build_heights()
	_build_color_texture()
	_build_territory_textures()
	_build_mesh()
	_build_water()
	_scatter_nature()
	sync()


# --- Heights ------------------------------------------------------------------------

func _build_heights() -> void:
	heights = map.heights


func _corner(x: int, y: int) -> float:
	x = clampi(x, 0, map.width)
	y = clampi(y, 0, map.height)
	return heights[y * (map.width + 1) + x]


## Ground height at a point in tile coordinates (bilinear).
func height_at(tx: float, ty: float) -> float:
	var x0 := floori(tx)
	var y0 := floori(ty)
	var fx := tx - x0
	var fy := ty - y0
	var a := lerpf(_corner(x0, y0), _corner(x0 + 1, y0), fx)
	var b := lerpf(_corner(x0, y0 + 1), _corner(x0 + 1, y0 + 1), fx)
	return lerpf(a, b, fy)


## Sim pixel position -> 3D point on the ground.
func to3(px: Vector2) -> Vector3:
	var t := px / GameMap.TILE
	return Vector3(t.x, height_at(t.x, t.y), t.y)


static func to_px(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z) * GameMap.TILE


# --- Surface ------------------------------------------------------------------------

func _tile_color(t: Vector2i) -> Color:
	var ter: int = map.get_terrain(t)
	var v := float(absi((t.x * 73856093) ^ (t.y * 19349663)) % 100) / 100.0
	match ter:
		GameMap.WATER:
			return Color(0.26, 0.25, 0.22)
		GameMap.FOREST:
			return Color(0.15, 0.2, 0.12).lerp(Color(0.18, 0.23, 0.13), v)
		GameMap.ROCK:
			return Color(0.33, 0.32, 0.31).lerp(Color(0.38, 0.36, 0.34), v)
		GameMap.DIRT:
			return Color(0.3, 0.25, 0.19).lerp(Color(0.34, 0.28, 0.21), v)
	if _next_to_water(t):
		return Color(0.42, 0.38, 0.3)
	# Moss and sooty heath rather than a bright meadow.
	return Color(0.25, 0.31, 0.16).lerp(Color(0.3, 0.33, 0.18), v)


func _next_to_water(t: Vector2i) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if map.get_terrain(t + d) == GameMap.WATER and map.in_bounds(t + d):
			return true
	return false


func _build_color_texture() -> void:
	_color_img = Image.create(map.width, map.height, false, Image.FORMAT_RGBA8)
	_pave.resize(map.width * map.height)
	_pave.fill(0.0)
	for y in map.height:
		for x in map.width:
			_color_img.set_pixel(x, y, _tile_color(Vector2i(x, y)))
	_color_tex = ImageTexture.create_from_image(_color_img)


func _build_territory_textures() -> void:
	# One channel per nation (owner 0-3): 255 where it holds the tile. The shader
	# blurs these masks so borders come out as smooth curves, not tile steps.
	_territory_img = Image.create(map.width, map.height, false, Image.FORMAT_RGBA8)
	_territory_tex = ImageTexture.create_from_image(_territory_img)
	_tint_img = Image.create(map.width, map.height, false, Image.FORMAT_RGBA8)
	territory_tint_tex = ImageTexture.create_from_image(_tint_img)


func _build_mesh() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w: int = map.width
	var h: int = map.height
	for y in h + 1:
		for x in w + 1:
			st.set_uv(Vector2(x, y) / Vector2(w, h))
			st.add_vertex(Vector3(x, _corner(x, y), y))
	for y in h:
		for x in w:
			var i := y * (w + 1) + x
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + w + 1)
			st.add_index(i + 1)
			st.add_index(i + w + 2)
			st.add_index(i + w + 1)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	material = ShaderMaterial.new()
	material.shader = load("res://view3d/shaders/terrain.gdshader")
	material.set_shader_parameter("color_tex", _color_tex)
	material.set_shader_parameter("territory_tex", _territory_tex)
	material.set_shader_parameter("map_size", Vector2(w, h))
	var teams: Array[Color] = []
	for c in DB.rules.player_colors:
		teams.append(DB.color_of(c))
	for i in world.players.size():
		teams[i] = world.players[i].color
	material.set_shader_parameter("team_colors", teams)
	mi.material_override = material
	add_child(mi)


func _build_water() -> void:
	var plane := PlaneMesh.new()
	# Open sea all the way to the horizon around the map.
	plane.size = Vector2(map.width, map.height) + Vector2(800, 800)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.position = Vector3(map.width * 0.5, WATER_LEVEL, map.height * 0.5)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://view3d/shaders/water.gdshader")
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# --- Trees and rocks ----------------------------------------------------------------

func _scatter_nature() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4321
	var tree_spots: Array = []  # per variant: [[tile_index, Transform3D]]
	var rock_spots: Array = []
	for i in DB.visuals.trees.size():
		tree_spots.append([])
	for i in DB.visuals.rocks.size():
		rock_spots.append([])
	for y in map.height:
		for x in map.width:
			var t := Vector2i(x, y)
			var ter: int = map.get_terrain(t)
			if ter == GameMap.FOREST:
				for k in 1:
					var p := Vector2(x + rng.randf_range(0.3, 0.7), y + rng.randf_range(0.3, 0.7))
					var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.85, 1.2)),
							Vector3(p.x, height_at(p.x, p.y), p.y))
					tree_spots[rng.randi() % tree_spots.size()].append([map.idx(t), xf])
			elif ter == GameMap.ROCK:
				for k in rng.randi_range(1, 2):
					var p := Vector2(x + rng.randf_range(0.25, 0.75), y + rng.randf_range(0.25, 0.75))
					var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(2.2, 3.4)),
							Vector3(p.x, height_at(p.x, p.y) - 0.05, p.y))
					rock_spots[rng.randi() % rock_spots.size()].append([map.idx(t), xf])
			elif ter == GameMap.GRASS and rng.randf() < 0.015:
				var p := Vector2(x + rng.randf(), y + rng.randf())
				var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.3)),
						Vector3(p.x, height_at(p.x, p.y), p.y))
				rock_spots[rng.randi() % rock_spots.size()].append([map.idx(t), xf])
	for i in tree_spots.size():
		_multimesh(DB.visuals.trees[i], tree_spots[i], true)
	for i in rock_spots.size():
		_multimesh(DB.visuals.rocks[i], rock_spots[i], false)


## Size of the square chunks trees and rocks are batched into, so off-screen chunks
## are culled and distant ones fall back to the meshes' generated LODs.
const CHUNK := 16


## `spec` is a model path, or {model, height (tiles), rotate_x (deg), colors
## {surface-name fragment: [r, g, b]}} for imported nature that needs fitting.
func _multimesh(spec, spots: Array, track: bool) -> void:
	if spots.is_empty():
		return
	var d: Dictionary = spec if spec is Dictionary else {"model": spec}
	var path: String = d.model
	var fit := Transform3D.IDENTITY
	if d.has("rotate_x"):
		fit = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(float(d.rotate_x))), Vector3.ZERO)
	if d.has("height"):
		var box: AABB = fit * Models.aabb_of(path)
		fit = Transform3D(Basis().scaled(Vector3.ONE * float(d.height) / maxf(box.size.y, 0.01)), Vector3.ZERO) * fit
	var tinted: bool = d.has("colors")
	var chunks := {}
	for j in spots.size():
		var tile: int = spots[j][0]
		var key := Vector2i((tile % map.width) / CHUNK, (tile / map.width) / CHUNK)
		if not chunks.has(key):
			chunks[key] = []
		chunks[key].append(j)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(path)
	for part in Models.mesh_parts(path):
		var mesh: Mesh = _recolored(part.mesh, d.colors, float(d.get("height", 4.0))) if tinted else part.mesh
		for key in chunks:
			var ids: Array = chunks[key]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = tinted
			mm.mesh = mesh
			mm.instance_count = ids.size()
			for n in ids.size():
				var j: int = ids[n]
				mm.set_instance_transform(n, spots[j][1] * fit * part.xf)
				if tinted:
					# A little per-tree variation so forests aren't uniform.
					var v := rng.randf_range(0.82, 1.12)
					mm.set_instance_color(n, Color(v * rng.randf_range(0.95, 1.05), v, v * rng.randf_range(0.9, 1.0)))
				if track:
					var tkey: int = spots[j][0]
					if not _tree_instances.has(tkey):
						_tree_instances[tkey] = []
					_tree_instances[tkey].append([mm, n])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			add_child(mmi)


## A copy of `mesh` whose surfaces get the foliage shader by name ("Bark",
## "Leaves"), tinted per instance through the MultiMesh colour.
func _recolored(mesh: Mesh, colors: Dictionary, height: float) -> Mesh:
	var out: Mesh = mesh.duplicate()
	for i in out.get_surface_count():
		var old := out.surface_get_material(i)
		var name: String = old.resource_name if old else ""
		var m := ShaderMaterial.new()
		m.shader = _FOLIAGE
		m.set_shader_parameter("tree_height", height)
		m.set_shader_parameter("leafy", 0.0 if name.contains("Bark") or name.contains("Wood") else 1.0)
		for frag in colors:
			if name.contains(frag):
				m.set_shader_parameter("base_color", DB.color_of(colors[frag]))
		out.surface_set_material(i, m)
	return out


# --- Updates ------------------------------------------------------------------------

## Applies terrain changes (felled forests) from the sim.
func apply_changed_tiles(tiles: Array[Vector2i]) -> void:
	for t in tiles:
		var col := _tile_color(t)
		col.a = _pave[int(map.idx(t))]
		_color_img.set_pixelv(t, col)
		if map.get_terrain(t) != GameMap.FOREST:
			for inst in _tree_instances.get(map.idx(t), []):
				inst[0].set_instance_transform(inst[1], Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
			_tree_instances.erase(map.idx(t))
	if not tiles.is_empty():
		_color_tex.update(_color_img)


func sync() -> void:
	if world.territory.version == _territory_version:
		return
	_territory_version = world.territory.version
	var terr = world.territory
	for y in map.height:
		for x in map.width:
			var o: int = terr.owner_at(Vector2i(x, y))
			var mask := Color(0, 0, 0, 0)
			if o >= 0 and o < 4:
				mask[o] = 1.0
			_territory_img.set_pixel(x, y, mask)
			_tint_img.set_pixel(x, y, Color(world.players[o].color, 0.35) if o >= 0 else Color(0, 0, 0, 0))
	_territory_tex.update(_territory_img)
	territory_tint_tex.update(_tint_img)
	_update_paving()


## Cobbles under every building, fading out over a couple of tiles around it.
## Territory is rebuilt whenever buildings appear or fall, so this follows it.
func _update_paving() -> void:
	_pave.fill(0.0)
	for e in world.entities.values():
		if e.kind != Entity.BUILDING or not e.alive or e.def.get("water", false):
			continue
		var r: Rect2 = Rect2(Vector2(e.tile), Vector2(e.size))
		var reach := 1.6 + minf(e.size.x, 4) * 0.35
		var c := r.get_center()
		for y in range(floori(r.position.y - reach), ceili(r.end.y + reach)):
			for x in range(floori(r.position.x - reach), ceili(r.end.x + reach)):
				var t := Vector2i(x, y)
				if not map.in_bounds(t) or map.get_terrain(t) == GameMap.WATER:
					continue
				# Distance from the tile centre to the building's footprint.
				var p := Vector2(x + 0.5, y + 0.5)
				var d := Vector2(maxf(absf(p.x - c.x) - r.size.x * 0.5, 0.0), maxf(absf(p.y - c.y) - r.size.y * 0.5, 0.0)).length()
				var v := clampf(1.0 - d / reach, 0.0, 1.0)
				var i: int = map.idx(t)
				_pave[i] = maxf(_pave[i], v)
	for y in map.height:
		for x in map.width:
			var col := _color_img.get_pixel(x, y)
			col.a = _pave[y * map.width + x]
			_color_img.set_pixel(x, y, col)
	_color_tex.update(_color_img)


## Shows the building footprint under the cursor (tiles), or hides it when `size` is 0.
func show_placement(top_left: Vector2i, size: int, ok: bool) -> void:
	if size <= 0:
		material.set_shader_parameter("placement_color", Color(0, 0, 0, 0))
		return
	material.set_shader_parameter("placement_rect", Vector4(top_left.x, top_left.y, size, size))
	material.set_shader_parameter("placement_color", Color(0.3, 1.0, 0.35, 0.6) if ok else Color(1.0, 0.25, 0.2, 0.6))
