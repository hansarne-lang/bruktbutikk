extends Node2D
## Void Miner – Motorrom-scene
## Spilleren kan gå rundt og interagere med skipets 5 komponenter.

const SPEED         := 220.0
const INTERACT_DIST := 95.0
const REPAIR_TICK   := 3.0   # sekunder per reparasjons-tikk

# Komponent-stasjoner: posisjon og id
const STATIONS : Array = [
	{"id": "engine",       "name": "Drivverk",   "x": 175.0},
	{"id": "reactor",      "name": "Reaktor",    "x": 320.0},
	{"id": "drill_head",   "name": "Boresystem", "x": 465.0},
	{"id": "life_support", "name": "Livsstøtte", "x": 610.0},
	{"id": "navigation",   "name": "Navigasjon", "x": 755.0},
	{"id": "shield",       "name": "Skjold",     "x": 900.0},
	{"id": "laser_cannon", "name": "Laserkanon", "x": 1045.0},
	{"id": "torpedo",      "name": "Torpedorør", "x": 1190.0},
]
const EXIT_X : float = 85.0   # dør tilbake til skipets rom

var _time            : float = 0.0
var _near_station    : int   = -1
var _near_exit       : bool  = false
var _panel_open      : bool  = false
var _repair_active   : bool  = false
var _repair_target   : int   = -1   # indeks i STATIONS
var _repair_progress : float = 0.0

@onready var player          : Sprite2D    = $Player
@onready var interact_prompt               = $UI/InteractPrompt
@onready var interact_label  : Label       = $UI/InteractPrompt/InteractLabel
@onready var repair_panel                  = $UI/RepairPanel
@onready var rp_title        : Label       = $UI/RepairPanel/VBox/TitleLabel
@onready var rp_cond         : Label       = $UI/RepairPanel/VBox/CondLabel
@onready var rp_bar          : ProgressBar = $UI/RepairPanel/VBox/CondBar
@onready var rp_status       : Label       = $UI/RepairPanel/VBox/StatusLabel
@onready var rp_repair_btn   : Button      = $UI/RepairPanel/VBox/RepairBtn
@onready var rp_close_btn    : Button      = $UI/RepairPanel/VBox/CloseBtn

func _ready() -> void:
	$UI/HUD/BackButton.pressed.connect(_go_back)
	rp_repair_btn.pressed.connect(_on_repair_pressed)
	rp_close_btn.pressed.connect(func() -> void:
		repair_panel.visible = false
		_panel_open = false)

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

	# Bevegelse (blokkert når panel er åpent)
	if not _panel_open:
		var dir : float = 0.0
		if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
			dir = -1.0
			player.flip_h = true
		elif Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
			dir = 1.0
			player.flip_h = false
		player.position.x = clamp(player.position.x + dir * SPEED * delta, 30.0, 1255.0)

	# Finn nærmeste stasjon
	_near_station = -1
	_near_exit    = false
	var min_dist  : float = INTERACT_DIST
	for i in STATIONS.size():
		var d : float = abs(player.position.x - float(STATIONS[i]["x"]))
		if d < min_dist:
			min_dist = d
			_near_station = i
	if _near_station == -1:
		if abs(player.position.x - EXIT_X) < INTERACT_DIST:
			_near_exit = true

	# Oppdater interact-prompt
	if not _panel_open:
		if _near_exit:
			interact_label.text    = "  [E]  Gå tilbake til skipet"
			interact_prompt.visible = true
		elif _near_station >= 0:
			var comp : Dictionary = _get_comp(STATIONS[_near_station]["id"])
			var cond : int        = comp.get("condition", 100)
			if cond >= 100:
				interact_label.text = "  [E]  %s – OK (100%%)" % STATIONS[_near_station]["name"]
			else:
				interact_label.text = "  [E]  Reparer %s  (%d%%)" % [STATIONS[_near_station]["name"], cond]
			interact_prompt.visible = true
		else:
			interact_prompt.visible = false
	else:
		interact_prompt.visible = false

	# Reparasjonstikk
	if _repair_active and _repair_target >= 0:
		_repair_progress += delta
		if _repair_progress >= REPAIR_TICK:
			_repair_progress -= REPAIR_TICK
			_do_repair_tick()
		if repair_panel.visible:
			_refresh_repair_panel()

# ── Tastaturinput ─────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not event is InputEventKey: return
	var key := event as InputEventKey
	if not key.pressed or key.echo: return
	if key.keycode == KEY_E:
		if _near_exit and not _panel_open:
			_go_back()
		elif _near_station >= 0 and not _panel_open:
			_open_repair_panel(_near_station)
			get_viewport().set_input_as_handled()
	elif key.keycode == KEY_ESCAPE:
		if _panel_open:
			repair_panel.visible = false
			_panel_open = false

# ── Reparasjonspanel ──────────────────────────────────────────
func _open_repair_panel(idx: int) -> void:
	_repair_target  = idx
	_panel_open     = true
	repair_panel.visible = true
	_refresh_repair_panel()

func _refresh_repair_panel() -> void:
	if _repair_target < 0:
		return
	var st    : Dictionary = STATIONS[_repair_target]
	var comp  : Dictionary = _get_comp(st["id"])
	var cond  : int        = comp.get("condition", 100)
	var lvl   : int        = comp.get("level", 1)
	var spd   : float      = SaveManager.get_repair_speed()
	var skill : float      = SaveManager.game_data.get("repair_skill", 0.0)

	rp_title.text    = "%s  [Nivå %d]" % [st["name"], lvl]
	rp_cond.text     = "Kondisjon: %d%%   |   Reparasjonsfart: %.0f/tikk   |   Ferdighet: %.1f" % [cond, spd, skill]
	rp_bar.value     = float(cond)
	rp_bar.modulate  = _cond_color(cond)

	if _repair_active and _repair_target >= 0:
		var pct : int = int(_repair_progress / REPAIR_TICK * 100.0)
		rp_repair_btn.text     = "Reparerer...  %d%%" % pct
		rp_repair_btn.disabled = true
		rp_status.text         = "Reparasjon pågår, vent..."
		rp_status.visible      = true
	elif cond >= 100:
		rp_repair_btn.text     = "Allerede i toppstand"
		rp_repair_btn.disabled = true
		rp_status.text         = "Ingen reparasjon nødvendig."
		rp_status.visible      = true
	else:
		rp_repair_btn.text     = "Start reparasjon"
		rp_repair_btn.disabled = false
		rp_status.visible      = false

func _on_repair_pressed() -> void:
	if _repair_target < 0:
		return
	_repair_active   = true
	_repair_progress = 0.0
	_refresh_repair_panel()

func _do_repair_tick() -> void:
	if _repair_target < 0:
		return
	var st_id : String = STATIONS[_repair_target]["id"]
	var spd   : float  = SaveManager.get_repair_speed()
	var comps : Array  = SaveManager.game_data.get("ship_components", [])
	for comp in comps:
		if comp.get("id", "") != st_id:
			continue
		var old_cond : int = comp.get("condition", 100)
		comp["condition"] = min(100, old_cond + int(spd))
		var skill : float = SaveManager.game_data.get("repair_skill", 0.0)
		SaveManager.game_data["repair_skill"] = min(10.0, skill + 0.05)
		if comp["condition"] >= 100:
			_repair_active   = false
			_repair_target   = -1
			_repair_progress = 0.0
			SaveManager.save_game()
		_refresh_repair_panel()
		break

# ── Hjelpere ──────────────────────────────────────────────────
func _get_comp(comp_id: String) -> Dictionary:
	for c in SaveManager.game_data.get("ship_components", []):
		if c.get("id", "") == comp_id:
			return c
	return {}

func _cond_color(cond: int) -> Color:
	if   cond > 70: return Color(0.3, 1.0, 0.4)
	elif cond > 35: return Color(1.0, 0.85, 0.2)
	else:           return Color(1.0, 0.30, 0.2)

func _cond_glow(cond: int) -> Color:
	if   cond > 70: return Color(0.20, 0.80, 0.35)
	elif cond > 35: return Color(0.90, 0.70, 0.10)
	else:           return Color(0.95, 0.20, 0.10)

func _go_back() -> void:
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://scenes/sprite_room/SpriteRoom.tscn")

# ══════════════════════════════════════════════════════════════
# PROSEDURAL TEGNING
# ══════════════════════════════════════════════════════════════
func _draw() -> void:
	var C_BG    := Color(0.04, 0.05, 0.07)
	var C_WALL  := Color(0.07, 0.09, 0.12)
	var C_PANEL := Color(0.09, 0.11, 0.15)
	var C_SEAM  := Color(0.03, 0.04, 0.06)
	var C_FLOOR := Color(0.06, 0.08, 0.10)
	var C_STEEL := Color(0.18, 0.21, 0.27)
	var C_ACC   := Color(0.20, 0.35, 0.65)

	# ── Bakgrunn ─────────────────────────────────────────────
	draw_rect(Rect2(0, 0, 1280, 720), C_BG)

	# ── Tak ──────────────────────────────────────────────────
	draw_rect(Rect2(0, 0, 1280, 72), Color(0.03, 0.04, 0.06))
	# Tykk rørledning
	draw_rect(Rect2(0, 18, 1280, 18), Color(0.16, 0.19, 0.25))
	draw_rect(Rect2(0, 20, 1280,  6), Color(0.25, 0.30, 0.42))
	draw_rect(Rect2(0, 46, 1280, 14), Color(0.13, 0.16, 0.21))
	draw_rect(Rect2(0, 48, 1280,  4), Color(0.20, 0.24, 0.34))
	# Rørfester
	for i in 11:
		var px : float = 40.0 + i * 120.0
		draw_rect(Rect2(px, 12, 22, 30), C_STEEL)
		draw_circle(Vector2(px + 11, 16), 5.5, Color(0.28, 0.32, 0.42))
	# Advarselstriper
	for i in 20:
		if i % 2 == 0:
			draw_rect(Rect2(i * 64.0, 0, 32, 12), Color(1.0, 0.65, 0.0, 0.18))
	# Lysribber
	for i in 5:
		var lx : float = 80.0 + i * 230.0
		draw_rect(Rect2(lx, 60, 100, 12), Color(0.55, 0.72, 1.0, 0.10))
		draw_rect(Rect2(lx + 8, 62, 84,  4), Color(0.65, 0.82, 1.0, 0.50))

	# ── Vegger ───────────────────────────────────────────────
	draw_rect(Rect2(0, 72, 1280, 420), C_WALL)
	for i in 9:
		var px : float = i * 142.0
		draw_rect(Rect2(px + 3, 78, 136, 406), C_PANEL)
		draw_rect(Rect2(px, 72, 3, 420), C_SEAM)
	draw_rect(Rect2(0, 155, 1280, 3), C_SEAM)
	draw_rect(Rect2(0, 340, 1280, 3), C_SEAM)
	# Horisontalt rør midt på vegg
	draw_rect(Rect2(130, 336, 1010, 10), Color(0.14, 0.17, 0.23))
	draw_rect(Rect2(130, 338, 1010,  4), Color(0.20, 0.25, 0.36))
	for i in 8:
		var cx : float = 160.0 + i * 130.0
		draw_rect(Rect2(cx, 332, 12, 18), Color(0.20, 0.24, 0.32))

	# ── Utgangsdør (venstre) ──────────────────────────────────
	draw_rect(Rect2(20, 330, 90, 162), Color(0.07, 0.09, 0.12))
	draw_rect(Rect2(23, 333, 84, 156), Color(0.05, 0.07, 0.10))
	# Dørramme
	draw_rect(Rect2(18, 328, 94, 166), C_ACC, false, 3.0)
	# Bjelke i midten
	draw_rect(Rect2(63, 333, 4, 156), Color(0.18, 0.22, 0.30))
	# Håndtak
	draw_rect(Rect2(72, 400, 5, 50), Color(0.40, 0.48, 0.60))
	draw_circle(Vector2(72, 400), 5,  Color(0.45, 0.55, 0.68))
	draw_circle(Vector2(72, 450), 5,  Color(0.45, 0.55, 0.68))
	# Exit-lampe (blinkende grønn)
	var door_p : float = (sin(_time * 1.8) + 1.0) * 0.5
	draw_circle(Vector2(120, 342), 7, Color(0.1, 0.9, 0.35, 0.5 + door_p * 0.4))
	draw_circle(Vector2(120, 342), 4, Color(0.3, 1.0, 0.55))

	# ── Gulv ─────────────────────────────────────────────────
	draw_rect(Rect2(0, 492, 1280, 228), C_FLOOR)
	for gx in range(0, 1281, 80):
		draw_line(Vector2(gx, 492), Vector2(gx, 610),
			Color(0.11, 0.13, 0.17, 0.85), 1.0)
	for gy in range(492, 611, 40):
		draw_line(Vector2(0, gy), Vector2(1280, gy),
			Color(0.11, 0.13, 0.17, 0.85), 1.0)
	draw_rect(Rect2(0, 489, 1280, 5), Color(C_ACC.r, C_ACC.g, C_ACC.b, 0.38))
	# Advarselsstriper gulv
	for i in range(0, 1280, 160):
		if (i / 160) % 2 == 0:
			draw_rect(Rect2(i, 492, 80, 7), Color(1.0, 0.65, 0.0, 0.07))
	# Nødlys langs gulv
	for nx in range(100, 1280, 140):
		var gl : float = (sin(_time * 2.0 + nx * 0.012) + 1.0) * 0.5
		draw_circle(Vector2(nx, 496), 4.0, Color(1.0, 0.15, 0.15, 0.4 + gl * 0.3))

	# ── 5 komponent-stasjoner ─────────────────────────────────
	for i in STATIONS.size():
		var st   : Dictionary = STATIONS[i]
		var cx   : float      = float(st["x"])
		var comp : Dictionary = _get_comp(st["id"])
		var cond : int        = comp.get("condition", 100)
		var lvl  : int        = comp.get("level", 1)
		var glow : Color      = _cond_glow(cond)
		var is_near : bool    = (_near_station == i)
		_draw_station(i, cx, cond, lvl, glow, is_near)

func _draw_station(idx: int, cx: float, cond: int, lvl: int,
		glow: Color, highlighted: bool) -> void:
	var C_BASE  := Color(0.12, 0.14, 0.18)
	var C_METAL := Color(0.16, 0.19, 0.25)
	var C_DARK  := Color(0.08, 0.09, 0.12)

	# Fremhev-halo (nær spilleren)
	if highlighted:
		draw_circle(Vector2(cx, 380), 80, Color(glow.r, glow.g, glow.b, 0.06))

	# ── Gulvplate ────────────────────────────────────────────
	draw_rect(Rect2(cx - 60, 462, 120, 30), C_BASE)
	draw_rect(Rect2(cx - 55, 457, 110,  8), C_METAL)
	draw_rect(Rect2(cx - 55, 457, 110,  2), Color(0.25, 0.30, 0.40))

	# ── Ulik visuell for hvert komponent ─────────────────────
	match idx:
		0: _draw_engine(cx, cond, lvl, glow)
		1: _draw_reactor(cx, cond, lvl, glow)
		2: _draw_drill(cx, cond, lvl, glow)
		3: _draw_life_support(cx, cond, lvl, glow)
		4: _draw_navigation(cx, cond, lvl, glow)
		5: _draw_shield(cx, cond, lvl, glow)
		6: _draw_laser_cannon(cx, cond, lvl, glow)
		7: _draw_torpedo(cx, cond, lvl, glow)

	# ── Kondisjon-bar under navneplaten ──────────────────────
	var bar_x : float = cx - 50.0
	draw_rect(Rect2(bar_x, 475, 100, 8), Color(0.08, 0.09, 0.12))
	var bar_w : float = float(clamp(cond, 0, 100))
	draw_rect(Rect2(bar_x, 475, bar_w, 8), Color(glow.r, glow.g, glow.b, 0.85))

	# ── Navneplate ───────────────────────────────────────────
	draw_rect(Rect2(cx - 52, 487, 104, 3), Color(glow.r, glow.g, glow.b, 0.4))

func _draw_engine(cx: float, cond: int, lvl: int, glow: Color) -> void:
	var C_BODY := Color(0.14, 0.16, 0.22)
	var C_RING := Color(0.20, 0.24, 0.32)

	# Tilkoblingsrør til tak
	draw_rect(Rect2(cx - 7, 72, 14, 240), Color(0.14, 0.17, 0.22))
	draw_rect(Rect2(cx - 3, 72,  6, 240), Color(0.18, 0.22, 0.30))

	# Hoveddel (trapezoidal motorblokk)
	var body := PackedVector2Array([
		Vector2(cx - 32, 310),
		Vector2(cx + 32, 310),
		Vector2(cx + 48, 460),
		Vector2(cx - 48, 460),
	])
	draw_colored_polygon(body, C_BODY)

	# Sidefinners
	for side in [-1, 1]:
		var fin := PackedVector2Array([
			Vector2(cx + side * 32, 320),
			Vector2(cx + side * 52, 295),
			Vector2(cx + side * 64, 390),
			Vector2(cx + side * 48, 420),
		])
		draw_colored_polygon(fin, Color(0.11, 0.13, 0.18))
		draw_polyline(fin, Color(0.20, 0.24, 0.32), 1.5)

	# Dyse (bunn)
	var noz := PackedVector2Array([
		Vector2(cx - 44, 460),
		Vector2(cx + 44, 460),
		Vector2(cx + 60, 492),
		Vector2(cx - 60, 492),
	])
	draw_colored_polygon(noz, Color(0.17, 0.20, 0.27))

	# Ringe rundt kroppen
	for ry in [330, 360, 400, 435]:
		var rw : float = 32.0 + (ry - 310.0) / 150.0 * 16.0
		draw_rect(Rect2(cx - rw - 2, ry, rw * 2 + 4, 6), C_RING)
		draw_rect(Rect2(cx - rw, ry + 1, rw * 2, 3), Color(0.24, 0.29, 0.40))

	# Indre kjerne
	draw_rect(Rect2(cx - 16, 318, 32, 130), Color(0.09, 0.11, 0.15))
	draw_circle(Vector2(cx, 383), 10, Color(glow.r, glow.g, glow.b, 0.4))
	draw_circle(Vector2(cx, 383),  6, Color(glow.r, glow.g, glow.b, 0.7))

	# Exhaust-glow
	var pulse : float = (sin(_time * 2.5) + 1.0) * 0.5
	draw_circle(Vector2(cx, 476), 40, Color(glow.r, glow.g, glow.b, 0.08 + pulse * 0.06))
	draw_circle(Vector2(cx, 480), 24, Color(glow.r, glow.g, glow.b, 0.18 + pulse * 0.12))
	draw_circle(Vector2(cx, 484), 12, Color(glow.r, glow.g, glow.b, 0.40 + pulse * 0.20))

	# Nivå-indikatorer
	for n in min(lvl, 3):
		draw_circle(Vector2(cx - 20 + n * 18, 308), 4, Color(0.35, 0.70, 1.0))

	# Skade-gnister
	if cond < 45 and int(_time * 4) % 3 == 0:
		draw_circle(Vector2(cx + randf_range(-30, 30), randf_range(330, 450)), 3,
			Color(1.0, 0.75, 0.15, 0.8))

func _draw_reactor(cx: float, cond: int, lvl: int, glow: Color) -> void:
	# Smal høy sylinder
	draw_rect(Rect2(cx - 8, 80, 16, 230), Color(0.14, 0.17, 0.23))
	draw_rect(Rect2(cx - 4, 80,  8, 230), Color(0.18, 0.22, 0.32))

	# Reaktorkropp
	draw_rect(Rect2(cx - 40, 200, 80, 260), Color(0.10, 0.12, 0.17))
	draw_rect(Rect2(cx - 36, 204, 72, 252), Color(0.08, 0.10, 0.14))

	# Glødende kjerne
	var pulse : float = (sin(_time * 1.8) + 1.0) * 0.5
	draw_circle(Vector2(cx, 330), 52, Color(glow.r, glow.g, glow.b, 0.05 + pulse * 0.04))
	draw_circle(Vector2(cx, 330), 36, Color(glow.r, glow.g, glow.b, 0.12 + pulse * 0.08))
	draw_circle(Vector2(cx, 330), 22, Color(glow.r, glow.g, glow.b, 0.30 + pulse * 0.15))
	draw_circle(Vector2(cx, 330), 10, Color(glow.r, glow.g, glow.b, 0.70 + pulse * 0.20))
	draw_circle(Vector2(cx, 330),  4, Color(1.0, 1.0, 1.0, 0.85))

	# Horisontale ringer
	for ry in [240, 270, 300, 330, 360, 390, 420]:
		draw_rect(Rect2(cx - 42, ry - 1, 84, 4), Color(0.16, 0.19, 0.26))
		draw_rect(Rect2(cx - 40, ry,     80, 2), Color(0.22, 0.26, 0.36))

	# Topp/bunn-kapsel
	draw_rect(Rect2(cx - 30, 195, 60, 10), Color(0.18, 0.22, 0.30))
	draw_rect(Rect2(cx - 30, 455, 60, 10), Color(0.18, 0.22, 0.30))

	# Side-rør
	for side in [-1, 1]:
		draw_rect(Rect2(cx + side * 40, 290, side * 30, 8), Color(0.16, 0.19, 0.25))
		draw_rect(Rect2(cx + side * 40, 370, side * 30, 8), Color(0.16, 0.19, 0.25))

	# Niv-indikatorer (blå prikker øverst)
	for n in min(lvl, 3):
		draw_circle(Vector2(cx - 16 + n * 16, 208), 4, Color(0.35, 0.70, 1.0))

	# Skade-effekt (flimring)
	if cond < 45:
		var flicker : float = (sin(_time * 18.0) + 1.0) * 0.5
		draw_circle(Vector2(cx, 330), 36, Color(1.0, 0.4, 0.1, 0.15 * flicker))

func _draw_drill(cx: float, cond: int, lvl: int, glow: Color) -> void:
	var mining : bool = SaveManager.game_data.get("mining_active", false)

	# Veggfeste øverst
	draw_rect(Rect2(cx - 55, 155, 110, 18), Color(0.15, 0.18, 0.24))
	draw_rect(Rect2(cx - 50, 159,  100, 8), Color(0.20, 0.24, 0.32))

	# Vertikalt arm
	draw_rect(Rect2(cx - 12, 173, 24, 200), Color(0.12, 0.14, 0.20))
	draw_rect(Rect2(cx -  5, 173, 10, 200), Color(0.16, 0.19, 0.27))

	# Drill-hode (roterende effekt – raskere ved aktiv mining)
	var speed      : float = 8.0 if mining else 2.0
	var rot_angle  : float = _time * speed * (float(cond) / 100.0)
	var dh_y       : float = 373.0
	draw_rect(Rect2(cx - 22, dh_y - 5, 44, 30), Color(0.18, 0.21, 0.28))
	draw_rect(Rect2(cx - 18, dh_y,     36, 20), Color(0.14, 0.17, 0.23))

	# Drill-bit (spiralform via linjer)
	var bit_col : Color = glow if not mining else Color(1.0, 0.55, 0.1)
	for i in 8:
		var a  : float = rot_angle + i * TAU / 8.0
		var r1 : float = 14.0
		var r2 : float = 5.0
		var y1 : float = dh_y + 25.0
		var y2 : float = dh_y + 55.0
		draw_line(
			Vector2(cx + cos(a) * r1, y1),
			Vector2(cx + cos(a + PI * 0.7) * r2, y2),
			Color(bit_col.r, bit_col.g, bit_col.b, 0.85), 2.0)

	# Drill-spiss
	var tip_col : Color = Color(0.24, 0.28, 0.36) if not mining \
		else Color(1.0, 0.45, 0.10).lerp(Color(0.8, 0.7, 0.2), 0.5 + sin(_time * 6.0) * 0.5)
	var tip := PackedVector2Array([
		Vector2(cx - 16, dh_y + 55),
		Vector2(cx + 16, dh_y + 55),
		Vector2(cx,      dh_y + 85),
	])
	draw_colored_polygon(tip, tip_col)
	draw_polyline(tip, Color(0.35, 0.42, 0.55), 1.5)

	# Glow rundt drill-hodet
	var pulse : float = (sin(_time * 3.0) + 1.0) * 0.5
	draw_circle(Vector2(cx, dh_y + 40), 30, Color(glow.r, glow.g, glow.b, 0.08 + pulse * 0.06))
	draw_circle(Vector2(cx, dh_y + 40), 18, Color(glow.r, glow.g, glow.b, 0.20 + pulse * 0.10))

	# Ekstra varme-glow og partikkeleffekt ved aktiv mining
	if mining:
		draw_circle(Vector2(cx, dh_y + 50), 40, Color(1.0, 0.4, 0.1, 0.12 + pulse * 0.10))
		draw_circle(Vector2(cx, dh_y + 60), 22, Color(1.0, 0.6, 0.2, 0.25 + pulse * 0.15))
		# Gnist-prikker
		if int(_time * 12) % 2 == 0:
			for _s in 3:
				draw_circle(
					Vector2(cx + randf_range(-18, 18), dh_y + randf_range(40, 85)),
					1.5 + randf() * 2.0, Color(1.0, 0.85, 0.3, 0.9))

	# Hydraulikk-sylindere (sidene)
	for side in [-1, 1]:
		draw_rect(Rect2(cx + side * 30, 220, 8, 130), Color(0.14, 0.17, 0.23))
		draw_rect(Rect2(cx + side * 32, 240, 4,  90), Color(0.20, 0.26, 0.36))

	# Nivå
	for n in min(lvl, 3):
		draw_circle(Vector2(cx - 16 + n * 16, 165), 4, Color(0.35, 0.70, 1.0))

	# Skade: drill stopper/gnister
	if cond < 45 and int(_time * 5) % 4 == 0:
		draw_circle(Vector2(cx + randf_range(-18, 18), dh_y + randf_range(20, 70)),
			2.5, Color(1.0, 0.80, 0.20, 0.9))

func _draw_life_support(cx: float, cond: int, lvl: int, glow: Color) -> void:
	# Sentralenhet (boks)
	draw_rect(Rect2(cx - 44, 200, 88, 262), Color(0.11, 0.13, 0.18))
	draw_rect(Rect2(cx - 40, 204, 80, 254), Color(0.09, 0.11, 0.15))

	# Oksygentanker (2 sylindere til høyre)
	for i in 2:
		var tx : float = cx + 54.0 + i * 30.0
		draw_rect(Rect2(tx, 240, 22, 160), Color(0.13, 0.16, 0.22))
		draw_rect(Rect2(tx + 2, 242, 18, 156), Color(0.10, 0.12, 0.16))
		draw_rect(Rect2(tx + 4, 244, 14, 30),
			Color(glow.r, glow.g, glow.b, 0.3 + 0.1 * i))
		draw_circle(Vector2(tx + 11, 243), 10, Color(0.14, 0.17, 0.23))
		draw_circle(Vector2(tx + 11, 399), 10, Color(0.14, 0.17, 0.23))
		# Rørkobling til sentralenhet
		draw_rect(Rect2(cx + 44, 280 + i * 60, 10, 8), Color(0.16, 0.19, 0.26))

	# Ventilasjonsrist på fronten
	for vy in range(220, 380, 16):
		draw_rect(Rect2(cx - 38, vy, 76, 6), Color(0.07, 0.09, 0.12))
		draw_rect(Rect2(cx - 36, vy + 1, 72, 3), Color(glow.r, glow.g, glow.b, 0.08))

	# Status-display
	draw_rect(Rect2(cx - 32, 385, 64, 44), Color(0.04, 0.10, 0.16))
	draw_rect(Rect2(cx - 28, 389, 56, 36), Color(0.00, 0.15, 0.28, 0.5))
	# "Skjerm" innhold
	var pulse : float = (sin(_time * 1.2) + 1.0) * 0.5
	for sl in 3:
		var sw : float = 24.0 + pulse * 18.0 * (1.0 - sl * 0.25)
		draw_rect(Rect2(cx - 24 + sl * 2, 393 + sl * 10, sw, 3),
			Color(glow.r, glow.g, glow.b, 0.55))

	# Topp-rør til tak
	draw_rect(Rect2(cx - 6, 72, 12, 130), Color(0.14, 0.17, 0.22))
	draw_rect(Rect2(cx - 3, 72,  6, 130), Color(0.18, 0.22, 0.30))

	# Nivå
	for n in min(lvl, 3):
		draw_circle(Vector2(cx - 16 + n * 16, 210), 4, Color(0.35, 0.70, 1.0))

	# Skade: rød alarm-blink
	if cond < 45:
		var alarm : float = abs(sin(_time * 5.0))
		draw_rect(Rect2(cx - 44, 200, 88, 262),
			Color(1.0, 0.1, 0.1, 0.08 * alarm))

func _draw_navigation(cx: float, cond: int, lvl: int, glow: Color) -> void:
	# Bred konsoll-plate
	draw_rect(Rect2(cx - 62, 330, 124, 130), Color(0.10, 0.12, 0.17))
	draw_rect(Rect2(cx - 58, 334, 116, 122), Color(0.08, 0.10, 0.14))

	# Helning fremover (perspektivplate)
	var desk := PackedVector2Array([
		Vector2(cx - 62, 330),
		Vector2(cx + 62, 330),
		Vector2(cx + 50, 370),
		Vector2(cx - 50, 370),
	])
	draw_colored_polygon(desk, Color(0.13, 0.15, 0.21))

	# 3 skjermer øverst på veggen
	var screen_colors : Array = [Color(0.0, 0.2, 0.5), Color(0.0, 0.15, 0.35), Color(0.0, 0.2, 0.5)]
	for s in 3:
		var sx : float = cx - 50.0 + s * 50.0
		draw_rect(Rect2(sx - 18, 168, 36, 56), Color(0.06, 0.08, 0.12))
		draw_rect(Rect2(sx - 14, 172, 28, 48), screen_colors[s])
		# "Animerte" scan-linjer
		for sl in 4:
			var sw : float = 10.0 + sin(_time * 1.5 + s + sl * 0.7) * 10.0
			draw_rect(Rect2(sx - 12 + sl * 0.5, 175 + sl * 10, sw, 2),
				Color(glow.r, glow.g, glow.b, 0.55))
		# Ramme
		draw_rect(Rect2(sx - 18, 168, 36, 56), Color(0.20, 0.24, 0.34), false, 2.0)

	# Tastatur/kontrollpanel på skrivebordet
	for row in 2:
		for col in 6:
			draw_rect(Rect2(cx - 46 + col * 16, 338 + row * 14, 12, 9),
				Color(0.16, 0.19, 0.26))
			draw_rect(Rect2(cx - 45 + col * 16, 339 + row * 14, 10, 7),
				Color(0.21, 0.26, 0.36))

	# Joystick
	draw_circle(Vector2(cx + 44, 345), 8,  Color(0.16, 0.19, 0.26))
	draw_circle(Vector2(cx + 44, 342), 5,  Color(0.22, 0.26, 0.35))
	draw_circle(Vector2(cx + 44, 340), 3,  Color(glow.r, glow.g, glow.b, 0.7))

	# Navigasjons-lys langs toppen av konsollen
	var nav_colors : Array = [Color(0.2, 1.0, 0.4), Color(1.0, 0.85, 0.2),
		Color(0.3, 0.6, 1.0), Color(1.0, 0.3, 0.3)]
	for ni in 4:
		var blink2 : bool = int(_time * 1.2 + ni * 0.5) % 2 == 0
		var nc     : Color = nav_colors[ni] if blink2 else nav_colors[ni] * 0.3
		draw_circle(Vector2(cx - 38 + ni * 26, 334), 5, nc)
		draw_circle(Vector2(cx - 38 + ni * 26, 334), 8, Color(nc.r, nc.g, nc.b, 0.2))

	# Forbindelsesrør opp
	draw_rect(Rect2(cx - 6, 72, 12, 98), Color(0.14, 0.17, 0.22))
	draw_rect(Rect2(cx - 3, 72,  6, 98), Color(0.18, 0.22, 0.30))

	# Nivå
	for n in min(lvl, 3):
		draw_circle(Vector2(cx - 16 + n * 16, 340), 4, Color(0.35, 0.70, 1.0))

	# Skade: skjermene flimrer
	if cond < 45:
		var flick : float = abs(sin(_time * 12.0))
		for s in 3:
			var sx : float = cx - 50.0 + s * 50.0
			draw_rect(Rect2(sx - 14, 172, 28, 48), Color(0.0, 0.0, 0.0, 0.5 * flick))

func _draw_shield(cx: float, cond: int, lvl: int, glow: Color) -> void:
	# Rørkobling til tak
	draw_rect(Rect2(cx - 5, 72, 10, 160), Color(0.12, 0.15, 0.20))
	draw_rect(Rect2(cx - 2, 72,  4, 160), Color(0.16, 0.20, 0.28))

	# Skjold-generator (sekskant-form)
	var pulse : float = (sin(_time * 1.4) + 1.0) * 0.5
	var pts   : PackedVector2Array = PackedVector2Array()
	for i in 6:
		var a : float = i * TAU / 6.0 - PI / 6.0
		pts.append(Vector2(cx + cos(a) * 52.0, 320.0 + sin(a) * 52.0))
	draw_colored_polygon(pts, Color(0.10, 0.12, 0.18))
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], pts[5], pts[0]]),
		Color(glow.r, glow.g, glow.b, 0.6), 2.5)

	# Indre kjerne
	draw_circle(Vector2(cx, 320), 28, Color(glow.r, glow.g, glow.b, 0.08 + pulse * 0.06))
	draw_circle(Vector2(cx, 320), 16, Color(glow.r, glow.g, glow.b, 0.20 + pulse * 0.15))
	draw_circle(Vector2(cx, 320),  6, Color(glow.r, glow.g, glow.b, 0.70 + pulse * 0.20))

	# Energiringer (animerte)
	for ri in 3:
		var rr : float = 34.0 + ri * 14.0
		var ra : float = _time * 0.8 + ri * TAU / 3.0
		draw_arc(Vector2(cx, 320), rr, ra, ra + TAU * 0.65, 24,
			Color(glow.r, glow.g, glow.b, 0.25 - ri * 0.06), 2.0)

	# Sokkel
	draw_rect(Rect2(cx - 30, 372, 60, 90), Color(0.12, 0.14, 0.20))
	draw_rect(Rect2(cx - 26, 376, 52, 82), Color(0.09, 0.11, 0.15))

	# Nivå
	for n in min(lvl, 3):
		draw_circle(Vector2(cx - 16 + n * 16, 242), 4, Color(0.35, 0.70, 1.0))

	# Skade: felt flimrer
	if cond < 45:
		var fl : float = abs(sin(_time * 8.0))
		draw_circle(Vector2(cx, 320), 56, Color(1.0, 0.3, 0.1, 0.10 * fl))

func _draw_laser_cannon(cx: float, cond: int, lvl: int, glow: Color) -> void:
	# Veggfeste / kraftenhet bak
	draw_rect(Rect2(cx - 30, 200, 60, 220), Color(0.11, 0.13, 0.18))
	draw_rect(Rect2(cx - 26, 204, 52, 212), Color(0.09, 0.11, 0.15))

	# Kanonrør (peker rett frem / ned)
	draw_rect(Rect2(cx - 12, 155, 24, 200), Color(0.16, 0.19, 0.27))
	draw_rect(Rect2(cx -  6, 155, 12, 200), Color(0.20, 0.24, 0.34))

	# Kanonmunning
	draw_rect(Rect2(cx - 18, 145, 36, 14), Color(0.18, 0.22, 0.30))
	draw_rect(Rect2(cx -  8, 143,  16, 4), Color(0.26, 0.32, 0.46))

	# Laser-kjerne (pulserende)
	var pulse  : float = (sin(_time * 3.5) + 1.0) * 0.5
	var charge : float = (sin(_time * 7.0) + 1.0) * 0.5
	draw_circle(Vector2(cx, 152), 10, Color(glow.r, glow.g, glow.b, 0.30 + pulse * 0.25))
	draw_circle(Vector2(cx, 152),  5, Color(1.0, 0.85, 0.5, 0.70 + charge * 0.25))

	# Laser-stråle (synlig energibane nedover røret)
	for li in 5:
		var ly  : float = 158.0 + li * 36.0
		var lw  : float = 1.5 + charge * 2.5
		draw_line(Vector2(cx, ly), Vector2(cx, ly + 24),
			Color(glow.r, glow.g, glow.b, 0.15 + charge * 0.30 - li * 0.03), lw)

	# Kjølevinger (begge sider)
	for side in [-1, 1]:
		var fin := PackedVector2Array([
			Vector2(cx + side * 12, 250),
			Vector2(cx + side * 42, 230),
			Vector2(cx + side * 44, 290),
			Vector2(cx + side * 14, 310),
		])
		draw_colored_polygon(fin, Color(0.13, 0.15, 0.22))
		draw_polyline(fin, Color(0.20, 0.24, 0.34), 1.5)

	# Rørtilkobling til kraftenhet
	draw_rect(Rect2(cx - 4, 355, 8, 65), Color(0.14, 0.17, 0.23))

	# Nivå
	for n in min(lvl, 3):
		draw_circle(Vector2(cx - 16 + n * 16, 210), 4, Color(0.35, 0.70, 1.0))

	# Skade: energilekkasje
	if cond < 45 and int(_time * 6) % 3 == 0:
		draw_circle(Vector2(cx + randf_range(-14, 14), randf_range(155, 350)),
			2.0, Color(1.0, 0.3, 0.1, 0.8))

func _draw_torpedo(cx: float, cond: int, lvl: int, glow: Color) -> void:
	# Tak-rørkobling
	draw_rect(Rect2(cx - 6, 72, 12, 100), Color(0.14, 0.17, 0.22))
	draw_rect(Rect2(cx - 3, 72,  6, 100), Color(0.18, 0.22, 0.30))

	# Torpedorørhus
	draw_rect(Rect2(cx - 48, 170, 96, 240), Color(0.11, 0.13, 0.19))
	draw_rect(Rect2(cx - 44, 174, 88, 232), Color(0.09, 0.11, 0.16))

	# 3 rør (torpedorammer)
	for ti in 3:
		var ty : float = 188.0 + ti * 70.0
		# Rørring ytre
		draw_rect(Rect2(cx - 42, ty, 84, 48), Color(0.14, 0.16, 0.22))
		draw_rect(Rect2(cx - 38, ty + 4, 76, 40), Color(0.07, 0.08, 0.12))
		# Torpedo-profil inne i røret
		var torp := PackedVector2Array([
			Vector2(cx - 24, ty + 8),
			Vector2(cx + 24, ty + 8),
			Vector2(cx + 30, ty + 24),
			Vector2(cx + 24, ty + 40),
			Vector2(cx - 24, ty + 40),
			Vector2(cx - 30, ty + 24),
		])
		var t_col : Color = Color(0.18, 0.22, 0.30)
		draw_colored_polygon(torp, t_col)
		# Ladeindikator
		var pulse  : float = (sin(_time * 1.2 + ti * 1.1) + 1.0) * 0.5
		draw_rect(Rect2(cx - 22, ty + 20, int(44.0 * pulse), 6),
			Color(glow.r, glow.g, glow.b, 0.55))
		# Torpedo-spiss
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx - 8, ty + 8),
			Vector2(cx + 8, ty + 8),
			Vector2(cx, ty),
		]), Color(0.30, 0.36, 0.50))

	# Kontrollpanel (høyre side)
	draw_rect(Rect2(cx + 48, 200, 40, 100), Color(0.10, 0.12, 0.16))
	for bi in 6:
		var brow : int = bi / 2
		var bcol : int = bi % 2
		var bc   : Color = Color(0.9, 0.2, 0.2) if bi < 2 else \
			(Color(0.9, 0.75, 0.2) if bi < 4 else Color(0.2, 0.8, 0.4))
		var blink3 : bool = int(_time * 0.9 + bi * 0.4) % 2 == 0
		draw_circle(Vector2(cx + 58 + bcol * 18, 218 + brow * 24), 5,
			bc if blink3 else bc * 0.3)

	# Nivå
	for n in min(lvl, 3):
		draw_circle(Vector2(cx - 16 + n * 16, 180), 4, Color(0.35, 0.70, 1.0))

	# Skade: ladesvikt
	if cond < 45:
		var fl : float = abs(sin(_time * 6.0))
		draw_rect(Rect2(cx - 44, 174, 88, 232), Color(1.0, 0.2, 0.1, 0.06 * fl))
