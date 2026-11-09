extends Node3D
## Game scene root (3D): owns the World, steps it at a fixed rate, turns player
## input into commands, and wires up terrain, entities, fog, camera and HUD.

const DB = preload("res://sim/db.gd")
const World = preload("res://sim/world.gd")
const Entity = preload("res://sim/entity.gd")
const GameMap = preload("res://sim/game_map.gd")
const GameConfig = preload("res://sim/game_config.gd")
const Terrain = preload("res://view3d/terrain.gd")
const EntityViews = preload("res://view3d/entity_views.gd")
const FogPass = preload("res://view3d/fog_pass.gd")
const RtsCamera = preload("res://view3d/rts_camera.gd")
const Effects = preload("res://view3d/effects.gd")
const Overlay = preload("res://view3d/overlay.gd")
const Models = preload("res://view3d/models.gd")
const Flags = preload("res://view3d/flags.gd")
const Hud = preload("res://ui/hud.gd")
const GameMenu = preload("res://ui/game_menu.gd")
const MissionScreen = preload("res://ui/mission_screen.gd")
const SaveGame = preload("res://sim/save_game.gd")
const AudioManager = preload("res://audio/audio_manager.gd")
const Scenario = preload("res://scenarios/scenario.gd")
const Graphics = preload("res://ui/graphics.gd")
const Abilities = preload("res://sim/abilities.gd")
const HudIcons = preload("res://ui/hud_icons.gd")

const TILE := GameMap.TILE
const SPEEDS := [0.5, 1.0, 1.5, 2.0]
const SPEED_NAMES := ["Slow", "Normal", "Fast", "Very fast"]
const EDGE_MARGIN := 6.0
const DRAG_THRESHOLD := 6.0
const DOUBLE_CLICK_MS := 350
## Catch-up ticks per frame. Kept low so a slow machine slows the game a little
## instead of freezing the screen while it simulates several ticks in a row.
const MAX_TICKS_PER_FRAME := 3
## Screen-space pick radius for units, in pixels at the default zoom.
const UNIT_PICK_PX := 36.0
## Game seconds between autosaves.
const AUTOSAVE_EVERY := 300

enum Mode { NORMAL, PLACE, ATTACK_MOVE, CAST }

var world := World.new()
var me := 0
var selection: Array[int] = []
var groups := {}
var mode := Mode.NORMAL
## Formation for move and attack-move orders of soldiers (World.FORMATIONS).
var formation := "line"
var _cursor := ""
var place_type := ""
## Spell waiting for a target click (Mode.CAST).
var cast_ability := ""
var paused := false
var speed_index := 1
var reveal_all := false
## Cheat: the treasury never runs dry.
var cheat_resources := false
## Mouse-at-screen-edge scrolling (off for scripted captures).
var edge_scroll := true
## Ignore real mouse/keyboard input (scripted captures).
var input_enabled := true
## Current drag-select rectangle in screen space (empty when not dragging).
var drag_rect_screen := Rect2()

var camera: Camera3D
var terrain: Node3D
var entity_views: Node3D
var fog_pass: MeshInstance3D
var effects: Node3D
var hud: CanvasLayer
var game_menu: CanvasLayer
var mission_screen: CanvasLayer
var audio: Node
## Last tick our troops were in a fight (drives the battle music).
var _last_combat := -100000
var fog_tex: ImageTexture
var territory_tint_tex: ImageTexture

var _accum := 0.0
var _drag_start = null
var _rotating := false
var _rotate_drag := 0.0
var _last_click_ms := 0
var _last_click_type := ""
var _last_group_key := -1
var _last_group_ms := 0
var _idle_cycle := 0
var _ghost: Node3D
var _ghost_type := ""
var _ghost_mat: StandardMaterial3D
var _rally_flag: Node3D
## The scenario's "go here" flag.
var _marker_flag: Node3D


func _ready() -> void:
	var seed_value := GameConfig.map_seed if GameConfig.map_seed != 0 else randi() % 1000000
	var loaded := {}
	if GameConfig.load_path != "":
		loaded = SaveGame.load_into(world, GameConfig.load_path)
		GameConfig.load_path = ""
	var scripted := Scenario.create(GameConfig.scenario) if loaded.is_empty() else null
	if scripted:
		me = 0
		scripted.setup(world)
		speed_index = 1
	elif loaded.is_empty():
		world.new_game(seed_value, [GameConfig.player_faction, GameConfig.enemy_faction], me, GameConfig.difficulty,
				GameConfig.map_type, GameConfig.options())
		speed_index = GameConfig.speed_index
		reveal_all = GameConfig.reveal == "revealed"
	else:
		GameConfig.scenario = world.scenario.get("id", "")
		world.scenario_logic = Scenario.create(GameConfig.scenario)
		me = int(loaded.get("me", 0))
		speed_index = int(loaded.get("speed_index", 1))
		reveal_all = loaded.get("reveal_all", false)
	Models.set_teams(world.players)
	_build_environment()

	terrain = Terrain.new()
	add_child(terrain)
	terrain.setup(world)
	territory_tint_tex = terrain.territory_tint_tex
	entity_views = EntityViews.new()
	entity_views.gv = self
	entity_views.terrain = terrain
	add_child(entity_views)
	effects = Effects.new()
	effects.terrain = terrain
	add_child(effects)
	fog_pass = FogPass.new()
	add_child(fog_pass)
	fog_pass.setup(world, me)
	fog_tex = fog_pass.tex
	camera = RtsCamera.new()
	add_child(camera)
	camera.setup(terrain, Vector2(world.map.width, world.map.height))
	camera.make_current()
	var ambience := preload("res://view3d/ambience.gd").new()
	ambience.camera = camera
	add_child(ambience)

	var overlay_layer := CanvasLayer.new()
	overlay_layer.layer = 0
	add_child(overlay_layer)
	var overlay := Overlay.new()
	overlay.gv = self
	overlay_layer.add_child(overlay)
	hud = Hud.new()
	hud.gv = self
	add_child(hud)
	game_menu = GameMenu.new()
	game_menu.gv = self
	add_child(game_menu)
	mission_screen = MissionScreen.new()
	mission_screen.gv = self
	add_child(mission_screen)
	audio = AudioManager.new()
	add_child(audio)
	audio.music("peace")

	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var city = _my_city()
	if city:
		center_on(city.pos)
	# Start the camera pointing "up" the map toward the enemy for the bottom-right player.
	if city and city.pos.x > world.map.width * TILE * 0.5:
		camera.set_heading(PI)
	camera.update_transform()
	if not loaded.is_empty():
		_restore_view(loaded)
		hud.flash("Game loaded", 3.0)
	elif scripted:
		# Let the scenario post its opening objectives, then brief the player.
		world.scenario_logic.update(world, world.scenario)
		_consume_events()
		world.events.clear()
		mission_screen.show_briefing(scripted.id, world.scenario.get("objectives", []))
	else:
		hud.flash("Seed %d - you lead the %s against a %s opponent" % [seed_value, DB.factions[GameConfig.player_faction].name,
				DB.ai.difficulties[GameConfig.difficulty].name], 4.0)


func _build_environment() -> void:
	# Mood: a smoggy industrial dusk. A bronze haze on the horizon over a slate sky,
	# low amber sun, cool violet ambient, and a thin mist pooling in the hollows.
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.12, 0.13, 0.2)
	sky_mat.sky_horizon_color = Color(0.62, 0.42, 0.26)
	sky_mat.sky_curve = 0.12
	sky_mat.ground_horizon_color = Color(0.4, 0.3, 0.24)
	sky_mat.ground_bottom_color = Color(0.06, 0.06, 0.08)
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.36, 0.38, 0.52)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.88
	env.adjustment_contrast = 1.08
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.36, 0.33, 0.4)
	env.fog_light_energy = 0.8
	env.fog_sun_scatter = 0.25
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.4
	env.fog_height = 0.15
	env.fog_height_density = 0.25
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -38, 0)
	sun.light_energy = 1.05
	sun.light_color = Color(1.0, 0.78, 0.55)
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.85
	sun.directional_shadow_max_distance = 70.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)
	# A cool rim from the opposite side keeps silhouettes readable in the gloom.
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-30, 150, 0)
	rim.light_energy = 0.25
	rim.light_color = Color(0.5, 0.6, 1.0)
	add_child(rim)
	Graphics.apply(env, sun, get_viewport())


## Per-section milliseconds of the last frames (filled only when frame_profiling).
var frame_profiling := false
var frame_prof := {}
var _fp_t := 0


func _fp(section: String) -> void:
	if not frame_profiling:
		return
	var now := Time.get_ticks_usec()
	frame_prof[section] = frame_prof.get(section, 0) + now - _fp_t
	_fp_t = now


func _process(delta: float) -> void:
	if frame_profiling:
		_fp_t = Time.get_ticks_usec()
	if not paused:
		_accum += delta * SPEEDS[speed_index]
		var steps := 0
		while _accum >= World.DT and steps < MAX_TICKS_PER_FRAME:
			world.tick()
			_fp("sim")
			_consume_events()
			_fp("events")
			_autosave()
			_accum -= World.DT
			steps += 1
		if steps == MAX_TICKS_PER_FRAME:
			_accum = 0.0
	var alpha := clampf(_accum / World.DT, 0.0, 1.0)
	_fp("sim")
	_scroll_camera(delta)
	camera.turn(delta)
	camera.update_transform()
	var changed: Array[Vector2i] = world.map.dirty_tiles.duplicate()
	world.map.dirty_tiles.clear()
	if not changed.is_empty():
		terrain.apply_changed_tiles(changed)
		hud.minimap.paint_tiles(changed)
	terrain.sync()
	fog_pass.visible = not reveal_all
	fog_pass.sync()
	_fp("terrain_fog")
	entity_views.sync(alpha, delta)
	_fp("entity_views")
	_update_ghost()
	_update_rally_flag()
	_update_marker()
	_update_cursor()
	if cheat_resources:
		var p = world.players[me]
		for k in p.res:
			p.res[k] = maxf(p.res[k], 99999.0)
	_fp("misc")
	hud.refresh(delta)
	_fp("hud")
	audio.listener = camera.focus
	audio.hearing = camera.distance * 1.6
	audio.music("battle" if (world.tick_count - _last_combat) * World.DT < 15.0 else "peace")


# --- Save and load ---------------------------------------------------------------------

func view_state() -> Dictionary:
	return {
		"me": me, "focus": camera.focus, "yaw": camera.yaw, "distance": camera.distance,
		"selection": selection.duplicate(), "groups": groups.duplicate(true),
		"speed_index": speed_index, "reveal_all": reveal_all, "scenario": GameConfig.scenario,
	}


func _restore_view(v: Dictionary) -> void:
	camera.focus = v.get("focus", camera.focus)
	camera.set_heading(float(v.get("yaw", 0.0)))
	camera.distance = float(v.get("distance", 20.0))
	camera.update_transform()
	selection.assign(v.get("selection", []))
	groups = v.get("groups", {})


func save_game(slot: String) -> String:
	return SaveGame.save(world, view_state(), slot)


func load_game(path: String) -> void:
	GameConfig.load_path = path
	get_tree().change_scene_to_file("res://view3d/game3d.tscn")


func _autosave() -> void:
	if world.winner < 0 and world.tick_count > 0 and world.tick_count % (AUTOSAVE_EVERY * World.TICK_RATE) == 0:
		if save_game("autosave") == "":
			hud.flash("Autosaved", 1.5)


func _consume_events() -> void:
	for ev in world.events:
		match ev.type:
			"hit":
				if me in ev.get("owners", []):
					_last_combat = world.tick_count
				if _point_shown(ev.to) or _point_shown(ev.from):
					effects.add_hit(ev)
					entity_views.on_attack(ev.source, ev.to)
					audio.play(_hit_sound(ev), terrain.to3(ev.to), 0.7)
			"died":
				selection.erase(ev.id)
				if _point_shown(ev.pos) and ev.kind != Entity.RESOURCE:
					audio.play("thud" if ev.kind == Entity.UNIT else "cannon", terrain.to3(ev.pos), 0.8 if ev.kind == Entity.UNIT else 1.0)
				if ev.hero and ev.owner == me:
					hud.flash("Our hero has fallen! Revive them at a city.", 4.0)
			"cast":
				if _point_shown(ev.to) or _point_shown(ev.from):
					effects.add_cast(ev)
					entity_views.on_cast(ev.source)
					audio.play("fire" if ev.vfx == "fireball" else ("whoosh" if ev.vfx == "drain" else "magic"), terrain.to3(ev.to))
			"built":
				if ev.owner == me:
					hud.flash("Construction complete")
					audio.play("build")
			"captured":
				if ev.to == me:
					hud.flash("City captured!", 3.0)
				elif ev.from == me:
					hud.flash("One of our cities has fallen!", 3.0)
			"proclaimed":
				if ev.player == me:
					hud.flash("Proclaimed: " + DB.crown_lands[ev.land].name, 3.0)
			"researched":
				if ev.player == me:
					hud.flash("Research complete: " + ev.name, 3.0)
			"age_up":
				if ev.player == me:
					audio.play("fanfare")
					hud.flash("We enter the " + ev.name + "!", 4.0)
				else:
					hud.flash("The enemy has entered the " + ev.name, 3.0)
			"revolt", "unrest":
				audio.play("drum")
			"relics", "relic_stored", "wonder":
				audio.play("fanfare" if ev.type == "wonder" else "magic")
			"story":
				hud.story(ev.speaker, ev.text)
			"objective":
				hud.flash("New objective: " + ev.text, 4.0)
				audio.play("click")
			"objective_done":
				hud.flash("Objective complete: " + ev.text, 4.0)
				audio.play("magic")
			"victory":
				audio.play("fanfare")
				if ev.player == me and GameConfig.scenario != "":
					Scenario.record_win(GameConfig.scenario)
				var how: String = {"conquest": "by conquest", "territory": "by holding the land", "wonders": "by the wonders of the realm",
						"relics": "A.E.I.O.U. - the five relics are united"}.get(ev.get("reason", "conquest"), ev.get("text", ""))
				mission_screen.show_result(ev.player == me, how)
			"cloud":
				if _point_shown(ev.pos):
					effects.add_cloud(ev)
			"unrest":
				if ev.owner == me:
					hud.flash("Unrest! A city's %s is failing - garrison it or it will revolt." % ev.label.to_lower(), 5.0)
			"hungary_rises":
				hud.flash("Hungary rises in revolt! The insurrection fights every side - take its cities.", 6.0)
				audio.play("fanfare")
			"revolt":
				hud.flash("A city has revolted and gone over to Hungary!" if ev.owner == me else "An enemy city has revolted and joined Hungary!", 5.0)
			"charter":
				if ev.player == me:
					hud.flash("Federal Charter granted" if ev.on else "Charter revoked", 3.0)
			"tithe":
				if ev.player == me:
					hud.flash("The blood tithe is paid", 2.0)
			"wonder":
				hud.flash(("We completed the " if ev.owner == me else "The enemy completed the ") + ev.name, 4.0)
			"relics":
				hud.flash("The five AEIOU relics have appeared! Carry them to your cities with soldiers.", 5.0)
			"relic_taken":
				hud.flash(("We took the " if ev.owner == me else "The enemy took the ") + ev.name, 3.0)
			"relic_stored":
				hud.flash(("The %s is safe in our treasury" if ev.owner == me else "The enemy stored the %s") % ev.name, 3.0)
			"victory_countdown":
				hud.flash(("We" if ev.player == me else "The enemy") + " will win in %d:%02d unless stopped!" % [int(ev.seconds) / 60, int(ev.seconds) % 60], 5.0)
			"defeated":
				if ev.player == me:
					mission_screen.show_result(false, "All our cities have fallen.")


func _hit_sound(ev: Dictionary) -> String:
	if ev.get("siege", false):
		return "cannon"
	if not ev.ranged:
		return "clang"
	match ev.dtype:
		"arcane":
			return "arcane"
		"curse":
			return "curse"
		"fire":
			return "fire"
	return "musket"


func _point_shown(px: Vector2) -> bool:
	return reveal_all or world.tile_visible(me, GameMap.to_tile(px))


# --- Queries used by the view layers and HUD --------------------------------------------

func is_selected(id: int) -> bool:
	return selection.has(id)


func selected_entities() -> Array:
	var out: Array = []
	for id in selection:
		var e = world.get_entity(id)
		if e and e.alive:
			out.append(e)
	return out


func is_shown(e) -> bool:
	if e.inside >= 0:
		return false
	if reveal_all or e.owner == me:
		return true
	if e.kind == Entity.UNIT:
		return e.inside < 0 and world.is_visible_to(me, e)
	return world.tile_explored(me, GameMap.to_tile(e.pos))


## 3D anchor of an entity (interpolation-free; good enough for bars and picking).
func entity_point(e) -> Vector3:
	var view = entity_views.views.get(e.id)
	return view.node.position if view else terrain.to3(e.pos)


## Ground point under the mouse, in sim pixels.
func mouse_px() -> Vector2:
	return Terrain.to_px(camera.ground_at(get_viewport().get_mouse_position()))


## Corners of the visible ground area in sim pixels (for the minimap frame).
func view_polygon_px() -> PackedVector2Array:
	var vs := get_viewport().get_visible_rect().size
	var out := PackedVector2Array()
	for c in [Vector2.ZERO, Vector2(vs.x, 0), vs, Vector2(0, vs.y)]:
		out.append(Terrain.to_px(camera.ground_at(c)))
	return out


func placement_tile() -> Vector2i:
	var s := int(DB.buildings[place_type].size)
	var p := mouse_px() - Vector2(s, s) * TILE * 0.5 + Vector2(TILE, TILE) * 0.5
	return GameMap.to_tile(p)


## Entity under the mouse: units by screen distance, then buildings/resources by
## footprint or their projected silhouette.
func entity_at_mouse():
	var m := get_viewport().get_mouse_position()
	var pick := UNIT_PICK_PX * clampf(20.0 / camera.distance, 0.5, 1.8)
	var best = null
	var best_d := pick
	for e in world.entities.values():
		if not e.alive or e.kind != Entity.UNIT or not is_shown(e):
			continue
		var p3 := entity_point(e) + Vector3(0, entity_views.pick_height(e.id), 0)
		if camera.is_position_behind(p3):
			continue
		var d := camera.unproject_position(p3).distance_to(m)
		if d < best_d:
			best_d = d
			best = e
	if best:
		return best
	var ground := mouse_px()
	for e in world.entities.values():
		if not e.alive or e.kind == Entity.UNIT or not is_shown(e):
			continue
		if e.rect().has_point(ground):
			return e
		var top := entity_point(e) + Vector3(0, entity_views.bar_height(e.id) * 0.5, 0)
		if not camera.is_position_behind(top):
			var radius: float = e.size.x * 0.4
			var edge := camera.unproject_position(top + camera.global_basis.x * radius)
			var c := camera.unproject_position(top)
			if c.distance_to(m) < c.distance_to(edge):
				return e
	return null


func _my_city():
	for e in world.entities.values():
		if e.alive and e.owner == me and e.def.get("role", "") == "city":
			return e
	return null


# --- Actions (from HUD buttons and hotkeys) ------------------------------------------

func do_action(action: Dictionary) -> void:
	match action.kind:
		"build":
			mode = Mode.PLACE
			place_type = action.type
			hud.build_menu = ""
		"build_menu":
			hud.build_menu = action.page
		"train":
			for e in selected_entities():
				if e.kind == Entity.BUILDING and e.owner == me and action.type in e.def.get("trains", []):
					_report(world.issue({"type": "train", "player": me, "building": e.id, "unit": action.type}))
					break
		"research", "advance_age":
			for e in selected_entities():
				if e.kind == Entity.BUILDING and e.owner == me:
					var cmd := {"type": action.kind, "player": me, "building": e.id}
					if action.has("branch"):
						cmd.branch = action.branch
					var err := world.issue(cmd)
					if err == "" or selection.size() == 1:
						_report(err)
						break
		"crown_land":
			for e in selected_entities():
				if e.owner == me and world.is_city(e):
					_report(world.issue({"type": "crown_land", "player": me, "building": e.id, "land": action.land}))
					break
		"charter", "tithe":
			for e in selected_entities():
				if e.owner == me and world.is_city(e):
					var cmd := {"type": action.kind, "player": me, "building": e.id}
					if action.has("on"):
						cmd.on = action.on
					_report(world.issue(cmd))
					break
		"unload_here":
			var carriers := selected_entities().filter(func(e): return e.owner == me and not e.cargo.is_empty())
			for e in carriers:
				world.issue({"type": "unload", "player": me, "ids": [e.id], "pos": e.pos})
		"cancel_train":
			world.issue({"type": "cancel_train", "player": me, "building": action.building, "index": action.index})
		"stop":
			world.issue({"type": "stop", "player": me, "ids": selection.duplicate()})
		"attack_move":
			mode = Mode.ATTACK_MOVE
		"cast":
			var a := Abilities.def(action.ability)
			if a.target == "self":
				_report(world.issue({"type": "cast", "player": me, "ids": selection.duplicate(), "ability": action.ability}))
			else:
				mode = Mode.CAST
				cast_ability = action.ability
				hud.flash("%s: choose a target" % a.name, 1.5)
		"autocast":
			var casters := selected_entities().filter(func(e): return e.owner == me and action.ability in e.def.get("abilities", []))
			if not casters.is_empty():
				var on: bool = not casters[0].autocast.get(action.ability, false)
				world.issue({"type": "autocast", "player": me, "ids": casters.map(func(e): return e.id), "ability": action.ability, "on": on})
				hud.flash("%s autocast %s" % [Abilities.def(action.ability).name, "on" if on else "off"])


func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null)


func _report(err: String) -> void:
	if err != "":
		hud.flash(err)


func center_on(px: Vector2) -> void:
	camera.focus = Vector3(px.x / TILE, 0.0, px.y / TILE)
	camera.update_transform()


## Right-click on the minimap: same as a right-click on open ground there.
func command_move(px: Vector2) -> void:
	_smart_command(px, null, Input.is_key_pressed(KEY_SHIFT))


# --- Input -----------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or mission_screen.is_open():
		return
	if game_menu.visible:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_F10]:
			game_menu.close()
		return
	if event is InputEventMouseButton:
		_on_mouse_button(event)
	elif event is InputEventMouseMotion:
		if _rotating:
			# Middle-drag: every 120 px sideways turns the view a quarter turn.
			_rotate_drag += event.relative.x
			if absf(_rotate_drag) >= 120.0:
				camera.rotate_step(-1 if _rotate_drag > 0.0 else 1)
				_rotate_drag = 0.0
		if _drag_start != null and (event.position - _drag_start).length() > DRAG_THRESHOLD:
			drag_rect_screen = Rect2(_drag_start, Vector2.ZERO).expand(event.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		_on_key(event)


func _on_mouse_button(ev: InputEventMouseButton) -> void:
	match ev.button_index:
		MOUSE_BUTTON_LEFT:
			if ev.pressed:
				if mode == Mode.PLACE:
					var err := world.issue({"type": "place", "player": me, "ids": selection.duplicate(),
							"building": place_type, "tile": placement_tile(), "queue": ev.shift_pressed})
					_report(err)
					if err == "" and not ev.shift_pressed:
						mode = Mode.NORMAL
				elif mode == Mode.CAST:
					var t = entity_at_mouse()
					var err := world.issue({"type": "cast", "player": me, "ids": selection.duplicate(), "ability": cast_ability,
							"target": t.id if t else -1, "pos": mouse_px(), "queue": ev.shift_pressed})
					_report(err)
					if err == "":
						effects.add_marker(terrain.to3(mouse_px()), Color(0.6, 0.5, 1.0))
						if t:
							entity_views.flash_target(t.id, Color(0.4, 1.0, 0.45) if t.owner == me else Color(1.0, 0.3, 0.25))
					mode = Mode.NORMAL
				elif mode == Mode.ATTACK_MOVE:
					var t = entity_at_mouse()
					if t and t.owner >= 0 and t.owner != me:
						world.issue({"type": "attack", "player": me, "ids": selection.duplicate(), "target": t.id, "queue": ev.shift_pressed})
						_confirm_attack(t)
					else:
						world.issue({"type": "attack_move", "player": me, "ids": selection.duplicate(), "pos": mouse_px(), "queue": ev.shift_pressed,
								"formation": _formation_for(selected_entities().filter(func(e): return e.owner == me and e.kind == Entity.UNIT))})
						effects.add_marker(terrain.to3(mouse_px()), Color(1.0, 0.4, 0.3))
					mode = Mode.NORMAL
				else:
					_drag_start = ev.position
			elif _drag_start != null:
				if drag_rect_screen.has_area():
					_box_select(drag_rect_screen, ev.shift_pressed)
				else:
					_click_select(ev.shift_pressed)
				_drag_start = null
				drag_rect_screen = Rect2()
		MOUSE_BUTTON_RIGHT:
			if ev.pressed:
				if mode != Mode.NORMAL:
					mode = Mode.NORMAL
				else:
					_smart_command(mouse_px(), entity_at_mouse(), ev.shift_pressed)
		MOUSE_BUTTON_MIDDLE:
			_rotating = ev.pressed
			_rotate_drag = 0.0
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			if ev.pressed:
				camera.zoom_by(0.9 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 0.9)


## Drag-selects own units (or, with none in the box, buildings). With soldiers in
## the box, pure workers (Settlers, Thralls) are left out so the army moves alone.
func _box_select(r: Rect2, add: bool, drop_workers := true) -> void:
	var units: Array[int] = []
	var buildings: Array[int] = []
	for e in world.entities.values():
		if not e.alive or e.owner != me:
			continue
		var p3 := entity_point(e)
		if camera.is_position_behind(p3):
			continue
		if r.has_point(camera.unproject_position(p3 + Vector3(0, 0.3, 0))):
			if e.kind == Entity.UNIT:
				units.append(e.id)
			elif e.kind == Entity.BUILDING:
				buildings.append(e.id)
	var picked := units if not units.is_empty() else buildings
	if add:
		for id in picked:
			if not selection.has(id):
				selection.append(id)
	else:
		selection = picked
	if drop_workers and not units.is_empty():
		var army := selection.filter(func(id): return not _pure_worker(world.get_entity(id)))
		# Only when there's an actual fighter: Settlers with a supply wagon stay selected.
		if army.any(func(id): return _fighter(world.get_entity(id))):
			selection.assign(army)
	mode = Mode.NORMAL


func _fighter(e) -> bool:
	return e != null and e.kind == Entity.UNIT and e.can_attack()


func _pure_worker(e) -> bool:
	return e != null and e.kind == Entity.UNIT and e.def.get("role", "") == "worker"


func _click_select(add: bool) -> void:
	var e = entity_at_mouse()
	var now := Time.get_ticks_msec()
	if e == null:
		if not add:
			selection.clear()
		return
	if e.owner == me and now - _last_click_ms < DOUBLE_CLICK_MS and _last_click_type == e.type_id:
		# Double-click: everything of this type on screen.
		_box_select(get_viewport().get_visible_rect(), add, false)
		selection.assign(selection.filter(func(id): return world.get_entity(id).type_id == e.type_id))
	elif add and e.owner == me:
		if selection.has(e.id):
			selection.erase(e.id)
		else:
			selection.append(e.id)
	else:
		selection = [e.id]
	_last_click_ms = now
	_last_click_type = e.type_id


## Right-click: attack enemies, gather resources, help build, or move; buildings set rally.
func _smart_command(p: Vector2, target, queue: bool) -> void:
	var mine := selected_entities().filter(func(e): return e.owner == me)
	if mine.is_empty():
		return
	var ids: Array = mine.map(func(e): return e.id)
	var tile := GameMap.to_tile(p)
	var forest := world.map.timber_at(tile) > 0.0 and world.tile_explored(me, tile)
	var units := mine.filter(func(e): return e.kind == Entity.UNIT)
	if units.is_empty():
		var rally := {"type": "rally", "player": me, "ids": ids, "pos": p}
		if target and world.is_gatherable(target, me):
			rally.target = target.id
		elif forest:
			rally.tile = tile
		world.issue(rally)
		return
	var worker_ids: Array = units.filter(func(e): return e.is_worker()).map(func(e): return e.id)
	var other_ids: Array = units.filter(func(e): return not e.is_worker()).map(func(e): return e.id)
	var base := {"player": me, "queue": queue}
	var marker := Color(0.4, 1.0, 0.4)
	# Right-click ashore unloads ships; land transports (wagons) just drive there.
	var transports: Array = units.filter(func(e): return e.def.has("capacity") and not e.cargo.is_empty() and e.domain() == "naval")
	var land := world.map.is_walkable(tile)
	var carriers: Array = units.filter(func(e): return e.relic >= 0)
	if target and target.def.get("relic", false):
		_report(world.issue(base.merged({"type": "pickup", "ids": ids, "target": target.id})))
		effects.add_marker(terrain.to3(target.pos), Color(1.0, 0.85, 0.3))
		return
	if target and target.owner == me and world.is_relic_holder(target) and not carriers.is_empty():
		world.issue(base.merged({"type": "store", "ids": carriers.map(func(e): return e.id), "target": target.id}))
		effects.add_marker(terrain.to3(target.pos), Color(1.0, 0.85, 0.3))
		return
	if target and target.owner == me and target.def.has("capacity") and not target in units:
		world.issue(base.merged({"type": "board", "ids": ids, "target": target.id}))
		effects.add_marker(terrain.to3(target.pos), Color(0.5, 0.8, 1.0))
		return
	if not transports.is_empty() and land and target == null:
		world.issue(base.merged({"type": "unload", "ids": transports.map(func(e): return e.id), "pos": p}))
		effects.add_marker(terrain.to3(p), Color(0.5, 0.8, 1.0))
		return
	if target and target.owner >= 0 and target.owner != me:
		world.issue(base.merged({"type": "attack", "ids": ids, "target": target.id}))
		_confirm_attack(target)
		return
	elif target and world.is_gatherable(target, me) and not worker_ids.is_empty():
		world.issue(base.merged({"type": "gather", "ids": worker_ids, "target": target.id}))
		_move_or_skip(base, other_ids, p)
		marker = Color(1.0, 0.85, 0.3)
	elif target and target.owner == me and target.constructing and not worker_ids.is_empty():
		world.issue(base.merged({"type": "build", "ids": worker_ids, "target": target.id}))
		_move_or_skip(base, other_ids, p)
	elif forest and not worker_ids.is_empty():
		world.issue(base.merged({"type": "gather", "ids": worker_ids, "tile": tile}))
		_move_or_skip(base, other_ids, p)
		marker = Color(1.0, 0.85, 0.3)
	else:
		world.issue(base.merged({"type": "move", "ids": units.map(func(e): return e.id), "pos": p, "formation": _formation_for(units)}))
	effects.add_marker(terrain.to3(p), marker)


func _move_or_skip(base: Dictionary, ids: Array, p: Vector2) -> void:
	if not ids.is_empty():
		world.issue(base.merged({"type": "move", "ids": ids, "pos": p, "formation": formation}))


## The chosen formation when the group has soldiers in it (Settlers just gather round).
func _formation_for(units: Array) -> String:
	return formation if units.any(func(e): return e.can_attack() and not e.is_worker()) else ""


## A clear "attack!" acknowledgement: the target's ring blinks red, a red marker
## drops on it and a clash of steel sounds.
func _confirm_attack(target) -> void:
	entity_views.flash_target(target.id, Color(1.0, 0.25, 0.2))
	effects.add_marker(terrain.to3(target.pos), Color(1.0, 0.3, 0.25))
	audio.play("clang", null, 0.45)
	hud.flash("Attack: " + (target.title if target.title != "" else String(target.def.get("name", target.type_id))), 1.2)


## What the cursor would act on: [cursor name, hint text, entity for the ring, ring colour].
func _cursor_state() -> Array:
	var t = entity_at_mouse()
	match mode:
		Mode.CAST:
			var a := Abilities.def(cast_ability)
			match a.target:
				"unit_ally":
					var ok: bool = t != null and t.kind == Entity.UNIT and t.owner == me
					if t != null and not ok:
						return ["cursor_forbid", "%s: choose one of YOUR units" % a.name, null, Color.WHITE]
					return ["cursor_spell_ally", "%s: click one of your units" % a.name, t if ok else null, Color(0.4, 1.0, 0.45)]
				"unit_enemy":
					var ok: bool = t != null and t.kind != Entity.RESOURCE and t.owner >= 0 and t.owner != me
					if ok and a.has("target_domain") and (t.kind != Entity.UNIT or t.domain() != a.target_domain):
						ok = false
					if t != null and not ok:
						return ["cursor_forbid", "%s: choose an ENEMY%s" % [a.name, " ship" if a.get("target_domain", "") == "naval" else ""], null, Color.WHITE]
					return ["cursor_spell_enemy", "%s: click an enemy" % a.name, t if ok else null, Color(1.0, 0.3, 0.25)]
				_:
					return ["cursor_spell_ground", "%s: click the ground" % a.name, null, Color.WHITE]
		Mode.ATTACK_MOVE:
			var enemy: bool = t != null and t.owner >= 0 and t.owner != me
			return ["cursor_sword", "Attack-move: click the ground, or an enemy to attack it", t if enemy else null, Color(1.0, 0.3, 0.25)]
		Mode.NORMAL:
			if t != null and t.owner >= 0 and t.owner != me and selected_entities().any(func(e): return e.owner == me and e.kind == Entity.UNIT and e.can_attack()):
				return ["cursor_sword", "", t, Color(1.0, 0.3, 0.25)]
	return ["", "", null, Color.WHITE]


func _update_cursor() -> void:
	var st := _cursor_state()
	if st[0] != _cursor:
		_cursor = st[0]
		if _cursor == "":
			Input.set_custom_mouse_cursor(null)
		else:
			var hot := Vector2(2, 2) if _cursor == "cursor_sword" else Vector2(16, 16)
			Input.set_custom_mouse_cursor(HudIcons.get_icon(_cursor), Input.CURSOR_ARROW, hot)
	entity_views.show_hover(st[2], st[3])
	hud.set_cursor_hint(st[1], get_viewport().get_mouse_position())


func _on_key(ev: InputEventKey) -> void:
	var key := ev.keycode
	if ev.alt_pressed and key >= KEY_1 and key <= KEY_5:
		hud.set_formation(World.FORMATIONS[key - KEY_1])
		return
	if key >= KEY_0 and key <= KEY_9:
		_control_group(key - KEY_0, ev.ctrl_pressed)
		return
	if ev.alt_pressed and (key == KEY_Q or key == KEY_E):
		camera.rotate_step(1 if key == KEY_Q else -1)
		return
	match key:
		KEY_ESCAPE:
			if mode != Mode.NORMAL:
				mode = Mode.NORMAL
			elif hud.close_build_menu():
				pass
			elif not selection.is_empty():
				selection.clear()
			else:
				game_menu.toggle()
			return
		KEY_F5:
			var err := save_game("quick")
			hud.flash(err if err != "" else "Quick-saved (F9 to load)", 2.0)
			return
		KEY_PERIOD:
			_select_idle_worker()
			return
		KEY_H:
			var city = _my_city()
			if city:
				selection = [city.id]
				center_on(city.pos)
			return
		KEY_SPACE:
			var sel := selected_entities()
			if not sel.is_empty():
				center_on(sel[0].pos)
			return
		KEY_BRACKETLEFT:
			camera.rotate_step(1)
			return
		KEY_BRACKETRIGHT:
			camera.rotate_step(-1)
			return
		KEY_BACKSPACE:
			camera.target_yaw = 0.0
			camera.distance = 20.0
			return
		KEY_P, KEY_PAUSE:
			paused = not paused
			return
		KEY_EQUAL, KEY_KP_ADD:
			speed_index = mini(speed_index + 1, SPEEDS.size() - 1)
			hud.flash("Speed: " + SPEED_NAMES[speed_index])
			return
		KEY_MINUS, KEY_KP_SUBTRACT:
			speed_index = maxi(speed_index - 1, 0)
			hud.flash("Speed: " + SPEED_NAMES[speed_index])
			return
		KEY_F9:
			if ev.ctrl_pressed:
				reveal_all = not reveal_all
			elif FileAccess.file_exists(SaveGame.slot_path("quick")):
				load_game(SaveGame.slot_path("quick"))
			else:
				hud.flash("No quick-save yet (F5)")
			return
		KEY_F10:
			game_menu.toggle()
			return
	hud.try_hotkey(key)


func _control_group(n: int, assign: bool) -> void:
	if assign:
		groups[n] = selection.duplicate()
		hud.flash("Group %d set" % n)
		return
	var ids: Array = groups.get(n, [])
	var live: Array[int] = []
	for id in ids:
		var e = world.get_entity(id)
		if e and e.alive:
			live.append(id)
	if live.is_empty():
		return
	selection = live
	var now := Time.get_ticks_msec()
	if _last_group_key == n and now - _last_group_ms < DOUBLE_CLICK_MS:
		center_on(world.get_entity(live[0]).pos)
	_last_group_key = n
	_last_group_ms = now


func _select_idle_worker() -> void:
	var idle: Array = []
	for e in world.entities.values():
		if e.alive and e.owner == me and e.is_worker() and e.orders.is_empty():
			idle.append(e)
	if idle.is_empty():
		hud.flash("No idle workers")
		return
	idle.sort_custom(func(a, b): return a.id < b.id)
	_idle_cycle = (_idle_cycle + 1) % idle.size()
	var e = idle[_idle_cycle]
	selection = [e.id]
	center_on(e.pos)


func idle_worker_count() -> int:
	var n := 0
	for e in world.entities.values():
		if e.alive and e.owner == me and e.is_worker() and e.orders.is_empty():
			n += 1
	return n


# --- Camera, placement ghost, rally flag ------------------------------------------------

func _scroll_camera(delta: float) -> void:
	var dir := Vector2.ZERO
	if input_enabled:
		if Input.is_key_pressed(KEY_LEFT): dir.x -= 1
		if Input.is_key_pressed(KEY_RIGHT): dir.x += 1
		if Input.is_key_pressed(KEY_UP): dir.y -= 1
		if Input.is_key_pressed(KEY_DOWN): dir.y += 1
	if edge_scroll and input_enabled and DisplayServer.window_is_focused() and not _rotating:
		var m := get_viewport().get_mouse_position()
		var vs := get_viewport().get_visible_rect().size
		if Rect2(Vector2.ZERO, vs).has_point(m):
			if m.x < EDGE_MARGIN: dir.x -= 1
			if m.x > vs.x - EDGE_MARGIN: dir.x += 1
			if m.y < EDGE_MARGIN: dir.y -= 1
			if m.y > vs.y - EDGE_MARGIN: dir.y += 1
	if dir != Vector2.ZERO:
		camera.pan(dir.normalized(), delta)


func _update_ghost() -> void:
	if mode != Mode.PLACE:
		if _ghost:
			_ghost.queue_free()
			_ghost = null
			_ghost_type = ""
		terrain.show_placement(Vector2i.ZERO, 0, false)
		return
	var size := int(DB.buildings[place_type].size)
	if _ghost_type != place_type:
		if _ghost:
			_ghost.queue_free()
		_ghost = Models.make_footprint_model(DB.visuals.buildings.get(place_type, {}), me, size)
		Models.override_material(_ghost, _ghost_mat)
		add_child(_ghost)
		_ghost_type = place_type
	var top_left := placement_tile()
	var ok := world.placement_error(me, place_type, top_left) == ""
	_ghost_mat.albedo_color = Color(0.4, 1.0, 0.45, 0.45) if ok else Color(1.0, 0.3, 0.25, 0.45)
	var center := Vector2(top_left) + Vector2(size, size) * 0.5
	_ghost.position = Vector3(center.x, terrain.height_at(center.x, center.y), center.y)
	terrain.show_placement(top_left, size, ok)


var _marker_flags: Array = []
var _rail_built := false


## Scenario flags: the single "marker" plus any "markers" (open capture points).
func _update_marker() -> void:
	var spots: Array = world.scenario.get("markers", []).duplicate()
	var at = world.scenario.get("marker", null)
	if at != null:
		spots.push_front(at)
	while _marker_flags.size() < spots.size():
		var f := Flags.make("habsburg", 2.0, 1.0)
		add_child(f)
		_marker_flags.append(f)
	for i in _marker_flags.size():
		_marker_flags[i].visible = i < spots.size()
		if i < spots.size():
			_marker_flags[i].position = terrain.to3(spots[i])
	if not _rail_built and world.scenario.has("rail"):
		_rail_built = true
		_build_rail(world.scenario.rail)


## Sleepers and two iron rails along the scenario's rail line.
func _build_rail(line: Array) -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.32, 0.22, 0.14)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.45, 0.45, 0.48)
	iron.metallic = 0.7
	var sleeper := BoxMesh.new()
	sleeper.size = Vector3(0.7, 0.05, 0.12)
	sleeper.material = wood
	var xfs: Array = []
	var rails := ImmediateMesh.new()
	for i in line.size() - 1:
		var a: Vector3 = terrain.to3(line[i]) + Vector3(0, 0.03, 0)
		var b: Vector3 = terrain.to3(line[i + 1]) + Vector3(0, 0.03, 0)
		var dir := (b - a).normalized()
		var side := dir.cross(Vector3.UP).normalized() * 0.22
		var n := maxi(1, int(a.distance_to(b) / 0.35))
		for k in n:
			var p := a.lerp(b, k / float(n))
			xfs.append(Transform3D(Basis.looking_at(dir, Vector3.UP), p))
		for off in [side, -side]:
			rails.surface_begin(Mesh.PRIMITIVE_LINES, iron)
			rails.surface_add_vertex(a + off + Vector3(0, 0.05, 0))
			rails.surface_add_vertex(b + off + Vector3(0, 0.05, 0))
			rails.surface_end()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sleeper
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)
	var rmi := MeshInstance3D.new()
	rmi.mesh = rails
	add_child(rmi)


func _update_rally_flag() -> void:
	var rally := {}
	for e in selected_entities():
		if e.owner == me and e.kind == Entity.BUILDING and not e.rally.is_empty():
			rally = e.rally
			break
	if rally.is_empty():
		if _rally_flag:
			_rally_flag.visible = false
		return
	if _rally_flag == null:
		_rally_flag = Flags.make(DB.factions[world.players[me].faction].get("flag", "habsburg"), 1.2, 0.6)
		add_child(_rally_flag)
	_rally_flag.visible = true
	_rally_flag.position = terrain.to3(rally.pos)
