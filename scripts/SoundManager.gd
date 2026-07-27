extends Node
## SoundManager – Autoload
## Programmatisk lydgenerator og cache for hele spillet.

var _cache: Dictionary = {}

# ── API ──────────────────────────────────────────────────────
func play(sound_id: String, vol_db: float = 0.0) -> void:
	var stream := _fetch(sound_id)
	if stream == null: return
	var p := AudioStreamPlayer.new()
	p.stream    = stream
	p.volume_db = vol_db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

# ── Cache + generering ────────────────────────────────────────
func _fetch(id: String) -> AudioStreamWAV:
	if id in _cache:
		return _cache[id]
	var s := _gen(id)
	_cache[id] = s
	return s

func _gen(id: String) -> AudioStreamWAV:
	match id:
		"item_click":   return _tone(320, 380, 0.07, 0.30)
		"item_take":    return _tone(280, 560, 0.20, 0.50)
		"item_throw":   return _tone(220,  70, 0.22, 0.40)
		"wash":         return _tone(380, 180, 0.30, 0.38, 1)   # firkant – svøp
		"repair":       return _tone(160,  90, 0.22, 0.50, 1)   # tung dunk
		"shelf":        return _tone(480, 520, 0.10, 0.40)       # lett klikk
		"kaching":      return _tone(523, 1046, 0.38, 0.65)      # kassalyd
		"door_open":    return _tone(200, 260, 0.18, 0.35)
		"combine":      return _tone(440, 880, 0.28, 0.55)       # sett-kombiner
		_:              return _tone(440, 440, 0.10, 0.30)

# ── Lydgenerator ──────────────────────────────────────────────
func _tone(freq_start: float, freq_end: float, dur: float,
		vol: float = 0.6, wave: int = 0) -> AudioStreamWAV:
	var sr  : int = 22050
	var n   : int = int(sr * dur)
	var data: PackedByteArray = PackedByteArray()
	data.resize(n)
	var phase: float = 0.0
	for i in n:
		var t    : float = float(i) / float(n)
		var freq : float = lerpf(freq_start, freq_end, t)
		phase += TAU * freq / float(sr)
		var attack: float = minf(t / maxf(0.01 / dur, 0.001), 1.0)
		var decay : float = 1.0 - t
		var env   : float = attack * decay * vol
		var raw   : float = (1.0 if fmod(phase, TAU) < PI else -1.0) if wave == 1 else sin(phase)
		data[i] = int(clamp(raw * env * 127.0 + 128.0, 0.0, 255.0))
	var stream := AudioStreamWAV.new()
	stream.format   = 0
	stream.mix_rate = sr
	stream.stereo   = false
	stream.data     = data
	return stream
