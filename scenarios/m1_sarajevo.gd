extends "res://scenarios/scenario.gd"
## Mission 1: Sarajevo, 28 June 1914. Escort the Archduke's convoy past the Station,
## along the Appel Quay and over the Latin Bridge to the Town Hall. Each stop is
## guarded by Covenant ambushers. In this history, the shot misses.

const ARRIVE := 4.0 * TILE
## When the Archduke comes this close to the next stop, its ambush springs.
const SPRING := 11.0 * TILE
const STOPS := [
	["the Station", [["thrall", 8], ["bonebow", 3]], "Covenant thralls around the Station! Close up around the Archduke."],
	["the Appel Quay", [["reaver", 5], ["bonebow", 4], ["hexcaster", 2]], "Reavers along the Appel Quay. Hold the column together!"],
	["the Latin Bridge", [["shade", 1], ["thrall", 7], ["grave_brute", 1]], "A shade steps from the crowd by the Latin Bridge and fires..."],
	["the Town Hall", [["thrall", 7], ["hexcaster", 2], ["bonebow", 3], ["grave_brute", 1]], "They have barricaded the Town Hall square. Break through!"],
]


func setup(w) -> void:
	start(w, 1914, "inland", {"map_size": "small",
			"victories": {"conquest": false, "territory": false, "wonders": false, "relics": false}}, false)
	var town = capital(w, ME)
	town.title = "Sarajevo Town Hall"
	var from: Vector2 = capital(w, FOE).pos
	clear_player(w, FOE)
	# An L-shaped route: along one side of the valley, then across to the Town Hall.
	var corner := Vector2(town.pos.x, from.y)
	var stops: Array = [_walkable(w, from.lerp(corner, 0.45)), _walkable(w, from.lerp(corner, 0.95)),
			_walkable(w, corner.lerp(town.pos, 0.55)), town.pos]
	var duke: Entity = w.spawn_unit("archduke", ME, _walkable(w, from))
	spawn_group(w, "grenadier", ME, from + Vector2(TILE, 0), 5)
	spawn_group(w, "musketeer", ME, from - Vector2(TILE, 0), 4)
	spawn_group(w, "kuerassier", ME, from + Vector2(0, 2 * TILE), 2)
	# The escort travels outside the normal population limit.
	w.players[ME].base_pop_limit += 20
	w.scenario.flags.duke = duke.id
	w.scenario.flags.stops = stops
	w.scenario.flags.stop = 0
	w.scenario.flags.sprung = 0
	w.scenario.marker = stops[0]


func update(w, s: Dictionary) -> void:
	var duke = w.get_entity(int(s.flags.duke))
	if duke == null or not duke.alive:
		lose(w, "The Archduke has fallen. History repeats itself.")
		return
	var i: int = s.flags.stop
	if once(w, "intro"):
		say(w, "Count Harrach", "Your Highness, the people line the streets. The Covenant will not let this day pass quietly.")
		say(w, "Count Harrach", "Select the Archduke and his escort and follow the flag from stop to stop.")
		objective(w, "alive", "The Archduke must survive")
	var stop: Vector2 = s.flags.stops[i]
	objective(w, "escort", "Escort the Archduke to %s (%d/4)" % [STOPS[i][0], i + 1])
	if int(s.flags.sprung) == i and duke.pos.distance_to(stop) <= SPRING:
		s.flags.sprung = i + 1
		_ambush(w, duke, stop, i)
	if s.flags.has("shot") and elapsed(w, "shot") >= 3.0 and once(w, "missed"):
		say(w, "Count Harrach", "The shot missed! The Archduke lives. Cut the shade down before it fires again!")
	if duke.pos.distance_to(stop) <= ARRIVE:
		if i == STOPS.size() - 1:
			complete(w, "escort")
			complete(w, "alive")
			s.erase("marker")
			win(w, "The Archduke reaches the Town Hall. The shot that missed will change the century.")
			return
		say(w, "Count Harrach", "We are past %s. The surgeon tends His Highness - onward!" % STOPS[i][0])
		duke.hp = minf(duke.max_hp, duke.hp + 200.0)
		s.flags.stop = i + 1
		s.marker = s.flags.stops[i + 1]


func _ambush(w, duke, stop: Vector2, i: int) -> void:
	say(w, "Scout", STOPS[i][2])
	if i == 2:
		mark(w, "shot")
	var ids: Array = []
	for group in STOPS[i][1]:
		if group[0] == "shade":
			# A visible assassin (not a stealthed wraith) so the escort can answer it.
			var spot: Vector2 = duke.pos + (stop - duke.pos).normalized().orthogonal() * 4.0 * TILE
			var shade: Entity = w.spawn_unit("hexcaster", FOE, _walkable(w, spot))
			shade.title = "The Covenant Shade"
			ids.append(shade.id)
			continue
		ids.append_array(spawn_group(w, group[0], FOE, stop, int(group[1])))
	# A third (and the shade) go for the Archduke himself; the rest fight the escort.
	var hunters := ids.slice(0, (ids.size() + 2) / 3)
	w.issue({"type": "attack", "player": FOE, "ids": hunters, "target": duke.id})
	attack_move(w, FOE, ids.slice(hunters.size()), duke.pos)
