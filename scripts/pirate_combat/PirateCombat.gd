extends Node2D
## Void Miner – Piratkamp
## Turbasert kamp mot rompirat.
## Taper du: Game Over – lagringsfilen slettes.

# ── Pirat-databaser ───────────────────────────────────────────
const PIRATE_TIERS : Array = [
	{"min_day": 1,  "hp": 3, "shield": 1, "atk": 1, "special": false,
	 "name": "Lykt-pirat",  "reward": 400},
	{"min_day": 6,  "hp": 5, "shield": 2, "atk": 2, "special": false,
	 "name": "Rompirat",    "reward": 750},
	{"min_day": 13, "hp": 7, "shield": 3, "atk": 2, "special": true,
	 "name": "Elitepirat",  "reward": 1500},
]

const TORPEDO_INFO : Dictionary = {
	"standard":   {"name": "Standard",    "dmg": 3, "half_shield": true,  "bypass": false, "stun": 0, "is_decoy": false},
	"emp":        {"name": "EMP",         "dmg": 2, "half_shield": false, "bypass": false, "stun": 1, "is_decoy": false},
	"penetrator": {"name": "Penetrator",  "dmg": 3, "half_shield": false, "bypass": true,  "stun": 0, "is_decoy": false},
	"nuke":       {"name": "Nuke",        "dmg": 5, "half_shield": false, "bypass": true,  "stun": 0, "is_decoy": false},
	"decoy":      {"name": "Lokkedekke", "dmg": 0, "half_shield": false, "bypass": false, "stun": 1, "is_decoy": true},
}

const TORP_ORDER : Array = ["standard", "emp", "penetrator", "nuke", "decoy"]

# ── Spillertilstand ────────────────────────────────────────────
var _player_hp      : int  = 3
var _player_hp_max  : int  = 3
var _shield_boost   : bool = false

# ── Pirattilstand ─────────────────────────────────────────────
var _pirate_hp         : int    = 0
var _pirate_hp_max     : int    = 0
var _pirate_shield     : int    = 0
var _pirate_shield_max : int    = 0
var _pirate_atk        : int    = 0
var _pirate_special    : bool   = false
var _pirate_name       : String = ""
var _pirate_reward     : int    = 0
var _pirate_stunned    : int    = 0   # Turns without attack

# ── Scenetilstand ─────────────────────────────────────────────
var _turn         : int   = 0
var _over         : bool  = false
var _won          : bool  = false
var _time         : float = 0.0
var _need_scroll  : bool  = false

# ── Noder ─────────────────────────────────────────────────────
@onready var log_label    : Label           = $UI/LogScroll/LogLabel
@onready var log_scroll   : ScrollContainer = $UI/LogScroll
@onready var actions_panel                  = $UI/ActionsPanel
@onready var torp_panel                     = $UI/TorpedoPanel
@onready var torp_list    : VBoxContainer   = $UI/TorpedoPanel/VBox/TorpList
@onready var result_panel                   = $UI/ResultPanel
@onready var result_title : Label           = $UI/ResultPanel/VBox/TitleLabel
@onready var result_msg   : Label           = $UI/ResultPanel/VBox/MessageLabel
@onready var result_btn   : Button          = $UI/ResultPanel/VBox/ResultBtn
@onready var player_lbl   : Label           = $UI/StatsBar/PlayerLabel
@onready var pirate_lbl   : Label           = $UI/StatsBar/PirateLabel

func _ready() -> void:
	_init_pirate()
	_build_torpedo_buttons()
	_connect_buttons()
	_update_stats_labels()
	_log("⚠  %s brer seg i veien og angriper!" % _pirate_name)
	_log("Pirat: HP %d  |  Skjold %d  |  Angrep %d%s" % [
		_pirate_hp_max, _pirate_shield_max, _pirate_atk,
		"  +spesialangrep" if _pirate_special else ""])
	_log("─────────────────────────────────────────────────")

# ── Initialisering ─────────────────────────────────────────────
func _init_pirate() -> void:
	var day : int = SaveManager.game_data.get("day", 1)
	var tier : Dictionary = PIRATE_TIERS[0]
	for t : Dictionary in PIRATE_TIERS:
		if day >= t["min_day"]:
			tier = t
	_pirate_hp         = tier["hp"]
	_pirate_hp_max     = tier["hp"]
	_pirate_shield     = tier["shield"]
	_pirate_shield_max = tier["shield"]
	_pirate_atk        = tier["atk"]
	_pirate_special    = tier["special"]
	_pirate_name       = tier["name"]
	_pirate_reward     = tier["reward"]

func _build_torpedo_buttons() -> void:
	for tt : String in TORP_ORDER:
		var info : Dictionary = TORPEDO_INFO[tt]
		var td   : Dictionary = SaveManager.game_data.get("torpedoes", {})
		var cnt  : int        = td.get(tt, 0)
		var btn  := Button.new()
		btn.name = "TBtn_" + tt
		btn.custom_minimum_size = Vector2(580, 36)
		btn.disabled = cnt <= 0
		_set_torp_btn_text(btn, tt, info, cnt)
		var capture_tt : String = tt
		btn.pressed.connect(func(): _use_torpedo(capture_tt))
		torp_list.add_child(btn)

func _set_torp_btn_text(btn: Button, tt: String, info: Dictionary, cnt: int) -> void:
	btn.text = "%s  ×%d  – %s" % [info["name"].rpad(14), cnt, _torpedo_effect_desc(tt)]

func _torpedo_effect_desc(tt: String) -> String:
	match tt:
		"standard":   return "3 skade (halvt skjold ignorert)"
		"emp":        return "2 skade + piraten mister neste angrep"
		"penetrator": return "3 skade (gjennomtrenger alt skjold)"
		"nuke":       return "5 skade (gjennomtrenger alt skjold)"
		"decoy":      return "Piraten taper runden – ingen skade på deg"
	return ""

func _connect_buttons() -> void:
	$UI/ActionsPanel/LaserBtn.pressed.connect(func(): _do_player_action("laser"))
	$UI/ActionsPanel/TorpedoBtn.pressed.connect(_open_torpedo_panel)
	$UI/ActionsPanel/ShieldBtn.pressed.connect(func(): _do_player_action("shield"))
	$UI/ActionsPanel/FleeBtn.pressed.connect(func(): _do_player_action("flee"))
	$UI/TorpedoPanel/VBox/CancelBtn.pressed.connect(func(): torp_panel.visible = false)
	result_btn.pressed.connect(_on_result_btn)

# ── Torpedo-panel ─────────────────────────────────────────────
func _open_torpedo_panel() -> void:
	if _over: return
	# Refresh torpedo counts on buttons
	var td : Dictionary = SaveManager.game_data.get("torpedoes", {})
	for i : int in TORP_ORDER.size():
		var tt  : String     = TORP_ORDER[i]
		var btn : Button     = torp_list.get_child(i) as Button
		if btn:
			var cnt : int = td.get(tt, 0)
			btn.disabled = cnt <= 0
			_set_torp_btn_text(btn, tt, TORPEDO_INFO[tt], cnt)
	torp_panel.visible = true

func _use_torpedo(ttype: String) -> void:
	torp_panel.visible = false
	if not SaveManager.use_torpedo(ttype):
		_log("❌  Ingen %s-torpedoer igjen!" % TORPEDO_INFO[ttype]["name"])
		return
	_do_player_action("torpedo", ttype)

# ── Spillerhandling ────────────────────────────────────────────
func _do_player_action(action: String, ttype: String = "") -> void:
	if _over: return
	actions_panel.visible = false
	_turn += 1
	_log("\n── Runde %d ──────────────────────────────────────" % _turn)

	# Bestem piratens handling (før spiller-effekter for å holde simultanitet)
	var pirate_dmg         : int    = 0
	var pirate_action_text : String = ""

	if _pirate_stunned > 0:
		_pirate_stunned -= 1
		pirate_action_text = "  🔵 Piraten er lamslått – mister angrepet denne runden!"
	else:
		var base_dmg : int = _pirate_atk
		if _pirate_special and randf() < 0.20:
			base_dmg = _pirate_atk * 2
			pirate_action_text = "  ⚡ SPESIALANGREP! Piraten slår dobbelt!"
		else:
			pirate_action_text = "  💀 Piraten angriper!"
		pirate_dmg = base_dmg

	# ── Spillerens valg ────────────────────────────────────────
	match action:
		"laser":
			var battery_upg : bool = SaveManager.game_data.get("battery_upgrade", false)
			var cannons     : int  = SaveManager.game_data.get("laser_cannons", 1)
			var dmg_per     : int  = 2 if battery_upg else 1
			var total_dmg   : int  = cannons * dmg_per
			_log("  🔫 Avfyrer laser: %d kanon(er) × %d skade = %d total" % [cannons, dmg_per, total_dmg])
			_deal_damage_to_pirate(total_dmg, false, false)

		"torpedo":
			var info : Dictionary = TORPEDO_INFO[ttype]
			_log("  🚀 Avfyrer %s-torpedo!" % info["name"])
			if info["is_decoy"]:
				_log("  🎭 Lokkedekket aktivert – piraten er forvirret!")
				_pirate_stunned = 1
				pirate_dmg = 0
				pirate_action_text = "  🎭 Piraten ble lurt og mister sin tur!"
			else:
				_deal_damage_to_pirate(info["dmg"], info["half_shield"], info["bypass"])
				if info["stun"] > 0:
					_pirate_stunned = info["stun"]
					_log("  ⚡ EMP-impuls! Piraten mister neste angrep.")

		"shield":
			_shield_boost = true
			_log("  🛡 Skjoldblokk aktivert – absorberer all innkommende skade denne runden!")

		"flee":
			var day          : int   = SaveManager.game_data.get("day", 1)
			var flee_chance  : float = 0.60 if day <= 5 else 0.40
			_log("  🏃 Forsøker å rømme… (%.0f%% sjanse)" % (flee_chance * 100.0))
			if randf() < flee_chance:
				_log("  ✅ Slapp unna! Piraten ser deg forsvinne i mørket.")
				_over = true
				_won  = true
				_show_result("Rømte fra piraten – ingen krigsbytte, men skipet er i sikkerhet.\n\nDu ankommer trader-stasjonen.", true, "🏃  Slapp unna!")
				return
			else:
				_log("  ❌ Rømningsforsøket mislyktes! Piraten sperrer ruten.")

	# ── Piratens angrep ────────────────────────────────────────
	_log(pirate_action_text)
	if pirate_dmg > 0:
		if _shield_boost:
			_log("  🛡 Skjoldet blokkerte alt piratskade!")
		else:
			var shield_lvl : int = SaveManager.game_data.get("shield_level", 1)
			var reduced    : int = max(0, pirate_dmg - shield_lvl)
			if shield_lvl > 0 and reduced < pirate_dmg:
				_log("  🛡 Passivt skjold (nivå %d) demper skade: %d → %d" % [shield_lvl, pirate_dmg, reduced])
			if reduced > 0:
				_player_hp -= reduced
				_player_hp = max(0, _player_hp)
				_log("  💥 Du tar %d skade!  (HP: %d/%d)" % [reduced, _player_hp, _player_hp_max])
			else:
				_log("  🛡 Skipets skjold absorberte alt skade!")

	_shield_boost = false
	_update_stats_labels()

	# ── Sjekk sluttbetingelser ─────────────────────────────────
	if _player_hp <= 0:
		_log("\n  ☠  Skipet er fullstendig ødelagt…")
		_over = true
		_won  = false
		_show_result("Skipet ditt ble knust av piraten.\n\nGame Over – lagringsfilen slettes.", false)
		return

	if _pirate_hp <= 0:
		_log("\n  💥  %s er beseiret!" % _pirate_name)
		_over = true
		_won  = true
		var reward : int = _pirate_reward
		SaveManager.game_data["credits"] = SaveManager.game_data.get("credits", 0) + reward
		_show_result("%s er nedkjempet!\n\n+%d kreditter i krigsbytte. Du ankommer trader-stasjonen." % [_pirate_name, reward], true)
		return

	# ── Fortsett ──────────────────────────────────────────────
	_log("  [Ditt skip HP: %d/%d]  Velg neste handling:" % [_player_hp, _player_hp_max])
	actions_panel.visible = true

# ── Skadesystem ───────────────────────────────────────────────
func _deal_damage_to_pirate(dmg: int, half_shield: bool, bypass: bool) -> void:
	if bypass:
		_pirate_hp = max(0, _pirate_hp - dmg)
		_log("    → Gjennomtrenger skjoldet! %d skade direkte på HP  (nå %d/%d)" % [
			dmg, _pirate_hp, _pirate_hp_max])
	elif half_shield:
		# Standard: shield only absorbs half its current pool
		var eff_shield : int = _pirate_shield / 2
		var absorbed   : int = min(eff_shield, dmg)
		var remainder  : int = dmg - absorbed
		if absorbed > 0:
			_log("    → Halvt skjold: %d skade absorbert av skjoldet" % absorbed)
		if remainder > 0:
			_pirate_hp = max(0, _pirate_hp - remainder)
			_log("    → %d skade på HP  (nå %d/%d)" % [remainder, _pirate_hp, _pirate_hp_max])
		else:
			_log("    → Skjoldet absorberte all skade")
	else:
		# Normal: shield absorbs first, then HP
		var absorbed  : int = min(_pirate_shield, dmg)
		_pirate_shield = max(0, _pirate_shield - absorbed)
		var remainder : int = dmg - absorbed
		if absorbed > 0:
			_log("    → Skjold: %d absorbert  (gjenstår %d/%d)" % [absorbed, _pirate_shield, _pirate_shield_max])
		if remainder > 0:
			_pirate_hp = max(0, _pirate_hp - remainder)
			_log("    → %d skade på HP  (nå %d/%d)" % [remainder, _pirate_hp, _pirate_hp_max])
		else:
			_log("    → Skjoldet absorberte all skade")

# ── HUD-oppdatering ────────────────────────────────────────────
func _update_stats_labels() -> void:
	var ph_str : String = ""
	for i : int in _player_hp_max:
		ph_str += "❤" if i < _player_hp else "🖤"
	player_lbl.text = "Ditt skip:  %s  (%d/%d HP)" % [ph_str, _player_hp, _player_hp_max]

	var pi_hp_str : String = ""
	for i : int in _pirate_hp_max:
		pi_hp_str += "■" if i < _pirate_hp else "□"
	var pi_sh_str : String = ""
	for i : int in _pirate_shield_max:
		pi_sh_str += "◆" if i < _pirate_shield else "◇"
	pirate_lbl.text = "%s:  HP %s  |  Skjold %s" % [_pirate_name, pi_hp_str, pi_sh_str]

# ── Resultatpanel ─────────────────────────────────────────────
func _show_result(msg: String, won: bool, custom_title: String = "") -> void:
	if custom_title != "":
		result_title.text = custom_title
	elif won:
		result_title.text = "✅  Kamp vunnet!"
	else:
		result_title.text = "☠  Game Over"
	result_btn.text = "Fortsett til trader  →" if won else "Tilbake til hovedmeny"
	result_msg.text = msg
	result_panel.visible = true

func _on_result_btn() -> void:
	if _won:
		SaveManager.save_game()
		get_tree().change_scene_to_file("res://scenes/trader_office/TraderOffice.tscn")
	else:
		SaveManager.save_hiscore()   # Lagre score FØR sletting
		SaveManager.delete_save()
		get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")

# ── Logg ─────────────────────────────────────────────────────
func _log(text: String) -> void:
	log_label.text += text + "\n"
	_need_scroll = true

# ── Prosess + tegning ─────────────────────────────────────────
func _process(delta: float) -> void:
	_time += delta
	if _need_scroll:
		_need_scroll = false
		log_scroll.scroll_vertical = log_scroll.get_v_scroll_bar().max_value
	queue_redraw()

func _draw() -> void:
	# Bakgrunn
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.04, 0.05, 0.09))

	# Stjernefeltet (statisk – bruker _time for bevegelse)
	for i : int in 80:
		var seed_f : float = float(i) * 12.34567
		var sx     : float = fmod(seed_f * 137.5, 1280.0)
		var sy     : float = fmod(seed_f * 317.8, 720.0)
		var sa     : float = fmod(seed_f * 0.73, 0.6) + 0.2
		var sr     : float = fmod(seed_f * 0.031, 1.2) + 0.4
		draw_circle(Vector2(sx, sy), sr, Color(1.0, 1.0, 1.0, sa))

	# Stats-bar øverst
	draw_rect(Rect2(0, 0, 1280, 62), Color(0.08, 0.10, 0.16))
	draw_rect(Rect2(0, 60, 1280, 3), Color(0.8, 0.2, 0.15, 0.55))

	# Logg-panel
	draw_rect(Rect2(10, 68, 902, 506), Color(0.06, 0.07, 0.12))
	draw_rect(Rect2(10, 68, 902, 506), Color(0.20, 0.30, 0.50, 0.28), false, 2.0)

	# Handling-panel boks
	draw_rect(Rect2(0, 582, 922, 138), Color(0.07, 0.08, 0.14))
	draw_rect(Rect2(0, 580, 922, 3), Color(0.25, 0.45, 0.80, 0.45))

	# Høyre illustrasjonspanel
	draw_rect(Rect2(918, 68, 354, 652), Color(0.05, 0.06, 0.11))
	draw_rect(Rect2(918, 68, 2, 652), Color(0.25, 0.45, 0.80, 0.25))

	# Pirat-skip (øverst til høyre)
	_draw_pirate_ship(1094.0, 210.0)

	# Vs-linje
	var pulse : float = (sin(_time * 1.5) + 1.0) * 0.5
	draw_rect(Rect2(940, 378, 310, 2), Color(0.5, 0.2, 0.2, 0.3 + pulse * 0.2))

	# Spiller-skip (nederst til høyre)
	_draw_player_ship(1094.0, 490.0)

func _draw_player_ship(cx: float, cy: float) -> void:
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
	draw_rect(Rect2(cx + 33, cy + 5, 14, 6), Color(0.7, 0.9, 1.0, 0.5))
	draw_rect(Rect2(cx - 68, cy + 8, 10, 14), Color(0.4, 0.5, 0.6))
	# Motor-glow
	var ga : float = 0.45 + sin(_time * 8.0) * 0.3
	draw_circle(Vector2(cx - 64, cy + 14), 12.0, Color(0.4, 0.6, 1.0, ga * 0.6))
	draw_circle(Vector2(cx - 64, cy + 14), 5.0, Color(0.8, 0.9, 1.0, ga))
	# HP-indikatorer under skipet
	for i : int in _player_hp_max:
		var hx : float = cx - float(_player_hp_max) * 9.0 + float(i) * 18.0
		var col : Color = Color(0.9, 0.2, 0.2) if i < _player_hp else Color(0.18, 0.06, 0.06)
		draw_circle(Vector2(hx, cy + 70.0), 7.0, col)
		draw_circle(Vector2(hx, cy + 70.0), 7.0, Color(1.0, 0.5, 0.5, 0.3), false, 1.5)

func _draw_pirate_ship(cx: float, cy: float) -> void:
	# Pirat-skip peker mot venstre (ned mot spilleren)
	var C_BODY := Color(0.42, 0.10, 0.10)
	var C_TRIM := Color(0.75, 0.22, 0.08)
	var C_EYE  := Color(1.00, 0.28, 0.04, 0.92)

	# Hoveddskrog (peker venstre)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx + 55, cy + 8),  Vector2(cx - 55, cy),
		Vector2(cx - 55, cy + 22), Vector2(cx + 55, cy + 30),
	]), C_BODY)
	# Nesespiss (venstre)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 55, cy), Vector2(cx - 55, cy + 22), Vector2(cx - 88, cy + 11),
	]), C_TRIM)
	# Øvre finnev
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx + 10, cy), Vector2(cx - 18, cy),
		Vector2(cx - 8,  cy - 24), Vector2(cx + 20, cy - 18),
	]), C_TRIM)
	# Nedre finne
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx + 10, cy + 30), Vector2(cx - 18, cy + 30),
		Vector2(cx - 8,  cy + 52), Vector2(cx + 20, cy + 46),
	]), C_TRIM)
	# Cockpit (eye)
	draw_rect(Rect2(cx - 40, cy + 6, 24, 12), Color(0.02, 0.02, 0.05))
	draw_circle(Vector2(cx - 36, cy + 12), 6.0, C_EYE)
	draw_circle(Vector2(cx - 36, cy + 12), 3.0, Color(1.0, 0.55, 0.18, 0.8))
	# Eksos (høyre side)
	var ea : float = 0.4 + sin(_time * 9.0 + 1.3) * 0.3
	draw_circle(Vector2(cx + 60, cy + 14), 11.0, Color(0.85, 0.35, 0.08, ea * 0.55))
	draw_circle(Vector2(cx + 60, cy + 14), 5.0,  Color(1.0, 0.65, 0.20, ea * 0.80))
	# Pirat-HP-indikatorer over skipet
	for i : int in _pirate_hp_max:
		var hx : float = cx - float(_pirate_hp_max) * 9.0 + float(i) * 18.0
		var col : Color = Color(0.85, 0.18, 0.18) if i < _pirate_hp else Color(0.15, 0.05, 0.05)
		draw_circle(Vector2(hx, cy - 22.0), 7.0, col)
	# Pirat-skjold-indikatorer
	for i : int in _pirate_shield_max:
		var hx : float = cx - float(_pirate_shield_max) * 9.0 + float(i) * 18.0
		var col : Color = Color(0.28, 0.48, 0.90) if i < _pirate_shield else Color(0.06, 0.08, 0.14)
		draw_rect(Rect2(hx - 6, cy - 38.0, 12, 9), col)
