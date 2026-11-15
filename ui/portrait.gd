extends SubViewportContainer
## Live 3D portrait of the selected entity in its own little world: a head-and-
## shoulders close-up of characters (playing their idle animation), or the whole
## model for buildings, beasts and machines, slowly turning.

const DB = preload("res://sim/db.gd")
const Entity = preload("res://sim/entity.gd")
const Models = preload("res://view3d/models.gd")

const SIZE := Vector2i(176, 176)

var _viewport: SubViewport
var _camera: Camera3D
var _stage: Node3D
var _model: Node3D
var _key := ""
var _spin := false


func _ready() -> void:
	stretch = true
	custom_minimum_size = Vector2(SIZE)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.size = SIZE
	_viewport.own_world_3d = true
	_viewport.transparent_bg = false
	_viewport.msaa_3d = Viewport.MSAA_4X
	add_child(_viewport)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.13, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.72, 0.68)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	_viewport.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, -35, 0)
	key.light_energy = 1.3
	_viewport.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 150, 0)
	rim.light_energy = 0.6
	rim.light_color = Color(1.0, 0.85, 0.6)
	_viewport.add_child(rim)
	_camera = Camera3D.new()
	_camera.fov = 30.0
	_viewport.add_child(_camera)
	_stage = Node3D.new()
	_viewport.add_child(_stage)
	visible = false


## Shows `e` (or hides the portrait for null). Rebuilds only when the type or owner changes.
func show_entity(e) -> void:
	if e == null:
		visible = false
		_key = ""
		return
	visible = true
	var key := "%s/%d/%s" % [e.type_id, e.owner, e.crown_land]
	if key == _key:
		return
	_key = key
	if _model:
		_model.queue_free()
	_spin = false
	match e.kind:
		Entity.UNIT:
			_model = Models.make_unit(e.type_id, e.owner)
			_model.scale = Vector3.ONE  # close-ups use the full-size model
			var v: Dictionary = DB.visuals.units.get(e.type_id, {})
			_stage.add_child(_model)
			# Characters face the camera; flyers' bodies sit at their flying height.
			_model.rotation.y = 0.0
			for c in _model.get_children():
				if c is Node3D and v.has("fly_height"):
					c.position.y = 0.0
			var ap := Models.anim_player(_model)
			var idle: String = Models.anims_of(v).get("idle", "")
			if ap and idle != "" and ap.has_animation(idle):
				ap.play(idle)
			if v.has("procedural") or not ap:
				_spin = true
				_frame_whole()
			elif v.has("figure"):
				# Realistic proportions: a small head at the top of a tall figure.
				var h := float(v.get("height", 1.0))
				var head := Vector3(0, h * 0.87, 0)
				_camera.position = head + Vector3(0, h * 0.02, h * 0.62)
				_camera.look_at(head, Vector3.UP)
			else:
				_frame_head(float(v.get("height", 1.0)))
		_:
			var table: Dictionary = DB.visuals.buildings if e.kind == Entity.BUILDING else DB.visuals.resources
			_model = Models.make_footprint_model(table.get(e.type_id, {"procedural": "crystal"}), e.owner, e.size.x, e.crown_land if e.kind == Entity.BUILDING else "")
			_stage.add_child(_model)
			_spin = true
			_frame_whole()


## KayKit heads are about the top 40% of the figure; leave room above for hats.
func _frame_head(height: float) -> void:
	var head := Vector3(0, height * 0.88, 0)
	_camera.position = head + Vector3(0, height * 0.04, height * 1.6)
	_camera.look_at(head, Vector3.UP)


func _frame_whole() -> void:
	var box := Models._bounds(_model, Transform3D.IDENTITY)
	var center := box.get_center()
	var radius := maxf(box.size.length() * 0.5, 0.3)
	_camera.position = center + Vector3(0, radius * 0.5, radius * 2.4)
	_camera.look_at(center, Vector3.UP)


func _process(delta: float) -> void:
	if visible and _spin and _model:
		_model.rotation.y += delta * 0.5
