extends RefCounted
## Base for scripted scenarios (tutorial and campaign missions).
##
## A scenario builds its world in setup(), then update() runs once per game second.
## Everything that must survive a save lives in the world's `scenario` dictionary
## (`s` below); the script itself holds no state, so it can be re-attached on load.
## The human is always player 0 and the scripted enemy player 1.

const DB = preload("res://sim/db.gd")
const Entity = preload("res://sim/entity.gd")
const GameMap = preload("res://sim/game_map.gd")

const TILE := GameMap.TILE
const ME := 0
const FOE := 1

## Mission order for the campaign menu (the tutorial stands apart).
const CAMPAIGN := ["m1_sarajevo", "m2_vienna", "m3_viribus"]

var id := ""
var title := ""
var briefing := ""


static func create(scenario_id: String) -> RefCounted:
	var path := "res://scenarios/%s.gd" % scenario_id
	if scenario_id == "" or not ResourceLoader.exists(path):
		return null
	var sc: RefCounted = load(path).new()
	sc.id = scenario_id
	return sc


## Builds the match in a fresh world. Subclasses call start() first, then add to it.
func setup(_w) -> void:
	pass


## Runs once per game second while the match is undecided.
func update(_w, _s: Dictionary) -> void:
	pass


# --- Helpers for subclasses -------------------------------------------------------

func start(w, seed_value: int, map_type: String, options: Dictionary, keep_ai := true) -> void:
	w.new_game(seed_value, ["monarchy", "covenant"], ME, options.get("difficulty", "normal"), map_type, options)
	if not keep_ai:
		w.ais.clear()
	w.scenario = {"id": id, "step": 0, "objectives": [], "flags": {}, "started": w.tick_count}
	w.scenario_logic = self


## A line of story in the message box.
func say(w, speaker: String, text: String) -> void:
	w.events.append({"type": "story", "speaker": speaker, "text": text})


func objective(w, key: String, text: String) -> void:
	for o in w.scenario.objectives:
		if o.id == key:
			o.text = text
			return
	w.scenario.objectives.append({"id": key, "text": text, "done": false})
	w.events.append({"type": "objective", "text": text})


func complete(w, key: String) -> void:
	for o in w.scenario.objectives:
		if o.id == key and not o.done:
			o.done = true
			w.events.append({"type": "objective_done", "text": o.text})


func is_done(w, key: String) -> bool:
	for o in w.scenario.objectives:
		if o.id == key:
			return o.done
	return false


func win(w, text: String) -> void:
	_finish(w, ME, text)


func lose(w, text: String) -> void:
	_finish(w, FOE, text)


func _finish(w, pid: int, text: String) -> void:
	if w.winner >= 0:
		return
	w.winner = pid
	for p in w.players:
		if p.index != pid and not p.is_rebels:
			p.defeated = true
	w.events.append({"type": "victory", "player": pid, "reason": "scenario", "text": text})


## Seconds since the scenario (or a step stamped with mark()) began.
func elapsed(w, since := "started") -> float:
	var t: int = int(w.scenario.flags.get(since, w.scenario.started))
	return (w.tick_count - int(t)) * w.DT


func mark(w, key: String) -> void:
	w.scenario.flags[key] = w.tick_count


func once(w, key: String) -> bool:
	if w.scenario.flags.has("once_" + key):
		return false
	w.scenario.flags["once_" + key] = true
	return true


func capital(w, pid: int):
	return w.get_entity(w.players[pid].capital_id)


## Removes everything a player starts with (used to replace it with a scripted setup).
func clear_player(w, pid: int) -> void:
	for e in w.entities.values():
		if e.owner == pid:
			w.kill(e)
	for e in w.entities.values():
		if not e.alive:
			w.entities.erase(e.id)
	w.events.clear()
	w.territory.dirty = true


## Spawns `count` units of a type around a point (pixels) and returns their ids.
func spawn_group(w, type_id: String, pid: int, at: Vector2, count: int) -> Array:
	var ids: Array = []
	for i in count:
		var a := TAU * i / maxf(1.0, count) + 0.4
		var spot := at + Vector2(cos(a), sin(a)) * TILE * (0.8 + 0.25 * (i % 3))
		ids.append(w.spawn_unit(type_id, pid, _walkable(w, spot)).id)
	return ids


func _walkable(w, spot: Vector2) -> Vector2:
	var t := GameMap.to_tile(spot)
	for r in 6:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var c := t + Vector2i(dx, dy)
				if w.map.in_bounds(c) and w.map.is_walkable(c):
					return GameMap.tile_center(c) if r > 0 else spot
	return spot


func attack_move(w, pid: int, ids: Array, to: Vector2) -> void:
	w.issue({"type": "attack_move", "player": pid, "ids": ids, "pos": to})


func alive_count(w, ids: Array) -> int:
	var n := 0
	for i in ids:
		var e = w.get_entity(int(i))
		if e and e.alive:
			n += 1
	return n


func soldiers(w, pid: int) -> int:
	var n := 0
	for e in w.entities.values():
		if e.alive and e.owner == pid and e.kind == Entity.UNIT and e.can_attack() and not e.is_worker():
			n += 1
	return n


# --- Campaign progress (user://campaign.cfg) -------------------------------------

const PROGRESS := "user://campaign.cfg"
const MISSIONS := {
	"tutorial": ["Tutorial: The Margrave's First Day", "Learn to gather, build, train, advance and capture a city."],
	"m1_sarajevo": ["1. The Shot That Missed", "Sarajevo, 28 June 1914. Escort Archduke Franz Ferdinand through Covenant ambushes to the Town Hall."],
	"m2_vienna": ["2. The Siege of Vienna", "The dead are at the gates. Hold the Hofburg for ten minutes until the relief army arrives."],
	"m3_viribus": ["3. Viribus Unitis", "Unite the crown lands and bring the five A.E.I.O.U. relics home to proclaim the Federation."],
}


## How many campaign missions are open (at least the first).
static func unlocked() -> int:
	var cfg := ConfigFile.new()
	cfg.load(PROGRESS)
	return int(cfg.get_value("campaign", "unlocked", 1))


static func is_won(scenario_id: String) -> bool:
	var cfg := ConfigFile.new()
	cfg.load(PROGRESS)
	return cfg.get_value("won", scenario_id, false)


static func record_win(scenario_id: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PROGRESS)
	cfg.set_value("won", scenario_id, true)
	var i := CAMPAIGN.find(scenario_id)
	if i >= 0:
		cfg.set_value("campaign", "unlocked", maxi(int(cfg.get_value("campaign", "unlocked", 1)), mini(i + 2, CAMPAIGN.size())))
	cfg.save(PROGRESS)
