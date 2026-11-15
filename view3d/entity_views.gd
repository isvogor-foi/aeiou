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
## Target ring under whatever the cursor would act on (attack, spell), and
## blinking rings on targets just ordered: [ring, until_seconds].
var _hover_ring: MeshInstance3D
var _flashes: Array = []


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
			r.anims = Models.anims_of(v)
			r.fly = float(v.get("fly_height", 0.0))
			r.naval = v.get("naval", false)
			r.bar_height = (float(v.get("height", 0.9)) + 0.25) * Models.unit_scale(e.type_id) + r.fly
			r.animated = _animated_parts(body)
			r.rumble = float(v.get("rumble", 0.0))
			# Heavy vehicles swing round slowly ("turn" in visuals.json, default as for infantry).
			r.turn = float(v.get("turn", TURN_SPEED))
			r.variant = Models.unit_variant(e.type_id, e.owner)
			r.bank = v.get("bank", false)
			r.circle = float(v.get("circle", 0.0))
			if r.fly > 0.0:
				body.position.y = r.fly
				node.add_child(_shadow())
			var team: Color = gv.world.players[e.owner].color
			# The team (and hero) rings show only while the unit is selected.
			r.rings = [_ring(0.45, Color(team, 0.75))]
			node.add_child(r.rings[0])
			if e.is_hero():
				r.rings.append(_ring(0.75, Color(1.0, 0.82, 0.3, 0.9)))
				node.add_child(r.rings[-1])
			r.shield = _shield_bubble(r.bar_height)
			node.add_child(r.shield)
			r.sel = _ring(0.58, Color(0.35, 1.0, 0.35, 0.95))
			node.add_child(r.sel)
			r.yaw = atan2(e.facing.x, e.facing.y)
			_play(r, "idle")
		Entity.BUILDING, Entity.RESOURCE:
			var table: Dictionary = DB.visuals.buildings if e.kind == Entity.BUILDING else DB.visuals.resources
			var body := Models.make_footprint_model(table.get(e.type_id, {"procedural": "crystal"}), e.owner, e.size.x, e.crown_land if e.kind == Entity.BUILDING else "")
			node.add_child(body)
			r.body = body
			# The design and age it was built in, so proclaiming a crown land or
			# advancing an age rebuilds it.
			r.styled_land = e.crown_land if e.kind == Entity.BUILDING else ""
			r.built_age = _age_of(e.owner) if e.kind == Entity.BUILDING else 0
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
			if e.kind == Entity.RESOURCE and e.def.get("relic", false):
				_dress_relic(r, e)
			if e.kind == Entity.BUILDING and e.constructing:
				var scaffold := Models.make_footprint_model({"building": "scaffold"}, e.owner, e.size.x)
				scaffold.scale = Vector3(e.size.x * 0.95, 1.0, e.size.y * 0.95)
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


## Puts the target ring under entity `e` in `color`, or hides it when e is null.
func show_hover(e, color: Color) -> void:
	if _hover_ring == null:
		_hover_ring = _ring(1.0, color)
		add_child(_hover_ring)
	var r = views.get(e.id) if e != null else null
	_hover_ring.visible = r != null and r.node.visible
	if not _hover_ring.visible:
		return
	_hover_ring.material_override = _ring_material(Color(color, 0.9))
	var rad: float = 0.62 if e.kind == Entity.UNIT else e.size.x * 0.8
	_hover_ring.scale = Vector3(rad, 0.06, rad)
	_hover_ring.global_position = r.node.global_position + Vector3(0, 0.05, 0)


## Confirms an order on entity `id`: its ring blinks in `color` for a moment.
func flash_target(id: int, color: Color) -> void:
	var r = views.get(id)
	if r == null:
		return
	var e = gv.world.get_entity(id)
	var rad: float = 0.7 if e == null or e.kind == Entity.UNIT else e.size.x * 0.85
	var ring := _ring(rad, color)
	r.node.add_child(ring)
	_flashes.append([ring, Time.get_ticks_msec() / 1000.0 + 0.9])


func _sync_flashes(now: float) -> void:
	for f in _flashes.duplicate():
		var ring: MeshInstance3D = f[0]
		if not is_instance_valid(ring) or now > f[1]:
			if is_instance_valid(ring):
				ring.queue_free()
			_flashes.erase(f)
			continue
		# Three quick blinks, the ring tightening onto the target.
		var left: float = f[1] - now
		ring.visible = fmod(left, 0.3) > 0.12
		var k := 1.0 + left * 0.5
		ring.scale = Vector3(ring.scale.x / maxf(0.01, ring.get_meta("k", 1.0)) * k, 0.06, ring.scale.z / maxf(0.01, ring.get_meta("k", 1.0)) * k)
		ring.set_meta("k", k)


func sync(alpha: float, delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_sync_flashes(now)
	var ages: Array = gv.world.players.map(func(p): return p.age)
	# An age-up can change what figures wear (era variants): recheck them once.
	var era_check: bool = ages != Models.team_ages
	Models.team_ages = ages
	var seen := {}
	var cam: Camera3D = gv.camera
	var anim_step := ANIM_STEP_CROWD if _unit_views >= CROWD else 0.0
	var units := 0
	for e in gv.world.entities.values():
		if not e.alive:
			continue
		seen[e.id] = true
		var r = views.get(e.id)
		if r == null or r.owner != e.owner or r.type_id != e.type_id \
				or (era_check and r.kind == Entity.UNIT and r.get("variant", "") != Models.unit_variant(e.type_id, e.owner)):
			if r != null:
				r.node.queue_free()
			r = _create(e)
			views[e.id] = r
		var shown: bool = gv.is_shown(e)
		r.node.visible = shown
		if not shown:
			continue
		r.sel.visible = gv.is_selected(e.id)
		for ring in r.get("rings", []):
			ring.visible = r.sel.visible
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
				_sync_relic(e, r)
		# Wheels, tracks, turrets, rotors: only for what the camera can see.
		if not r.animated.is_empty() and cam.is_position_in_frustum(r.node.global_position):
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
	var p3: Vector3 = terrain.to3(p)
	# Ground covered this frame, for wheels and tracks (forward is positive).
	if r.has("last3"):
		var step: Vector3 = p3 - r.last3
		var fwd := Vector3(sin(r.yaw), 0.0, cos(r.yaw))
		r.travel = step.length() * (1.0 if step.dot(fwd) >= 0.0 else -1.0)
	r.last3 = p3
	r.node.position = p3
	var moving: bool = e.pos.distance_squared_to(e.prev_pos) > 0.04
	var target_yaw := atan2(e.facing.x, e.facing.y)
	var was_yaw: float = r.yaw
	r.yaw = lerp_angle(r.yaw, target_yaw, minf(1.0, delta * float(r.get("turn", TURN_SPEED))))
	r.node.rotation.y = r.yaw
	if r.naval:
		r.node.position.y = terrain.WATER_LEVEL
		r.body.rotation.z = sin(now * 1.3 + e.id) * 0.05
	elif r.fly > 0.0:
		_sync_flight(e, r, moving, wrapf(r.yaw - was_yaw, -PI, PI) / maxf(delta, 0.001), delta, now)
	r.moving = moving
	if r.get("rumble", 0.0) > 0.0 and r.fly <= 0.0 and not r.naval:
		# Engines shake the hull while driving and idle gently when parked.
		var amp: float = r.rumble * (1.0 if moving else 0.25)
		r.body.rotation.x = sin(now * 23.0 + e.id) * 0.012 * amp
		r.body.position.y = absf(sin(now * 17.0 + e.id)) * 0.012 * amp
	if now < r.attack_until and not moving:
		return
	if moving:
		_play(r, "walk")
	elif not e.orders.is_empty() and e.orders[0].type in ["gather", "build"] and not e.orders[0].get("returning", false):
		_play(r, "work")
	else:
		_play(r, "idle")


## Flyers bob; planes ("bank") lean into turns, and with "circle" they orbit their
## spot slowly while idle instead of hanging in the air.
func _sync_flight(e, r: Dictionary, moving: bool, turn_rate: float, delta: float, now: float) -> void:
	var bob: float = sin(now * 2.0 + e.id) * 0.08
	var lean := 0.0
	if r.circle > 0.0:
		r.orbit = lerpf(r.get("orbit", 0.0), 0.0 if moving else 1.0, minf(1.0, delta * 1.2))
		var a: float = now * 0.8 + e.id
		r.body.position = Vector3(cos(a) * r.circle * r.orbit, r.fly + bob, sin(a) * r.circle * r.orbit)
		r.body.rotation.y = lerp_angle(0.0, -a, r.orbit)
		lean = -0.45 * r.orbit
	else:
		r.body.position.y = r.fly + bob
	if r.bank:
		lean += clampf(-turn_rate * 0.25, -0.7, 0.7)
		r.body.rotation.z = lerp_angle(r.body.rotation.z, lean, minf(1.0, delta * 4.0))


## Cities fly their crown land's flag next to the imperial one.
func _sync_land_flag(e, r: Dictionary) -> void:
	if r.get("land", "") == e.crown_land:
		return
	r.land = e.crown_land
	if r.get("land_flag"):
		r.land_flag.queue_free()
		r.land_flag = null
	# A city is rebuilt in the design of the land it proclaims (view3d/buildings.gd).
	var v: Dictionary = DB.visuals.buildings.get(e.type_id, {})
	if v.get("styled", false) and r.get("styled_land", "") != e.crown_land:
		_rebuild_body(e, r)
	r.styled_land = e.crown_land
	if e.crown_land == "":
		return
	var flag := Flags.make(DB.crown_lands[e.crown_land].get("flag", e.crown_land), r.bar_height * 0.85 + 0.6, 0.85)
	flag.position = Vector3(e.size.x * 0.42, 0, e.size.y * 0.42)
	r.node.add_child(flag)
	r.land_flag = flag


## Relics are hard to miss: a pillar of golden light while they lie loose, and
## their name floating over them (and over whoever carries one).
func _dress_relic(r: Dictionary, e) -> void:
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.02
	cyl.bottom_radius = 0.16
	cyl.height = 7.0
	cyl.radial_segments = 12
	cyl.cap_top = false
	cyl.cap_bottom = false
	beam.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(1.0, 0.78, 0.3, 0.35)
	beam.material_override = mat
	beam.position.y = 3.5
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.node.add_child(beam)
	r.relic_beam = beam
	var label := Label3D.new()
	label.text = e.def.name
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0011
	label.font_size = 26
	label.outline_size = 8
	label.modulate = Color(1.0, 0.86, 0.45)
	label.outline_modulate = Color(0.08, 0.05, 0.02)
	label.position.y = 1.1
	r.node.add_child(label)
	r.relic_label = label


func _sync_relic(e, r: Dictionary) -> void:
	if r.has("relic_beam"):
		# The pillar marks it only while it lies loose; carried, its name rides along higher.
		r.relic_beam.visible = e.carried_by < 0
		r.relic_label.position.y = 2.1 if e.carried_by >= 0 else 1.1


func _age_of(owner: int) -> int:
	return gv.world.players[owner].age if owner >= 0 and owner < gv.world.players.size() else 0


## Swaps a building's model for a fresh one (new crown-land design or new age).
func _rebuild_body(e, r: Dictionary) -> void:
	var v: Dictionary = DB.visuals.buildings.get(e.type_id, {})
	var body := Models.make_footprint_model(v, e.owner, e.size.x, e.crown_land)
	var holder: Node = r.body.get_parent()
	holder.add_child(body)
	holder.move_child(body, r.body.get_index())
	# Detach the old model first, so its moving parts aren't collected below
	# and then touched after they are freed.
	holder.remove_child(r.body)
	r.body.queue_free()
	r.body = body
	r.animated = _animated_parts(r.node)
	r.built_age = _age_of(e.owner)


func _sync_building(e, r: Dictionary) -> void:
	# Buildings are dressed for their owner's age: advancing rebuilds them all.
	if r.get("built_age", 0) != _age_of(e.owner) and DB.visuals.buildings.get(e.type_id, {}).has("building"):
		_rebuild_body(e, r)
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
		if n.has_meta("flap") or n.has_meta("spin") or n.has_meta("deploy") or n.has_meta("gallop") or n.has_meta("spin_z") or n.has_meta("nod") \
				or n.has_meta("roll") or n.has_meta("tread") or n.has_meta("turret"):
			out.append(n)
	return out


func _animate_parts(r: Dictionary, delta: float, now: float) -> void:
	for n in r.animated:
		if n.has_meta("roll"):
			# Wheels turn by the ground covered (radius in world units, cached).
			if not n.has_meta("_wr"):
				n.set_meta("_wr", float(n.get_meta("roll")) * n.global_transform.basis.x.length())
			n.rotation.x = fmod(n.rotation.x + r.get("travel", 0.0) / float(n.get_meta("_wr")), TAU)
		elif n.has_meta("tread"):
			if not n.has_meta("_ws"):
				n.set_meta("_ws", n.global_transform.basis.x.length())
			var scroll: float = float(n.get_meta("_scroll", 0.0)) + r.get("travel", 0.0) / float(n.get_meta("_ws"))
			n.set_meta("_scroll", fmod(scroll, 100.0))
			for c in n.get_children():
				if c is GeometryInstance3D:
					c.set_instance_shader_parameter("scroll", scroll)
		elif n.has_meta("turret"):
			# Turn to the last target for a few seconds, then back to the front.
			var aim := 0.0
			if now < r.get("aim_until", 0.0):
				aim = wrapf(r.aim_yaw - r.yaw, -PI, PI)
			n.rotation.y = lerp_angle(n.rotation.y, aim, minf(1.0, delta * float(n.get_meta("turret"))))
		elif n.has_meta("flap"):
			n.rotation.z = float(n.get_meta("flap")) * sin(now * 9.0) * 0.55
		elif n.has_meta("gallop"):
			# Legs swing while moving and settle when standing.
			var swing: float = sin(now * 10.0) * 0.6 * float(n.get_meta("gallop")) if r.get("moving", false) else 0.0
			n.rotation.x = lerpf(n.rotation.x, swing, minf(1.0, delta * 12.0))
		elif n.has_meta("spin_z"):
			n.rotation.z += delta * float(n.get_meta("spin_z"))
		elif n.has_meta("nod"):
			# Pumpjacks and beam engines rock back and forth.
			n.rotation.x = sin(now * 1.6) * float(n.get_meta("nod"))
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


## Where a unit is drawn, for picking: its body's position (a flyer's includes its
## height, its idle circle and its bob), or null if it has no view yet.
func pick_point(id: int):
	var r = views.get(id)
	if r == null or not r.has("body") or r.body == null:
		return null
	return r.body.global_position + Vector3(0, 0.3 if r.fly > 0.0 else 0.4, 0)


## A unit's drawn height (feet to head, or a flyer's body), for picking.
func pick_span(id: int) -> float:
	var r = views.get(id)
	if r == null:
		return 0.8
	return 0.6 if r.fly > 0.0 else maxf(0.6, r.bar_height - 0.25)


## True for units that are hard to hit with a small pick circle (aircraft).
func is_flyer(id: int) -> bool:
	var r = views.get(id)
	return r != null and r.fly > 0.0


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
	var e = gv.world.get_entity(source_id)
	if e:
		r.aim_yaw = atan2(target_pos.x - e.pos.x, target_pos.y - e.pos.y)
		r.aim_until = r.attack_until + 2.5


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
