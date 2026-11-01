extends RefCounted
## Match setup chosen in the menu and read by the game scene.

static var player_faction := "monarchy"
static var enemy_faction := "covenant"
## 0 picks a random seed when the match starts.
static var map_seed := 0
static var difficulty := "normal"
static var map_type := "inland"
## Skirmish options (see rules.json "skirmish").
static var map_size := "normal"
static var start_age := 1
static var resources := "standard"
static var victories := {"territory": true, "wonders": true, "relics": true}
static var speed_index := 1
## "explored" starts with the map explored; "revealed" shows everything all game.
static var reveal := "normal"


## The options dictionary World.new_game() takes.
static func options() -> Dictionary:
	return {"map_size": map_size, "start_age": start_age, "resources": resources, "victories": victories.duplicate(),
			"explored": reveal != "normal"}
## Campaign or tutorial scenario to play ("" = skirmish), and a save file to load instead.
static var scenario := ""
static var load_path := ""
