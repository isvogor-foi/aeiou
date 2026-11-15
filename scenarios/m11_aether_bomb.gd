extends "res://scenarios/scenario.gd"
## Chapter 11: The Aether Bomb (the Pannonian plain, 1945, Age of the Atom).
## Take two relay pylons to triangulate the Concern's soul reactor. Then a choice:
## drop Lise Meitner's Aether bomb (it ends the chapter at once, and leaves a scar
## Chapter 12 remembers) or go in on foot against the reactor's full garrison and
## its Reactor Lich, and break the reactor (it collapses at 1 HP).
## Lise Meitner must survive. The Concern is scripted (no AI).

const BOMB_RADIUS := 7.0


func setup(w) -> void:
	start(w, 1945, "inland", {"map_size": "normal", "start_age": 11, "end_age": 11, "all_ages": true, "resources": "high",
			"difficulty": "easy", "victories": {"conquest": false, "territory": false, "wonders": false, "relics": false}}, false)
	w.scenario.weather = {"night": 0.25}
	var home = capital(w, ME)
	home.title = "Pressburg Field Headquarters"
	var reactor = capital(w, FOE)
	reactor.title = "The Soul Reactor"
	var toward: Vector2 = (reactor.pos - home.pos).normalized()
	var side: Vector2 = toward.orthogonal()
	for i in 2:
		var at: Vector2 = on_map(w, home.pos.lerp(reactor.pos, 0.5) + side * (i * 2 - 1) * 9.0 * TILE)
		add_point(w, "pylon%d" % i, at, ["The North Relay", "The South Relay"][i])
		spawn_group(w, "frost_dead", FOE, at, 5)
		spawn_group(w, "reactor_ghoul", FOE, at, 3)
		spawn_group(w, "plated_abomination", FOE, at, 1)
	var army: Vector2 = home.pos + toward * 4.0 * TILE
	w.get_entity(hero(w, "lise_meitner", home.pos - toward * 2.0 * TILE)).title = "Lise Meitner"
	spawn_group(w, "atom_trooper", ME, army, 6)
	spawn_group(w, "rifleman", ME, army + side * TILE, 6)
	spawn_group(w, "flame_trooper", ME, army - side * TILE, 3)
	spawn_group(w, "heavy_tank", ME, army - toward * TILE, 2)
	spawn_group(w, "rocket_battery", ME, army - toward * 2.0 * TILE, 2)
	spawn_group(w, "jet", ME, army, 2)
	w.players[ME].base_pop_limit += 40
	w.scenario.flags.reactor = reactor.id


func update(w, s: Dictionary) -> void:
	if capital(w, ME) == null:
		lose(w, "Pressburg is lost.")
		return
	if w.type_count(ME, "lise_meitner") == 0:
		lose(w, "Lise Meitner is dead, and her secret with her.")
		return
	if once(w, "intro"):
		say(w, "Lise Meitner", "Somewhere on this plain the Concern has built a reactor that runs on souls. When it reaches full power it will raise every grave from Pressburg to Belgrade.")
		say(w, "Lise Meitner", "Take the two relay pylons and I can find it. And then, Majesty, you will have to decide what to do with what I have built.")
		objective(w, "lise", "Lise Meitner must survive")
	match s.step:
		0:
			for _key in update_points(w):
				say(w, "Lise Meitner", "A relay is ours. I can hear the reactor humming through it.")
			objective(w, "pylons", "Take the relay pylons (%d/2)" % points_held(w))
			if points_held(w) >= 2:
				complete(w, "pylons")
				s.step = 1
				var reactor = w.get_entity(int(s.flags.reactor))
				s.marker = reactor.pos
				ask(w, "bomb", "The Aether Bomb",
						"Lise Meitner has found the reactor. Her Aether bomb would end it in a single flash, and leave a wound in the plain that will glow for a hundred years. Or the army can go in on foot, against everything the Concern has left.",
						[["drop", "Drop the Aether bomb"], ["foot", "Go in on foot"]])
		1:
			match answered(w, "bomb"):
				"drop":
					_drop(w, s)
				"foot":
					_foot(w, s)
		2:
			_assault(w, s)


func _drop(w, s: Dictionary) -> void:
	s.step = 3
	var reactor = w.get_entity(int(s.flags.reactor))
	w.events.append({"type": "bomb", "pos": reactor.pos, "radius": BOMB_RADIUS * TILE})
	for e in w.entities.values():
		if e.alive and e.owner == FOE and e.pos.distance_to(reactor.pos) <= BOMB_RADIUS * TILE:
			w.kill(e)
	say(w, "Lise Meitner", "...It is done. I wanted to understand the world, Majesty. I did not want to light it.")
	complete(w, "reactor")
	win(w, "The soul reactor is gone, and the plain glows where it stood. The dead lie down again from Pressburg to Belgrade. The scar will outlive everyone who saw it.")


func _foot(w, s: Dictionary) -> void:
	s.step = 2
	var reactor = w.get_entity(int(s.flags.reactor))
	var gate: Vector2 = reactor.pos + (capital(w, ME).pos - reactor.pos).normalized() * 3.0 * TILE
	spawn_boss(w, "lich_general", gate, 0.6)
	w.get_entity(int(w.scenario.boss)).title = "The Reactor Lich"
	spawn_group(w, "reactor_ghoul", FOE, gate, 6)
	spawn_group(w, "frost_dead", FOE, gate, 6)
	spawn_group(w, "undead_panzer", FOE, gate, 2)
	spawn_group(w, "atom_trooper", ME, capital(w, ME).pos, 6)
	spawn_group(w, "flame_trooper", ME, capital(w, ME).pos, 3)
	spawn_group(w, "heavy_tank", ME, capital(w, ME).pos, 2)
	say(w, "Emperor Franz Ferdinand", "We go in on foot. Nobody will light the plain on my signature.")
	say(w, "Lise Meitner", "Thank you, Majesty. Then I am coming too.")
	objective(w, "reactor", "Break the soul reactor (and its Reactor Lich)")


func _assault(w, s: Dictionary) -> void:
	var reactor = w.get_entity(int(s.flags.reactor))
	if reactor and reactor.alive and reactor.hp <= 1.0:
		w.events.append({"type": "cloud", "pos": reactor.pos, "radius": 4.0 * TILE, "duration": 5.0, "color": [0.45, 1.0, 0.45, 0.5]})
		w.kill(reactor)
	if reactor == null or not reactor.alive or reactor.owner == ME:
		complete(w, "reactor")
		win(w, "The reactor is broken by hand, and the dead of the plain lie down again. Nothing glows here but the dawn.")
		return
	match boss_phase(w, [0.5]):
		1:
			var b = boss(w)
			say(w, "The Reactor Lich", "Every soul on this plain is fuel. Including yours.")
			wave(w, [["frost_dead", 6], ["reactor_ghoul", 3]], b.pos, b.pos)
