extends "res://scenarios/scenario.gd"
## Chapter 3: The Federation (1915, Age of the Golden Lane).
## Found cities and proclaim three crown lands. Halfway there, Hungary secedes:
## Szentkirályi's stronghold rises in the middle of the map (the Hungarian third
## side) and Tesla comes home. Win by taking the stronghold with the lands proclaimed.
## The Covenant is a quiet Easy AI in the far corner: a nuisance, not the target.

const LANDS := 3
## Hungary secedes once this many lands are proclaimed, or after this long.
const SECEDE_LANDS := 2
const SECEDE_AT := 540.0


func setup(w) -> void:
	start(w, 1915, "inland", {"map_size": "normal", "start_age": 3, "resources": "high", "difficulty": "easy",
			"victories": {"conquest": false, "territory": false, "wonders": false, "relics": false}})
	capital(w, ME).title = "Vienna (Hofburg)"
	capital(w, FOE).title = "Covenant Barrow"
	var home: Vector2 = capital(w, ME).pos + Vector2(0, 3) * TILE
	hero(w, "archduke", home)
	spawn_group(w, "grenadier", ME, home + Vector2(2, 0) * TILE, 5)
	spawn_group(w, "jaeger", ME, home - Vector2(2, 0) * TILE, 4)
	spawn_group(w, "settler", ME, capital(w, ME).pos - Vector2(0, 3) * TILE, 4)


func update(w, s: Dictionary) -> void:
	var vienna = capital(w, ME)
	if vienna == null:
		lose(w, "Vienna has fallen. The Federation dies before it is born.")
		return
	if once(w, "intro"):
		say(w, "Emperor Franz Ferdinand", "Croats, Czechs, Slovenes, Poles, Romanians: an empire of equals or no empire at all.")
		say(w, "Chancellor", "Found new cities with Settlers, then proclaim each as a crown land from its card. Every crown land brings its own regiments.")
	var lands := _lands(w)
	objective(w, "lands", "Proclaim %d crown lands (%d/%d)" % [LANDS, mini(lands, LANDS), LANDS])
	if lands >= LANDS:
		complete(w, "lands")
	if lands == 1 and once(w, "first_land"):
		say(w, "Chancellor", "The first crown land is proclaimed. In Budapest, they have stopped smiling.")
	if not w.hungary_risen and (lands >= SECEDE_LANDS or elapsed(w) >= SECEDE_AT):
		_secede(w, s)
	if w.hungary_risen:
		_against_hungary(w, s, lands)


func _lands(w) -> int:
	var n := 0
	for e in w.entities.values():
		if e.alive and e.owner == ME and w.is_city(e) and e.crown_land != "" and not DB.crown_lands[e.crown_land].get("capital", false):
			n += 1
	return n


func _secede(w, s: Dictionary) -> void:
	w.hungary_rises()
	var hold = w.get_entity(w.players[w.rebels].capital_id)
	if hold == null:
		return
	hold.title = "Szentkirályi's Stronghold"
	s.flags.stronghold = hold.id
	s.marker = hold.pos
	mark(w, "seceded")
	say(w, "Courier", "From Budapest: the Diet has declared Hungary free of Vienna. Count Szentkirályi raises the Honvéd and the Hussars.")
	say(w, "Franz Joseph", "Sixty-seven years I have held this together. I find I am tired. Franzi, the crown is yours. Do not lose Hungary twice.")
	say(w, "Emperor Franz Ferdinand", "We will not lose it, Uncle. We will free it.")
	var at: Vector2 = capital(w, ME).pos + Vector2(3, 3) * TILE
	w.get_entity(hero(w, "tesla", at)).title = "Nikola Tesla"
	spawn_group(w, "kuerassier", ME, at, 3)
	say(w, "Nikola Tesla", "I came from New York on the first ship. Your Majesty's laboratories are a disgrace, and I am delighted to fix them.")
	objective(w, "stronghold", "Take Szentkirályi's stronghold (capture the city)")


func _against_hungary(w, s: Dictionary, lands: int) -> void:
	var hold = w.get_entity(int(s.flags.get("stronghold", -1)))
	var taken: bool = hold == null or not hold.alive or hold.owner == ME
	if taken:
		complete(w, "stronghold")
		if once(w, "taken"):
			say(w, "Emperor Franz Ferdinand", "Szentkirályi has fled east. He left in a hurry, and he left in a hearse.")
			s.erase("marker")
	if taken and lands >= LANDS:
		win(w, "The crown lands are proclaimed. Hungary's rebels are scattered, and their leader rode east to someone who is not alive.")
	elif taken and once(w, "need_lands"):
		say(w, "Chancellor", "The stronghold is ours. Now finish the proclamations: %d crown lands." % LANDS)
	if elapsed(w, "seceded") >= 60.0 and once(w, "hint"):
		say(w, "Field Marshal", "The Hungarians fight the dead as hard as they fight us. Let them bleed each other.")
