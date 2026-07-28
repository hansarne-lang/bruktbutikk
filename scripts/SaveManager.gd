extends Node
## SaveManager – Autoload singleton
## Haandterer lagring og lasting av spilldata for Void Miner.

const SAVE_PATH = "user://save_game.json"

var game_data: Dictionary = {}

func has_active_game() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func new_game() -> void:
	game_data = {
		"day":             1,
		"credits":         1200,
		"base_level":      1,
		"ship_level":      1,
		"location":        "base",
		"tanks": [
			{"mineral_id": "", "amount": 0, "capacity": 50},
			{"mineral_id": "", "amount": 0, "capacity": 50},
		],
		"mined_total":     0,
		"trades_done":     0,
		# Oppgraderinger
		"drill_upgraded":  false,
		"extra_tank":      false,
		"bigger_tanks":    false,
		# Dag/natt
		"time_of_day":     0.0,
		# Handler
		"last_earned":     0,
		"last_trader":     "",
		"chosen_trader":   1,
		"trade_log":       [],
		# Stasjonsnavn
		"moon_name":       "Luna-7 Mining Station",
	}

func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: Kunne ikke åpne fil for skriving")
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
	if not game_data.has("day"):            game_data["day"]            = 1
	if not game_data.has("credits"):        game_data["credits"]        = 1200
	if not game_data.has("base_level"):     game_data["base_level"]     = 1
	if not game_data.has("ship_level"):     game_data["ship_level"]     = 1
	if not game_data.has("location"):       game_data["location"]       = "base"
	if not game_data.has("tanks"):          game_data["tanks"]          = [
		{"mineral_id": "", "amount": 0, "capacity": 50},
		{"mineral_id": "", "amount": 0, "capacity": 50},
	]
	if not game_data.has("mined_total"):    game_data["mined_total"]    = 0
	if not game_data.has("trades_done"):    game_data["trades_done"]    = 0
	if not game_data.has("drill_upgraded"): game_data["drill_upgraded"] = false
	if not game_data.has("extra_tank"):     game_data["extra_tank"]     = false
	if not game_data.has("bigger_tanks"):   game_data["bigger_tanks"]   = false
	if not game_data.has("time_of_day"):    game_data["time_of_day"]    = 0.0
	if not game_data.has("last_earned"):    game_data["last_earned"]    = 0
	if not game_data.has("last_trader"):    game_data["last_trader"]    = ""
	if not game_data.has("chosen_trader"):  game_data["chosen_trader"]  = 1
	if not game_data.has("trade_log"):      game_data["trade_log"]      = []
	if not game_data.has("moon_name"):      game_data["moon_name"]      = "Luna-7 Mining Station"
	return true

## Beregn totalt antall enheter i alle tanker
func total_minerals() -> int:
	var total := 0
	for tank in game_data.get("tanks", []):
		total += tank.get("amount", 0)
	return total

## Legg til mineral i foerste ledige tank
func add_mineral(mineral_id: String, amount: int = 1) -> bool:
	var tanks : Array = game_data.get("tanks", [])
	for tank in tanks:
		if tank["mineral_id"] == mineral_id:
			if tank["amount"] < tank["capacity"]:
				tank["amount"] += amount
				game_data["mined_total"] += amount
				return true
	for tank in tanks:
		if tank["mineral_id"] == "" and tank["amount"] == 0:
			tank["mineral_id"] = mineral_id
			tank["amount"]     = amount
			game_data["mined_total"] += amount
			return true
	return false

## Toem alle tanker (etter salg)
func empty_tanks() -> void:
	for tank in game_data.get("tanks", []):
		tank["mineral_id"] = ""
		tank["amount"]     = 0

## Legg til logginnslag
func add_trade_log(earned: int, trader: String) -> void:
	var log_arr : Array = game_data.get("trade_log", [])
	log_arr.append({
		"day":    game_data.get("day", 1),
		"earned": earned,
		"trader": trader,
	})
	# Behold maks 50 innslag
	if log_arr.size() > 50:
		log_arr = log_arr.slice(log_arr.size() - 50)
	game_data["trade_log"] = log_arr
