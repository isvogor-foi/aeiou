extends "res://scenarios/scenario.gd"
## Chapter 6: Viribus Unitis (1918, Age of the Aether Monarchy).
## Part one: bring the five A.E.I.O.U. relics home and hold them. Part two: storm
## Rudolf's seat at Buda and destroy the Umbral Sovereign. The Iron Emperor marches
## with the army; he does not survive the day (the cost of the triumph).


func setup(w) -> void:
	# Normal, not Hard: a Hard AI sees the whole map and had all five relics home
	# before the player could scout them. Relic victory is the player's alone here
	# (checked below); the Covenant has to be fought for the relics it hoards.
	start(w, 1867, "coastal", {"map_size": "normal", "start_age": 6, "resources": "high", "difficulty": "normal",
			"victories": {"territory": false, "wonders": false, "relics": false}})
	capital(w, ME).title = "Vienna (Hofburg)"
	capital(w, FOE).title = "Buda Castle"
	# The Hofburg garrison: enough to hold the first wave and to scout for relics.
	var home: Vector2 = capital(w, ME).pos + Vector2(0, 3) * TILE
	hero(w, "archduke", home)
	spawn_group(w, "kaiserjaeger", ME, home, 6)
	spawn_group(w, "jaeger", ME, home + Vector2(2, 0) * TILE, 3)
	spawn_group(w, "kuerassier", ME, home + Vector2(-2, 0) * TILE, 3)


func update(w, s: Dictionary) -> void:
	if once(w, "intro"):
		say(w, "Emperor Franz Ferdinand", "Five relics of the House, five vowels: A.E.I.O.U. Rudolf needs them to crown himself. We need them to crown the Federation.")
		say(w, "Chancellor", "Send riders out: the relics are scattered across the land. Carry them to any of our cities.")
		say(w, "Franz Joseph, the Iron Emperor", "And when they are home, we go to Buda. All of us. I have an appointment with my son.")
	if s.step == 0:
		_relics(w, s)
	else:
		_buda(w, s)


func _relics(w, s: Dictionary) -> void:
	var relics: int = w.relics_stored(ME)
	var hold := float(w.rules.victory.relic_hold)
	if relics >= 5:
		if not s.flags.has("relics_held"):
			mark(w, "relics_held")
			w.events.append({"type": "victory_countdown", "player": ME, "reason": "relics", "seconds": hold})
			say(w, "Chancellor", "All five relics are ours! Hold them for %d minutes while the crown lands gather." % int(hold / 60.0))
		var left := maxf(0.0, hold - elapsed(w, "relics_held"))
		objective(w, "relics", "Hold all five A.E.I.O.U. relics: the crown lands march in %d:%02d" % [int(left) / 60, int(left) % 60])
		if left <= 0.0:
			complete(w, "relics")
			_storm(w, s)
	else:
		if s.flags.has("relics_held"):
			s.flags.erase("relics_held")
			say(w, "Chancellor", "A relic is lost! Take it back before the crown lands can march.")
		objective(w, "relics", "Store the five A.E.I.O.U. relics in your cities and hold them (%d/5)" % relics)
	if w.relics_stored(FOE) >= 3 and once(w, "foe_hoards"):
		say(w, "Scout", "The Covenant is carrying relics into Buda. We'll have to storm it to take them back.")


func _storm(w, s: Dictionary) -> void:
	s.step = 1
	mark(w, "storm")
	var buda = capital(w, FOE)
	var target: Vector2 = buda.pos if buda else w.map.width * TILE * Vector2(0.5, 0.5)
	spawn_boss(w, "rudolf_sovereign", target + Vector2(0, 3) * TILE)
	var home: Vector2 = capital(w, ME).pos
	var at: Vector2 = home + (target - home).normalized() * 4.0 * TILE
	s.flags.emperor = hero(w, "iron_emperor", at)
	w.get_entity(hero(w, "tesla", at + Vector2(2, 0) * TILE)).title = "Nikola Tesla"
	w.get_entity(hero(w, "houdini", at - Vector2(2, 0) * TILE)).title = "Harry Houdini"
	# Every crown land sends a regiment.
	spawn_group(w, "grenzer", ME, at + Vector2(0, 2) * TILE, 4)
	spawn_group(w, "standschuetze", ME, at + Vector2(0, -2) * TILE, 4)
	spawn_group(w, "war_wagon", ME, at, 1)
	spawn_group(w, "aether_colossus", ME, at, 1)
	s.marker = target
	say(w, "Emperor Franz Ferdinand", "Croatia, Bohemia, Carniola, Galicia, Transylvania, Austria. All of them, under one banner. To Buda!")
	say(w, "Crown Prince Rudolf", "Cousin. You brought my father. How thoughtful. I have so much to tell him.")
	objective(w, "rudolf", "Storm Buda and destroy Rudolf, the Umbral Sovereign")


func _buda(w, s: Dictionary) -> void:
	var b = boss(w)
	var emperor = w.get_entity(int(s.flags.get("emperor", -1)))
	if b == null:
		complete(w, "rudolf")
		s.erase("marker")
		if emperor and emperor.alive:
			say(w, "Franz Joseph, the Iron Emperor", "The gauge is in the red, Mr. Tesla. Do not fix it. Franzi... we won one.")
			w.kill(emperor)
		win(w, "Rudolf is ended. The Iron Emperor's boilers go quiet on the walls of Buda. Viribus Unitis.")
		return
	if emperor and not emperor.alive and once(w, "emperor_fell"):
		say(w, "Emperor Franz Ferdinand", "The Emperor is down! Finish this, for him!")
	match boss_phase(w, [0.66, 0.33]):
		1:
			say(w, "Crown Prince Rudolf", "Father! Do you remember Mayerling? You wept for an empty coffin.")
			say(w, "Franz Joseph, the Iron Emperor", "I wept for my son. I see now I was right to.")
			wave(w, [["lich", 2], ["bone_golem", 3], ["risen", 10]], b.pos, b.pos)
		2:
			say(w, "Crown Prince Rudolf", "Every one of your dead is mine to raise! Every one!")
			say(w, "Harry Houdini", "It is a trick. Nobody gets every one. Keep hitting him!")
			wave(w, [["bone_colossus", 1], ["wraith", 6]], b.pos, b.pos)
