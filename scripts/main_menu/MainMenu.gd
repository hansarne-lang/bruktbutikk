extends Control

@onready var new_game_button : Button = $VBoxContainer/NewGameButton
@onready var load_button     : Button = $VBoxContainer/LoadButton
@onready var save_button     : Button = $VBoxContainer/SaveButton
@onready var quit_button     : Button = $VBoxContainer/QuitButton
@onready var stars_node              = $Stars

func _ready() -> void:
	new_game_button.pressed.connect(_on_new_game_pressed)
	load_button.pressed.connect(_on_load_pressed)
	save_button.pressed.connect(_on_save_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	save_button.disabled = not SaveManager.has_active_game()
	_draw_stars()

func _draw_stars() -> void:
	# Tegn stjernefeltet som smaae ColorRects paa Stars-noden
	for i in 120:
		var rect := ColorRect.new()
		var sz   := 1 + randi() % 2
		rect.size             = Vector2(sz, sz)
		rect.position         = Vector2(randf() * 1280, randf() * 720)
		rect.color            = Color(1, 1, 1, randf_range(0.3, 0.9))
		stars_node.add_child(rect)

func _on_new_game_pressed() -> void:
	SaveManager.new_game()
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://scenes/base/Base.tscn")

func _on_load_pressed() -> void:
	if SaveManager.load_game():
		get_tree().change_scene_to_file("res://scenes/base/Base.tscn")
	else:
		load_button.text = "Ingen lagret spill!"
		await get_tree().create_timer(2.0).timeout
		load_button.text = "Last inn"

func _on_save_pressed() -> void:
	SaveManager.save_game()
	save_button.text = "Lagret!"
	await get_tree().create_timer(1.5).timeout
	save_button.text = "Lagre"

func _on_quit_pressed() -> void:
	get_tree().quit()
