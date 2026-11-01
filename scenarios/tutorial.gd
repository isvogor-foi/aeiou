extends "res://scenarios/scenario.gd"
## Guided first match: gather, build, train, advance an age, take a city.

const STEPS := [
	["gather", "Put your 3 workers to work: drag a box around them, then right-click a forest or mine"],
	["barracks", "Build a Kaserne: select a worker, open Military on its card and place it"],
	["train", "Train 3 soldiers: select the Kaserne and click Grenadier or Musketeer"],
	["age", "Advance to the Age of AEIOU: select the Residenz and click Advance Age"],
	["capture", "Capture the Covenant citadel: select your army, right-click the citadel"],
]
const TIPS := [
	"Welcome, Margrave. Move the view with WASD or the screen edges, rotate with Q/E, zoom with the wheel.",
	"Workers gather Timber, Thaler, Provisions, Aether and Coal. Each resource has a gathering cap shown in the top bar.",
	"A Kaserne trains your line infantry. Buildings must stand inside your borders.",
	"Grenadiers hold the line in melee; Musketeers shoot from range. Mixed regiments fight best (Viribus Unitis).",
	"Each age unlocks new units, buildings and research. I have sent a little extra Thaler to help.",
	"Cities are captured, not destroyed: bring its defences down and your soldiers take the keys.",
]


func setup(w) -> void:
	start(w, 4242, "inland", {"map_size": "small", "victories": {"territory": false, "wonders": false, "relics": false}}, false)
	var citadel = capital(w, FOE)
	# A crumbling outpost, so the first siege is a lesson rather than a slaughter.
	citadel.hp = citadel.max_hp * 0.45
	for e in w.entities.values():
		if e.owner == FOE and e.kind == Entity.UNIT:
			w.kill(e)
	spawn_group(w, "thrall", FOE, citadel.pos + Vector2(0, 3 * TILE), 3)


func update(w, s: Dictionary) -> void:
	var p = w.players[ME]
	var step: int = s.step
	if step >= STEPS.size():
		return
	if once(w, "step%d" % step):
		say(w, "Chancellor", TIPS[step])
		objective(w, STEPS[step][0], STEPS[step][1])
		if step == 1:
			_top_up(p, {"timber": 250, "gold": 100})
		elif step == 2:
			_top_up(p, {"herbs": 300, "gold": 200})
		elif step == 3:
			_top_up(p, {"herbs": 400, "gold": 250})
		elif step == 4:
			say(w, "Chancellor", TIPS[5])
			say(w, "Chancellor", "The Margrave's levy has arrived at your Residenz: six Grenadiers and two Cuirassiers.")
			var home = capital(w, ME)
			var citadel = capital(w, FOE)
			var toward: Vector2 = (citadel.pos - home.pos).normalized()
			spawn_group(w, "grenadier", ME, home.pos + toward * 4.0 * TILE, 6)
			spawn_group(w, "kuerassier", ME, home.pos + toward * 5.0 * TILE, 2)
	if _met(w, step, p):
		complete(w, STEPS[step][0])
		s.step = step + 1


func _met(w, step: int, p) -> bool:
	match step:
		0:
			var n := 0
			for e in w.entities.values():
				if e.alive and e.owner == ME and e.kind == Entity.UNIT and e.is_worker() and not e.orders.is_empty() and e.orders[0].type == "gather":
					n += 1
			return n >= 3
		1:
			for e in w.entities.values():
				if e.alive and e.owner == ME and e.type_id == "kaserne" and not e.constructing:
					return true
			return false
		2:
			return soldiers(w, ME) >= 3
		3:
			return p.age >= 2
	return false


func _top_up(p, amounts: Dictionary) -> void:
	for k in amounts:
		p.res[k] = maxf(p.res[k], float(amounts[k]))
