extends Node
## SaveManager – Autoload singleton
## Håndterer lagring og lasting av spilldata.

const SAVE_PATH = "user://save_game.json"

var game_data: Dictionary = {}

func has_active_game() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func new_game() -> void:
	game_data = {
		"day": 1,
		"money": 5000,
		"shop": {},
		"home": {},
		"player": {},
		"home_computer": false,   # C64 tatt med hjem fra butikken
		"home_items": []          # gjenstander sendt hjem
	}

func save_game() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(game_data))
	print("Spill lagret.")

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var result = JSON.parse_string(file.get_as_text())
	if result == null:
		return false
	game_data = result
	print("Spill lastet inn.")
	return true
