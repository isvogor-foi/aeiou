extends Control
## Minimap: terrain, units as dots, fog, and the camera frame.
## Left-click/drag moves the camera; right-click issues a move/smart command.

const DB = preload("res://sim/db.gd")
const Entity = preload("res://sim/entity.gd")
const GameMap = preload("res://sim/game_map.gd")

const TERRAIN_COLORS := {
	GameMap.GRASS: Color(0.33, 0.52, 0.22),
	GameMap.WATER: Color(0.15, 0.32, 0.55),
	GameMap.FOREST: Color(0.12, 0.3, 0.12),
	GameMap.ROCK: Color(0.46, 0.45, 0.42),
	GameMap.DIRT: Color(0.5, 0.41, 0.27),
}

const REDRAW_INTERVAL := 0.2

var gv
var _terrain_img: Image
var _terrain_tex: ImageTexture
var _redraw_timer := 0.0
var _dragging := false


func _ready() -> void:
	var m = gv.world.map
	_terrain_img = Image.create(m.width, m.height, false, Image.FORMAT_RGBA8)
	for y in m.height:
		for x in m.width:
			_paint(Vector2i(x, y))
	_terrain_tex = ImageTexture.create_from_image(_terrain_img)
	mouse_filter = Control.MOUSE_FILTER_STOP


func paint_tiles(tiles: Array[Vector2i]) -> void:
	for t in tiles:
		_paint(t)
	_terrain_tex.update(_terrain_img)


func _paint(t: Vector2i) -> void:
	_terrain_img.set_pixelv(t, TERRAIN_COLORS[gv.world.map.get_terrain(t)])


func tick(delta: float) -> void:
	_redraw_timer -= delta
	if _redraw_timer <= 0.0:
		_redraw_timer = REDRAW_INTERVAL
		queue_redraw()


func _scale() -> Vector2:
	return size / Vector2(gv.world.map.width, gv.world.map.height)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_texture_rect(_terrain_tex, rect, false)
	draw_texture_rect(gv.territory_tint_tex, rect, false)
	var s := _scale()
	for e in gv.world.entities.values():
		if not e.alive or not gv.is_shown(e):
			continue
		var col: Color
		if e.kind == Entity.RESOURCE:
			col = DB.color_of(gv.world.rules.resource_colors[e.def.resource])
		else:
			col = gv.world.players[e.owner].color
			if gv.is_selected(e.id):
				col = Color.WHITE
		if e.kind == Entity.UNIT:
			var t := GameMap.to_tile(e.pos)
			draw_rect(Rect2(Vector2(t) * s - Vector2.ONE, Vector2(3, 3)), col)
		else:
			draw_rect(Rect2(Vector2(e.tile) * s, Vector2(e.size) * s), col)
	if not gv.reveal_all:
		draw_texture_rect(gv.fog_tex, rect, false)
	# AEIOU relics we know of: gold diamonds over the fog, outlined so they stand out.
	for r in gv.relics():
		var st: Dictionary = gv.relic_status(r)
		if st.pos == null:
			continue
		var c: Vector2 = st.pos / GameMap.TILE * s
		var d := 5.0
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -d - 1.5), c + Vector2(d + 1.5, 0), c + Vector2(0, d + 1.5), c + Vector2(-d - 1.5, 0)]), Color(0.05, 0.04, 0.02))
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0)]), st.color if st.state != "loose" else Color(1.0, 0.82, 0.3))
	var frame := PackedVector2Array()
	for p in gv.view_polygon_px():
		frame.append((p / GameMap.TILE * s).clamp(Vector2.ZERO, size))
	frame.append(frame[0])
	draw_polyline(frame, Color.WHITE, 1.0)
	draw_rect(rect, Color(0.55, 0.45, 0.25), false, 2.0)


func _to_world(local: Vector2) -> Vector2:
	return local / _scale() * GameMap.TILE


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = true
			gv.center_on(_to_world(event.position))
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			gv.command_move(_to_world(event.position))
		accept_event()
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		gv.center_on(_to_world(event.position))
		accept_event()
