extends CanvasLayer
## In-game interface, kept light so the map stays visible: translucent resource
## chips top-left, status top-right, the command grid ("building blocks")
## bottom-left with the selection panel beside it, the minimap bottom-right;
## messages and story float at the top centre.

const DB = preload("res://sim/db.gd")
const Entity = preload("res://sim/entity.gd")
const World = preload("res://sim/world.gd")
const Minimap = preload("res://ui/minimap.gd")
const Research = preload("res://sim/research.gd")
const Abilities = preload("res://sim/abilities.gd")
const Portrait = preload("res://ui/portrait.gd")
const Flags = preload("res://view3d/flags.gd")
const IconFactory = preload("res://ui/icon_factory.gd")
const HudIcons = preload("res://ui/hud_icons.gd")

const MARGIN := 12.0
const CARD_COLUMNS := 5
const CARD_BUTTON_SIZE := Vector2(70, 70)
const MINIMAP_SIZE := Vector2(208, 208)
const PORTRAIT_SIZE := Vector2(104, 104)
const INFO_WIDTH := 340.0
## Build menu pages for workers: building role -> page.
const MILITARY_ROLES := ["military", "tower"]

var gv
var minimap: Control
var portrait: SubViewportContainer
var icons: SubViewport
## Open worker build page: "" (orders), "economy" or "military".
var build_menu := ""
var _selection_key := ""

var _res_labels := {}
var _res_income := {}
var _res_chips := {}
var _pop_label: Label
var _age_label: Label
var _state_label: Label
var _state_icon: TextureRect
var _victory_label: Label
var _boss_panel: PanelContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var _objectives: Label
var _story: PanelContainer
var _story_text: RichTextLabel
var _story_queue: Array = []
var _story_time := 0.0
var _idle_button: Button
var _command_panel: PanelContainer
var _info_panel: PanelContainer
var _hint: Label
var _tile_styles := {}
var _info_title: Label
var _info_body: Label
var _queue_box: HBoxContainer
var _train_row: VBoxContainer
var _train_label: Label
var _train_bar: ProgressBar
var _queue_tiles: Array = []
var _formation_bar: HBoxContainer
var _relic_bar: HBoxContainer
var _relic_buttons := {}
var _relic_refresh := 0.0
var _formation_buttons := {}
var _cursor_hint: Label
var _cheat_menu: PopupMenu
## One small tile per selected unit when several are selected.
var _group_box: HFlowContainer
var _group_key := ""
var _group_tiles: Array = []
var _card: GridContainer
var _flash: Label
var _banner: VBoxContainer
var _banner_title: Label
var _banner_sub: Label

var _card_entries: Array = []
var _card_signature := ""
var _queue_signature := ""
var _flash_time := 0.0


func _ready() -> void:
	icons = IconFactory.new()
	add_child(icons)
	_build_resource_bar()
	_build_status_bar()
	_build_relic_bar()
	_build_bottom_left()
	_build_minimap()
	_flash = _floating_label(17)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_flash.offset_top = 56
	_flash.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_flash)
	_build_banner()
	_victory_label = _floating_label(16)
	_victory_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_victory_label.offset_top = 14
	_victory_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_victory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_victory_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	add_child(_victory_label)
	_build_scenario_panels()
	_build_boss_bar()


## A label that floats over the map: outlined so it reads on any terrain.
func _floating_label(font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Objectives (top left, under the resources) and the story box (top centre).
func _build_scenario_panels() -> void:
	_objectives = _floating_label(14)
	_objectives.position = Vector2(MARGIN + 2, 52)
	add_child(_objectives)
	_story = PanelContainer.new()
	_story.add_theme_stylebox_override("panel", _glass(0.72, 10, Vector2(16, 10)))
	_story.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_story.offset_left = -340
	_story.offset_right = 340
	_story.offset_top = 92
	_story.offset_bottom = 170
	_story.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_story.visible = false
	add_child(_story)
	_story_text = RichTextLabel.new()
	_story_text.bbcode_enabled = true
	_story_text.fit_content = true
	_story_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_story_text.add_theme_font_size_override("normal_font_size", 15)
	_story_text.add_theme_font_size_override("bold_font_size", 15)
	_story.add_child(_story_text)


## A boss's name and health across the top of the screen.
func _build_boss_bar() -> void:
	_boss_panel = PanelContainer.new()
	_boss_panel.add_theme_stylebox_override("panel", _glass(0.65, 10, Vector2(14, 6)))
	_boss_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_boss_panel.offset_left = -260
	_boss_panel.offset_right = 260
	_boss_panel.offset_top = 48
	_boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_panel.visible = false
	add_child(_boss_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	_boss_panel.add_child(col)
	_boss_name = Label.new()
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name.add_theme_font_size_override("font_size", 15)
	_boss_name.add_theme_color_override("font_color", Color(1.0, 0.82, 0.5))
	col.add_child(_boss_name)
	_boss_bar = ProgressBar.new()
	_boss_bar.custom_minimum_size = Vector2(480, 12)
	_boss_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	bg.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.75, 0.12, 0.12)
	fill.set_corner_radius_all(4)
	_boss_bar.add_theme_stylebox_override("background", bg)
	_boss_bar.add_theme_stylebox_override("fill", fill)
	col.add_child(_boss_bar)


func _refresh_boss() -> void:
	var b = gv.world.get_entity(int(gv.world.scenario.get("boss", -1)))
	_boss_panel.visible = b != null and b.alive
	if _boss_panel.visible:
		_boss_name.text = _name_of(b)
		_boss_bar.max_value = b.max_hp
		_boss_bar.value = b.hp


func story(speaker: String, text: String) -> void:
	_story_queue.append([speaker, text])
	if not _story.visible:
		_next_story()


func _next_story() -> void:
	if _story_queue.is_empty():
		_story.visible = false
		return
	var line: Array = _story_queue.pop_front()
	_story_text.text = "[b][color=#e8c35a]%s[/color][/b]\n%s" % [line[0], line[1]]
	_story_time = clampf(2.5 + line[1].length() * 0.055, 4.0, 11.0)
	_story.visible = true


func _refresh_scenario(delta: float) -> void:
	var sc: Dictionary = gv.world.scenario
	var lines: Array[String] = []
	for o in sc.get("objectives", []):
		lines.append(("✔ " if o.done else "◆ ") + o.text)
	_objectives.text = "\n".join(lines)
	if _story.visible and not gv.paused:
		_story_time -= delta
		if _story_time <= 0.0:
			_next_story()


## The player's faction palette (Monarchy: black and gold).
func _ui_color(key: String, fallback: Color) -> Color:
	var ui: Dictionary = DB.factions[gv.world.players[gv.me].faction].get("ui", {})
	return DB.color_of(ui[key]) if ui.has(key) else fallback


# --- Layout ------------------------------------------------------------------------

## Translucent rounded background for floating panels and chips.
func _glass(alpha := 0.62, radius := 10, pad := Vector2(10, 8)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.04, 0.035, alpha)
	sb.border_color = Color(_ui_color("border", Color(0.55, 0.45, 0.25)), 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad.x
	sb.content_margin_right = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_bottom = pad.y
	return sb


func _icon_rect(tex: Texture2D, px := Vector2(18, 18)) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = px
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## A pill with an icon, a value and a small trailing note: [chip, value, note, icon].
func _chip(icon: Texture2D, tooltip := "", icon_size := Vector2(18, 18)) -> Array:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", _glass(0.5, 13, Vector2(9, 3)))
	chip.tooltip_text = tooltip
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)
	var icon_rect := _icon_rect(icon, icon_size)
	row.add_child(icon_rect)
	var value := Label.new()
	value.add_theme_font_size_override("font_size", 14)
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(value)
	var note := Label.new()
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", Color(0.75, 0.75, 0.7))
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(note)
	return [chip, value, note, icon_rect]


func _build_resource_bar() -> void:
	var bar := HBoxContainer.new()
	bar.position = Vector2(MARGIN, 10)
	bar.add_theme_constant_override("separation", 6)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	var faction: Dictionary = DB.factions[gv.world.players[gv.me].faction]
	var flag := _chip(Flags.texture(faction.get("flag", "habsburg")), faction.name, Vector2(27, 18))
	flag[1].visible = false
	flag[2].visible = false
	bar.add_child(flag[0])
	for k in DB.RESOURCE_TYPES:
		var c := _chip(HudIcons.get_icon(k))
		bar.add_child(c[0])
		_res_chips[k] = c[0]
		_res_labels[k] = c[1]
		_res_income[k] = c[2]
	var pop := _chip(HudIcons.get_icon("pop"), "Population: used / housing")
	bar.add_child(pop[0])
	_pop_label = pop[1]


## The AEIOU relic tracker under the status bar: one framed icon per relic,
## coloured by who holds it; hover for the story and where it is, click to look.
func _build_relic_bar() -> void:
	_relic_bar = HBoxContainer.new()
	_relic_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_relic_bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_relic_bar.offset_right = -MARGIN
	_relic_bar.offset_left = -MARGIN
	_relic_bar.offset_top = 46
	_relic_bar.add_theme_constant_override("separation", 4)
	add_child(_relic_bar)
	var title := Label.new()
	title.text = "A.E.I.O.U."
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 4)
	title.tooltip_text = "The five relics of the House of Austria. Store all five in your cities and hold them to win."
	title.mouse_filter = Control.MOUSE_FILTER_PASS
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_relic_bar.add_child(title)
	for id in ["relic_crown", "relic_lance", "relic_bowl", "relic_horn", "relic_orb"]:
		var b := Button.new()
		b.icon = HudIcons.get_icon(id)
		b.expand_icon = true
		b.custom_minimum_size = Vector2(32, 32)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): _look_at_relic(id))
		_relic_bar.add_child(b)
		_relic_buttons[id] = b


func _look_at_relic(id: String) -> void:
	for r in gv.relics():
		if r.type_id == id:
			var st: Dictionary = gv.relic_status(r)
			if st.pos != null:
				gv.center_on(st.pos)
			else:
				flash("%s: %s" % [r.def.name, st.where], 2.5)


func _refresh_relics() -> void:
	var v: Dictionary = gv.world.rules.get("victory", {})
	var on: bool = v.get("enabled", {}).get("relics", true)
	_relic_bar.visible = on
	if not on:
		return
	var by_id := {}
	for r in gv.relics():
		by_id[r.type_id] = r
	for id in _relic_buttons:
		var b: Button = _relic_buttons[id]
		var d: Dictionary = DB.resources[id]
		var col := Color(0.3, 0.3, 0.3)
		var status := "Not yet appeared: the relics surface when someone reaches Age %d." % int(v.get("relics_spawn_age", 5))
		if by_id.has(id):
			var st: Dictionary = gv.relic_status(by_id[id])
			col = st.color
			status = st.where.substr(0, 1).to_upper() + st.where.substr(1) + "."
		b.modulate = Color(1, 1, 1, 0.45) if not by_id.has(id) or gv.relic_status(by_id[id]).state == "hidden" else Color.WHITE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.07, 0.06, 0.8)
		sb.border_color = col
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(6)
		for state in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(state, sb)
		b.tooltip_text = "%s\n%s\n\n%s" % [d.name, d.get("description", ""), status]


func _build_status_bar() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bar.offset_right = -MARGIN
	bar.offset_left = -MARGIN
	bar.offset_top = 10
	bar.add_theme_constant_override("separation", 6)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	var age := _chip(HudIcons.get_icon("crown"))
	_age_label = age[1]
	bar.add_child(age[0])
	_idle_button = _chip_button(HudIcons.get_icon("idle"), "Select the next idle worker [.]", gv._select_idle_worker)
	bar.add_child(_idle_button)
	var state := _chip(HudIcons.get_icon("play"), "Game speed: + / -    Pause: P")
	_state_icon = state[3]
	_state_label = state[1]
	bar.add_child(state[0])
	var cheats := _chip_button(HudIcons.get_icon("spell"), "Cheats", Callable())
	cheats.text = "Cheats"
	cheats.pressed.connect(func(): _open_cheats(cheats))
	bar.add_child(cheats)
	_cheat_menu = PopupMenu.new()
	_cheat_menu.add_check_item("Infinite resources", 0)
	_cheat_menu.add_check_item("Reveal map  (Ctrl+F9)", 1)
	_cheat_menu.add_check_item("Fast building and training", 2)
	_cheat_menu.add_check_item("Fast research and ages", 3)
	_cheat_menu.id_pressed.connect(_on_cheat)
	add_child(_cheat_menu)
	bar.add_child(_chip_button(HudIcons.get_icon("menu"), "Menu: save, load, quit [F10]", func(): gv.game_menu.toggle()))


func _open_cheats(anchor: Control) -> void:
	_cheat_menu.set_item_checked(0, gv.cheat_resources)
	_cheat_menu.set_item_checked(1, gv.reveal_all)
	_cheat_menu.set_item_checked(2, gv.world.players[gv.me].cheat_build)
	_cheat_menu.set_item_checked(3, gv.world.players[gv.me].cheat_advance)
	var r := anchor.get_global_rect()
	_cheat_menu.position = Vector2i(int(r.position.x), int(r.end.y + 4))
	_cheat_menu.popup()


func _on_cheat(id: int) -> void:
	match id:
		0:
			gv.cheat_resources = not gv.cheat_resources
			flash("Infinite resources " + ("on" if gv.cheat_resources else "off"))
		1:
			gv.reveal_all = not gv.reveal_all
			flash("Map revealed" if gv.reveal_all else "Map hidden")
		2:
			var p = gv.world.players[gv.me]
			p.cheat_build = not p.cheat_build
			flash("Fast building and training " + ("on" if p.cheat_build else "off"))
		3:
			var p = gv.world.players[gv.me]
			p.cheat_advance = not p.cheat_advance
			flash("Fast research and ages " + ("on" if p.cheat_advance else "off"))


func _chip_button(icon: Texture2D, tooltip: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.icon = icon
	b.add_theme_constant_override("icon_max_width", 18)
	b.add_theme_font_size_override("font_size", 14)
	b.tooltip_text = tooltip
	b.focus_mode = Control.FOCUS_NONE
	var hover := _glass(0.7, 13, Vector2(9, 3))
	hover.border_color = Flags.GOLD
	b.add_theme_stylebox_override("normal", _glass(0.5, 13, Vector2(9, 3)))
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("disabled", _glass(0.3, 13, Vector2(9, 3)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if on_press.is_valid():
		b.pressed.connect(on_press)
	return b


## Picks the formation for the next move and attack-move orders.
func set_formation(f: String) -> void:
	gv.formation = f
	for k in _formation_buttons:
		_formation_buttons[k].set_pressed_no_signal(k == f)
	flash("Formation: " + f.capitalize(), 1.0)


## Text next to the mouse while targeting ("Heal: click one of your units").
func set_cursor_hint(text: String, at: Vector2) -> void:
	if _cursor_hint == null:
		_cursor_hint = Label.new()
		_cursor_hint.add_theme_font_size_override("font_size", 13)
		_cursor_hint.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
		_cursor_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		_cursor_hint.add_theme_constant_override("outline_size", 5)
		_cursor_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_cursor_hint)
	_cursor_hint.visible = text != ""
	if text != "":
		_cursor_hint.text = text
		_cursor_hint.position = at + Vector2(24, 20)


## Command grid and selection panel side by side along the bottom-left.
func _build_bottom_left() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.offset_left = MARGIN
	row.offset_bottom = -MARGIN
	row.offset_top = -MARGIN
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	_command_panel = PanelContainer.new()
	_command_panel.add_theme_stylebox_override("panel", _glass(0.6, 12, Vector2(8, 8)))
	_command_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(_command_panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	_command_panel.add_child(stack)
	_formation_bar = HBoxContainer.new()
	_formation_bar.add_theme_constant_override("separation", 4)
	stack.add_child(_formation_bar)
	var tips := {"line": "Line [Alt+1]: a wide front, ranged in the rear ranks",
			"column": "Column [Alt+2]: narrow and deep, for roads and passes",
			"square": "Square [Alt+3]: a hollow box that faces every way",
			"wedge": "Wedge [Alt+4]: a spearhead to punch through",
			"loose": "Loose [Alt+5]: spread out against bombardment"}
	for f in World.FORMATIONS:
		var b := Button.new()
		b.toggle_mode = true
		b.icon = HudIcons.get_icon("formation_" + f)
		b.expand_icon = true
		b.custom_minimum_size = Vector2(30, 30)
		b.tooltip_text = tips.get(f, f)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): set_formation(f))
		_formation_bar.add_child(b)
		_formation_buttons[f] = b
	_card = GridContainer.new()
	_card.columns = CARD_COLUMNS
	_card.add_theme_constant_override("h_separation", 6)
	_card.add_theme_constant_override("v_separation", 6)
	stack.add_child(_card)

	_info_panel = PanelContainer.new()
	_info_panel.add_theme_stylebox_override("panel", _glass(0.6, 12, Vector2(10, 10)))
	_info_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(_info_panel)
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 10)
	_info_panel.add_child(info_row)
	portrait = Portrait.new()
	info_row.add_child(portrait)
	portrait.custom_minimum_size = PORTRAIT_SIZE
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var info := VBoxContainer.new()
	info.custom_minimum_size.x = INFO_WIDTH
	info.add_theme_constant_override("separation", 3)
	info_row.add_child(info)
	_info_title = Label.new()
	_info_title.add_theme_font_size_override("font_size", 16)
	_info_title.add_theme_color_override("font_color", _ui_color("accent", Color.WHITE))
	info.add_child(_info_title)
	_info_body = Label.new()
	_info_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_body.add_theme_font_size_override("font_size", 12)
	_info_body.add_theme_color_override("font_color", Color(0.86, 0.85, 0.8))
	info.add_child(_info_body)
	_train_row = VBoxContainer.new()
	_train_row.add_theme_constant_override("separation", 2)
	info.add_child(_train_row)
	_train_label = Label.new()
	_train_label.add_theme_font_size_override("font_size", 12)
	_train_label.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0))
	_train_row.add_child(_train_label)
	_train_bar = ProgressBar.new()
	_train_bar.custom_minimum_size = Vector2(INFO_WIDTH, 10)
	_train_bar.show_percentage = false
	_train_bar.max_value = 1.0
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0, 0, 0, 0.6)
	bar_bg.set_corner_radius_all(4)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.45, 0.75, 1.0)
	bar_fill.set_corner_radius_all(4)
	_train_bar.add_theme_stylebox_override("background", bar_bg)
	_train_bar.add_theme_stylebox_override("fill", bar_fill)
	_train_row.add_child(_train_bar)
	_queue_box = HBoxContainer.new()
	_queue_box.add_theme_constant_override("separation", 4)
	info.add_child(_queue_box)
	_group_box = HFlowContainer.new()
	_group_box.add_theme_constant_override("h_separation", 4)
	_group_box.add_theme_constant_override("v_separation", 4)
	_group_box.custom_minimum_size.x = INFO_WIDTH
	info.add_child(_group_box)

	_hint = _floating_label(12)
	_hint.text = "Left-click or drag to select  ·  right-click to command  ·  [.] idle worker  ·  [H] home  ·  [P] pause  ·  [F10] menu"
	_hint.modulate = Color(1, 1, 1, 0.75)
	_hint.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(_hint)

	var normal := _glass(0.55, 8, Vector2(4, 4))
	normal.content_margin_bottom = 17
	var hover: StyleBoxFlat = normal.duplicate()
	hover.border_color = Flags.GOLD
	hover.bg_color = Color(0.13, 0.11, 0.07, 0.82)
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color(0.03, 0.03, 0.03, 0.45)
	disabled.border_color = Color(0.3, 0.3, 0.3, 0.3)
	_tile_styles = {"normal": normal, "hover": hover, "pressed": hover, "hover_pressed": hover, "disabled": disabled, "focus": StyleBoxEmpty.new()}


func _build_minimap() -> void:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _glass(0.6, 12, Vector2(6, 6)))
	frame.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	frame.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	frame.grow_vertical = Control.GROW_DIRECTION_BEGIN
	frame.offset_right = -MARGIN
	frame.offset_bottom = -MARGIN
	frame.offset_left = -MARGIN
	frame.offset_top = -MARGIN
	add_child(frame)
	minimap = Minimap.new()
	minimap.gv = gv
	minimap.custom_minimum_size = MINIMAP_SIZE
	frame.add_child(minimap)


func _build_banner() -> void:
	_banner = VBoxContainer.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.visible = false
	add_child(_banner)
	_banner_title = Label.new()
	_banner_title.add_theme_font_size_override("font_size", 72)
	_banner_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_banner_title.add_theme_color_override("font_outline_color", Color.BLACK)
	_banner_title.add_theme_constant_override("outline_size", 12)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_title)
	_banner_sub = Label.new()
	_banner_sub.add_theme_font_size_override("font_size", 22)
	_banner_sub.add_theme_color_override("font_outline_color", Color.BLACK)
	_banner_sub.add_theme_constant_override("outline_size", 6)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_sub)


## "Monarchy holds 3 wonders: victory in 4:12" for every running victory countdown.
func _victory_text() -> String:
	var w = gv.world
	var v: Dictionary = w.rules.get("victory", {})
	var holds := {"territory": float(v.get("territory_hold", 0)), "wonders": float(v.get("wonder_hold", 0)), "relics": float(v.get("relic_hold", 0))}
	var what := {"territory": "holds %d%% of the land" % roundi(float(v.get("territory_share", 0)) * 100.0),
			"wonders": "holds %d wonders" % int(v.get("wonders_needed", 3)), "relics": "holds all five AEIOU relics"}
	var lines: Array[String] = []
	for pid in w.victory_since:
		for kind in w.victory_since[pid]:
			var left: float = holds[kind] - (w.tick_count - w.victory_since[pid][kind]) * w.DT
			var who: String = "You" if pid == gv.me else DB.factions[w.players[pid].faction].short
			lines.append("%s %s: victory in %d:%02d" % [who, what[kind].replace("holds", "hold" if pid == gv.me else "holds"), int(left) / 60, int(left) % 60])
	return "\n".join(lines)


func flash(msg: String, seconds := 2.0) -> void:
	_flash.text = msg
	_flash.modulate.a = 1.0
	_flash_time = seconds


func show_banner(title: String, sub: String) -> void:
	_banner_title.text = title
	_banner_sub.text = sub
	_banner.visible = true


# --- Per-frame refresh -------------------------------------------------------------------

func refresh(delta: float) -> void:
	var p = gv.world.players[gv.me]
	_relic_refresh -= delta
	if _relic_refresh <= 0.0:
		_relic_refresh = 0.4
		_refresh_relics()
	for k in _res_labels:
		_res_labels[k].text = str(int(p.res[k]))
		_res_income[k].text = "+%.1f" % p.income[k]
		var capped: bool = p.income[k] > 0.0 and p.income[k] >= p.gather_cap(k) - 0.05
		_res_income[k].modulate = Color(1.0, 0.8, 0.35) if capped else Color.WHITE
		_res_chips[k].tooltip_text = "%s: %d\nGathering %.1f/s of a %.1f/s cap (shown gold when capped).\n%s research raises caps." % [
				DB.resource_name(k), int(p.res[k]), p.income[k], p.gather_cap(k), Research.branch("charms").name]
	_pop_label.text = "%d / %d" % [p.pop_used, p.pop_cap]
	_pop_label.modulate = Color(1, 0.5, 0.4) if p.pop_used >= p.pop_cap else Color.WHITE
	_age_label.text = "%s  ·  %d/%d cities" % [DB.ages[p.age - 1].name, gv.world.city_count(gv.me), gv.world.city_limit(gv.me)]
	var idle: int = gv.idle_worker_count()
	_idle_button.text = str(idle)
	_idle_button.disabled = idle == 0
	_state_label.text = "Paused" if gv.paused else gv.SPEED_NAMES[gv.speed_index]
	_state_icon.texture = HudIcons.get_icon("pause" if gv.paused else "play")
	_victory_label.text = _victory_text()
	_refresh_scenario(delta)
	_refresh_boss()
	if _flash_time > 0.0:
		_flash_time -= delta
		_flash.modulate.a = clampf(_flash_time / 0.5, 0.0, 1.0)
	_refresh_info()
	_refresh_card()
	_command_panel.visible = not _card_entries.is_empty()
	var soldiers: bool = gv.selected_entities().any(func(e): return e.owner == gv.me and e.kind == Entity.UNIT and e.can_attack() and not e.is_worker() and e.domain() == "ground")
	_formation_bar.visible = soldiers
	for f in _formation_buttons:
		_formation_buttons[f].set_pressed_no_signal(f == gv.formation)
	_info_panel.visible = not gv.selection.is_empty()
	_hint.visible = gv.selection.is_empty()
	minimap.tick(delta)


func _refresh_info() -> void:
	var sel: Array = gv.selected_entities()
	portrait.show_entity(sel[0] if not sel.is_empty() else null)
	# A new selection closes any open build page.
	var key := ",".join(sel.map(func(e): return str(e.id)))
	if key != _selection_key:
		_selection_key = key
		build_menu = ""
	_set_queue([])
	_refresh_group(sel if sel.size() > 1 else [])
	if sel.is_empty():
		_info_title.text = ""
		_info_body.text = ""
		return
	if sel.size() > 1:
		_info_title.text = "%d selected" % sel.size()
		var counts := {}
		for e in sel:
			var n := _name_of(e)
			counts[n] = counts.get(n, 0) + 1
		var parts: Array[String] = []
		for n in counts:
			parts.append("%d x %s" % [counts[n], n])
		_info_body.text = ",  ".join(parts)
		return
	var e = sel[0]
	_info_title.text = _name_of(e)
	var lines: Array[String] = []
	if e.owner >= 0:
		lines.append("%s    HP %d / %d" % [DB.factions[gv.world.players[e.owner].faction].short, ceili(e.hp), int(e.max_hp)])
	match e.kind:
		Entity.UNIT:
			if e.can_attack(): lines.append("%s damage %d  |  %s armour  |  range %s  |  speed %s" % [
					str(e.def.dtype).capitalize(), int(e.def.damage), str(e.def.armor).capitalize(),
					str(e.def.range), str(e.def.speed)])
			if e.deployed:
				lines.append("Deployed as a Wagenburg: immobile, fires with its garrison. Press D to pack up.")
			var vu: float = gv.world.viribus_unitis(e) if e.owner == gv.me else 0.0
			if vu > 0.0:
				lines.append("Viribus Unitis: +%d%% damage (troops of several crown lands nearby)" % roundi(vu * 100.0))
			if e.def.has("capacity"):
				lines.append("Aboard: %d / %d population. Right-click a shore to unload." % [int(e.def.capacity) - gv.world.cargo_space(e), int(e.def.capacity)])
			if e.def.has("supply_radius"):
				lines.append("Supplies troops within %d tiles: no attrition in enemy land" % int(e.def.supply_radius))
			if e.carry_amount > 0.0:
				lines.append("Carrying %d %s" % [int(e.carry_amount), DB.resource_name(e.carry_type)])
			if e.relic >= 0 and gv.world.get_entity(e.relic):
				lines.append("Carrying the %s - right-click one of your cities to store it." % gv.world.get_entity(e.relic).def.name)
			var status: Array[String] = []
			for id in e.def.get("abilities", []):
				var left := Abilities.cooldown_left(gv.world, e, id)
				status.append("%s %s%s" % [Abilities.def(id).name, "ready" if left <= 0.0 else "%ds" % ceili(left),
						" (auto)" if e.autocast.get(id, false) else ""])
			var shield := Abilities.effect_amount(e, "shield")
			if shield > 0.0:
				status.append("Warded (%d)" % ceili(shield))
			if e.expires_tick > 0:
				status.append("Fades in %ds" % ceili((e.expires_tick - gv.world.tick_count) * gv.world.DT))
			if not status.is_empty():
				lines.append("  |  ".join(status))
			if e.def.has("description"):
				lines.append(e.def.description)
		Entity.BUILDING:
			if e.constructing:
				lines.append("Under construction: %d%%" % int(e.build_progress * 100))
			else:
				# One compact line of what the building does.
				var traits: Array[String] = []
				if e.def.has("pop_provided"):
					traits.append("+%d population" % int(e.def.pop_provided))
				if e.def.has("dropoff"):
					traits.append("drop-off")
				if e.can_attack():
					traits.append("defends: %s %d, range %s" % [str(e.def.dtype), int(e.def.damage), str(e.def.range)])
				if e.def.has("border_radius"):
					traits.append("captured at 0 HP")
				if not traits.is_empty():
					lines.append(", ".join(traits))
				if gv.world.is_city(e) and e.owner >= 0 and not gv.world.players[e.owner].is_rebels:
					lines.append(_loyalty_line(e))
				var label: String = DB.factions[gv.world.players[e.owner].faction].get("lands_label", "Crown land") if e.owner >= 0 else ""
				if e.crown_land != "":
					var land: Dictionary = DB.crown_lands[e.crown_land]
					lines.append("%s: %s. %s" % [label, land.name, land.description])
				elif gv.world.is_city(e) and e.owner == gv.me and DB.factions[gv.world.players[e.owner].faction].get("crown_lands", false):
					lines.append("No %s yet: choose one in the grid." % label.to_lower())
				if gv.world.is_relic_holder(e) and e.owner >= 0:
					lines.append("Relics stored: %d / 5" % gv.world.relics_stored(e.owner))
				if e.def.has("mods") and e.def.get("role", "") == "wonder":
					lines.append(e.def.description)
				if e.def.has("research") and e.owner >= 0:
					var levels: Array[String] = []
					for b in e.def.research:
						var lv: int = gv.world.players[e.owner].techs.get(b, 0)
						levels.append("%s %s" % [Research.branch(b).name, Research.roman(lv) if lv > 0 else "-"])
					lines.append("  ".join(levels))
			if e.owner == gv.me:
				_set_queue(e.queue, e)
		Entity.RESOURCE when e.def.get("relic", false):
			lines.append(e.def.description)
			lines.append("Right-click it with a soldier, then right-click one of your cities to store it (AEIOU victory).")
		Entity.RESOURCE:
			var rname := DB.resource_name(e.def.resource)
			lines.append("Endless %s" % rname if e.amount < 0 else "%d %s remaining" % [int(e.amount), rname])
	_info_body.text = "\n".join(lines)


## Small tiles for a multi-selection: picture and health bar per unit.
## Click one to select just it; Shift-click to drop it from the selection.
const GROUP_TILE := Vector2(42, 42)
const GROUP_MAX := 32


func _refresh_group(sel: Array) -> void:
	var shown := sel.slice(0, GROUP_MAX)
	var key := ",".join(shown.map(func(e): return str(e.id)))
	if key != _group_key:
		_group_key = key
		for c in _group_box.get_children():
			c.queue_free()
		_group_tiles.clear()
		for e in shown:
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = GROUP_TILE
			b.expand_icon = true
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			for state in _tile_styles:
				var st = _tile_styles[state]
				if st is StyleBoxFlat:
					st = st.duplicate()
					st.content_margin_bottom = 6
					st.content_margin_left = 2
					st.content_margin_right = 2
					st.content_margin_top = 2
				b.add_theme_stylebox_override(state, st)
			b.tooltip_text = "%s  (HP %d / %d)\nClick: select only this one.  Shift-click: remove from selection." % [_name_of(e), ceili(e.hp), int(e.max_hp)]
			var bar_bg := ColorRect.new()
			bar_bg.color = Color(0, 0, 0, 0.7)
			bar_bg.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			bar_bg.offset_top = -5
			bar_bg.offset_bottom = -2
			bar_bg.offset_left = 3
			bar_bg.offset_right = -3
			bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(bar_bg)
			var bar := ColorRect.new()
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bar.size = Vector2(GROUP_TILE.x - 6, 3)
			bar_bg.add_child(bar)
			b.pressed.connect(_on_group_tile.bind(e.id))
			_group_box.add_child(b)
			_group_tiles.append([b, bar, e.id])
	for t in _group_tiles:
		var e = gv.world.get_entity(t[2])
		if e == null:
			continue
		var frac: float = clampf(e.hp / maxf(1.0, e.max_hp), 0.0, 1.0)
		t[1].size.x = (GROUP_TILE.x - 6) * frac
		t[1].color = Color(0.35, 0.85, 0.35) if frac > 0.5 else (Color(0.95, 0.75, 0.2) if frac > 0.25 else Color(0.9, 0.3, 0.25))
		if t[0].icon == null:
			var kind := "unit" if e.kind == Entity.UNIT else "building"
			t[0].icon = icons.icon(kind, e.type_id, e.owner if e.owner >= 0 else gv.me)


func _on_group_tile(id: int) -> void:
	if Input.is_key_pressed(KEY_SHIFT):
		gv.selection.erase(id)
	else:
		gv.selection.assign([id])
	gv.audio.play("click", null, 0.6)


## "Loyalty 64 ▼ (target 52): Far from the capital −12, Garrison +6, …"
func _loyalty_line(e) -> String:
	var lc: Dictionary = DB.factions[gv.world.players[e.owner].faction].get("loyalty", {})
	var trend := "▲" if e.loyalty_target > e.loyalty + 0.5 else ("▼" if e.loyalty_target < e.loyalty - 0.5 else "")
	var parts: Array[String] = []
	for f in e.loyalty_factors:
		if f[0] != "Base":
			parts.append("%s %+d" % [f[0], roundi(f[1])])
	var extra := ""
	if e.charter:
		extra = "  [Federal Charter: never below %d]" % int(gv.world.rules.loyalty.charter_floor)
	return "%s %d %s (target %d)%s\n  %s" % [lc.get("label", "Loyalty"), roundi(e.loyalty), trend, roundi(e.loyalty_target), extra, ",  ".join(parts)]


func _name_of(e) -> String:
	if e.title != "":
		return e.title
	var faction: String = gv.world.players[e.owner].faction if e.owner >= 0 else ""
	return DB.display_name(e.def, faction)


func _queue_label(item: Dictionary) -> String:
	match item.kind:
		"unit":
			return DB.units[item.type].glyph
		"tech":
			var level: int = Research.next_level(gv.world.players[gv.me], item.type)
			return "%s %s" % [Research.branch(item.type).name.left(3), Research.roman(level)]
		"age":
			return "Age"
	return "?"


func _queue_tooltip(item: Dictionary) -> String:
	match item.kind:
		"unit":
			return DB.units[item.type].name
		"tech":
			var level: int = Research.next_level(gv.world.players[gv.me], item.type)
			return Research.level_info(item.type, level).name
		"age":
			return "Advancing to " + DB.ages[gv.world.players[gv.me].age].name
	return ""


## The building's queue: "Training: Settler  45%" with a bar, then one picture
## tile per queued item (click to cancel); the first tile carries its own bar.
func _set_queue(queue: Array, building = null) -> void:
	_train_row.visible = building != null and not queue.is_empty()
	if _train_row.visible:
		var item: Dictionary = queue[0]
		var verb: String = {"unit": "Training", "tech": "Researching", "age": "Advancing"}.get(item.kind, "Working")
		_train_label.text = "%s: %s   %d%%%s" % [verb, _queue_tooltip(item).trim_prefix("Advancing to "), int(item.progress * 100),
				"   (+%d queued)" % (queue.size() - 1) if queue.size() > 1 else ""]
		_train_bar.value = item.progress
	var sig := ""
	for item in queue:
		sig += item.type + ","
	if building:
		sig += str(building.id)
	if sig != _queue_signature:
		_queue_signature = sig
		for c in _queue_box.get_children():
			c.queue_free()
		_queue_tiles.clear()
		for i in queue.size():
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(38, 38)
			b.expand_icon = true
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			for state in _tile_styles:
				var st = _tile_styles[state]
				if st is StyleBoxFlat:
					st = st.duplicate()
					st.content_margin_bottom = 6
					st.content_margin_top = 2
					st.content_margin_left = 2
					st.content_margin_right = 2
				b.add_theme_stylebox_override(state, st)
			b.tooltip_text = "%s - click to cancel" % _queue_tooltip(queue[i])
			var item: Dictionary = queue[i]
			if item.kind == "tech":
				var ri := _research_icon(item.type)
				if ri.has("icon_tex"):
					b.icon = ri.icon_tex
				else:
					item = item.merged({"icon_unit": ri.icon[1]})
			elif queue[i].kind == "age":
				b.icon = HudIcons.get_icon("crown")
			var bar := ColorRect.new()
			bar.color = Color(0.45, 0.75, 1.0)
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bar.position = Vector2(3, 33)
			bar.size = Vector2(0, 3)
			b.add_child(bar)
			b.pressed.connect(gv.do_action.bind({"kind": "cancel_train", "building": building.id, "index": i}))
			_queue_box.add_child(b)
			_queue_tiles.append([b, bar, item])
	for i in _queue_tiles.size():
		var t: Array = _queue_tiles[i]
		if i < queue.size():
			t[1].size.x = 32.0 * queue[i].progress if i == 0 else 0.0
		if t[0].icon == null and t[2].kind == "unit":
			t[0].icon = icons.icon("unit", t[2].type, gv.me)
		elif t[0].icon == null and t[2].has("icon_unit"):
			t[0].icon = icons.icon("unit", t[2].icon_unit, gv.me)


# --- Command grid --------------------------------------------------------------------------

func _refresh_card() -> void:
	var entries := _entries_for_selection()
	var sig := ""
	for en in entries:
		sig += "%s:%s|" % [en.label, en.get("locked", "")]
	if sig != _card_signature:
		_card_signature = sig
		_card_entries = entries
		for c in _card.get_children():
			c.queue_free()
		for en in entries:
			var b := _make_tile(en)
			b.tooltip_text = en.tooltip
			if en.get("locked", "") != "":
				b.disabled = true
				b.tooltip_text += "\n\n" + en.locked
			b.pressed.connect(gv.do_action.bind(en.action))
			b.pressed.connect(func(): gv.audio.play("click", null, 0.6))
			if en.has("alt_action"):
				b.gui_input.connect(_on_card_gui_input.bind(en.alt_action))
			_card.add_child(b)
	var p = gv.world.players[gv.me]
	var buttons := _card.get_children().filter(func(c): return not c.is_queued_for_deletion())
	for i in mini(buttons.size(), _card_entries.size()):
		var en: Dictionary = _card_entries[i]
		var cost: Dictionary = en.get("cost", {})
		buttons[i].modulate = Color.WHITE if p.can_afford(cost) else Color(1, 0.55, 0.5)
		if en.has("icon") and buttons[i].icon == null:
			buttons[i].icon = icons.icon(en.icon[0], en.icon[1], gv.me)


## One "building block" of the command grid: icon, [hotkey] badge, name underneath.
func _make_tile(en: Dictionary) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = CARD_BUTTON_SIZE
	for state in _tile_styles:
		b.add_theme_stylebox_override(state, _tile_styles[state])
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	if en.has("icon_tex"):
		b.icon = en.icon_tex
	elif not en.has("icon"):
		b.icon = HudIcons.get_icon(_action_icon(en.action))
	var name := Label.new()
	name.text = en.label
	name.clip_text = true
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	name.offset_top = -17
	name.offset_left = 2
	name.offset_right = -2
	name.offset_bottom = -2
	name.add_theme_font_size_override("font_size", 10)
	name.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	name.add_theme_constant_override("outline_size", 3)
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(name)
	var key := Label.new()
	key.text = "Esc" if en.hotkey == "Escape" else en.hotkey
	key.position = Vector2(5, 2)
	key.add_theme_font_size_override("font_size", 10)
	key.add_theme_color_override("font_color", Flags.GOLD)
	key.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	key.add_theme_constant_override("outline_size", 3)
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(key)
	if en.get("upgrade", false):
		# Military upgrade: a gold up-arrow in the corner.
		var arrow := Label.new()
		arrow.text = "▲"
		arrow.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		arrow.offset_left = -16
		arrow.offset_top = 1
		arrow.add_theme_font_size_override("font_size", 12)
		arrow.add_theme_color_override("font_color", Flags.GOLD)
		arrow.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		arrow.add_theme_constant_override("outline_size", 3)
		arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(arrow)
	return b


func _action_icon(action: Dictionary) -> String:
	match action.kind:
		"stop":
			return "stop"
		"attack_move":
			return "attack"
		"unload_here":
			return "unload"
		"research":
			return "attack" if Research.branch(action.branch).has("scope") else "research"
		"advance_age":
			return "crown"
		"build_menu":
			return "back" if action.get("page", "") == "" else "build"
	return "spell"


func _on_card_gui_input(event: InputEvent, alt_action: Dictionary) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		gv.do_action(alt_action)


## Compact cost line, e.g. "120 Ti  40 Th".
func _short_cost(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for k in DB.RESOURCE_TYPES:
		if cost.has(k):
			parts.append("%d %s" % [int(cost[k]), DB.resource_name(k).left(2)])
	return "  ".join(parts)


func _age_lock(required: int) -> String:
	if required > gv.world.players[gv.me].age:
		return "Requires " + DB.ages[required - 1].name
	return ""


func _entries_for_selection() -> Array:
	var sel: Array = gv.selected_entities().filter(func(e): return e.owner == gv.me)
	if sel.is_empty():
		return []
	var p = gv.world.players[gv.me]
	var faction: String = p.faction
	var entries: Array = []
	var first = sel[0]
	if first.kind == Entity.BUILDING:
		if first.constructing:
			return []
		for t in first.def.get("trains", []):
			var u: Dictionary = DB.units[t]
			# Shared buildings (docks) list both factions' ships; show only ours.
			if not u.get("faction", "any") in [faction, "any"]:
				continue
			var locked := _age_lock(int(u.get("age", 1)))
			if locked == "" and u.has("crown_land") and not u.crown_land in p.crown_lands:
				locked = "Requires the crown land of " + DB.crown_lands[u.crown_land].name
			if locked == "" and u.has("limit") and gv.world.type_count(gv.me, t) >= int(u.limit):
				locked = "Only %d at a time" % int(u.limit)
			if locked == "" and u.get("hero", false) and p.hero_type != "" and p.hero_type != t:
				continue
			if locked == "" and u.get("hero", false) and gv.world.hero_count(gv.me) > 0:
				locked = "Your hero is already in the field"
			var label: String = u.name
			if u.get("hero", false) and p.hero_fallen:
				label = "Revive " + u.name.get_slice(" ", u.name.get_slice_count(" ") - 1)
			entries.append({"label": label, "hotkey": u.hotkey, "cost": u.cost,
					"locked": locked, "icon": ["unit", t], "sub": _short_cost(u.cost),
					"tooltip": "%s\n%s\nCost: %s" % [u.name, u.get("description", ""), DB.format_cost(u.cost)],
					"action": {"kind": "train", "type": t}})
		for branch_id in first.def.get("research", []):
			entries.append(_research_entry(p, branch_id))
		if first.def.get("role", "") == "city" and first.crown_land == "" and DB.factions[faction].get("crown_lands", false):
			for land_id in DB.crown_lands:
				var land: Dictionary = DB.crown_lands[land_id]
				if land.get("capital", false) or land.get("faction", "") != faction:
					continue
				var units_list: Array = land.get("units", []).map(func(u): return DB.units[u].name)
				entries.append({"label": land.name.get_slice(" ", land.name.get_slice_count(" ") - 1), "hotkey": land.hotkey,
						"icon_tex": Flags.texture(land.get("flag", land_id)),
						"locked": "Already proclaimed elsewhere" if land_id in p.crown_lands else "",
						"tooltip": "Proclaim this city the %s.\n%s\nUnlocks: %s" % [land.name, land.description, ", ".join(units_list)],
						"action": {"kind": "crown_land", "land": land_id}})
		var lc: Dictionary = DB.factions[faction].get("loyalty", {})
		if first.def.get("role", "") == "city" and first.id != p.capital_id:
			var cfg: Dictionary = gv.world.rules.loyalty
			if lc.get("charters", false):
				var on: bool = not first.charter
				entries.append({"label": "Grant Charter" if on else "Revoke Charter", "hotkey": "J",
						"icon_tex": Flags.texture("empire"),
						"locked": _age_lock(int(cfg.charter_age)),
						"tooltip": "Federal Charter (Congress of Vienna): loyalty never drops below %d and the crown land's bonus grows by half, but the city passes on 20%% less income." % int(cfg.charter_floor),
						"action": {"kind": "charter", "on": on}})
			if lc.get("tithe", false):
				var left: float = maxf(0.0, (first.tithe_ready_tick - gv.world.tick_count) * gv.world.DT)
				entries.append({"label": "Blood Tithe", "hotkey": "J", "icon_tex": Flags.texture("blood"),
						"locked": "Ready in %ds" % ceili(left) if left > 0.0 else "",
						"tooltip": "Sacrifice the nearest soldier to restore %d Dread." % int(cfg.tithe_gain),
						"action": {"kind": "tithe"}})
		if first.def.get("advances_age", false) and p.age < gv.world.final_age():
			var next: Dictionary = DB.ages[p.age]
			entries.append({"label": "Advance", "hotkey": "U", "cost": next.cost,
					"locked": "Already advancing" if p.advancing_age else "",
					"tooltip": "Advance to %s\n%s\nCost: %s  (%ds)" % [next.name, next.description, DB.format_cost(next.cost), int(next.time)],
					"action": {"kind": "advance_age"}})
		return entries
	var has_worker := sel.any(func(e): return e.kind == Entity.UNIT and e.is_worker())
	entries.append({"label": "Stop", "hotkey": "S", "tooltip": "Stop all orders", "action": {"kind": "stop"}})
	entries.append({"label": "Attack", "hotkey": "A", "tooltip": "Attack-move: fight anything met on the way",
			"action": {"kind": "attack_move"}})
	if sel.any(func(e): return not e.cargo.is_empty() and e.domain() != "naval"):
		entries.append({"label": "Unload", "hotkey": "U", "tooltip": "Let the troops out here.", "action": {"kind": "unload_here"}})
	for id in _selected_abilities(sel):
		var a := Abilities.def(id)
		var auto: bool = sel.any(func(e): return e.autocast.get(id, false))
		entries.append({"label": "%s%s" % [a.name, " *" if auto else ""], "hotkey": a.hotkey, "cost": {"mana": a.mana},
				"tooltip": "%s  (%d Aether, %ds cooldown)\n%s\n\nRight-click to toggle autocast (*)." % [a.name, int(a.mana), int(a.cooldown), a.description],
				"action": {"kind": "cast", "ability": id}, "alt_action": {"kind": "autocast", "ability": id}})
	if has_worker and build_menu == "":
		entries.append({"label": "Build", "hotkey": "B", "tooltip": "Economic buildings: housing, farms, storage, library, docks, new cities",
				"icon": ["building", "dwelling"], "action": {"kind": "build_menu", "page": "economy"}})
		entries.append({"label": "Military", "hotkey": "V", "tooltip": "Barracks, ranges, workshops and towers",
				"icon": ["building", _military_icon(faction)], "action": {"kind": "build_menu", "page": "military"}})
		var wonders: Array = DB.factions[faction].buildable.filter(func(b): return DB.buildings[b].get("role", "") == "wonder")
		if not wonders.is_empty():
			entries.append({"label": "Wonders", "hotkey": "N", "tooltip": "Great works of the realm (Age 4+). Hold 3 for 5 minutes to win.",
					"icon": ["building", wonders[0]], "action": {"kind": "build_menu", "page": "wonder"}})
	elif has_worker:
		entries.clear()
		for b in DB.factions[faction].buildable:
			var d: Dictionary = DB.buildings[b]
			var page := "military" if d.get("role", "") in MILITARY_ROLES and not d.get("coastal", false) else "economy"
			if d.get("role", "") == "wonder":
				page = "wonder"
			if page != build_menu:
				continue
			var n := DB.display_name(d, faction)
			var tip := "%s\n%s\nCost: %s" % [n, d.get("description", ""), DB.format_cost(d.get("cost", {}))]
			var locked := _age_lock(int(d.get("age", 1)))
			if d.get("role", "") == "city":
				tip += "\nCities: %d / %d" % [gv.world.city_count(gv.me), gv.world.city_limit(gv.me)]
				if locked == "" and gv.world.city_count(gv.me) >= gv.world.city_limit(gv.me):
					locked = "City limit reached - advance the age"
			entries.append({"label": n, "hotkey": d.hotkey, "cost": d.get("cost", {}), "locked": locked,
					"sub": _short_cost(d.get("cost", {})), "icon": ["building", b], "tooltip": tip, "action": {"kind": "build", "type": b}})
		entries.append({"label": "Back", "hotkey": "Escape", "tooltip": "Back to orders",
				"action": {"kind": "build_menu", "page": ""}})
	return entries


func _military_icon(faction: String) -> String:
	for b in DB.factions[faction].buildable:
		if DB.buildings[b].get("role", "") == "military":
			return b
	return "dwelling"


func _selected_abilities(sel: Array) -> Array:
	var out: Array = []
	for e in sel:
		for id in e.def.get("abilities", []):
			if not id in out:
				out.append(id)
	return out


## Picture for a research line: its own icon, or for a military upgrade the unit it improves.
func _research_icon(branch_id: String) -> Dictionary:
	var b := Research.branch(branch_id)
	if b.has("scope"):
		var faction: String = gv.world.players[gv.me].faction
		for t in DB.buildings[b.scope].get("trains", []):
			if DB.units[t].get("faction", "any") in [faction, "any"] and DB.units[t].get("role", "") not in ["fisher", "transport", "support"]:
				return {"icon": ["unit", t], "upgrade": true}
	return {"icon_tex": HudIcons.get_icon(b.get("icon", "research"))}


func _research_entry(p, branch_id: String) -> Dictionary:
	var b := Research.branch(branch_id)
	var level := Research.next_level(p, branch_id)
	if level > Research.max_level(branch_id):
		return {"label": "%s (max)" % b.get("short", b.name), "hotkey": b.hotkey, "locked": "Fully researched",
				"tooltip": b.name, "action": {"kind": "research", "branch": branch_id}}.merged(_research_icon(branch_id))
	var info := Research.level_info(branch_id, level)
	var locked := _age_lock(info.age)
	if p.researching.has(branch_id):
		locked = "In progress"
	return {"label": "%s %s" % [b.get("short", b.name), Research.roman(level)], "hotkey": b.hotkey, "cost": info.cost,
			"locked": locked,
			"tooltip": "%s %s: %s\n%s\n\nPer level:\n%s\n\nCost: %s  (%ds)" % [b.name, Research.roman(level), info.name,
					b.description, Research.describe_effects(branch_id), DB.format_cost(info.cost), int(info.time)],
			"action": {"kind": "research", "branch": branch_id}}.merged(_research_icon(branch_id))


func close_build_menu() -> bool:
	if build_menu == "":
		return false
	build_menu = ""
	return true


## Runs the command-grid entry bound to `keycode`, if any.
func try_hotkey(keycode: Key) -> bool:
	for en in _card_entries:
		if OS.find_keycode_from_string(en.hotkey) == keycode:
			gv.do_action(en.action)
			return true
	return false
