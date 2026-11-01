extends SubViewport
## Renders small 3D icons of buildings and units for the command card, one per
## frame in a hidden viewport, and caches them. Ask with icon(); it returns null
## until the icon is ready, so callers just ask again on a later frame.

const DB = preload("res://sim/db.gd")
const Models = preload("res://view3d/models.gd")

const ICON_SIZE := Vector2i(112, 80)

var _cache := {}
var _queued := {}
var _queue: Array = []
var _busy := false
var _camera: Camera3D
var _stage: Node3D


func _ready() -> void:
	size = ICON_SIZE
	own_world_3d = true
	transparent_bg = true
	msaa_3d = Viewport.MSAA_4X
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.78, 0.74)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.light_energy = 1.3
	add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = 30.0
	add_child(_camera)
	_stage = Node3D.new()
	add_child(_stage)


## Icon for a "building" or "unit" type as owned by `owner`, or null while it renders.
func icon(kind: String, type_id: String, owner: int) -> Texture2D:
	var key := "%s/%s/%d" % [kind, type_id, owner]
	if _cache.has(key):
		return _cache[key]
	if not _queued.has(key):
		_queued[key] = true
		_queue.append([key, kind, type_id, owner])
	return null


func _process(_delta: float) -> void:
	if not _busy and not _queue.is_empty():
		_render(_queue.pop_front())


func _render(job: Array) -> void:
	_busy = true
	var key: String = job[0]
	var model: Node3D
	if job[1] == "unit":
		model = Models.make_unit(job[2], job[3])
	else:
		var size := int(DB.buildings[job[2]].size)
		model = Models.make_footprint_model(DB.visuals.buildings.get(job[2], {}), job[3], size)
	_stage.add_child(model)
	model.rotation.y = -0.5
	var ap := Models.anim_player(model)
	var v: Dictionary = DB.visuals.units.get(job[2], {}) if job[1] == "unit" else {}
	var idle: String = v.get("anims", {}).get("idle", "")
	if ap and idle != "" and ap.has_animation(idle):
		# A natural pose instead of the rest (T) pose.
		ap.play(idle)
		ap.seek(0.4, true)
	_frame(model, job[1] == "unit" and ap != null, float(v.get("height", 1.0)))
	# Two drawn frames make sure the new model is in the image.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_cache[key] = ImageTexture.create_from_image(get_texture().get_image())
	model.queue_free()
	_busy = false


## Characters: head and shoulders. Everything else: the whole model in 3/4 view.
func _frame(model: Node3D, character: bool, height: float) -> void:
	if character:
		var head := Vector3(0, height * 0.82, 0)
		_camera.position = head + Vector3(0, height * 0.06, height * 1.45)
		_camera.look_at(head, Vector3.UP)
		return
	var box := Models._bounds(model, Transform3D.IDENTITY)
	var center := box.get_center()
	var radius := maxf(box.size.length() * 0.5, 0.3)
	_camera.position = center + Vector3(radius * 0.75, radius * 0.9, radius * 1.6)
	_camera.look_at(center, Vector3.UP)
