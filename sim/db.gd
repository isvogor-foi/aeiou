extends RefCounted
## Static content database. All game content lives as JSON under res://data;
## code looks stats up here and never hardcodes them.

const RESOURCE_TYPES: Array[String] = ["gold", "timber", "herbs", "mana", "coal"]

static var rules: Dictionary = {}
static var units: Dictionary = {}
static var buildings: Dictionary = {}
static var resources: Dictionary = {}
static var factions: Dictionary = {}
static var ages: Array = []
static var damage: Dictionary = {}
static var techs: Dictionary = {}
static var visuals: Dictionary = {}
static var ai: Dictionary = {}
static var abilities: Dictionary = {}
static var crown_lands: Dictionary = {}
static var _loaded := false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	rules = _read("res://data/rules.json")
	units = _read("res://data/units.json")
	buildings = _read("res://data/buildings.json")
	resources = _read("res://data/resources.json")
	ages = _read("res://data/ages.json")
	damage = _read("res://data/damage.json")
	techs = _read("res://data/techs.json")
	visuals = _read("res://data/visuals.json")
	ai = _read("res://data/ai.json")
	abilities = _read("res://data/abilities.json")
	crown_lands = _read("res://data/crown_lands.json")
	crown_lands.erase("_comment")
	for file in DirAccess.get_files_at("res://data/factions"):
		if file.ends_with(".json"):
			factions[file.get_basename()] = _read("res://data/factions/" + file)
	for table in [units, buildings, resources, abilities]:
		for id in table.keys():
			if id.begins_with("_"):
				table.erase(id)
			else:
				table[id]["id"] = id


static func _read(path: String) -> Variant:
	var text := FileAccess.get_file_as_string(path)
	assert(text != "", "Missing data file: " + path)
	var data = JSON.parse_string(text)
	assert(data != null, "Invalid JSON: " + path)
	return data


static func get_def(type_id: String) -> Dictionary:
	if units.has(type_id):
		return units[type_id]
	if buildings.has(type_id):
		return buildings[type_id]
	return resources.get(type_id, {})


static func display_name(def: Dictionary, faction: String = "") -> String:
	if def.has("names") and def.names.has(faction):
		return def.names[faction]
	return def.get("name", def.get("id", "?"))


## The last playable age: ages marked "wip" in ages.json (content not built yet)
## are left out unless `all_ages` is set (developers, tests).
static func last_age(all_ages := false) -> int:
	if all_ages:
		return ages.size()
	var n := 0
	for a in ages:
		if a.get("wip", false):
			break
		n += 1
	return maxi(1, n)


static func damage_mult(dtype: String, armor: String) -> float:
	return float(damage.matrix.get(dtype, {}).get(armor, 1.0))


static func color_of(arr: Array) -> Color:
	return Color(arr[0], arr[1], arr[2], arr[3] if arr.size() > 3 else 1.0)


## Display name of a resource (the data keys stay gold/timber/herbs/mana).
static func resource_name(key: String) -> String:
	return rules.get("resource_names", {}).get(key, key.capitalize())


static func format_cost(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for k in RESOURCE_TYPES:
		if cost.has(k):
			parts.append("%d %s" % [int(cost[k]), resource_name(k)])
	return ", ".join(parts) if parts else "free"
