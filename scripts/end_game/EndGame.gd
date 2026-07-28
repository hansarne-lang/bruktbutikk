extends Node2D
## Void Miner – Endgame-scene
## TBD – kommer i fremtidig oppdatering.

var _time : float = 0.0

func _ready() -> void:
	$UI/BackButton.pressed.connect(_go_back)

func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	# Bakgrunn
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.03, 0.02, 0.08))

	# Stjerner
	for i in 120:
		var sf : float = float(i) * 17.391
		var sx : float = fmod(sf * 109.3, 1280.0)
		var sy : float = fmod(sf * 233.7, 720.0)
		var sa : float = fmod(sf * 0.071, 0.6) + 0.2
		draw_circle(Vector2(sx, sy), fmod(sf * 0.011, 1.3) + 0.4, Color(1, 1, 1, sa))

	# Pulserende glow i sentrum
	var pulse : float = sin(_time * 0.8) * 0.5 + 0.5
	draw_circle(Vector2(640, 280), 180 + pulse * 20, Color(0.4, 0.1, 0.6, 0.10 + pulse * 0.05))
	draw_circle(Vector2(640, 280), 90  + pulse * 10, Color(0.5, 0.15, 0.75, 0.13))

	# TBD-tekst (stor)
	var font : Font = ThemeDB.fallback_font
	draw_string(font, Vector2(640, 260), "TBD",
		HORIZONTAL_ALIGNMENT_CENTER, 1280, 72, Color(0.7, 0.4, 1.0, 0.85 + pulse * 0.15))
	draw_string(font, Vector2(640, 320), "Endgame – kommer snart",
		HORIZONTAL_ALIGNMENT_CENTER, 1280, 20, Color(0.55, 0.35, 0.75, 0.65))
	draw_string(font, Vector2(640, 360), "Du har utforsket Void Miner – fremtidens epilog venter her.",
		HORIZONTAL_ALIGNMENT_CENTER, 1280, 14, Color(0.4, 0.3, 0.55, 0.55))
