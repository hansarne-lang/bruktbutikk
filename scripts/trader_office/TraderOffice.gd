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
	},
	2: {
		"name":       "Zyla",
		"multiplier": 0.90,
		"body_col":   Color(0.55, 0.42, 0.18),
		"head_col":   Color(0.62, 0.50, 0.22),
		"accent":     Color(1.0,  0.85, 0.3),
		"greeting":   "Velkommen til Zyla Station. Vi betaler godt.",
	},
}

var _time    : float = 0.0
var _chosen  : int   = 1
var _td      : Dictionary = {}

@onready var trader_lbl  : Label  = $UI/TraderLabel
@onready var greeting_lbl: Label  = $UI/GreetingLabel
@onready var offer_lbl   : Label  = $UI/OfferLabel
@onready var cargo_lbl   : Label  = $UI/CargoLabel
@onready var sell_btn    : Button = $UI/ButtonPanel/SellButton
@onready var home_btn    : Button = $UI/ButtonPanel/HomeButton

func _ready() -> void:
	_chosen = SaveManager.game_data.get("chosen_trader", 1)
	_td     = TRADERS.get(_chosen, TRADERS[1])

	trader_lbl.text   = _td["name"]
	greeting_lbl.text = "\"" + _td["greeting"] + "\""

	var earned : int = _calculate_earnings(_td["multiplier"])
	if earned > 0:
		offer_lbl.text = "Tilbud:  %d  kreditter  (%d%% av baseverdi)" % [earned, int(_td["multiplier"] * 100)]
	else:
		offer_lbl.text = "Du har ingenting aa selge."

	_refresh_cargo()

	sell_btn.pressed.connect(_sell)
	home_btn.pressed.connect(_go_home)

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _calculate_earnings(multiplier: float) -> int:
	var tanks  : Array = SaveManager.game_data.get("tanks", [])
	var earned : int   = 0
	for tank in tanks:
		var mid : String = tank.get("mineral_id", "")
		var amt : int    = tank.get("amount", 0)
		if mid == "" or amt == 0:
			continue
		var val : int = int(DataLoader.get_mineral(mid).get("base_value", 0))
		earned += int(float(val) * float(amt) * multiplier)
	return earned

func _refresh_cargo() -> void:
	var tanks : Array = SaveManager.game_data.get("tanks", [])
	var lines : PackedStringArray = []
	for t in tanks:
		var mid  : String = t.get("mineral_id", "")
		var amt  : int    = t.get("amount", 0)
		if mid != "" and amt > 0:
			var mname : String = DataLoader.get_mineral(mid).get("name", mid)
			var val   : int    = int(DataLoader.get_mineral(mid).get("base_value", 0))
			var total : int    = int(float(val) * float(amt) * _td["multiplier"])
			lines.append("  %s  ×%d  →  %d kr" % [mname, amt, total])
	if lines.is_empty():
		cargo_lbl.text   = "Lasterom: tomt"
		sell_btn.disabled = true
	else:
		cargo_lbl.text = "Din last:\n" + "\n".join(lines)

func _sell() -> void:
	var earned : int = _calculate_earnings(_td["multiplier"])
	SaveManager.game_data["credits"]     = SaveManager.game_data.get("credits", 0) + earned
	SaveManager.game_data["trades_done"] = SaveManager.game_data.get("trades_done", 0) + 1
	SaveManager.game_data["day"]         = SaveManager.game_data.get("day", 1) + 1
	SaveManager.game_data["time_of_day"] = 0.0
	SaveManager.game_data["last_earned"] = earned
	SaveManager.game_data["last_trader"] = _td["name"]
	SaveManager.add_trade_log(earned, _td["name"])
	SaveManager.empty_tanks()
	SaveManager.save_game()
	SoundManager.play("kaching")
	get_tree().change_scene_to_file("res://scenes/base/Base.tscn")

func _go_home() -> void:
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://scenes/base/Base.tscn")

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
