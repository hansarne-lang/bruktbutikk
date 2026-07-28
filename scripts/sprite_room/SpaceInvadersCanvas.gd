extends Control
## Space Invaders-klon i C64-terminalen
## A/D eller piltaster = beveg, MELLOMROM = skyt, ESC = tilbake

signal game_closed

const BW     := 780.0
const BH     := 480.0
const HUD_H  := 40.0

# ── Invader-grid ─────────────────────────────────────────────
const INV_COLS  := 11
const INV_ROWS  := 5
const INV_W     := 32.0
const INV_H     := 20.0
const INV_GAP_X := 14.0
const INV_GAP_Y := 16.0
const INV_START_X := 50.0
const INV_START_Y := 80.0

# Poeng per rad (øverste rad = flest)
const ROW_PTS := [30, 20, 20, 10, 10]
# Farge per rad
const ROW_COL := [
	Color(1.0, 0.3, 0.3),   # rød
	Color(1.0, 0.65, 0.1),  # oransje
	Color(1.0, 1.0, 0.2),   # gul
	Color(0.3, 1.0, 0.3),   # grønn
	Color(0.4, 0.7, 1.0),   # blå
]

# ── Spiller ───────────────────────────────────────────────────
const PLAYER_W    := 52.0
const PLAYER_H    := 20.0
const PLAYER_Y    := BH - 55.0
const PLAYER_SPD  := 300.0

# ── Skudd ────────────────────────────────────────────────────
const BULLET_W    := 4.0
const BULLET_H    := 14.0
const PBULLET_SPD := 480.0
const IBULLET_SPD := 160.0

# ── Barrierer ────────────────────────────────────────────────
const NUM_BARRIERS := 4
const BAR_W        := 52.0
const BAR_H        := 28.0
const BAR_Y        := PLAYER_Y - 52.0
const BAR_HP       := 8

# ── Spieltilstand ────────────────────────────────────────────
var player_x    : float   = BW / 2.0
var invaders    : Array   = []   # {x,y,alive,row,col}
var inv_dir     : float   = 1.0
var inv_speed   : float   = 60.0
var inv_drop    : bool    = false
var inv_shoot_t : float   = 0.0
var inv_shoot_d : float   = 1.8

var p_bullet    : Dictionary = {}  # {x,y,active}
var i_bullets   : Array      = []  # [{x,y}]
var barriers    : Array      = []  # [{x,y,hp}]

var score       : int     = 0
var lives       : int     = 3
var state       : String  = "ready"
var wave        : int     = 1

# ── Lyd ──────────────────────────────────────────────────────
var _snd_shoot  : AudioStreamPlayer
var _snd_hit    : AudioStreamPlayer
var _snd_die    : AudioStreamPlayer
var _snd_over   : AudioStreamPlayer
var _snd_win    : AudioStreamPlayer
var _snd_march  : AudioStreamPlayer
var _march_t    : float   = 0.0
var _march_step : int     = 0

func _ready() -> void:
	custom_minimum_size = Vector2(BW, BH)
	set_process(true)
	set_process_unhandled_input(true)
	_setup_audio()
	_reset_wave()

func restart() -> void:
	score = 0
	lives = 3
	wave  = 1
	_reset_wave()
	state = "ready"
	queue_redraw()

func _reset_wave() -> void:
	# Invaders
	invaders.clear()
	for r in INV_ROWS:
		for c in INV_COLS:
			invaders.append({
				"x":     INV_START_X + c * (INV_W + INV_GAP_X),
				"y":     INV_START_Y + r * (INV_H + INV_GAP_Y),
				"alive": true,
				"row":   r,
				"col":   c,
			})
	inv_dir     = 1.0
	inv_speed   = 55.0 + (wave - 1) * 18.0
	inv_drop    = false
	inv_shoot_t = 0.0
	inv_shoot_d = maxf(0.6, 1.8 - (wave - 1) * 0.2)

	# Spiller
	player_x = BW / 2.0
	p_bullet  = {"active": false}
	i_bullets.clear()

	# Barrierer
	barriers.clear()
	var spacing := BW / (NUM_BARRIERS + 1)
	for i in NUM_BARRIERS:
		barriers.append({
			"x":  spacing * (i + 1) - BAR_W / 2.0,
			"y":  BAR_Y,
			"hp": BAR_HP,
		})

# ── Prosess ──────────────────────────────────────────────────
func _process(delta: float) -> void:
	if state != "playing":
		queue_redraw()
		return

	# Spillerbevegelse
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		player_x = maxf(PLAYER_W / 2.0, player_x - PLAYER_SPD * delta)
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		player_x = minf(BW - PLAYER_W / 2.0, player_x + PLAYER_SPD * delta)

	# Spillerbullet
	if p_bullet.get("active", false):
		p_bullet["y"] -= PBULLET_SPD * delta
		if p_bullet["y"] < HUD_H:
			p_bullet["active"] = false

	# Invader-bevegelse
	var alive_invs := invaders.filter(func(i): return i["alive"])
	if alive_invs.is_empty():
		# Neste bølge
		wave  += 1
		score += 200
		state  = "wave_clear"
		await get_tree().create_timer(1.5).timeout
		_reset_wave()
		state = "playing"
		return

	# Finn ytterpunkter
	var left_x  := INV_START_X + 999.0
	var right_x := 0.0
	for inv in alive_invs:
		left_x  = minf(left_x,  inv["x"])
		right_x = maxf(right_x, inv["x"] + INV_W)

	if inv_drop:
		for inv in invaders:
			if inv["alive"]:
				inv["y"] += INV_H * 0.6
		inv_dir  = -inv_dir
		inv_drop = false
	else:
		for inv in invaders:
			if inv["alive"]:
				inv["x"] += inv_speed * inv_dir * delta
		if inv_dir > 0 and right_x > BW - 10.0:
			inv_drop = true
		elif inv_dir < 0 and left_x < 10.0:
			inv_drop = true

	# Marsjlyd
	_march_t += delta
	var march_interval := maxf(0.08, 0.35 - float(alive_invs.size()) * 0.004)
	if _march_t >= march_interval:
		_march_t = 0.0
		_march_step = (_march_step + 1) % 4
		_play(_snd_march)

	# Invader-skudd
	inv_shoot_t += delta
	if inv_shoot_t >= inv_shoot_d:
		inv_shoot_t = 0.0
		# Finn en tilfeldig kolonne og den laveste levende der
		var col_map := {}
		for inv in invaders:
			if not inv["alive"]: continue
			var c : int = inv["col"]
			if not col_map.has(c) or inv["y"] > col_map[c]["y"]:
				col_map[c] = inv
		if not col_map.is_empty():
			var shooters := col_map.values()
			var shooter  : Dictionary = shooters[randi() % shooters.size()]
			i_bullets.append({
				"x": shooter["x"] + INV_W / 2.0,
				"y": shooter["y"] + INV_H,
			})

	# Flytt invader-skudd
	for b in i_bullets:
		b["y"] += IBULLET_SPD * delta
	i_bullets = i_bullets.filter(func(b): return b["y"] < BH + 20)

	# Kollisjon: spillerbullet vs invaders
	if p_bullet.get("active", false):
		var bx : float = p_bullet["x"]
		var by : float = p_bullet["y"]
		for inv in invaders:
			if not inv["alive"]: continue
			if bx >= inv["x"] and bx <= inv["x"] + INV_W and \
			   by >= inv["y"] and by <= inv["y"] + INV_H:
				inv["alive"]       = false
				p_bullet["active"] = false
				score             += ROW_PTS[inv["row"]]
				inv_speed          = minf(inv_speed * 1.04, 320.0)
				_play(_snd_hit)
				break

	# Kollisjon: spillerbullet vs barrierer
	if p_bullet.get("active", false):
		for bar in barriers:
			if bar["hp"] <= 0: continue
			var br := Rect2(bar["x"], bar["y"], BAR_W, BAR_H)
			if br.has_point(Vector2(p_bullet["x"], p_bullet["y"])):
				bar["hp"]          -= 2
				p_bullet["active"] = false
				break

	# Kollisjon: invader-skudd vs barrierer og spiller
	var kill_bullets : Array = []
	for b in i_bullets:
		var bpos := Vector2(b["x"], b["y"])
		# Barrierer
		var hit_bar := false
		for bar in barriers:
			if bar["hp"] <= 0: continue
			if Rect2(bar["x"], bar["y"], BAR_W, BAR_H).has_point(bpos):
				bar["hp"] -= 1
				hit_bar    = true
				break
		if hit_bar:
			kill_bullets.append(b)
			continue
		# Spiller
		var pr := Rect2(player_x - PLAYER_W / 2.0, PLAYER_Y, PLAYER_W, PLAYER_H)
		if pr.has_point(bpos):
			kill_bullets.append(b)
			lives -= 1
			_play(_snd_die)
			if lives <= 0:
				state = "gameover"
				_play(_snd_over)
			else:
				# Kort pause etter tap
				state = "dead"
				await get_tree().create_timer(1.0).timeout
				if state == "dead":
					state = "playing"
			break

	for b in kill_bullets:
		i_bullets.erase(b)

	# Invadere når bunnen
	for inv in invaders:
		if inv["alive"] and inv["y"] + INV_H >= PLAYER_Y:
			state = "gameover"
			_play(_snd_over)
			break

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
				"playing":
					if not p_bullet.get("active", false):
						p_bullet = {
							"x":      player_x,
							"y":      PLAYER_Y,
							"active": true,
						}
						_play(_snd_shoot)
				"gameover", "win":
					score = 0
					lives = 3
					wave  = 1
					_reset_wave()
					state = "playing"

# ── Tegning ──────────────────────────────────────────────────
func _draw() -> void:
	draw_rect(Rect2(0, 0, BW, BH), Color(0.0, 0.0, 0.05))
	draw_rect(Rect2(0, 0, BW, HUD_H), Color(0.0, 0.0, 0.0, 0.8))

	var fnt := ThemeDB.fallback_font
	draw_string(fnt, Vector2(10, 28),
		"SCORE: %d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.4, 1.0, 0.4))
	draw_string(fnt, Vector2(BW / 2.0, 28),
		"LIVES: %s" % "* ".repeat(lives).strip_edges(),
		HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color(1.0, 0.4, 0.4))
	draw_string(fnt, Vector2(BW - 10, 28),
		"WAVE %d" % wave, HORIZONTAL_ALIGNMENT_RIGHT, -1, 16, Color(0.5, 0.7, 1.0))

	# Gulvlinje
	draw_line(Vector2(0, PLAYER_Y + PLAYER_H + 8), Vector2(BW, PLAYER_Y + PLAYER_H + 8),
		Color(0.3, 1.0, 0.3, 0.5), 2.0)

	# Invaders
	for inv in invaders:
		if not inv["alive"]: continue
		var col : Color = ROW_COL[inv["row"]]
		_draw_invader(inv["x"], inv["y"], INV_W, INV_H, col, inv["row"])

	# Barrierer
	for bar in barriers:
		if bar["hp"] <= 0: continue
		var alpha := float(bar["hp"]) / float(BAR_HP)
		var col   := Color(0.2, 0.8, 0.2, alpha)
		draw_rect(Rect2(bar["x"], bar["y"], BAR_W, BAR_H), col)
		# Hullete tak
		if bar["hp"] < BAR_HP / 2:
			draw_rect(Rect2(bar["x"] + BAR_W * 0.3, bar["y"],
				BAR_W * 0.4, BAR_H * 0.4), Color(0.0, 0.0, 0.05))

	# Spiller
	_draw_ship(player_x, PLAYER_Y, PLAYER_W, PLAYER_H)

	# Spillerbullet
	if p_bullet.get("active", false):
		draw_rect(Rect2(p_bullet["x"] - BULLET_W / 2, p_bullet["y"],
			BULLET_W, BULLET_H), Color(1.0, 1.0, 0.5))

	# Invader-skudd
	for b in i_bullets:
		draw_rect(Rect2(b["x"] - BULLET_W / 2, b["y"], BULLET_W, BULLET_H),
			Color(1.0, 0.3, 0.3))

	# Meldinger
	match state:
		"ready":
			_draw_msg("TRYKK MELLOMROM FOR A STARTE", Color(1.0, 1.0, 0.4))
		"dead":
			_draw_msg("TREFF!  VENTER...", Color(1.0, 0.6, 0.2))
		"wave_clear":
			_draw_msg("BØLGE %d RYDDET! +200" % (wave - 1), Color(0.3, 1.0, 0.3))
		"gameover":
			_draw_msg("GAME OVER   SCORE: %d   MELLOMROM FOR NY" % score, Color(1.0, 0.3, 0.3))
		"win":
			_draw_msg("DU VANT!   SCORE: %d" % score, Color(0.3, 1.0, 0.3))

	draw_string(fnt, Vector2(BW / 2.0, BH - 6),
		"A/D eller piltaster = beveg   MELLOMROM = skyt   ESC = tilbake",
		HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.3, 0.5, 0.3))

func _draw_invader(x: float, y: float, w: float, h: float, col: Color, row: int) -> void:
	# Enkel piksel-lignende invader-form
	draw_rect(Rect2(x + w*0.1, y + h*0.1, w*0.8, h*0.55), col)
	# Antenner
	draw_rect(Rect2(x + w*0.15, y, w*0.12, h*0.18), col)
	draw_rect(Rect2(x + w*0.73, y, w*0.12, h*0.18), col)
	# Ben
	match row % 3:
		0:  # bredt
			draw_rect(Rect2(x,        y + h*0.65, w*0.22, h*0.32), col)
			draw_rect(Rect2(x + w*0.78, y + h*0.65, w*0.22, h*0.32), col)
		1:  # smalt
			draw_rect(Rect2(x + w*0.1, y + h*0.65, w*0.15, h*0.32), col)
			draw_rect(Rect2(x + w*0.75, y + h*0.65, w*0.15, h*0.32), col)
		2:
			draw_rect(Rect2(x + w*0.05, y + h*0.65, w*0.18, h*0.32), col)
			draw_rect(Rect2(x + w*0.77, y + h*0.65, w*0.18, h*0.32), col)
	# Øyne
	draw_rect(Rect2(x + w*0.22, y + h*0.2, w*0.16, h*0.22), Color(0.0, 0.0, 0.05))
	draw_rect(Rect2(x + w*0.62, y + h*0.2, w*0.16, h*0.22), Color(0.0, 0.0, 0.05))
	# Munn
	draw_rect(Rect2(x + w*0.28, y + h*0.5, w*0.44, h*0.08), Color(0.0, 0.0, 0.05))

func _draw_ship(cx: float, y: float, w: float, h: float) -> void:
	var col := Color(0.3, 0.85, 1.0)
	# Kropp
	draw_rect(Rect2(cx - w*0.5, y + h*0.35, w, h*0.65), col)
	# Kanon (midtstilt spiss)
	draw_rect(Rect2(cx - w*0.08, y, w*0.16, h*0.5), col)
	# Lys
	draw_rect(Rect2(cx - w*0.5, y + h*0.35, w, h*0.15),
		Color(0.6, 1.0, 1.0, 0.4))

func _draw_msg(text: String, color: Color) -> void:
	var fnt := ThemeDB.fallback_font
	draw_rect(Rect2(0, BH / 2.0 - 28, BW, 54), Color(0.0, 0.0, 0.0, 0.85))
	draw_string(fnt, Vector2(BW / 2.0, BH / 2.0 + 10),
		text, HORIZONTAL_ALIGNMENT_CENTER, -1, 20, color)

# ── Lyd ──────────────────────────────────────────────────────
func _make_tone(freq_start: float, freq_end: float, dur: float,
		vol: float = 0.6, wave: int = 0) -> AudioStreamWAV:
	var sr   := 22050
	var n    := int(sr * dur)
	var data := PackedByteArray()
	data.resize(n)
	var phase := 0.0
	for i in n:
		var t    := float(i) / float(n)
		var freq := lerpf(freq_start, freq_end, t)
		phase += TAU * freq / float(sr)
		var env := minf(t / maxf(0.01 / dur, 0.001), 1.0) * (1.0 - t) * vol
		var raw := 0.0
		match wave:
			0: raw = sin(phase)
			1: raw = 1.0 if sin(phase) >= 0.0 else -1.0
			2: raw = fmod(phase / TAU, 1.0) * 2.0 - 1.0
		data[i] = int(clamp(raw * env * 127.0 + 128.0, 0.0, 255.0))
	var s := AudioStreamWAV.new()
	s.format   = 0
	s.mix_rate = sr
	s.stereo   = false
	s.data     = data
	return s

func _make_seq(tones: Array) -> AudioStreamWAV:
	var sr   := 22050
	var full := PackedByteArray()
	for t in tones:
		full.append_array(_make_tone(t[0], t[1], t[2],
			t[3] if t.size() > 3 else 0.6,
			t[4] if t.size() > 4 else 0).data)
	var s := AudioStreamWAV.new()
	s.format   = 0
	s.mix_rate = sr
	s.stereo   = false
	s.data     = full
	return s

func _make_player(stream: AudioStreamWAV, vol_db: float = 0.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream    = stream
	p.volume_db = vol_db
	p.bus       = "Master"
	p.autoplay  = false
	add_child(p)
	return p

func _setup_audio() -> void:
	_snd_shoot = _make_player(_make_tone(880.0, 220.0, 0.10, 0.45, 1), -4.0)
	_snd_hit   = _make_player(_make_tone(600.0, 150.0, 0.12, 0.60, 2), -3.0)
	_snd_die   = _make_player(_make_tone(400.0,  60.0, 0.40, 0.70, 0), -2.0)
	_snd_over  = _make_player(_make_seq([
		[220.0, 220.0, 0.18, 0.6, 1],
		[165.0, 165.0, 0.18, 0.6, 1],
		[110.0,  50.0, 0.35, 0.7, 1],
	]), -1.0)
	_snd_win   = _make_player(_make_seq([
		[262.0, 262.0, 0.10, 0.5, 0],
		[330.0, 330.0, 0.10, 0.5, 0],
		[392.0, 392.0, 0.10, 0.5, 0],
		[524.0, 700.0, 0.25, 0.6, 0],
	]), -1.0)
	# March-lyd: fire vekslende toner
	var march_freqs := [160.0, 130.0, 110.0, 130.0]
	_snd_march = _make_player(_make_tone(
		march_freqs[0], march_freqs[0], 0.05, 0.25, 1), -8.0)

func _play(p: AudioStreamPlayer) -> void:
	if p == null: return
	p.stop()
	p.play()
