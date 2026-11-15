extends "res://scenarios/scenario.gd"
## Chapter 12: The Treaty of the Living (1955, Age of Rockets). The finale.
## Storm the Concern's machine-necropolis: break its three gates (capture points),
## then destroy Count Szentkirályi. Chapter 11's choice is remembered: if the Aether
## bomb was dropped, its scar glows on the field and the Concern's reserves are
## spent (Szentkirályi starts weakened); if the army went in on foot, Houdini's ghost
## returns. The Emperor (92) must survive. The Concern is scripted (no AI).

const WAVE_EVERY := 50.0


func setup(w) -> void:
	start(w, 1955, "inland", {"map_size": "normal", "start_age": 12, "end_age": 12, "all_ages": true, "resources": "high",
			"difficulty": "easy", "victories": {"conquest": false, "territory": false, "wonders": false, "relics": false}}, false)
	w.scenario.weather = {"night": 0.3}
	var home = capital(w, ME)
	home.title = "Vienna (Belvedere)"
	var necro = capital(w, FOE)
	necro.title = "The Machine-Necropolis"
	var toward: Vector2 = (necro.pos - home.pos).normalized()
	var side: Vector2 = toward.orthogonal()
	var gates := [["west", "The West Gate"], ["iron", "The Iron Gate"], ["east", "The East Gate"]]
	for i in gates.size():
		var at: Vector2 = on_map(w, home.pos.lerp(necro.pos, 0.62) + side * (i - 1) * 8.0 * TILE)
		add_point(w, gates[i][0], at, gates[i][1])
		spawn_group(w, "frost_dead", FOE, at, 7)
		spawn_group(w, "reactor_ghoul", FOE, at, 5)
		spawn_group(w, "plated_abomination", FOE, at, 2)
		spawn_group(w, "undead_panzer", FOE, at, 1)
	spawn_group(w, "necropolis_titan", FOE, necro.pos + (home.pos - necro.pos).normalized() * 4.0 * TILE, 1)
	var army: Vector2 = home.pos + toward * 4.0 * TILE
	hero(w, "archduke", home.pos - toward * 2.0 * TILE)
	w.get_entity(hero(w, "hedy_lamarr", army + side * 2.0 * TILE)).title = "Hedy Lamarr"
	w.get_entity(hero(w, "lise_meitner", army - side * 2.0 * TILE)).title = "Lise Meitner"
	spawn_group(w, "atom_trooper", ME, army, 8)
	spawn_group(w, "rifleman", ME, army + side * TILE, 6)
	spawn_group(w, "flame_trooper", ME, army - side * TILE, 3)
	spawn_group(w, "heavy_tank", ME, army - toward * TILE, 3)
	spawn_group(w, "rocket_battery", ME, army - toward * 2.0 * TILE, 2)
	spawn_group(w, "viribus_mech", ME, army - toward * 2.0 * TILE, 1)
	spawn_group(w, "jet", ME, army, 3)
	w.players[ME].base_pop_limit += 50
	w.scenario.flags.necro = necro.id
	# Chapter 11's choice (a fresh start counts as the bomb not dropped).
	w.scenario.flags.bomb = choice("bomb")
	if w.scenario.flags.bomb == "drop":
		w.events.append({"type": "bomb_scar", "pos": home.pos.lerp(necro.pos, 0.35), "radius": 6.0 * TILE})
	else:
		w.get_entity(hero(w, "houdini", army)).title = "Houdini's Ghost"


func update(w, s: Dictionary) -> void:
	var duke = _duke(w)
	if duke == null:
		lose(w, "The Emperor has fallen, ninety-two and unbowed. The Concern will sign nothing now.")
		return
	if once(w, "intro"):
		say(w, "Emperor Franz Ferdinand", "Forty years of paperwork, and it comes down to this. Break the gates; find the Count.")
		if s.flags.bomb == "drop":
			say(w, "Lise Meitner", "We cross the plain where the bomb fell. It still glows at night. The Concern's reserves burned with it: the Count is weaker than he lets on.")
		else:
			say(w, "Houdini's Ghost", "Did you think I'd miss the last act? I've escaped worse than death. Well. I've escaped death.")
		say(w, "Hedy Lamarr", "Their wireless is screaming. They know we are coming.")
		objective(w, "duke", "The Emperor must survive")
	match s.step:
		0:
			_gates(w, s)
		1:
			_count(w, s)


func _duke(w):
	for e in w.entities.values():
		if e.alive and e.owner == ME and e.type_id == "archduke":
			return e
	return null


func _gates(w, s: Dictionary) -> void:
	for _key in update_points(w):
		say(w, "Field Marshal", "A gate of the necropolis is ours!")
	var held := points_held(w)
	objective(w, "gates", "Break the necropolis gates (%d/3)" % held)
	var n: int = int(s.flags.get("waves", 0))
	if elapsed(w) >= 50.0 + n * WAVE_EVERY:
		s.flags.waves = n + 1
		var necro = w.get_entity(int(s.flags.necro))
		if necro:
			wave(w, [["frost_dead", 3 + n], ["reactor_ghoul", 2 + n / 2], ["wraith_jet", n / 3]], necro.pos, capital(w, ME).pos.lerp(necro.pos, 0.5))
	if held >= 3:
		complete(w, "gates")
		s.step = 1
		var necro = w.get_entity(int(s.flags.necro))
		var at: Vector2 = necro.pos + (capital(w, ME).pos - necro.pos).normalized() * 3.0 * TILE
		spawn_boss(w, "szentkiralyi", at, 0.7 if s.flags.bomb == "drop" else 1.0)
		w.get_entity(int(w.scenario.boss)).title = "Count Árpád Szentkirályi"
		s.marker = at
		spawn_group(w, "reactor_ghoul", FOE, at, 6)
		# The crown lands march: every land sends its regiment for the last fight.
		var home: Vector2 = capital(w, ME).pos.lerp(necro.pos, 0.5)
		spawn_group(w, "atom_trooper", ME, home, 4)
		spawn_group(w, "heavy_tank", ME, home, 1)
		say(w, "Field Marshal", "Croatia, Bohemia, Carniola, Galicia, Transylvania: every crown land has sent its regiment. Viribus unitis, Majesty.")
		say(w, "Count Szentkirályi", "Your Majesty. Ninety-two, and you came in person. I would have sent a clerk.")
		say(w, "Emperor Franz Ferdinand", "I have signed every paper of this Federation myself, Count. I will sign this one too.")
		objective(w, "count", "Destroy Count Szentkirályi")


func _count(w, s: Dictionary) -> void:
	var b = boss(w)
	if b == null:
		complete(w, "count")
		s.erase("marker")
		var wedding := "" if s.flags.bomb == "drop" else " And in the autumn there is a wedding in the Hofburg, because some habits of the House are worth keeping."
		win(w, "The Count is ended, and his ledgers burn. In the Belvedere the Emperor signs the Treaty of the Living himself, ninety-two years old, in a steady hand. Bella gerant alii: let others wage war. This time Austria won it." + wedding)
		return
	match boss_phase(w, [0.66, 0.33]):
		1:
			say(w, "Count Szentkirályi", "Every debt in the Federation is on my books. You cannot kill a ledger.")
			say(w, "Hedy Lamarr", "Then we jam it. Frequency hopping, Majesty: his dead cannot hear him.")
			wave(w, [["reactor_ghoul", 6], ["frost_dead", 6]], b.pos, b.pos)
		2:
			say(w, "Count Szentkirályi", "I was a living man once. I was in Budapest when you were all still in short trousers. I...")
			say(w, "Emperor Franz Ferdinand", "Your account is closed, Count.")
			wave(w, [["plated_abomination", 3], ["wraith_jet", 4], ["frost_dead", 6]], b.pos, b.pos)
