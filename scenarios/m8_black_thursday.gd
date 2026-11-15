extends "res://scenarios/scenario.gd"
## Chapter 8: Black Thursday (October 1929, Age of Zeppelins).
## The crash. The Federation holds Vienna and four crown-land cities around it.
## Every so often the Concern "buys" a city's debt: its collectors appear inside that
## city's borders, and enemy troops there drain loyalty fast. A city at 0 revolts and
## is lost. Garrisons, quick answers and Federal Charters (loyalty never below 50)
## keep the federation together. Corpse-zeppelins raid between buy-outs.
## Win: hold for HOLD seconds. Lose: three crown lands sold to the dead.

const HOLD := 720.0
const BUYOUT_EVERY := 70.0
const RAID_EVERY := 120.0
const LANDS := ["croatia", "bohemia", "galicia", "transylvania"]
const LOSE_AT := 3


func setup(w) -> void:
	start(w, 1929, "inland", {"map_size": "normal", "start_age": 8, "end_age": 8, "all_ages": true, "resources": "high",
			"difficulty": "easy", "victories": {"conquest": false, "territory": false, "wonders": false, "relics": false}})
	var vienna = capital(w, ME)
	vienna.title = "Vienna (Hofburg)"
	capital(w, FOE).title = "The Concern's Exchange"
	var home: Vector2 = vienna.pos
	var away: Vector2 = (capital(w, FOE).pos - home).normalized()
	# Four crown-land cities on a ring round Vienna, away from the Concern.
	var cities: Array = []
	for i in LANDS.size():
		var a: float = away.angle() + PI + (i - 1.5) * 1.0
		var t := _city_site(w, home + Vector2.from_angle(a) * 12.0 * TILE)
		if t.x < 0:
			continue
		var c = w.spawn_building("residenz", ME, t, true)
		c.crown_land = LANDS[i]
		c.title = DB.crown_lands[LANDS[i]].name
		cities.append(c.id)
		spawn_group(w, "rifleman", ME, c.pos + Vector2(0, 3) * TILE, 2)
	w.refresh_crown_lands(ME)
	w.territory.dirty = true
	var army: Vector2 = home + away * 4.0 * TILE
	hero(w, "archduke", home + Vector2(0, 3) * TILE)
	spawn_group(w, "rifleman", ME, army, 6)
	spawn_group(w, "sturmtrupp", ME, army, 4)
	spawn_group(w, "armoured_car", ME, army, 3)
	spawn_group(w, "biplane", ME, army, 2)
	spawn_group(w, "lorry", ME, army, 1)
	w.players[ME].base_pop_limit += 30
	w.scenario.flags.cities = cities
	w.scenario.flags.buyouts = 0


## Free 4x4 ground near `near` (pixels), at least 9 tiles from other cities.
func _city_site(w, near: Vector2) -> Vector2i:
	var c := GameMap.to_tile(on_map(w, near, 6))
	for r in range(0, 16):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var t := c + Vector2i(dx, dy)
				if not w.map.area_free(t - Vector2i.ONE, Vector2i(6, 6)):
					continue
				var mid := (Vector2(t) + Vector2(2, 2)) * TILE
				if w.entities.values().any(func(e): return e.alive and w.is_city(e) and e.pos.distance_to(mid) < 8.0 * TILE):
					continue
				return t
	return Vector2i(-1, -1)


func update(w, s: Dictionary) -> void:
	if capital(w, ME) == null:
		lose(w, "Vienna has fallen. The Concern owns the Federation now.")
		return
	if once(w, "intro"):
		say(w, "Chancellor", "New York has crashed, Majesty. Every bank in the crown lands is calling in its loans.")
		say(w, "Emperor Franz Ferdinand", "And who is buying the debt?")
		say(w, "Chancellor", "A firm called the Szentkirályi Concern. It pays cash. It pays it to the dead.")
		say(w, "Chancellor", "Where its collectors walk, a city's loyalty bleeds away. Garrison the cities, answer quickly, and grant Federal Charters: a chartered city never falls below half.")
		objective(w, "lands", "Keep the crown lands: lose no more than %d" % (LOSE_AT - 1))
	var lost := _lost(w, s)
	objective(w, "lands", "Keep the crown lands (%d of %d lost; %d loses the chapter)" % [lost, s.flags.cities.size(), LOSE_AT])
	if lost >= LOSE_AT:
		lose(w, "Three crown lands are sold to the dead. The Federation is a company now, and it is not ours.")
		return
	var left := HOLD - elapsed(w)
	objective(w, "hold", "Hold until the markets reopen: %d:%02d" % [int(maxf(0.0, left)) / 60, int(maxf(0.0, left)) % 60])
	if left <= 0.0:
		complete(w, "hold")
		complete(w, "lands")
		win(w, "The markets reopen. The Concern holds paper, but the Federation holds its cities.")
		return
	var t := elapsed(w)
	var n: int = s.flags.buyouts
	if t >= 40.0 + n * BUYOUT_EVERY:
		s.flags.buyouts = n + 1
		_buyout(w, s, n)
	if t >= 100.0 + int(s.flags.get("raids", 0)) * RAID_EVERY:
		s.flags.raids = int(s.flags.get("raids", 0)) + 1
		_raid(w)
	if left <= 120.0 and once(w, "nearly"):
		say(w, "Chancellor", "Two minutes until the markets reopen. Hold on, Majesty.")


func _lost(w, s: Dictionary) -> int:
	var n := 0
	for id in s.flags.cities:
		var c = w.get_entity(int(id))
		if c == null or not c.alive or c.owner != ME:
			n += 1
	return n


## The Concern buys a city's debt: collectors appear inside its borders.
func _buyout(w, s: Dictionary, n: int) -> void:
	var ours: Array = s.flags.cities.map(func(id): return w.get_entity(int(id))).filter(func(c): return c and c.alive and c.owner == ME)
	if ours.is_empty():
		return
	var city = ours[n % ours.size()]
	# The collectors loiter on the far side of the city, inside its borders but out
	# of reach of its guns, and wait for someone to make them leave.
	var out: Vector2 = (city.pos - capital(w, ME).pos).normalized()
	var at: Vector2 = city.pos
	for r in [9.0, 8.0, 7.5, 6.0]:
		var spot: Vector2 = _walkable(w, on_map(w, city.pos + out * r * TILE))
		if w.territory_owner(GameMap.to_tile(spot)) == ME:
			at = spot
			break
	var ids := spawn_group(w, "debt_collector", FOE, at + out * 3.0 * TILE, 6 + n / 2)
	ids.append_array(spawn_group(w, "tommy_ghoul", FOE, at + out * 3.0 * TILE, 3 + n / 3))
	ids.append_array(spawn_group(w, "gas_trooper", FOE, at + out * 3.0 * TILE, n / 4))
	w.issue({"type": "move", "player": FOE, "ids": ids, "pos": at})
	say(w, "Chancellor", "The Concern has bought the debts of %s! Its collectors are in the streets." % city.title)
	if n % 3 == 2:
		var home: Vector2 = capital(w, ME).pos
		spawn_group(w, "rifleman", ME, home, 4)
		spawn_group(w, "sturmtrupp", ME, home, 2)
		say(w, "Field Marshal Boroević", "Another company from the Arsenal, Majesty. They were promised their pay in schillings, not shares.")


## Corpse-zeppelins raid our supply lines and outlying cities.
func _raid(w) -> void:
	var from = capital(w, FOE)
	if from == null:
		return
	var targets: Array = w.entities.values().filter(func(e): return e.alive and e.owner == ME and e.type_id in ["lorry", "settler"])
	var to: Vector2 = targets[0].pos if not targets.is_empty() else capital(w, ME).pos
	wave(w, [["corpse_zeppelin", 2]], from.pos, to)
	say(w, "Scout", "Corpse-zeppelins over the supply roads!")
