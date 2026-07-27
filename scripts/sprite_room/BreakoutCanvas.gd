extends Control
## Breakout-klone som kjører inne i C64-terminalen
## Kontrolleres med mus (horisontal) + A/D / ←/→
## Lyd genereres programmatisk – ingen lydfiler nødvendig

signal game_closed

# ── Spilldimensjoner ──────────────────────────────────────────
const BW    := 780.0
const BH    := 480.0

# ── Brikke-layout ─────────────────────────────────────────────
const BRICK_ROWS  := 6
const BRICK_COLS  := 12
const BRICK_W     := 60.0
const BRICK_H     := 20.0
const BRICK_GAD_X := 3.0
const BRICK_GAD_Y := 3.0
const BRICK_OFF_X := 9.0
const BRICK_OFF_Y := 55.0

# ── Paddle og ball ─────────────────────────────────────────────
const PADDLE_W     := 100.0
const PADDLE_H     := 12.0
const PADDLE_Y     := BH - 45.0
const BALL_R       := 7.0
const INIT_SPEED   := 290.0
const PADDLE_SPEED := 420.0

# ── Farger per rad ─────────────────────────────────────────────
const ROW_COLORS: Array = [
	Color(1.0, 0.22, 0.22),
	Color(1.0, 0.55, 0.1),
	Color(1.0, 1.0,  0.2),
	Color(0.2, 0.95, 0.2),
	Color(0.25, 0.6, 1.0),
	Color(0.8,  0.2, 1.0),
]

# ── Brick-pitch per rad (øverste rad = høyest) ─────────────────
const ROW_FREQS: Array = [
	880.0,  # rød   – høy
	660.0,  # oransje
	523.0,  # gul
	440.0,  # grønn
	330.0,  # blå
	262.0,  # lilla – lav
]

# ── Spilltilstand ─────────────────────────────────────────────
var paddle_x  : float   = BW / 2.0
var ball_pos  : Vector2 = Vector2(BW / 2.0, BH - 100.0)
var ball_vel  : Vector2 = Vector2(180.0, -INIT_SPEED)
var bricks    : Array   = []
var lives     : int     = 3
var score     : int     = 0
var speed_mul : float   = 1.0
var state     : String  = "ready"

# ── Lydspillere ───────────────────────────────────────────────
var _snd_wall    : AudioStreamPlayer
var _snd_paddle  : AudioStreamPlayer
var _snd_brick   : Array  = []   # én per rad
var _snd_death   : AudioStreamPlayer
var _snd_win     : AudioStreamPlayer
var _snd_gameover: AudioStreamPlayer

# ── Init ──────────────────────────────────────────────────────
func _ready() -> void:
	custom_minimum_size = Vector2(BW, BH)
	set_process(true)
	set_process_unhandled_input(true)
	_init_bricks()
	_setup_audio()

func restart() -> void:
	lives     = 3
	score     = 0
	speed_mul = 1.0
	paddle_x  = BW / 2.0
	ball_pos  = Vector2(BW / 2.0, BH - 100.0)
	ball_vel  = Vector2(180.0, -INIT_SPEED)
	_init_bricks()
	state = "ready"
	queue_redraw()

func _init_bricks() -> void:
	bricks.clear()
	for row in BRICK_ROWS:
		for col in BRICK_COLS:
			var x : float = BRICK_OFF_X + col * (BRICK_W + BRICK_GAD_X)
			var y : float = BRICK_OFF_Y + row * (BRICK_H + BRICK_GAD_Y)
			bricks.append({
				"rect"  : Rect2(x, y, BRICK_W, BRICK_H),
				"alive" : true,
				"color" : ROW_COLORS[row % ROW_COLORS.size()],
				"pts"   : (BRICK_ROWS - row) * 10,
				"row"   : row
			})

# ═══════════════════════════════════════════════════════════════
# LYDGENERERING
# ═══════════════════════════════════════════════════════════════

## Lag en AudioStreamWAV fra tone-parametere (ingen lydfiler!)
## Bruker 8-bit unsigned PCM (128 = stille, 0 = min, 255 = max)
## freq_start/end: Hz, dur: sekunder, vol: 0-1
## wave: 0=sinus, 1=firkant, 2=sagtann
func _make_tone(freq_start: float, freq_end: float, dur: float,
		vol: float = 0.6, wave: int = 0) -> AudioStreamWAV:
	var sr    : int             = 22050
	var n     : int             = int(sr * dur)
	var data  : PackedByteArray = PackedByteArray()
	data.resize(n)   # 8-bit PCM, mono – 1 byte per sample

	var phase : float = 0.0
	for i in n:
		var t    : float = float(i) / float(n)
		var freq : float = lerpf(freq_start, freq_end, t)
		phase += TAU * freq / float(sr)

		# Envelope: rask attack og lineær decay
		var attack : float = minf(t / maxf(0.01 / dur, 0.001), 1.0)
		var decay  : float = 1.0 - t
		var env    : float = attack * decay * vol

		var raw : float = 0.0
		match wave:
			0:   # sinus
				raw = sin(phase)
			1:   # firkant
				raw = 1.0 if sin(phase) >= 0.0 else -1.0
			2:   # sagtann
				raw = fmod(phase / TAU, 1.0) * 2.0 - 1.0

		# 8-bit unsigned: 128 = stille, 0 = -1, 255 = +1
		data[i] = int(clamp(raw * env * 127.0 + 128.0, 0.0, 255.0))

	var stream : AudioStreamWAV = AudioStreamWAV.new()
	stream.format   = 0   # FORMAT_8_BIT = 0
	stream.mix_rate = sr
	stream.stereo   = false
	stream.data     = data
	return stream

## Sett sammen to toner etter hverandre
func _make_seq(tones: Array) -> AudioStreamWAV:
	var sr   : int   = 22050
	var full : PackedByteArray = PackedByteArray()
	for t in tones:
		var chunk : AudioStreamWAV = _make_tone(t[0], t[1], t[2],
			t[3] if t.size() > 3 else 0.6,
			t[4] if t.size() > 4 else 0)
		full.append_array(chunk.data)
	var stream : AudioStreamWAV = AudioStreamWAV.new()
	stream.format   = 0   # FORMAT_8_BIT = 0
	stream.mix_rate = sr
	stream.stereo   = false
	stream.data     = full
	return stream

func _make_player(stream: AudioStreamWAV, vol_db: float = 0.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream         = stream
	p.volume_db      = vol_db
	p.bus            = "Master"
	p.autoplay       = false
	add_child(p)
	return p

func _setup_audio() -> void:
	# Vegg-trekk: kort høy klikk
	_snd_wall = _make_player(_make_tone(700.0, 700.0, 0.04, 0.45, 1), -4.0)

	# Paddle-treff: stigende boing (sinus)
	_snd_paddle = _make_player(_make_tone(280.0, 500.0, 0.09, 0.65, 0), -2.0)

	# Brikke-pong: én lyd per rad, pitch fra ROW_FREQS
	_snd_brick.clear()
	for row in BRICK_ROWS:
		var freq : float = ROW_FREQS[row]
		# Kort plong med litt sagtann-innslag for fylde
		var p := _make_player(_make_tone(freq, freq * 0.7, 0.07, 0.55, 0), -3.0)
		_snd_brick.append(p)

	# Liv tapt: synkende sweep
	_snd_death = _make_player(_make_tone(440.0, 80.0, 0.55, 0.7, 0), -1.0)

	# Game over: tre fallende noter
	_snd_gameover = _make_player(_make_seq([
		[330.0, 330.0, 0.18, 0.6, 0],
		[247.0, 247.0, 0.18, 0.6, 0],
		[185.0,  80.0, 0.35, 0.7, 0],
	]), -1.0)

	# Seier: liten fanfare (C-E-G-C)
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

# ═══════════════════════════════════════════════════════════════
# SPILLOGIKK
# ═══════════════════════════════════════════════════════════════

func _process(delta: float) -> void:
	if state != "playing":
		queue_redraw()
		return

	# ── Paddle ───────────────────────────────────────────────
	var mouse_local : Vector2 = get_local_mouse_position()
	paddle_x = clamp(mouse_local.x, PADDLE_W / 2.0, BW - PADDLE_W / 2.0)
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		paddle_x = max(PADDLE_W / 2.0, paddle_x - PADDLE_SPEED * delta)
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		paddle_x = min(BW - PADDLE_W / 2.0, paddle_x + PADDLE_SPEED * delta)

	# ── Ball ─────────────────────────────────────────────────
	ball_pos += ball_vel * delta * speed_mul

	# Vegger
	if ball_pos.x <= BALL_R:
		ball_pos.x = BALL_R
		ball_vel.x = abs(ball_vel.x)
		_play(_snd_wall)
	if ball_pos.x >= BW - BALL_R:
		ball_pos.x = BW - BALL_R
		ball_vel.x = -abs(ball_vel.x)
		_play(_snd_wall)
	if ball_pos.y <= BALL_R:
		ball_pos.y = BALL_R
		ball_vel.y = abs(ball_vel.y)
		_play(_snd_wall)

	# Paddle-kollisjon
	var pl : Rect2 = Rect2(paddle_x - PADDLE_W / 2.0, PADDLE_Y, PADDLE_W, PADDLE_H)
	if pl.has_point(ball_pos) and ball_vel.y > 0.0:
		var hit  : float = (ball_pos.x - paddle_x) / (PADDLE_W / 2.0)
		var spd  : float = INIT_SPEED * speed_mul
		ball_vel = Vector2(hit * spd * 0.7, -spd).normalized() * spd
		ball_pos.y = PADDLE_Y - BALL_R - 1.0
		_play(_snd_paddle)

	# Ball faller ut
	if ball_pos.y > BH + 30.0:
		lives -= 1
		if lives <= 0:
			state = "gameover"
			_play(_snd_gameover)
		else:
			state = "dead"
			ball_pos = Vector2(BW / 2.0, BH - 100.0)
			ball_vel = Vector2(180.0, -INIT_SPEED)
			_play(_snd_death)

	# Brikke-kollisjon
	var hit_brick : bool = false
	for brick in bricks:
		if not brick.alive or hit_brick:
			continue
		var br       : Rect2 = brick.rect
		var expanded : Rect2 = br.grow(BALL_R * 0.4)
		if not expanded.has_point(ball_pos):
			continue

		brick.alive = false
		hit_brick   = true
		score      += int(brick.pts)

		var row_idx : int = int(brick.row)
		if row_idx >= 0 and row_idx < _snd_brick.size():
			_play(_snd_brick[row_idx])

		var center : Vector2 = br.get_center()
		var dx     : float   = abs(ball_pos.x - center.x) - br.size.x / 2.0
		var dy     : float   = abs(ball_pos.y - center.y) - br.size.y / 2.0
		if dx > dy:
			ball_vel.x = -ball_vel.x
		else:
			ball_vel.y = -ball_vel.y

		speed_mul = minf(1.0 + float(score) / 800.0, 1.8)

	# Sjekk seier
	var all_dead : bool = true
	for brick in bricks:
		if brick.alive:
			all_dead = false
			break
	if all_dead and state == "playing":
		state = "win"
		_play(_snd_win)

	queue_redraw()

# ── Tastatur ──────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey: return
	var key := event as InputEventKey
	if not key.pressed or key.echo: return

	if key.keycode == KEY_ESCAPE:
		game_closed.emit()
		return

	if key.keycode == KEY_SPACE:
		match state:
			"ready", "dead":
				state = "playing"
			"gameover", "win":
				restart()

# ═══════════════════════════════════════════════════════════════
# TEGNING
# ═══════════════════════════════════════════════════════════════

func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, BW, BH), Color(0.03, 0.03, 0.09))
	draw_rect(Rect2(0.0, 0.0, BW, 48.0), Color(0.0, 0.0, 0.0, 0.7))

	var fnt := ThemeDB.fallback_font
	draw_string(fnt, Vector2(10.0, 32.0),
		"SCORE: %d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.4, 1.0, 0.4))
	draw_string(fnt, Vector2(BW / 2.0, 32.0),
		"LIVES: %s" % _hearts(lives), HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color(1.0, 0.4, 0.4))
	draw_string(fnt, Vector2(BW - 10.0, 32.0),
		"LVL %.1fx" % speed_mul, HORIZONTAL_ALIGNMENT_RIGHT, -1, 16, Color(0.5, 0.7, 1.0))

	for brick in bricks:
		if not brick.alive:
			continue
		var br : Rect2 = brick.rect
		draw_rect(br, brick.color)
		draw_rect(Rect2(br.position.x, br.position.y, br.size.x, 3.0), Color(1.0, 1.0, 1.0, 0.3))
		draw_rect(br, Color(0.0, 0.0, 0.0, 0.4), false, 1.0)

	var pr : Rect2 = Rect2(paddle_x - PADDLE_W / 2.0, PADDLE_Y, PADDLE_W, PADDLE_H)
	draw_rect(pr, Color(0.75, 0.85, 1.0))
	draw_rect(Rect2(pr.position.x, pr.position.y, pr.size.x, 3.0), Color(1.0, 1.0, 1.0, 0.5))
	draw_rect(pr, Color(0.5, 0.7, 1.0, 0.6), false, 1.5)

	draw_circle(ball_pos, BALL_R, Color(1.0, 0.95, 0.8))
	draw_circle(ball_pos - Vector2(2.0, 2.0), BALL_R * 0.35, Color(1.0, 1.0, 1.0, 0.6))

	match state:
		"ready":
			_draw_msg("TRYKK MELLOMROM FOR Å STARTE", Color(1.0, 1.0, 0.4))
		"dead":
			_draw_msg("MISTET BALL – MELLOMROM FOR Å FORTSETTE", Color(1.0, 0.6, 0.2))
		"gameover":
			_draw_msg("GAME OVER   SCORE: %d   MELLOMROM FOR NY" % score, Color(1.0, 0.3, 0.3))
		"win":
			_draw_msg("DU VANT!   SCORE: %d   MELLOMROM FOR NY" % score, Color(0.3, 1.0, 0.3))

	draw_string(fnt, Vector2(BW / 2.0, BH - 6.0),
		"ESC – tilbake til terminal", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.4, 0.4, 0.4))

func _draw_msg(text: String, color: Color) -> void:
	var fnt := ThemeDB.fallback_font
	draw_rect(Rect2(0.0, BH / 2.0 - 28.0, BW, 54.0), Color(0.0, 0.0, 0.0, 0.8))
	draw_string(fnt, Vector2(BW / 2.0, BH / 2.0 + 10.0),
		text, HORIZONTAL_ALIGNMENT_CENTER, -1, 20, color)

func _hearts(n: int) -> String:
	var s := ""
	for i in 3:
		s += ("♥" if i < n else "♡")
	return s
