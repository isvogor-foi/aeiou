extends RefCounted
## Per-player economy, population and fog-of-war state.

var index := 0
var faction := ""
var color := Color.WHITE
var is_human := false
var res := {"gold": 0.0, "timber": 0.0, "herbs": 0.0, "mana": 0.0, "coal": 0.0}
## Population in use, including units queued for training.
var pop_used := 0
var pop_cap := 0
var age := 1
## Per tile: 0 unexplored, 1 explored, 2 currently visible.
var vis := PackedByteArray()
## Computer players skip fog bookkeeping; they still only notice enemies within their units' sight.
var tracks_fog := true
var defeated := false
## Researched level per branch, and the summed modifiers they grant (see Research).
var techs := {}
var mods := {}
## Branches with a level currently being researched.
var researching := {}
var advancing_age := false
## True once the hero has died; training it again is then a (slower) revival.
var hero_fallen := false
## The hero chosen with the first one trained; later heroes (revivals) must match.
var hero_type := ""
## The city whose distance sets every other city's loyalty penalty.
var capital_id := -1
## Grows with each soldier lost and slowly fades; lowers loyalty.
var weariness := 0.0
var is_rebels := false
## Crown lands held (from this player's cities) and the modifiers they add.
var crown_lands: Array = []
var land_mods := {}

# Gather caps: harvesting this tick is scaled by `gather_eff` so total income stays under the cap.
var gather_demand := {"gold": 0.0, "timber": 0.0, "herbs": 0.0, "mana": 0.0, "coal": 0.0}
var gather_eff := {"gold": 1.0, "timber": 1.0, "herbs": 1.0, "mana": 1.0, "coal": 1.0}
## Smoothed income per second, for display.
var income := {"gold": 0.0, "timber": 0.0, "herbs": 0.0, "mana": 0.0, "coal": 0.0}
var _harvested := {"gold": 0.0, "timber": 0.0, "herbs": 0.0, "mana": 0.0, "coal": 0.0}
var base_caps := {}
var base_pop_limit := 0
## Gathering multiplier (the Hard AI's bonus); also scales the gather caps.
var handicap := 1.0
## May build on tiles it hasn't explored (the AI knows the map layout).
var knows_map := false


func mod(name: String) -> float:
	return mods.get(name, 0.0)


## Max income per second for `res`.
func gather_cap(res: String) -> float:
	return (float(base_caps.get(res, 0.0)) + mod("cap_" + res)) * handicap


func pop_limit() -> int:
	return base_pop_limit + int(mod("pop_limit"))


func note_harvest(res: String, amount: float) -> void:
	_harvested[res] += amount


## Called once per second: fold the last second's harvest into the smoothed income.
func update_income() -> void:
	for k in income:
		income[k] = lerpf(income[k], _harvested[k], 0.35)
		_harvested[k] = 0.0


func can_afford(cost: Dictionary) -> bool:
	return missing(cost) == ""


## Name of the first resource the player lacks for `cost`, or "".
func missing(cost: Dictionary) -> String:
	for k in cost:
		if res.get(k, 0.0) < float(cost[k]):
			return k
	return ""


func pay(cost: Dictionary) -> void:
	for k in cost:
		res[k] -= float(cost[k])


func refund(cost: Dictionary) -> void:
	for k in cost:
		res[k] += float(cost[k])
