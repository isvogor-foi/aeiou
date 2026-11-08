extends Camera3D
## Tilted RTS camera orbiting a focus point on the ground: pan, zoom, rotate.

const PITCH_DEG := 44.0
const MIN_DISTANCE := 7.0
const MAX_DISTANCE := 42.0
const PAN_SPEED := 1.1  # screen-heights per second at any zoom
const ROTATE_SPEED := 1.8

var terrain
## Focus point on the ground (tile units).
var focus := Vector3.ZERO
var yaw := 0.0
## The heading the camera is turning toward: always a multiple of 90 degrees.
var target_yaw := 0.0
var distance := 20.0
var map_size := Vector2(96, 96)


func setup(t, size: Vector2) -> void:
	terrain = t
	map_size = size
	fov = 45.0
	near = 0.3
	far = 300.0


func update_transform() -> void:
	focus.x = clampf(focus.x, 0.0, map_size.x)
	focus.z = clampf(focus.z, 0.0, map_size.y)
	focus.y = terrain.height_at(focus.x, focus.z) if terrain else 0.0
	distance = clampf(distance, MIN_DISTANCE, MAX_DISTANCE)
	var pitch := deg_to_rad(PITCH_DEG)
	var back := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	global_position = focus + back * distance
	look_at(focus, Vector3.UP)


## Moves the focus by `dir` in screen terms (x right, y down), scaled by zoom.
func pan(dir: Vector2, delta: float) -> void:
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var step := PAN_SPEED * distance * delta
	focus += (right * dir.x - forward * dir.y) * step


## Turns the view a quarter turn left (+1) or right (-1), animated by turn().
func rotate_step(dir: int) -> void:
	target_yaw = wrapf(snap(target_yaw) + dir * PI / 2.0, -PI, PI)


## Jumps straight to the nearest quarter-turn heading of `y`.
func set_heading(y: float) -> void:
	target_yaw = snap(y)
	yaw = target_yaw


static func snap(y: float) -> float:
	return wrapf(roundf(y / (PI / 2.0)) * PI / 2.0, -PI, PI)


## Eases the heading toward target_yaw; call once per frame before update_transform().
func turn(delta: float) -> void:
	var diff := angle_difference(yaw, target_yaw)
	if absf(diff) < 0.002:
		yaw = target_yaw
	else:
		yaw = wrapf(yaw + diff * minf(1.0, delta * 9.0), -PI, PI)


func zoom_by(factor: float) -> void:
	distance *= factor


## Point on the terrain under a screen position (tile units).
func ground_at(screen: Vector2) -> Vector3:
	var o := project_ray_origin(screen)
	var d := project_ray_normal(screen)
	if absf(d.y) < 0.001:
		return focus
	var t := (focus.y - o.y) / d.y
	# Refine against the heightfield a few times.
	for i in 4:
		var p := o + d * t
		var h: float = terrain.height_at(p.x, p.z) if terrain else 0.0
		t = (h - o.y) / d.y
	return o + d * t
