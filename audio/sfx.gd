extends RefCounted
## Sound effects synthesised at startup (no sample files): short PCM clips built
## from noise, sine sweeps and inharmonic partials.

const RATE := 22050

static var _cache := {}


static func get_stream(name: String) -> AudioStreamWAV:
	if not _cache.has(name):
		_cache[name] = _make(name)
	return _cache[name]


static func _make(name: String) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	var s := PackedFloat32Array()
	match name:
		"musket":
			s = _noise(rng, 0.28, 0.004, 9.0, 0.35)
			_mix(s, _tone(0.28, 110.0, 0.0, 12.0), 0.6)
		"cannon":
			s = _noise(rng, 0.7, 0.01, 4.0, 0.15)
			_mix(s, _tone(0.7, 55.0, -20.0, 5.0), 1.0)
		"arcane":
			s = _sweep(0.28, 420.0, 1300.0, 7.0)
			_mix(s, _sweep(0.28, 630.0, 1950.0, 7.0), 0.4)
		"curse":
			s = _tone(0.4, 170.0, 0.0, 5.0)
			_mix(s, _tone(0.4, 181.0, 0.0, 5.0), 0.8)
			_mix(s, _noise(rng, 0.4, 0.05, 6.0, 0.1), 0.5)
		"fire":
			s = _noise(rng, 0.45, 0.02, 5.0, 0.25)
			_mix(s, _crackle(rng, 0.45), 0.6)
		"clang":
			s = _tone(0.32, 523.0, 0.0, 11.0)
			_mix(s, _tone(0.32, 1337.0, 0.0, 14.0), 0.6)
			_mix(s, _tone(0.32, 2411.0, 0.0, 18.0), 0.35)
			_mix(s, _noise(rng, 0.05, 0.0, 60.0, 1.0), 0.4)
		"thud":
			s = _tone(0.35, 90.0, -40.0, 9.0)
			_mix(s, _noise(rng, 0.2, 0.0, 20.0, 0.1), 0.4)
		"build":
			s = _knock(rng, 0.0, 0.5)
			_mix(s, _knock(rng, 0.14, 0.5), 1.0)
		"steam":
			s = _noise(rng, 0.6, 0.05, 3.0, 0.9)
		"click":
			s = _tone(0.05, 1250.0, 0.0, 60.0)
		"magic":
			s = _tone(0.6, 784.0, 0.0, 4.0)
			_mix(s, _tone(0.6, 988.0, 0.0, 4.0), 0.7)
			_mix(s, _tone(0.6, 1175.0, 0.0, 4.0), 0.5)
		"fanfare":
			s = PackedFloat32Array()
			s.resize(int(RATE * 1.3))
			var notes := [523.25, 659.25, 783.99, 1046.5]
			for i in notes.size():
				_mix_at(s, _brass(0.5 if i < 3 else 0.7, notes[i]), int(RATE * 0.16 * i), 0.7)
		"drum":
			s = PackedFloat32Array()
			s.resize(int(RATE * 0.9))
			for i in 3:
				var hit := _tone(0.25, 70.0, -30.0, 10.0)
				_mix(hit, _noise(rng, 0.25, 0.0, 14.0, 0.2), 0.5)
				_mix_at(s, hit, int(RATE * 0.28 * i), 0.9)
		"whoosh":
			s = _noise(rng, 0.35, 0.15, 4.0, 0.6)
		# --- The modern ages (7-12) ---
		"smg", "mg":
			# A burst of sharp cracks: four for a submachine gun, seven for a machine gun.
			var shots := 4 if name == "smg" else 7
			var gap := 0.075 if name == "smg" else 0.065
			s = PackedFloat32Array()
			for i in shots:
				var crack := _noise(rng, 0.09, 0.0, 38.0, 0.45)
				_mix(crack, _tone(0.09, 140.0 if name == "smg" else 100.0, -40.0, 30.0), 0.7)
				_mix_at(s, crack, int(RATE * gap * i), 0.9 - i * 0.04)
		"tank_gun":
			# A heavy gun: a sharp crack over a deep boom and a ringing tail.
			s = _noise(rng, 0.9, 0.0, 6.0, 0.6)
			_mix(s, _tone(0.9, 48.0, -15.0, 4.0), 1.2)
			_mix(s, _tone(0.9, 210.0, 0.0, 9.0), 0.25)
		"rocket":
			# A rising hiss as it leaves the rail, then the bang.
			s = _noise(rng, 0.45, 0.05, 2.0, 0.85)
			_mix(s, _sweep(0.45, 300.0, 900.0, 3.0), 0.25)
			_mix_at(s, _explosion(rng, 0.8), int(RATE * 0.4), 0.9)
		"explosion":
			s = _explosion(rng, 1.0)
		"bomb":
			# The Aether bomb: a long rolling rumble under a crackling Aether whine.
			s = _noise(rng, 3.5, 0.02, 0.9, 0.12)
			_mix(s, _tone(3.5, 32.0, -10.0, 0.8), 1.4)
			_mix(s, _sweep(2.0, 1800.0, 300.0, 1.5), 0.2)
			_mix(s, _crackle(rng, 3.5), 0.5)
		"siren":
			# An air-raid siren: rising and falling twice.
			var n := int(RATE * 3.0)
			s = PackedFloat32Array()
			s.resize(n)
			var phase := 0.0
			for i in n:
				var t := float(i) / RATE
				var f := 380.0 + 260.0 * (0.5 - 0.5 * cos(t * TAU / 1.5))
				phase += TAU * f / RATE
				var env := minf(1.0, t * 3.0) * minf(1.0, (3.0 - t) * 3.0)
				s[i] = (sin(phase) + 0.3 * sin(phase * 2.0)) * 0.6 * env
		"radio":
			# Radio static with two morse pips.
			s = _noise(rng, 0.6, 0.02, 2.5, 0.9)
			_mix(s, _crackle(rng, 0.6), 0.8)
			for k in 2:
				_mix_at(s, _tone(0.07, 1000.0, 0.0, 2.0), int(RATE * (0.12 + k * 0.16)), 0.5)
		"engine":
			# A motor starting up and settling into a chug.
			var n := int(RATE * 1.0)
			s = PackedFloat32Array()
			s.resize(n)
			var phase := 0.0
			for i in n:
				var t := float(i) / RATE
				var f := 28.0 + 18.0 * minf(1.0, t * 3.0)
				phase += TAU * f / RATE
				var chug := 0.5 + 0.5 * sin(phase * 0.25)
				s[i] = (sin(phase) * 0.6 + rng.randf_range(-0.3, 0.3) * chug) * minf(1.0, t * 8.0) * exp(-1.2 * t)
		_:
			s = _tone(0.1, 440.0, 0.0, 20.0)
	return _to_wav(s)


# --- Building blocks (all return mono float samples in -1..1) ----------------------

## A decaying sine (optionally sliding in pitch by `slide` Hz over its length).
static func _tone(seconds: float, freq: float, slide: float, decay: float) -> PackedFloat32Array:
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += TAU * (freq + slide * t / seconds) / RATE
		out[i] = sin(phase) * exp(-decay * t)
	return out


static func _sweep(seconds: float, from: float, to: float, decay: float) -> PackedFloat32Array:
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := lerpf(from, to, t / seconds)
		phase += TAU * (f + sin(t * 40.0) * 15.0) / RATE
		out[i] = sin(phase) * exp(-decay * t) * minf(1.0, t * 60.0)
	return out


## Noise with an attack, an exponential decay, and a one-pole filter (`bright` 0..1).
static func _noise(rng: RandomNumberGenerator, seconds: float, attack: float, decay: float, bright: float) -> PackedFloat32Array:
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		var t := float(i) / RATE
		y = lerpf(y, rng.randf_range(-1.0, 1.0), clampf(bright, 0.02, 1.0))
		var env := (minf(1.0, t / attack) if attack > 0.0 else 1.0) * exp(-decay * t)
		out[i] = y * env * (1.0 / sqrt(maxf(bright, 0.05)))
	return out


## A shell or grenade bursting: a noise blast over a falling low tone, with debris.
static func _explosion(rng: RandomNumberGenerator, seconds: float) -> PackedFloat32Array:
	var out := _noise(rng, seconds, 0.003, 4.5, 0.3)
	_mix(out, _tone(seconds, 70.0, -40.0, 5.0), 1.1)
	_mix(out, _crackle(rng, seconds), 0.4)
	return out


static func _crackle(rng: RandomNumberGenerator, seconds: float) -> PackedFloat32Array:
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		if rng.randf() < 0.004:
			for k in mini(40, n - i):
				out[i + k] += rng.randf_range(-1.0, 1.0) * exp(-k * 0.15)
	return out


static func _knock(rng: RandomNumberGenerator, at: float, gain: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(RATE * (at + 0.12)))
	var hit := _tone(0.12, 220.0, -80.0, 35.0)
	_mix(hit, _noise(rng, 0.12, 0.0, 45.0, 0.5), 0.5)
	_mix_at(out, hit, int(RATE * at), gain)
	return out


## A brass-like note: odd harmonics with a soft attack.
static func _brass(seconds: float, freq: float) -> PackedFloat32Array:
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, t * 25.0) * exp(-2.0 * t)
		var v := sin(TAU * freq * t) + 0.45 * sin(TAU * freq * 3.0 * t) + 0.2 * sin(TAU * freq * 5.0 * t)
		out[i] = v * 0.55 * env
	return out


static func _mix(into: PackedFloat32Array, other: PackedFloat32Array, gain: float) -> void:
	_mix_at(into, other, 0, gain)


static func _mix_at(into: PackedFloat32Array, other: PackedFloat32Array, offset: int, gain: float) -> void:
	if into.size() < offset + other.size():
		into.resize(offset + other.size())
	for i in other.size():
		into[offset + i] += other[i] * gain


static func _to_wav(s: PackedFloat32Array) -> AudioStreamWAV:
	var peak := 0.001
	for v in s:
		peak = maxf(peak, absf(v))
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i] / peak * 0.8, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
