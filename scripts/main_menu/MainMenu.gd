extends Control

const MOON_NAMES := [
	"Luna-7 Mining Station", "Kepler Station", "Nyx-3 Outpost",
	"Astraea Base", "Helios Station", "Erebus Mining Camp",
	"Callisto-2 Hub", "Phaedra-9 Station", "Io Outpost", "Vega Base",
	"Selene Station", "Artemis Base", "Hyperion Camp", "Tethys-4",
]

@onready var new_game_button    : Button   = $VBoxContainer/NewGameButton
@onready var load_button        : Button   = $VBoxContainer/LoadButton
@onready var save_button        : Button   = $VBoxContainer/SaveButton
@onready var quit_button        : Button   = $VBoxContainer/QuitButton
@onready var test_button        : Button   = $VBoxContainer/TestButton
@onready var meteor_test_btn    : Button   = $VBoxContainer/MeteorstormTestBtn
@onready var pirate_test_btn    : Button   = $VBoxContainer/PirateTestBtn
@onready var end_game_btn       : Button   = $VBoxContainer/EndGameBtn
@onready var future_plans_btn   : Button   = $VBoxContainer/FuturePlansBtn
@onready var hiscore_label      : Label    = $HiscoreLabel
@onready var stars_node                    = $Stars
@onready var name_dialog                   = $NameDialog
@onready var name_edit          : LineEdit = $NameDialog/VBox/NameEdit
@onready var confirm_btn        : Button   = $NameDialog/VBox/HBox/ConfirmButton
@onready var cancel_btn         : Button   = $NameDialog/VBox/HBox/CancelButton

func _ensure_test_game() -> void:
	if not SaveManager.has_active_game():
		SaveManager.new_game()
		SaveManager.game_data["moon_name"] = "Testbase Alpha"
		# Gi noen torpedoer for testing
		var td : Dictionary = SaveManager.game_data.get("torpedoes", {})
		td["standard"]   = 5
		td["emp"]        = 3
		td["penetrator"] = 2
		td["nuke"]       = 1
		td["decoy"]      = 4
		SaveManager.game_data["torpedoes"] = td

func _ready() -> void:
	new_game_button.pressed.connect(_on_new_game_pressed)
	load_button.pressed.connect(_on_load_pressed)
	save_button.pressed.connect(_on_save_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	confirm_btn.pressed.connect(_on_confirm_name)
	cancel_btn.pressed.connect(func(): name_dialog.visible = false)
	test_button.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/tests/TestScene.tscn"))
	meteor_test_btn.pressed.connect(func() -> void:
		_ensure_test_game()
		get_tree().change_scene_to_file("res://scenes/meteor_storm/MeteorStorm.tscn"))
	pirate_test_btn.pressed.connect(func() -> void:
		_ensure_test_game()
		get_tree().change_scene_to_file("res://scenes/pirate_combat/PirateCombat.tscn"))
	end_game_btn.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/end_game/EndGame.tscn"))
	future_plans_btn.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/future_plans/FuturePlans.tscn"))
	save_button.disabled = not SaveManager.has_active_game()
	_draw_stars()
	_refresh_hiscore()
	var ver_lbl := $VersionLabel as Label
	ver_lbl.text = "v%s  –  Void Miner  ·  Oppdatert: %s" % [Version.VERSION, Version.BUILD_TIME]

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
	# Vis navne-dialog med tilfeldig forslag
	name_edit.text = MOON_NAMES[randi() % MOON_NAMES.size()]
	name_dialog.visible = true
	name_edit.grab_focus()
	name_edit.select_all()

func _on_confirm_name() -> void:
	var moon_name : String = name_edit.text.strip_edges()
	if moon_name == "":
		moon_name = "Luna-7 Mining Station"
	name_dialog.visible = false
	SaveManager.new_game()
	SaveManager.game_data["moon_name"] = moon_name
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

func _refresh_hiscore() -> void:
	var entries : Array = SaveManager.load_hiscore()
	if entries.is_empty():
		hiscore_label.text = "🏆  Hiscore\n(ingen oppføringer ennå)"
		return
	var lines : PackedStringArray = ["🏆  Hiscore – topp %d" % mini(entries.size(), 3)]
	for i : int in mini(entries.size(), 3):
		var e : Dictionary = entries[i]
		lines.append("%d.  %s  |  %d p  (dag %d,  %d kr)" % [
			i + 1,
			e.get("moon_name", "?"),
			e.get("score", 0),
			e.get("day", 0),
			e.get("credits", 0),
		])
	hiscore_label.text = "\n".join(lines)
