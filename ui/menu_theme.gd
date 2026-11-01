extends RefCounted
## The black-and-gold theme shared by the title screen and the in-game menu.

const Flags = preload("res://view3d/flags.gd")

const GOLD := Flags.GOLD
const TEXT := Color(0.90, 0.87, 0.80)
const MUTED := Color(0.62, 0.60, 0.56)
const LINE := Color(0.34, 0.29, 0.20)
const CARD := Color(0.10, 0.092, 0.08, 0.96)

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _make()
	return _theme


static func box(bg: Color, border: Color, width := 1, radius := 5, margin := Vector2(16, 9)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = margin.x
	sb.content_margin_right = margin.x
	sb.content_margin_top = margin.y
	sb.content_margin_bottom = margin.y
	return sb


static func _make() -> Theme:
	var t := Theme.new()
	t.default_font_size = 17
	var normal := box(Color(0.12, 0.11, 0.095, 0.96), LINE)
	var hover := box(Color(0.19, 0.16, 0.11, 0.98), GOLD)
	var pressed := box(Color(0.25, 0.20, 0.11), GOLD, 2)
	var disabled := box(Color(0.09, 0.085, 0.08, 0.7), Color(0.17, 0.16, 0.14))
	var focus := box(Color(0, 0, 0, 0), Color(GOLD, 0.6))
	focus.draw_center = false
	for type in ["Button", "OptionButton"]:
		t.set_stylebox("normal", type, normal)
		t.set_stylebox("hover", type, hover)
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("hover_pressed", type, pressed)
		t.set_stylebox("disabled", type, disabled)
		t.set_stylebox("focus", type, focus)
		t.set_color("font_color", type, TEXT)
		t.set_color("font_hover_color", type, GOLD)
		t.set_color("font_pressed_color", type, GOLD)
		t.set_color("font_hover_pressed_color", type, GOLD)
		t.set_color("font_focus_color", type, TEXT)
		t.set_color("font_disabled_color", type, Color(0.40, 0.38, 0.35))
	# Checkboxes are not buttons visually: no frame, just the tick and the text.
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 2
	empty.content_margin_top = 3
	empty.content_margin_bottom = 3
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		t.set_stylebox(state, "CheckBox", empty)
	t.set_constant("h_separation", "CheckBox", 10)
	t.set_icon("unchecked", "CheckBox", _check_icon(false))
	t.set_icon("checked", "CheckBox", _check_icon(true))
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_hover_color", "CheckBox", GOLD)
	t.set_color("font_pressed_color", "CheckBox", TEXT)
	t.set_color("font_hover_pressed_color", "CheckBox", GOLD)
	t.set_stylebox("panel", "PanelContainer", box(Color(0.065, 0.06, 0.055, 0.93), Color(0.45, 0.37, 0.20), 1, 8, Vector2(28, 24)))
	t.set_stylebox("panel", "PopupMenu", box(Color(0.10, 0.09, 0.08), GOLD, 1, 4, Vector2(6, 6)))
	t.set_stylebox("hover", "PopupMenu", box(Color(0.25, 0.20, 0.11), Color(0, 0, 0, 0), 0, 3, Vector2(6, 4)))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", GOLD)
	t.set_stylebox("normal", "LineEdit", box(Color(0.12, 0.11, 0.095), LINE, 1, 5, Vector2(10, 7)))
	t.set_stylebox("focus", "LineEdit", focus)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_stylebox("slider", "HSlider", box(Color(0.18, 0.16, 0.13), LINE, 1, 3, Vector2(0, 3)))
	var fill := box(Color(GOLD, 0.75), Color(0, 0, 0, 0), 0, 3, Vector2(0, 3))
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_stylebox("separator", "HSeparator", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0))
	return t


## The single most important button on a page: gold, with dark text.
static func make_primary(b: Button) -> void:
	b.add_theme_stylebox_override("normal", box(Color(0.80, 0.63, 0.16), GOLD))
	b.add_theme_stylebox_override("hover", box(Color(0.93, 0.75, 0.24), Color(1, 0.92, 0.6)))
	b.add_theme_stylebox_override("pressed", box(Color(0.66, 0.50, 0.12), GOLD))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, Color(0.08, 0.06, 0.03))


## Small gold capitals over a group of settings.
static func section(text: String) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", GOLD)
	l.add_theme_constant_override("line_spacing", 0)
	return l


static func muted(text: String, size := 15) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", MUTED)
	return l


## An 18px checkbox: a gold-rimmed square, filled gold with a dark tick when on.
static func _check_icon(on: bool) -> ImageTexture:
	var n := 18
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in n:
		for x in n:
			var edge := x <= 1 or y <= 1 or x >= n - 2 or y >= n - 2
			if on:
				img.set_pixel(x, y, GOLD)
			elif edge:
				img.set_pixel(x, y, Color(GOLD, 0.8))
			else:
				img.set_pixel(x, y, Color(0.12, 0.11, 0.095))
	if on:
		var dark := Color(0.08, 0.06, 0.03)
		for i in 4:
			for w in 2:
				img.set_pixel(4 + i, 8 + i + w, dark)
		for i in 7:
			for w in 2:
				img.set_pixel(7 + i, 11 - i + w, dark)
	return ImageTexture.create_from_image(img)
