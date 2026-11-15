extends "res://scenarios/scenario.gd"
## Chapter 7: Rosabelle, Believe (November 1926, Age of the Federation).
## Part one: take three séance parlours (capture points) where the Concern keeps
## pieces of Houdini's soul; each gives a word of his secret code. With all three,
## Houdini's ghost joins you. Part two: storm the Concern's counting-house. When it
## is hard pressed, Count Szentkirályi steps out, speaks, and walks away.

const CODE := ["\"Rosabelle... answer... tell...\"", "\"...pray, answer... look... tell...\"", "\"...answer, answer... tell.\" Rosabelle, believe."]
## Szentkirályi appears when the counting-house falls below this share of its health.
const APPEAR_AT := 0.6
## And walks away after this many seconds.
const STAYS := 10.0
const WAVE_EVERY := 75.0


func setup(w) -> void:
	start(w, 1926, "inland", {"map_size": "small", "start_age": 7, "end_age": 7, "all_ages": true, "resources": "high",
			"difficulty": "easy", "victories": {"conquest": false, "territory": false, "wonders": false, "relics": false}})
	var vienna = capital(w, ME)
	vienna.title = "Vienna (Hofburg)"
	var house = capital(w, FOE)
	house.title = "The Concern's Counting-House"
	var toward: Vector2 = (house.pos - vienna.pos).normalized()
	var side: Vector2 = toward.orthogonal()
	var army: Vector2 = vienna.pos + toward * 4.0 * TILE
	hero(w, "archduke", army)
	spawn_group(w, "rifleman", ME, army + side * TILE, 6)
	spawn_group(w, "sturmtrupp", ME, army - side * TILE, 4)
	spawn_group(w, "sanitaeter", ME, army - toward * TILE, 2)
	spawn_group(w, "armoured_car", ME, army - toward * 2.0 * TILE, 2)
	w.players[ME].base_pop_limit += 25
	# Three parlours across the middle of the map, each with its staff.
	var names := [["opera", "The Parlour by the Opera"], ["prater", "The Prater Parlour"], ["danube", "The Danube Parlour"]]
	for i in names.size():
		var at: Vector2 = on_map(w, vienna.pos.lerp(house.pos, 0.45 + 0.08 * (i % 2)) + side * (i - 1) * 9.0 * TILE)
		add_point(w, names[i][0], at, names[i][1])
		spawn_group(w, "debt_collector", FOE, at, 5)
		spawn_group(w, "tommy_ghoul", FOE, at, 4)
		spawn_group(w, "gas_trooper", FOE, at, 2)
		spawn_group(w, "necromancer", FOE, at, 2)
	w.scenario.flags.house = house.id
	w.scenario.flags.code = 0


func update(w, s: Dictionary) -> void:
	var duke = _duke(w)
	if duke == null:
		lose(w, "The Emperor has fallen. The Concern will be pleased.")
		return
	if capital(w, ME) == null:
		lose(w, "Vienna is lost.")
		return
	if once(w, "intro"):
		say(w, "Emperor Franz Ferdinand", "A séance. In my capital. Charging admission.")
		say(w, "Sigmund Freud", "Majesty, the bereaved will pay anything to hear a dead voice. Somebody has found a way to make it a business.")
		say(w, "Emperor Franz Ferdinand", "Then we close the business. Every parlour.")
		objective(w, "alive", "The Emperor must survive")
	if s.step == 0:
		_parlours(w, s)
	else:
		_house(w, s)


func _duke(w):
	for e in w.entities.values():
		if e.alive and e.owner == ME and e.type_id == "archduke":
			return e
	return null


func _parlours(w, s: Dictionary) -> void:
	for key in update_points(w):
		var i: int = s.flags.code
		s.flags.code = i + 1
		say(w, "The Medium", CODE[mini(i, CODE.size() - 1)])
	var held := points_held(w)
	objective(w, "parlours", "Shut down the séance parlours (%d/3)" % held)
	if held >= 3:
		complete(w, "parlours")
		s.step = 1
		var at: Vector2 = s.points[-1].pos
		w.get_entity(hero(w, "houdini", at)).title = "Houdini's Ghost"
		say(w, "Houdini's Ghost", "Ten years I spent proving that nobody comes back. Look at me now. Bess will never let me hear the end of it.")
		say(w, "Houdini's Ghost", "The money goes east, Majesty. To a counting-house in Budapest. I'll show you the way.")
		var house = w.get_entity(int(s.flags.house))
		if house:
			s.marker = house.pos
			# The Concern calls in its enforcers to hold the counting-house.
			var guard: Vector2 = house.pos + (capital(w, ME).pos - house.pos).normalized() * 4.0 * TILE
			spawn_group(w, "tommy_ghoul", FOE, guard, 5)
			spawn_group(w, "debt_collector", FOE, guard, 3)
			spawn_group(w, "abomination", FOE, guard, 1)
			mark(w, "march")
		# And Vienna sends what it can spare.
		var home: Vector2 = capital(w, ME).pos
		spawn_group(w, "rifleman", ME, home, 6)
		spawn_group(w, "sturmtrupp", ME, home, 2)
		spawn_group(w, "armoured_car", ME, home, 2)
		spawn_group(w, "landpanzer", ME, home, 2)
		say(w, "Field Marshal Boroević", "Two more companies, the armoured cars, and two Landpanzers from the Arsenal: rifles won't crack a counting-house, Majesty, but shells will. Do try to keep your head down.")
		objective(w, "house", "Storm the Concern's counting-house (capture or destroy it)")


func _house(w, s: Dictionary) -> void:
	var house = w.get_entity(int(s.flags.house))
	# Every 75 seconds the Concern sends the dead out to meet the march.
	if house and house.alive and elapsed(w, "march") >= 40.0 + int(s.flags.get("waves", 0)) * WAVE_EVERY:
		s.flags.waves = int(s.flags.get("waves", 0)) + 1
		var n: int = s.flags.waves
		wave(w, [["tommy_ghoul", 2 + n], ["debt_collector", 1 + n], ["gas_trooper", n / 2]], house.pos, capital(w, ME).pos)
		say(w, "Houdini's Ghost", "More of them coming out of the counting-house. Clerks with guns. Of course.")
	if house == null or not house.alive or house.owner == ME:
		complete(w, "house")
		s.erase("marker")
		win(w, "The counting-house is ours. Its ledgers list ten thousand names, living and dead, and one signature on every page.")
		return
	var share: float = house.hp / maxf(1.0, house.max_hp)
	if share < APPEAR_AT and once(w, "count"):
		var sz = w.spawn_unit("szentkiralyi", FOE, _walkable(w, house.pos + Vector2(0, 3) * TILE))
		s.flags.count_id = sz.id
		mark(w, "count")
		say(w, "Count Szentkirályi", "Your Majesty. You have been closing my branches. Sixty-three, and still so energetic.")
		say(w, "Emperor Franz Ferdinand", "Szentkirályi. We buried your hearse in 1915.")
		say(w, "Count Szentkirályi", "You buried a hearse. I have been busy. Keep the building; I have others. Do give my regards to your paperwork.")
	if s.flags.has("count") and elapsed(w, "count") >= STAYS and once(w, "count_gone"):
		var sz = w.get_entity(int(s.flags.count_id))
		if sz and sz.alive:
			w.events.append({"type": "cloud", "pos": sz.pos, "radius": 2.0 * TILE, "duration": 3.0, "color": [0.3, 0.9, 0.4, 0.4]})
			w.kill(sz)
		say(w, "Houdini's Ghost", "Gone. Not a trapdoor, not a mirror. That was the real thing, and he wasn't even trying.")
