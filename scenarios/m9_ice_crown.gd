extends "res://scenarios/scenario.gd"
## Chapter 9: The Ice Crown (Franz Josef Land, 1934, Age of Diesel).
## In snow, three phases: set up camp (build a Kaserne before the light goes),
## hold through the polar night against waves of the Frost Dead, then at dawn
## destroy the Concern's foundry under the glacier, guarded by the Ice Engine.
## Hedy Lamarr runs the camp radio and must survive. The Concern here is an outpost,
## not a growing city: no AI, only the scripted waves and the foundry's garrison.

const CAMP_TIME := 180.0
const NIGHT := 300.0
const WAVE_EVERY := 60.0


func setup(w) -> void:
	start(w, 1934, "coastal", {"map_size": "small", "start_age": 9, "end_age": 9, "all_ages": true, "resources": "high",
			"difficulty": "easy", "victories": {"conquest": false, "territory": false, "wonders": false, "relics": false}}, false)
	w.scenario.weather = {"snow": true, "night": 0.2}
	var camp = capital(w, ME)
	camp.title = "Camp Tegetthoff"
	var foundry = capital(w, FOE)
	foundry.title = "The Foundry under the Glacier"
	var toward: Vector2 = (foundry.pos - camp.pos).normalized()
	var at: Vector2 = camp.pos + toward * 4.0 * TILE
	w.get_entity(hero(w, "hedy_lamarr", camp.pos - toward * 3.5 * TILE)).title = "Hedy Lamarr"
	spawn_group(w, "arctic_trooper", ME, at, 8)
	spawn_group(w, "sturmtrupp", ME, at + toward.orthogonal() * TILE, 4)
	spawn_group(w, "light_tank", ME, at - toward * TILE, 2)
	spawn_group(w, "halftrack", ME, at - toward * 2.0 * TILE, 1)
	spawn_group(w, "settler", ME, camp.pos - toward * 3.0 * TILE, 3)
	w.players[ME].base_pop_limit += 30
	w.scenario.flags.camp = camp.id
	w.scenario.flags.foundry = foundry.id


func update(w, s: Dictionary) -> void:
	var camp = w.get_entity(int(s.flags.camp))
	if camp == null or not camp.alive or camp.owner != ME:
		lose(w, "Camp Tegetthoff is lost to the ice.")
		return
	if w.type_count(ME, "hedy_lamarr") == 0:
		lose(w, "Hedy Lamarr is dead. The radio is silent.")
		return
	if once(w, "intro"):
		say(w, "Hedy Lamarr", "Camp Tegetthoff to Vienna. We are down on the ice, eighty-one degrees north. The Austro-Hungarian flag is still on the cairn from 1873.")
		say(w, "Emperor Franz Ferdinand", "And the Concern?")
		say(w, "Hedy Lamarr", "Smoke under the glacier, Majesty. Something down there is very busy, and it does not need daylight. We have a few hours of it left.")
		objective(w, "alive", "Hedy Lamarr must survive")
	match s.step:
		0:
			_camp(w, s)
		1:
			_night(w, s, camp)
		2:
			_dawn(w, s)


func _camp(w, s: Dictionary) -> void:
	var left := CAMP_TIME - elapsed(w)
	objective(w, "camp", "Build a Kaserne before the light goes (%d:%02d)" % [int(maxf(0.0, left)) / 60, int(maxf(0.0, left)) % 60])
	var built: bool = w.entities.values().any(func(e): return e.alive and e.owner == ME and e.type_id == "kaserne" and not e.constructing)
	if built:
		complete(w, "camp")
	if left <= 0.0:
		s.step = 1
		mark(w, "night")
		w.scenario.weather.night = 1.0
		say(w, "Hedy Lamarr", "The sun is gone. It will not be back for a long time. And now I can hear them on the wireless: counting.")
		objective(w, "night", "Hold the camp through the polar night")


func _night(w, s: Dictionary, camp) -> void:
	var left := NIGHT - elapsed(w, "night")
	objective(w, "night", "Hold the camp through the polar night (%d:%02d)" % [int(maxf(0.0, left)) / 60, int(maxf(0.0, left)) % 60])
	var n: int = int(s.flags.get("waves", 0))
	if elapsed(w, "night") >= 20.0 + n * WAVE_EVERY:
		s.flags.waves = n + 1
		var foundry = w.get_entity(int(s.flags.foundry))
		var from: Vector2 = foundry.pos.lerp(camp.pos, 0.35) if foundry else camp.pos + Vector2(20, 20) * TILE
		wave(w, [["frost_dead", 3 + n], ["tommy_ghoul", 1 + n], ["bone_halftrack", n / 3]], from, camp.pos)
		if n == 0:
			say(w, "Hedy Lamarr", "Movement on the ice. They are wearing our parkas. Older ones. From 1873.")
		if n == 2:
			say(w, "Hedy Lamarr", "I am jamming their wireless. Without it they only know where to walk, not when. Use it.")
			# Halfway through the night, the supply zeppelin finds the camp.
			spawn_group(w, "arctic_trooper", ME, camp.pos + Vector2(0, 3) * TILE, 4)
			spawn_group(w, "sturmtrupp", ME, camp.pos + Vector2(2, 3) * TILE, 2)
			say(w, "Hedy Lamarr", "And there is the supply zeppelin! Six more of ours coming down the ropes. Bless the Navy.")
	if left <= 0.0:
		complete(w, "night")
		s.step = 2
		w.scenario.weather.night = 0.15
		# Sunrise: the night's attackers near the camp freeze where they stand.
		var frozen := 0
		for e in w.entities.values():
			if e.alive and e.owner == FOE and e.kind == Entity.UNIT and e.pos.distance_to(camp.pos) < 16.0 * TILE:
				w.events.append({"type": "cloud", "pos": e.pos, "radius": TILE, "duration": 3.0, "color": [0.85, 0.95, 1.0, 0.5]})
				w.kill(e)
				frozen += 1
		if frozen > 0:
			say(w, "Hedy Lamarr", "The sun is up and they have stopped. Frozen where they stood, %d of them. The ice takes back what it lends." % frozen)
		var foundry = w.get_entity(int(s.flags.foundry))
		if foundry:
			s.marker = foundry.pos
			spawn_boss(w, "grave_engine", foundry.pos + (camp.pos - foundry.pos).normalized() * 4.0 * TILE, 0.3)
			w.get_entity(int(w.scenario.boss)).title = "The Ice Engine"
			# The foundry's own garrison stands in the glacier's mouth.
			var mouth: Vector2 = foundry.pos + (camp.pos - foundry.pos).normalized() * 2.0 * TILE
			spawn_group(w, "frost_dead", FOE, mouth, 6)
			spawn_group(w, "tommy_ghoul", FOE, mouth, 4)
			spawn_group(w, "undead_panzer", FOE, mouth, 1)
		spawn_group(w, "heavy_tank", ME, camp.pos, 2)
		say(w, "Hedy Lamarr", "Dawn. Two of Porsche's heavy tanks came down on the supply zeppelin in the night. The foundry is in the glacier's mouth. Let us close it.")
		objective(w, "foundry", "Destroy the foundry under the glacier")


func _dawn(w, s: Dictionary) -> void:
	var foundry = w.get_entity(int(s.flags.foundry))
	# Cities hold at 1 HP until captured; this one is meant to fall: it collapses.
	if foundry and foundry.alive and foundry.hp <= 1.0:
		w.events.append({"type": "cloud", "pos": foundry.pos, "radius": 4.0 * TILE, "duration": 5.0, "color": [0.85, 0.95, 1.0, 0.6]})
		w.kill(foundry)
	if foundry == null or not foundry.alive or foundry.owner == ME:
		complete(w, "foundry")
		s.erase("marker")
		win(w, "The foundry collapses into the glacier. In its office, a ledger: shipments of the dead, south, to the Carpathians.")
		return
	match boss_phase(w, [0.5]):
		1:
			var b = boss(w)
			say(w, "Hedy Lamarr", "The Engine is calling the ice. More of them, coming up out of the crevasses!")
			wave(w, [["frost_dead", 6], ["undead_panzer", 1]], b.pos, b.pos)
