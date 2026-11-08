extends "res://scenarios/scenario.gd"
## Mission 3: Viribus Unitis. Unite the crown lands and bring the five A.E.I.O.U.
## relics home to become the Federation the shot in Sarajevo failed to stop.


func setup(w) -> void:
	# Normal, not Hard: a Hard AI sees the whole map and had all five relics home
	# before the player could scout them. Relic victory is the player's alone here
	# (checked below); the Covenant has to be fought for the relics it hoards.
	start(w, 1867, "coastal", {"map_size": "normal", "start_age": 5, "resources": "high", "difficulty": "normal",
			"victories": {"territory": false, "wonders": false, "relics": false}})
	capital(w, ME).title = "Vienna (Hofburg)"
	# The Hofburg garrison: enough to hold the first wave and to scout for relics.
	var home: Vector2 = capital(w, ME).pos + Vector2(0, 3) * TILE
	spawn_group(w, "kaiserjaeger", ME, home, 6)
	spawn_group(w, "jaeger", ME, home + Vector2(2, 0) * TILE, 3)
	spawn_group(w, "kuerassier", ME, home + Vector2(-2, 0) * TILE, 3)


func update(w, s: Dictionary) -> void:
	if once(w, "intro"):
		say(w, "Archduke Franz Ferdinand", "Croats, Czechs, Tyroleans, Magyars: an empire of equals or no empire at all. Proclaim the crown lands and recover the relics.")
		say(w, "Chancellor", "Found new cities and proclaim them as crown lands. Federal Charters keep distant cities loyal.")
		say(w, "Field Marshal", "The Hofburg garrison stands ready. Send riders out: the relics are scattered across the land, and the Covenant is hunting them too.")
	var lands := 0
	for e in w.entities.values():
		if e.alive and e.owner == ME and w.is_city(e) and e.crown_land != "":
			lands += 1
	objective(w, "lands", "Proclaim 3 crown lands (%d/3)" % mini(lands, 3))
	if lands >= 3:
		complete(w, "lands")
	var relics: int = w.relics_stored(ME)
	var hold := float(w.rules.victory.relic_hold)
	if relics >= 5:
		if not s.flags.has("relics_held"):
			mark(w, "relics_held")
			w.events.append({"type": "victory_countdown", "player": ME, "reason": "relics", "seconds": hold})
			say(w, "Chancellor", "All five relics are ours! Hold them for %d minutes and the Federation is proclaimed." % int(hold / 60.0))
		var left := maxf(0.0, hold - elapsed(w, "relics_held"))
		objective(w, "relics", "Hold all five A.E.I.O.U. relics: the Federation is proclaimed in %d:%02d" % [int(left) / 60, int(left) % 60])
		if left <= 0.0:
			complete(w, "relics")
			win(w, "Viribus Unitis! With the five relics in Vienna the crown lands proclaim the Federation.")
	else:
		if s.flags.has("relics_held"):
			s.flags.erase("relics_held")
			say(w, "Chancellor", "A relic is lost! Take it back before the Federation can be proclaimed.")
		objective(w, "relics", "Store the five A.E.I.O.U. relics in your cities and hold them (%d/5)" % relics)
	if w.relics_stored(FOE) >= 3 and once(w, "foe_hoards"):
		say(w, "Scout", "The Covenant is carrying relics into its cities. We'll have to storm them to take them back.")
