extends Node2D
## Void Miner – Meteorstorm mini-spill
## Spilleren styrer skipet gjennom et tett meteorbeltet.
## Overlev 22 sekunder → bonuskreditter.
## 3 treff → skjoldet skades, men spillet fortsetter til trader.

const SHIP_SPEED    := 290.0
const SURVIVE_TIME  := 22.0
const MAX_LIVES     := 3
const SPAWN_BASE    := 0.70    # startintervall mellom meteorer (s)
const SPAWN_MIN     := 0.22    # tetteste intervall mot slutten

var _ship       : Vector2 = Vector2(240.0, 330.0)
var _time       : float   = 0.0
var _countdown  : float   = SURVIVE_TIME
var _lives      : int     = MAX_LIVES
var _invinc     : float   = 0.0    # sekunder uovervinnelig
var _spawn_t    : float   = 0.0
var _meteors    : Array   = []     # {x,y,vx,vy,r,rot,rot_spd,offsets}
var _stars      : Array   = []
var _explosions : Array   = []     # {x,y,r,life}
var _over       : bool    = false
var _won        : bool    = false

@onready var timer_lbl    : Label  = $UI/HUD/TimerLabel
@onready var lives_lbl    : Label  = $UI/HUD/LivesLabel
@onready var result_panel           = $UI/ResultPanel
@onready var result_title : Label  = $UI/ResultPanel/VBox/TitleLabel
@onready var result_msg   : Label  = $UI/ResultPanel/VBox/MessageLabel
@onready var cont_btn     : Button = $UI/ResultPanel/VBox/ContinueBtn

func _ready() -> void:
	for _i in 220:
		_stars.append({
			"x":   randf() * 1280,
			"y":   randf() * 720,
			"r":   randf_range(0.5, 2.0),
			"a":   randf_range(0.3, 1.0),
			"spd": randf_range(50.0, 140.0),
		})
	cont_btn.pressed.connect(_continue_game)

func _process(delta: float) -> void:
	if _over:
		return

	_time      += delta
	_countdown -= delta
	_invinc    -= delta
	_spawn_t   -= delta

	# ── Bevegelse ────────────────────────────────────────────────
	var dir : Vector2 = Vector2.ZERO
	if Input.is_action_pressed("ui_up")    or Input.is_key_pressed(KEY_W): dir.y = -1.0
	if Input.is_action_pressed("ui_down")  or Input.is_key_pressed(KEY_S): dir.y =  1.0
	if Input.is_action_pressed("ui_left")  or Input.is_key_pressed(KEY_A): dir.x = -0.6
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D): dir.x =  0.6
	if dir.length() > 0.01:
		dir = dir.normalized()
	_ship.x = clamp(_ship.x + dir.x * SHIP_SPEED * delta, 60.0, 720.0)
	_ship.y = clamp(_ship.y + dir.y * SHIP_SPEED * delta, 40.0, 650.0)

	# ── Stjerner ──────────────────────────────────────────────────
	for s in _stars:
		s["x"] -= s["spd"] * delta
		if s["x"] < -4.0:
			s["x"] = 1284.0
			s["y"] = randf() * 720.0

	# ── Spawn meteorer ────────────────────────────────────────────
	if _spawn_t <= 0.0:
		var progress : float = 1.0 - _countdown / SURVIVE_TIME
		_spawn_t = lerpf(SPAWN_BASE, SPAWN_MIN, progress)
		_spawn_meteor()
		# Mot slutten: noen doble-spawner
		if progress > 0.55 and randf() < 0.35:
			_spawn_meteor()

	# ── Flytt meteorer ────────────────────────────────────────────
	for m in _meteors:
		m["x"]   += m["vx"]  * delta
		m["y"]   += m["vy"]  * delta
		m["rot"] += m["rot_spd"] * delta

	# Fjern meteorer utenfor skjerm
	var keep_m : Array = []
	for m in _meteors:
		if m["x"] > -100.0 and m["y"] > -100.0 and m["y"] < 820.0:
			keep_m.append(m)
	_meteors = keep_m

	# ── Kollisjon ────────────────────────────────────────────────
	if _invinc <= 0.0:
		var sc : Vector2 = Vector2(_ship.x + 10.0, _ship.y + 14.0)
		for m in _meteors:
			var mc : Vector2 = Vector2(m["x"], m["y"])
			if sc.distance_to(mc) < 22.0 + m["r"] * 0.65:
				_hit()
				break

	# ── Eksplosjoner ──────────────────────────────────────────────
	var keep_e : Array = []
	for e in _explosions:
		e["life"] -= delta * 2.2
		if e["life"] > 0.0:
			keep_e.append(e)
	_explosions = keep_e

	# ── HUD ──────────────────────────────────────────────────────
	timer_lbl.text = "Tid igjen: %.1f s" % maxf(_countdown, 0.0)
	var sh_str : String = ""
	for i in MAX_LIVES:
		sh_str += ("■" if i < _lives else "□")
	lives_lbl.text = "Skjold: " + sh_str

	# ── Slutt-sjekk ───────────────────────────────────────────────
	if _countdown <= 0.0:
		_end_game(true)

	queue_redraw()

func _spawn_meteor() -> void:
	var r       : float = randf_range(12.0, 36.0)
	var y_start : float = randf_range(30.0, 690.0)
	var spd     : float = randf_range(170.0, 400.0)
	var drift   : float = randf_range(-70.0, 70.0)
	var offsets : Array = []
	for i in 9:
		offsets.append(randf_range(0.72, 1.0))
	_meteors.append({
		"x":       1330.0,
		"y":       y_start,
		"vx":      -spd,
		"vy":      drift,
		"r":       r,
		"rot":     randf() * TAU,
		"rot_spd": randf_range(-2.5, 2.5),
		"offsets": offsets,
	})

func _hit() -> void:
	_lives  -= 1
	_invinc  = 1.8
	_explosions.append({
		"x":    _ship.x + 10.0,
		"y":    _ship.y + 14.0,
		"r":    44.0,
		"life": 1.0,
	})
	SoundManager.play("drill_tick", -1.0)
	if _lives <= 0:
		_end_game(false)

func _end_game(won: bool) -> void:
	_over = true
	_won  = won

	if won:
		var bonus : int = 350
		SaveManager.game_data["credits"] = SaveManager.game_data.get("credits", 0) + bonus
		result_title.text = "✅  Igjennom meteorfeltet!"
		result_msg.text   = (
			"Fremragende navigering! Skipet er uskadet.\n+%d kreditter i bonusbelønning." % bonus)
	else:
		# Skader skjold-komponenten
		var comps : Array = SaveManager.game_data.get("ship_components", [])
		for c in comps:
			if c.get("id", "") == "shield":
				c["condition"] = max(0, c.get("condition", 100) - 38)
				break
		result_title.text = "💥  Fikk juling av meteorene!"
		result_msg.text   = (
			"Skipet tok tre treff. Skjoldet er skadet – reparer det i Motorrommet.")

	result_panel.visible = true

func _continue_game() -> void:
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://scenes/trader_office/TraderOffice.tscn")

# ══════════════════════════════════════════════════════════════
# TEGNING
# ══════════════════════════════════════════════════════════════
func _draw() -> void:
	# Bakgrunn
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.01, 0.01, 0.06))

	# Stjerner
	for s in _stars:
		draw_circle(Vector2(s["x"], s["y"]), s["r"], Color(1.0, 1.0, 1.0, s["a"]))

	# Planetglød i bakgrunnen
	var pulse : float = (sin(_time * 0.5) + 1.0) * 0.5
	draw_circle(Vector2(1100, 260), 95 + pulse * 10,
		Color(0.10, 0.06, 0.20, 0.14 + pulse * 0.05))
	draw_circle(Vector2(1100, 260), 58 + pulse * 5,
		Color(0.18, 0.08, 0.30, 0.22))
	draw_circle(Vector2(1100, 260), 32,
		Color(0.25, 0.12, 0.40, 0.35))

	# Fare-overlay ved ett liv igjen
	if _lives == 1:
		var warn : float = (sin(_time * 5.0) + 1.0) * 0.5
		draw_rect(Rect2(0, 0, 1280, 720), Color(1.0, 0.08, 0.05, 0.04 + warn * 0.05))

	# Overlevelse-bar øverst
	var pct : float = 1.0 - clampf(_countdown / SURVIVE_TIME, 0.0, 1.0)
	draw_rect(Rect2(50, 4, 1180, 12), Color(0.08, 0.08, 0.12))
	var bar_col : Color = Color(0.2, 1.0, 0.4).lerp(Color(1.0, 0.6, 0.1), pct)
	draw_rect(Rect2(50, 4, 1180.0 * pct, 12), bar_col)
	draw_rect(Rect2(50, 4, 1180, 12), Color(0.3, 0.4, 0.5, 0.5), false, 1.0)

	# Meteorer
	for m in _meteors:
		var mc  : Vector2 = Vector2(m["x"], m["y"])
		var mr  : float   = m["r"]
		var rot : float   = m["rot"]

		# Rock-form (uregelmessig polygon)
		draw_set_transform(mc, rot)
		var pts9 : PackedVector2Array = PackedVector2Array()
		for i in 9:
			var a  : float = i * TAU / 9.0
			var rr : float = mr * m["offsets"][i]
			pts9.append(Vector2(cos(a) * rr, sin(a) * rr))
		draw_colored_polygon(pts9, Color(0.28, 0.24, 0.22))
		# Kant
		var outline9 : PackedVector2Array = pts9.duplicate()
		outline9.append(pts9[0])
		draw_polyline(outline9, Color(0.48, 0.42, 0.38), 1.5)
		# Lysglimt
		var highlight_pt : Vector2 = pts9[0] * 0.5
		draw_circle(highlight_pt, mr * 0.18, Color(0.70, 0.65, 0.60, 0.25))
		draw_set_transform(Vector2.ZERO, 0.0)

		# Støvhale
		draw_circle(mc, mr * 1.35, Color(0.55, 0.48, 0.40, 0.07))

	# Eksplosjoner
	for e in _explosions:
		var ec : Vector2 = Vector2(e["x"], e["y"])
		var el : float   = e["life"]
		draw_circle(ec, e["r"] * (2.0 - el), Color(1.0, 0.55, 0.1, el * 0.45))
		draw_circle(ec, e["r"] * (1.4 - el * 0.5), Color(1.0, 0.85, 0.3, el * 0.65))
		draw_circle(ec, e["r"] * 0.4, Color(1.0, 1.0, 0.8, el * 0.80))

	# Skip (blinker ved uovervinnelig)
	var skip_draw : bool = not (_invinc > 0.0 and int(_time * 10.0) % 2 == 0)
	if skip_draw:
		_draw_ship(_ship.x, _ship.y)
		# Motorglow
		var ga : float = 0.5 + sin(_time * 10.0) * 0.3
		draw_circle(Vector2(_ship.x - 60, _ship.y + 12),
			13.0 + sin(_time * 12) * 3, Color(0.4, 0.6, 1.0, ga * 0.7))
		draw_circle(Vector2(_ship.x - 60, _ship.y + 12),
			5.5, Color(0.8, 0.9, 1.0, ga))

func _draw_ship(cx: float, cy: float) -> void:
	var C_HULL := Color(0.55, 0.65, 0.75)
	var C_WIN  := Color(0.4,  0.7,  0.9, 0.8)
	var C_WING := Color(0.65, 0.72, 0.80)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 60, cy + 10), Vector2(cx + 60, cy),
		Vector2(cx + 60, cy + 20), Vector2(cx - 60, cy + 28),
	]), C_HULL)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx + 60, cy), Vector2(cx + 60, cy + 20), Vector2(cx + 90, cy + 10),
	]), C_WING)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 10, cy),      Vector2(cx + 20, cy),
		Vector2(cx + 10, cy - 26), Vector2(cx - 20, cy - 20),
	]), C_WING)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 10, cy + 28), Vector2(cx + 20, cy + 28),
		Vector2(cx + 10, cy + 52), Vector2(cx - 20, cy + 46),
	]), C_WING)
	draw_rect(Rect2(cx + 30, cy + 4, 22, 12), C_WIN)
	draw_rect(Rect2(cx + 33, cy + 5, 14,  6), Color(0.7, 0.9, 1.0, 0.5))
	draw_rect(Rect2(cx - 68, cy + 8, 10, 14), Color(0.4, 0.5, 0.6))
