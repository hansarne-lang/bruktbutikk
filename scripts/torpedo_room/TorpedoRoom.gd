extends Node2D
## Void Miner – Torpedorom
## Kjøp og administrer ulike torpedotyper.

const TORPEDO_CATALOG := [
	{
		"id":   "standard",
		"name": "Standard",
		"desc": "Ignorerer halvt av piratskjoldet. Allsidig og pålitelig.",
		"col":  Color(0.55, 0.70, 0.95),
		"qty":  5,
		"cost": 400,
	},
	{
		"id":   "emp",
		"name": "EMP",
		"desc": "Elektromagnetisk puls. 2 skade + piraten mister neste angrep.",
		"col":  Color(0.35, 0.95, 0.60),
		"qty":  3,
		"cost": 700,
	},
	{
		"id":   "penetrator",
		"name": "Penetrator",
		"desc": "Gjennomtrenger alt skjold. 3 skade direkte på piratens HP.",
		"col":  Color(1.00, 0.55, 0.20),
		"qty":  3,
		"cost": 1100,
	},
	{
		"id":   "nuke",
		"name": "Nuke",
		"desc": "Massiv eksplosjon. 5 skade, ignorerer alt skjold. Svært kostbar.",
		"col":  Color(1.00, 0.25, 0.25),
		"qty":  1,
		"cost": 2800,
	},
	{
		"id":   "decoy",
		"name": "Lokkedekke",
		"desc": "Avleder piraten. Taper sin tur. Ingen skade på ditt skip denne runden.",
		"col":  Color(0.90, 0.85, 0.25),
		"qty":  4,
		"cost": 600,
	},
]

var _time         : float = 0.0
var _feedback_t   : float = 0.0
var _count_labels : Array = []

@onready var credits_lbl  : Label          = $UI/HUD/CreditsLabel
@onready var list_vbox    : VBoxContainer  = $UI/TorpedoList
@onready var feedback_lbl : Label          = $UI/FeedbackLabel

func _ready() -> void:
	$UI/HUD/BackButton.pressed.connect(_go_back)
	_build_list()
	_refresh_credits()

func _build_list() -> void:
	_count_labels.clear()
	for tt : Dictionary in TORPEDO_CATALOG:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)

		# Name
		var nm := Label.new()
		nm.custom_minimum_size = Vector2(140, 0)
		nm.add_theme_font_size_override("font_size", 18)
		nm.add_theme_color_override("font_color", tt["col"])
		nm.text = tt["name"]
		row.add_child(nm)

		# Current count
		var cnt := Label.new()
		cnt.custom_minimum_size = Vector2(75, 0)
		cnt.add_theme_font_size_override("font_size", 18)
		cnt.add_theme_color_override("font_color", Color(0.85, 0.90, 0.85))
		_count_labels.append(cnt)
		row.add_child(cnt)

		# Description
		var dsc := Label.new()
		dsc.custom_minimum_size = Vector2(480, 0)
		dsc.add_theme_font_size_override("font_size", 13)
		dsc.add_theme_color_override("font_color", Color(0.55, 0.62, 0.70))
		dsc.text = tt["desc"]
		row.add_child(dsc)

		# Cost label
		var cst := Label.new()
		cst.custom_minimum_size = Vector2(140, 0)
		cst.add_theme_font_size_override("font_size", 13)
		cst.add_theme_color_override("font_color", Color(0.70, 0.85, 0.50))
		cst.text = "%d kr / ×%d" % [tt["cost"], tt["qty"]]
		row.add_child(cst)

		# Buy button
		var btn := Button.new()
		btn.text = "Kjøp"
		btn.custom_minimum_size = Vector2(100, 38)
		var ttype : String = tt["id"]
		var qty   : int    = tt["qty"]
		var cost  : int    = tt["cost"]
		btn.pressed.connect(func(): _buy(ttype, qty, cost))
		row.add_child(btn)

		list_vbox.add_child(row)

	_refresh_counts()

func _refresh_counts() -> void:
	var td : Dictionary = SaveManager.game_data.get("torpedoes", {})
	for i : int in TORPEDO_CATALOG.size():
		var cnt : int = td.get(TORPEDO_CATALOG[i]["id"], 0)
		_count_labels[i].text = "×%d" % cnt

func _refresh_credits() -> void:
	credits_lbl.text = "%d kr" % SaveManager.game_data.get("credits", 0)

func _buy(ttype: String, qty: int, cost: int) -> void:
	if SaveManager.buy_torpedoes(ttype, qty, cost):
		_refresh_counts()
		_refresh_credits()
		_set_feedback("✅  Kjøpt %s ×%d" % [ttype, qty], Color(0.3, 1.0, 0.4))
	else:
		_set_feedback("❌  Ikke nok kreditter!", Color(1.0, 0.4, 0.3))

func _set_feedback(msg: String, col: Color) -> void:
	feedback_lbl.text = msg
	feedback_lbl.add_theme_color_override("font_color", col)
	feedback_lbl.visible = true
	_feedback_t = 2.5

func _go_back() -> void:
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://scenes/sprite_room/SpriteRoom.tscn")

func _process(delta: float) -> void:
	_time += delta
	if _feedback_t > 0.0:
		_feedback_t -= delta
		if _feedback_t <= 0.0:
			feedback_lbl.visible = false
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
