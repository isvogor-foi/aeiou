extends RefCounted
## One thing on the map: a unit, a building, or a resource node.
## Plain data; behaviour lives in World and UnitAI.

const TILE := 32
enum { UNIT, BUILDING, RESOURCE }

var id := 0
var type_id := ""
## A scenario-given name ("Sarajevo Town Hall"), shown instead of the type name.
var title := ""
var def: Dictionary = {}
var kind := UNIT
var owner := -1
## Centre point in world pixels.
var pos := Vector2.ZERO
## Position at the previous tick, for render interpolation.
var prev_pos := Vector2.ZERO
var hp := 1.0
var max_hp := 1.0
var alive := true

# Footprint (buildings and resources). Units have size ZERO.
var tile := Vector2i.ZERO
var size := Vector2i.ZERO

# Unit state
var orders: Array = []
var path := PackedVector2Array()
var path_index := 0
var path_goal := Vector2i(-1, -1)
## The entity the current path approaches (lets _approach reuse its goal tile).
var approach_id := -1
## Seconds since this unit last moved (attacking doesn't reset it; Hold the Line).
var stand := 0.0
## Tile and sight of this entity's last fog reveal (skips repeats when fog is sticky).
var fog_key := Vector3i(-1, -1, -1)
var repath := 0
var stuck := 0
var attack_cd := 0.0
var carry_type := ""
var carry_amount := 0.0
var facing := Vector2.DOWN
## Spell id -> tick when it's ready again; spell id -> autocast on/off.
var cooldowns := {}
var autocast := {}
## Timed effects: [{type, amount, until}] (e.g. shields).
var effects: Array = []
## Summoned units vanish at this tick (0 = permanent).
var expires_tick := 0
## Charge passive: distance walked since the last blow, and whether the next blow is a charge.
var moved := 0.0
var charge_ready := false
## Transports: ids of units aboard. Passengers: id of the transport they ride in (-1 = none).
var cargo: Array = []
var inside := -1
## Wagon forts: deployed (immobile, firing) or on the move.
var deployed := false
## Siege set-up progress (seconds), air-rifle magazine, seconds standing still (stealth).
var setup := 0.0
var ammo := -1
var reload_left := 0.0
var still := 0.0
## Movement multiplier set by the world each second (Semmering Railway).
var speed_mult := 1.0
## Relics: carried by a unit, or stored in a relic holder (also kept in `inside`, which hides it).
var relic := -1
var carried_by := -1
## Cities of crown-land factions: the land this city was proclaimed ("" = not yet).
var crown_land := ""
## Cities: loyalty (or Dread) 0-100, its target and the factors behind it (for the UI),
## when it was last conquered, when enemies were last inside, charter and tithe state.
var loyalty := 100.0
var loyalty_target := 100.0
var loyalty_factors: Array = []
var captured_tick := -1
var last_enemy_tick := -100000
var charter := false
var charter_tick := 0
var tithe_ready_tick := 0

# Building state
var target_id := -1
var constructing := false
var build_progress := 0.0
## Training queue: [{type, progress}]
var queue: Array = []
## Rally point: {pos, target, tile} or empty.
var rally: Dictionary = {}

# Resource state (-1 = inexhaustible)
var amount := 0.0


func rect() -> Rect2:
	return Rect2(Vector2(tile) * TILE, Vector2(size) * TILE)


## Gathers and builds (Settlers, and militia like the Grenzer).
func is_worker() -> bool:
	return def.get("role", "") == "worker" or def.get("gathers", false)


func domain() -> String:
	if _domain == "":
		_domain = def.get("domain", "ground")
	return _domain


var _domain := ""


func is_hero() -> bool:
	return def.get("hero", false)


func can_attack() -> bool:
	return float(def.get("damage", 0)) > 0.0
