extends Node2D
## Void Miner – Maanebase-scene
## Spilleren ser basen fra siden: maaneoverflate, tanker, skip og dome.

const MINE_INTERVAL := 4.0      # sekunder mellom hvert automatisk mining-steg
const MINE_AMT      := 1        # enheter per steg

@onready var hud_day_lbl    : Label = $UI/HUD/DayLabel
@onready var hud_cred_lbl   : Label = $UI/HUD/CreditsLabel
@onready var hud_mine_lbl   : Label = $UI/HUD/MiningLabel
@onready var tank_panel              = $UI/TankPanel
@onready var tank_list               = $UI/TankPanel/TankVBox/TankList
@onready var info_panel              = $UI/InfoPanel
@onready var info_text      : Label = $UI/InfoPanel/InfoText
@onready var status_lbl     : Label = $UI/StatusLabel
@onready var mine_timer     : Timer = $MineTimer
@onready var bg_node                 = $Background

var _current_mineral : String = ""
var _mining_active   : bool   = false

# ── Farger ───────────────────────────────────────────────────
const C_SPACE   := Color(0.02, 0.02, 0.08)
const C_MOON    := Color(0.38, 0.36, 0.32)
const C_MOON_D  := Color(0.28, 0.26, 0.24)
const C_DOME    := Color(0.22, 0.32, 0.42)
const C_DOME_H  := Color(0.35, 0.55, 0.72)
const C_TUBE    := Color(0.28, 0.38, 0.46)
const C_SHIP    := Color(0.55, 0.65, 0.75)
const C_SHIP_W  := Color(0.80, 0.90, 1.00)
const C_TANK    := Color(0.30, 0.42, 0.38)
const C_DRILL   := Color(0.55, 0.50, 0.40)
const C_STAR    := Color(1.00, 1.00, 1.00)

# Stjerneplasseringer genereres en gang i _ready
var _stars : Array = []

func _ready() -> void:
	# Generer stjerneposisjonar
	for i in 140:
		_stars.append({
			"x": randf() * 1280,
			"y": randf() * 340,
			"r": randf_range(0.5, 1.8),
			"a": randf_range(0.3, 1.0),
		})

	# Koble timer
	mine_timer.wait_time = MINE_INTERVAL
	mine_timer.one_shot  = false
	mine_timer.timeout.connect(_on_mine_tick)

	# Koble knapper
	$UI/ActionBar/MineButton.pressed.connect(_on_mine_toggled)
	$UI/ActionBar/ShipButton.pressed.connect(_on_enter_ship)
	$UI/ActionBar/LaunchButton.pressed.connect(_on_launch)
	$UI/ActionBar/MainMenuButton.pressed.connect(func():
		SaveManager.save_game()
		get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn"))

	# Pick first mining mineral
	_current_mineral = DataLoader.random_mineral()

	_refresh_ui()
	queue_redraw()

func _on_mine_toggled() -> void:
	_mining_active = not _mining_active
	if _mining_active:
		mine_timer.start()
		$UI/ActionBar/MineButton.text = "Stopp mining"
		_set_status("Gruvedrift paabegynt – utvinner %s" % _mineral_name(_current_mineral))
	else:
		mine_timer.stop()
		$UI/ActionBar/MineButton.text = "Start mining"
		_set_status("Gruvedrift stoppet.")

func _on_mine_tick() -> void:
	var ok := SaveManager.add_mineral(_current_mineral, MINE_AMT)
	if ok:
		# Bytt mineral av og til
		if randf() < 0.25:
			_current_mineral = DataLoader.random_mineral()
		_refresh_ui()
		queue_redraw()
	else:
		# Tankene er fulle
		mine_timer.stop()
		_mining_active = false
		$UI/ActionBar/MineButton.text = "Start mining"
		_set_status("Alle tanker er fulle! Reis til en trader for aa selge.")

func _on_enter_ship() -> void:
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://scenes/sprite_room/SpriteRoom.tscn")

func _on_launch() -> void:
	if SaveManager.total_minerals() == 0:
		_set_status("Ingen mineraler aa selge – start mining foerst.")
		return
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://scenes/travel/Travel.tscn")

func _refresh_ui() -> void:
	var d  := SaveManager.game_data
	hud_day_lbl.text  = "Dag  %d" % d.get("day", 1)
	hud_cred_lbl.text = "%d  kreditter" % d.get("credits", 0)

	var mn := _mineral_name(_current_mineral)
	hud_mine_lbl.text = "Utvinner: %s" % mn

	# Oppdater tankliste
	for child in tank_list.get_children():
		child.queue_free()
	var tanks : Array = d.get("tanks", [])
	for i in tanks.size():
		var tank : Dictionary = tanks[i]
		var mid  : String = tank.get("mineral_id", "")
		var amt  : int    = tank.get("amount",     0)
		var cap  : int    = tank.get("capacity",   50)
		var row  := HBoxContainer.new()
		var lbl  := Label.new()
		var bar  := ProgressBar.new()
		lbl.text                                     = "Tank %d: %s" % [i + 1, _mineral_name(mid) if mid != "" else "(tom)"]
		lbl.custom_minimum_size                      = Vector2(200, 0)
		lbl.add_theme_font_size_override("font_size", 12)
		bar.value                                    = float(amt) / float(cap) * 100.0
		bar.custom_minimum_size                      = Vector2(120, 16)
		var val_lbl := Label.new()
		val_lbl.text = "%d/%d" % [amt, cap]
		val_lbl.add_theme_font_size_override("font_size", 12)
		row.add_child(lbl)
		row.add_child(bar)
		row.add_child(val_lbl)
		tank_list.add_child(row)

func _mineral_name(id: String) -> String:
	if id == "":
		return ""
	return DataLoader.get_mineral(id).get("name", id)

func _set_status(msg: String) -> void:
	status_lbl.text = msg

# ── Tegning ──────────────────────────────────────────────────
func _draw() -> void:
	# Himmel / verdensrom
	draw_rect(Rect2(0, 0, 1280, 590), C_SPACE)

	# Stjerner
	for s in _stars:
		draw_circle(Vector2(s["x"], s["y"]), s["r"], Color(1, 1, 1, s["a"]))

	# Maaneoverflate – bulete terreng
	var moon_pts : PackedVector2Array = PackedVector2Array()
	moon_pts.append(Vector2(0, 590))
	moon_pts.append(Vector2(0, 390))
	moon_pts.append(Vector2(60, 380))
	moon_pts.append(Vector2(120, 375))
	moon_pts.append(Vector2(200, 385))
	moon_pts.append(Vector2(280, 378))
	moon_pts.append(Vector2(360, 382))
	moon_pts.append(Vector2(440, 370))
	moon_pts.append(Vector2(520, 375))
	moon_pts.append(Vector2(600, 368))
	moon_pts.append(Vector2(680, 372))
	moon_pts.append(Vector2(760, 366))
	moon_pts.append(Vector2(840, 370))
	moon_pts.append(Vector2(920, 374))
	moon_pts.append(Vector2(1000, 368))
	moon_pts.append(Vector2(1080, 375))
	moon_pts.append(Vector2(1160, 380))
	moon_pts.append(Vector2(1280, 372))
	moon_pts.append(Vector2(1280, 590))
	draw_polygon(moon_pts, PackedColorArray([C_MOON]))

	# Maanekrater-detaljer
	_draw_crater(160, 410, 24)
	_draw_crater(520, 430, 18)
	_draw_crater(940, 415, 30)
	_draw_crater(1150, 435, 14)

	# ── Base-struktur ─────────────────────────────────────────
	# Sentral kupol
	_draw_dome(560, 370, 130, 80)

	# Venstre roer: lagertunnel
	draw_rect(Rect2(360, 378, 180, 28), C_TUBE)
	draw_rect(Rect2(360, 378, 180, 5), Color(0.45, 0.60, 0.72, 0.6))

	# Venstre modul
	draw_rect(Rect2(280, 362, 88, 44), C_DOME)
	draw_rect(Rect2(280, 362, 88, 8),  C_DOME_H)

	# Hoyre roer: landingsseksjon
	draw_rect(Rect2(700, 378, 160, 28), C_TUBE)
	draw_rect(Rect2(700, 378, 160, 5), Color(0.45, 0.60, 0.72, 0.6))

	# ── Tanker (venstre for domen) ────────────────────────────
	var tanks : Array = SaveManager.game_data.get("tanks", [])
	for i in tanks.size():
		_draw_tank(160 + i * 70, 320, tanks[i])

	# ── Gruvedrill (hoyre) ───────────────────────────────────
	_draw_drill(980, 370)

	# ── Skip paa landingsplattform ───────────────────────────
	_draw_ship(1050, 330)

	# Landingsplattform
	draw_rect(Rect2(880, 374, 250, 8), Color(0.45, 0.50, 0.55))
	draw_rect(Rect2(890, 382, 4, 24), Color(0.35, 0.38, 0.42))
	draw_rect(Rect2(1122, 382, 4, 24), Color(0.35, 0.38, 0.42))

func _draw_dome(cx: float, base_y: float, w: float, h: float) -> void:
	# Kuppelform med draw_arc
	draw_rect(Rect2(cx - w / 2, base_y - 10, w, 18), C_DOME)
	# Halvellipse som kuppel – tegnes som mange trekanter
	var steps  := 24
	var prev   := Vector2(cx - w / 2, base_y - 10)
	for i in steps + 1:
		var angle := PI * float(i) / float(steps)
		var pt    := Vector2(cx + cos(PI - angle) * w / 2,
							 base_y - 10 - sin(angle) * h)
		if i > 0:
			draw_colored_polygon(
				PackedVector2Array([Vector2(cx, base_y - 10), prev, pt]),
				C_DOME)
		prev = pt
	# Kuppeloverlys (reflex)
	prev = Vector2(cx - w * 0.32, base_y - 10)
	for i in steps + 1:
		var angle := PI * float(i) / float(steps)
		var ptb   := Vector2(cx + cos(PI - angle) * w * 0.32,
							 base_y - 10 - sin(angle) * h * 0.88)
		if i > 0:
			draw_colored_polygon(
				PackedVector2Array([Vector2(cx, base_y - 10), prev, ptb]),
				Color(C_DOME_H.r, C_DOME_H.g, C_DOME_H.b, 0.30))
		prev = ptb
	# Vindu i kupelen
	draw_circle(Vector2(cx, base_y - h * 0.5), 16, Color(0.5, 0.8, 1.0, 0.5))
	draw_circle(Vector2(cx, base_y - h * 0.5), 12, Color(0.3, 0.6, 0.9, 0.35))

func _draw_tank(x: float, base_y: float, tank: Dictionary) -> void:
	var cap  : int    = tank.get("capacity", 50)
	var amt  : int    = tank.get("amount", 0)
	var mid  : String = tank.get("mineral_id", "")
	var fill : float  = float(amt) / float(cap) if cap > 0 else 0.0

	var tw := 44.0
	var th := 60.0
	# Tank-kropp
	draw_rect(Rect2(x, base_y - th, tw, th), C_TANK)
	draw_rect(Rect2(x, base_y - th, tw, 6), Color(0.4, 0.6, 0.55))
	# Fyllnivaa
	if fill > 0:
		var fill_col := Color(0.3, 0.9, 0.5, 0.85)
		if mid != "":
			var hex := DataLoader.get_mineral(mid).get("color", "44FF88")
			fill_col = Color.html(hex)
			fill_col.a = 0.85
		draw_rect(Rect2(x + 3, base_y - 3 - (th - 9) * fill,
					   tw - 6, (th - 9) * fill), fill_col)
	# Ramme
	draw_rect(Rect2(x, base_y - th, tw, th), Color(0.5, 0.65, 0.6, 0.7), false, 1.5)
	# Roer ned
	draw_rect(Rect2(x + tw / 2 - 3, base_y, 6, 10), C_TUBE)

func _draw_drill(x: float, base_y: float) -> void:
	# Drillarm
	draw_rect(Rect2(x - 4, base_y - 60, 8, 60), C_DRILL)
	# Drillhode
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(x - 10, base_y),
			Vector2(x + 10, base_y),
			Vector2(x, base_y + 22),
		]),
		Color(0.7, 0.6, 0.3))
	# Support-arm
	draw_rect(Rect2(x - 22, base_y - 62, 44, 6), C_DRILL)

func _draw_ship(cx: float, base_y: float) -> void:
	# Skipsskrog
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(cx - 36, base_y + 40),
			Vector2(cx + 36, base_y + 40),
			Vector2(cx + 24, base_y),
			Vector2(cx - 24, base_y),
		]),
		C_SHIP)
	# Cockpit
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(cx - 14, base_y),
			Vector2(cx + 14, base_y),
			Vector2(cx + 8,  base_y - 22),
			Vector2(cx - 8,  base_y - 22),
		]),
		Color(0.4, 0.6, 0.8))
	# Cockpit-refleks
	draw_rect(Rect2(cx - 5, base_y - 18, 8, 12), Color(0.7, 0.9, 1.0, 0.5))
	# Vingene
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(cx - 36, base_y + 40),
			Vector2(cx - 58, base_y + 52),
			Vector2(cx - 38, base_y + 52),
		]),
		C_SHIP_W)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(cx + 36, base_y + 40),
			Vector2(cx + 58, base_y + 52),
			Vector2(cx + 38, base_y + 52),
		]),
		C_SHIP_W)
	# Dyse-glow
	draw_rect(Rect2(cx - 10, base_y + 40, 20, 6), Color(0.6, 0.7, 0.8))

func _draw_crater(cx: float, cy: float, r: float) -> void:
	draw_circle(Vector2(cx, cy), r, C_MOON_D)
	draw_arc(Vector2(cx, cy), r, 0, TAU, 20, Color(0.22, 0.20, 0.18), 1.5)
