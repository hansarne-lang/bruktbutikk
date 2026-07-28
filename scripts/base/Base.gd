extends Node2D
## Void Miner – Maanebase-scene

const MINE_INTERVAL_NORMAL := 4.0
const MINE_INTERVAL_FAST   := 2.0
const MINE_AMT             := 1

@onready var hud_day_lbl  : Label          = $UI/HUD/DayLabel
@onready var hud_cred_lbl : Label          = $UI/HUD/CreditsLabel
@onready var hud_mine_lbl : Label          = $UI/HUD/MiningLabel
@onready var day_progress : ProgressBar    = $UI/HUD/DayProgress
@onready var day_time_lbl : Label          = $UI/HUD/DayTimeLabel
@onready var tank_panel                    = $UI/TankPanel
@onready var tank_list                     = $UI/TankPanel/TankVBox/TankList
@onready var info_panel                    = $UI/InfoPanel
@onready var info_text    : Label          = $UI/InfoPanel/InfoText
@onready var status_lbl   : Label          = $UI/StatusLabel
@onready var mine_timer   : Timer          = $MineTimer
@onready var upgrade_panel                 = $UI/UpgradePanel
@onready var log_panel                     = $UI/LogPanel

var _current_mineral  : String = ""
var _mining_active    : bool   = false
var _stars            : Array  = []
var _drill_angle      : float  = 0.0
var _time             : float  = 0.0
var _particles        : Array  = []  # {x, y, vx, vy, life, color}

# ── Farger ───────────────────────────────────────────────────
const C_SPACE  := Color(0.02, 0.02, 0.08)
const C_MOON   := Color(0.38, 0.36, 0.32)
const C_MOON_D := Color(0.28, 0.26, 0.24)
const C_DOME   := Color(0.22, 0.32, 0.42)
const C_DOME_H := Color(0.35, 0.55, 0.72)
const C_TUBE   := Color(0.28, 0.38, 0.46)
const C_SHIP   := Color(0.55, 0.65, 0.75)
const C_SHIP_W := Color(0.80, 0.90, 1.00)
const C_TANK   := Color(0.30, 0.42, 0.38)
const C_DRILL  := Color(0.55, 0.50, 0.40)

func _ready() -> void:
	for _i in 140:
		_stars.append({
			"x": randf() * 1280,
			"y": randf() * 340,
			"r": randf_range(0.5, 1.8),
			"a": randf_range(0.3, 1.0),
		})

	_update_mine_timer()
	mine_timer.one_shot = false
	mine_timer.timeout.connect(_on_mine_tick)

	$UI/ActionBar/MineButton.pressed.connect(_on_mine_toggled)
	$UI/ActionBar/ShipButton.pressed.connect(_on_enter_ship)
	$UI/ActionBar/UpgradeButton.pressed.connect(_toggle_upgrade_panel)
	$UI/ActionBar/LogButton.pressed.connect(_toggle_log_panel)
	$UI/ActionBar/MainMenuButton.pressed.connect(func() -> void:
		SaveManager.save_game()
		get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn"))

	_current_mineral = DataLoader.random_mineral()

	# Kreditt-popup fra siste handel
	var earned : int = SaveManager.game_data.get("last_earned", 0)
	if earned > 0:
		_show_credit_popup(earned, SaveManager.game_data.get("last_trader", ""))
		SaveManager.game_data["last_earned"] = 0

	_refresh_ui()
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta

	if _mining_active:
		_drill_angle += delta * 5.0
		# Dag/natt-syklus: fremskrider sakte under mining
		var tod : float = SaveManager.game_data.get("time_of_day", 0.0)
		SaveManager.game_data["time_of_day"] = fmod(tod + delta * 0.012, TAU)

	# Oppdater dag-fremgang i HUD
	var tod_now  : float = SaveManager.game_data.get("time_of_day", 0.0)
	var pct      : float = tod_now / TAU * 100.0
	day_progress.value   = pct
	day_time_lbl.text    = "%d%%" % int(pct)

	# Oppdater partikler
	for i : int in range(_particles.size() - 1, -1, -1):
		var p : Dictionary = _particles[i]
		p["x"]    += p["vx"] * delta
		p["y"]    += p["vy"] * delta
		p["vy"]   += 30.0 * delta   # tyngdekraft
		p["life"] -= delta
		if p["life"] <= 0.0:
			_particles.remove_at(i)

	queue_redraw()

func _update_mine_timer() -> void:
	var fast : bool = SaveManager.game_data.get("drill_upgraded", false)
	mine_timer.wait_time = MINE_INTERVAL_FAST if fast else MINE_INTERVAL_NORMAL

# ── Mining ───────────────────────────────────────────────────
func _on_mine_toggled() -> void:
	_mining_active = not _mining_active
	if _mining_active:
		mine_timer.start()
		$UI/ActionBar/MineButton.text = "Stopp mining"
		_set_status("Gruvedrift påbegynt – utvinner %s" % _mineral_name(_current_mineral))
	else:
		mine_timer.stop()
		$UI/ActionBar/MineButton.text = "Start mining"
		_set_status("Gruvedrift stoppet.")

func _on_mine_tick() -> void:
	SoundManager.play("drill_tick", -4.0)
	var ok := SaveManager.add_mineral(_current_mineral, MINE_AMT)
	if ok:
		_spawn_particles(980.0, 392.0)
		if randf() < 0.25:
			_current_mineral = DataLoader.random_mineral()
		_refresh_ui()
	else:
		mine_timer.stop()
		_mining_active = false
		$UI/ActionBar/MineButton.text = "Start mining"
		_set_status("Alle tanker er fulle! Gå om bord og reis til en trader for å selge.")

func _spawn_particles(x: float, y: float) -> void:
	var colors := ["CC8833", "FFDD44", "AADDFF", "88CCFF", "4488FF", "AAFFAA"]
	for _i in 10:
		_particles.append({
			"x":     x + randf_range(-8.0, 8.0),
			"y":     y,
			"vx":    randf_range(-35.0, 35.0),
			"vy":    randf_range(-70.0, -25.0),
			"life":  randf_range(0.35, 0.9),
			"color": Color.html(colors[randi() % colors.size()]),
		})

# ── Kredit-popup (#10) ────────────────────────────────────────
func _show_credit_popup(amount: int, trader: String) -> void:
	var lbl := Label.new()
	lbl.text = "+%d kr" % amount
	if trader != "":
		lbl.text += "\n– %s" % trader
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.25))
	lbl.position = Vector2(540, 300)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$UI.add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "position", Vector2(540, 180), 1.6)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.6)
	tw.tween_callback(lbl.queue_free)

# ── Navigasjon ───────────────────────────────────────────────
func _on_enter_ship() -> void:
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://scenes/sprite_room/SpriteRoom.tscn")

func _on_launch() -> void:
	if SaveManager.total_minerals() == 0:
		_set_status("Ingen mineraler å selge – start mining først.")
		return
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://scenes/map/Map.tscn")

# ── Oppgraderingspanel (#3) ───────────────────────────────────
func _toggle_upgrade_panel() -> void:
	upgrade_panel.visible = not upgrade_panel.visible
	if upgrade_panel.visible:
		log_panel.visible = false
		_refresh_upgrade_panel()

func _refresh_upgrade_panel() -> void:
	var vbox := upgrade_panel.get_node("VBox")
	for child in vbox.get_children():
		if child.name != "Title":
			child.queue_free()

	var d  := SaveManager.game_data
	var cr : int = d.get("credits", 0)

	var upgrades := [
		{"key": "drill_upgraded", "label": "Raskere drill  (2s intervall)", "cost": 1500},
		{"key": "extra_tank",     "label": "3. mineraltank",                "cost": 2000},
		{"key": "bigger_tanks",   "label": "Større tanker  (100 kap)",      "cost": 3000},
	]
	for upg in upgrades:
		var row  := HBoxContainer.new()
		var lbl  := Label.new()
		var btn  := Button.new()
		var done : bool = d.get(upg["key"], false)
		lbl.text = "  %s  –  %d kr" % [upg["label"], upg["cost"]]
		lbl.custom_minimum_size = Vector2(290, 0)
		lbl.add_theme_font_size_override("font_size", 12)
		if done:
			lbl.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
		elif cr < upg["cost"]:
			lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		btn.text     = "Kjøpt ✓" if done else "Kjøp"
		btn.disabled = done or cr < upg["cost"]
		var key  : String = upg["key"]
		var cost : int    = upg["cost"]
		btn.pressed.connect(func() -> void: _buy_upgrade(key, cost))
		row.add_child(lbl)
		row.add_child(btn)
		vbox.add_child(row)

func _buy_upgrade(key: String, cost: int) -> void:
	var d := SaveManager.game_data
	if d.get("credits", 0) < cost:
		return
	d["credits"] -= cost
	d[key] = true
	if key == "extra_tank":
		var tanks : Array = d.get("tanks", [])
		tanks.append({"mineral_id": "", "amount": 0, "capacity": 50})
		d["tanks"] = tanks
	elif key == "bigger_tanks":
		for tank in d.get("tanks", []):
			tank["capacity"] = 100
	elif key == "drill_upgraded":
		_update_mine_timer()
		if _mining_active:
			mine_timer.start()
	SoundManager.play("kaching")
	SaveManager.save_game()
	_refresh_ui()
	_refresh_upgrade_panel()
	_set_status("Oppgradering fullført!")

# ── Loggpanel (#15) ──────────────────────────────────────────
func _toggle_log_panel() -> void:
	log_panel.visible = not log_panel.visible
	if log_panel.visible:
		upgrade_panel.visible = false
		_refresh_log_panel()

func _refresh_log_panel() -> void:
	var lbl := log_panel.get_node("VBox/Scroll/LogText") as Label
	var entries : Array = SaveManager.game_data.get("trade_log", [])
	if entries.is_empty():
		lbl.text = "(ingen handler enda)"
		return
	var lines : PackedStringArray = []
	# Vis nyeste oeverst
	for i : int in range(entries.size() - 1, -1, -1):
		var e : Dictionary = entries[i]
		lines.append("Dag %d  ·  %s  ·  +%d kr" % [
			e.get("day", 0),
			e.get("trader", "?"),
			e.get("earned", 0),
		])
	lbl.text = "\n".join(lines)

# ── UI-oppdatering ───────────────────────────────────────────
func _refresh_ui() -> void:
	var d := SaveManager.game_data
	hud_day_lbl.text  = "Dag  %d" % d.get("day", 1)
	hud_cred_lbl.text = "%d  kreditter" % d.get("credits", 0)

	var mn    := _mineral_name(_current_mineral)
	var day   : int = d.get("day", 1)
	var hint  := ""
	if   day < 3:  hint = "  [dag 3: sjeldne]"
	elif day < 7:  hint = "  [dag 7: rare]"
	elif day < 14: hint = "  [dag 14: svært sjeldne]"
	hud_mine_lbl.text = "Utvinner: %s%s" % [mn, hint]

	for child in tank_list.get_children():
		child.queue_free()
	var tanks : Array = d.get("tanks", [])
	for i in tanks.size():
		var tank    : Dictionary = tanks[i]
		var mid     : String     = tank.get("mineral_id", "")
		var amt     : int        = tank.get("amount",     0)
		var cap     : int        = tank.get("capacity",   50)
		var row     := HBoxContainer.new()
		var lbl     := Label.new()
		var bar     := ProgressBar.new()
		var val_lbl := Label.new()
		lbl.text = "Tank %d: %s" % [i + 1, _mineral_name(mid) if mid != "" else "(tom)"]
		lbl.custom_minimum_size = Vector2(200, 0)
		lbl.add_theme_font_size_override("font_size", 12)
		bar.value = float(amt) / float(cap) * 100.0
		bar.custom_minimum_size = Vector2(100, 16)
		val_lbl.text = "%d/%d" % [amt, cap]
		val_lbl.add_theme_font_size_override("font_size", 12)
		row.add_child(lbl)
		row.add_child(bar)
		row.add_child(val_lbl)
		tank_list.add_child(row)

func _mineral_name(id: String) -> String:
	if id == "": return ""
	return DataLoader.get_mineral(id).get("name", id)

func _set_status(msg: String) -> void:
	status_lbl.text = msg

# ── Tegning ──────────────────────────────────────────────────
func _draw() -> void:
	# Dag/natt-himmel (#5)
	var tod     : float = SaveManager.game_data.get("time_of_day", 0.0)
	var night_t : float = cos(tod) * 0.5 + 0.5   # 1 = natt, 0 = dag
	var sky_col := C_SPACE.lerp(Color(0.04, 0.06, 0.18), 1.0 - night_t * 0.8)
	draw_rect(Rect2(0, 0, 1280, 590), sky_col)

	# Sol-glow ved dag (#5)
	var sun_a : float = clampf((1.0 - night_t) * 0.5, 0.0, 0.5)
	if sun_a > 0.03:
		draw_circle(Vector2(1200, 55), 90.0, Color(1.0, 0.65, 0.2, sun_a * 0.25))
		draw_circle(Vector2(1200, 55), 22.0, Color(1.0, 0.92, 0.7, sun_a))

	# Stjerner (synlige om natten)
	for s in _stars:
		draw_circle(Vector2(s["x"], s["y"]), s["r"], Color(1, 1, 1, s["a"] * night_t))

	# Maaneoverflate
	var moon_pts : PackedVector2Array = PackedVector2Array([
		Vector2(0, 590), Vector2(0, 390), Vector2(60, 380), Vector2(120, 375),
		Vector2(200, 385), Vector2(280, 378), Vector2(360, 382), Vector2(440, 370),
		Vector2(520, 375), Vector2(600, 368), Vector2(680, 372), Vector2(760, 366),
		Vector2(840, 370), Vector2(920, 374), Vector2(1000, 368), Vector2(1080, 375),
		Vector2(1160, 380), Vector2(1280, 372), Vector2(1280, 590),
	])
	draw_polygon(moon_pts, PackedColorArray([C_MOON]))

	_draw_crater(160, 410, 24)
	_draw_crater(520, 430, 18)
	_draw_crater(940, 415, 30)
	_draw_crater(1150, 435, 14)

	# Base-strukturer
	_draw_dome(560, 370, 130, 80)
	draw_rect(Rect2(360, 378, 180, 28), C_TUBE)
	draw_rect(Rect2(360, 378, 180, 5),  Color(0.45, 0.60, 0.72, 0.6))
	draw_rect(Rect2(280, 362, 88, 44),  C_DOME)
	draw_rect(Rect2(280, 362, 88, 8),   C_DOME_H)
	draw_rect(Rect2(700, 378, 160, 28), C_TUBE)
	draw_rect(Rect2(700, 378, 160, 5),  Color(0.45, 0.60, 0.72, 0.6))

	# Tanker
	var tanks : Array = SaveManager.game_data.get("tanks", [])
	for i in tanks.size():
		_draw_tank(160.0 + i * 70.0, 320.0, tanks[i])

	# Drill
	_draw_drill(980.0, 370.0)

	# Skip
	_draw_ship(1050.0, 330.0)

	# Landingsplattform
	draw_rect(Rect2(880, 374, 250, 8), Color(0.45, 0.50, 0.55))
	draw_rect(Rect2(890, 382, 4, 24),  Color(0.35, 0.38, 0.42))
	draw_rect(Rect2(1122, 382, 4, 24), Color(0.35, 0.38, 0.42))

	# Partikler (#7)
	for p in _particles:
		var col : Color = p["color"]
		col.a = clampf(p["life"] * 2.5, 0.0, 1.0)
		draw_circle(Vector2(p["x"], p["y"]), clampf(p["life"] * 4.0, 1.0, 4.0), col)

func _draw_dome(cx: float, base_y: float, w: float, h: float) -> void:
	draw_rect(Rect2(cx - w / 2, base_y - 10, w, 18), C_DOME)
	var steps := 24
	var prev  := Vector2(cx - w / 2, base_y - 10)
	for i in steps + 1:
		var angle := PI * float(i) / float(steps)
		var pt    := Vector2(cx + cos(PI - angle) * w / 2, base_y - 10 - sin(angle) * h)
		if i > 0:
			draw_colored_polygon(PackedVector2Array([Vector2(cx, base_y - 10), prev, pt]), C_DOME)
		prev = pt
	prev = Vector2(cx - w * 0.32, base_y - 10)
	for i in steps + 1:
		var angle := PI * float(i) / float(steps)
		var ptb   := Vector2(cx + cos(PI - angle) * w * 0.32, base_y - 10 - sin(angle) * h * 0.88)
		if i > 0:
			draw_colored_polygon(PackedVector2Array([Vector2(cx, base_y - 10), prev, ptb]),
				Color(C_DOME_H.r, C_DOME_H.g, C_DOME_H.b, 0.30))
		prev = ptb
	draw_circle(Vector2(cx, base_y - h * 0.5), 16, Color(0.5, 0.8, 1.0, 0.5))
	draw_circle(Vector2(cx, base_y - h * 0.5), 12, Color(0.3, 0.6, 0.9, 0.35))

func _draw_tank(x: float, base_y: float, tank: Dictionary) -> void:
	var cap  : int    = tank.get("capacity", 50)
	var amt  : int    = tank.get("amount",   0)
	var mid  : String = tank.get("mineral_id", "")
	var fill : float  = float(amt) / float(cap) if cap > 0 else 0.0
	var tw   := 44.0
	var th   := 60.0
	draw_rect(Rect2(x, base_y - th, tw, th), C_TANK)
	draw_rect(Rect2(x, base_y - th, tw, 6),  Color(0.4, 0.6, 0.55))
	if fill > 0:
		var fill_col := Color(0.3, 0.9, 0.5, 0.85)
		if mid != "":
			var hex : String = DataLoader.get_mineral(mid).get("color", "44FF88")
			fill_col = Color.html(hex)
			fill_col.a = 0.85
		draw_rect(Rect2(x + 3, base_y - 3 - (th - 9) * fill, tw - 6, (th - 9) * fill), fill_col)
	draw_rect(Rect2(x, base_y - th, tw, th), Color(0.5, 0.65, 0.6, 0.7), false, 1.5)
	draw_rect(Rect2(x + tw / 2 - 3, base_y, 6, 10), C_TUBE)

func _draw_drill(x: float, base_y: float) -> void:
	# Arm og support
	draw_rect(Rect2(x - 4, base_y - 60, 8, 60),  C_DRILL)
	draw_rect(Rect2(x - 22, base_y - 62, 44, 6), C_DRILL)
	# Roterende drillhode (#6)
	var tip_col := Color(0.7, 0.6, 0.3)
	if _mining_active:
		tip_col = tip_col.lerp(Color(1.0, 0.45, 0.05), 0.5 + sin(_drill_angle * 3.0) * 0.5)
		# Varme-glow
		draw_circle(Vector2(x, base_y + 6), 14.0 + sin(_time * 8.0) * 3.0,
			Color(1.0, 0.4, 0.1, 0.18 + sin(_time * 5.0) * 0.08))
	draw_set_transform(Vector2(x, base_y), _drill_angle if _mining_active else 0.0)
	draw_colored_polygon(
		PackedVector2Array([Vector2(-10, 0), Vector2(10, 0), Vector2(0, 22)]),
		tip_col)
	draw_set_transform(Vector2.ZERO, 0.0)

func _draw_ship(cx: float, base_y: float) -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 36, base_y + 40), Vector2(cx + 36, base_y + 40),
		Vector2(cx + 24, base_y),      Vector2(cx - 24, base_y),
	]), C_SHIP)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 14, base_y),      Vector2(cx + 14, base_y),
		Vector2(cx + 8,  base_y - 22), Vector2(cx - 8,  base_y - 22),
	]), Color(0.4, 0.6, 0.8))
	draw_rect(Rect2(cx - 5, base_y - 18, 8, 12), Color(0.7, 0.9, 1.0, 0.5))
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 36, base_y + 40), Vector2(cx - 58, base_y + 52), Vector2(cx - 38, base_y + 52),
	]), C_SHIP_W)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx + 36, base_y + 40), Vector2(cx + 58, base_y + 52), Vector2(cx + 38, base_y + 52),
	]), C_SHIP_W)
	draw_rect(Rect2(cx - 10, base_y + 40, 20, 6), Color(0.6, 0.7, 0.8))

func _draw_crater(cx: float, cy: float, r: float) -> void:
	draw_circle(Vector2(cx, cy), r, C_MOON_D)
	draw_arc(Vector2(cx, cy), r, 0, TAU, 20, Color(0.22, 0.20, 0.18), 1.5)
