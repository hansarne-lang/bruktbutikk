extends Node2D
## Void Miner – Overfart-scene
## #2  Tilfeldige hendelser
## #8  Skip-animasjon (letter fra basen)
## #13 Flere handlere med dialog

const SHIP_SPEED := 60.0

# Trader-data: multiplier og dialog
const TRADERS := {
	1: {
		"name":       "Grom Korrec",
		"multiplier": 0.70,
	},
	2: {
		"name":       "Zyla",
		"multiplier": 0.90,
	},
	3: {
		"name":       "Dypromstasjon",
		"multiplier": 1.00,
	},
}

# Tilfeldige hendelser (#2)
const EVENTS := [
	{
		"title":  "Asteroide-treff!",
		"text":   "En liten asteroide krasjer i lasteluken. Noe last forsvinner ut i rommet.",
		"effect": "lose_cargo",
		"amount": 0.20,
	},
	{
		"title":  "Motorfeil!",
		"text":   "Hovedmotoren havarerer. Crawl-fart mens du reparerer – noe last lekker ut.",
		"effect": "lose_cargo",
		"amount": 0.35,
	},
	{
		"title":  "Vennlig handelsskip!",
		"text":   "Et passerende skip tilbyr en liten kontant-bonus for navigasjonsdata.",
		"effect": "bonus_credits",
		"amount": 250,
	},
	{
		"title":  "Toll-skanning!",
		"text":   "En patruljefregatt scanner skipet. Alt er i orden – de lar deg passere.",
		"effect": "none",
		"amount": 0,
	},
	{
		"title":  "Meteorstorm foran!",
		"text":   "Radaren varsler et tett meteorbeltet rett i kursen. Styr skipet helskinnet igjennom!",
		"effect": "meteor_storm",
		"amount": 0,
	},
	{
		"title":  "Piratangrep!",
		"text":   "En ukjent fartøy trer frem fra mørket – og åpner ild!",
		"effect": "pirate_attack",
		"amount": 0,
	},
	{
		"title":  "🏴  Svart marked!",
		"text":   "Et mystisk fartøy blinker med stjernesignaler – svart markedsvarer til nedsatte priser. Risikabelt, men fristende.",
		"effect": "black_market",
		"amount": 0,
	},
]

# Svart marked-tilbud (fast liste, kjøpes direkte for kreditter)
const BLACK_MARKET_ITEMS : Array = [
	{"name": "Nano-reparasjonssett (−35%)", "cost": 7800,  "type": "tool",    "id": "nano_repair_kit"},
	{"name": "Nuke-torpedoer ×3 (−25%)",   "cost": 1125,  "type": "torpedo", "id": "torp_nuke",  "qty": 3},
	{"name": "Reaktor Nivå 2 (−30%)",       "cost": 4900,  "type": "comp_upg","id": "reactor_upg2",
	 "comp_id": "reactor", "new_level": 2},
	{"name": "Skjold Nivå 2 (−30%)",        "cost": 2450,  "type": "upg",     "id": "shield_lvl2"},
	{"name": "2. laserkanon (−20%)",         "cost": 4000,  "type": "upg",     "id": "cannon_2"},
]

var _bm_btn      : Button = null   # svart marked-kjøp-knapp (dynamisk)

var _stars         : Array = []
var _ship_x        : float = -120.0
var _ship_y        : float = 620.0   # Starter under skjermen (#8)
var _ship_y_target : float = 300.0
var _time          : float = 0.0
var _animating     : bool  = true

@onready var btn_sell   : Button = $UI/ButtonPanel/SellButton
@onready var btn_home   : Button = $UI/ButtonPanel/HomeButton
@onready var cargo_lbl  : Label  = $UI/CargoLabel
@onready var trader_lbl : Label  = $UI/TraderLabel
@onready var event_panel          = $UI/EventPanel
@onready var event_text : Label  = $UI/EventPanel/EventVBox/EventText
@onready var event_title: Label  = $UI/EventPanel/EventVBox/EventTitle
@onready var event_btn  : Button = $UI/EventPanel/EventVBox/EventButton

func _ready() -> void:
	for _i in 180:
		_stars.append({
			"x":   randf() * 1280,
			"y":   randf() * 590,
			"r":   randf_range(0.5, 2.0),
			"a":   randf_range(0.3, 1.0),
			"spd": randf_range(8.0, 32.0),
		})

	btn_sell.pressed.connect(_go_trader)
	btn_home.pressed.connect(_go_home)
	event_btn.pressed.connect(_dismiss_event)

	# Trader-info (#13)
	var chosen : int        = SaveManager.game_data.get("chosen_trader", 1)
	var td     : Dictionary = TRADERS.get(chosen, TRADERS[1])
	trader_lbl.text = "Kurs mot %s  (%d%% av baseverdi)" % [td["name"], int(td["multiplier"] * 100)]
	btn_sell.text   = "Ankom %s" % td["name"]

	_refresh_cargo()

	# Forbruk drivstoff ved avreise
	SaveManager.consume_travel_fuel(3)
	var fuel_left : int = SaveManager.game_data.get("fuel", 0)
	if fuel_left <= 0:
		cargo_lbl.text += "\n\n⚠  Tom for drivstoff! Kjøp mer hos neste trader."
	elif fuel_left <= 5:
		cargo_lbl.text += "\n\n⚠  Lavt drivstoff: %d enheter igjen." % fuel_left

	# Tilfeldig hendelse 40% sjanse, etter 2 sek (#2)
	if randf() < 0.40:
		await get_tree().create_timer(2.0).timeout
		_trigger_event()

func _process(delta: float) -> void:
	_time += delta

	# Skip-animasjon: letter opp fra basen (#8)
	if _animating:
		_ship_y = move_toward(_ship_y, _ship_y_target, delta * 230.0)
		if abs(_ship_y - _ship_y_target) < 1.0:
			_animating = false

	_ship_x = _ship_x + SHIP_SPEED * delta
	if _ship_x > 1400:
		_ship_x = -120.0

	for s in _stars:
		s["x"] -= s["spd"] * delta * 0.3
		if s["x"] < -4:
			s["x"] = 1284.0
			s["y"] = randf() * 590

	queue_redraw()

# ── Tilfeldige hendelser (#2) ─────────────────────────────────
func _trigger_event() -> void:
	var ev : Dictionary = EVENTS[randi() % EVENTS.size()]

	# Meteorstorm → bytt til mini-spill-scene umiddelbart
	if ev["effect"] == "meteor_storm":
		SaveManager.save_game()
		get_tree().change_scene_to_file("res://scenes/meteor_storm/MeteorStorm.tscn")
		return

	# Piratangrep → turbasert kamp
	if ev["effect"] == "pirate_attack":
		SaveManager.save_game()
		get_tree().change_scene_to_file("res://scenes/pirate_combat/PirateCombat.tscn")
		return

	# Svart marked → vis tilbud i event-panelet med ekstra kjøp-knapp
	if ev["effect"] == "black_market":
		# Velg et tilfeldig BM-tilbud
		var bm_item : Dictionary = BLACK_MARKET_ITEMS[randi() % BLACK_MARKET_ITEMS.size()]
		event_title.text = ev["title"]
		event_text.text  = ev["text"] + "\n\nTilbud: %s  –  %d kr" % [bm_item["name"], bm_item["cost"]]
		event_btn.text   = "Ignorer – reis forbi"
		# Dynamisk kjøp-knapp
		if _bm_btn:
			_bm_btn.queue_free()
		_bm_btn = Button.new()
		_bm_btn.text = "Kjøp  (%d kr)" % bm_item["cost"]
		_bm_btn.disabled = SaveManager.game_data.get("credits", 0) < bm_item["cost"]
		var captured_item : Dictionary = bm_item.duplicate()
		_bm_btn.pressed.connect(func() -> void: _do_black_market(captured_item))
		$UI/EventPanel/EventVBox.add_child(_bm_btn)
		event_panel.visible = true
		return

	event_title.text = "⚠  " + ev["title"]
	event_text.text  = ev["text"]

	match ev["effect"]:
		"lose_cargo":
			var tanks : Array = SaveManager.game_data.get("tanks", [])
			for tank in tanks:
				var loss : int = int(float(tank.get("amount", 0)) * float(ev["amount"]))
				tank["amount"] = max(0, tank.get("amount", 0) - loss)
			event_text.text += "\n\n(Du mistet deler av lasten.)"
			_refresh_cargo()
		"bonus_credits":
			var bonus : int = int(ev["amount"])
			SaveManager.game_data["credits"] = SaveManager.game_data.get("credits", 0) + bonus
			event_text.text += "\n\n(+%d kr lagt til.) " % bonus
		"none":
			# Toll: straff hvis svart marked-varer om bord
			if SaveManager.game_data.get("black_market_heat", false):
				var toll : int = 400
				SaveManager.game_data["credits"] = max(0, SaveManager.game_data.get("credits", 0) - toll)
				SaveManager.game_data["black_market_heat"] = false
				event_title.text = "🚨  Toll-kontroll – ulovlige varer oppdaget!"
				event_text.text  = "Patruljeskipet fant smuglervarer om bord. Bot: −%d kr. Varene konfiskert." % toll

	event_panel.visible = true

func _dismiss_event() -> void:
	event_panel.visible = false
	if _bm_btn:
		_bm_btn.queue_free()
		_bm_btn = null
	event_btn.text = "OK – fortsett"

func _do_black_market(bm_item: Dictionary) -> void:
	var cost : int = bm_item.get("cost", 0)
	if SaveManager.game_data.get("credits", 0) < cost:
		return
	SaveManager.game_data["credits"] = SaveManager.game_data.get("credits", 0) - cost
	SaveManager.game_data["black_market_heat"] = true
	# Lever varen
	match bm_item.get("type", ""):
		"tool":
			var tools : Array = SaveManager.game_data.get("repair_tools", [])
			if bm_item["id"] not in tools:
				tools.append(bm_item["id"])
			SaveManager.game_data["repair_tools"] = tools
		"torpedo":
			var td  : Dictionary = SaveManager.game_data.get("torpedoes", {})
			var tid : String     = bm_item["id"].substr(5)   # "torp_nuke" → "nuke"
			td[tid] = td.get(tid, 0) + bm_item.get("qty", 1)
			SaveManager.game_data["torpedoes"] = td
		"comp_upg":
			for comp in SaveManager.game_data.get("ship_components", []):
				if comp.get("id", "") == bm_item.get("comp_id", ""):
					comp["level"] = max(comp.get("level", 1), bm_item.get("new_level", 2))
					break
		"upg":
			match bm_item["id"]:
				"shield_lvl2":
					SaveManager.game_data["shield_level"] = max(SaveManager.game_data.get("shield_level", 1), 2)
				"cannon_2":
					SaveManager.game_data["laser_cannons"] = max(SaveManager.game_data.get("laser_cannons", 1), 2)
	SaveManager.save_game()
	event_text.text = "Kjøp fullfort: %s\n\n(Advarsel: varene er ulovlige – forvent toll-kontroller!)" % bm_item["name"]
	if _bm_btn:
		_bm_btn.disabled = true

# ── Ankommer trader – gå til kontoret for forhandling ────────
func _go_trader() -> void:
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://scenes/trader_office/TraderOffice.tscn")

func _go_home() -> void:
	get_tree().change_scene_to_file("res://scenes/base/Base.tscn")

func _refresh_cargo() -> void:
	var tanks : Array = SaveManager.game_data.get("tanks", [])
	var lines : PackedStringArray = []
	for t in tanks:
		var mid  : String = t.get("mineral_id", "")
		var amt  : int    = t.get("amount", 0)
		if mid != "" and amt > 0:
			var name : String = DataLoader.get_mineral(mid).get("name", mid)
			lines.append("  %s:  %d enheter" % [name, amt])
	cargo_lbl.text = "Lasterom: tomt" if lines.is_empty() else "Lasterom:\n" + "\n".join(lines)

# ── Tegning ──────────────────────────────────────────────────
func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 590), Color(0.01, 0.01, 0.06))

	for s in _stars:
		draw_circle(Vector2(s["x"], s["y"]), s["r"], Color(1, 1, 1, s["a"]))

	var pulse : float = (sin(_time * 0.4) + 1.0) * 0.5
	draw_circle(Vector2(980, 180), 120 + pulse * 12, Color(0.15, 0.08, 0.28, 0.18 + pulse * 0.05))
	draw_circle(Vector2(980, 180), 70  + pulse * 6,  Color(0.20, 0.10, 0.35, 0.22))

	draw_circle(Vector2(200, 100), 55, Color(0.28, 0.22, 0.38))
	draw_circle(Vector2(200, 100), 55, Color(0.35, 0.28, 0.48, 0.5), false, 2.0)
	draw_line(Vector2(135, 118), Vector2(265, 82), Color(0.5, 0.4, 0.6, 0.6), 3.0)

	_draw_ship(_ship_x, _ship_y)

	var glow_a : float = 0.5 + sin(_time * 8.0) * 0.3
	var boost  : float = 2.0 if _animating else 1.0
	draw_circle(Vector2(_ship_x - 60, _ship_y + 12),
		14.0 + sin(_time * 12) * 3, Color(0.4, 0.6, 1.0, glow_a * 0.7 * boost))
	draw_circle(Vector2(_ship_x - 60, _ship_y + 12),
		6.0, Color(0.8, 0.9, 1.0, glow_a * boost))

func _draw_ship(cx: float, cy: float) -> void:
	var C_HULL := Color(0.55, 0.65, 0.75)
	var C_WIN  := Color(0.4,  0.7,  0.9, 0.8)
	var C_WING := Color(0.65, 0.72, 0.80)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 60, cy + 10), Vector2(cx + 60, cy),
		Vector2(cx + 60, cy + 20), Vector2(cx - 60, cy + 28),
	]), C_HULL)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx + 60, cy), Vector2(cx + 60, cy + 20), Vector2(cx + 90, cy + 10),
	]), C_WING)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 10, cy), Vector2(cx + 20, cy),
		Vector2(cx + 10, cy - 26), Vector2(cx - 20, cy - 20),
	]), C_WING)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 10, cy + 28), Vector2(cx + 20, cy + 28),
		Vector2(cx + 10, cy + 52), Vector2(cx - 20, cy + 46),
	]), C_WING)
	draw_rect(Rect2(cx + 30, cy + 4, 22, 12), C_WIN)
	draw_rect(Rect2(cx + 33, cy + 5, 14,  6), Color(0.7, 0.9, 1.0, 0.5))
	draw_rect(Rect2(cx - 68, cy + 8, 10, 14), Color(0.4, 0.5, 0.6))
