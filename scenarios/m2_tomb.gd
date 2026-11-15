extends "res://scenarios/scenario.gd"
## Chapter 2: The Empty Tomb (October 1914, Age of AEIOU).
## Part one: Houdini slips past the Covenant watchers into the Kapuzinergruft and
## finds Rudolf's coffin empty. Being seen raises the alarm (a squad comes for him).
## Part two: the Archduke's column joins him and they smash the Grave Engine at
## Mayerling, the lodge where the Crown Prince "died" in 1889.

## The crypt is entered when Houdini is this close to it.
const REACH := 2.0 * TILE
## Seconds between alarms: a seen Houdini gets one squad on him, not one a second.
const ALARM_COOLDOWN := 20.0
## The Grave Engine starts at this share of its health.
const ENGINE_HP := 0.35


func setup(w) -> void:
	start(w, 1889, "inland", {"map_size": "small", "start_age": 2,
			"victories": {"conquest": false, "territory": false, "wonders": false, "relics": false}}, false)
	var vienna = capital(w, ME)
	vienna.title = "Vienna (Hofburg)"
	var lodge: Vector2 = capital(w, FOE).pos
	clear_player(w, FOE)
	var toward: Vector2 = (lodge - vienna.pos).normalized()
	var side: Vector2 = toward.orthogonal()
	# The crypt lies a third of the way out, off to one side: Houdini walks, the army waits.
	var crypt: Vector2 = _walkable(w, vienna.pos.lerp(lodge, 0.38) + side * 6.0 * TILE)
	var start_at: Vector2 = vienna.pos + toward * 4.0 * TILE
	var houdini := hero(w, "houdini", start_at)
	w.get_entity(houdini).title = "Harry Houdini"
	# Watchers in a loose ring around the crypt, each looking outward across the approach.
	for i in 5:
		var a := (start_at - crypt).angle() + (i - 2) * 0.75
		var spot: Vector2 = _walkable(w, crypt + Vector2.from_angle(a) * 5.5 * TILE)
		var g = w.spawn_unit("hexcaster", FOE, spot)
		g.title = "Covenant Watcher"
		add_sentry(w, g.id, a, 4.5, 0.5, 0.8)
	spawn_group(w, "thrall", FOE, crypt, 3)
	w.players[ME].base_pop_limit += 20
	w.scenario.flags.merge({"houdini": houdini, "crypt": crypt, "lodge": lodge, "alarms": 0})
	w.scenario.marker = crypt


func update(w, s: Dictionary) -> void:
	var houdini = w.get_entity(int(s.flags.houdini))
	if s.step == 0 and (houdini == null or not houdini.alive):
		lose(w, "Houdini is dead. Without him, no one will believe what lies in the crypt.")
		return
	if s.step == 1 and soldiers(w, ME) == 0:
		lose(w, "The column is destroyed. Mayerling keeps its secrets.")
		return
	if once(w, "intro"):
		say(w, "Harry Houdini", "I have unmasked four hundred mediums, Highness. Ectoplasm is cheesecloth. Spirit trumpets are tin. These sigils are neither.")
		say(w, "Archduke Franz Ferdinand", "Then find out whose they are. Quietly.")
		say(w, "Harry Houdini", "Quietly is my profession. Locks, chains and the watchful eye. I stand still, they see nothing.")
		objective(w, "alive", "Houdini must survive until he reaches the crypt")
		objective(w, "crypt", "Lead Houdini unseen into the Kapuzinergruft (stand still to hide; watchers' cones show where they look)")
	if s.step == 0:
		_sneak(w, s, houdini)
	elif s.step == 1:
		_lodge(w, s)


func _sneak(w, s: Dictionary, houdini) -> void:
	var seen = sentry_spots(w, [houdini.id])
	if seen and elapsed(w, "alarm") >= ALARM_COOLDOWN:
		mark(w, "alarm")
		s.flags.alarms = int(s.flags.alarms) + 1
		say(w, "Harry Houdini", ["Ah. Applause, of a sort.", "Spotted again. My reputation is suffering.", "This audience is far too attentive."][mini(int(s.flags.alarms) - 1, 2)])
		var ids := spawn_group(w, "reaver", FOE, seen.pos, 2 + int(s.flags.alarms))
		w.issue({"type": "attack", "player": FOE, "ids": ids, "target": houdini.id})
	if houdini.pos.distance_to(s.flags.crypt) <= REACH:
		complete(w, "crypt")
		complete(w, "alive")
		s.step = 1
		mark(w, "found")
		# The watchers melt back into the fog to warn Mayerling.
		for g in s.get("sentries", []):
			var u = w.get_entity(int(g.id))
			if u and u.alive:
				w.kill(u)
		s.erase("sentries")
		for e in w.entities.values():
			if e.alive and e.owner == FOE and e.kind == Entity.UNIT and e.pos.distance_to(s.flags.crypt) < 8.0 * TILE:
				w.kill(e)
		say(w, "Harry Houdini", "Rudolf's coffin. Empty. No body, no dust, no lid screws: it was opened from the inside.")
		say(w, "Harry Houdini", "And the floor is scratched with the same sigil, pointing south-west. To Mayerling.")
		say(w, "Archduke Franz Ferdinand", "Then we pay the Crown Prince a visit. The column marches. Houdini, wait for us.")
		_column(w, s)


func _column(w, s: Dictionary) -> void:
	var vienna = capital(w, ME)
	var at: Vector2 = vienna.pos + (s.flags.lodge - vienna.pos).normalized() * 4.0 * TILE
	hero(w, "archduke", at)
	spawn_group(w, "grenadier", ME, at, 8)
	spawn_group(w, "musketeer", ME, at + Vector2(TILE, TILE), 8)
	spawn_group(w, "vampire_hunter", ME, at - Vector2(TILE, TILE), 4)
	spawn_group(w, "field_alchemist", ME, at, 3)
	spawn_group(w, "bombardier", ME, at, 4)
	# Half-built: the Covenant did not expect visitors this early.
	spawn_boss(w, "grave_engine", s.flags.lodge, ENGINE_HP)
	spawn_group(w, "thrall", FOE, s.flags.lodge, 6)
	spawn_group(w, "bonebow", FOE, s.flags.lodge, 3)
	spawn_group(w, "vampire", FOE, s.flags.lodge, 1)
	w.scenario.marker = s.flags.lodge
	objective(w, "engine", "March on Mayerling and destroy the Grave Engine")


func _lodge(w, s: Dictionary) -> void:
	var b = boss(w)
	if b == null:
		complete(w, "engine")
		s.erase("marker")
		win(w, "The Grave Engine burns. In the cellar of Mayerling, Houdini finds a portrait of Empress Elisabeth, and a ledger of Hungarian names.")
		return
	if once(w, "engine_seen") and elapsed(w, "found") > 5.0:
		say(w, "Scout", "Something is moving in the hunting lodge. Something large.")
	match boss_phase(w, [0.66, 0.33]):
		1:
			say(w, "Harry Houdini", "It is raising the hunting party. 1889's hunting party.")
			wave(w, [["risen", 6], ["bonebow", 2]], b.pos, b.pos)
		2:
			say(w, "Archduke Franz Ferdinand", "Push! It is coming apart!")
			wave(w, [["risen", 6], ["reaver", 2]], b.pos, b.pos)
	# Every so often the lodge sends the dead out to meet the column.
	if elapsed(w, "found") >= 60.0 + int(s.flags.get("waves", 0)) * 50.0:
		s.flags.waves = int(s.flags.get("waves", 0)) + 1
		wave(w, [["thrall", 4], ["reaver", 2]], s.flags.lodge, capital(w, ME).pos)
