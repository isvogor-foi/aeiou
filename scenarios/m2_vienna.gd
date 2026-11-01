extends "res://scenarios/scenario.gd"
## Mission 2: the Covenant lays siege to Vienna. Hold the Hofburg until the relief
## army comes down from the Kahlenberg.

const HOLD := 600.0
const WAVE_EVERY := 100.0


func setup(w) -> void:
	start(w, 1683, "inland", {"map_size": "small", "start_age": 3, "resources": "high", "difficulty": "easy",
			"victories": {"territory": false, "wonders": false, "relics": false}})
	var vienna = capital(w, ME)
	vienna.title = "Vienna (Hofburg)"
	var toward: Vector2 = (capital(w, FOE).pos - vienna.pos).normalized()
	var front: Vector2 = vienna.pos + toward * 5.0 * TILE
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
		say(w, "Prince Eugene", "The dead are at the gates, Majesty. Raise walls and towers, and hold until the relief army comes.")
	var left: float = HOLD - elapsed(w)
	objective(w, "hold", "Hold Vienna for %d:%02d" % [int(maxf(0.0, left)) / 60, int(maxf(0.0, left)) % 60])
	if left <= 0.0:
		complete(w, "hold")
		win(w, "The relief army storms down the Kahlenberg. Vienna stands!")
		return
	var t: float = elapsed(w)
	var n: int = s.flags.wave
	if t >= 45.0 + n * WAVE_EVERY:
		s.flags.wave = n + 1
		_wave(w, vienna, n)
	if left <= 120.0 and once(w, "relief"):
		say(w, "Scout", "Signal fires on the Kahlenberg! Two more minutes!")


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
	if n >= 4:
		ids.append_array(spawn_group(w, "plague_catapult", FOE, from, 2))
	attack_move(w, FOE, ids, vienna.pos)
	say(w, "Scout", "Siege wave %d approaches the walls!" % (n + 1))
