extends Node3D
## One 3D view per sim entity: positions (interpolated between ticks), facing,
## animations, construction, team and selection rings, deaths and rubble.

const Prof = preload("res://sim/prof.gd")
const DB = preload("res://sim/db.gd")
const Entity = preload("res://sim/entity.gd")
const GameMap = preload("res://sim/game_map.gd")
const Models = preload("res://view3d/models.gd")
const Flags = preload("res://view3d/flags.gd")

const TURN_SPEED := 12.0
const ATTACK_ANIM_TIME := 0.7
const DEATH_TIME := 2.4
const RUBBLE_TIME := 6.0

var gv
var terrain
## id -> record (see _create)
var views := {}
var _dying: Array = []
var _ring_mesh := TorusMesh.new()
var _thin_ring_mesh := TorusMesh.new()
var _ring_materials := {}


func _ready() -> void:
	_ring_mesh.inner_radius = 0.9
	_ring_mesh.outer_radius = 1.0
	_ring_mesh.rings = 32
	_ring_mesh.ring_segments = 4
	_thin_ring_mesh.inner_radius = 0.96
	_thin_ring_mesh.outer_radius = 1.0
	_thin_ring_mesh.rings = 48
	_thin_ring_mesh.ring_segments = 4


func _ring_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _ring_materials.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = color
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		# Rings stay visible over terrain bumps and under bodies.
		m.no_depth_test = true
		m.render_priority = 1
		_ring_materials[key] = m
	return _ring_materials[key]


func _ring(radius: float, color: Color, thin := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _thin_ring_mesh if thin else _ring_mesh
	mi.material_override = _ring_material(color)
	mi.scale = Vector3(radius, 0.05, radius)
	mi.position.y = 0.04
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _create(e) -> Dictionary:
	var node := Node3D.new()
	add_child(node)
	var r := {"node": node, "owner": e.owner, "type_id": e.type_id, "kind": e.kind, "yaw": 0.0,
			"attack_until": 0.0, "anim": "", "ap": null, "anims": {}, "scaffold": null, "bar_height": 1.0,
			"fly": 0.0, "naval": false, "animated": []}
	match e.kind:
		Entity.UNIT:
			var v: Dictionary = DB.visuals.units.get(e.type_id, {})
			var body := Models.make_unit(e.type_id, e.owner)
			# Units use their blob shadow; real shadows for hundreds of soldiers cost
			# several extra draws each in the sun's shadow maps.
			_no_shadows(body)
			node.add_child(body)
			r.body = body
			r.ap = Models.anim_player(body)
			if r.ap:
				# Advanced by hand in sync(): only on screen, and less often in big battles.
				r.ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			r.anim_acc = 0.0
			r.anims = v.get("anims", {})
			r.fly = float(v.get("fly_height", 0.0))
			r.naval = v.get("naval", false)
			r.bar_height = float(v.get("height", 0.9)) + 0.25 + r.fly
			r.animated = _animated_parts(body)
			if r.fly > 0.0:
				body.position.y = r.fly
				node.add_child(_shadow())
			var team: Color = gv.world.players[e.owner].color
			node.add_child(_ring(0.32, Color(team, 0.75)))
			if e.is_hero():
				node.add_child(_ring(0.55, Color(1.0, 0.82, 0.3, 0.9)))
			r.shield = _shield_bubble(r.bar_height)
			node.add_child(r.shield)
			r.sel = _ring(0.42, Color(0.35, 1.0, 0.35, 0.95))
			node.add_child(r.sel)
			r.yaw = atan2(e.facing.x, e.facing.y)
			_play(r, "idle")
		Entity.BUILDING, Entity.RESOURCE:
			var table: Dictionary = DB.visuals.buildings if e.kind == Entity.BUILDING else DB.visuals.resources
			var body := Models.make_footprint_model(table.get(e.type_id, {"procedural": "crystal"}), e.owner, e.size.x)
			node.add_child(body)
			r.body = body
			var box := Models._bounds(body, Transform3D.IDENTITY)
			r.bar_height = box.end.y + 0.3
			r.animated = _animated_parts(body)
			var base := _footprint_base(e, table.get(e.type_id, {}).get("base", "min") == "max")
			if table.get(e.type_id, {}).get("naval", false):
				base = terrain.WATER_LEVEL
			node.position = Vector3(e.pos.x / GameMap.TILE, base, e.pos.y / GameMap.TILE)
			r.sel = _ring(e.size.x * 0.72, Color(0.35, 1.0, 0.35, 0.95), true)
			node.add_child(r.sel)
			if e.kind == Entity.BUILDING and e.owner >= 0:
				var fkind: String = DB.factions[gv.world.players[e.owner].faction].get("flag", "")
				if fkind != "":
					var big: bool = gv.world.is_city(e)
					var flag := Flags.make(fkind, r.bar_height * 0.85 + (0.9 if big else 0.4), 0.95 if big else 0.6)
					flag.position = Vector3(-e.size.x * 0.42, 0, e.size.y * 0.42)
					node.add_child(flag)
			if e.kind == Entity.BUILDING and e.constructing:
				var scaffold := Models.make_footprint_model({"model": DB.visuals.scaffolding, "fit": 1.0}, e.owner, e.size.x)
				node.add_child(scaffold)
				r.scaffold = scaffold
	return r


## Lowest ground height under a footprint, so buildings never float (or the
## highest, for piers that should stand clear of the slope down to the water).
func _no_shadows(n: Node) -> void:
	if n is GeometryInstance3D:
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_no_shadows(c)


func _footprint_base(e, highest := false) -> float:
	var out := -INF if highest else INF
	for y in e.size.y + 1:
		for x in e.size.x + 1:
			var h: float = terrain.height_at(e.tile.x + x, e.tile.y + y)
			out = maxf(out, h) if highest else minf(out, h)
	return out


## Skeletal animation is the view's biggest cost with hundreds of soldiers: units
## off screen don't animate at all, and with many on screen they update at 20 Hz.
const ANIM_STEP_CROWD := 1.0 / 20.0
const CROWD := 120


func sync(alpha: float, delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var seen := {}
	var cam: Camera3D = gv.camera
	var anim_step := ANIM_STEP_CROWD if _unit_views >= CROWD else 0.0
	var units := 0
	for e in gv.world.entities.values():
		if not e.alive:
			continue
		seen[e.id] = true
		var r = views.get(e.id)
		if r == null or r.owner != e.owner or r.type_id != e.type_id:
			if r != null:
				r.node.queue_free()
			r = _create(e)
			views[e.id] = r
		var shown: bool = gv.is_shown(e)
		r.node.visible = shown
		if not shown:
			continue
		r.sel.visible = gv.is_selected(e.id)
		match e.kind:
			Entity.UNIT:
				units += 1
				r.deployed = e.deployed
				var pt := Prof.start()
				_sync_unit(e, r, alpha, delta, now)
				Prof.stop("v_sync_unit", pt)
				pt = Prof.start()
				_advance_anim(r, delta, anim_step, cam)
				Prof.stop("v_anim", pt)
				r.shield.visible = not e.effects.is_empty() and e.effects.any(func(fx): return fx.type == "shield")
				if e.expires_tick > 0:
					# Summons flicker as their time runs out.
					var left: int = e.expires_tick - gv.world.tick_count
					r.body.visible = left > 60 or (left / 4) % 2 == 0
			Entity.BUILDING:
				_sync_building(e, r)
			Entity.RESOURCE:
				if r.body.get_child_count() > 0 and r.body.get_child(0).has_meta("spin"):
					r.body.rotation.y += delta * 0.6
		_animate_parts(r, delta, now)
	_unit_views = units
	for id in views.keys():
		if not seen.has(id):
			_on_removed(id)
	_update_dying(delta)


var _unit_views := 0


func _advance_anim(r: Dictionary, delta: float, step: float, cam: Camera3D) -> void:
	var ap: AnimationPlayer = r.ap
	if ap == null:
		return
	r.anim_acc = minf(r.anim_acc + delta, 0.5)
	if r.anim_acc < step or not cam.is_position_in_frustum(r.node.global_position):
		return
	ap.advance(r.anim_acc)
	r.anim_acc = 0.0


func _sync_unit(e, r: Dictionary, alpha: float, delta: float, now: float) -> void:
	var p: Vector2 = e.prev_pos.lerp(e.pos, alpha)
	r.node.position = terrain.to3(p)
	if r.naval:
		r.node.position.y = terrain.WATER_LEVEL
		r.body.rotation.z = sin(now * 1.3 + e.id) * 0.05
	elif r.fly > 0.0:
		r.body.position.y = r.fly + sin(now * 2.0 + e.id) * 0.08
	var target_yaw := atan2(e.facing.x, e.facing.y)
	r.yaw = lerp_angle(r.yaw, target_yaw, minf(1.0, delta * TURN_SPEED))
	r.node.rotation.y = r.yaw
	var moving: bool = e.pos.distance_squared_to(e.prev_pos) > 0.04
	r.moving = moving
	if now < r.attack_until and not moving:
		return
	if moving:
		_play(r, "walk")
	elif not e.orders.is_empty() and e.orders[0].type in ["gather", "build"] and not e.orders[0].get("returning", false):
		_play(r, "work")
	else:
		_play(r, "idle")


## Cities fly their crown land's flag next to the imperial one.
func _sync_land_flag(e, r: Dictionary) -> void:
	if r.get("land", "") == e.crown_land:
		return
	r.land = e.crown_land
	if r.get("land_flag"):
		r.land_flag.queue_free()
		r.land_flag = null
	# The city's roofs take the nation's colour (devtools/roofs.py paints the atlases).
	var roofs := "res://assets/recolor/roofs_%s.png" % e.crown_land
	if e.crown_land != "" and ResourceLoader.exists(roofs):
		Models.retexture(r.body, roofs)
	elif r.get("roofs_changed", false):
		Models.retexture(r.body, "res://assets/kaykit/medieval/buildings/yellow/hexagons_medieval.png")
	r.roofs_changed = e.crown_land != ""
	if e.crown_land == "":
		return
	var flag := Flags.make(DB.crown_lands[e.crown_land].get("flag", e.crown_land), r.bar_height * 0.85 + 0.6, 0.85)
	flag.position = Vector3(e.size.x * 0.42, 0, e.size.y * 0.42)
	r.node.add_child(flag)
	r.land_flag = flag


func _sync_building(e, r: Dictionary) -> void:
	_sync_land_flag(e, r)
	if e.constructing:
		r.body.scale = Vector3(1.0, maxf(0.05, e.build_progress), 1.0)
	elif r.scaffold:
		r.scaffold.queue_free()
		r.scaffold = null
		r.body.scale = Vector3.ONE


func _play(r: Dictionary, key: String, restart := false) -> void:
	var ap: AnimationPlayer = r.ap
	if ap == null:
		return
	var name: String = r.anims.get(key, r.anims.get("idle", ""))
	if name == "" or not ap.has_animation(name):
		return
	if r.anim == name and not restart:
		return
	r.anim = name
	ap.play(name, 0.15)
	if restart:
		ap.seek(0.0, true)


## Parts of procedural models that move: wings ("flap") and orbiting groups ("spin").
func _animated_parts(root: Node) -> Array:
	var out: Array = []
	for n in root.find_children("*", "Node3D", true, false):
		if n.has_meta("flap") or n.has_meta("spin") or n.has_meta("deploy") or n.has_meta("gallop") or n.has_meta("spin_z"):
			out.append(n)
	return out


func _animate_parts(r: Dictionary, delta: float, now: float) -> void:
	for n in r.animated:
		if n.has_meta("flap"):
			n.rotation.z = float(n.get_meta("flap")) * sin(now * 9.0) * 0.55
		elif n.has_meta("gallop"):
			# Legs swing while moving and settle when standing.
			var swing: float = sin(now * 10.0) * 0.6 * float(n.get_meta("gallop")) if r.get("moving", false) else 0.0
			n.rotation.x = lerpf(n.rotation.x, swing, minf(1.0, delta * 12.0))
		elif n.has_meta("spin_z"):
			n.rotation.z += delta * float(n.get_meta("spin_z"))
		elif n.has_meta("deploy"):
			# Wagon pavises swing down and out when dug in.
			var target := float(n.get_meta("deploy")) * (-1.3 if r.get("deployed", false) else 0.0)
			n.rotation.z = lerpf(n.rotation.z, target, minf(1.0, delta * 4.0))
		else:
			n.rotation.y += delta * float(n.get_meta("spin"))


func _shadow() -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = 0.45
	m.bottom_radius = 0.45
	m.height = 0.01
	m.radial_segments = 16
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0, 0, 0, 0.3)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position.y = 0.03
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func pick_height(id: int) -> float:
	var r = views.get(id)
	return (r.fly + 0.4) if r else 0.4


func _shield_bubble(height: float) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = 0.55
	m.height = height
	m.radial_segments = 16
	m.rings = 8
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.55, 0.8, 1.0, 0.13)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.7, 1.0)
	mat.emission_energy_multiplier = 0.6
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position.y = height * 0.45
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	return mi


## A unit just cast a spell: play its cast animation once.
func on_cast(source_id: int) -> void:
	var r = views.get(source_id)
	if r == null or r.kind != Entity.UNIT:
		return
	r.attack_until = Time.get_ticks_msec() / 1000.0 + ATTACK_ANIM_TIME
	_play(r, "cast" if r.anims.has("cast") else "attack", true)


## A unit just struck: play its attack once.
func on_attack(source_id: int, target_pos: Vector2) -> void:
	var r = views.get(source_id)
	if r == null or r.kind != Entity.UNIT:
		return
	r.attack_until = Time.get_ticks_msec() / 1000.0 + ATTACK_ANIM_TIME
	_play(r, "attack", true)


func _on_removed(id: int) -> void:
	var r: Dictionary = views[id]
	views.erase(id)
	if not r.node.visible:
		r.node.queue_free()
		return
	r.sel.visible = false
	match r.kind:
		Entity.UNIT:
			if r.ap and r.anims.has("death"):
				r.ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
				_play(r, "death", true)
				_dying.append({"node": r.node, "t": 0.0, "ttl": DEATH_TIME, "sink": true})
			else:
				r.node.queue_free()
		Entity.BUILDING:
			var size: int = DB.buildings[r.type_id].size
			var rubble := Models.make_footprint_model({"model": DB.visuals.rubble, "fit": 1.0}, -1, size)
			rubble.position = r.node.position
			add_child(rubble)
			r.node.queue_free()
			_dying.append({"node": rubble, "t": 0.0, "ttl": RUBBLE_TIME, "sink": true})
		_:
			r.node.queue_free()


func _update_dying(delta: float) -> void:
	for d in _dying:
		d.t += delta
		var sink_start: float = d.ttl * 0.6
		if d.sink and d.t > sink_start:
			d.node.position.y -= delta * 0.6
	for d in _dying.filter(func(x): return x.t >= x.ttl):
		d.node.queue_free()
	_dying = _dying.filter(func(x): return x.t < x.ttl)


func bar_height(id: int) -> float:
	var r = views.get(id)
	return r.bar_height if r else 1.0
