extends "res://scenarios/scenario.gd"
## Chapter 10: The Long Winter (the Carpathians, winter 1941, Age of Radar).
## A front: the Federation holds three passes; the Concern's winter offensive
## strikes them in turn under a séance-fog. Losing all three at once loses. At four
## minutes Tesla brings his radar online. After eight minutes, break through and
## take the Concern's winter headquarters (it collapses at 1 HP).
## The Concern is scripted here (no AI).

const HOLD := 480.0
const RADAR_AT := 240.0
const WAVE_EVERY := 50.0


func setup(w) -> void:
	start(w, 1941, "inland", {"map_size": "normal", "start_age": 10, "end_age": 10, "all_ages": true, "resources": "high",
			"difficulty": "easy", "victories": {"conquest": false, "territory": false, "wonders": false, "relics": false}}, false)
	w.scenario.weather = {"snow": true, "night": 0.35}
	var home = capital(w, ME)
	home.title = "Lemberg Headquarters"
	var hq = capital(w, FOE)
	hq.title = "The Concern's Winter Headquarters"
	var toward: Vector2 = (hq.pos - home.pos).normalized()
	var side: Vector2 = toward.orthogonal()
	var line: Vector2 = home.pos.lerp(hq.pos, 0.45)
	var names := [["dukla", "The Dukla Pass"], ["uzsok", "The Uzsok Pass"], ["tatar", "The Tatar Pass"]]
	for i in names.size():
		var at: Vector2 = on_map(w, line + side * (i - 1) * 10.0 * TILE)
		add_point(w, names[i][0], at, names[i][1])
		var pt: Dictionary = w.scenario.points[-1]
		pt.owner = ME
		pt.progress = 1.0
		spawn_group(w, "rifleman", ME, pt.pos - toward * TILE, 4)
		spawn_group(w, "sturmtrupp", ME, pt.pos - toward * 2.0 * TILE, 2)
	w.scenario.markers = []
	var army: Vector2 = home.pos + toward * 4.0 * TILE
	w.get_entity(hero(w, "tesla", army)).title = "Nikola Tesla"
	spawn_group(w, "light_tank", ME, army, 3)
	spawn_group(w, "rocket_battery", ME, army - toward * TILE, 2)
	spawn_group(w, "rocket_trooper", ME, army + side * TILE, 3)
	spawn_group(w, "sanitaeter", ME, army - side * TILE, 2)
	spawn_group(w, "settler", ME, home.pos - toward * 3.0 * TILE, 4)
	w.players[ME].base_pop_limit += 40
	w.scenario.flags.hq = hq.id


func update(w, s: Dictionary) -> void:
	if capital(w, ME) == null:
		lose(w, "Lemberg has fallen and the road to Vienna is open.")
		return
	if w.type_count(ME, "tesla") == 0:
		lose(w, "Tesla is dead before his radar ever turned.")
		return
	if once(w, "intro"):
		say(w, "Field Marshal Boroević", "Three passes, Majesty: Dukla, Uzsok and the Tatar. The dead come through all three, and the fog comes with them.")
		say(w, "Nikola Tesla", "Fog that a séance makes, a radio wave can unmake. Give me four minutes and the use of a lorry.")
		objective(w, "tesla", "Nikola Tesla must survive")
	var front := update_front(w)
	for key in front.lost:
		say(w, "Scout", "We have lost %s!" % _label(s, key))
	for key in front.taken:
		say(w, "Scout", "%s is ours again!" % _label(s, key))
	var held := points_held(w)
	if s.step == 0:
		if held == 0:
			lose(w, "All three passes are lost. The winter belongs to the dead.")
			return
		var left := HOLD - elapsed(w)
		objective(w, "passes", "Hold the passes (%d/3) for %d:%02d" % [held, int(maxf(0.0, left)) / 60, int(maxf(0.0, left)) % 60])
		var n: int = int(s.flags.get("waves", 0))
		if elapsed(w) >= 30.0 + n * WAVE_EVERY:
			s.flags.waves = n + 1
			_wave(w, s, n)
		if elapsed(w) >= RADAR_AT and once(w, "radar"):
			_radar(w)
		if left <= 0.0:
			complete(w, "passes")
			s.step = 1
			var hq = w.get_entity(int(s.flags.hq))
			if hq:
				s.marker = hq.pos
				var gate: Vector2 = hq.pos + (capital(w, ME).pos - hq.pos).normalized() * 3.0 * TILE
				spawn_group(w, "frost_dead", FOE, gate, 8)
				spawn_group(w, "plated_abomination", FOE, gate, 2)
				spawn_group(w, "undead_panzer", FOE, gate, 1)
			spawn_group(w, "heavy_tank", ME, capital(w, ME).pos, 2)
			spawn_group(w, "paratrooper", ME, capital(w, ME).pos, 6)
			say(w, "Emperor Franz Ferdinand", "The passes held. Now we go through them. All of us.")
			objective(w, "hq", "Break through and take the Concern's winter headquarters")
	else:
		var hq = w.get_entity(int(s.flags.hq))
		if hq and hq.alive and hq.hp <= 1.0:
			w.events.append({"type": "cloud", "pos": hq.pos, "radius": 4.0 * TILE, "duration": 5.0, "color": [0.8, 0.8, 0.85, 0.6]})
			w.kill(hq)
		if hq == null or not hq.alive or hq.owner == ME:
			complete(w, "hq")
			s.erase("marker")
			win(w, "The winter headquarters burns. The Concern's offensive is broken in the snow. Tesla goes back to Vienna, and does not see another spring at war's end: he dies in January 1943, as he did in our history.")


func _label(s: Dictionary, key: String) -> String:
	for pt in s.points:
		if pt.key == key:
			return pt.label
	return key


## The winter offensive strikes one pass at a time, harder each time.
func _wave(w, s: Dictionary, n: int) -> void:
	var hq = capital(w, FOE)
	if hq == null:
		return
	var pt: Dictionary = s.points[n % s.points.size()]
	var from: Vector2 = hq.pos.lerp(pt.pos, 0.4)
	wave(w, [["frost_dead", 3 + n / 2], ["tommy_ghoul", 1 + n / 3], ["gas_trooper", n / 4], ["undead_panzer", n / 5]], from, pt.pos)
	if n == 0:
		say(w, "Scout", "They are coming out of the fog at %s!" % pt.label)


## Tesla's radar: the séance-fog lifts and the whole front is seen.
func _radar(w) -> void:
	var home = capital(w, ME)
	var radar = w.spawn_unit("radar_truck", ME, _walkable(w, home.pos + Vector2(2, 2) * TILE))
	radar.title = "Tesla's Radar"
	w.players[ME].vis.fill(1)
	w.fog_version += 1
	spawn_group(w, "rifleman", ME, home.pos + Vector2(0, 3) * TILE, 4)
	spawn_group(w, "light_tank", ME, home.pos + Vector2(2, 3) * TILE, 2)
	say(w, "Nikola Tesla", "There. Every dead thing on this mountain, as a green dot on a screen. Death is very easy to see, once you know its frequency.")
	say(w, "Emperor Franz Ferdinand", "Thank you, Mr. Tesla.")
	say(w, "Nikola Tesla", "Do not thank me, Majesty. Win. I am eighty-five and I would like to see it.")
