extends Control

# Referanser til knapper
@onready var new_game_button: Button = $VBoxContainer/NewGameButton
@onready var load_button: Button = $VBoxContainer/LoadButton
@onready var save_button: Button = $VBoxContainer/SaveButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

func _ready() -> void:
	# Koble til signaler
	new_game_button.pressed.connect(_on_new_game_pressed)
	load_button.pressed.connect(_on_load_pressed)
	save_button.pressed.connect(_on_save_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Lagre-knapp er grå til et spill er aktivt
	save_button.disabled = not SaveManager.has_active_game()

func _on_new_game_pressed() -> void:
	SaveManager.new_game()
	get_tree().change_scene_to_file("res://scenes/shop/Shop.tscn")

func _on_load_pressed() -> void:
	# TODO: Åpne last inn-dialog
	pass

func _on_save_pressed() -> void:
	SaveManager.save_game()

func _on_settings_pressed() -> void:
	# TODO: Åpne innstillinger
	pass

func _on_quit_pressed() -> void:
	get_tree().quit()
