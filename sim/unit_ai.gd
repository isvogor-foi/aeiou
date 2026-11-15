extends RefCounted
## Per-tick unit behaviour: run the front order of each unit's queue, auto-acquire
## enemies when idle, and walk paths.

const Prof = preload("res://sim/prof.gd")
const GameMap = preload("res://sim/game_map.gd")
const Entity = preload("res://sim/entity.gd")
const Abilities = preload("res://sim/abilities.gd")

const DT := 1.0 / 20.0
const TILE := GameMap.TILE
const UNIT_RADIUS := 0.35 * TILE
const SCAN_INTERVAL := 5
const REPATH_TICKS := 10
## How close (outline to outline) a unit must be to gather, build or drop off.
const INTERACT_RANGE := 0.5 * TILE
## Auto-acquired targets are abandoned once the unit strays this far (in tiles beyond sight).
const LEASH_EXTRA := 4.0
## Ground units board a transport from this close (centre to centre).
const BOARD_RANGE := 2.2 * TILE
## Within this distance, chase a unit target in a straight line instead of pathfinding.
const DIRECT_CHASE := 4.0 * TILE

enum { MOVING, IN_RANGE, UNREACHABLE }


static func update(w, e) -> void:
	if e.attack_cd > 0.0:
		e.attack_cd -= DT
	if e.reload_left > 0.0:
		e.reload_left -= DT
		if e.reload_left <= 0.0:
			e.ammo = int(e.def.passives.magazine.shots)
	_update_charge(e)
	if not e.autocast.is_empty() and (w.tick_count + e.id) % SCAN_INTERVAL == 0:
		Abilities.try_autocast(w, e)
	if e.deployed:
		# Dug in: the only order a wagon fort takes is to let its garrison out.
		if not e.orders.is_empty() and e.orders[0].type == "unload" and _unload(w, e, e.orders[0]):
			e.orders.pop_front()
		_wagon_fort(w, e)
		return
	if e.orders.is_empty():
		_idle(w, e)
		return
	var o: Dictionary = e.orders[0]
	var done := true
	match o.type:
		"move":
			done = _move(w, e, o)
		"attack":
			done = _attack(w, e, o)
		"attack_move":
			done = _attack_move(w, e, o)
		"gather":
			done = _gather(w, e, o)
		"build":
			done = _build(w, e, o)
		"cast":
			done = _cast(w, e, o)
		"board":
			done = _board(w, e, o)
		"unload":
			done = _unload(w, e, o)
		"pickup":
			var r = w.get_entity(o.target)
			if r == null or r.carried_by >= 0 or r.inside >= 0 or e.relic >= 0:
				done = true
			else:
				var st := _approach_rect(w, e, r.tile, Vector2i.ONE, INTERACT_RANGE)
				if st == IN_RANGE:
					w.pick_up_relic(e, r)
				done = st != MOVING
		"store":
			var holder = w.get_entity(o.target)
			if holder == null or not holder.alive or e.relic < 0:
				done = true
			else:
				var st := _approach(w, e, holder, INTERACT_RANGE)
				if st == IN_RANGE:
					w.store_relic(e, holder)
				done = st != MOVING
	if done and not e.orders.is_empty() and is_same(e.orders[0], o):
		e.orders.pop_front()
		reset_path(e)


static func domain(e) -> String:
	return e.def.get("domain", "ground")


static func reset_path(e) -> void:
	e.path = PackedVector2Array()
	e.path_index = 0
	e.path_goal = Vector2i(-1, -1)
	e.repath = 0
	e.stuck = 0
	e.wp_best = INF
	e.wp_stall = 0


static func update_tower(w, b) -> void:
	if not b.can_attack():
		return
	if b.attack_cd > 0.0:
		b.attack_cd -= DT
	var range_px := float(b.def.range) * TILE
	var t = w.get_entity(b.target_id)
	if t == null or not t.alive or w.edge_dist(b, t) > range_px:
		b.target_id = -1
		if (w.tick_count + b.id) % SCAN_INTERVAL != 0:
			return
		t = w.find_enemy_near(b, range_px)
		if t == null:
			return
		b.target_id = t.id
	if b.attack_cd <= 0.0:
		b.attack_cd = float(b.def.cooldown)
		_hit(w, b, t)


# --- Orders -----------------------------------------------------------------------

static func _idle(w, e) -> void:
	# Workers don't pick fights; militia (Grenzer) do when they have nothing else to do.
	if not e.can_attack() or (e.is_worker() and e.def.get("role", "") != "militia"):
		return
	if (w.tick_count + e.id) % SCAN_INTERVAL != 0:
		return
	var pt := Prof.start()
	var t = w.find_enemy_near(e, float(e.def.sight) * TILE)
	Prof.stop("idle_scan", pt)
	if t:
		e.orders.push_front({"type": "attack", "target": t.id, "auto": true, "leash": e.pos})


static func _move(w, e, o: Dictionary) -> bool:
	if not o.get("started", false):
		if not w.take_path_budget():
			return false
		o.started = true
		_path_to(w, e, GameMap.to_tile(o.pos), o.pos)
	var done := _follow(e)
	if done and o.has("face"):
		# Formations: turn to face the way the group was marching.
		e.facing = o.face
	return done


static func _attack(w, e, o: Dictionary) -> bool:
	var t = w.get_entity(o.target)
	if t == null or not t.alive or not w.is_enemy(e, t) or not w.can_target(e, t):
		return true
	if t.kind == Entity.UNIT and not w.is_visible_to(e.owner, t):
		return true
	if o.get("auto", false) and e.pos.distance_to(o.leash) > (float(e.def.sight) + LEASH_EXTRA) * TILE:
		return true
	var passives: Dictionary = e.def.get("passives", {})
	if passives.has("min_range") and w.edge_dist(e, t) < float(passives.min_range) * TILE:
		# Too close for a siege gun to lob at.
		return true
	var state := _approach(w, e, t, w.attack_range(e, t))
	if state == UNREACHABLE:
		return true
	if state == IN_RANGE:
		e.facing = (t.pos - e.pos).normalized()
		if passives.has("setup") and e.setup < float(passives.setup.time):
			e.setup += DT
			return false
		if e.attack_cd <= 0.0 and e.reload_left <= 0.0:
			e.attack_cd = float(e.def.cooldown)
			_hit(w, e, t)
			_spend_round(e)
	return false


## Air rifles: a few quick shots, then a long pump to refill the air flask.
static func _spend_round(e) -> void:
	var mag: Dictionary = e.def.get("passives", {}).get("magazine", {})
	if mag.is_empty():
		return
	if e.ammo < 0:
		e.ammo = int(mag.shots)
	e.ammo -= 1
	if e.ammo <= 0:
		e.reload_left = float(mag.reload)


## Ground troops walk to the shore beside the transport and climb aboard.
static func _board(w, e, o: Dictionary) -> bool:
	var t = w.get_entity(o.target)
	if t == null or not t.alive or t.owner != e.owner or not t.def.has("capacity"):
		return true
	if w.cargo_space(t) < int(e.def.get("pop", 1)):
		return true
	if e.pos.distance_to(t.pos) <= BOARD_RANGE:
		w.load_unit(t, e)
		return true
	var goal: Vector2i = w.map.nearest_walkable(GameMap.to_tile(t.pos), 4)
	if goal.x < 0:
		return true
	return _travel(w, e, goal) == UNREACHABLE


## A deployed wagon fort: fires its garrison's guns at the nearest enemy in range.
static func _wagon_fort(w, e) -> void:
	var cfg: Dictionary = e.def.deployed
	if e.attack_cd > 0.0:
		return
	var shooters := 0
	for id in e.cargo:
		var u = w.get_entity(id)
		if u and u.can_attack():
			shooters += 1
	var t = w.find_enemy_near(e, float(cfg.range) * TILE)
	if t == null:
		return
	e.attack_cd = float(cfg.cooldown)
	e.facing = (t.pos - e.pos).normalized()
	w.deal_damage(e, t, float(cfg.base) + float(cfg.per_passenger) * shooters, cfg.dtype)


## A transport sails to the shore nearest `pos` and puts its cargo ashore (a land
## transport just drives there).
static func _unload(w, e, o: Dictionary) -> bool:
	if e.cargo.is_empty():
		return true
	if domain(e) != "naval":
		if e.deployed or e.pos.distance_to(o.pos) <= TILE * 1.5:
			reset_path(e)
			w.unload_all(e, o.pos)
			return true
		if not o.get("started", false):
			if not w.take_path_budget():
				return false
			o.started = true
			_path_to(w, e, GameMap.to_tile(o.pos), o.pos)
		return _follow(e)
	if not o.has("shore"):
		o.shore = w.map.nearest_shore(GameMap.to_tile(o.pos))
		if o.shore.x < 0:
			return true
	var shore_px := GameMap.tile_center(o.shore)
	if e.pos.distance_to(shore_px) <= TILE * 1.2:
		reset_path(e)
		w.unload_all(e, o.pos)
		return true
	return _travel(w, e, o.shore) == UNREACHABLE


## Walks into range of the spell's target, then casts it once.
static func _cast(w, e, o: Dictionary) -> bool:
	var a := Abilities.def(o.ability)
	var range_px := float(a.range) * TILE
	var t = w.get_entity(o.target)
	if a.target in ["unit_ally", "unit_enemy"]:
		if t == null or not t.alive:
			return true
		var state := _approach(w, e, t, range_px)
		if state == UNREACHABLE:
			return true
		if state == IN_RANGE:
			Abilities.cast(w, e, o.ability, t, t.pos)
			return true
		return false
	if e.pos.distance_to(o.pos) <= range_px:
		reset_path(e)
		Abilities.cast(w, e, o.ability, null, o.pos)
		return true
	return _travel(w, e, GameMap.to_tile(o.pos)) == UNREACHABLE


## Charge passive: after walking far enough, the next blow is a charge (and the run-up is faster).
static func _update_charge(e) -> void:
	if not e.def.has("passives") or not e.def.passives.has("charge"):
		return
	if e.moved >= float(e.def.passives.charge.distance) * TILE:
		e.charge_ready = true


## Vehicles with "accel" in units.json (seconds from a standstill to full speed)
## pull away at this share of their top speed.
const ACCEL_FROM := 0.25


static func _speed(e) -> float:
	var s: float = float(e.def.speed) * TILE * DT * e.speed_mult
	if e.def.has("accel"):
		# Stopped (even for a moment): start again from a crawl.
		if e.still > 0.0:
			e.throttle = ACCEL_FROM
		e.throttle = minf(1.0, e.throttle + DT * (1.0 - ACCEL_FROM) / maxf(0.05, float(e.def.accel)))
		s *= e.throttle
	if e.charge_ready:
		s *= float(e.def.passives.charge.speed_mult)
	for fx in e.effects:
		if fx.type == "slow":
			s *= 1.0 - fx.amount
		elif fx.type == "haste":
			s *= 1.0 + fx.amount
	# Anything that moves loses its siege set-up.
	e.setup = 0.0
	return s


static func _attack_move(w, e, o: Dictionary) -> bool:
	# Scan on the usual cadence, and always right after a fight ends (before paying
	# for a fresh long path): in a melee the next enemy is usually right there.
	if not o.get("started", false) or (w.tick_count + e.id) % SCAN_INTERVAL == 0:
		var t = w.find_enemy_near(e, float(e.def.sight) * TILE)
		if t:
			o.started = false
			reset_path(e)
			e.orders.push_front({"type": "attack", "target": t.id, "auto": true, "leash": e.pos})
			return false
	return _move(w, e, o)


static func _gather(w, e, o: Dictionary) -> bool:
	var res: String = o.res
	var cap := float(w.rules.carry)
	if e.carry_type != "" and e.carry_type != res:
		e.carry_type = ""
		e.carry_amount = 0.0
	if o.get("returning", false) or e.carry_amount >= cap:
		var pd := Prof.start()
		var r := _deliver(w, e, o)
		Prof.stop("g_deliver", pd)
		return r

	if o.has("tile"):
		var tile: Vector2i = o.tile
		if w.map.timber_at(tile) <= 0.0:
			tile = w.map.nearest_forest(tile, 8)
			if tile.x < 0:
				return _finish_gather(w, e, o)
			o.tile = tile
			reset_path(e)
		var state := _approach_rect(w, e, tile, Vector2i.ONE, INTERACT_RANGE)
		if state == UNREACHABLE:
			o.tile = w.map.nearest_forest(GameMap.to_tile(e.pos), 8)
			reset_path(e)
			if o.tile.x < 0:
				return _finish_gather(w, e, o)
		elif state == IN_RANGE:
			var take: float = w.harvest_take(e.owner, res, float(o.rate), e.pos)
			var got: float = w.map.take_timber(tile, minf(take, cap - e.carry_amount))
			e.carry_type = res
			e.carry_amount += got
			w.players[e.owner].note_harvest(res, got)
		return false

	var t = w.get_entity(o.target)
	if t == null or not t.alive:
		t = w.nearest_resource(res, o.get("last_pos", e.pos), 12.0 * TILE, e.owner, domain(e))
		if t == null:
			return _finish_gather(w, e, o)
		o.target = t.id
		reset_path(e)
	o.last_pos = t.pos
	var pa := Prof.start()
	var state := _approach(w, e, t, INTERACT_RANGE)
	Prof.stop("g_approach", pa)
	if state == UNREACHABLE:
		return _finish_gather(w, e, o)
	if state == IN_RANGE:
		var ph := Prof.start()
		var amt := minf(w.harvest_take(e.owner, res, float(o.rate), e.pos), cap - e.carry_amount)
		Prof.stop("g_harvest", ph)
		if t.amount >= 0.0:
			amt = minf(amt, t.amount)
			t.amount -= amt
			if t.amount <= 0.0:
				w.kill(t)
		e.carry_type = res
		e.carry_amount += amt
		w.players[e.owner].note_harvest(res, amt)
	return false


static func _deliver(w, e, o: Dictionary) -> bool:
	o.returning = true
	if e.carry_amount <= 0.0:
		o.returning = false
		return o.get("stop_after_drop", false)
	# Pick the drop-off once per trip home; re-pick only if it is lost.
	var drop = w.get_entity(int(o.get("drop", -1)))
	if drop == null or not drop.alive or drop.owner != e.owner:
		var pt := Prof.start()
		drop = w.nearest_dropoff(e.owner, e.carry_type, e.pos, domain(e))
		Prof.stop("nearest_dropoff", pt)
		o.drop = drop.id if drop else -1
	if drop == null:
		return true
	var state := _approach(w, e, drop, INTERACT_RANGE)
	if state == UNREACHABLE:
		return true
	if state == IN_RANGE:
		w.players[e.owner].res[e.carry_type] += e.carry_amount * w.deposit_mult(drop)
		e.carry_amount = 0.0
		e.carry_type = ""
		o.returning = false
		o.erase("drop")
		reset_path(e)
		return o.get("stop_after_drop", false)
	return false


## The resource ran out: drop off what we carry, then stop.
static func _finish_gather(w, e, o: Dictionary) -> bool:
	if e.carry_amount <= 0.0:
		return true
	o.stop_after_drop = true
	return _deliver(w, e, o)


static func _build(w, e, o: Dictionary) -> bool:
	var b = w.get_entity(o.target)
	if b == null or not b.alive or not b.constructing:
		return true
	var state := _approach(w, e, b, INTERACT_RANGE)
	if state == UNREACHABLE:
		return true
	if state == IN_RANGE:
		w.advance_construction(b, DT)
	return false


# --- Combat --------------------------------------------------------------------------

static func _hit(w, attacker, target) -> void:
	w.deal_damage(attacker, target)


# --- Movement ------------------------------------------------------------------------

## Moves toward entity `t` until within `range_px` of its outline.
static func _approach(w, e, t, range_px: float) -> int:
	if _in_reach(e, t.id, w.edge_dist(e, t), range_px):
		reset_path(e)
		return IN_RANGE
	var goal: Vector2i
	var dom := domain(e)
	if t.kind == Entity.UNIT:
		if e.pos.distance_to(t.pos) < DIRECT_CHASE and w.map.line_clear(e.pos, t.pos, dom):
			reset_path(e)
			_step_toward(e, t.pos)
			return MOVING
		goal = GameMap.to_tile(t.pos)
	elif e.approach_id == t.id and e.path_index < e.path.size() and e.repath > 1:
		# Still walking an approach path to the same building or node: keep its goal.
		goal = e.path_goal
	else:
		var pt := Prof.start()
		goal = w.map.approach_tile(t.tile, t.size, e.pos, dom)
		Prof.stop("approach_tile", pt)
		e.approach_id = t.id
	return _travel(w, e, goal)


static func _approach_rect(w, e, top_left: Vector2i, size: Vector2i, range_px: float) -> int:
	var r := Rect2(Vector2(top_left) * TILE, Vector2(size) * TILE)
	if _in_reach(e, -2 - (top_left.y * 4096 + top_left.x), w.rect_dist(r, e.pos) - UNIT_RADIUS, range_px):
		reset_path(e)
		return IN_RANGE
	return _travel(w, e, w.map.approach_tile(top_left, size, e.pos, domain(e)))


## Once a unit has reached a target it keeps a little extra reach (hysteresis),
## so a neighbour heading for the same spot can jostle it without sending it back
## to walk in, which made pairs of units push each other round in circles.
const ENGAGED_SLACK := TILE * 0.6


static func _in_reach(e, key: int, dist: float, range_px: float) -> bool:
	if dist <= range_px or (e.engaged == key and dist <= range_px + ENGAGED_SLACK):
		e.engaged = key
		return true
	if e.engaged == key:
		e.engaged = -1
	return false


static func _travel(w, e, goal: Vector2i) -> int:
	e.repath -= 1
	var path_done: bool = e.path_index >= e.path.size()
	if path_done or (goal != e.path_goal and e.repath <= 0):
		if not w.take_path_budget():
			# Too many searches this tick: keep walking the old path, retry next tick.
			if not path_done:
				_follow(e)
			return MOVING
		_path_to(w, e, goal)
		e.repath = REPATH_TICKS
		if e.path.is_empty():
			# Pushed off the goal tile's centre (e.g. by a neighbour): step back onto it.
			var center := GameMap.tile_center(goal)
			if GameMap.to_tile(e.pos) == goal and e.pos.distance_to(center) > 2.0:
				# Bounded: if a neighbour keeps shoving us off, give up rather than circle.
				e.stuck += 1
				if e.stuck > 30:
					return UNREACHABLE
				_step_toward(e, center)
				return MOVING
			# Already as close as we can get, but still not in range.
			e.stuck += 1
			return UNREACHABLE if e.stuck > 3 else MOVING
	_follow(e)
	return MOVING


static func _path_to(w, e, goal: Vector2i, exact: Variant = null) -> void:
	var pt := Prof.start()
	e.path = w.map.find_path(e.pos, goal, domain(e))
	Prof.stop("find_path", pt)
	e.path_index = 0
	e.wp_best = INF
	e.wp_stall = 0
	e.path_goal = goal
	if exact != null and w.map.is_passable(GameMap.to_tile(exact), domain(e)):
		var n: int = e.path.size()
		if n > 0 and GameMap.to_tile(e.path[n - 1]) == GameMap.to_tile(exact):
			e.path[n - 1] = exact
		elif n == 0:
			e.path.append(exact)


static func _step_toward(e, p: Vector2) -> void:
	var d: float = e.pos.distance_to(p)
	if d < 0.01:
		return
	e.facing = (p - e.pos) / d
	var step := minf(d, _speed(e))
	e.pos += e.facing * step
	e.moved += step


## Intermediate waypoints (tile centres) count as reached within this distance:
## units bunched on one route can't all stand on the exact centre.
const WAYPOINT_SLACK := 8.0
## Ticks without getting any closer to a waypoint before giving up on it.
const WAYPOINT_STALL := 15


## Advances along the current path. Returns true once the end is reached.
static func _follow(e) -> bool:
	var step := _speed(e)
	var start: Vector2 = e.pos
	while step > 0.0 and e.path_index < e.path.size():
		var wp: Vector2 = e.path[e.path_index]
		var d: float = e.pos.distance_to(wp)
		var last: bool = e.path_index == e.path.size() - 1
		if d <= step:
			e.pos = wp
			step -= d
			_next_waypoint(e)
		elif not last and d <= WAYPOINT_SLACK:
			_next_waypoint(e)
		else:
			# Two units pressing for the same point push each other sideways and
			# can orbit it forever: if we stop gaining on it, take it as reached.
			if d < e.wp_best - 0.5:
				e.wp_best = d
				e.wp_stall = 0
			else:
				e.wp_stall += 1
				if e.wp_stall > WAYPOINT_STALL and d < TILE * 0.75:
					_next_waypoint(e)
					continue
			e.facing = (wp - e.pos) / d
			e.pos += e.facing * step
			step = 0.0
	e.moved += start.distance_to(e.pos)
	return e.path_index >= e.path.size()


static func _next_waypoint(e) -> void:
	e.path_index += 1
	e.wp_best = INF
	e.wp_stall = 0
