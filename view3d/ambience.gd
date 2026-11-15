extends Node3D
## Atmosphere that follows the camera: drifting aether motes (glowing, slowly
## rising) and falling soot from the empire's chimneys, thickening as the ages
## industrialise (Age 7 on). Purely cosmetic.

const Graphics = preload("res://ui/graphics.gd")

var camera
var gv
var _motes: GPUParticles3D
var _ash: GPUParticles3D


func _ready() -> void:
	var level := Graphics.effective()
	if level == "low":
		return
	var many := level == "high"
	_motes = _make(160 if many else 80, 0.07, Color(0.45, 0.85, 1.0), 4.0, Vector3(0, 0.25, 0), 9.0)
	# Room for twice the soot of the early ages; amount_ratio dials it in by age.
	_ash = _make(520 if many else 240, 0.045, Color(0.16, 0.15, 0.15), 0.0, Vector3(0.15, -0.35, 0.05), 10.0)
	_ash.amount_ratio = 0.5
	add_child(_motes)
	add_child(_ash)


## `glow` > 0 makes the particle emissive (picked up by bloom).
func _make(amount: int, size: float, color: Color, glow: float, drift: Vector3, life: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.visibility_aabb = AABB(Vector3(-30, -5, -30), Vector3(60, 20, 60))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(22, 3, 22)
	pm.direction = drift.normalized() if drift.length() > 0.0 else Vector3.UP
	pm.spread = 35.0
	pm.initial_velocity_min = drift.length() * 0.5
	pm.initial_velocity_max = drift.length() * 1.5
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 4.0
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	# Fade in and out over each particle's life.
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.2, 1.0))
	curve.add_point(Vector2(0.8, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.alpha_curve = ct
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	quad.material = m
	p.draw_pass_1 = quad
	return p


func _process(_delta: float) -> void:
	if camera and _motes:
		global_position = camera.focus + Vector3(0, 1.5, 0)
	if gv and _ash:
		# Half the room until the Age of the Federation, then up to all of it by Age 12.
		var age: int = gv.world.players[gv.me].age
		_ash.amount_ratio = 0.5 + 0.5 * clampf((age - 6) / 6.0, 0.0, 1.0)
