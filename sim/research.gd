extends RefCounted
## Research branches and the per-player modifiers they grant. Tech data lives in
## data/techs.json. Library branches have one level per age (level N needs age N);
## military lines list the age of each level in "ages".

const DB = preload("res://sim/db.gd")

static func branch(id: String) -> Dictionary:
	return DB.techs.branches[id]


static func max_level(id: String) -> int:
	return branch(id).levels.size()


static var _trainers := {}


## The (non-city) building that trains `unit_type`, which scopes military upgrades.
static func trainer_of(unit_type: String) -> String:
	if _trainers.is_empty():
		for bid in DB.buildings:
			var d: Dictionary = DB.buildings[bid]
			if d.get("role", "") == "city":
				continue
			for t in d.get("trains", []):
				if not _trainers.has(t):
					_trainers[t] = bid
	# Later tiers of a line count as trained where the line's first unit is.
	return _trainers.get(unit_type, _trainers.get(DB.line_root(unit_type), ""))


## Name, cost, time and age requirement of `branch_id` at `level` (1-based).
static func level_info(branch_id: String, level: int) -> Dictionary:
	var b := branch(branch_id)
	var growth := pow(float(b.cost_growth), level - 1)
	var cost := {}
	for k in b.cost:
		cost[k] = roundi(float(b.cost[k]) * growth)
	return {
		"name": b.levels[level - 1],
		"cost": cost,
		"time": float(b.time) + float(b.time_step) * (level - 1),
		"age": int(b.ages[level - 1]) if b.has("ages") else level,
	}


static func next_level(p, branch_id: String) -> int:
	return int(p.techs.get(branch_id, 0)) + 1


## Rebuilds p.mods from researched levels and crown-land bonuses.
static func recompute_mods(p) -> void:
	p.mods.clear()
	for k in p.land_mods:
		p.mods[k] = p.mods.get(k, 0.0) + float(p.land_mods[k])
	for b in p.techs:
		if not DB.techs.branches.has(b):
			continue
		var level: int = p.techs[b]
		var effects: Dictionary = branch(b).effects
		# Scoped upgrades land in e.g. "damage@kaserne".
		var suffix: String = "@" + branch(b).scope if branch(b).has("scope") else ""
		for k in effects:
			p.mods[k + suffix] = p.mods.get(k + suffix, 0.0) + float(effects[k]) * level


static func describe_effects(branch_id: String) -> String:
	var lines: Array[String] = []
	var effects: Dictionary = branch(branch_id).effects
	for k in effects:
		var v := float(effects[k])
		if k in DB.techs.percent_effects:
			v *= 100.0
		lines.append(DB.techs.effect_labels.get(k, k + " +%s") % _num(v))
	if branch(branch_id).has("scope"):
		lines.append("(only troops trained in this building)")
	return "\n".join(lines)


static func _num(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(roundi(v))
	return "%.2f" % v


static func roman(n: int) -> String:
	var out := ""
	for pair in [[10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]]:
		while n >= pair[0]:
			out += pair[1]
			n -= pair[0]
	return out
