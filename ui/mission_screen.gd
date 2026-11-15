extends CanvasLayer
## Full-screen mission cards that pause the match:
## - the briefing before a scripted mission starts ("Begin"),
## - the result when the match is decided: Victory or Defeat, the objectives,
##   and what to do next (continue to the next mission, retry, main menu).

const GameConfig = preload("res://sim/game_config.gd")
const Scenario = preload("res://scenarios/scenario.gd")
const MenuTheme = preload("res://ui/menu_theme.gd")
const Flags = preload("res://view3d/flags.gd")

const RED := Color(0.86, 0.32, 0.26)

var gv
var _box: VBoxContainer
var _pending := {}
var _delay := 0.0


func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.theme = MenuTheme.get_theme()
	panel.custom_minimum_size.x = 560
	center.add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	panel.add_child(_box)
	visible = false


## True while a card is up (the view ignores game input then).
func is_open() -> bool:
	return visible


# --- Briefing --------------------------------------------------------------------

func show_briefing(scenario_id: String, objectives: Array) -> void:
	# Each campaign opens with title cards that tell the premise.
	var camp := Scenario.campaign_of(scenario_id)
	if not camp.is_empty() and scenario_id == camp.chapters[0]:
		_intro_page(0, scenario_id, objectives)
	else:
		_briefing_card(scenario_id, objectives)


func _intro_page(i: int, scenario_id: String, objectives: Array) -> void:
	var camp := Scenario.campaign_of(scenario_id)
	var intro: Array = camp.intro
	var page: Array = intro[i]
	_clear()
	_kicker("%s  ·  %d / %d" % [camp.title, i + 1, intro.size()])
	_title(page[0], Flags.GOLD)
	_text(page[1])
	var next := _button("Continue", _intro_page.bind(i + 1, scenario_id, objectives) if i + 1 < intro.size()
			else _briefing_card.bind(scenario_id, objectives))
	MenuTheme.make_primary(next)
	if i == 0:
		_button("Skip the introduction", _briefing_card.bind(scenario_id, objectives))
	_open()
	next.grab_focus.call_deferred()


func _briefing_card(scenario_id: String, objectives: Array) -> void:
	var info: Array = Scenario.MISSIONS.get(scenario_id, [scenario_id.capitalize(), "", "", ""])
	_clear()
	var camp := Scenario.campaign_of(scenario_id)
	_kicker("%s  ·  Chapter %d" % [camp.title, Scenario.chapter_number(scenario_id)] if not camp.is_empty() else "Training")
	_title(_strip_number(info[0]), Flags.GOLD)
	if info.size() > 3 and info[3] != "":
		_text(info[2], MenuTheme.MUTED, 13)
		_text(info[3])
	else:
		_text(info[1])
	if not objectives.is_empty():
		_kicker("Objectives")
		for o in objectives:
			_text("◆  " + str(o.text), MenuTheme.TEXT)
	_text("A victory or defeat ends the mission. You will be asked before moving on.", MenuTheme.MUTED, 13)
	var go := _button("Begin", _close)
	MenuTheme.make_primary(go)
	_open()
	go.grab_focus.call_deferred()


# --- A choice ----------------------------------------------------------------------

## A decision the scenario asks for (scenario.ask): one button per option. The pick
## goes into the match's scenario flags and into campaign progress.
func show_choice(ev: Dictionary) -> void:
	_clear()
	_kicker("A decision")
	_title(ev.title, Flags.GOLD)
	_text(ev.text)
	var first: Button = null
	for opt in ev.options:
		var b := _button(opt[1], _pick.bind(ev.key, opt[0]))
		if first == null:
			first = b
			MenuTheme.make_primary(b)
	_open()
	first.grab_focus.call_deferred()


func _pick(key: String, id: String) -> void:
	gv.world.scenario.flags["choice_" + key] = id
	Scenario.record_choice(key, id)
	_close()


# --- Result ----------------------------------------------------------------------

## Queues the result card; it appears after a short beat so the last blow and
## the fanfare land first.
func show_result(won: bool, reason: String) -> void:
	if not _pending.is_empty() or visible and _box.has_meta("result"):
		return
	_pending = {"won": won, "reason": reason}
	_delay = 1.6


func _process(delta: float) -> void:
	if _pending.is_empty():
		return
	_delay -= delta
	if _delay <= 0.0:
		var p := _pending
		_pending = {}
		_build_result(p.won, p.reason)


func _build_result(won: bool, reason: String) -> void:
	_clear()
	_box.set_meta("result", true)
	var sid: String = GameConfig.scenario
	var info: Array = Scenario.MISSIONS.get(sid, [])
	if not info.is_empty():
		_kicker(_strip_number(info[0]))
	_title("Victory" if won else "Defeat", Flags.GOLD if won else RED)
	if reason != "":
		_text(reason)
	var objectives: Array = gv.world.scenario.get("objectives", [])
	if not objectives.is_empty():
		_kicker("Objectives")
		for o in objectives:
			# On a win, standing goals ("X must survive") were met too.
			var met: bool = o.done or won
			_text(("✔  " if met else "✘  ") + str(o.text), MenuTheme.TEXT if met else MenuTheme.MUTED)
	var secs := int(gv.world.tick_count * gv.world.DT)
	_text("Time: %d:%02d" % [secs / 60, secs % 60], MenuTheme.MUTED, 13)

	var camp := Scenario.campaign_of(sid)
	var chapters: Array = camp.get("chapters", [])
	var i := chapters.find(sid)
	var menu_offered := false
	if won and i >= 0 and i + 1 < chapters.size():
		var next: String = chapters[i + 1]
		_text("Chapter complete. Next: " + _strip_number(Scenario.MISSIONS[next][0]), Flags.GOLD, 15)
		MenuTheme.make_primary(_button("Continue to the next chapter", _start.bind(next)))
		_button("Replay this mission", _start.bind(sid))
	elif won and i >= 0:
		_text(camp.epilogue, MenuTheme.TEXT, 15)
		var later := Scenario.CAMPAIGNS.filter(func(c): return c.needs == sid)
		if not later.is_empty():
			_text("%s is complete. Viribus Unitis! A new campaign begins: %s (%s)." % [camp.title, later[0].title, later[0].years], Flags.GOLD, 15)
			MenuTheme.make_primary(_button("Begin " + later[0].title, _start.bind(later[0].chapters[0])))
			_button("Return to the main menu", _to_menu)
		else:
			_text("The campaign is complete. Viribus Unitis!", Flags.GOLD, 15)
			MenuTheme.make_primary(_button("Return to the main menu", _to_menu))
		menu_offered = true
		_button("Replay this mission", _start.bind(sid))
	elif won and sid == "tutorial":
		_text("Training complete. The campaign awaits.", Flags.GOLD, 15)
		MenuTheme.make_primary(_button("Start the campaign", _start.bind(Scenario.CAMPAIGN[0])))
	elif won:
		MenuTheme.make_primary(_button("Return to the main menu", _to_menu))
		menu_offered = true
		_button("Keep playing", _close)
	elif sid != "":
		MenuTheme.make_primary(_button("Retry the mission", _start.bind(sid)))
	else:
		MenuTheme.make_primary(_button("Return to the main menu", _to_menu))
		menu_offered = true
		_button("Play again", _start.bind(""))
	if not menu_offered:
		_button("Main menu", _to_menu)
	_open()
	(_box.get_children().filter(func(c): return c is Button)[0] as Button).grab_focus.call_deferred()


# --- Actions -----------------------------------------------------------------------

func _start(scenario_id: String) -> void:
	GameConfig.scenario = scenario_id
	GameConfig.load_path = ""
	gv.get_tree().change_scene_to_file("res://view3d/game3d.tscn")


func _to_menu() -> void:
	gv.get_tree().change_scene_to_file("res://ui/main_menu.tscn")


func _open() -> void:
	gv.paused = true
	if gv.game_menu.visible:
		gv.game_menu.visible = false
	visible = true


func _close() -> void:
	visible = false
	gv.paused = false


# --- Building blocks ---------------------------------------------------------------

func _clear() -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	_box.remove_meta("result")


func _kicker(text: String) -> void:
	var l := Label.new()
	l.text = text.to_upper()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", MenuTheme.MUTED)
	_box.add_child(l)


func _title(text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 34)
	l.add_theme_color_override("font_color", color)
	_box.add_child(l)


func _text(text: String, color := MenuTheme.TEXT, size := 15) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 520
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	_box.add_child(l)


func _button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 44
	b.pressed.connect(on_press)
	_box.add_child(b)
	return b


## "2. The Siege of Vienna" -> "The Siege of Vienna".
static func _strip_number(title: String) -> String:
	var parts := title.split(". ", true, 1)
	return parts[1] if parts.size() == 2 and parts[0].is_valid_int() else title
