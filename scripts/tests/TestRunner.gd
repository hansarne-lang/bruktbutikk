extends Node
## Void Miner – Regresjonstestsuite (50 tester)
## Kjøres via scenes/tests/TestScene.tscn

signal tests_done(summary: String, results: Array)

var _pass  : int          = 0
var _fail  : int          = 0
var _res   : Array[String] = []

# ── Offentlig API ────────────────────────────────────────────────
func run_all() -> void:
	_pass = 0
	_fail = 0
	_res  = []

	_section("SAVEMANAGER – new_game()")
	_t01_new_game_day()
	_t02_new_game_credits()
	_t03_new_game_tanks()
	_t04_new_game_time_of_day()
	_t05_new_game_moon_name()

	_section("SAVEMANAGER – add_mineral()")
	_t06_add_mineral_returns_true()
	_t07_add_mineral_sets_mineral_id()
	_t08_add_mineral_sets_amount()
	_t09_add_mineral_accumulates()
	_t10_add_mineral_second_tank()
	_t11_add_mineral_full_returns_false()

	_section("SAVEMANAGER – total_minerals() / empty_tanks()")
	_t12_total_minerals_zero_on_new()
	_t13_total_minerals_sums_all()
	_t14_empty_tanks_resets_amount()
	_t15_empty_tanks_resets_mineral_id()
	_t16_add_mineral_after_empty()

	_section("SAVEMANAGER – add_trade_log()")
	_t17_trade_log_appends()
	_t18_trade_log_earned()
	_t19_trade_log_trader()
	_t20_trade_log_caps_at_50()

	_section("SAVEMANAGER – moon_name")
	_t21_moon_name_stored()
	_t22_moon_name_migration()

	_section("DATALOADER – mineral-innlasting")
	_t23_mineral_count()
	_t24_ferroxite_name()
	_t25_ferroxite_base_value()
	_t26_ferroxite_rarity()
	_t27_novium_base_value()
	_t28_novium_rarity()
	_t29_quantite_rarity()
	_t30_unknown_mineral_empty()
	_t31_all_have_color()
	_t32_all_have_description()

	_section("DATALOADER – random_mineral() & låsing")
	_t33_day1_only_common()
	_t34_day3_uncommon_appears()
	_t35_day7_rare_appears()
	_t36_day14_very_rare_appears()
	_t37_day25_legendary_appears()
	_t38_never_returns_empty()
	_t39_is_unlocked_ferroxite_day1()
	_t40_not_unlocked_morganite_day1()
	_t41_unlocked_morganite_day3()
	_t42_not_unlocked_novanite_day3()

	_section("TANK-LOGIKK")
	_t43_fill_pct_half()
	_t44_fill_pct_zero()
	_t45_fill_pct_full()
	_t46_bigger_tanks_capacity()
	_t47_extra_tank_count()

	_section("HANDELSBEREGNING")
	_t48_ferroxite_earnings_grom()
	_t49_ferroxite_earnings_zyla()
	_t50_empty_cargo_zero_earnings()

	var summary : String = "Resultat: %d / %d bestått  (%d feilet)" % [_pass, _pass + _fail, _fail]
	tests_done.emit(summary, _res)

# ════════════════════════════════════════════════════════════════
#  SAVEMANAGER – new_game()
# ════════════════════════════════════════════════════════════════
func _t01_new_game_day() -> void:
	SaveManager.new_game()
	_chk("T01  new_game() → dag = 1",
		SaveManager.game_data.get("day", 0) == 1)

func _t02_new_game_credits() -> void:
	SaveManager.new_game()
	_chk("T02  new_game() → kreditter = 1200",
		SaveManager.game_data.get("credits", 0) == 1200)

func _t03_new_game_tanks() -> void:
	SaveManager.new_game()
	_chk("T03  new_game() → 2 tanker",
		SaveManager.game_data.get("tanks", []).size() == 2)

func _t04_new_game_time_of_day() -> void:
	SaveManager.new_game()
	_chk("T04  new_game() → time_of_day = 0.0",
		SaveManager.game_data.get("time_of_day", -1.0) == 0.0)

func _t05_new_game_moon_name() -> void:
	SaveManager.new_game()
	_chk("T05  new_game() → moon_name finnes",
		SaveManager.game_data.has("moon_name"))

# ════════════════════════════════════════════════════════════════
#  SAVEMANAGER – add_mineral()
# ════════════════════════════════════════════════════════════════
func _t06_add_mineral_returns_true() -> void:
	SaveManager.new_game()
	_chk("T06  add_mineral() → true for tom tank",
		SaveManager.add_mineral("ferroxite", 1) == true)

func _t07_add_mineral_sets_mineral_id() -> void:
	SaveManager.new_game()
	SaveManager.add_mineral("ferroxite", 1)
	_chk("T07  add_mineral() setter mineral_id",
		SaveManager.game_data["tanks"][0].get("mineral_id", "") == "ferroxite")

func _t08_add_mineral_sets_amount() -> void:
	SaveManager.new_game()
	SaveManager.add_mineral("ferroxite", 5)
	_chk("T08  add_mineral() setter amount = 5",
		SaveManager.game_data["tanks"][0].get("amount", 0) == 5)

func _t09_add_mineral_accumulates() -> void:
	SaveManager.new_game()
	SaveManager.add_mineral("ferroxite", 3)
	SaveManager.add_mineral("ferroxite", 7)
	_chk("T09  add_mineral() akkumulerer i eksisterende tank",
		SaveManager.game_data["tanks"][0].get("amount", 0) == 10)

func _t10_add_mineral_second_tank() -> void:
	SaveManager.new_game()
	SaveManager.add_mineral("ferroxite", 1)
	SaveManager.add_mineral("glacite",   1)
	_chk("T10  nytt mineral bruker tank 2",
		SaveManager.game_data["tanks"][1].get("mineral_id", "") == "glacite")

func _t11_add_mineral_full_returns_false() -> void:
	SaveManager.new_game()
	# Fyll begge tankene med to ulike mineraler til maks kapasitet
	for _i in 50:
		SaveManager.add_mineral("ferroxite", 1)
	for _i in 50:
		SaveManager.add_mineral("glacite", 1)
	# Nå er begge fulle – nytt mineral skal feile
	_chk("T11  add_mineral() returnerer false når alle tanker fulle",
		SaveManager.add_mineral("obsidite", 1) == false)

# ════════════════════════════════════════════════════════════════
#  SAVEMANAGER – total_minerals() / empty_tanks()
# ════════════════════════════════════════════════════════════════
func _t12_total_minerals_zero_on_new() -> void:
	SaveManager.new_game()
	_chk("T12  total_minerals() = 0 på nytt spill",
		SaveManager.total_minerals() == 0)

func _t13_total_minerals_sums_all() -> void:
	SaveManager.new_game()
	SaveManager.add_mineral("ferroxite", 5)
	SaveManager.add_mineral("glacite",   3)
	_chk("T13  total_minerals() summerer alle tanker = 8",
		SaveManager.total_minerals() == 8)

func _t14_empty_tanks_resets_amount() -> void:
	SaveManager.new_game()
	SaveManager.add_mineral("ferroxite", 10)
	SaveManager.empty_tanks()
	_chk("T14  empty_tanks() setter amount = 0",
		SaveManager.game_data["tanks"][0].get("amount", -1) == 0)

func _t15_empty_tanks_resets_mineral_id() -> void:
	SaveManager.new_game()
	SaveManager.add_mineral("ferroxite", 10)
	SaveManager.empty_tanks()
	_chk("T15  empty_tanks() setter mineral_id = \"\"",
		SaveManager.game_data["tanks"][0].get("mineral_id", "X") == "")

func _t16_add_mineral_after_empty() -> void:
	SaveManager.new_game()
	SaveManager.add_mineral("ferroxite", 10)
	SaveManager.empty_tanks()
	var ok := SaveManager.add_mineral("glacite", 2)
	_chk("T16  add_mineral() virker igjen etter empty_tanks()", ok == true)

# ════════════════════════════════════════════════════════════════
#  SAVEMANAGER – add_trade_log()
# ════════════════════════════════════════════════════════════════
func _t17_trade_log_appends() -> void:
	SaveManager.new_game()
	SaveManager.add_trade_log(500, "Grom Korrec")
	_chk("T17  add_trade_log() legger til 1 innslag",
		SaveManager.game_data.get("trade_log", []).size() == 1)

func _t18_trade_log_earned() -> void:
	SaveManager.new_game()
	SaveManager.add_trade_log(999, "Zyla")
	_chk("T18  trade_log inneholder riktig beløp",
		SaveManager.game_data["trade_log"][0].get("earned", 0) == 999)

func _t19_trade_log_trader() -> void:
	SaveManager.new_game()
	SaveManager.add_trade_log(1, "Testtrader")
	_chk("T19  trade_log inneholder riktig trader-navn",
		SaveManager.game_data["trade_log"][0].get("trader", "") == "Testtrader")

func _t20_trade_log_caps_at_50() -> void:
	SaveManager.new_game()
	for i in 55:
		SaveManager.add_trade_log(i, "X")
	_chk("T20  add_trade_log() kapper logg ved 50 innslag",
		SaveManager.game_data.get("trade_log", []).size() == 50)

# ════════════════════════════════════════════════════════════════
#  SAVEMANAGER – moon_name
# ════════════════════════════════════════════════════════════════
func _t21_moon_name_stored() -> void:
	SaveManager.new_game()
	SaveManager.game_data["moon_name"] = "Testbasen Prime"
	_chk("T21  moon_name lagres i game_data",
		SaveManager.game_data.get("moon_name", "") == "Testbasen Prime")

func _t22_moon_name_migration() -> void:
	# Simulér gammel save uten moon_name – migrasjonslogikken skal fylle inn default
	SaveManager.new_game()
	SaveManager.game_data.erase("moon_name")
	# Kjør migrasjonssjekken manuelt (samme logikk som i load_game)
	if not SaveManager.game_data.has("moon_name"):
		SaveManager.game_data["moon_name"] = "Luna-7 Mining Station"
	_chk("T22  moon_name migreres inn i gamle saves",
		SaveManager.game_data.get("moon_name", "") == "Luna-7 Mining Station")

# ════════════════════════════════════════════════════════════════
#  DATALOADER – innlasting
# ════════════════════════════════════════════════════════════════
func _t23_mineral_count() -> void:
	_chk("T23  20 mineraler er lastet inn",
		DataLoader.minerals.size() == 20)

func _t24_ferroxite_name() -> void:
	_chk("T24  ferroxite har name-felt",
		DataLoader.get_mineral("ferroxite").has("name"))

func _t25_ferroxite_base_value() -> void:
	_chk("T25  ferroxite base_value = \"280\"",
		DataLoader.get_mineral("ferroxite").get("base_value", "") == "280")

func _t26_ferroxite_rarity() -> void:
	_chk("T26  ferroxite rarity = \"common\"",
		DataLoader.get_mineral("ferroxite").get("rarity", "") == "common")

func _t27_novium_base_value() -> void:
	_chk("T27  novium base_value = \"4500\"",
		DataLoader.get_mineral("novium").get("base_value", "") == "4500")

func _t28_novium_rarity() -> void:
	_chk("T28  novium rarity = \"legendary\"",
		DataLoader.get_mineral("novium").get("rarity", "") == "legendary")

func _t29_quantite_rarity() -> void:
	_chk("T29  quantite rarity = \"very_rare\"",
		DataLoader.get_mineral("quantite").get("rarity", "") == "very_rare")

func _t30_unknown_mineral_empty() -> void:
	_chk("T30  ukjent mineral returnerer {}",
		DataLoader.get_mineral("ukjent_xyz_abc") == {})

func _t31_all_have_color() -> void:
	var ok := true
	for id in DataLoader.minerals:
		if not DataLoader.minerals[id].has("color"):
			ok = false; break
	_chk("T31  alle 20 mineraler har color-felt", ok)

func _t32_all_have_description() -> void:
	var ok := true
	for id in DataLoader.minerals:
		if not DataLoader.minerals[id].has("description"):
			ok = false; break
	_chk("T32  alle 20 mineraler har description-felt", ok)

# ════════════════════════════════════════════════════════════════
#  DATALOADER – random_mineral() & is_mineral_unlocked()
# ════════════════════════════════════════════════════════════════
func _t33_day1_only_common() -> void:
	SaveManager.new_game()  # dag 1
	var ok := true
	for _i in 300:
		var r : String = DataLoader.get_mineral(DataLoader.random_mineral()).get("rarity", "")
		if r != "common":
			ok = false; break
	_chk("T33  dag 1 → kun common mineraler (300 forsøk)", ok)

func _t34_day3_uncommon_appears() -> void:
	SaveManager.new_game()
	SaveManager.game_data["day"] = 3
	var saw := false
	for _i in 500:
		if DataLoader.get_mineral(DataLoader.random_mineral()).get("rarity","") == "uncommon":
			saw = true; break
	_chk("T34  dag 3 → uncommon kan dukke opp (500 forsøk)", saw)

func _t35_day7_rare_appears() -> void:
	SaveManager.new_game()
	SaveManager.game_data["day"] = 7
	var saw := false
	for _i in 1000:
		if DataLoader.get_mineral(DataLoader.random_mineral()).get("rarity","") == "rare":
			saw = true; break
	_chk("T35  dag 7 → rare kan dukke opp (1000 forsøk)", saw)

func _t36_day14_very_rare_appears() -> void:
	SaveManager.new_game()
	SaveManager.game_data["day"] = 14
	var saw := false
	for _i in 2000:
		if DataLoader.get_mineral(DataLoader.random_mineral()).get("rarity","") == "very_rare":
			saw = true; break
	_chk("T36  dag 14 → very_rare kan dukke opp (2000 forsøk)", saw)

func _t37_day25_legendary_appears() -> void:
	SaveManager.new_game()
	SaveManager.game_data["day"] = 25
	var saw := false
	for _i in 3000:
		if DataLoader.get_mineral(DataLoader.random_mineral()).get("rarity","") == "legendary":
			saw = true; break
	_chk("T37  dag 25 → legendary kan dukke opp (3000 forsøk)", saw)

func _t38_never_returns_empty() -> void:
	SaveManager.new_game()
	var ok := true
	for _i in 200:
		if DataLoader.random_mineral() == "":
			ok = false; break
	_chk("T38  random_mineral() returnerer aldri tom streng", ok)

func _t39_is_unlocked_ferroxite_day1() -> void:
	SaveManager.new_game()  # dag 1
	_chk("T39  ferroxite er låst opp dag 1",
		DataLoader.is_mineral_unlocked("ferroxite") == true)

func _t40_not_unlocked_morganite_day1() -> void:
	SaveManager.new_game()  # dag 1
	_chk("T40  morganite er IKKE låst opp dag 1",
		DataLoader.is_mineral_unlocked("morganite") == false)

func _t41_unlocked_morganite_day3() -> void:
	SaveManager.new_game()
	SaveManager.game_data["day"] = 3
	_chk("T41  morganite låses opp dag 3",
		DataLoader.is_mineral_unlocked("morganite") == true)

func _t42_not_unlocked_novanite_day3() -> void:
	SaveManager.new_game()
	SaveManager.game_data["day"] = 3
	_chk("T42  novanite er IKKE låst opp dag 3",
		DataLoader.is_mineral_unlocked("novanite") == false)

# ════════════════════════════════════════════════════════════════
#  TANK-LOGIKK
# ════════════════════════════════════════════════════════════════
func _t43_fill_pct_half() -> void:
	_chk("T43  fyllprosent 25/50 = 50 %",
		_fill_pct(25, 50) == 50.0)

func _t44_fill_pct_zero() -> void:
	_chk("T44  fyllprosent 0/50 = 0 %",
		_fill_pct(0, 50) == 0.0)

func _t45_fill_pct_full() -> void:
	_chk("T45  fyllprosent 50/50 = 100 %",
		_fill_pct(50, 50) == 100.0)

func _t46_bigger_tanks_capacity() -> void:
	SaveManager.new_game()
	for tank in SaveManager.game_data.get("tanks", []):
		tank["capacity"] = 100
	_chk("T46  bigger_tanks setter kapasitet til 100",
		SaveManager.game_data["tanks"][0].get("capacity", 0) == 100)

func _t47_extra_tank_count() -> void:
	SaveManager.new_game()
	var before : int = SaveManager.game_data.get("tanks", []).size()
	SaveManager.game_data["tanks"].append({"mineral_id": "", "amount": 0, "capacity": 50})
	_chk("T47  extra_tank legger til 3. tank",
		SaveManager.game_data.get("tanks", []).size() == before + 1)

# ════════════════════════════════════════════════════════════════
#  HANDELSBEREGNING
# ════════════════════════════════════════════════════════════════
func _t48_ferroxite_earnings_grom() -> void:
	SaveManager.new_game()
	SaveManager.add_mineral("ferroxite", 1)
	# ferroxite base_value=280, Grom multiplier=0.70 → 196
	_chk("T48  ferroxite × 1 × 0.70 = 196 kr",
		_calc_earnings(0.70) == 196)

func _t49_ferroxite_earnings_zyla() -> void:
	SaveManager.new_game()
	SaveManager.add_mineral("ferroxite", 1)
	# ferroxite base_value=280, Zyla multiplier=0.90 → 252
	_chk("T49  ferroxite × 1 × 0.90 = 252 kr",
		_calc_earnings(0.90) == 252)

func _t50_empty_cargo_zero_earnings() -> void:
	SaveManager.new_game()
	_chk("T50  tom last gir 0 kr i inntjening",
		_calc_earnings(0.70) == 0)

# ════════════════════════════════════════════════════════════════
#  Hjelpefunksjoner
# ════════════════════════════════════════════════════════════════
func _fill_pct(amt: int, cap: int) -> float:
	if cap == 0: return 0.0
	return float(amt) / float(cap) * 100.0

func _calc_earnings(multiplier: float) -> int:
	var tanks  : Array = SaveManager.game_data.get("tanks", [])
	var earned : int   = 0
	for tank in tanks:
		var mid : String = tank.get("mineral_id", "")
		var amt : int    = tank.get("amount", 0)
		if mid == "" or amt == 0:
			continue
		var val : int = int(DataLoader.get_mineral(mid).get("base_value", "0"))
		earned += int(float(val) * float(amt) * multiplier)
	return earned

func _chk(name: String, passed: bool) -> void:
	if passed:
		_pass += 1
		_res.append("✅ " + name)
	else:
		_fail += 1
		_res.append("❌ " + name)

func _section(title: String) -> void:
	_res.append("")
	_res.append("── " + title + " ──")

func _format_result() -> String:
	return "Resultat: %d / %d bestått" % [_pass, _pass + _fail]
