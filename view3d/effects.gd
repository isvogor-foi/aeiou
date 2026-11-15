extends Node3D
## Short-lived 3D effects: spell bolts, melee sparks and click markers; for the
## modern ages, tracer bursts, shells, rockets, flame, flak and explosions (chosen
## by the firing unit's visuals.json "shot"), and the Aether bomb with its scar.

const DB = preload("res://sim/db.gd")

var terrain
var _fx: Array = []
var _bolt_mesh := SphereMesh.new()
var _ring_mesh := TorusMesh.new()
var _materials := {}
var _puff_mesh := SphereMesh.new()
## Aether-bomb scars stay for the rest of the match (view only; not saved).
var _scars: Array = []


func _ready() -> void:
	_bolt_mesh.radius = 0.09
	_bolt_mesh.height = 0.18
	_bolt_mesh.radial_segments = 8
	_bolt_mesh.rings = 4
	_ring_mesh.inner_radius = 0.28
	_ring_mesh.outer_radius = 0.34
	_ring_mesh.rings = 24
	_ring_mesh.ring_segments = 4
	_puff_mesh.radius = 0.5
	_puff_mesh.height = 1.0
	_puff_mesh.radial_segments = 10
	_puff_mesh.rings = 5


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
	var v: Dictionary = DB.visuals.units.get(ev.get("unit", ""), {})
	if ev.ranged and v.has("shot"):
		_shot(String(v.shot), v, from, to, col)
		return
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


## Modern weapon fire by style: "burst" (tracers; visuals "burst" = rounds),
## "shell" (a fast tracer and a blast), "rocket" (a smoking rocket and a blast),
## "flame" (a short cone of fire), "flak" (black puffs at the target).
func _shot(style: String, v: Dictionary, from: Vector3, to: Vector3, col: Color) -> void:
	var tracer := Color(1.0, 0.85, 0.45)
	match style:
		"burst":
			for i in int(v.get("burst", 4)):
				var jitter := Vector3(randf_range(-0.12, 0.12), randf_range(-0.05, 0.1), randf_range(-0.12, 0.12))
				_tracer(from, to + jitter, tracer, 0.12, i * 0.07)
			_burst(from, tracer, 0.12, 0.1, 0.0)
		"shell":
			_tracer(from, to, tracer, 0.15, 0.0, 1.6)
			explosion(to, 0.45, 0.15)
		"rocket":
			_orb(from, to, Color(1.0, 0.6, 0.25), 0.45, 0.08)
			for i in 6:
				var p: Vector3 = from.lerp(to, i / 6.0) + Vector3(0, sin(i / 6.0 * PI) * 0.4, 0)
				_puff(p, Color(0.6, 0.6, 0.58, 0.55), 0.12, 1.0, i * 0.07, 0.15)
			explosion(to, 0.6, 0.45)
		"flame":
			for i in 5:
				_orb(from, from.lerp(to, randf_range(0.7, 1.0)) + Vector3(randf_range(-0.15, 0.15), 0, randf_range(-0.15, 0.15)),
						Color(1.0, 0.5 + i * 0.06, 0.15), 0.25, 0.1 + i * 0.02)
		"flak":
			for i in 3:
				var at := to + Vector3(randf_range(-0.4, 0.4), randf_range(-0.2, 0.3), randf_range(-0.4, 0.4))
				_puff(at, Color(0.08, 0.08, 0.08, 0.8), 0.25, 0.9, i * 0.1, 0.0)
				_burst(at, Color(1.0, 0.6, 0.2), 0.15, 0.12, i * 0.1)
		_:
			_orb(from, to, col, 0.28, 0.09)


## A streak of light flying from `from` to `to` (stretched along its path).
func _tracer(from: Vector3, to: Vector3, col: Color, ttl: float, delay: float, thick := 1.0) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _bolt_mesh
	mi.material_override = _glow(col)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var dir := (to - from).normalized()
	if dir.length_squared() > 0.0001 and absf(dir.dot(Vector3.UP)) < 0.999:
		# Stretched along its own forward axis (local scale, after the rotation).
		mi.basis = Basis.looking_at(dir) * Basis.from_scale(Vector3(0.35, 0.35, 2.6) * thick)
	mi.position = from
	_fx.append({"node": mi, "kind": "tracer", "from": from, "to": to, "t": -delay, "ttl": ttl})


## A shell or grenade bursting at `at`: a flash, a shock ring and rising smoke.
func explosion(at: Vector3, size: float, delay := 0.0) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _puff_mesh
	mi.material_override = _glow(Color(1.0, 0.62, 0.22))
	mi.position = at
	mi.scale = Vector3.ZERO
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_fx.append({"node": mi, "kind": "flash", "size": size, "t": -delay, "ttl": 0.3})
	_burst(at - Vector3(0, 0.4, 0), Color(1.0, 0.8, 0.5), size * 1.6, 0.4, delay)
	for i in 4:
		_puff(at + Vector3(randf_range(-0.2, 0.2), 0.0, randf_range(-0.2, 0.2)) * size * 2.0, Color(0.22, 0.2, 0.19, 0.7),
				size * randf_range(1.0, 1.5), randf_range(1.2, 1.8), delay + 0.08, 0.6)


## A soft smoke puff that grows, rises by `rise` and fades.
func _puff(at: Vector3, col: Color, size: float, ttl: float, delay: float, rise: float) -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mi := MeshInstance3D.new()
	mi.mesh = _puff_mesh
	mi.material_override = m
	mi.position = at
	mi.scale = Vector3.ONE * size * 0.5
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_fx.append({"node": mi, "kind": "puff", "from": at, "size": size, "rise": rise, "t": -delay, "ttl": ttl})


## The Aether bomb (event "bomb": pos, radius in px): a blinding flash, two shock
## rings, a rising column with a cap, and a glowing scar left on the ground.
func add_bomb(ev: Dictionary) -> void:
	var at: Vector3 = terrain.to3(ev.pos)
	var r: float = float(ev.get("radius", 192.0)) / 32.0
	var mi := MeshInstance3D.new()
	mi.mesh = _puff_mesh
	mi.material_override = _glow(Color(0.85, 0.97, 1.0))
	mi.position = at + Vector3(0, 0.5, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_fx.append({"node": mi, "kind": "flash", "size": r * 1.2, "t": 0.0, "ttl": 1.2})
	_burst(at + Vector3(0, 0.1, 0), Color(0.5, 0.9, 1.0), r * 1.6, 1.4, 0.0)
	_burst(at + Vector3(0, 0.1, 0), Color(1.0, 1.0, 1.0), r * 2.4, 2.2, 0.3)
	for i in 8:
		_puff(at + Vector3(0, 0.3 + i * 0.35, 0), Color(0.42, 0.45, 0.47, 0.85), r * 0.35 + i * 0.03, 6.0, 0.2 + i * 0.12, 0.6)
	for i in 6:
		var a := TAU * i / 6.0
		_puff(at + Vector3(cos(a) * r * 0.3, 3.2, sin(a) * r * 0.3), Color(0.4, 0.43, 0.46, 0.85), r * 0.55, 7.0, 1.1, 0.8)
	# The scar is a decal, so it lies on the ground however the terrain rolls:
	# charred in the middle, a cooling Aether glow at the rim.
	var scar := Decal.new()
	scar.size = Vector3(r * 1.7, 4.0, r * 1.7)
	scar.position = at
	scar.texture_albedo = _scar_texture(false)
	scar.texture_emission = _scar_texture(true)
	scar.emission_energy = 3.0
	scar.upper_fade = 0.3
	scar.lower_fade = 0.3
	add_child(scar)
	_scars.append({"node": scar, "t": 0.0})


var _scar_tex := {}


## Radial textures for the bomb scar: soot that fades out at the edge (albedo), or
## a glowing ring near the rim (emission).
func _scar_texture(glow: bool) -> Texture2D:
	if _scar_tex.has(glow):
		return _scar_tex[glow]
	var g := Gradient.new()
	if glow:
		g.set_color(0, Color(0.0, 0.0, 0.0, 0.0))
		g.set_color(1, Color(0.0, 0.0, 0.0, 0.0))
		g.add_point(0.55, Color(0.05, 0.12, 0.15, 1.0))
		g.add_point(0.8, Color(0.35, 0.85, 1.0, 1.0))
		g.add_point(0.92, Color(0.05, 0.15, 0.2, 1.0))
	else:
		g.set_color(0, Color(0.03, 0.03, 0.03, 0.95))
		g.set_color(1, Color(0.1, 0.09, 0.08, 0.0))
		g.add_point(0.7, Color(0.08, 0.08, 0.07, 0.8))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	_scar_tex[glow] = t
	return t


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
			"tracer":
				n.position = fx.from.lerp(fx.to, k)
			"flash":
				n.scale = Vector3.ONE * fx.size * (0.4 + 1.2 * k)
				n.transparency = k * k
			"puff":
				n.scale = Vector3.ONE * fx.size * (0.5 + 0.8 * k)
				n.position = fx.from + Vector3(0, fx.rise * k, 0)
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
	# Bomb scars cool from white-hot to a faint lasting glow.
	for sc in _scars:
		sc.t += delta
		sc.node.emission_energy = 0.5 + 2.5 * exp(-sc.t * 0.3)
	for fx in _fx.filter(func(f): return f.t >= f.ttl):
		fx.node.queue_free()
	_fx = _fx.filter(func(f): return f.t < f.ttl)
