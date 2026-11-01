extends Node
## Plays sound effects (a small voice pool, quieter the farther from the camera)
## and music (crossfading tracks), with volumes saved in user://settings.cfg.

const Sfx = preload("res://audio/sfx.gd")

const SETTINGS := "user://settings.cfg"
const VOICES := 14
const TRACKS := {
	"menu": "res://assets/music/kaiserhymne.ogg",
	"peace": "res://assets/music/blue_danube.mp3",
	"battle": "res://assets/music/radetzky_march.mp3",
}
const CROSSFADE := 2.5

static var master_volume := 0.8
static var music_volume := 0.55
static var sfx_volume := 0.8
static var _settings_loaded := false

## Where the listener is (world tiles, set by the game view) and how far it hears.
var listener := Vector3.ZERO
var hearing := 30.0
var _voices: Array = []
var _next_voice := 0
var _recent := {}
var _music: Array = []
var _active := 0
var _track := ""


func _ready() -> void:
	load_settings()
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.volume_db = -80.0
		add_child(m)
		_music.append(m)


static func load_settings() -> void:
	if _settings_loaded:
		return
	_settings_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		master_volume = cfg.get_value("audio", "master", master_volume)
		music_volume = cfg.get_value("audio", "music", music_volume)
		sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)


static func get_volume(key: String) -> float:
	match key:
		"music":
			return music_volume
		"sfx":
			return sfx_volume
	return master_volume


static func set_volume(key: String, v: float) -> void:
	match key:
		"music":
			music_volume = v
		"sfx":
			sfx_volume = v
		_:
			master_volume = v


static func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.save(SETTINGS)


## Plays effect `name`, at `pos` (world tiles) or everywhere when pos is null.
func play(name: String, pos = null, gain := 1.0) -> void:
	var now := Time.get_ticks_msec()
	# The same sound at most a few times per moment, so big battles don't roar.
	var stamps: Array = _recent.get(name, []).filter(func(t): return now - t < 120)
	if stamps.size() >= 3:
		return
	stamps.append(now)
	_recent[name] = stamps
	var g := gain
	if pos != null:
		var d: float = Vector2(pos.x, pos.z).distance_to(Vector2(listener.x, listener.z))
		if d > hearing:
			return
		g *= 1.0 - d / hearing
	var v: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	v.stream = Sfx.get_stream(name)
	v.volume_db = linear_to_db(maxf(0.0001, g * sfx_volume * master_volume))
	v.pitch_scale = randf_range(0.94, 1.06)
	v.play()


## Switches music to `track` ("menu", "peace", "battle"), crossfading.
func music(track: String) -> void:
	if track == _track or not TRACKS.has(track):
		return
	_track = track
	var old: AudioStreamPlayer = _music[_active]
	_active = 1 - _active
	var new: AudioStreamPlayer = _music[_active]
	var stream = load(TRACKS[track])
	if stream == null:
		return
	if "loop" in stream:
		stream.loop = true
	new.stream = stream
	new.volume_db = -60.0
	new.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(new, "volume_db", _music_db(), CROSSFADE)
	tw.tween_property(old, "volume_db", -60.0, CROSSFADE)
	tw.chain().tween_callback(old.stop)


func _music_db() -> float:
	return linear_to_db(maxf(0.0001, music_volume * master_volume))


## Re-applies volumes after the settings change.
func refresh_volumes() -> void:
	if _track != "":
		_music[_active].volume_db = _music_db()
