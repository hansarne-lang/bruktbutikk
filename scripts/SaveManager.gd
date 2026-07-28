extends Node
## SaveManager – Autoload singleton
## Haandterer lagring og lasting av spilldata for Void Miner.

const SAVE_PATH = "user://save_game.json"

var game_data: Dictionary = {}

func has_active_game() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func new_game() -> void:
	game_data = {
		"day":             1,
		"credits":         1200,
		"base_level":      1,
		"ship_level":      1,
		"location":        "base",
		"tanks": [
			{"mineral_id": "", "amount": 0, "capacity": 50},
			{"mineral_id": "", "amount": 0, "capacity": 50},
		],
		"mined_total":     0,
		"trades_done":     0,
		# Oppgraderinger
		"drill_upgraded":  false,
		"extra_tank":      false,
		"bigger_tanks":    false,
		# Dag/natt
		"time_of_day":     0.0,
		# Handler
		"last_earned":     0,
		"last_trader":     "",
		"chosen_trader":   1,
		"trade_log":       [],
		# Stasjonsnavn
		"moon_name":       "Luna-7 Mining Station",
		# Gruvekart
		"current_zone":    "",
		"ground_scanner":  false,
		"drill_sites":     _gen_drill_sites(),
		# Motorrom
		"ship_components": _default_ship_components(),
		"repair_skill":    0.0,
		"repair_tools":    [],
		"pending_orders":  [],
		# Skip-lasterom
		"ship_cargo":          [],
		"ship_cargo_capacity": 40,
		# Mining-tilstand (synkes fra Base.gd)
		"mining_active":       false,
		# Våpen
		"torpedoes":           0,
		"battery_capacity":    100,
		"battery_charge":      100.0,
		"battery_upgrade":     false,
	}

func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: Kunne ikke åpne fil for skriving")
		return
	file.store_string(JSON.stringify(game_data, "\t"))
	file.close()

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var result = JSON.parse_string(file.get_as_text())
	file.close()
	if result == null or not result is Dictionary:
		return false
	game_data = result
	# Migrasjon – fyll inn manglende felt
	if not game_data.has("day"):            game_data["day"]            = 1
	if not game_data.has("credits"):        game_data["credits"]        = 1200
	if not game_data.has("base_level"):     game_data["base_level"]     = 1
	if not game_data.has("ship_level"):     game_data["ship_level"]     = 1
	if not game_data.has("location"):       game_data["location"]       = "base"
	if not game_data.has("tanks"):          game_data["tanks"]          = [
		{"mineral_id": "", "amount": 0, "capacity": 50},
		{"mineral_id": "", "amount": 0, "capacity": 50},
	]
	if not game_data.has("mined_total"):    game_data["mined_total"]    = 0
	if not game_data.has("trades_done"):    game_data["trades_done"]    = 0
	if not game_data.has("drill_upgraded"): game_data["drill_upgraded"] = false
	if not game_data.has("extra_tank"):     game_data["extra_tank"]     = false
	if not game_data.has("bigger_tanks"):   game_data["bigger_tanks"]   = false
	if not game_data.has("time_of_day"):    game_data["time_of_day"]    = 0.0
	if not game_data.has("last_earned"):    game_data["last_earned"]    = 0
	if not game_data.has("last_trader"):    game_data["last_trader"]    = ""
	if not game_data.has("chosen_trader"):  game_data["chosen_trader"]  = 1
	if not game_data.has("trade_log"):      game_data["trade_log"]      = []
	if not game_data.has("moon_name"):        game_data["moon_name"]        = "Luna-7 Mining Station"
	if not game_data.has("current_zone"):     game_data["current_zone"]     = ""
	if not game_data.has("ground_scanner"):   game_data["ground_scanner"]   = false
	if not game_data.has("drill_sites"):      game_data["drill_sites"]      = _gen_drill_sites()
	if not game_data.has("ship_components"):      game_data["ship_components"]      = _default_ship_components()
	if not game_data.has("repair_skill"):         game_data["repair_skill"]         = 0.0
	if not game_data.has("repair_tools"):         game_data["repair_tools"]         = []
	if not game_data.has("pending_orders"):       game_data["pending_orders"]       = []
	if not game_data.has("ship_cargo"):           game_data["ship_cargo"]           = []
	if not game_data.has("ship_cargo_capacity"):  game_data["ship_cargo_capacity"]  = 40
	if not game_data.has("mining_active"):        game_data["mining_active"]        = false
	if not game_data.has("torpedoes"):            game_data["torpedoes"]            = 0
	if not game_data.has("battery_capacity"):     game_data["battery_capacity"]     = 100
	if not game_data.has("battery_charge"):       game_data["battery_charge"]       = 100.0
	if not game_data.has("battery_upgrade"):      game_data["battery_upgrade"]      = false
	# Migrasjon: legg til nye skipkomponenter hvis de mangler
	var comps : Array = game_data.get("ship_components", [])
	var comp_ids : Array = []
	for c in comps:
		comp_ids.append(c.get("id", ""))
	if not comp_ids.has("shield"):
		comps.append({"id": "shield",       "name": "Skjold",      "condition": 100, "level": 1})
	if not comp_ids.has("laser_cannon"):
		comps.append({"id": "laser_cannon", "name": "Laserkanon",  "condition": 100, "level": 1})
	if not comp_ids.has("torpedo"):
		comps.append({"id": "torpedo",      "name": "Torpedorør",  "condition": 100, "level": 1})
	game_data["ship_components"] = comps
	return true

func _gen_drill_sites() -> Array:
	var cats := ["Metall", "Metall", "Krystall", "Krystall", "Mineral",
				 "Mineral", "Element", "Element", "Gass", "Ukjent",
				 "Krystall", "Metall"]
	cats.shuffle()
	var sites : Array = []
	for i in 12:
		sites.append({"id": i, "category": cats[i]})
	return sites

## Beregn totalt antall enheter i alle tanker
func total_minerals() -> int:
	var total := 0
	for tank in game_data.get("tanks", []):
		total += tank.get("amount", 0)
	return total

## Legg til mineral i foerste ledige tank
func add_mineral(mineral_id: String, amount: int = 1) -> bool:
	var tanks : Array = game_data.get("tanks", [])
	for tank in tanks:
		if tank["mineral_id"] == mineral_id:
			if tank["amount"] < tank["capacity"]:
				tank["amount"] += amount
				game_data["mined_total"] += amount
				return true
	for tank in tanks:
		if tank["mineral_id"] == "" and tank["amount"] == 0:
			tank["mineral_id"] = mineral_id
			tank["amount"]     = amount
			game_data["mined_total"] += amount
			return true
	return false

## Toem alle tanker (etter salg)
func empty_tanks() -> void:
	for tank in game_data.get("tanks", []):
		tank["mineral_id"] = ""
		tank["amount"]     = 0

## ── Skip-lasterom ────────────────────────────────────────────────

## Totalt antall enheter om bord i skipet
func get_ship_cargo_used() -> int:
	var total : int = 0
	for item in game_data.get("ship_cargo", []):
		total += item.get("amount", 0)
	return total

## Prøv å laste mineral fra gruve-tanker til skipets lasterom.
## Returnerer faktisk lastet antall.
func load_to_ship_cargo(mineral_id: String, amount: int) -> int:
	if mineral_id == "" or amount <= 0:
		return 0
	var cap   : int   = game_data.get("ship_cargo_capacity", 40)
	var used  : int   = get_ship_cargo_used()
	var space : int   = max(0, cap - used)
	var load  : int   = min(amount, space)
	if load <= 0:
		return 0
	# Finn / opprett plass i ship_cargo
	var cargo : Array = game_data.get("ship_cargo", [])
	var found : bool  = false
	for item in cargo:
		if item.get("mineral_id", "") == mineral_id:
			item["amount"] += load
			found = true
			break
	if not found:
		cargo.append({"mineral_id": mineral_id, "amount": load})
		game_data["ship_cargo"] = cargo
	# Trekk fra gruve-tankene
	_remove_from_tanks(mineral_id, load)
	return load

## Flytt mineral tilbake fra skip-lasterom til gruve-tanker
func unload_from_ship_cargo(mineral_id: String) -> void:
	var cargo : Array = game_data.get("ship_cargo", [])
	for i in cargo.size():
		if cargo[i].get("mineral_id", "") != mineral_id:
			continue
		var amt   : int   = cargo[i].get("amount", 0)
		var tanks : Array = game_data.get("tanks", [])
		# Prøv eksisterende tank
		for tank in tanks:
			if tank.get("mineral_id", "") == mineral_id:
				var space : int = tank.get("capacity", 50) - tank.get("amount", 0)
				var put   : int = min(amt, space)
				tank["amount"] += put
				amt -= put
				break
		# Prøv tom tank
		if amt > 0:
			for tank in tanks:
				if tank.get("mineral_id", "") == "" or tank.get("amount", 0) == 0:
					tank["mineral_id"] = mineral_id
					tank["amount"]     = amt
					amt = 0
					break
		cargo.remove_at(i)
		break
	game_data["ship_cargo"] = cargo

## Trekk ut antall fra gruve-tankene (intern hjelpefunksjon)
func _remove_from_tanks(mineral_id: String, amount: int) -> void:
	var tanks : Array = game_data.get("tanks", [])
	var rem   : int   = amount
	for tank in tanks:
		if tank.get("mineral_id", "") == mineral_id and rem > 0:
			var take : int = min(tank.get("amount", 0), rem)
			tank["amount"] -= take
			rem            -= take
			if tank["amount"] <= 0:
				tank["mineral_id"] = ""
				tank["amount"]     = 0

## Tøm skip-lasterom etter salg
func empty_ship_cargo() -> void:
	game_data["ship_cargo"] = []

## ── Motorrom ─────────────────────────────────────────────────────

func _default_ship_components() -> Array:
	return [
		{"id": "engine",       "name": "Drivverk",   "condition": 100, "level": 1},
		{"id": "reactor",      "name": "Reaktor",    "condition": 100, "level": 1},
		{"id": "drill_head",   "name": "Boresystem", "condition": 100, "level": 1},
		{"id": "life_support", "name": "Livsstøtte", "condition": 100, "level": 1},
		{"id": "navigation",   "name": "Navigasjon", "condition": 100, "level": 1},
		{"id": "shield",       "name": "Skjold",     "condition": 100, "level": 1},
		{"id": "laser_cannon", "name": "Laserkanon", "condition": 100, "level": 1},
		{"id": "torpedo",      "name": "Torpedorør", "condition": 100, "level": 1},
	]

## Skader et tilfeldig skipkomponent (kall fraa mine-tikk)
func apply_mine_damage() -> void:
	if randf() > 0.06:   # 6 % sjanse per tikk
		return
	var comps : Array = game_data.get("ship_components", [])
	if comps.is_empty():
		return
	var target : Dictionary = comps[randi() % comps.size()]
	var level  : int        = target.get("level", 1)
	var resist : float      = 1.0 - (level - 1) * 0.18   # niv. 2 = 82 %, niv. 3 = 64 %...
	var dmg    : int        = max(1, int(randf_range(1.0, 4.0) * resist))
	target["condition"] = max(0, target.get("condition", 100) - dmg)

## Reparasjonsfart (condition-poeng per tikk)
func get_repair_speed() -> float:
	var skill  : float = game_data.get("repair_skill", 0.0)
	var tools  : Array = game_data.get("repair_tools", [])
	var base   : float = 5.0 + skill * 1.5
	var bonus  : float = 0.0
	for t in tools:
		match t:
			"basic_toolkit":     bonus += 5.0
			"calibrated_wrench": bonus += 15.0
			"nano_repair_kit":   bonus += 35.0
	return base + bonus

## Effektivt mine-intervall basert paa engine/reaktor-kondisjon
func get_effective_mine_interval(base_interval: float) -> float:
	var comps    : Array = game_data.get("ship_components", [])
	var eng_cond : int   = 100
	var react    : int   = 100
	for c in comps:
		match c.get("id", ""):
			"engine":  eng_cond = c.get("condition", 100)
			"reactor": react    = c.get("condition", 100)
	# Reaktor-skade forsterker motor-effekten (opp til 30 %)
	var react_mult  : float = lerp(1.3, 1.0, react / 100.0)
	var eng_penalty : float = lerp(3.0, 0.0, eng_cond / 100.0) * react_mult
	return base_interval + eng_penalty

## Drill-effektivitet 0.4–1.0 (sjanse for aa faktisk utvinne mineral)
func get_drill_efficiency() -> float:
	var comps : Array = game_data.get("ship_components", [])
	var drill : int   = 100
	var react : int   = 100
	for c in comps:
		match c.get("id", ""):
			"drill_head": drill = c.get("condition", 100)
			"reactor":    react = c.get("condition", 100)
	var react_mult : float = lerp(1.3, 1.0, react / 100.0)
	var eff        : float = lerp(0.40, 1.0, drill / 100.0)
	return clamp(eff / react_mult, 0.05, 1.0)

## Plasser en bestilling (trekker kreditter)
func place_order(item_id: String, item_name: String, cost: int,
		deliver_days: int, extra: Dictionary = {}) -> void:
	game_data["credits"] = game_data.get("credits", 0) - cost
	var order := {
		"item_id":    item_id,
		"item_name":  item_name,
		"deliver_day": game_data.get("day", 1) + deliver_days,
	}
	order.merge(extra)
	var orders : Array = game_data.get("pending_orders", [])
	orders.append(order)
	game_data["pending_orders"] = orders

## Leverer modne bestillinger, returnerer liste over leverte varer
func check_and_deliver_orders() -> Array:
	var day       : int   = game_data.get("day", 1)
	var orders    : Array = game_data.get("pending_orders", [])
	var delivered : Array = []
	var remaining : Array = []
	for order in orders:
		if order.get("deliver_day", 9999) <= day:
			delivered.append(order)
			_apply_order(order)
		else:
			remaining.append(order)
	game_data["pending_orders"] = remaining
	return delivered

func _apply_order(order: Dictionary) -> void:
	var item_id : String = order.get("item_id", "")
	if item_id in ["basic_toolkit", "calibrated_wrench", "nano_repair_kit"]:
		var tools : Array = game_data.get("repair_tools", [])
		if item_id not in tools:
			tools.append(item_id)
		game_data["repair_tools"] = tools
	elif order.has("comp_id"):
		var comp_id   : String = order["comp_id"]
		var new_level : int    = order.get("new_level", 2)
		for comp in game_data.get("ship_components", []):
			if comp.get("id", "") == comp_id:
				if new_level > comp.get("level", 1):
					comp["level"] = new_level
				break
	elif item_id == "extra_tank_order":
		if not game_data.get("extra_tank", false):
			game_data["extra_tank"] = true
			var tanks : Array = game_data.get("tanks", [])
			tanks.append({"mineral_id": "", "amount": 0, "capacity": 50})
			game_data["tanks"] = tanks
	elif item_id == "drill_upgraded":
		game_data["drill_upgraded"] = true
	elif item_id == "bigger_tanks":
		if not game_data.get("bigger_tanks", false):
			game_data["bigger_tanks"] = true
			for tank in game_data.get("tanks", []):
				tank["capacity"] = 100
	elif item_id == "ground_scanner":
		game_data["ground_scanner"] = true
	elif item_id == "battery_upgrade":
		game_data["battery_upgrade"]  = true
		game_data["battery_capacity"] = 200
		game_data["battery_charge"]   = 200.0
	elif item_id in ["torpedoes_5", "torpedoes_10"]:
		var amt : int = 10 if item_id == "torpedoes_10" else 5
		game_data["torpedoes"] = game_data.get("torpedoes", 0) + amt

## ─────────────────────────────────────────────────────────────────
## Legg til logginnslag
func add_trade_log(earned: int, trader: String) -> void:
	var log_arr : Array = game_data.get("trade_log", [])
	log_arr.append({
		"day":    game_data.get("day", 1),
		"earned": earned,
		"trader": trader,
	})
	# Behold maks 50 innslag
	if log_arr.size() > 50:
		log_arr = log_arr.slice(log_arr.size() - 50)
	game_data["trade_log"] = log_arr
