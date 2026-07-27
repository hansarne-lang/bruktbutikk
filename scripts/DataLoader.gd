extends Node
## DataLoader – Autoload singleton
## Leser inn spilldata fra CSV-filer eksportert fra regnearket (game_data.xlsx).
## Legg til nye items/rom/karakterer i regnearket og eksporter som CSV.

var items: Dictionary = {}
var rooms: Dictionary = {}
var characters: Dictionary = {}
var settings: Dictionary = {}
var sets: Dictionary = {}

func _ready() -> void:
	load_all()

func load_all() -> void:
	items      = _load_csv("res://data/items.csv",      "id")
	rooms      = _load_csv("res://data/rooms.csv",      "id")
	characters = _load_csv("res://data/characters.csv", "id")
	settings   = _load_csv("res://data/settings.csv",   "key")
	sets       = _load_csv("res://data/sets.csv",       "id")

func _load_csv(path: String, key_column: String) -> Dictionary:
	var result: Dictionary = {}
	if not FileAccess.file_exists(path):
		push_warning("DataLoader: Fant ikke filen %s" % path)
		return result
	var file = FileAccess.open(path, FileAccess.READ)
	var headers: Array = file.get_csv_line()
	while not file.eof_reached():
		var line = file.get_csv_line()
		if line.size() < headers.size():
			continue
		var entry: Dictionary = {}
		for i in headers.size():
			entry[headers[i]] = line[i]
		var key = entry.get(key_column, "")
		if key != "":
			result[key] = entry
	return result
