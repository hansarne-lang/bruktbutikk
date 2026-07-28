extends Node2D
## Void Miner – Overfart-scene
## Romskipet flyr i verdensrommet.
## Spilleren velger destinasjon: hjem eller Trader 1.

const SHIP_SPEED := 60.0   # piksler per sekund (sakte drift)

var _stars      : Array  = []
var _ship_x     : float  = -120.0
var _ship_y     : float  = 300.0
var _time       : float  = 0.0

@onready var btn_home   : Button = $UI/ButtonPanel/HomeButton
@onready var btn_trader : Button = $UI/ButtonPanel/TraderButton
@onready var cargo_lbl  : Label  = $UI/CargoLabel

func _ready() -> void:
	for i in 180:
		_stars.append({
			"x": randf() * 1280,
			"y": randf() * 590,
			"r": randf_range(0.5, 2.0),
			"a": randf_range(0.3, 1.0),
			"spd": randf_range(8.0, 32.0),  # parallax-fart
		})

	btn_home.pressed.connect(_go_home)
	btn_trader.pressed.connect(_go_trader)

	# Vis last
	var total := SaveManager.total_minerals()
	var tanks  := SaveManager.game_data.get("tanks", [])
	var lines  : PackedStringArray = []
	for t in tanks:
		var mid : String = t.get("mineral_id", "")
		var amt : int    = t.get("amount", 0)
		if mid != "" and amt > 0:
			var name := DataLoader.get_mineral(mid).get("name", mid)
			lines.append("  %s:  %d enheter" % [name, amt])
	if lines.is_empty():
		cargo_lbl.text = "Lasterom: tomt"
	else:
		cargo_lbl.text = "Lasterom:\n" + "\n".join(lines)

func _process(delta: float) -> void:
	_time  += delta
	_ship_x = _ship_x + SHIP_SPEED * delta
	if _ship_x > 1400:
		_ship_x = -120.0

	# Flytt stjerner (parallax scroll)
	for s in _stars:
		s["x"] -= s["spd"] * delta * 0.3
		if s["x"] < -4:
			s["x"] = 1284.0
			s["y"] = randf() * 590

	queue_redraw()

func _go_home() -> void:
	get_tree().change_scene_to_file("res://scenes/base/Base.tscn")

func _go_trader() -> void:
	# Sett kreditter basert paa last
	var tanks   : Array = SaveManager.game_data.get("tanks", [])
	var earned  : int   = 0
	for tank in tanks:
		var mid : String = tank.get("mineral_id", "")
		var amt : int    = tank.get("amount",     0)
		if mid == "" or amt == 0:
			continue
		var val : int = int(DataLoader.get_mineral(mid).get("base_value", 0))
		# Trader 1 gir 70% av baseverdi (trygg men lav profitt)
		earned += int(val * amt * 0.70)

	SaveManager.game_data["credits"] = \
		SaveManager.game_data.get("credits", 0) + earned
	SaveManager.game_data["trades_done"] = \
		SaveManager.game_data.get("trades_done", 0) + 1
	SaveManager.game_data["day"] = \
		SaveManager.game_data.get("day", 1) + 1
	SaveManager.empty_tanks()
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://scenes/base/Base.tscn")

# ── Tegning ──────────────────────────────────────────────────
func _draw() -> void:
	# Bakgrunn
	draw_rect(Rect2(0, 0, 1280, 590), Color(0.01, 0.01, 0.06))

	# Stjerner med parallax
	for s in _stars:
		draw_circle(Vector2(s["x"], s["y"]), s["r"], Color(1, 1, 1, s["a"]))

	# Fjern nebula-glow (pulserende)
	var pulse := (sin(_time * 0.4) + 1.0) * 0.5
	draw_circle(Vector2(980, 180), 120 + pulse * 12,
		Color(0.15, 0.08, 0.28, 0.18 + pulse * 0.05))
	draw_circle(Vector2(980, 180), 70 + pulse * 6,
		Color(0.20, 0.10, 0.35, 0.22))

	# Distant planet
	draw_circle(Vector2(200, 100), 55, Color(0.28, 0.22, 0.38))
	draw_circle(Vector2(200, 100), 55, Color(0.35, 0.28, 0.48, 0.5), false, 2.0)
	# Ring
	draw_line(Vector2(135, 118), Vector2(265, 82), Color(0.5, 0.4, 0.6, 0.6), 3.0)

	# Romskip
	_draw_ship(_ship_x, _ship_y)

	# Motor-glow
	var glow_a := 0.5 + sin(_time * 8.0) * 0.3
	draw_circle(Vector2(_ship_x - 60, _ship_y + 12),
		14.0 + sin(_time * 12) * 3, Color(0.4, 0.6, 1.0, glow_a * 0.7))
	draw_circle(Vector2(_ship_x - 60, _ship_y + 12),
		6.0, Color(0.8, 0.9, 1.0, glow_a))

func _draw_ship(cx: float, cy: float) -> void:
	var C_HULL := Color(0.55, 0.65, 0.75)
	var C_WIN  := Color(0.4,  0.7,  0.9,  0.8)
	var C_WING := Color(0.65, 0.72, 0.80)

	# Hoveskrog
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 60, cy + 10),
		Vector2(cx + 60, cy),
		Vector2(cx + 60, cy + 20),
		Vector2(cx - 60, cy + 28),
	]), C_HULL)

	# Nese
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx + 60, cy),
		Vector2(cx + 60, cy + 20),
		Vector2(cx + 90, cy + 10),
	]), C_WING)

	# Oevrevinge
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 10, cy),
		Vector2(cx + 20, cy),
		Vector2(cx + 10, cy - 26),
		Vector2(cx - 20, cy - 20),
	]), C_WING)

	# Undervinge
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 10, cy + 28),
		Vector2(cx + 20, cy + 28),
		Vector2(cx + 10, cy + 52),
		Vector2(cx - 20, cy + 46),
	]), C_WING)

	# Cockpit-vinduer
	draw_rect(Rect2(cx + 30, cy + 4, 22, 12), C_WIN)
	draw_rect(Rect2(cx + 33, cy + 5, 14, 6), Color(0.7, 0.9, 1.0, 0.5))

	# Dyse
	draw_rect(Rect2(cx - 68, cy + 8, 10, 14), Color(0.4, 0.5, 0.6))
