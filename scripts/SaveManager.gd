extends Node
## SaveManager – Autoload singleton
## Haandterer lagring og lasting av spilldata for Void Miner.

const SAVE_PATH = "user://save_game.json"

var game_data: Dictionary = {}

func has_active_game() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func new_game() -> void:
	game_data = {
		"day":         1,
		"credits":     1200,
		"base_level":  1,
		"ship_level":  1,
		"location":    "base",
		"tanks": [
			{"mineral_id": "", "amount": 0, "capacity": 50},
			{"mineral_id": "", "amount": 0, "capacity": 50},
		],
		"mined_total": 0,
		"trades_done": 0,
	}

func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: Kunne ikke aapne fil for skriving")
		return
	file.store_string(JSON.stringify(game_data, "\t"))
	file.close()

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var result = JSON.parse_string(file.get_as_text())
	file.close()
	if result == null or not result is Dictionary:
		return false
	game_data = result
	# Migrasjon – fyll inn manglende felt
	if not game_data.has("day"):         game_data["day"]         = 1
	if not game_data.has("credits"):     game_data["credits"]     = 1200
	if not game_data.has("base_level"):  game_data["base_level"]  = 1
	if not game_data.has("ship_level"):  game_data["ship_level"]  = 1
	if not game_data.has("location"):    game_data["location"]    = "base"
	if not game_data.has("tanks"):       game_data["tanks"]       = [
		{"mineral_id": "", "amount": 0, "capacity": 50},
		{"mineral_id": "", "amount": 0, "capacity": 50},
	]
	if not game_data.has("mined_total"): game_data["mined_total"] = 0
	if not game_data.has("trades_done"): game_data["trades_done"] = 0
	return true

## Beregn totalt antall enheter i alle tanker
func total_minerals() -> int:
	var total := 0
	for tank in game_data.get("tanks", []):
		total += tank.get("amount", 0)
	return total

## Legg til mineral i foerste ledige tank
## Returnerer true hvis det ble lagt til
func add_mineral(mineral_id: String, amount: int = 1) -> bool:
	var tanks : Array = game_data.get("tanks", [])
	# Foerst: finn tank som allerede inneholder dette mineralet
	for tank in tanks:
		if tank["mineral_id"] == mineral_id:
			if tank["amount"] < tank["capacity"]:
				tank["amount"] += amount
				game_data["mined_total"] += amount
				return true
	# Saa: finn tom tank
	for tank in tanks:
		if tank["mineral_id"] == "" and tank["amount"] == 0:
			tank["mineral_id"] = mineral_id
			tank["amount"]     = amount
			game_data["mined_total"] += amount
			return true
	return false   # alle tanker fulle

## Toem alle tanker (etter salg)
func empty_tanks() -> void:
	for tank in game_data.get("tanks", []):
		tank["mineral_id"] = ""
		tank["amount"]     = 0
