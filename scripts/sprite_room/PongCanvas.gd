extends Control
## Pong i C64-terminalen
## Venstre: W/S   Høyre: Pil opp/ned (eller AI)
## ESC = tilbake til terminal

signal game_closed

const BW       := 780.0
const BH       := 480.0
const HUD_H    := 40.0
const WIN_SCORE := 7

# ── Paddle ────────────────────────────────────────────────────
const PAD_W    := 14.0
const PAD_H    := 80.0
const PAD_OFFX := 24.0
const PAD_SPD  := 320.0

# ── Ball ──────────────────────────────────────────────────────
const BALL_R   := 8.0
const BALL_SPD := 280.0

# ── Farger ───────────────────────────────────────────────────
const COL_BG    := Color(0.04, 0.04, 0.08)
const COL_PAD_L := Color(0.3, 0.7, 1.0)
const COL_PAD_R := Color(1.0, 0.5, 0.2)
const COL_BALL  := Color(1.0, 1.0, 0.9)
const COL_NET   := Color(0.25, 0.25, 0.3)
const COL_HUD   := Color(0.0, 0.0, 0.0, 0.8)

# ── Spilltilstand ────────────────────────────────────────────
var pad_l_y : float   = (BH - HUD_H) / 2.0 - PAD_H / 2.0 + HUD_H
var pad_r_y : float   = (BH - HUD_H) / 2.0 - PAD_H / 2.0 + HUD_H
var ball_pos : Vector2 = Vector2(BW / 2.0, HUD_H + (BH - HUD_H) / 2.0)
var ball_vel : Vector2 = Vector2(BALL_SPD, BALL_SPD * 0.5)
var score_l  : int    = 0
var score_r  : int    = 0
var state    : String = "ready"
var ai_right : bool   = true   # CPU styrer høyre paddle

# ── Lyd ──────────────────────────────────────────────────────
var _snd_wall   : AudioStreamPlayer
var _snd_paddle : AudioStreamPlayer
var _snd_score  : AudioStreamPlayer
var _snd_win    : AudioStreamPlayer

func _ready() -> void:
	custom_minimum_size = Vector2(BW, BH)
	set_process(true)
	set_process_unhandled_input(true)
	_setup_audio()

func restart() -> void:
	pad_l_y  = (BH - HUD_H) / 2.0 - PAD_H / 2.0 + HUD_H
	pad_r_y  = pad_l_y
	score_l  = 0
	score_r  = 0
	state    = "ready"
	_reset_ball(1.0)
	queue_redraw()

func _reset_ball(dir_x: float) -> void:
	ball_pos = Vector2(BW / 2.0, HUD_H + (BH - HUD_H) / 2.0)
	var angle := randf_range(-0.45, 0.45)
	ball_vel  = Vector2(dir_x, 0.0).rotated(angle).normalized() * BALL_SPD

# ── Prosess ──────────────────────────────────────────────────
func _process(delta: float) -> void:
	if state != "playing":
		queue_redraw()
		return

	# ── Venstre paddle (W/S) ────────────────────────────────
	if Input.is_key_pressed(KEY_W):
		pad_l_y = maxf(HUD_H, pad_l_y - PAD_SPD * delta)
	if Input.is_key_pressed(KEY_S):
		pad_l_y = minf(BH - PAD_H, pad_l_y + PAD_SPD * delta)

	# ── Høyre paddle ────────────────────────────────────────
	if ai_right:
		# Enkel AI: følger ballen med litt forsinkelse
		var center := pad_r_y + PAD_H / 2.0
		var diff   := ball_pos.y - center
		var move   := clampf(diff * 4.0, -PAD_SPD, PAD_SPD) * delta
		pad_r_y    = clampf(pad_r_y + move, HUD_H, BH - PAD_H)
	else:
		if Input.is_key_pressed(KEY_UP):
			pad_r_y = maxf(HUD_H, pad_r_y - PAD_SPD * delta)
		if Input.is_key_pressed(KEY_DOWN):
			pad_r_y = minf(BH - PAD_H, pad_r_y + PAD_SPD * delta)

	# ── Ball ────────────────────────────────────────────────
	ball_pos += ball_vel * delta

	# Tak og gulv
	if ball_pos.y - BALL_R < HUD_H:
		ball_pos.y = HUD_H + BALL_R
		ball_vel.y = abs(ball_vel.y)
		_play(_snd_wall)
	if ball_pos.y + BALL_R > BH:
		ball_pos.y = BH - BALL_R
		ball_vel.y = -abs(ball_vel.y)
		_play(_snd_wall)

	# Venstre paddle-kollisjon
	var lr := Rect2(PAD_OFFX, pad_l_y, PAD_W, PAD_H)
	if lr.has_point(ball_pos) and ball_vel.x < 0:
		var hit    := (ball_pos.y - (pad_l_y + PAD_H / 2.0)) / (PAD_H / 2.0)
		var speed  := ball_vel.length() * 1.04
		ball_vel   = Vector2(abs(ball_vel.x), hit * speed * 0.7).normalized() * minf(speed, 520.0)
		ball_pos.x = PAD_OFFX + PAD_W + BALL_R
		_play(_snd_paddle)

	# Høyre paddle-kollisjon
	var rr := Rect2(BW - PAD_OFFX - PAD_W, pad_r_y, PAD_W, PAD_H)
	if rr.has_point(ball_pos) and ball_vel.x > 0:
		var hit    := (ball_pos.y - (pad_r_y + PAD_H / 2.0)) / (PAD_H / 2.0)
		var speed  := ball_vel.length() * 1.04
		ball_vel   = Vector2(-abs(ball_vel.x), hit * speed * 0.7).normalized() * minf(speed, 520.0)
		ball_pos.x = BW - PAD_OFFX - PAD_W - BALL_R
		_play(_snd_paddle)

	# Mål
	if ball_pos.x < -BALL_R:
		score_r += 1
		_play(_snd_score)
		if score_r >= WIN_SCORE:
			state = "win_r"
			_play(_snd_win)
		else:
			state = "scored"
			await get_tree().create_timer(1.0).timeout
			if state == "scored":
				_reset_ball(1.0)
				state = "playing"

	elif ball_pos.x > BW + BALL_R:
		score_l += 1
		_play(_snd_score)
		if score_l >= WIN_SCORE:
			state = "win_l"
			_play(_snd_win)
		else:
			state = "scored"
			await get_tree().create_timer(1.0).timeout
			if state == "scored":
				_reset_ball(-1.0)
				state = "playing"

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
				"ready":
					state = "playing"
				"win_l", "win_r":
					restart()
		KEY_TAB:
			# Bytt mellom AI og 2-spiller for høyre paddle
			ai_right = not ai_right

# ── Tegning ──────────────────────────────────────────────────
func _draw() -> void:
	draw_rect(Rect2(0, 0, BW, BH), COL_BG)
	draw_rect(Rect2(0, 0, BW, HUD_H), COL_HUD)

	var fnt := ThemeDB.fallback_font

	# Score
	draw_string(fnt, Vector2(BW * 0.25, 28),
		str(score_l), HORIZONTAL_ALIGNMENT_CENTER, -1, 22, COL_PAD_L)
	draw_string(fnt, Vector2(BW * 0.75, 28),
		str(score_r), HORIZONTAL_ALIGNMENT_CENTER, -1, 22, COL_PAD_R)
	draw_string(fnt, Vector2(BW / 2.0, 28),
		"PONG", HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(0.6, 0.6, 0.7))

	var mode_txt := "AI" if ai_right else "2P"
	draw_string(fnt, Vector2(BW - 10, 28),
		mode_txt, HORIZONTAL_ALIGNMENT_RIGHT, -1, 13, Color(0.5, 0.5, 0.6))

	# Midtlinje (stiplet)
	var seg_h := 14.0
	var y     := HUD_H + 4.0
	while y < BH:
		draw_rect(Rect2(BW / 2.0 - 2.0, y, 4.0, seg_h), COL_NET)
		y += seg_h + 8.0

	# Paddles
	draw_rect(Rect2(PAD_OFFX, pad_l_y, PAD_W, PAD_H), COL_PAD_L)
	draw_rect(Rect2(BW - PAD_OFFX - PAD_W, pad_r_y, PAD_W, PAD_H), COL_PAD_R)

	# Høydepunkt på paddles
	draw_rect(Rect2(PAD_OFFX, pad_l_y, PAD_W, 6), Color(0.7, 1.0, 1.0, 0.4))
	draw_rect(Rect2(BW - PAD_OFFX - PAD_W, pad_r_y, PAD_W, 6), Color(1.0, 0.8, 0.5, 0.4))

	# Ball (med lyseffekt)
	draw_circle(ball_pos, BALL_R, COL_BALL)
	draw_circle(ball_pos - Vector2(2, 2), BALL_R * 0.35, Color(1.0, 1.0, 1.0, 0.6))

	# Lag-etiketter
	draw_string(fnt, Vector2(PAD_OFFX + PAD_W + 8, HUD_H + 22),
		"W/S", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.3, 0.6, 0.9, 0.7))
	var r_label := "TAB=AI/2P" if state == "ready" else ("AI" if ai_right else "Pil opp/ned")
	draw_string(fnt, Vector2(BW - PAD_OFFX - PAD_W - 8, HUD_H + 22),
		r_label, HORIZONTAL_ALIGNMENT_RIGHT, -1, 12, Color(0.9, 0.5, 0.2, 0.7))

	# Meldinger
	match state:
		"ready":
			_draw_msg("TRYKK MELLOMROM FOR A STARTE  (TAB = AI/2P)", Color(1.0, 1.0, 0.4))
		"scored":
			_draw_msg("MÅL!", Color(1.0, 0.8, 0.2))
		"win_l":
			_draw_msg("VENSTRE VANT!   MELLOMROM FOR NY RUNDE", COL_PAD_L)
		"win_r":
			_draw_msg(("%s VANT!   MELLOMROM FOR NY RUNDE" % ("AI" if ai_right else "HØYRE")), COL_PAD_R)

	draw_string(fnt, Vector2(BW / 2.0, BH - 6),
		"W/S = venstre   Pil opp/ned = høyre (eller AI)   TAB = bytt modus   ESC = tilbake",
		HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(0.3, 0.4, 0.5))

func _draw_msg(text: String, color: Color) -> void:
	var fnt := ThemeDB.fallback_font
	draw_rect(Rect2(0, BH / 2.0 - 28, BW, 54), Color(0.0, 0.0, 0.0, 0.85))
	draw_string(fnt, Vector2(BW / 2.0, BH / 2.0 + 10),
		text, HORIZONTAL_ALIGNMENT_CENTER, -1, 20, color)

# ── Lyd ──────────────────────────────────────────────────────
func _make_tone(freq_start: float, freq_end: float, dur: float,
		vol: float = 0.6, wave: int = 0) -> AudioStreamWAV:
	var sr := 22050; var n := int(sr * dur)
	var data := PackedByteArray(); data.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(n)
		var freq := lerpf(freq_start, freq_end, t)
		phase += TAU * freq / float(sr)
		var env := minf(t / maxf(0.01 / dur, 0.001), 1.0) * (1.0 - t) * vol
		var raw := 0.0
		match wave:
			0: raw = sin(phase)
			1: raw = 1.0 if sin(phase) >= 0.0 else -1.0
		data[i] = int(clamp(raw * env * 127.0 + 128.0, 0.0, 255.0))
	var s := AudioStreamWAV.new()
	s.format = 0; s.mix_rate = sr; s.stereo = false; s.data = data
	return s

func _make_seq(tones: Array) -> AudioStreamWAV:
	var sr := 22050; var full := PackedByteArray()
	for t in tones:
		full.append_array(_make_tone(t[0], t[1], t[2],
			t[3] if t.size() > 3 else 0.6,
			t[4] if t.size() > 4 else 0).data)
	var s := AudioStreamWAV.new()
	s.format = 0; s.mix_rate = sr; s.stereo = false; s.data = full
	return s

func _make_player(stream: AudioStreamWAV, vol_db: float = 0.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream; p.volume_db = vol_db; p.bus = "Master"; p.autoplay = false
	add_child(p); return p

func _setup_audio() -> void:
	_snd_wall   = _make_player(_make_tone(700.0, 700.0, 0.04, 0.45, 1), -4.0)
	_snd_paddle = _make_player(_make_tone(300.0, 550.0, 0.08, 0.60, 0), -3.0)
	_snd_score  = _make_player(_make_tone(200.0,  80.0, 0.30, 0.65, 0), -2.0)
	_snd_win    = _make_player(_make_seq([
		[262.0, 262.0, 0.10, 0.5, 0],
		[330.0, 330.0, 0.10, 0.5, 0],
		[392.0, 392.0, 0.10, 0.5, 0],
		[524.0, 700.0, 0.22, 0.6, 0],
	]), -1.0)

func _play(p: AudioStreamPlayer) -> void:
	if p == null: return
	p.stop(); p.play()
