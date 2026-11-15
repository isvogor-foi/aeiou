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
## The last age of the match; 0 means the last playable age.
static var end_age := 0
static var resources := "standard"
static var victories := {"territory": true, "wonders": true, "relics": true}
static var speed_index := 1
## "explored" starts with the map explored; "revealed" shows everything all game.
static var reveal := "normal"


## The options dictionary World.new_game() takes.
static func options() -> Dictionary:
	return {"map_size": map_size, "start_age": start_age, "end_age": end_age, "all_ages": all_ages(),
			"resources": resources, "victories": victories.duplicate(),
			"explored": reveal != "normal"}
## Developers can play the unfinished ages (marked "wip" in ages.json):
##   tools/godot --path . -- --all-ages
static func all_ages() -> bool:
	return "--all-ages" in OS.get_cmdline_user_args()


## Cheats are hidden unless the game is started with -c (or --cheats):
##   tools/godot --path . -c
## They show the Cheats menu and Ctrl+F9, and open every campaign chapter.
static func cheats() -> bool:
	for a in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if a == "-c" or a == "--cheats":
			return true
	return false


## Campaign or tutorial scenario to play ("" = skirmish), and a save file to load instead.
static var scenario := ""
static var load_path := ""
