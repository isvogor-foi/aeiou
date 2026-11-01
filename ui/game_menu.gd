extends CanvasLayer
## In-game menu (F10 or Esc): resume, save to a slot, load, main menu, quit.
## Pauses the match while open.

const SaveGame = preload("res://sim/save_game.gd")
const GameConfig = preload("res://sim/game_config.gd")
const Flags = preload("res://view3d/flags.gd")
const MenuTheme = preload("res://ui/menu_theme.gd")

const SLOTS := ["1", "2", "3", "4", "5"]

var gv
var _panel: PanelContainer
var _box: VBoxContainer
var _was_paused := false


func _ready() -> void:
	layer = 10
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.theme = MenuTheme.get_theme()
	_panel.custom_minimum_size.x = 460
	center.add_child(_panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	_panel.add_child(_box)
	visible = false


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	_was_paused = gv.paused
	gv.paused = true
	visible = true
	_show_main()


func close() -> void:
	visible = false
	gv.paused = _was_paused


func _clear(title: String) -> void:
	for c in _box.get_children():
		c.queue_free()
	var l := Label.new()
	l.text = title
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", Flags.GOLD)
	_box.add_child(l)


func _button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 42
	b.pressed.connect(on_press)
	_box.add_child(b)
	return b


func _show_main() -> void:
	_clear("Paused")
	MenuTheme.make_primary(_button("Resume", close))
	_button("Save Game", _show_save)
	_button("Load Game", _show_load)
	_button("Main Menu", func(): gv.get_tree().change_scene_to_file("res://ui/main_menu.tscn"))
	_button("Quit to Desktop", func(): gv.get_tree().quit())


func _show_save() -> void:
	_clear("Save Game")
	for slot in SLOTS:
		var meta := SaveGame.read_meta(SaveGame.slot_path(slot))
		var label := "Slot %s:  %s" % [slot, _describe(meta) if not meta.is_empty() else "(empty)"]
		_button(label, func():
			var err: String = gv.save_game(slot)
			gv.hud.flash(err if err != "" else "Saved to slot " + slot, 3.0)
			close())
	_button("Back", _show_main)


func _show_load() -> void:
	_clear("Load Game")
	var saves := SaveGame.list_saves()
	if saves.is_empty():
		var l := Label.new()
		l.text = "No saved games yet."
		_box.add_child(l)
	for meta in saves:
		var path: String = meta.path
		_button("%s:  %s" % [meta.slot.capitalize(), _describe(meta)], func(): gv.load_game(path))
	_button("Back", _show_main)


static func _describe(meta: Dictionary) -> String:
	return "%s, %s, %d min  (%s)" % [meta.get("faction", "?"), meta.get("age", "?"), int(meta.get("minutes", 0)), str(meta.get("time", "")).replace("T", " ").left(16)]
