extends RefCounted
## Graphics quality (Settings page), saved in user://settings.cfg next to audio.
## "auto" picks Medium on integrated GPUs and High otherwise.

const SETTINGS := "user://settings.cfg"
const LEVELS := ["auto", "high", "medium", "low"]

static var quality := "auto"
static var _loaded := false


static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		quality = cfg.get_value("graphics", "quality", quality)


static func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("graphics", "quality", quality)
	cfg.save(SETTINGS)


## The level actually used ("auto" resolved by the GPU in use).
static func effective() -> String:
	load_settings()
	if quality != "auto":
		return quality
	var gpu := RenderingServer.get_video_adapter_name().to_lower()
	for weak in ["intel", "llvmpipe", "swiftshader", "radeon(tm) graphics", "vega", "apple m1"]:
		if gpu.contains(weak):
			return "medium"
	return "high"


## Applies the level to the scene's environment, sun and viewport.
static func apply(env: Environment, sun: DirectionalLight3D, viewport: Viewport) -> void:
	var level := effective()
	env.ssao_enabled = level == "high"
	env.glow_enabled = level != "low"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if level == "low" \
			else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 70.0 if level == "high" else 50.0
	viewport.scaling_3d_scale = 0.75 if level == "low" else 1.0
