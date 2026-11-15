extends "res://scenarios/scenario.gd"
## Chapter 5: The Empress Rises (September 1917, Age of the Congress).
## Three ritual circles burn around Gödöllő. Break them (capture points) before the
## rite completes; every circle still burning when it does makes the Pale Empress
## stronger. Then defeat her. Rudolf watches and leaves before the end.

const RITE := 480.0
## The Empress's health with 0, 1, 2 or 3 circles still burning when she rises.
const EMPRESS_HP := [0.45, 0.6, 0.8, 1.0]
const WAVE_EVERY := 75.0


func setup(w) -> void:
	start(w, 1837, "inland", {"map_size": "small", "start_age": 5, "resources": "high",
			"victories": {"conquest": false, "territory": false, "wonders": false, "relics": false}}, false)
	capital(w, ME).title = "Field Headquarters"
	var palace = capital(w, FOE)
	palace.title = "Gödöllő Palace"
	var home: Vector2 = capital(w, ME).pos
	var toward: Vector2 = (palace.pos - home).normalized()
	# Keep the palace, lose its people: the rite has emptied the town.
	for e in w.entities.values():
		if e.alive and e.owner == FOE and e.kind == Entity.UNIT:
			w.kill(e)
	var circles := [["north", "The North Circle"], ["west", "The Chapel Circle"], ["south", "The Garden Circle"]]
	for i in circles.size():
		var a: float = toward.angle() + PI + (i - 1) * 0.9
		var spot: Vector2 = on_map(w, palace.pos + Vector2.from_angle(a) * 9.0 * TILE)
		add_point(w, circles[i][0], spot, circles[i][1])
		spawn_group(w, "necromancer", FOE, spot, 2)
		spawn_group(w, "reaver", FOE, spot, 4)
		spawn_group(w, "bonebow", FOE, spot, 3)
		if i == 1:
			spawn_group(w, "lich", FOE, spot, 1)
	spawn_group(w, "grave_brute", FOE, palace.pos, 3)
	var army: Vector2 = home + toward * 4.0 * TILE
	hero(w, "archduke", army)
	w.get_entity(hero(w, "tesla", army + toward.orthogonal() * 2.0 * TILE)).title = "Nikola Tesla"
	w.get_entity(hero(w, "houdini", army - toward.orthogonal() * 2.0 * TILE)).title = "Harry Houdini"
	spawn_group(w, "kaiserjaeger", ME, army, 12)
	spawn_group(w, "vampire_hunter", ME, army - toward * TILE, 6)
	spawn_group(w, "steam_walker", ME, army - toward * 2.0 * TILE, 3)
	spawn_group(w, "field_alchemist", ME, army - toward * 2.0 * TILE, 3)
	w.players[ME].base_pop_limit += 30
	w.scenario.flags.palace = palace.id


func update(w, s: Dictionary) -> void:
	if capital(w, ME) == null:
		lose(w, "The headquarters is overrun. The rite goes on without witnesses.")
		return
	if once(w, "intro"):
		say(w, "Harry Houdini", "Three circles, Majesty. Candles, chalk, a choir that has not breathed in years. The real thing, I'm afraid.")
		say(w, "Nikola Tesla", "Each circle feeds the one in the palace. Break the circuit and the current fails. It is only electrical engineering with worse manners.")
	if s.step == 0:
		_rite(w, s)
	else:
		_empress(w, s)


func _rite(w, s: Dictionary) -> void:
	for _key in update_points(w):
		say(w, "Harry Houdini", "A circle is broken! Somewhere in the palace, someone screamed.")
	var broken := points_held(w)
	var left := maxf(0.0, RITE - elapsed(w))
	objective(w, "circles", "Break the ritual circles before the rite ends in %d:%02d (%d/3)" % [int(left) / 60, int(left) % 60, broken])
	if elapsed(w) >= 60.0 + int(s.flags.get("waves", 0)) * WAVE_EVERY:
		s.flags.waves = int(s.flags.get("waves", 0)) + 1
		var palace = w.get_entity(int(s.flags.palace))
		if palace:
			wave(w, [["thrall", 5], ["ghoul_rider", 2], ["bonebow", 2]], palace.pos, capital(w, ME).pos)
	if broken >= 3 or left <= 0.0:
		_rise(w, s, 3 - broken)


func _rise(w, s: Dictionary, burning: int) -> void:
	s.step = 1
	mark(w, "risen")
	if burning == 0:
		complete(w, "circles")
	var palace = w.get_entity(int(s.flags.palace))
	var at: Vector2 = palace.pos if palace else capital(w, ME).pos
	spawn_boss(w, "pale_empress", at + Vector2(0, 3) * TILE, float(EMPRESS_HP[burning]))
	s.points = []
	s.markers = []
	say(w, "Crown Prince Rudolf", "Mother. You are home.")
	say(w, "Elisabeth, the Pale Empress", "Rudolf. You were always so loud. Who are all these men?")
	if burning == 0:
		say(w, "Nikola Tesla", "The rite came up short. She is weak. Now, quickly!")
	else:
		say(w, "Harry Houdini", "%d circle%s still burning. She came back strong." % [burning, "" if burning == 1 else "s"])
	say(w, "Crown Prince Rudolf", "Deal with them, Mother. I will be at Buda.")
	objective(w, "empress", "Defeat Elisabeth, the Pale Empress")


func _empress(w, s: Dictionary) -> void:
	var b = boss(w)
	if b == null:
		complete(w, "empress")
		win(w, "Elisabeth falls, and this time she stays at rest. Houdini takes off his hat. Rudolf has fled to Buda with the relics he needs.")
		return
	match boss_phase(w, [0.6, 0.3]):
		1:
			say(w, "Elisabeth, the Pale Empress", "I walked the Alps in a single day. You will not tire me.")
			wave(w, [["vampire", 4], ["risen", 8]], b.pos, b.pos)
		2:
			say(w, "Elisabeth, the Pale Empress", "Geneva... the lake... I remember the lake.")
			say(w, "Harry Houdini", "She remembers dying. That is the knot that holds her. Pull it!")
			wave(w, [["wraith", 4], ["grave_brute", 2]], b.pos, b.pos)
