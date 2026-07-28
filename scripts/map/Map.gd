extends Node2D
## Void Miner – Kartscene
## Spilleren velger destinasjon foer overfart.

var _stars    : Array = []
var _time     : float = 0.0

# Handelsstasjoner
const TRADER1_POS := Vector2(980, 180)
const TRADER2_POS := Vector2(400, 130)
const TRADER3_POS := Vector2(700, 460)
const BASE_POS    := Vector2(160, 470)

func _ready() -> void:
	for _i in 160:
		_stars.append({
			"x": randf() * 1280,
			"y": randf() * 590,
			"r": randf_range(0.5, 2.0),
			"a": randf_range(0.2, 1.0),
		})

	$UI/Trader1Button.pressed.connect(func() -> void: _go_trader(1))
	$UI/Trader2Button.pressed.connect(func() -> void: _go_trader(2))
	$UI/Trader3Button.pressed.connect(func() -> void: _go_trader(3))
	$UI/BackButton.pressed.connect(_go_back)

	# Trader 3 låses opp fra dag 8
	var zones : int = SaveManager.game_data.get("zones_discovered", 1)
	var show3 : bool = zones >= 2
	$UI/Trader3Button.visible = show3
	$UI/Trader3Label.visible  = show3
	$UI/Trader3Sub.visible    = show3

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _go_trader(which: int) -> void:
	SaveManager.game_data["chosen_trader"] = which
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://scenes/travel/Travel.tscn")

func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/base/Base.tscn")

func _draw() -> void:
	# Bakgrunn
	draw_rect(Rect2(0, 0, 1280, 590), Color(0.02, 0.02, 0.10))

	# Stjerner
	for s in _stars:
		draw_circle(Vector2(s["x"], s["y"]), s["r"], Color(1, 1, 1, s["a"]))

	# Nebula
	var pulse : float = sin(_time * 0.5) * 0.5 + 0.5
	draw_circle(Vector2(640, 295), 220 + pulse * 15, Color(0.1, 0.05, 0.22, 0.12))
	draw_circle(Vector2(640, 295), 140 + pulse * 8,  Color(0.15, 0.06, 0.30, 0.10))

	# Rute-linjer
	var route_col := Color(0.3, 0.6, 1.0, 0.25)
	draw_line(BASE_POS, TRADER1_POS, route_col, 1.5)
	draw_line(BASE_POS, TRADER2_POS, route_col, 1.5)
	draw_line(TRADER1_POS, TRADER2_POS, Color(0.4, 0.4, 0.6, 0.15), 1.0)
	var zones : int = SaveManager.game_data.get("zones_discovered", 1)
	if zones >= 2:
		draw_line(BASE_POS, TRADER3_POS, Color(0.8, 0.3, 0.8, 0.30), 1.5)

	# Maaen (basen)
	draw_circle(BASE_POS, 40, Color(0.38, 0.36, 0.32))
	draw_circle(BASE_POS, 40, Color(0.5, 0.5, 0.5, 0.4), false, 2.0)
	draw_circle(BASE_POS + Vector2(-12, -8), 9, Color(0.28, 0.26, 0.24))
	draw_circle(BASE_POS + Vector2(14, 12),  6, Color(0.28, 0.26, 0.24))
	# Base-marker
	draw_circle(BASE_POS, 5, Color(0.5, 0.9, 0.5))

	# Trader 1 – stjerne/stasjon (rolig, blaa)
	_draw_station(TRADER1_POS, Color(0.4, 0.7, 1.0), pulse)

	# Trader 2 – stasjon (varmere, gul)
	_draw_station(TRADER2_POS, Color(1.0, 0.85, 0.3), pulse)

	# Trader 3 – Dypromstasjon (lilla, låst til dag 8)
	var zones2 : int = SaveManager.game_data.get("zones_discovered", 1)
	if zones2 >= 2:
		_draw_station(TRADER3_POS, Color(0.8, 0.3, 0.9), pulse)

	# Labels
	_draw_map_label(BASE_POS + Vector2(0, 55), "Luna-7  (din base)")
	_draw_map_label(TRADER1_POS + Vector2(0, 50), "Grom Korrec  –  70% pris")
	_draw_map_label(TRADER2_POS + Vector2(0, 50), "Zyla Station  –  90% pris")

func _draw_station(pos: Vector2, col: Color, pulse: float) -> void:
	# Glow
	draw_circle(pos, 28 + pulse * 6, Color(col.r, col.g, col.b, 0.12))
	# Stasjonskropp
	draw_circle(pos, 16, col.lerp(Color.WHITE, 0.3))
	draw_circle(pos, 10, col)
	# Solcellepaneler
	draw_rect(Rect2(pos.x - 32, pos.y - 3, 16, 6), col.lerp(Color.BLACK, 0.3))
	draw_rect(Rect2(pos.x + 16, pos.y - 3, 16, 6), col.lerp(Color.BLACK, 0.3))
	# Blinkende lys
	var blink : float = sin(_time * 3.0 + pos.x) * 0.5 + 0.5
	draw_circle(pos, 4, Color(1, 1, 1, blink))

func _draw_map_label(pos: Vector2, text: String) -> void:
	# Enkel label via draw_string er ikke tilgjengelig i Node2D direkte,
	# saateksten haandteres av Label-noder i UI-laget
	pass
