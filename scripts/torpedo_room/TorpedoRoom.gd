extends Node2D
## Void Miner – Torpedorom
## Viser nåværende torpedolager.
## Torpedoer bestilles hos trader og leveres neste dag.

const TORPEDO_CATALOG := [
	{"id": "standard",   "name": "Standard",    "col": Color(0.55, 0.70, 0.95),
	 "desc": "3 skade  ·  halvt skjold ignorert  ·  Allsidig og pålitelig."},
	{"id": "emp",        "name": "EMP",         "col": Color(0.35, 0.95, 0.60),
	 "desc": "2 skade  ·  piraten mister neste angrep."},
	{"id": "penetrator", "name": "Penetrator",  "col": Color(1.00, 0.55, 0.20),
	 "desc": "3 skade  ·  gjennomtrenger alt skjold."},
	{"id": "nuke",       "name": "Nuke",        "col": Color(1.00, 0.25, 0.25),
	 "desc": "5 skade  ·  ignorerer alt skjold  ·  Svært kostbar."},
	{"id": "decoy",      "name": "Lokkedekke",  "col": Color(0.90, 0.85, 0.25),
	 "desc": "Piraten mister sin tur  ·  ingen skade på ditt skip denne runden."},
]

var _time         : float = 0.0
var _count_labels : Array = []

@onready var list_vbox : VBoxContainer = $UI/TorpedoList

func _ready() -> void:
	$UI/HUD/BackButton.pressed.connect(_go_back)
	_build_list()

func _build_list() -> void:
	_count_labels.clear()
	for tt : Dictionary in TORPEDO_CATALOG:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)

		# Navn
		var nm := Label.new()
		nm.custom_minimum_size = Vector2(160, 0)
		nm.add_theme_font_size_override("font_size", 18)
		nm.add_theme_color_override("font_color", tt["col"])
		nm.text = tt["name"]
		row.add_child(nm)

		# Nåværende beholdning
		var cnt := Label.new()
		cnt.custom_minimum_size = Vector2(75, 0)
		cnt.add_theme_font_size_override("font_size", 18)
		cnt.add_theme_color_override("font_color", Color(0.85, 0.90, 0.85))
		_count_labels.append(cnt)
		row.add_child(cnt)

		# Beskrivelse
		var dsc := Label.new()
		dsc.custom_minimum_size = Vector2(600, 0)
		dsc.add_theme_font_size_override("font_size", 13)
		dsc.add_theme_color_override("font_color", Color(0.55, 0.62, 0.70))
		dsc.text = tt["desc"]
		row.add_child(dsc)

		list_vbox.add_child(row)

	# Info-linje nederst
	var info := Label.new()
	info.text = "📦  Bestill torpedoer hos trader  –  leveres neste dag"
	info.add_theme_font_size_override("font_size", 13)
	info.add_theme_color_override("font_color", Color(0.6, 0.7, 0.5, 0.8))
	list_vbox.add_child(info)

	_refresh_counts()

func _refresh_counts() -> void:
	var td : Dictionary = SaveManager.game_data.get("torpedoes", {})
	for i : int in TORPEDO_CATALOG.size():
		var cnt : int = td.get(TORPEDO_CATALOG[i]["id"], 0)
		_count_labels[i].text = "×%d" % cnt

func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/sprite_room/SpriteRoom.tscn")

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	# Room background
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.05, 0.06, 0.10))

	# Header bar
	draw_rect(Rect2(0, 0, 1280, 72), Color(0.08, 0.10, 0.17))
	draw_rect(Rect2(0, 70, 1280, 3), Color(0.25, 0.45, 0.80, 0.6))

	# Main content background
	draw_rect(Rect2(24, 88, 1232, 582), Color(0.07, 0.08, 0.13))
	draw_rect(Rect2(24, 88, 1232, 582), Color(0.15, 0.22, 0.35, 0.35), false, 2.0)

	# Torpedo rack visuals on the right side
	var rack_x : float = 1058.0
	for i : int in TORPEDO_CATALOG.size():
		var tt    : Dictionary = TORPEDO_CATALOG[i]
		var ry    : float      = 106.0 + i * 108.0
		var tc    : Color      = tt["col"]
		var cnt   : int        = SaveManager.game_data.get("torpedoes", {}).get(tt["id"], 0)

		# Rack frame
		draw_rect(Rect2(rack_x, ry, 190, 72), Color(0.09, 0.11, 0.17))
		draw_rect(Rect2(rack_x, ry, 190, 72), Color(tc.r, tc.g, tc.b, 0.28), false, 1.5)

		# Separator track
		draw_rect(Rect2(rack_x + 4, ry + 34, 182, 2), Color(tc.r, tc.g, tc.b, 0.15))

		# Torpedo silhouettes (up to 6)
		var show_n : int = min(cnt, 6)
		for j : int in show_n:
			var tx : float = rack_x + 8.0 + j * 29.0
			var ty : float = ry + 10.0
			# Body
			draw_rect(Rect2(tx, ty, 22, 12), Color(tc.r * 0.55, tc.g * 0.55, tc.b * 0.55))
			# Nose cone
			draw_colored_polygon(PackedVector2Array([
				Vector2(tx + 22, ty + 1),
				Vector2(tx + 22, ty + 11),
				Vector2(tx + 32, ty + 6),
			]), tc)
			# Warhead glow
			draw_rect(Rect2(tx, ty + 4, 5, 4), Color(tc.r, tc.g, tc.b, 0.90))
			# Tail fins
			draw_colored_polygon(PackedVector2Array([
				Vector2(tx, ty), Vector2(tx - 5, ty - 4), Vector2(tx - 5, ty + 4),
			]), Color(tc.r * 0.4, tc.g * 0.4, tc.b * 0.4))

		# Pulse glow on rack edge when cnt > 0
		if cnt > 0:
			var pulse : float = (sin(_time * 2.0 + i * 1.3) + 1.0) * 0.5
			draw_rect(Rect2(rack_x, ry, 3, 72),
				Color(tc.r, tc.g, tc.b, 0.15 + pulse * 0.25))

		# Empty rack: cross-hatch
		if cnt == 0:
			draw_line(Vector2(rack_x + 4, ry + 4), Vector2(rack_x + 186, ry + 68),
				Color(0.22, 0.10, 0.10, 0.45), 1.5)
			draw_line(Vector2(rack_x + 186, ry + 4), Vector2(rack_x + 4, ry + 68),
				Color(0.22, 0.10, 0.10, 0.45), 1.5)

	# Floor strip
	draw_rect(Rect2(0, 656, 1280, 64), Color(0.07, 0.09, 0.13))
	for gx : int in range(0, 1281, 80):
		draw_line(Vector2(gx, 656), Vector2(gx, 720),
			Color(0.12, 0.16, 0.22, 0.7), 1.0)
	draw_rect(Rect2(0, 654, 1280, 4), Color(0.25, 0.45, 0.80, 0.28))
