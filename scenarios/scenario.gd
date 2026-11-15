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
const CAMPAIGN := ["m1_sarajevo", "m2_tomb", "m3_federation", "m4_vienna", "m5_empress", "m6_viribus"]
## Campaign 2, The Undying Century (1926-1955): one chapter per age 7-12, added as built.
const CAMPAIGN2 := ["m7_rosabelle", "m8_black_thursday", "m9_ice_crown"]

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
	options = options.duplicate()
	options["hungary"] = options.get("hungary", false)
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


## Pulls a point (pixels) inside the map, a few tiles in from the edge.
func on_map(w, spot: Vector2, margin := 4) -> Vector2:
	return Vector2(clampf(spot.x, margin * TILE, (w.map.width - margin) * TILE),
			clampf(spot.y, margin * TILE, (w.map.height - margin) * TILE))


func _walkable(w, spot: Vector2) -> Vector2:
	var t := GameMap.to_tile(spot)
	for r in 6:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var c := t + Vector2i(dx, dy)
				if w.map.in_bounds(c) and w.map.is_walkable(c):
					return GameMap.tile_center(c) if r > 0 else spot
	return spot


## The unit of `type_id`'s upgrade line that player `pid` fields in its current age
## (spawn this rather than a fixed tier, so a chapter stays right if the lines change).
func tier(w, type_id: String, pid := ME) -> String:
	return DB.tier(type_id, w.players[pid].age)


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


# --- Legendary-mission toolkit ------------------------------------------------------
# All state lives in w.scenario so it saves with the match; the view reads
# "boss", "sentries", "markers", "rail" from it to draw bars, cones, flags and rails.

## Spawns a boss and shows its health bar at the top of the screen. `hp_share`
## starts it wounded (the bar shows it); its phases count from that starting health.
func spawn_boss(w, type_id: String, at: Vector2, hp_share := 1.0) -> int:
	var b: Entity = w.spawn_unit(type_id, FOE, _walkable(w, at))
	b.hp = b.max_hp * hp_share
	w.scenario.boss = b.id
	w.scenario.flags.boss_phase = 0
	w.scenario.flags.boss_start = b.hp
	return b.id


func boss(w):
	var b = w.get_entity(int(w.scenario.get("boss", -1)))
	return b if b and b.alive else null


## The next phase number (1, 2, ...) the first time the boss falls below each of
## `thresholds` (fractions of its starting health, descending), else 0.
func boss_phase(w, thresholds: Array) -> int:
	var b = boss(w)
	if b == null:
		return 0
	var done: int = int(w.scenario.flags.get("boss_phase", 0))
	var start: float = float(w.scenario.flags.get("boss_start", b.max_hp))
	if done < thresholds.size() and b.hp <= start * float(thresholds[done]):
		w.scenario.flags.boss_phase = done + 1
		return done + 1
	return 0


## A sentry with a vision cone: `facing` (radians, 0 = +x), sweeping `sweep` either side.
func add_sentry(w, unit_id: int, facing: float, range_tiles := 5.0, half_angle := 0.6, sweep := 0.7) -> void:
	if not w.scenario.has("sentries"):
		w.scenario.sentries = []
	w.scenario.sentries.append({"id": unit_id, "facing": facing, "range": range_tiles * TILE, "half": half_angle, "sweep": sweep})


## Current facing of a sentry (they sweep slowly back and forth).
static func sentry_dir(w, s: Dictionary) -> float:
	return float(s.facing) + sin(w.tick_count * w.DT * 0.6 + float(s.id)) * float(s.sweep)


## The first living sentry that sees one of `ids` (stealth-hidden units are unseen).
func sentry_spots(w, ids: Array):
	for s in w.scenario.get("sentries", []):
		var g = w.get_entity(int(s.id))
		if g == null or not g.alive:
			continue
		var dir := Vector2.from_angle(sentry_dir(w, s))
		for i in ids:
			var u = w.get_entity(int(i))
			if u == null or not u.alive or w.is_hidden_by_stealth(FOE, u):
				continue
			var d: Vector2 = u.pos - g.pos
			if d.length() <= float(s.range) and absf(dir.angle_to(d)) <= float(s.half):
				return g
	return null


## Capture points: hold one with soldiers (no enemies near) to win it over.
func add_point(w, key: String, at: Vector2, label: String) -> void:
	if not w.scenario.has("points"):
		w.scenario.points = []
	w.scenario.points.append({"key": key, "pos": _walkable(w, at), "label": label, "progress": 0.0, "owner": -1})
	_sync_markers(w)


## Advances capture points by one second; returns the keys captured this second.
func update_points(w, seconds_to_take := 6.0) -> Array:
	var taken: Array = []
	for pt in w.scenario.get("points", []):
		if pt.owner == ME:
			continue
		var mine := 0
		var theirs := 0
		for e in w.entities.values():
			if e.alive and e.kind == Entity.UNIT and e.can_attack() and not e.is_worker() and e.pos.distance_to(pt.pos) <= 3.0 * TILE:
				if e.owner == ME:
					mine += 1
				elif e.owner == FOE:
					theirs += 1
		if mine > 0 and theirs == 0:
			pt.progress += 1.0 / seconds_to_take
			if pt.progress >= 1.0:
				pt.owner = ME
				taken.append(pt.key)
		elif theirs > 0:
			pt.progress = maxf(0.0, pt.progress - 0.2)
	if not taken.is_empty():
		_sync_markers(w)
	return taken


func points_held(w) -> int:
	return w.scenario.get("points", []).filter(func(pt): return pt.owner == ME).size()


## Flags on every open capture point (plus any explicit "marker").
func _sync_markers(w) -> void:
	w.scenario.markers = w.scenario.get("points", []).filter(func(pt): return pt.owner != ME).map(func(pt): return pt.pos)


## Lays a rail line between `stops` (pixels) along walkable ground; returns it.
func lay_rail(w, stops: Array) -> Array:
	var line: Array = []
	for i in stops.size() - 1:
		var seg: PackedVector2Array = w.map.find_path(stops[i], GameMap.to_tile(stops[i + 1]), "ground")
		if line.is_empty():
			line.append(stops[i])
		for p in seg:
			line.append(p)
	w.scenario.rail = line
	w.scenario.flags.rail_i = 0
	return line


## Moves the train along the rail; it waits while enemy soldiers block the track ahead.
## Returns true once it reaches the end.
func drive_train(w, train_id: int) -> bool:
	var t = w.get_entity(train_id)
	var rail: Array = w.scenario.get("rail", [])
	if t == null or not t.alive or rail.is_empty():
		return false
	var i: int = int(w.scenario.flags.get("rail_i", 0))
	while i < rail.size() - 1 and t.pos.distance_to(rail[i]) < TILE * 0.8:
		i += 1
	w.scenario.flags.rail_i = i
	if i >= rail.size() - 1 and t.pos.distance_to(rail[-1]) < TILE:
		return true
	var ahead: Vector2 = rail[mini(i + 1, rail.size() - 1)]
	for e in w.entities.values():
		if e.alive and e.owner == FOE and e.kind == Entity.UNIT and e.pos.distance_to(ahead) < 1.6 * TILE:
			t.orders.clear()
			w.scenario.flags.train_blocked = true
			return false
	w.scenario.flags.train_blocked = false
	t.orders = [{"type": "move", "pos": rail[mini(i + 2, rail.size() - 1)]}]
	return false


## A snow avalanche: heavy damage to every enemy in the radius and a white cloud.
func avalanche(w, at: Vector2, radius_tiles: float, damage: float) -> int:
	var hit := 0
	for e in w.entities.values():
		if e.alive and e.kind == Entity.UNIT and e.owner == FOE and e.pos.distance_to(at) <= radius_tiles * TILE:
			w.apply_damage(null, e, damage, "blade")
			hit += 1
	w.events.append({"type": "cloud", "pos": at, "radius": radius_tiles * TILE, "duration": 4.0, "color": [0.95, 0.97, 1.0, 0.55]})
	return hit


## A wave of `groups` ([[type, count], ...]) from `from`, attack-moving to `to`.
func wave(w, groups: Array, from: Vector2, to: Vector2) -> Array:
	var ids: Array = []
	for g in groups:
		ids.append_array(spawn_group(w, g[0], FOE, from, int(g[1])))
	attack_move(w, FOE, ids, to)
	return ids


## Spawns a campaign hero (or any unit) for the player with an optional title.
func hero(w, type_id: String, at: Vector2) -> int:
	return w.spawn_unit(type_id, ME, _walkable(w, at)).id


func alive(w, uid) -> bool:
	var e = w.get_entity(int(uid))
	return e != null and e.alive


# --- Campaign progress (user://campaign.cfg) -------------------------------------

const PROGRESS := "user://campaign.cfg"
## id: [menu title, one-line summary, dateline, briefing card text].
const MISSIONS := {
	"tutorial": ["Tutorial: The Margrave's First Day", "Learn to gather, build, train, advance and capture a city.", "", ""],
	"m1_sarajevo": ["1. The Shot That Missed", "Escort Archduke Franz Ferdinand through Covenant ambushes to the Sarajevo Town Hall.",
			"Sarajevo  ·  28 June 1914",
			"The heir to the throne is visiting Bosnia, against all advice and in an open motor car. The crowds are cheering. Some of the crowd, your scouts report, are not breathing."],
	"m2_tomb": ["2. The Empty Tomb", "Houdini follows the assassins' sigils to Rudolf's coffin and to Mayerling. Get him out alive.",
			"Vienna and Mayerling  ·  October 1914",
			"The assassins carried sigils. The Archduke has hired the one man alive who can tell real necromancy from parlour tricks: Harry Houdini of Budapest. He has examined them and, to his great annoyance, they are genuine. The trail leads to a coffin in the Kapuzinergruft, and to a hunting lodge where a Crown Prince died in 1889."],
	"m3_federation": ["3. The Federation", "Proclaim three crown lands, then answer Hungary's secession by taking its stronghold.",
			"Vienna  ·  Spring 1915",
			"Franz Joseph has abdicated: \"I have signed everything else; I may as well sign this.\" Emperor Franz Ferdinand will proclaim an empire of equals. In Budapest, Count Árpád Szentkirályi and the magnates have other plans, and a dead prince to crown. On a happier note, Mr. Tesla has cabled from New York. He is coming home."],
	"m4_vienna": ["4. The Siege of Vienna", "The dead and the Honvéd are at the gates. Hold the Hofburg for ten minutes.",
			"Vienna  ·  November 1916",
			"Rudolf's dead and Szentkirályi's regiments stand before the walls. Vienna has been besieged before, and it is tradition that the relief arrives at the last possible moment. In the Hofburg the old Emperor is dying. Tesla has asked for his measurements, and will not say why."],
	"m5_empress": ["5. The Empress Rises", "Break the ritual circles at Gödöllő before Rudolf raises his mother, then face her.",
			"Gödöllő, Hungary  ·  September 1917",
			"Elisabeth was murdered in Geneva in 1898. Her son means to mend that. At Gödöllő, the palace she loved, three ritual circles are burning. Every circle we break before the rite is done leaves her weaker. Houdini assures us he has seen worse séances. He did not say where."],
	"m6_viribus": ["6. Viribus Unitis", "Bring the five A.E.I.O.U. relics home, then end Rudolf at Buda.",
			"Vienna and Buda  ·  Autumn 1918",
			"The five relics of the House are scattered, and Rudolf wants them as badly as we do. Bring them home, and the crown lands will march as one on his seat at Buda. The Iron Emperor insists on coming. Nobody has found a way to refuse him."],
	"m7_rosabelle": ["7. Rosabelle, Believe", "Shut down the Concern's séance parlours, free Houdini's soul, and storm its counting-house.",
			"Vienna and Budapest  ·  November 1926",
			"Harry Houdini died on Halloween. Before he went, he told his wife a code that any honest medium would have to give: ten words that spell \"Rosabelle, believe\". Last night a Viennese medium spoke it. The Concern is keeping his soul in its séance parlours, and charging admission."],
	"m8_black_thursday": ["8. Black Thursday", "The crash: keep the crown lands loyal while the Concern buys their debts.",
			"The crown lands  ·  October 1929",
			"Wall Street has crashed, and every bank in the crown lands is calling in its loans. Someone is buying the debts, city by city, and paying in cash: the Szentkirályi Concern. Where its collectors walk, loyalty bleeds away. Hold the Federation together until the markets reopen."],
	"m9_ice_crown": ["9. The Ice Crown", "Build a camp on the ice, hold through the polar night, then destroy the Concern's foundry under the glacier.",
			"Franz Josef Land  ·  February 1934",
			"In 1873 an Austro-Hungarian expedition discovered an archipelago in the Arctic and named it for the Emperor. Now there is smoke under its glacier: the Concern has built a foundry where no one would look. An airship expedition is on its way, with Hedy Lamarr on the radio. There are a few hours of daylight left."],
}

## Title cards before Chapter 1: the premise, one page at a time.
const INTRO := [
	["Vienna, 1914", "For three centuries the Habsburgs have ruled by the light of Aether, the alchemists' fire first kindled in Rudolf II's Prague. Airships cross the Danube; Tesla coils hum in the Hofburg; and the old Emperor Franz Joseph, eighty-four years old, still signs every paper himself."],
	["A tired empire", "Its peoples want a voice, its wars are lost more often than won, and in Budapest the magnates whisper that Vienna's day is done.\n\nOn the 28th of June, in Sarajevo, a young man steps from the crowd and fires at the heir, Archduke Franz Ferdinand."],
	["He misses.", "The Archduke lives to keep his promise: an empire of equals, every crown land free under one crown. Viribus Unitis.\n\nSome do not want it. And some of them, it turns out, were never meant to be alive at all."],
]

## Shown on the last victory card.
const EPILOGUE := "Vienna, 12 November 1918. The Federation is proclaimed from the balcony of the Hofburg, in eleven languages. Franz Joseph lies in the Kapuzinergruft, in a coffin that is not empty. The empire paid dearly, but it stands, united. And for once in its history, it won the war."


## Campaign 2's opening title cards (1918-1926).
const INTRO2 := [
	["Vienna, 1918", "The Federation is proclaimed and Rudolf is ended at Buda. The crown lands get their own parliaments, the Danube fills with Aether barges, and for the first time in living memory the empire is solvent."],
	["The quiet years", "Jazz in the coffeehouses, radio in every parlour, cinemas on the Ring. Emperor Franz Ferdinand, sixty-three and stubborn, still signs every paper himself.\n\nThe dead do not rest. Rudolf's necromancers are scattered and out of work."],
	["Somebody hires them.", "Count Árpád Szentkirályi rode east in a hearse in 1915. He has come back, after a fashion, with a company: the Szentkirályi Concern. It buys debts, bankrupt cities, and the dead.\n\nThe dead make excellent employees. They never strike, never sleep and never ask for wages."],
]

const EPILOGUE2 := "Vienna, 15 May 1955. In the Belvedere the Emperor, ninety-two, signs the Treaty of the Living himself. The Concern is dissolved, its dead laid to rest, its ledgers burned. The Federation has outlived the century that should have destroyed it, and Franz Ferdinand, for the first time in forty years, takes a holiday."

## The campaigns in menu order: chapters, cards, where progress is kept, and what
## unlocks them. Chapters are numbered across campaigns (Campaign 2 opens at 7).
const CAMPAIGNS := [
	{"key": "campaign", "title": "Viribus Unitis", "years": "1914-1918", "chapters": CAMPAIGN, "intro": INTRO, "epilogue": EPILOGUE, "needs": ""},
	{"key": "campaign2", "title": "The Undying Century", "years": "1926-1955", "chapters": CAMPAIGN2, "intro": INTRO2, "epilogue": EPILOGUE2, "needs": "m6_viribus"},
]


## The campaign a chapter belongs to, or {}.
static func campaign_of(scenario_id: String) -> Dictionary:
	for c in CAMPAIGNS:
		if scenario_id in c.chapters:
			return c
	return {}


## A chapter's number across all campaigns (Sarajevo is 1, Rosabelle 7), or 0.
static func chapter_number(scenario_id: String) -> int:
	var n := 0
	for c in CAMPAIGNS:
		var i: int = c.chapters.find(scenario_id)
		if i >= 0:
			return n + i + 1
		n += 6
	return 0


## How many chapters of a campaign are open: at least the first once the campaign
## itself is unlocked (Campaign 2 needs Campaign 1's last chapter won), else 0.
static func unlocked(camp: Dictionary = CAMPAIGNS[0]) -> int:
	if camp.needs != "" and not is_won(camp.needs):
		return 0
	var cfg := ConfigFile.new()
	cfg.load(PROGRESS)
	return int(cfg.get_value(camp.key, "unlocked", 1))


static func is_won(scenario_id: String) -> bool:
	var cfg := ConfigFile.new()
	cfg.load(PROGRESS)
	return cfg.get_value("won", scenario_id, false)


static func record_win(scenario_id: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PROGRESS)
	cfg.set_value("won", scenario_id, true)
	var camp := campaign_of(scenario_id)
	if not camp.is_empty():
		var i: int = camp.chapters.find(scenario_id)
		var n: int = camp.chapters.size()
		cfg.set_value(camp.key, "unlocked", maxi(int(cfg.get_value(camp.key, "unlocked", 1)), mini(i + 2, n)))
	cfg.save(PROGRESS)
