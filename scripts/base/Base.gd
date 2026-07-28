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
@onready var engine_room_panel             = $UI/EngineRoomPanel

var _current_mineral  : String = ""
var _mining_active    : bool   = false
var _stars            : Array  = []
var _drill_angle      : float  = 0.0
var _time             : float  = 0.0
var _particles        : Array  = []  # {x, y, vx, vy, life, color}

# ── Gruvekart ────────────────────────────────────────────────────
var _map_open    : bool  = false
var _map_hovered : int   = -1

# ── Overflow ─────────────────────────────────────────────────────
var _pending_mineral : String = ""   # mineral som ikke fikk plass

# ── Skip-lasterom ────────────────────────────────────────────────
var _cargo_panel_open : bool   = false

# ── Motorrom / Reparasjon ─────────────────────────────────────────
var _repair_active    : bool   = false
var _repair_target_id : String = ""
var _repair_progress  : float  = 0.0
var _er_refresh_acc   : float  = 0.0   # akkumulator for ER-panel refresh

const REPAIR_TICK_DURATION := 3.0   # sekunder per reparasjons-tikk

# ── Sonekart farger ──────────────────────────────────────────────
const ZONE_COLORS := {
	"Metall":   Color(0.90, 0.65, 0.25),
	"Krystall": Color(0.35, 0.60, 1.00),
	"Mineral":  Color(0.58, 0.58, 0.48),
	"Element":  Color(0.25, 0.95, 0.80),
	"Gass":     Color(0.40, 0.90, 0.45),
	"Ukjent":   Color(0.88, 0.88, 0.95),
}
const ZONE_HINTS := {
	"Metall":   "Varme tonser – metaller mulig",
	"Krystall": "Kalde blåtoner – krystaller mulig",
	"Mineral":  "Grå sone – mineraler mulig",
	"Element":  "Elektrisk glød – elementer mulig",
	"Gass":     "Grønnskimmer – gass mulig",
	"Ukjent":   "Uleselig signal – ukjent innhold",
}

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
	$UI/UpgradePanel/VBox/TitleRow/CloseBtn.pressed.connect(func(): upgrade_panel.visible = false)
	$UI/LogPanel/VBox/TitleRow/CloseBtn.pressed.connect(func(): log_panel.visible = false)
	$UI/ActionBar/EngineRoomButton.pressed.connect(_toggle_engine_room)
	$UI/EngineRoomPanel/VBox/TitleRow/CloseBtn.pressed.connect(func(): engine_room_panel.visible = false)
	$CargoLayer/CargoPanel/VBox/BtnRow/CancelBtn.pressed.connect(_close_cargo_panel)
	$CargoLayer/CargoPanel/VBox/BtnRow/BoardBtn.pressed.connect(_depart_to_ship)

	# Sjekk om bestilte varer er ankommet
	var delivered : Array = SaveManager.check_and_deliver_orders()
	if not delivered.is_empty():
		var names : Array = delivered.map(func(o) -> String: return o.get("item_name", "?"))
		_set_status("Levering ankommet: %s" % ", ".join(names))

	# Kart: åpnes via Start mining (se _on_mine_toggled)
	# Overflow-layer er skjult til det trengs (se _show_overflow_dialog)

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

	# ── Reparasjon (concurrent med mining) ───────────────────────
	if _repair_active:
		_repair_progress += delta
		if _repair_progress >= REPAIR_TICK_DURATION:
			_repair_progress -= REPAIR_TICK_DURATION
			_do_repair_tick()
		# Oppdater panel ca. hvert halvsekund
		_er_refresh_acc += delta
		if engine_room_panel.visible and _er_refresh_acc >= 0.5:
			_er_refresh_acc = 0.0
			_refresh_engine_room()

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
	var fast  : bool  = SaveManager.game_data.get("drill_upgraded", false)
	var base  : float = MINE_INTERVAL_FAST if fast else MINE_INTERVAL_NORMAL
	mine_timer.wait_time = SaveManager.get_effective_mine_interval(base)

# ── Mining ───────────────────────────────────────────────────
func _on_mine_toggled() -> void:
	# BUG-FIX: kart allerede åpent → "Avbryt"-klikk lukker kartet
	if _map_open:
		_close_map()
		return
	if _mining_active:
		# Stopp direkte
		mine_timer.stop()
		_mining_active = false
		$UI/ActionBar/MineButton.text = "Start mining"
		_set_status("Gruvedrift stoppet.")
	else:
		# Vis gruvekart først
		_map_open    = true
		_map_hovered = -1
		$UI/ActionBar/MineButton.text = "Avbryt"
		upgrade_panel.visible     = false
		log_panel.visible         = false
		engine_room_panel.visible = false
		queue_redraw()

func _on_mine_tick() -> void:
	SoundManager.play("drill_tick", -4.0)
	# Tilfeldig komponentskade + oppdater intervall
	SaveManager.apply_mine_damage()
	_update_mine_timer()
	if _mining_active:
		mine_timer.start()   # restart med (mulig) ny wait_time
	# Livsstøtte-penalitet ved kritisk kondisjon
	_check_life_support()
	# Drill-effektivitet: lavt kondisjon = sjanse for tapte mineraler
	var eff : float = SaveManager.get_drill_efficiency()
	if randf() >= eff:
		var dc : int = _get_comp_condition("drill_head")
		_set_status("Boresystem skadet (%d%%) – mistet mineral! Reparer i Motorrom." % dc)
		if engine_room_panel.visible:
			_refresh_engine_room()
		return
	var ok := SaveManager.add_mineral(_current_mineral, MINE_AMT)
	if not ok:
		# Prøv stille bytte til mineral som finnes i eksisterende tank med plass
		if _switch_to_available_mineral():
			ok = SaveManager.add_mineral(_current_mineral, MINE_AMT)
		else:
			# Ekte overflow – vis dialog
			_pending_mineral = _current_mineral   # siste forsøkte mineral
			_show_overflow_dialog()
			mine_timer.stop()
			_mining_active = false
			$UI/ActionBar/MineButton.text = "Start mining"
			return
	if ok:
		_check_tank_full_warning()
		_spawn_particles(980.0, 392.0)
		if randf() < 0.25:
			var zone : String = SaveManager.game_data.get("current_zone", "")
			_current_mineral = DataLoader.random_mineral_for_zone(zone)
		_refresh_ui()

## Bytter _current_mineral til et som passer i en eksisterende tank.
## Returnerer true hvis det fantes plass et sted.
func _switch_to_available_mineral() -> bool:
	var tanks : Array = SaveManager.game_data.get("tanks", [])
	for tank in tanks:
		var mid : String = tank.get("mineral_id", "")
		var amt : int    = tank.get("amount",     0)
		var cap : int    = tank.get("capacity",   50)
		if mid != "" and amt < cap:
			_current_mineral = mid
			_set_status("Byttet til %s (ingen plass til annet mineral)" % _mineral_name(mid))
			return true
	return false

## Sjekker om den aktive tanken nettopp ble full → advarsel til spiller
func _check_tank_full_warning() -> void:
	var tanks : Array = SaveManager.game_data.get("tanks", [])
	for i in tanks.size():
		var tank : Dictionary = tanks[i]
		if tank.get("mineral_id", "") == _current_mineral:
			var amt : int = tank.get("amount", 0)
			var cap : int = tank.get("capacity", 50)
			if amt >= cap:
				_set_status("⚠  Tank %d er full (%s)! Vurder å reise til en trader." % [i + 1, _mineral_name(_current_mineral)])
			elif amt >= cap * 0.8:
				_set_status("Tank %d er %d%% full (%s)." % [i + 1, int(float(amt)/float(cap)*100), _mineral_name(_current_mineral)])
			break

# ── Overflow-dialog ───────────────────────────────────────────────
func _show_overflow_dialog() -> void:
	var panel   := $OverflowLayer/OverflowPanel
	var bg      := $OverflowLayer/OverflowBg
	var msg_lbl := $OverflowLayer/OverflowPanel/VBox/MessageLabel as Label
	var btn_box := $OverflowLayer/OverflowPanel/VBox/ButtonsVBox

	# Rydd gamle knapper
	for child in btn_box.get_children():
		child.queue_free()

	msg_lbl.text = "Du fant %s, men du har ingen ledig tank.\nHva vil du gjøre?" % _mineral_name(_pending_mineral)

	# Knapp: dump det nye funnet
	var dump_btn := Button.new()
	dump_btn.text = "🗑  Dump funnet mineral (mist %s)" % _mineral_name(_pending_mineral)
	dump_btn.custom_minimum_size = Vector2(460, 38)
	dump_btn.pressed.connect(func() -> void:
		_close_overflow()
		_set_status("Dumpet %s. Gruvedriften fortsetter." % _mineral_name(_pending_mineral))
		_resume_mining_same_zone())
	btn_box.add_child(dump_btn)

	# Knapper: bytt ut en tank
	var tanks : Array = SaveManager.game_data.get("tanks", [])
	for i in tanks.size():
		var tank : Dictionary = tanks[i]
		var mid  : String     = tank.get("mineral_id", "")
		var amt  : int        = tank.get("amount", 0)
		if mid == "" or amt == 0:
			continue
		var swap_btn := Button.new()
		swap_btn.text = "↕  Bytt Tank %d: %s (%d stk) → legg inn %s" % [
			i + 1, _mineral_name(mid), amt, _mineral_name(_pending_mineral)]
		swap_btn.custom_minimum_size = Vector2(460, 38)
		var tank_idx : int    = i
		var old_mid  : String = mid
		swap_btn.pressed.connect(func() -> void:
			# Tøm den valgte tanken og sett inn det nye mineralet
			tanks[tank_idx]["mineral_id"] = _pending_mineral
			tanks[tank_idx]["amount"]     = MINE_AMT
			_close_overflow()
			_set_status("Dumpet %s og lagt inn %s i Tank %d." % [
				_mineral_name(old_mid), _mineral_name(_pending_mineral), tank_idx + 1])
			_current_mineral = _pending_mineral
			# BUG-FIX: bruk _restart_mining, ikke _resume (ville overskrive _current_mineral)
			_restart_mining())
		btn_box.add_child(swap_btn)

	# Knapp: reis til trader
	var trader_btn := Button.new()
	trader_btn.text = "🚀 Stopp mining og reis til trader"
	trader_btn.custom_minimum_size = Vector2(460, 38)
	trader_btn.pressed.connect(func() -> void:
		_close_overflow()
		SaveManager.save_game()
		get_tree().change_scene_to_file("res://scenes/sprite_room/SpriteRoom.tscn"))
	btn_box.add_child(trader_btn)

	bg.visible    = true
	panel.visible = true

func _close_overflow() -> void:
	$OverflowLayer/OverflowBg.visible     = false
	$OverflowLayer/OverflowPanel.visible  = false
	_pending_mineral = ""

func _resume_mining_same_zone() -> void:
	var zone : String = SaveManager.game_data.get("current_zone", "")
	_current_mineral = DataLoader.random_mineral_for_zone(zone)
	_restart_mining()

func _restart_mining() -> void:
	_mining_active = true
	mine_timer.start()
	$UI/ActionBar/MineButton.text = "Stopp mining"
	_refresh_ui()

# ── Gruvekart ─────────────────────────────────────────────────────
func _drill_site_pos(idx: int) -> Vector2:
	var col : int = idx % 4
	var row : int = idx / 4
	return Vector2(200.0 + col * 230.0, 148.0 + row * 168.0)

func _unhandled_input(event: InputEvent) -> void:
	if not _map_open:
		return
	if event is InputEventMouseMotion:
		var me := event as InputEventMouseMotion
		var sites : Array = SaveManager.game_data.get("drill_sites", [])
		_map_hovered = -1
		for i in sites.size():
			if _drill_site_pos(i).distance_to(me.position) < 36.0:
				_map_hovered = i
				break
		queue_redraw()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		var sites : Array = SaveManager.game_data.get("drill_sites", [])
		for i in sites.size():
			if _drill_site_pos(i).distance_to(mb.position) < 36.0:
				_on_site_clicked(sites[i])
				get_viewport().set_input_as_handled()
				return
		# Klikk utenfor → avbryt
		_close_map()
		get_viewport().set_input_as_handled()

func _on_site_clicked(site: Dictionary) -> void:
	var cat     : String = site.get("category", "Mineral")
	var scanner : bool   = SaveManager.game_data.get("ground_scanner", false)
	SaveManager.game_data["current_zone"] = cat
	# Sjanse-faktor: uten skanner 50 % sjanse for at hintet er "feil".
	# Med Grunnskanner øker treffsikkerheten til 90 %.
	var accuracy : float = 0.90 if scanner else 0.50
	if randf() < accuracy:
		_current_mineral = DataLoader.random_mineral_for_zone(cat)
	else:
		_current_mineral = DataLoader.random_mineral()   # fullstendig tilfeldig
	_close_map()
	# Start mining
	_mining_active = true
	mine_timer.start()
	$UI/ActionBar/MineButton.text = "Stopp mining"
	var hint : String = (cat if scanner else ZONE_HINTS.get(cat, ""))
	_set_status("Gruvedrift startet – sone: %s  ·  utvinner %s" % [hint, _mineral_name(_current_mineral)])
	_refresh_ui()

func _close_map() -> void:
	_map_open    = false
	_map_hovered = -1
	$UI/ActionBar/MineButton.text = "Start mining"
	queue_redraw()

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
	# Vis lastepanel før avreise
	_open_cargo_panel()

# ── Skip-lasterom ─────────────────────────────────────────────
func _open_cargo_panel() -> void:
	_cargo_panel_open = true
	$CargoLayer/CargoBg.visible    = true
	$CargoLayer/CargoPanel.visible = true
	_refresh_cargo_panel()

func _close_cargo_panel() -> void:
	_cargo_panel_open = false
	$CargoLayer/CargoBg.visible    = false
	$CargoLayer/CargoPanel.visible = false

func _depart_to_ship() -> void:
	_close_cargo_panel()
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://scenes/sprite_room/SpriteRoom.tscn")

func _refresh_cargo_panel() -> void:
	var cap    : int   = SaveManager.game_data.get("ship_cargo_capacity", 40)
	var used   : int   = SaveManager.get_ship_cargo_used()
	var space  : int   = cap - used
	var cargo  : Array = SaveManager.game_data.get("ship_cargo", [])
	var tanks  : Array = SaveManager.game_data.get("tanks", [])

	# Kapasitetsbar
	var cap_lbl := $CargoLayer/CargoPanel/VBox/CapacityLabel as Label
	var cap_bar := $CargoLayer/CargoPanel/VBox/CapBar as ProgressBar
	cap_lbl.text  = "Lasterom: %d / %d enheter" % [used, cap]
	cap_bar.value = float(used) / float(cap) * 100.0

	# ── Gruve-tanker ──────────────────────────────────────────
	var tank_rows := $CargoLayer/CargoPanel/VBox/TankRows
	for child in tank_rows.get_children():
		child.queue_free()

	var any_in_tanks : bool = false
	for tank in tanks:
		var mid : String = tank.get("mineral_id", "")
		var amt : int    = tank.get("amount", 0)
		if mid == "" or amt == 0:
			continue
		any_in_tanks = true
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var info := Label.new()
		info.text = "%s  ×%d" % [_mineral_name(mid), amt]
		info.custom_minimum_size = Vector2(300, 0)
		info.add_theme_font_size_override("font_size", 13)

		var load_all := Button.new()
		load_all.text = "Last inn alt  →"
		load_all.disabled = space <= 0
		var m : String = mid
		var a : int    = amt
		load_all.pressed.connect(func() -> void:
			var loaded : int = SaveManager.load_to_ship_cargo(m, a)
			if loaded > 0:
				_refresh_cargo_panel()
				_refresh_ui())

		var load_half := Button.new()
		load_half.text = "Last inn halvpart"
		load_half.disabled = space <= 0 or amt <= 1
		load_half.pressed.connect(func() -> void:
			var loaded : int = SaveManager.load_to_ship_cargo(m, max(1, a / 2))
			if loaded > 0:
				_refresh_cargo_panel()
				_refresh_ui())

		row.add_child(info)
		row.add_child(load_all)
		row.add_child(load_half)
		tank_rows.add_child(row)

	if not any_in_tanks:
		var empty_lbl := Label.new()
		empty_lbl.text = "(Ingen mineraler i gruve-tanker)"
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		tank_rows.add_child(empty_lbl)

	# ── Skip-lasterom ─────────────────────────────────────────
	var cargo_rows := $CargoLayer/CargoPanel/VBox/CargoRows
	for child in cargo_rows.get_children():
		child.queue_free()

	if cargo.is_empty():
		var empty_lbl2 := Label.new()
		empty_lbl2.text = "(Ingenting lastet enda)"
		empty_lbl2.add_theme_font_size_override("font_size", 12)
		empty_lbl2.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		cargo_rows.add_child(empty_lbl2)
	else:
		for item in cargo:
			var mid : String = item.get("mineral_id", "")
			var amt : int    = item.get("amount", 0)
			if mid == "" or amt == 0:
				continue
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)

			var info := Label.new()
			info.text = "%s  ×%d" % [_mineral_name(mid), amt]
			info.custom_minimum_size = Vector2(300, 0)
			info.add_theme_font_size_override("font_size", 13)
			info.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))

			var unload_btn := Button.new()
			unload_btn.text = "Fjern"
			var m : String = mid
			unload_btn.pressed.connect(func() -> void:
				SaveManager.unload_from_ship_cargo(m)
				_refresh_cargo_panel()
				_refresh_ui())

			row.add_child(info)
			row.add_child(unload_btn)
			cargo_rows.add_child(row)

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
		if child.name != "TitleRow":
			child.queue_free()

	var d  := SaveManager.game_data
	var cr : int = d.get("credits", 0)

	var upgrades := [
		{"key": "drill_upgraded",  "label": "Raskere drill  (2s intervall)", "cost": 1500},
		{"key": "extra_tank",      "label": "3. mineraltank",                 "cost": 2000},
		{"key": "bigger_tanks",    "label": "Større tanker  (100 kap)",       "cost": 3000},
		{"key": "ground_scanner",  "label": "Grunnskanner  (avslører soner)", "cost": 8000},
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

# ── Motorrom ─────────────────────────────────────────────────
func _toggle_engine_room() -> void:
	engine_room_panel.visible = not engine_room_panel.visible
	if engine_room_panel.visible:
		upgrade_panel.visible = false
		log_panel.visible     = false
		_refresh_engine_room()

func _refresh_engine_room() -> void:
	var comp_list := engine_room_panel.get_node("VBox/CompList")
	for child in comp_list.get_children():
		child.queue_free()

	var skill : float = SaveManager.game_data.get("repair_skill", 0.0)
	var tools : Array = SaveManager.game_data.get("repair_tools",  [])
	var spd   : float = SaveManager.get_repair_speed()
	(engine_room_panel.get_node("VBox/SkillLabel") as Label).text = \
		"Reparasjonsferdighet: %.1f  |  Fart: %.0f kond/tikk" % [skill, spd]
	var tool_names : Array = tools.map(func(t) -> String: return _tool_label(t))
	(engine_room_panel.get_node("VBox/ToolLabel") as Label).text = \
		"Verktøy: %s" % (", ".join(tool_names) if not tool_names.is_empty() else "ingen")

	var comps : Array = SaveManager.game_data.get("ship_components", [])
	for comp in comps:
		var cid       : String = comp.get("id",        "")
		var cname     : String = comp.get("name",       cid)
		var cond      : int    = comp.get("condition",  100)
		var level     : int    = comp.get("level",      1)
		var is_target : bool   = (_repair_active and _repair_target_id == cid)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var name_lbl := Label.new()
		name_lbl.text = "%s [Niv.%d]" % [cname, level]
		name_lbl.custom_minimum_size = Vector2(168, 0)
		name_lbl.add_theme_font_size_override("font_size", 12)

		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(100, 18)
		bar.max_value = 100.0
		bar.value     = float(cond)
		if   cond > 70: bar.modulate = Color(0.3, 1.0, 0.4)
		elif cond > 35: bar.modulate = Color(1.0, 0.85, 0.2)
		else:           bar.modulate = Color(1.0, 0.35, 0.2)

		var cond_lbl := Label.new()
		cond_lbl.text = "%d%%" % cond
		cond_lbl.custom_minimum_size = Vector2(38, 0)
		cond_lbl.add_theme_font_size_override("font_size", 12)

		var rep_btn := Button.new()
		rep_btn.custom_minimum_size = Vector2(130, 0)
		if is_target:
			var pct : int = int(_repair_progress / REPAIR_TICK_DURATION * 100.0)
			rep_btn.text     = "Reparerer... %d%%" % pct
			rep_btn.disabled = true
		elif cond >= 100:
			rep_btn.text     = "OK"
			rep_btn.disabled = true
		else:
			rep_btn.text     = "Reparer"
			rep_btn.disabled = _repair_active
			var target_id : String = cid
			rep_btn.pressed.connect(func() -> void: _start_repair(target_id))

		row.add_child(name_lbl)
		row.add_child(bar)
		row.add_child(cond_lbl)
		row.add_child(rep_btn)
		comp_list.add_child(row)

	# Pending-bestillinger
	var orders : Array = SaveManager.game_data.get("pending_orders", [])
	var rep_status := engine_room_panel.get_node("VBox/RepairStatus") as Label
	if not orders.is_empty():
		var lines : Array = []
		for o in orders:
			lines.append("%s → leveres dag %d" % [o.get("item_name", "?"), o.get("deliver_day", 0)])
		rep_status.text    = "Ventende bestillinger:\n" + "\n".join(lines)
		rep_status.visible = true
	elif _repair_active:
		rep_status.text    = "Reparerer %s..." % _comp_name(_repair_target_id)
		rep_status.visible = true
	else:
		rep_status.visible = false

func _start_repair(comp_id: String) -> void:
	_repair_active    = true
	_repair_target_id = comp_id
	_repair_progress  = 0.0
	_er_refresh_acc   = 0.0
	_refresh_engine_room()
	_set_status("Reparerer %s..." % _comp_name(comp_id))

func _do_repair_tick() -> void:
	var spd   : float = SaveManager.get_repair_speed()
	var comps : Array = SaveManager.game_data.get("ship_components", [])
	for comp in comps:
		if comp.get("id", "") != _repair_target_id:
			continue
		var old_cond : int = comp.get("condition", 100)
		comp["condition"] = min(100, old_cond + int(spd))
		# Øk reparasjonsferdighet
		var skill : float = SaveManager.game_data.get("repair_skill", 0.0)
		SaveManager.game_data["repair_skill"] = min(10.0, skill + 0.05)
		if comp["condition"] >= 100:
			var finished_id : String = _repair_target_id
			_repair_active    = false
			_repair_target_id = ""
			_repair_progress  = 0.0
			# Oppdater mine-intervall dersom drivverk/reaktor ble reparert
			if finished_id in ["engine", "reactor"]:
				_update_mine_timer()
				if _mining_active:
					mine_timer.start()
			_set_status("Reparasjon fullfort: %s er tilbake pa 100%%!" % comp.get("name", "?"))
		else:
			_set_status("Reparerer %s... %d%%" % [comp.get("name", "?"), comp["condition"]])
		break
	if engine_room_panel.visible:
		_refresh_engine_room()

func _get_comp_condition(comp_id: String) -> int:
	for c in SaveManager.game_data.get("ship_components", []):
		if c.get("id", "") == comp_id:
			return c.get("condition", 100)
	return 100

func _comp_name(id: String) -> String:
	for c in SaveManager.game_data.get("ship_components", []):
		if c.get("id", "") == id:
			return c.get("name", id)
	return id

func _tool_label(id: String) -> String:
	match id:
		"basic_toolkit":     return "Basis verktøysett"
		"calibrated_wrench": return "Kalibrert skiftenøkkel"
		"nano_repair_kit":   return "Nano-reparasjonssett"
	return id

func _check_life_support() -> void:
	var ls_cond : int = _get_comp_condition("life_support")
	if ls_cond < 30:
		var penalty : int = int(lerp(50.0, 0.0, ls_cond / 30.0))
		if penalty > 0:
			SaveManager.game_data["credits"] = max(0, SaveManager.game_data.get("credits", 0) - penalty)
			_set_status("Livsstøtte kritisk (%d%%) – kredittlekkasje: -%d kr!" % [ls_cond, penalty])

# ── UI-oppdatering ───────────────────────────────────────────
func _refresh_ui() -> void:
	var d := SaveManager.game_data
	hud_day_lbl.text  = "Dag  %d" % d.get("day", 1)
	hud_cred_lbl.text = "%d  kreditter" % d.get("credits", 0)
	$UI/HUD/LocationLabel.text = d.get("moon_name", "Luna-7 Mining Station")

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

	# Gruvekart-overlay
	if _map_open:
		_draw_mining_map()

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

# ── Gruvekart-overlay ─────────────────────────────────────────────
func _draw_mining_map() -> void:
	var font    : Font = ThemeDB.fallback_font
	var scanner : bool = SaveManager.game_data.get("ground_scanner", false)
	var sites   : Array = SaveManager.game_data.get("drill_sites", [])

	# Mørk halvtransparent bakgrunn
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.03, 0.07, 0.94))
	# Panel-ramme
	draw_rect(Rect2(60, 58, 1160, 600), Color(0.07, 0.09, 0.16))
	draw_rect(Rect2(60, 58, 1160, 600), Color(0.25, 0.40, 0.65, 0.55), false, 2.0)

	# Tittel
	draw_string(font, Vector2(640, 44), "VELG BORESTED", HORIZONTAL_ALIGNMENT_CENTER,
		1280, 22, Color(0.55, 0.80, 1.00, 1.0))
	var sub : String = "Grunnskanner aktiv — sonekategorier synlige" if scanner else \
		"Trykk på et borested  ·  fargen gir et vagt hint om innholdet"
	draw_string(font, Vector2(640, 68), sub, HORIZONTAL_ALIGNMENT_CENTER,
		1280, 12, Color(0.55, 0.65, 0.75, 0.85))

	# Rutenett-linjer mellom siter
	for row in 3:
		for col in 4:
			var gx : float = 200.0 + col * 230.0
			var gy : float = 148.0 + row * 168.0
			draw_rect(Rect2(gx - 60, gy - 60, 120, 120),
				Color(0.12, 0.14, 0.22, 0.4))

	# Tegn hvert borested
	for i in sites.size():
		_draw_site(i, sites[i], scanner, font)

	# Legende (bottom)
	var lx : float = 120.0
	for cat in ZONE_COLORS.keys():
		var lc : Color = ZONE_COLORS[cat]
		draw_circle(Vector2(lx + 7, 682), 7.0, lc)
		draw_string(font, Vector2(lx + 18, 687), cat, HORIZONTAL_ALIGNMENT_LEFT,
			90, 11, Color(0.7, 0.7, 0.7, 0.8))
		lx += 110.0

	# Avbryt-instruksjon
	draw_string(font, Vector2(640, 710), "[Klikk utenfor et punkt for å avbryte]",
		HORIZONTAL_ALIGNMENT_CENTER, 1280, 11, Color(0.4, 0.45, 0.5, 0.7))

func _draw_site(idx: int, site: Dictionary, scanner: bool, font: Font) -> void:
	var cat   : String  = site.get("category", "Mineral")
	var col   : Color   = ZONE_COLORS.get(cat, Color(0.5, 0.5, 0.5))
	var pos   : Vector2 = _drill_site_pos(idx)
	var hover : bool    = (idx == _map_hovered)
	var pulse : float   = sin(_time * 2.3 + idx * 0.9) * 0.5 + 0.5

	# Ytre glow
	var gr : float = 52.0 + pulse * 14.0 + (10.0 if hover else 0.0)
	draw_circle(pos, gr,        Color(col.r, col.g, col.b, 0.10 + pulse * 0.05))
	draw_circle(pos, gr * 0.6,  Color(col.r, col.g, col.b, 0.18 + pulse * 0.07))

	# Kjerne
	var cr : float = 28.0 + (7.0 if hover else 0.0)
	draw_circle(pos, cr, Color(col.r * 0.45, col.g * 0.45, col.b * 0.45))
	draw_circle(pos, cr * 0.72, col)

	# Senterdot / drillpunkt
	draw_circle(pos, 5.5, Color(1.0, 1.0, 1.0, 0.85))
	draw_line(pos, pos + Vector2(0.0, 22.0), Color(0.75, 0.75, 0.75, 0.7), 2.0)

	# Nummerlabel
	draw_string(font, pos + Vector2(-4.0, 5.0), str(idx + 1),
		HORIZONTAL_ALIGNMENT_LEFT, 20, 10, Color(0.15, 0.15, 0.15, 0.9))

	# Scanner-info (enten kategori eller vag hint)
	if scanner:
		draw_string(font, pos + Vector2(-40.0, cr + 16.0), cat,
			HORIZONTAL_ALIGNMENT_LEFT, 80, 11, Color(0.9, 0.95, 0.9, 0.9))
	else:
		# Vag hint: kategori-initial + "..."
		var vague : String = cat.substr(0, 1).to_upper() + "?"
		draw_string(font, pos + Vector2(-8.0, cr + 16.0), vague,
			HORIZONTAL_ALIGNMENT_LEFT, 40, 11, Color(col.r, col.g, col.b, 0.7))
