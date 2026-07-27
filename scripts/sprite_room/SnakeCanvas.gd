extends Control
## Snake-klon som kjører inne i C64-terminalen
## Piltaster eller WASD styrer slangen
## ESC – tilbake til terminal

signal game_closed

# ── Grid ──────────────────────────────────────────────────────
const BW      := 780.0
const BH      := 480.0
const HUD_H   := 40.0
const CELL    := 20.0
const COLS    := 39       # BW / CELL
const ROWS    := 22       # (BH - HUD_H) / CELL

# ── Farger ───────────────────────────────────────────────────
const COL_BG    := Color(0.03, 0.06, 0.03)
const COL_HEAD  := Color(0.3,  1.0,  0.3)
const COL_BODY  := Color(0.18, 0.72, 0.18)
const COL_FOOD  := Color(1.0,  0.25, 0.25)
const COL_HUD   := Color(0.0,  0.0,  0.0,  0.75)
const COL_SCORE := Color(0.4,  1.0,  0.4)
const COL_LIVES := Color(1.0,  0.4,  0.4)

# ── Spilltilstand ────────────────────────────────────────────
var snake       : Array   = []   # Array[Vector2i]
var direction   : Vector2i= Vector2i(1, 0)
var next_dir    : Vector2i= Vector2i(1, 0)
var food        : Vector2i= Vector2i(0, 0)
var score       : int     = 0
var lives       : int     = 3
var state       : String  = "ready"
var step_timer  : float   = 0.0
var step_time   : float   = 0.18   # sekunder per steg
var grow_pending: int     = 0

# ── Lyd ──────────────────────────────────────────────────────
var _snd_eat    : AudioStreamPlayer
var _snd_die    : AudioStreamPlayer
var _snd_over   : AudioStreamPlayer
var _snd_win    : AudioStreamPlayer

func _ready() -> void:
	custom_minimum_size = Vector2(BW, BH)
	set_process(true)
	set_process_unhandled_input(true)
	_setup_audio()
	_reset_game()

func restart() -> void:
	_reset_game()
	queue_redraw()

func _reset_game() -> void:
	# Start med 3 segment midt på skjermen
	snake.clear()
	snake.append(Vector2i(COLS / 2,     ROWS / 2))
	snake.append(Vector2i(COLS / 2 - 1, ROWS / 2))
	snake.append(Vector2i(COLS / 2 - 2, ROWS / 2))
	direction    = Vector2i(1, 0)
	next_dir     = Vector2i(1, 0)
	grow_pending = 0
	step_timer   = 0.0
	step_time    = 0.18
	score        = 0
	_place_food()
	state        = "ready"

func _place_food() -> void:
	var occupied := {}
	for seg in snake:
		occupied[seg] = true
	var candidates : Array = []
	for c in COLS:
		for r in ROWS:
			var p := Vector2i(c, r)
			if not occupied.has(p):
				candidates.append(p)
	if candidates.is_empty():
		state = "win"
		return
	food = candidates[randi() % candidates.size()]

# ── Prosess ──────────────────────────────────────────────────
func _process(delta: float) -> void:
	if state != "playing":
		queue_redraw()
		return

	step_timer += delta
	if step_timer < step_time:
		queue_redraw()
		return
	step_timer = 0.0

	direction = next_dir
	var head  : Vector2i = snake[0] + direction

	# Vegg-kollisjon
	if head.x < 0 or head.x >= COLS or head.y < 0 or head.y >= ROWS:
		_die()
		return

	# Selv-kollisjon (ikke hale, den flyttes bort)
	var body_end := snake.size() - 1 if grow_pending == 0 else snake.size()
	for i in body_end:
		if snake[i] == head:
			_die()
			return

	snake.insert(0, head)

	if head == food:
		score       += 10
		grow_pending += 2
		step_time    = maxf(0.06, step_time - 0.004)
		_play(_snd_eat)
		_place_food()
	elif grow_pending > 0:
		grow_pending -= 1
		# Ikke fjern halen
	else:
		snake.pop_back()

	queue_redraw()

func _die() -> void:
	lives -= 1
	if lives <= 0:
		state = "gameover"
		_play(_snd_over)
	else:
		state = "dead"
		_play(_snd_die)
	queue_redraw()

# ── Input ────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey: return
	var key := event as InputEventKey
	if not key.pressed or key.echo: return

	match key.keycode:
		KEY_ESCAPE:
			game_closed.emit()
			return
		KEY_SPACE:
			match state:
				"ready", "dead":
					state = "playing"
				"gameover", "win":
					lives = 3
					restart()
			return

	if state != "playing":
		return

	var d := Vector2i(0, 0)
	match key.keycode:
		KEY_UP,    KEY_W:  d = Vector2i( 0, -1)
		KEY_DOWN,  KEY_S:  d = Vector2i( 0,  1)
		KEY_LEFT,  KEY_A:  d = Vector2i(-1,  0)
		KEY_RIGHT, KEY_D:  d = Vector2i( 1,  0)

	# Ikke tillat 180-graders sving
	if d != Vector2i(0, 0) and d != -direction:
		next_dir = d

# ── Tegning ──────────────────────────────────────────────────
func _draw() -> void:
	# Bakgrunn
	draw_rect(Rect2(0, 0, BW, BH), COL_BG)

	# HUD-stripe
	draw_rect(Rect2(0, 0, BW, HUD_H), COL_HUD)

	var fnt := ThemeDB.fallback_font
	draw_string(fnt, Vector2(10, 28),
		"SCORE: %d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, COL_SCORE)
	draw_string(fnt, Vector2(BW / 2.0, 28),
		"LIVES: %s" % _hearts(lives), HORIZONTAL_ALIGNMENT_CENTER, -1, 18, COL_LIVES)
	draw_string(fnt, Vector2(BW - 10, 28),
		"SPD %.1fx" % (0.18 / maxf(step_time, 0.001)), HORIZONTAL_ALIGNMENT_RIGHT, -1, 16,
		Color(0.5, 0.7, 1.0))

	# Grid-linje (subtil)
	for c in COLS + 1:
		var x := c * CELL
		draw_line(Vector2(x, HUD_H), Vector2(x, BH), Color(0.07, 0.12, 0.07), 1.0)
	for r in ROWS + 1:
		var y := HUD_H + r * CELL
		draw_line(Vector2(0, y), Vector2(BW, y), Color(0.07, 0.12, 0.07), 1.0)

	# Mat
	var fr := _cell_rect(food)
	draw_rect(fr.grow(-3), COL_FOOD)
	draw_rect(fr.grow(-3), Color(1.0, 0.5, 0.5, 0.5), false, 1.0)

	# Slange
	for i in snake.size():
		var seg  : Vector2i = snake[i]
		var rect : Rect2    = _cell_rect(seg)
		var col  : Color    = COL_HEAD if i == 0 else COL_BODY
		draw_rect(rect.grow(-2), col)
		# Lyshighlight øverst på hvert segment
		draw_rect(Rect2(rect.position.x + 2, rect.position.y + 2, rect.size.x - 4, 4),
			Color(1.0, 1.0, 1.0, 0.18))

	# Overlay-meldinger
	match state:
		"ready":
			_draw_msg("TRYKK MELLOMROM FOR A STARTE", Color(1.0, 1.0, 0.4))
		"dead":
			_draw_msg("AU!  MELLOMROM FOR A FORTSETTE  (%d LIV IGJEN)" % lives,
				Color(1.0, 0.6, 0.2))
		"gameover":
			_draw_msg("GAME OVER   SCORE: %d   MELLOMROM FOR NY" % score, Color(1.0, 0.3, 0.3))
		"win":
			_draw_msg("DU VANT!  SCORE: %d  IMPONERENDE!" % score, Color(0.3, 1.0, 0.3))

	draw_string(fnt, Vector2(BW / 2.0, BH - 6),
		"Piltaster/WASD = styr   ESC = tilbake til terminal",
		HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.3, 0.5, 0.3))

func _cell_rect(pos: Vector2i) -> Rect2:
	return Rect2(pos.x * CELL, HUD_H + pos.y * CELL, CELL, CELL)

func _draw_msg(text: String, color: Color) -> void:
	var fnt := ThemeDB.fallback_font
	draw_rect(Rect2(0, BH / 2.0 - 28, BW, 54), Color(0.0, 0.0, 0.0, 0.85))
	draw_string(fnt, Vector2(BW / 2.0, BH / 2.0 + 10),
		text, HORIZONTAL_ALIGNMENT_CENTER, -1, 20, color)

func _hearts(n: int) -> String:
	var s := ""
	for i in 3:
		s += ("v" if i < n else "-")
	return s

# ── Lyd (samme mønster som Breakout) ────────────────────────
func _make_tone(freq_start: float, freq_end: float, dur: float,
		vol: float = 0.6, wave: int = 0) -> AudioStreamWAV:
	var sr   : int             = 22050
	var n    : int             = int(sr * dur)
	var data : PackedByteArray = PackedByteArray()
	data.resize(n)
	var phase : float = 0.0
	for i in n:
		var t    : float = float(i) / float(n)
		var freq : float = lerpf(freq_start, freq_end, t)
		phase += TAU * freq / float(sr)
		var attack : float = minf(t / maxf(0.01 / dur, 0.001), 1.0)
		var decay  : float = 1.0 - t
		var env    : float = attack * decay * vol
		var raw    : float = 0.0
		match wave:
			0: raw = sin(phase)
			1: raw = 1.0 if sin(phase) >= 0.0 else -1.0
			2: raw = fmod(phase / TAU, 1.0) * 2.0 - 1.0
		data[i] = int(clamp(raw * env * 127.0 + 128.0, 0.0, 255.0))
	var stream := AudioStreamWAV.new()
	stream.format   = 0
	stream.mix_rate = sr
	stream.stereo   = false
	stream.data     = data
	return stream

func _make_seq(tones: Array) -> AudioStreamWAV:
	var sr   : int             = 22050
	var full : PackedByteArray = PackedByteArray()
	for t in tones:
		var chunk := _make_tone(t[0], t[1], t[2],
			t[3] if t.size() > 3 else 0.6,
			t[4] if t.size() > 4 else 0)
		full.append_array(chunk.data)
	var stream := AudioStreamWAV.new()
	stream.format   = 0
	stream.mix_rate = sr
	stream.stereo   = false
	stream.data     = full
	return stream

func _make_player(stream: AudioStreamWAV, vol_db: float = 0.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream    = stream
	p.volume_db = vol_db
	p.bus       = "Master"
	p.autoplay  = false
	add_child(p)
	return p

func _setup_audio() -> void:
	# Spiser mat: lystig stigende boing
	_snd_eat = _make_player(_make_tone(440.0, 880.0, 0.08, 0.55, 0), -3.0)
	# Dør: kort synkende pip
	_snd_die = _make_player(_make_tone(440.0, 110.0, 0.30, 0.65, 1), -2.0)
	# Game over: tre fallende noter
	_snd_over = _make_player(_make_seq([
		[330.0, 330.0, 0.15, 0.6, 0],
		[247.0, 247.0, 0.15, 0.6, 0],
		[165.0,  80.0, 0.30, 0.7, 0],
	]), -1.0)
	# Seier: liten fanfare
	_snd_win = _make_player(_make_seq([
		[262.0, 262.0, 0.10, 0.55, 0],
		[330.0, 330.0, 0.10, 0.55, 0],
		[392.0, 392.0, 0.10, 0.55, 0],
		[524.0, 700.0, 0.25, 0.65, 0],
	]), -1.0)

func _play(p: AudioStreamPlayer) -> void:
	if p == null: return
	p.stop()
	p.play()
