extends "res://scenarios/scenario.gd"
## Chapter 4: The Siege of Vienna (November 1916, Age of Reform).
## The Covenant and Szentkirályi's Hungarians (the third side) attack in waves.
## Halfway through, the dying Franz Joseph returns in Tesla's steam armour as the
## Iron Emperor. Hold the Hofburg until the relief comes down the Kahlenberg.

const HOLD := 600.0
const WAVE_EVERY := 100.0
## The Iron Emperor marches out when this much of the siege has passed.
const EMPEROR_AT := 270.0


func setup(w) -> void:
	start(w, 1916, "inland", {"map_size": "small", "start_age": 4, "resources": "high", "difficulty": "easy",
			"victories": {"territory": false, "wonders": false, "relics": false}})
	var vienna = capital(w, ME)
	vienna.title = "Vienna (Hofburg)"
	capital(w, FOE).title = "The Covenant Siege Camp"
	var toward: Vector2 = (capital(w, FOE).pos - vienna.pos).normalized()
	var front: Vector2 = vienna.pos + toward * 5.0 * TILE
	hero(w, "archduke", vienna.pos + toward * 3.0 * TILE)
	spawn_group(w, "grenadier", ME, front, 8)
	spawn_group(w, "musketeer", ME, front - toward * TILE, 6)
	spawn_group(w, "jaeger", ME, front - toward * 2.0 * TILE, 4)
	spawn_group(w, "settler", ME, vienna.pos - toward * 3.0 * TILE, 4)
	w.players[ME].base_pop_limit += 25
	w.scenario.flags.vienna = vienna.id
	w.scenario.flags.wave = 0


func update(w, s: Dictionary) -> void:
	var vienna = w.get_entity(int(s.flags.vienna))
	if vienna == null or not vienna.alive or vienna.owner != ME:
		lose(w, "Vienna has fallen. The Covenant's banners fly over the Hofburg.")
		return
	if once(w, "intro"):
		say(w, "Field Marshal Boroević", "The dead to the east, the Honvéd to the south, Majesty. Raise walls and towers, and hold until the relief comes.")
		say(w, "Emperor Franz Ferdinand", "Vienna has been besieged before. It has a habit of not falling.")
	var left: float = HOLD - elapsed(w)
	objective(w, "hold", "Hold Vienna for %d:%02d" % [int(maxf(0.0, left)) / 60, int(maxf(0.0, left)) % 60])
	if left <= 0.0:
		complete(w, "hold")
		win(w, "The relief army storms down the Kahlenberg. Vienna stands, and the Iron Emperor stands with it.")
		return
	var t: float = elapsed(w)
	var n: int = s.flags.wave
	if t >= 45.0 + n * WAVE_EVERY:
		s.flags.wave = n + 1
		_wave(w, vienna, n)
	if t >= EMPEROR_AT and once(w, "emperor"):
		_iron_emperor(w, vienna)
	if left <= 120.0 and once(w, "relief"):
		say(w, "Scout", "Signal fires on the Kahlenberg! Two more minutes!")


func _iron_emperor(w, vienna) -> void:
	var at: Vector2 = vienna.pos + Vector2(0, 3) * TILE
	hero(w, "iron_emperor", at)
	spawn_group(w, "kaiserjaeger", ME, at + Vector2(2, 0) * TILE, 4)
	say(w, "Scout", "The Hofburg gates are opening! Something is coming out... on foot. On very large feet.")
	say(w, "Franz Joseph, the Iron Emperor", "The doctors gave me a week. Mr. Tesla gave me a boiler. I prefer Mr. Tesla.")
	say(w, "Nikola Tesla", "Majesty, the pressure gauge must stay out of the red. Please do not do what you are about to do.")
	say(w, "Franz Joseph, the Iron Emperor", "I have reigned for sixty-eight years. Let me have one battle I win.")


func _wave(w, vienna, n: int) -> void:
	var foe = capital(w, FOE)
	var from: Vector2 = foe.pos if foe else vienna.pos + Vector2(30, 30) * TILE
	from = from.lerp(vienna.pos, 0.25)
	var ids: Array = []
	ids.append_array(spawn_group(w, "thrall", FOE, from, 4 + n + n / 2))
	ids.append_array(spawn_group(w, "reaver", FOE, from + Vector2(TILE, 0), 1 + n / 2))
	ids.append_array(spawn_group(w, "bonebow", FOE, from - Vector2(TILE, 0), 2 + n / 2))
	if n >= 2:
		ids.append_array(spawn_group(w, "grave_brute", FOE, from, (n - 1) / 2 + 1))
	if n >= 3:
		ids.append_array(spawn_group(w, "abomination", FOE, from, 1))
	if n >= 4:
		ids.append_array(spawn_group(w, "plague_catapult", FOE, from, 2))
	attack_move(w, FOE, ids, vienna.pos)
	say(w, "Scout", "Siege wave %d approaches the walls!" % (n + 1))
	# From the second wave, Szentkirályi's Hungarians come in from the flank.
	if n >= 1:
		var side: Vector2 = (from - vienna.pos).normalized().orthogonal()
		var flank: Vector2 = _walkable(w, on_map(w, vienna.pos + side * 14.0 * TILE))
		var hu: Array = []
		hu.append_array(spawn_group(w, "hussar", w.rebels, flank, 1 + n / 2))
		hu.append_array(spawn_group(w, "honved", w.rebels, flank, 2 + n / 2))
		attack_move(w, w.rebels, hu, vienna.pos)
		if n == 1:
			say(w, "Scout", "Hussars on the southern road! The Honvéd ride with the dead.")
