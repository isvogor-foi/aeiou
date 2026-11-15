extends Control
## Title screen. Branding sits in a left column; the pages (main menu, skirmish
## setup, campaign, load game, settings) share one framed panel on the right with
## a header and a footer (Back on the left, the page's main action on the right).

const DB = preload("res://sim/db.gd")
const GameConfig = preload("res://sim/game_config.gd")
const Flags = preload("res://view3d/flags.gd")
const SaveGame = preload("res://sim/save_game.gd")
const GameMenu = preload("res://ui/game_menu.gd")
const AudioManager = preload("res://audio/audio_manager.gd")
const Scenario = preload("res://scenarios/scenario.gd")
const Research = preload("res://sim/research.gd")
const MenuTheme = preload("res://ui/menu_theme.gd")
const Graphics = preload("res://ui/graphics.gd")

const MAP_TYPES := {"inland": "Inland (lakes)", "coastal": "Coastal (central sea)", "islands": "Islands (transports needed)"}
const MAP_SIZES := {"small": "Small (64)", "normal": "Normal (96)", "large": "Large (128)"}
const RESOURCES := {"standard": "Standard", "high": "High", "deathmatch": "Deathmatch"}
const REVEAL := {"normal": "Black shroud", "explored": "Explored", "revealed": "Revealed"}
const VICTORIES := {"territory": "Territory (hold most of the land)", "wonders": "Wonders (build three)", "relics": "A.E.I.O.U. relics (store all five)"}
const SPEEDS := {"0": "Slow", "1": "Normal", "2": "Fast", "3": "Very fast"}
const PANEL_WIDTH := 780.0

var _faction_ids: Array = []
var _faction_index := 0
var _faction_cards: Array = []
var _desc: Label
var _realm_name: Label
var _emblem: TextureRect
var _motto: Label
var _options := {}
var _victory_boxes := {}
var _seed: SpinBox
var _audio: Node
var _page := ""
var _header_title: Label
var _header_sub: Label
var _content: VBoxContainer
var _footer: HBoxContainer
## The skirmish page keeps its choices while you visit other pages.
var _skirmish_page: Control


func _ready() -> void:
	DB.ensure_loaded()
	theme = MenuTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_faction_ids = DB.factions.keys().filter(func(f): return DB.factions[f].get("playable", true))
	_faction_ids.sort()
	_faction_index = maxi(0, _faction_ids.find(GameConfig.player_faction))
	_build_background()

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 56)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(row)
	row.add_child(_build_branding())
	row.add_child(_build_panel())

	_skirmish_page = _build_skirmish()
	_update_faction()
	_show("main")
	_audio = AudioManager.new()
	add_child(_audio)
	_audio.music("menu")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and _page != "main":
		_show("main")
		get_viewport().set_input_as_handled()


# --- Frame -------------------------------------------------------------------------

func _build_background() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.16, 0.12, 0.07))
	grad.set_color(1, Color(0.025, 0.022, 0.02))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.25, 0.35)
	tex.fill_to = Vector2(1.1, 1.2)
	var bg := TextureRect.new()
	bg.texture = tex
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)


func _build_branding() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 400
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	_emblem = TextureRect.new()
	_emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_emblem.custom_minimum_size = Vector2(240, 160)
	col.add_child(_emblem)
	var title := Label.new()
	title.text = "A.E.I.O.U."
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Flags.GOLD)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("outline_size", 10)
	col.add_child(title)
	_motto = Label.new()
	_motto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_motto.add_theme_font_size_override("font_size", 17)
	_motto.add_theme_color_override("font_color", Color(Flags.GOLD, 0.85))
	col.add_child(_motto)
	var tag := MenuTheme.muted("Six ages of Aether and steam. Many crowns, one empire.", 15)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(tag)
	return col


func _build_panel() -> Control:
	var holder := VBoxContainer.new()
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = PANEL_WIDTH
	holder.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	panel.add_child(col)
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 2)
	col.add_child(head)
	_header_title = Label.new()
	_header_title.add_theme_font_size_override("font_size", 30)
	_header_title.add_theme_color_override("font_color", Flags.GOLD)
	head.add_child(_header_title)
	_header_sub = MenuTheme.muted("", 15)
	head.add_child(_header_sub)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	col.add_child(_content)
	_footer = HBoxContainer.new()
	_footer.add_theme_constant_override("separation", 12)
	col.add_child(_footer)
	return holder


func _show(page: String) -> void:
	_page = page
	for c in _content.get_children():
		if c == _skirmish_page:
			_content.remove_child(c)
		else:
			c.queue_free()
	for c in _footer.get_children():
		c.queue_free()
	match page:
		"main":
			_header("Main Menu", "Choose how to serve the Crown.")
			_fill_main()
		"skirmish":
			_header("Skirmish", "One battle against the AI on a fresh map.")
			_content.add_child(_skirmish_page)
			_footer_buttons("Begin Battle", _start)
		"campaign":
			_header("Campaign", "1914-1955: two campaigns, a chapter for each age. Each victory opens the next.")
			_fill_campaign()
			_footer_buttons("", Callable())
		"load":
			_header("Load Game", "Saved matches, newest first. Quick-save with F5 in game.")
			_fill_load()
			_footer_buttons("", Callable())
		"settings":
			_header("Settings", "Saved automatically.")
			_fill_settings()
			_footer_buttons("", Callable())


func _header(title: String, sub: String) -> void:
	_header_title.text = title
	_header_sub.text = sub


## Back on the left, the page's main action (if any) on the right.
func _footer_buttons(primary: String, on_primary: Callable) -> void:
	var back := _button("Back", _show.bind("main"))
	back.custom_minimum_size.x = 140
	_footer.add_child(back)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer.add_child(spacer)
	if primary != "":
		var go := _button(primary, on_primary)
		go.custom_minimum_size = Vector2(220, 48)
		go.add_theme_font_size_override("font_size", 20)
		MenuTheme.make_primary(go)
		_footer.add_child(go)
		go.grab_focus.call_deferred()


func _button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 42
	b.pressed.connect(on_press)
	return b


## A tall menu button with a title and a one-line caption.
func _entry(title: String, caption: String, on_press: Callable, primary := false) -> Button:
	var b := Button.new()
	b.custom_minimum_size.y = 68
	b.pressed.connect(on_press)
	if primary:
		MenuTheme.make_primary(b)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", 20)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(m)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 21)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c := Label.new()
	c.text = caption
	c.add_theme_font_size_override("font_size", 14)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if primary:
		t.add_theme_color_override("font_color", Color(0.08, 0.06, 0.03))
		c.add_theme_color_override("font_color", Color(0.18, 0.13, 0.05))
	else:
		c.add_theme_color_override("font_color", MenuTheme.MUTED)
		b.mouse_entered.connect(func(): t.add_theme_color_override("font_color", Flags.GOLD))
		b.mouse_exited.connect(func(): t.remove_theme_color_override("font_color"))
	v.add_child(t)
	v.add_child(c)
	return b


# --- Main --------------------------------------------------------------------------

func _fill_main() -> void:
	var saves := SaveGame.list_saves()
	var first: Button = null
	if not saves.is_empty():
		var latest: Dictionary = saves[0]
		first = _entry("Continue", "%s:  %s" % [latest.slot.capitalize(), GameMenu._describe(latest)], _load.bind(latest), true)
		_content.add_child(first)
	# The caption names the next chapter to play, across both campaigns.
	var camp_caption := "1914-1955  -  every chapter won"
	for c in Scenario.CAMPAIGNS:
		var open := Scenario.unlocked(c)
		var todo: Array = c.chapters.filter(func(sid): return not Scenario.is_won(sid))
		if open > 0 and not todo.is_empty():
			var next: String = c.chapters[mini(open, c.chapters.size()) - 1]
			camp_caption = "%s  -  next: %s" % [c.years, Scenario.MISSIONS[next][0].split(". ", true, 1)[-1]]
			break
	var camp := _entry("Campaign", camp_caption, _show.bind("campaign"), first == null)
	_content.add_child(camp)
	_content.add_child(_entry("Skirmish", "A single battle against the AI, with your choice of map and rules", _show.bind("skirmish")))
	_content.add_child(_entry("Tutorial", "Learn to gather, build, train and conquer" + ("  -  completed" if Scenario.is_won("tutorial") else ""),
			_start_scenario.bind("tutorial")))
	_content.add_child(_entry("Load Game", "%d saved game%s" % [saves.size(), "" if saves.size() == 1 else "s"] if not saves.is_empty() else "No saved games yet",
			_show.bind("load")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var settings := _button("Settings", _show.bind("settings"))
	var quit := _button("Quit", func(): get_tree().quit())
	for b in [settings, quit]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	_content.add_child(_gap(4))
	_content.add_child(row)
	(first if first else camp).grab_focus.call_deferred()


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c


# --- Skirmish ----------------------------------------------------------------------

func _build_skirmish() -> Control:
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 32)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 280
	left.add_theme_constant_override("separation", 10)
	cols.add_child(left)
	left.add_child(MenuTheme.section("Your realm"))
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 10)
	left.add_child(cards)
	var group := ButtonGroup.new()
	for i in _faction_ids.size():
		var f: Dictionary = DB.factions[_faction_ids[i]]
		var card := Button.new()
		card.toggle_mode = true
		card.button_group = group
		card.custom_minimum_size = Vector2(135, 120)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.tooltip_text = f.name
		card.pressed.connect(func():
			_faction_index = i
			_update_faction())
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(v)
		var flag := TextureRect.new()
		flag.texture = Flags.texture(f.get("flag", "habsburg"), 2)
		flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		flag.custom_minimum_size = Vector2(0, 58)
		flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(flag)
		var name := Label.new()
		name.text = f.get("short", f.name)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(name)
		cards.add_child(card)
		_faction_cards.append(card)
	left.add_child(_gap(2))
	_realm_name = Label.new()
	_realm_name.add_theme_font_size_override("font_size", 20)
	left.add_child(_realm_name)
	_desc = MenuTheme.muted("", 15)
	_desc.custom_minimum_size.x = 280
	left.add_child(_desc)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	cols.add_child(right)
	right.add_child(MenuTheme.section("Battlefield"))
	var field := _grid()
	right.add_child(field)
	var diffs := {}
	for id in ["easy", "normal", "hard"]:
		diffs[id] = DB.ai.difficulties[id].name
	_option(field, "difficulty", "Opponent", diffs, GameConfig.difficulty,
			"Easy and Normal play fair. Hard gathers 25% faster and sees the whole map.")
	_option(field, "map_type", "Map", MAP_TYPES, GameConfig.map_type)
	_option(field, "map_size", "Size", MAP_SIZES, GameConfig.map_size)
	_option(field, "reveal", "Visibility", REVEAL, GameConfig.reveal)
	_seed = SpinBox.new()
	_seed.max_value = 999999
	_seed.value = GameConfig.map_seed
	_seed.tooltip_text = "The same seed always makes the same map. 0 picks one at random."
	_seed.prefix = ""
	_seed.get_line_edit().placeholder_text = "random"
	_grid_row(field, "Map seed", _seed)
	right.add_child(_gap(6))
	right.add_child(MenuTheme.section("Rules"))
	var rules := _grid()
	right.add_child(rules)
	# Only finished ages are offered (all of them with --all-ages).
	var last := DB.last_age(GameConfig.all_ages())
	var starts := {}
	var ends := {}
	for a in range(1, last + 1):
		if a < last and (a <= 4 or a >= 7):
			starts[str(a)] = DB.ages[a - 1].name
		if a >= 2:
			ends[str(a)] = DB.ages[a - 1].name
	_option(rules, "start_age", "Starting age", starts, str(GameConfig.start_age))
	var end := GameConfig.end_age if GameConfig.end_age > 0 else last
	_option(rules, "end_age", "Last age", ends, str(mini(end, last)),
			"The match ends its age ladder here: no one can advance past it.")
	_option(rules, "resources", "Resources", RESOURCES, GameConfig.resources)
	_option(rules, "speed", "Game speed", SPEEDS, str(GameConfig.speed_index))
	var checks := VBoxContainer.new()
	checks.add_theme_constant_override("separation", 0)
	for id in VICTORIES:
		var cb := CheckBox.new()
		cb.text = VICTORIES[id]
		cb.button_pressed = GameConfig.victories.get(id, true)
		_victory_boxes[id] = cb
		checks.add_child(cb)
	var vlabel := Label.new()
	vlabel.text = "Victories"
	vlabel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	vlabel.custom_minimum_size.x = 130
	vlabel.tooltip_text = "Conquest always counts."
	rules.add_child(vlabel)
	rules.add_child(checks)
	return cols


func _grid() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 16)
	g.add_theme_constant_override("v_separation", 8)
	return g


func _grid_row(g: GridContainer, text: String, control: Control) -> void:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = 130
	g.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.custom_minimum_size.y = 38
	g.add_child(control)


func _option(g: GridContainer, key: String, label: String, choices: Dictionary, current: String, tip := "") -> void:
	var ob := OptionButton.new()
	var ids: Array = choices.keys()
	for id in ids:
		ob.add_item(choices[id])
	ob.select(maxi(0, ids.find(current)))
	ob.set_meta("ids", ids)
	ob.tooltip_text = tip
	_options[key] = ob
	_grid_row(g, label, ob)


func _picked(key: String) -> String:
	var ob: OptionButton = _options[key]
	return ob.get_meta("ids")[ob.selected]


func _update_faction() -> void:
	var f: Dictionary = DB.factions[_faction_ids[_faction_index]]
	for i in _faction_cards.size():
		_faction_cards[i].set_pressed_no_signal(i == _faction_index)
	var foe: Dictionary = DB.factions[_faction_ids[(_faction_index + 1) % _faction_ids.size()]]
	_realm_name.text = f.name
	_desc.text = "%s\n\nYour enemy: %s." % [f.description, foe.name]
	_emblem.texture = Flags.texture(f.get("flag", "habsburg"), 4)
	_motto.text = "Austriae Est Imperare Orbi Universo" if f.has("motto") else "We do not die.\nWe wait."


# --- Campaign, load, settings ------------------------------------------------------

func _card() -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", MenuTheme.box(MenuTheme.CARD, MenuTheme.LINE, 1, 6, Vector2(18, 14)))
	return card


func _fill_campaign() -> void:
	# The chapters outgrow the panel on short screens: the list scrolls.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 560
	_content.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	for camp in Scenario.CAMPAIGNS:
		var open := Scenario.unlocked(camp)
		var head := Label.new()
		head.text = "%s  ·  %s" % [camp.title, camp.years]
		head.add_theme_font_size_override("font_size", 18)
		head.add_theme_color_override("font_color", Flags.GOLD if open > 0 else MenuTheme.MUTED)
		list.add_child(head)
		if open == 0:
			list.add_child(MenuTheme.muted("Win %s to begin this campaign." % Scenario.MISSIONS[camp.needs][0].split(". ", true, 1)[-1], 14))
		for i in camp.chapters.size():
			list.add_child(_chapter_card(camp.chapters[i], i >= open))


func _chapter_card(sid: String, locked: bool) -> PanelContainer:
	var info: Array = Scenario.MISSIONS[sid]
	var n := Scenario.chapter_number(sid)
	var card := _card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)
	var badge := Label.new()
	badge.text = Research.roman(n)
	badge.custom_minimum_size.x = 56
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 30)
	badge.add_theme_color_override("font_color", Flags.GOLD if not locked else MenuTheme.MUTED)
	row.add_child(badge)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	row.add_child(text)
	var title := Label.new()
	title.text = info[0].trim_prefix("%d. " % n)
	title.add_theme_font_size_override("font_size", 20)
	if locked:
		title.add_theme_color_override("font_color", MenuTheme.MUTED)
	text.add_child(title)
	text.add_child(MenuTheme.muted(info[1] if not locked else "Win the previous chapter to unlock.", 14))
	var side := VBoxContainer.new()
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(side)
	var won := Scenario.is_won(sid)
	var play := _button("Replay" if won else ("Locked" if locked else "Play"), _start_scenario.bind(sid))
	play.custom_minimum_size.x = 120
	play.disabled = locked
	if not locked and not won:
		MenuTheme.make_primary(play)
	side.add_child(play)
	if won:
		var w := Label.new()
		w.text = "✔ Won"
		w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		w.add_theme_color_override("font_color", Flags.GOLD)
		side.add_child(w)
	return card


func _fill_load() -> void:
	var saves := SaveGame.list_saves()
	if saves.is_empty():
		var l := MenuTheme.muted("No saved games yet. Press F5 during a match to quick-save, or use the game menu (Esc).", 16)
		_content.add_child(l)
		return
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = mini(saves.size(), 6) * 78
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	_content.add_child(scroll)
	for meta in saves:
		var card := _card()
		var row := HBoxContainer.new()
		card.add_child(row)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 0)
		row.add_child(text)
		var name := Label.new()
		var scen: String = meta.get("scenario", "")
		name.text = meta.slot.capitalize() + ("  -  " + Scenario.MISSIONS[scen][0] if Scenario.MISSIONS.has(scen) else "")
		name.add_theme_font_size_override("font_size", 18)
		text.add_child(name)
		text.add_child(MenuTheme.muted(GameMenu._describe(meta), 14))
		var b := _button("Load", _load.bind(meta))
		b.custom_minimum_size.x = 110
		row.add_child(b)
		list.add_child(card)


func _fill_settings() -> void:
	_content.add_child(MenuTheme.section("Audio"))
	var g := _grid()
	g.columns = 3
	_content.add_child(g)
	for key in ["master", "music", "sfx"]:
		var l := Label.new()
		l.text = {"master": "Master volume", "music": "Music", "sfx": "Sound effects"}[key]
		l.custom_minimum_size.x = 140
		g.add_child(l)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = AudioManager.get_volume(key)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.custom_minimum_size.y = 24
		g.add_child(slider)
		var pct := Label.new()
		pct.custom_minimum_size.x = 52
		pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pct.text = "%d%%" % roundi(slider.value * 100.0)
		g.add_child(pct)
		slider.value_changed.connect(func(v):
			pct.text = "%d%%" % roundi(v * 100.0)
			AudioManager.set_volume(key, v)
			AudioManager.save_settings()
			_audio.refresh_volumes())
	_content.add_child(_gap(6))
	_content.add_child(MenuTheme.section("Display"))
	var gfx := OptionButton.new()
	var names := {"auto": "Auto (%s)" % Graphics.effective().capitalize() if Graphics.quality == "auto" else "Auto",
			"high": "High: ambient occlusion, glow, detailed shadows",
			"medium": "Medium: no ambient occlusion",
			"low": "Low: also no glow, simple shadows, 75% resolution"}
	Graphics.load_settings()
	for id in Graphics.LEVELS:
		gfx.add_item(names[id])
	gfx.select(Graphics.LEVELS.find(Graphics.quality))
	gfx.item_selected.connect(func(i):
		Graphics.quality = Graphics.LEVELS[i]
		Graphics.save_settings())
	var gg := _grid()
	_grid_row(gg, "Graphics", gfx)
	_content.add_child(gg)
	var full := CheckBox.new()
	full.text = "Fullscreen"
	full.button_pressed = DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	full.toggled.connect(func(on): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
	_content.add_child(full)


# --- Starting a match --------------------------------------------------------------

func _start() -> void:
	GameConfig.player_faction = _faction_ids[_faction_index]
	GameConfig.enemy_faction = _faction_ids[(_faction_index + 1) % _faction_ids.size()]
	GameConfig.map_seed = int(_seed.value)
	GameConfig.difficulty = _picked("difficulty")
	GameConfig.map_type = _picked("map_type")
	GameConfig.map_size = _picked("map_size")
	GameConfig.start_age = int(_picked("start_age"))
	GameConfig.end_age = maxi(int(_picked("end_age")), GameConfig.start_age)
	GameConfig.resources = _picked("resources")
	GameConfig.speed_index = int(_picked("speed"))
	GameConfig.reveal = _picked("reveal")
	for id in _victory_boxes:
		GameConfig.victories[id] = _victory_boxes[id].button_pressed
	GameConfig.scenario = ""
	GameConfig.load_path = ""
	get_tree().change_scene_to_file("res://view3d/game3d.tscn")


func _start_scenario(id: String) -> void:
	GameConfig.scenario = id
	GameConfig.load_path = ""
	get_tree().change_scene_to_file("res://view3d/game3d.tscn")


func _load(meta: Dictionary) -> void:
	GameConfig.load_path = meta.path
	GameConfig.scenario = meta.get("scenario", "")
	get_tree().change_scene_to_file("res://view3d/game3d.tscn")
