extends Control
## Screen-space overlay above the 3D scene: health and progress bars, carried
## resources, and the drag-select box.

const DB = preload("res://sim/db.gd")
const Entity = preload("res://sim/entity.gd")

var gv


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _bar(center: Vector2, width: float, frac: float, color: Color) -> void:
	var r := Rect2(center - Vector2(width * 0.5, 0), Vector2(width, 5))
	draw_rect(r.grow(1), Color(0, 0, 0, 0.75))
	draw_rect(Rect2(r.position, Vector2(width * clampf(frac, 0.0, 1.0), 5)), color)


func _hp_color(frac: float) -> Color:
	if frac > 0.6:
		return Color(0.25, 0.9, 0.25)
	return Color(0.95, 0.8, 0.15) if frac > 0.3 else Color(0.95, 0.2, 0.15)


func _draw() -> void:
	var cam: Camera3D = gv.camera
	var zoom := clampf(20.0 / float(gv.camera.distance), 0.5, 1.6)
	for e in gv.world.entities.values():
		if not e.alive or e.kind == Entity.RESOURCE or not gv.is_shown(e):
			continue
		var selected: bool = gv.is_selected(e.id)
		var building: bool = e.kind == Entity.BUILDING
		var busy: bool = building and e.owner == gv.me and (e.constructing or not e.queue.is_empty() \
				or (gv.world.is_city(e) and e.loyalty < 100.0))
		if not selected and e.hp >= e.max_hp and not busy:
			continue
		var p3: Vector3 = gv.entity_point(e) + Vector3(0, gv.entity_views.bar_height(e.id), 0)
		if cam.is_position_behind(p3):
			continue
		var s := cam.unproject_position(p3)
		var w: float = (28.0 if not building else 18.0 * e.size.x) * zoom
		_bar(s, w, e.hp / e.max_hp, _hp_color(e.hp / e.max_hp))
		if building and e.constructing:
			_bar(s + Vector2(0, 8), w, e.build_progress, Color(0.95, 0.75, 0.3))
		elif building and not e.queue.is_empty() and e.owner == gv.me:
			# Training / research progress, with how many more are waiting.
			_bar(s + Vector2(0, 8), w, e.queue[0].progress, Color(0.45, 0.75, 1.0))
			if e.queue.size() > 1:
				draw_string(get_theme_default_font(), s + Vector2(w * 0.5 + 4, 15), "+%d" % (e.queue.size() - 1),
						HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.88, 1.0))
		if building and gv.world.is_city(e) and e.owner == gv.me and e.loyalty < 100.0:
			var lcol := Color(0.55, 0.7, 1.0) if e.loyalty > float(gv.world.rules.loyalty.warning) else Color(1.0, 0.45, 0.2)
			_bar(s + Vector2(0, -8), w, e.loyalty / 100.0, lcol)
		if e.kind == Entity.UNIT and e.carry_amount > 0.0 and e.owner == gv.me:
			draw_rect(Rect2(s + Vector2(w * 0.5 + 3, -1), Vector2(7, 7)), DB.color_of(gv.world.rules.resource_colors[e.carry_type]))
	var box: Rect2 = gv.drag_rect_screen
	if box.has_area():
		draw_rect(box, Color(0.35, 1.0, 0.35, 0.12))
		draw_rect(box, Color(0.35, 1.0, 0.35, 0.9), false, 1.5)
