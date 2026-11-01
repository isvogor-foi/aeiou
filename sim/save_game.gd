extends RefCounted
## Save files: the whole match (world, map, players, entities, AI) plus whatever the
## view wants back (camera, selection, scenario). Stored with store_var as plain
## variants; entity data definitions are re-linked from the database on load.

const DB = preload("res://sim/db.gd")
const Entity = preload("res://sim/entity.gd")
const PlayerState = preload("res://sim/player_state.gd")
const AIPlayer = preload("res://ai/ai_player.gd")

const SAVE_DIR := "user://saves"
const VERSION := 1
## Script variables that are references or per-tick caches, not state.
const SKIP_WORLD := ["map", "territory", "players", "entities", "ais", "events", "scenario_logic", "_unit_grid", "_buildings", "_aura_units"]
const SKIP_ENTITY := ["def"]
const SKIP_AI := ["w", "p", "diff", "style", "_units", "_workers", "_army", "_buildings", "_cities", "_queued"]


static func slot_path(slot: String) -> String:
	return "%s/%s.save" % [SAVE_DIR, slot]


## Writes the match to `slot` ("1".."5", "quick", "autosave"). Returns an error or "".
static func save(w, view_state: Dictionary, slot: String) -> String:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var f := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if f == null:
		return "Could not write the save file"
	var me: int = view_state.get("me", 0)
	var p = w.players[me]
	var meta := {
		"version": VERSION, "slot": slot, "time": Time.get_datetime_string_from_system(false, true),
		"faction": DB.factions[p.faction].name, "age": DB.ages[p.age - 1].name,
		"minutes": int(w.tick_count * w.DT / 60.0), "scenario": view_state.get("scenario", ""),
	}
	f.store_var(meta)
	f.store_var(_dump_world(w))
	f.store_var(view_state)
	return ""


static func read_meta(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var meta = f.get_var()
	return meta if meta is Dictionary else {}


## Every save on disk with its meta, newest first.
static func list_saves() -> Array:
	var out: Array = []
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		return out
	for file in DirAccess.get_files_at(SAVE_DIR):
		if file.ends_with(".save"):
			var path := SAVE_DIR + "/" + file
			var meta := read_meta(path)
			if not meta.is_empty():
				meta.path = path
				out.append(meta)
	out.sort_custom(func(a, b): return a.time > b.time)
	return out


## Restores a match into the (fresh) `w`. Returns the saved view state, or {} on failure.
static func load_into(w, path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var meta = f.get_var()
	if not meta is Dictionary or int(meta.get("version", 0)) != VERSION:
		return {}
	_restore_world(w, f.get_var())
	var view = f.get_var()
	return view if view is Dictionary else {}


# --- Dumping -------------------------------------------------------------------------

static func _dump(obj: Object, skip: Array) -> Dictionary:
	var d := {}
	for prop in obj.get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and not prop.name in skip:
			var v = obj.get(prop.name)
			d[prop.name] = v.duplicate(true) if v is Dictionary or v is Array else v
	return d


static func _apply(obj: Object, d: Dictionary) -> void:
	for k in d:
		var cur = obj.get(k)
		if cur is Array and d[k] is Array and cur.is_typed():
			cur.assign(d[k])
		else:
			obj.set(k, d[k])


static func _dump_world(w) -> Dictionary:
	var m = w.map
	return {
		"world": _dump(w, SKIP_WORLD),
		"map": {"width": m.width, "height": m.height, "terrain": m.terrain, "timber": m.timber, "heights": m.heights},
		"territory": w.territory.grid,
		"players": w.players.map(func(p): return _dump(p, [])),
		"entities": w.entities.values().filter(func(e): return e.alive).map(func(e): return _dump(e, SKIP_ENTITY)),
		"ais": w.ais.map(func(ai): return _dump(ai, SKIP_AI)),
	}


static func _restore_world(w, d: Dictionary) -> void:
	DB.ensure_loaded()
	_apply(w, d.world)
	var m = w.map
	m.setup(int(d.map.width), int(d.map.height))
	m.terrain = d.map.terrain
	m.timber = d.map.timber
	m.heights = d.map.heights
	w.territory.setup(m.width, m.height)
	w.territory.grid = d.territory
	w.territory.dirty = true
	w.players.clear()
	for pd in d.players:
		var p := PlayerState.new()
		_apply(p, pd)
		w.players.append(p)
	w.entities.clear()
	for ed in d.entities:
		var e := Entity.new()
		_apply(e, ed)
		e.def = DB.get_def(e.type_id)
		w.entities[e.id] = e
		if e.kind != Entity.UNIT and e.def.get("blocking", true):
			m.occupy(e.tile, e.size, e.id)
	m.rebuild_solids()
	w.ais.clear()
	for ad in d.ais:
		var ai := AIPlayer.new()
		ai.setup(w, int(ad.pid), ad.get("difficulty_id", "normal"))
		_apply(ai, ad)
		w.ais.append(ai)
