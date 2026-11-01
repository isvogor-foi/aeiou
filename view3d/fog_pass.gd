extends MeshInstance3D
## Full-screen fog-of-war pass (see shaders/fog.gdshader). Also owns the fog
## texture, which the minimap reuses.

const ALPHA_UNEXPLORED := 255
const ALPHA_EXPLORED := 135

var world
var player := 0
var tex: ImageTexture
var _image: Image
var _bytes := PackedByteArray()
var _version := -1


func setup(w, viewer: int) -> void:
	world = w
	player = viewer
	_image = Image.create(w.map.width, w.map.height, false, Image.FORMAT_RGBA8)
	tex = ImageTexture.create_from_image(_image)
	_bytes.resize(w.map.width * w.map.height * 4)
	_bytes.fill(0)
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	mesh = quad
	# Never culled: the vertex shader pins it to the screen.
	custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = load("res://view3d/shaders/fog.gdshader")
	mat.set_shader_parameter("fog_tex", tex)
	mat.set_shader_parameter("map_size", Vector2(w.map.width, w.map.height))
	mat.render_priority = 100
	material_override = mat
	sync()


func sync() -> void:
	if world.fog_version == _version:
		return
	_version = world.fog_version
	var vis: PackedByteArray = world.players[player].vis
	for i in vis.size():
		var v := vis[i]
		_bytes[i * 4 + 3] = ALPHA_UNEXPLORED if v == 0 else (ALPHA_EXPLORED if v == 1 else 0)
	_image.set_data(world.map.width, world.map.height, false, Image.FORMAT_RGBA8, _bytes)
	tex.update(_image)
