extends Node3D
## City life from the Age of the Federation (7): civilian cars, buses (from Age 8)
## and pedestrians wander the open ground of cities near the camera. The Concern's
## cities get hearses and its dead clerks instead. Purely visual: nothing here is
## in the simulation, saved, or seen by the AI. Off on the Low graphics setting.

const DB = preload("res://sim/db.gd")
const GameMap = preload("res://sim/game_map.gd")
const Machines = preload("res://view3d/machines.gd")
const Gear = preload("res://view3d/gear.gd")
const Graphics = preload("res://ui/graphics.gd")

## The first age with traffic, and with buses.
const FROM_AGE := 7
const BUS_AGE := 8
## Cities further than this (tiles) from the camera's focus get none.
const NEAR := 26.0
## How far from its city an agent wanders (tiles).
const ROAM := 6.0
const PAINTS := [Color(0.12, 0.13, 0.16), Color(0.45, 0.1, 0.1), Color(0.14, 0.24, 0.18), Color(0.55, 0.5, 0.42),
		Color(0.2, 0.25, 0.42), Color(0.08, 0.08, 0.08)]
const BUS_PAINTS := [Color(0.6, 0.12, 0.1), Color(0.18, 0.3, 0.2)]
const COATS := [Color(0.22, 0.2, 0.18), Color(0.3, 0.26, 0.2), Color(0.15, 0.16, 0.2), Color(0.45, 0.4, 0.32), Color(0.4, 0.14, 0.14), Color(0.52, 0.48, 0.4)]

var gv
var terrain
## Agents: {node, city, kind ("car"/"bus"/"walker"), pos (px), goal (px), speed (px/s), wheels, phase}
var _agents: Array = []
var _rng := RandomNumberGenerator.new()
var _refresh := 0.0
var _limits := {}
static var _walkers := {}


func _ready() -> void:
	_rng.seed = 1918
	match Graphics.effective():
		"high":
			_limits = {"cities": 5, "car": 5, "bus": 1, "walker": 10}
		"medium":
			_limits = {"cities": 3, "car": 3, "bus": 1, "walker": 6}
		_:
			_limits = {}


func _process(delta: float) -> void:
	if _limits.is_empty() or gv == null:
		return
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.5
		_populate()
	var w = gv.world
	var dt: float = 0.0 if gv.paused else delta * float(gv.SPEEDS[gv.speed_index])
	for a in _agents:
		_move(a, w, dt)


## Keeps each near, modern city stocked with its traffic and clears the rest.
func _populate() -> void:
	var w = gv.world
	var focus: Vector3 = gv.camera.focus
	var cities: Array = []
	for e in w.entities.values():
		if not e.alive or e.owner < 0 or not w.is_city(e) or e.constructing:
			continue
		if w.players[e.owner].age < FROM_AGE or w.players[e.owner].is_rebels:
			continue
		var d := Vector2(e.pos.x / GameMap.TILE - focus.x, e.pos.y / GameMap.TILE - focus.z).length()
		if d <= NEAR:
			cities.append([d, e])
	cities.sort_custom(func(a, b): return a[0] < b[0])
	var keep := {}
	for i in mini(cities.size(), int(_limits.cities)):
		keep[cities[i][1].id] = cities[i][1]
	for a in _agents.duplicate():
		if not keep.has(a.city):
			_remove(a)
	for id in keep:
		var city = keep[id]
		var necro: bool = w.players[city.owner].faction == "covenant"
		var age: int = w.players[city.owner].age
		for kind in ["car", "bus", "walker"]:
			var want: int = int(_limits[kind]) if kind != "bus" or age >= BUS_AGE else 0
			var have := _agents.filter(func(a): return a.city == id and a.kind == kind).size()
			for n in want - have:
				_spawn(city, kind, necro)


func _spawn(city, kind: String, necro: bool) -> void:
	var start := _free_spot(city)
	if start == Vector2.INF:
		return
	var node: Node3D
	var team: Color = gv.world.players[city.owner].color
	match kind:
		"car":
			node = Machines.build("hearse_civil" if necro else "sedan", team if necro else PAINTS[_rng.randi() % PAINTS.size()])
			node.scale = Vector3.ONE * 0.7
		"bus":
			node = Machines.build("hearse_civil" if necro else "bus", team if necro else BUS_PAINTS[_rng.randi() % BUS_PAINTS.size()])
			node.scale = Vector3.ONE * 0.75
		_:
			node = _walker(necro, _rng.randi() % 4)
	add_child(node)
	var wheels: Array = node.find_children("*", "Node3D", true, false).filter(func(n): return n.has_meta("roll"))
	var speed: float = {"car": 1.5, "bus": 0.9, "walker": 0.35}[kind] * GameMap.TILE
	_agents.append({"node": node, "city": city.id, "kind": kind, "pos": start, "goal": start, "speed": speed * _rng.randf_range(0.85, 1.15),
			"wheels": wheels, "phase": _rng.randf() * TAU, "wait": _rng.randf_range(0.0, 2.0), "yaw": 0.0})


func _remove(a: Dictionary) -> void:
	a.node.queue_free()
	_agents.erase(a)


func _move(a: Dictionary, w, dt: float) -> void:
	var node: Node3D = a.node
	var city = w.get_entity(int(a.city))
	if city == null or not city.alive:
		node.visible = false
		return
	if a.wait > 0.0:
		a.wait -= dt
	elif a.pos.distance_to(a.goal) < 4.0:
		var next := _next_goal(city, a.pos)
		if next != Vector2.INF:
			a.goal = next
		a.wait = _rng.randf_range(0.5, 3.0) if a.kind == "walker" else _rng.randf_range(0.2, 1.2)
	else:
		var step: Vector2 = (a.goal - a.pos).limit_length(a.speed * dt)
		a.pos += step
		a.yaw = lerp_angle(a.yaw, atan2(step.x, step.y), minf(1.0, dt * 6.0))
		for wh in a.wheels:
			if not wh.has_meta("_wr"):
				wh.set_meta("_wr", float(wh.get_meta("roll")) * wh.global_transform.basis.x.length())
			wh.rotation.x = fmod(wh.rotation.x + step.length() / GameMap.TILE / float(wh.get_meta("_wr")), TAU)
		a.phase += dt * 9.0
	node.position = terrain.to3(a.pos)
	node.rotation.y = a.yaw
	if a.kind == "walker" and a.wait <= 0.0:
		node.position.y += absf(sin(a.phase)) * 0.025
	node.visible = gv.reveal_all or w.tile_visible(gv.me, GameMap.to_tile(a.pos))


## A random free tile in the city's own land, or INF.
func _free_spot(city) -> Vector2:
	var w = gv.world
	var c: Vector2i = GameMap.to_tile(city.pos)
	for i in 16:
		var t := c + Vector2i(_rng.randi_range(-int(ROAM), int(ROAM)), _rng.randi_range(-int(ROAM), int(ROAM)))
		if w.map.is_walkable(t) and w.territory_owner(t) == city.owner:
			return GameMap.tile_center(t)
	return Vector2.INF


## A free spot reachable in a straight line over open ground (no buildings), or INF.
func _next_goal(city, from: Vector2) -> Vector2:
	var w = gv.world
	for i in 10:
		var to := _free_spot(city)
		if to == Vector2.INF:
			return to
		var clear := true
		var n := ceili(from.distance_to(to) / (GameMap.TILE * 0.4))
		for k in range(1, n):
			if not w.map.is_walkable(GameMap.to_tile(from.lerp(to, float(k) / n))):
				clear = false
				break
		if clear:
			return to
	return Vector2.INF


## A townsperson, baked once per look: coat, legs, a head and a hat (a clerk of the
## dead in a bowler for the Concern).
func _walker(necro: bool, look: int) -> Node3D:
	var key := "%s/%d" % [necro, look]
	if not _walkers.has(key):
		var raw := Node3D.new()
		var coat := Gear.mat(COATS[(look * 2 + (1 if necro else 0)) % COATS.size()] if not necro else Color(0.1, 0.1, 0.11))
		var skin := Gear.mat(Color(0.86, 0.7, 0.58) if not necro else Color(0.86, 0.82, 0.7))
		var dark := Gear.mat(Color(0.08, 0.08, 0.09))
		for x in [-0.035, 0.035]:
			Gear.part(raw, Gear.cyl(0.026, 0.3), dark, Vector3(x, 0.15, 0))
		Gear.part(raw, Gear.cyl(0.07, 0.34, 0.055), coat, Vector3(0, 0.44, 0))
		if look == 3 and not necro:
			# A long skirt and a cloche hat.
			Gear.part(raw, Gear.cyl(0.085, 0.24, 0.06), coat, Vector3(0, 0.26, 0))
		Gear.part(raw, Gear.sphere(0.055), skin, Vector3(0, 0.67, 0))
		if necro:
			for s in [-1.0, 1.0]:
				Gear.part(raw, Gear.sphere(0.012), Gear.soul(), Vector3(s * 0.02, 0.68, 0.048))
		var hat := Gear.mat(Color(0.1, 0.09, 0.08) if look != 2 else Color(0.4, 0.33, 0.24))
		if look == 3 and not necro:
			Gear.part(raw, Gear.sphere(0.06, true), Gear.mat(Color(0.45, 0.2, 0.25)), Vector3(0, 0.69, 0))
		else:
			Gear.part(raw, Gear.cyl(0.08, 0.012), hat, Vector3(0, 0.71, 0))
			Gear.part(raw, Gear.cyl(0.05, 0.06, 0.045), hat, Vector3(0, 0.74, 0))
		_walkers[key] = Gear._bake(raw).mesh
		raw.free()
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = _walkers[key]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	root.scale = Vector3.ONE * 1.1
	return root
