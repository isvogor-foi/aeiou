extends RefCounted
## Tiny opt-in profiler for benchmarks: Prof.start() / Prof.stop(key, t0).

static var enabled := false
static var data := {}


static func start() -> int:
	return Time.get_ticks_usec() if enabled else 0


static func stop(key: String, t0: int) -> void:
	if enabled:
		data[key] = data.get(key, 0) + Time.get_ticks_usec() - t0
		data["#" + key] = data.get("#" + key, 0) + 1
