extends Node2D
## Void Miner – Trader-kontor
## Spilleren ankommer trader-stasjonen og forhandler om salg.

const TRADERS := {
	1: {
		"name":       "Grom Korrec",
		"multiplier": 0.70,
		"body_col":   Color(0.30, 0.40, 0.58),
		"head_col":   Color(0.35, 0.48, 0.65),
		"accent":     Color(0.5,  0.7,  1.0),
		"greeting":   "Hei, hei! La meg se kva du har med deg...",
		"farewell":   "Bra gjort! Kom tilbake når tankene er fulle igjen.",
	},
	2: {
		"name":       "Zyla",
		"multiplier": 0.90,
		"body_col":   Color(0.55, 0.42, 0.18),
		"head_col":   Color(0.62, 0.50, 0.22),
		"accent":     Color(1.0,  0.85, 0.3),
		"greeting":   "Velkommen til Zyla Station. Vi betaler godt.",
		"farewell":   "En fornøyelse. Fly trygt.",
	},
}

var _time    : float = 0.0
var _chosen  : int   = 1
var _td      : Dictionary = {}

@onready var trader_lbl  : Label  = $UI/TraderLabel
@onready var greeting_lbl: Label  = $UI/GreetingLabel
@onready var offer_lbl   : Label  = $UI/OfferLabel
@onready var cargo_rows            = $UI/CargoPanel/CargoVBox/CargoScroll/CargoRows
@onready var sell_all_btn: Button  = $UI/CargoPanel/CargoVBox/SellAllBtn
@onready var home_btn    : Button  = $UI/ButtonPanel/HomeButton
@onready var travel_btn  : Button  = $UI/ButtonPanel/TravelButton
@onready var order_btn   : Button  = $UI/ButtonPanel/OrderButton
@onready var order_panel            = $UI/OrderPanel
@onready var catalog_vbox           = $UI/OrderPanel/VBox/Scroll/CatalogVBox

const ORDER_CATALOG := [
	# ── Reparasjonsverktøy ──────────────────────────────────────
	{"id": "basic_toolkit",     "name": "Basis verktøysett",
	 "desc": "+5 reparasjonsfart",         "cost": 600,   "days": 2, "type": "tool"},
	{"id": "calibrated_wrench", "name": "Kalibrert skiftenøkkel",
	 "desc": "+15 reparasjonsfart",        "cost": 3000,  "days": 3, "type": "tool"},
	{"id": "nano_repair_kit",   "name": "Nano-reparasjonssett",
	 "desc": "+35 reparasjonsfart",        "cost": 12000, "days": 5, "type": "tool"},
	# ── Komponentoppgraderinger ─────────────────────────────────
	{"id": "engine_upg2",     "name": "Drivverk – Nivå 2",
	 "desc": "Raskere mining, tåler mer",  "cost": 4000,  "days": 3,
	 "type": "comp_upg", "comp_id": "engine",       "new_level": 2},
	{"id": "drill_upg2",      "name": "Boresystem – Nivå 2",
	 "desc": "Bedre drill-effektivitet",   "cost": 3500,  "days": 3,
	 "type": "comp_upg", "comp_id": "drill_head",   "new_level": 2},
	{"id": "reactor_upg2",    "name": "Reaktor – Nivå 2",
	 "desc": "Reduserer skadeforsterkning","cost": 7000,  "days": 4,
	 "type": "comp_upg", "comp_id": "reactor",      "new_level": 2},
	{"id": "life_upg2",       "name": "Livsstøtte – Nivå 2",
	 "desc": "Høyere krit.-grense",        "cost": 2500,  "days": 3,
	 "type": "comp_upg", "comp_id": "life_support", "new_level": 2},
	{"id": "nav_upg2",        "name": "Navigasjon – Nivå 2",
	 "desc": "Bedre navigasjonsytelse",    "cost": 2500,  "days": 2,
	 "type": "comp_upg", "comp_id": "navigation",   "new_level": 2},
	# ── Skipoppgraderinger ──────────────────────────────────────
	{"id": "drill_upgraded",  "name": "Raskere drill",
	 "desc": "Halverer mine-intervall (2s)","cost": 1500,  "days": 1, "type": "upgrade"},
	{"id": "bigger_tanks",    "name": "Større tanker",
	 "desc": "Alle tanker økes til 100 kap","cost": 3000,  "days": 2, "type": "upgrade"},
	{"id": "ground_scanner",  "name": "Grunnskanner",
	 "desc": "90 % nøyaktighet på gruvekart","cost": 8000, "days": 3, "type": "upgrade"},
	{"id": "extra_tank_order","name": "Ekstra mineraltank",
	 "desc": "3. tank, 50 kap",            "cost": 2000,  "days": 3, "type": "upgrade"},
	# ── Laser og skjold ────────────────────────────────────────
	{"id": "battery_upgrade", "name": "Laser-batteri v2",
	 "desc": "Øker laserskade per kanon (1 → 2 per salve)",
	 "cost": 2500, "days": 1, "type": "upgrade"},
	{"id": "cannon_2",        "name": "2. laserkanon",
	 "desc": "Dobler laser-salver per kamptrinn",
	 "cost": 5000, "days": 3, "type": "upgrade"},
	{"id": "cannon_3",        "name": "3. laserkanon",
	 "desc": "Tredobler laser-salver per kamptrinn",
	 "cost": 12000,"days": 4, "type": "upgrade"},
	{"id": "shield_lvl2",     "name": "Skjold Nivå 2",
	 "desc": "Blokkerer 2 skade per piratangrep",
	 "cost": 3500, "days": 2, "type": "upgrade"},
	{"id": "shield_lvl3",     "name": "Skjold Nivå 3",
	 "desc": "Blokkerer 3 skade per piratangrep – nesten ugjennomtrengelig",
	 "cost": 8000, "days": 3, "type": "upgrade"},
	# ── Forbruksvarer ────────────────────────────────────────────
	{"id": "buy_fuel",     "name": "Drivstoff  (+10 enheter)",
	 "desc": "Fyller på 10 enheter drivstoff",      "cost": 300,  "days": 0, "type": "consumable"},
	{"id": "buy_supplies", "name": "Proviant  (+5 enheter)",
	 "desc": "Fyller på 5 enheter forsyninger",     "cost": 200,  "days": 0, "type": "consumable"},
]

func _ready() -> void:
	_chosen = SaveManager.game_data.get("chosen_trader", 1)
	_td     = TRADERS.get(_chosen, TRADERS[1])

	trader_lbl.text   = _td["name"]
	greeting_lbl.text = "\"" + _td["greeting"] + "\""
	offer_lbl.text    = "Kjøpspris: %d%% av baseverdi" % int(_td["multiplier"] * 100)

	_refresh_cargo_rows()

	sell_all_btn.pressed.connect(_sell_all)
	home_btn.pressed.connect(_go_home)
	travel_btn.pressed.connect(_go_map)
	order_btn.pressed.connect(_toggle_order_panel)
	$UI/OrderPanel/VBox/TitleRow/CloseBtn.pressed.connect(func(): order_panel.visible = false)

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

## Beregn verdi av ett mineral fra ship_cargo (inkl. daglig prismod)
func _item_value(mineral_id: String, amount: int) -> int:
	var val       : int   = int(DataLoader.get_mineral(mineral_id).get("base_value", 0))
	var price_mod : float = SaveManager.get_mineral_price_mod(mineral_id)
	return int(float(val) * float(amount) * _td["multiplier"] * price_mod)

## Oppfrisk cargo-radene med per-mineral selg-knapper
func _refresh_cargo_rows() -> void:
	for child in cargo_rows.get_children():
		child.queue_free()

	var cargo : Array = SaveManager.game_data.get("ship_cargo", [])
	var total : int   = 0

	if cargo.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "(Lasterom er tomt – last mineraler om bord fra basen)"
		empty_lbl.add_theme_font_size_override("font_size", 13)
		empty_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		cargo_rows.add_child(empty_lbl)
		sell_all_btn.disabled = true
		return

	for item in cargo:
		var mid : String = item.get("mineral_id", "")
		var amt : int    = item.get("amount",     0)
		if mid == "" or amt == 0:
			continue
		var val : int = _item_value(mid, amt)
		total        += val

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var price_mod : float = SaveManager.get_mineral_price_mod(mid)
		var pct_diff  : int   = int((price_mod - 1.0) * 100.0)
		var price_str : String
		if pct_diff > 0:
			price_str = " [+%d%%]" % pct_diff
		elif pct_diff < 0:
			price_str = " [%d%%]" % pct_diff
		else:
			price_str = ""

		var info := Label.new()
		info.text = "%s  ×%d  →  %d kr%s" % [
			DataLoader.get_mineral(mid).get("name", mid), amt, val, price_str]
		info.custom_minimum_size = Vector2(500, 0)
		info.add_theme_font_size_override("font_size", 13)
		var row_col := Color(0.85, 0.95, 0.75)
		if price_mod > 1.05:   row_col = Color(0.6, 1.0, 0.5)
		elif price_mod < 0.95: row_col = Color(1.0, 0.6, 0.5)
		info.add_theme_color_override("font_color", row_col)

		var sell_btn := Button.new()
		sell_btn.text = "Selg"
		sell_btn.custom_minimum_size = Vector2(80, 0)
		var m : String = mid
		var v : int    = val
		sell_btn.pressed.connect(func() -> void: _sell_item(m, v))

		row.add_child(info)
		row.add_child(sell_btn)
		cargo_rows.add_child(row)

	# Totallinje
	var total_lbl := Label.new()
	total_lbl.text = "Totalverdi:  %d kr" % total
	total_lbl.add_theme_font_size_override("font_size", 14)
	total_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
	cargo_rows.add_child(total_lbl)

	sell_all_btn.disabled = false

## Selg ett mineral
func _sell_item(mineral_id: String, value: int) -> void:
	SaveManager.game_data["credits"] = SaveManager.game_data.get("credits", 0) + value
	var cargo : Array = SaveManager.game_data.get("ship_cargo", [])
	for i in cargo.size():
		if cargo[i].get("mineral_id", "") == mineral_id:
			cargo.remove_at(i)
			break
	SaveManager.game_data["ship_cargo"] = cargo
	SoundManager.play("kaching")
	var mname : String = DataLoader.get_mineral(mineral_id).get("name", mineral_id)
	greeting_lbl.text = "\"+%d kr for %s!\"" % [value, mname]
	offer_lbl.text    = "Kjøpspris: %d%% av baseverdi  ·  +%d kr" % [int(_td["multiplier"] * 100), value]
	SaveManager.save_game()
	_refresh_cargo_rows()
	_maybe_show_depart_options()

## Selg alt i lasterom
func _sell_all() -> void:
	var cargo  : Array = SaveManager.game_data.get("ship_cargo", [])
	var earned : int   = 0
	for item in cargo:
		earned += _item_value(item.get("mineral_id", ""), item.get("amount", 0))
	if earned == 0:
		return
	SaveManager.game_data["credits"]     = SaveManager.game_data.get("credits", 0) + earned
	SaveManager.game_data["trades_done"] = SaveManager.game_data.get("trades_done", 0) + 1
	SaveManager.game_data["last_earned"] = earned
	SaveManager.game_data["last_trader"] = _td["name"]
	SaveManager.add_trade_log(earned, _td["name"])   # logg FØR dag-økning
	SaveManager.game_data["day"]         = SaveManager.game_data.get("day", 1) + 1
	SaveManager.game_data["time_of_day"] = 0.0
	SaveManager.empty_ship_cargo()
	SaveManager.refresh_mineral_prices()
	SaveManager.update_zone_discovery()
	SaveManager.consume_daily_supplies()
	SaveManager.save_game()
	SoundManager.play("kaching")
	offer_lbl.text    = "Salg fullfort!  +%d kreditter" % earned
	greeting_lbl.text = "\"%s\"" % _td.get("farewell", "Takk for handelen!")
	sell_all_btn.disabled = true
	_refresh_cargo_rows()
	_maybe_show_depart_options()

func _maybe_show_depart_options() -> void:
	var cargo : Array = SaveManager.game_data.get("ship_cargo", [])
	if cargo.is_empty():
		home_btn.text      = "Reis hjem"
		travel_btn.visible = true

func _go_home() -> void:
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://scenes/base/Base.tscn")

func _go_map() -> void:
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://scenes/map/Map.tscn")

# ── Bestillingskatalog ────────────────────────────────────────
func _toggle_order_panel() -> void:
	order_panel.visible = not order_panel.visible
	if order_panel.visible:
		_refresh_order_panel()

func _refresh_order_panel() -> void:
	for child in catalog_vbox.get_children():
		child.queue_free()

	var d       : Dictionary = SaveManager.game_data
	var credits : int        = d.get("credits", 0)
	var orders  : Array      = d.get("pending_orders", [])
	var tools   : Array      = d.get("repair_tools", [])
	var comps   : Array      = d.get("ship_components", [])

	for item in ORDER_CATALOG:
		var iid   : String = item["id"]
		var cost  : int    = item["cost"]
		var days  : int    = item["days"]
		var row   := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var info := Label.new()
		info.custom_minimum_size = Vector2(500, 0)
		info.add_theme_font_size_override("font_size", 12)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(200, 0)

		# Bestem tilstand
		var pending_order : Dictionary = {}
		for o in orders:
			if o.get("item_id", "") == iid:
				pending_order = o
				break

		var already_have : bool = false
		if item["type"] == "tool":
			already_have = iid in tools
		elif item["type"] == "comp_upg":
			var need_lvl : int = item.get("new_level", 2)
			for c in comps:
				if c.get("id","") == item.get("comp_id","") and c.get("level",1) >= need_lvl:
					already_have = true
					break
		elif iid == "extra_tank_order":
			already_have = d.get("extra_tank", false)
		elif iid == "shield_lvl2":
			already_have = d.get("shield_level", 1) >= 2
		elif iid == "shield_lvl3":
			already_have = d.get("shield_level", 1) >= 3
		elif iid == "cannon_2":
			already_have = d.get("laser_cannons", 1) >= 2
		elif iid == "cannon_3":
			already_have = d.get("laser_cannons", 1) >= 3
		elif item["type"] == "upgrade":
			already_have = d.get(iid, false)
		# "consumable" – aldri already_have, kan alltid kjøpes

		if already_have:
			info.text = "%s – %s" % [item["name"], item["desc"]]
			info.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4, 1))
			btn.text     = "Mottatt ✓"
			btn.disabled = true
		elif not pending_order.is_empty():
			info.text = "%s – %s" % [item["name"], item["desc"]]
			info.add_theme_color_override("font_color", Color(0.8, 0.8, 0.4, 1))
			btn.text     = "Bestilt – dag %d" % pending_order.get("deliver_day", 0)
			btn.disabled = true
		else:
			if days == 0 and item.get("type", "") == "consumable":
				var cur_val : int = 0
				if iid == "buy_fuel":     cur_val = d.get("fuel", 0)
				elif iid == "buy_supplies": cur_val = d.get("supplies", 0)
				info.text = "%s – %s  (%d kr, øyeblikkelig)  [nå: %d]" % [
					item["name"], item["desc"], cost, cur_val]
			elif days == 0:
				info.text = "%s – %s  (%d kr, øyeblikkelig)" % [
					item["name"], item["desc"], cost]
			else:
				info.text = "%s – %s  (%d kr,  %d dag%s levering)" % [
					item["name"], item["desc"], cost, days,
					"er" if days > 1 else ""]
			if credits < cost:
				info.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55, 1))
				btn.text     = "Kjøp  (%d kr)" % cost
				btn.disabled = true
			else:
				info.add_theme_color_override("font_color", Color(0.85, 0.9, 0.85, 1))
				btn.text     = "Kjøp  (%d kr)" % cost
				btn.disabled = false
				var captured : Dictionary = item.duplicate(true)
				btn.pressed.connect(func() -> void: _place_order(captured))

		row.add_child(info)
		row.add_child(btn)
		catalog_vbox.add_child(row)

func _place_order(item: Dictionary) -> void:
	var cost : int = item.get("cost", 0)
	if SaveManager.game_data.get("credits", 0) < cost:
		return

	# Forbruksvarer – øyeblikkelig levering, ikke i bestillingskø
	if item.get("type", "") == "consumable":
		SaveManager.game_data["credits"] = SaveManager.game_data.get("credits", 0) - cost
		match item["id"]:
			"buy_fuel":
				SaveManager.game_data["fuel"] = SaveManager.game_data.get("fuel", 0) + 10
				offer_lbl.text = "Drivstoff påfylt: +10 enheter  (%d kr)" % cost
			"buy_supplies":
				SaveManager.game_data["supplies"] = SaveManager.game_data.get("supplies", 0) + 5
				offer_lbl.text = "Proviant kjøpt: +5 enheter  (%d kr)" % cost
		SaveManager.save_game()
		_refresh_order_panel()
		return

	var extra := {}
	if item.has("comp_id"):
		extra["comp_id"]   = item["comp_id"]
		extra["new_level"] = item.get("new_level", 2)
	SaveManager.place_order(
		item["id"], item["name"], cost, item["days"], extra)
	SaveManager.save_game()
	if item["days"] == 0:
		offer_lbl.text = "Kjøpt: %s" % item["name"]
	else:
		offer_lbl.text = "Bestilt: %s  –  leveres om %d dag(er)" % [
			item["name"], item["days"]]
	_refresh_order_panel()

# ── Tegning ──────────────────────────────────────────────────
func _draw() -> void:
	var accent : Color = _td.get("accent", Color(0.5, 0.7, 1.0))

	# ── Bakgrunn: stasjonens handelsrom ──────────────────────
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.05, 0.04, 0.09))

	# Vegger – paneler
	draw_rect(Rect2(0, 40, 1280, 420), Color(0.09, 0.07, 0.14))
	for i in 8:
		var px : float = i * 160.0
		draw_rect(Rect2(px + 6, 50, 148, 400), Color(0.11, 0.09, 0.17))
		draw_rect(Rect2(px, 40, 6, 420), Color(0.06, 0.05, 0.10))
	draw_rect(Rect2(0, 100, 1280, 3), Color(0.06, 0.05, 0.10))
	draw_rect(Rect2(0, 330, 1280, 3), Color(0.06, 0.05, 0.10))

	# Takbelysning
	for i in 5:
		var lx : float = 80.0 + i * 240.0
		draw_rect(Rect2(lx, 44, 120, 8), Color(accent.r, accent.g, accent.b, 0.35))
		draw_rect(Rect2(lx + 10, 46, 100, 4), Color(accent.r, accent.g, accent.b, 0.65))
		draw_colored_polygon(PackedVector2Array([
			Vector2(lx,       52),
			Vector2(lx + 120, 52),
			Vector2(lx + 160, 100),
			Vector2(lx - 40,  100),
		]), Color(accent.r, accent.g, accent.b, 0.04))

	# Gulv
	draw_rect(Rect2(0, 460, 1280, 260), Color(0.08, 0.06, 0.13))
	for gx in range(0, 1281, 80):
		draw_line(Vector2(gx, 460), Vector2(gx, 720),
			Color(accent.r, accent.g, accent.b, 0.10), 1.0)
	for gy in range(460, 721, 65):
		draw_line(Vector2(0, gy), Vector2(1280, gy),
			Color(accent.r, accent.g, accent.b, 0.10), 1.0)
	draw_rect(Rect2(0, 458, 1280, 4), Color(accent.r, accent.g, accent.b, 0.40))

	# Disk (counter)
	draw_rect(Rect2(280, 360, 720, 130), Color(0.12, 0.09, 0.20))
	draw_rect(Rect2(280, 360, 720, 12),  Color(accent.r * 0.6, accent.g * 0.6, accent.b * 0.6))
	draw_rect(Rect2(280, 360, 8, 130),   Color(0.18, 0.14, 0.28))
	draw_rect(Rect2(992, 360, 8, 130),   Color(0.18, 0.14, 0.28))
	# Detaljer på disk
	draw_rect(Rect2(370, 375, 200, 60),  Color(0.07, 0.05, 0.12))
	draw_rect(Rect2(374, 379, 192, 52),  Color(0.04, 0.10, 0.20, 0.6))
	for sl in 5:
		var sy2 : float = 383 + sl * 9.0
		var w2  : float = 80.0 + sin(_time * 1.1 + sl * 0.7) * 60.0
		draw_rect(Rect2(378, sy2, w2, 3), Color(accent.r, accent.g, accent.b, 0.45))
	draw_rect(Rect2(590, 378, 80, 22),   Color(0.08, 0.06, 0.14))
	draw_rect(Rect2(596, 384, 68, 10),   Color(accent.r * 0.4, accent.g * 0.4, 0.05))

	# Pulserende glow bak trader
	var pulse : float = sin(_time * 1.8) * 0.5 + 0.5
	draw_circle(Vector2(830, 280),
		90 + pulse * 12,
		Color(accent.r, accent.g, accent.b, 0.07 + pulse * 0.04))

	# Trader-figur (bak disken)
	_draw_trader(Vector2(830, 340))

	# Vindu til høyre (stjerner)
	draw_rect(Rect2(1050, 80, 180, 220), Color(0.01, 0.01, 0.06))
	draw_rect(Rect2(1050, 80, 180, 220), Color(accent.r, accent.g, accent.b, 0.25), false, 4.0)
	for s_i in 18:
		var sx : float = 1058 + fmod(float(s_i) * 37.3 + _time * 0.5, 164.0)
		var sy : float = 88   + fmod(float(s_i) * 53.7, 204.0)
		draw_circle(Vector2(sx, sy), randf_range(0.5, 1.5), Color(1, 1, 1, 0.6))

func _draw_trader(pos: Vector2) -> void:
	var body_col : Color = _td.get("body_col", Color(0.4, 0.5, 0.6))
	var head_col : Color = _td.get("head_col", Color(0.45, 0.55, 0.65))
	var accent   : Color = _td.get("accent",   Color(0.5, 0.7, 1.0))

	# Kropp (bak disk, halvt synlig)
	draw_colored_polygon(PackedVector2Array([
		Vector2(pos.x - 48, pos.y + 20),
		Vector2(pos.x + 48, pos.y + 20),
		Vector2(pos.x + 36, pos.y - 90),
		Vector2(pos.x - 36, pos.y - 90),
	]), body_col)
	# Krage/jakke-linje
	draw_colored_polygon(PackedVector2Array([
		Vector2(pos.x - 20, pos.y - 90),
		Vector2(pos.x + 20, pos.y - 90),
		Vector2(pos.x + 10, pos.y - 68),
		Vector2(pos.x,      pos.y - 58),
		Vector2(pos.x - 10, pos.y - 68),
	]), Color(accent.r * 0.6, accent.g * 0.6, accent.b * 0.6))
	# Hode
	draw_circle(pos + Vector2(0, -115), 40, head_col)
	# Øyne
	if _chosen == 2:
		# Zyla – tre øyne
		draw_circle(pos + Vector2(-16, -120), 7, Color(0.05, 0.05, 0.05))
		draw_circle(pos + Vector2(16,  -120), 7, Color(0.05, 0.05, 0.05))
		draw_circle(pos + Vector2(0,   -108), 5, Color(0.05, 0.05, 0.05))
		draw_circle(pos + Vector2(-16, -120), 4, accent)
		draw_circle(pos + Vector2(16,  -120), 4, accent)
		draw_circle(pos + Vector2(0,   -108), 3, accent)
	else:
		# Grom Korrec – to øyne, brede
		draw_circle(pos + Vector2(-14, -118), 8, Color(0.05, 0.05, 0.05))
		draw_circle(pos + Vector2(14,  -118), 8, Color(0.05, 0.05, 0.05))
		draw_circle(pos + Vector2(-14, -118), 4, accent)
		draw_circle(pos + Vector2(14,  -118), 4, accent)
	# Armer på disk
	draw_colored_polygon(PackedVector2Array([
		Vector2(pos.x - 36, pos.y - 70),
		Vector2(pos.x - 24, pos.y - 52),
		Vector2(pos.x - 72, pos.y + 18),
		Vector2(pos.x - 88, pos.y + 10),
	]), body_col)
	draw_colored_polygon(PackedVector2Array([
		Vector2(pos.x + 36, pos.y - 70),
		Vector2(pos.x + 24, pos.y - 52),
		Vector2(pos.x + 72, pos.y + 18),
		Vector2(pos.x + 88, pos.y + 10),
	]), body_col)
	# Hender (på disken)
	draw_circle(pos + Vector2(-80, 22), 12, head_col)
	draw_circle(pos + Vector2(80,  22), 12, head_col)
