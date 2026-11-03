extends Node3D
## Short-lived 3D effects: spell bolts, melee sparks and click markers.

const DB = preload("res://sim/db.gd")

var terrain
var _fx: Array = []
var _bolt_mesh := SphereMesh.new()
var _ring_mesh := TorusMesh.new()
var _materials := {}


func _ready() -> void:
	_bolt_mesh.radius = 0.09
	_bolt_mesh.height = 0.18
	_bolt_mesh.radial_segments = 8
	_bolt_mesh.rings = 4
	_ring_mesh.inner_radius = 0.28
	_ring_mesh.outer_radius = 0.34
	_ring_mesh.rings = 24
	_ring_mesh.ring_segments = 4


func _glow(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = color
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 3.0
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_materials[key] = m
	return _materials[key]


func add_hit(ev: Dictionary) -> void:
	var col := DB.color_of(DB.damage.colors.get(ev.dtype, [1, 1, 1]))
	var from: Vector3 = terrain.to3(ev.from) + Vector3(0, 0.6, 0)
	var to: Vector3 = terrain.to3(ev.to) + Vector3(0, 0.5, 0)
	var mi := MeshInstance3D.new()
	mi.mesh = _bolt_mesh
	mi.material_override = _glow(col)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	if ev.ranged:
		mi.position = from
		_fx.append({"node": mi, "kind": "bolt", "from": from, "to": to, "t": 0.0, "ttl": 0.28})
	else:
		mi.position = to
		_fx.append({"node": mi, "kind": "spark", "t": 0.0, "ttl": 0.18})


## Visuals for a spell cast (see "vfx" in data/abilities.json).
func add_cast(ev: Dictionary) -> void:
	var col := DB.color_of(DB.visuals.spell_colors.get(ev.vfx, [0.8, 0.6, 1.0]))
	var from: Vector3 = terrain.to3(ev.from) + Vector3(0, 0.8, 0)
	var to: Vector3 = terrain.to3(ev.to) + Vector3(0, 0.5, 0)
	match ev.vfx:
		"fireball":
			_orb(from, to, col, 0.45, 0.22)
			_burst(to, col, float(ev.radius) / 32.0, 0.55, 0.4)
		"drain":
			# Life flows from the victim back to the caster.
			_orb(to, from, col, 0.35, 0.14)
		"heal", "shield":
			_burst(to, col, 0.6, 0.5, 0.0)
		"mass_shield", "summon":
			_burst(terrain.to3(ev.to) + Vector3(0, 0.1, 0), col, maxf(1.5, float(ev.radius) / 32.0), 0.7, 0.0)


func _orb(from: Vector3, to: Vector3, col: Color, ttl: float, size: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _bolt_mesh
	mi.material_override = _glow(col)
	mi.scale = Vector3.ONE * size / 0.09
	mi.position = from
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_fx.append({"node": mi, "kind": "bolt", "from": from, "to": to, "t": 0.0, "ttl": ttl})


## An expanding glowing ring (plus a flash when `delay` is 0 or after it).
func _burst(at: Vector3, col: Color, radius: float, ttl: float, delay: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _ring_mesh
	mi.material_override = _glow(col)
	mi.position = at
	mi.scale = Vector3.ZERO
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_fx.append({"node": mi, "kind": "burst", "radius": radius / 0.31, "t": -delay, "ttl": ttl})


## A lingering poison cloud (Plague Catapult).
func add_cloud(ev: Dictionary) -> void:
	var m := SphereMesh.new()
	var r: float = float(ev.radius) / 32.0
	m.radius = r
	m.height = r * 0.7
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = DB.color_of(ev.color) if ev.has("color") else Color(0.45, 0.85, 0.25, 0.3)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = terrain.to3(ev.pos) + Vector3(0, 0.15, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_fx.append({"node": mi, "kind": "cloud", "t": 0.0, "ttl": float(ev.duration)})


func add_marker(p: Vector3, color := Color(0.4, 1.0, 0.4)) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _ring_mesh
	mi.material_override = _glow(color)
	mi.position = p + Vector3(0, 0.05, 0)
	mi.scale = Vector3(1, 0.2, 1)
	add_child(mi)
	_fx.append({"node": mi, "kind": "marker", "t": 0.0, "ttl": 0.45})


func _process(delta: float) -> void:
	for fx in _fx:
		fx.t += delta
		var k: float = clampf(fx.t / fx.ttl, 0.0, 1.0)
		if fx.t < 0.0:
			fx.node.visible = false
			continue
		fx.node.visible = true
		var n: MeshInstance3D = fx.node
		match fx.kind:
			"bolt":
				var p: Vector3 = fx.from.lerp(fx.to, k)
				p.y += sin(k * PI) * 0.4
				n.position = p
			"spark":
				n.scale = Vector3.ONE * (1.0 + k * 2.0)
				n.transparency = k
			"marker":
				n.scale = Vector3(1.0 - k * 0.6, 0.2, 1.0 - k * 0.6)
				n.transparency = k
			"cloud":
				n.rotation.y += delta * 0.4
				n.transparency = clampf((k - 0.75) * 4.0, 0.0, 1.0)
			"burst":
				if fx.t < 0.0:
					continue
				var r: float = fx.radius * (0.3 + 0.7 * k)
				n.scale = Vector3(r, 0.6, r)
				n.transparency = k
	for fx in _fx.filter(func(f): return f.t >= f.ttl):
		fx.node.queue_free()
	_fx = _fx.filter(func(f): return f.t < f.ttl)
