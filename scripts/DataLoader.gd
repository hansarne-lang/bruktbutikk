extends Node
## DataLoader – Autoload singleton
## Laster inn spilldata fra CSV-filer.

var minerals: Dictionary = {}   # id -> {name, category, description, base_value, rarity, color}

func _ready() -> void:
	_load_csv("res://data/minerals.csv", minerals)
	print("DataLoader: %d mineraler lastet" % minerals.size())

func _load_csv(path: String, target: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DataLoader: Fant ikke %s" % path)
		return
	var headers : PackedStringArray = file.get_csv_line()
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < headers.size() or row[0].strip_edges() == "":
			continue
		var entry : Dictionary = {}
		for i in headers.size():
			entry[headers[i].strip_edges()] = row[i].strip_edges()
		target[row[0].strip_edges()] = entry
	file.close()

## Hent mineraldata, eller tom dictionary om ikke funnet
func get_mineral(id: String) -> Dictionary:
	return minerals.get(id, {})

## Tilfeldig mineral basert paa sjeldenhet og dag (laas opp gradvis)
func random_mineral() -> String:
	if minerals.is_empty():
		return ""
	var day : int = SaveManager.game_data.get("day", 1)
	# Sjeldenheter laases opp etter dag
	var unlock_day := {
		"common":    1,
		"uncommon":  3,
		"rare":      7,
		"very_rare": 14,
		"legendary": 25,
	}
	var weights := {
		"common":    60,
		"uncommon":  25,
		"rare":      12,
		"very_rare":  2,
		"legendary":  1,
	}
	var pool : Array = []
	for id in minerals:
		var rarity    : String = minerals[id].get("rarity", "common")
		var min_day   : int    = unlock_day.get(rarity, 1)
		if day < min_day:
			continue  # Ikke laast opp enda
		var w : int = weights.get(rarity, 10)
		for _i in w:
			pool.append(id)
	if pool.is_empty():
		# Fallback: bare common
		for id in minerals:
			if minerals[id].get("rarity", "common") == "common":
				pool.append(id)
	if pool.is_empty():
		return minerals.keys()[0]
	return pool[randi() % pool.size()]

## Sjekk om et mineral er laast opp
func is_mineral_unlocked(id: String) -> bool:
	var day : int = SaveManager.game_data.get("day", 1)
	var unlock_day := {"common": 1, "uncommon": 3, "rare": 7, "very_rare": 14, "legendary": 25}
	var rarity : String = minerals.get(id, {}).get("rarity", "common")
	return day >= unlock_day.get(rarity, 1)
