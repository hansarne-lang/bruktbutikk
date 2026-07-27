extends Node2D
## Del 1: Bruktbutikken

const SHOP_CAPACITY := 100

@onready var day_label      : Label  = $UI/HUD/DayLabel
@onready var money_label    : Label  = $UI/HUD/MoneyLabel
@onready var capacity_label : Label  = $UI/HUD/CapacityLabel
@onready var open_close_btn : Button = $UI/HUD/OpenCloseButton
@onready var inventory_row           = $UI/InventoryScroll/InventoryRow
@onready var wb_panel                = $UI/WorkbenchPanel
@onready var wb_item_name   : Label  = $UI/WorkbenchPanel/WorkbenchVBox/WBItemName
@onready var wb_condition   : Label  = $UI/WorkbenchPanel/WorkbenchVBox/WBCondition
@onready var wb_sell_price  : Label  = $UI/WorkbenchPanel/WorkbenchVBox/WBSellPrice
@onready var wb_wash_btn    : Button = $UI/WorkbenchPanel/WorkbenchVBox/WBWashButton
@onready var wb_repair_btn  : Button = $UI/WorkbenchPanel/WorkbenchVBox/WBRepairButton
@onready var wb_shelf_btn   : Button = $UI/WorkbenchPanel/WorkbenchVBox/WBShelfButton
@onready var wb_set_status  : Label  = $UI/WorkbenchPanel/WorkbenchVBox/WBSetStatus
@onready var wb_combine_btn : Button = $UI/WorkbenchPanel/WorkbenchVBox/WBCombineButton
@onready var wb_home_btn    : Button = $UI/WorkbenchPanel/WorkbenchVBox/WBHomeButton

var is_open     : bool = false
var inventory   : Array[ItemData] = []
var selected    : Array[ItemData] = []   # støtter multi-valg for sett

func _ready() -> void:
	open_close_btn.pressed.connect(_on_open_close)
	$UI/HUD/ArtRoomButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/sprite_room/SpriteRoom.tscn"))
	$UI/HUD/CleanupButton.pressed.connect(_on_go_cleanup)
	$UI/HUD/HomeButton.pressed.connect(_on_go_home)
	$UI/HUD/MainMenuButton.pressed.connect(_on_main_menu)
	wb_wash_btn.pressed.connect(_on_wash)
	wb_repair_btn.pressed.connect(_on_repair)
	wb_shelf_btn.pressed.connect(_on_place_on_shelf)
	wb_combine_btn.pressed.connect(_on_combine_set)
	wb_home_btn.pressed.connect(_on_take_home)
	$UI/WorkbenchPanel/WorkbenchVBox/WBCloseButton.pressed.connect(_close_workbench)

	_load_inventory()
	_update_hud()
	_refresh_inventory_ui()

	if inventory.is_empty():
		_add_test_items()

# ── HUD ──────────────────────────────────────────────────────
func _update_hud() -> void:
	var data := SaveManager.game_data
	day_label.text      = "Dag %d" % data.get("day", 1)
	money_label.text    = "%s kr" % _fmt(data.get("money", 0))
	open_close_btn.text = "Lukk butikk" if is_open else "Åpne butikk"
	var used := inventory.size()
	capacity_label.text = "📦 Lager: %d/%d" % [used, SHOP_CAPACITY]
	# Rød farge når nesten full
	if used >= SHOP_CAPACITY:
		capacity_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	elif used >= SHOP_CAPACITY * 0.8:
		capacity_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	else:
		capacity_label.remove_theme_color_override("font_color")

func _fmt(n: int) -> String:
	var s := str(n); var r := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0: r += " "
		r += s[i]
	return r

# ── Åpne/lukke ───────────────────────────────────────────────
func _on_open_close() -> void:
	is_open = !is_open
	_update_hud()
	if not is_open:
		SaveManager.game_data["day"] = SaveManager.game_data.get("day", 1) + 1
		SaveManager.save_game()
		_update_hud()

# ── Lager ────────────────────────────────────────────────────
func _load_inventory() -> void:
	inventory.clear()
	for d in SaveManager.game_data.get("inventory", []):
		inventory.append(ItemData.from_dict(d))

func _save_inventory() -> void:
	SaveManager.game_data["inventory"] = inventory.map(func(i): return i.to_dict())

func _add_test_items() -> void:
	var specs := [
		["lamp_01",     "Retro lampe",    "Belysning", 35, 150, 400, 50, 15, 100, 20],
		["chair_01",    "Teakstol",       "Møbler",    55, 200, 650, 80, 10, 200, 25],
		["c64_computer","Commodore 64",   "Retro",     40, 500,2800,120, 15, 600, 25],
		["c64_datasette","Datasette",     "Retro",     50, 200, 900, 80, 10, 300, 20],
		["c64_joystick","Competition Pro","Retro",     65, 100, 450, 40, 20,  80, 15],
	]
	for s in specs:
		var it := ItemData.new()
		it.id = s[0]; it.name = s[1]; it.category = s[2]
		it.condition_value = s[3]; it.base_buy_price = s[4]
		it.base_sell_price = s[5]; it.wash_cost = s[6]
		it.wash_condition_gain = s[7]; it.repair_cost = s[8]
		it.repair_condition_gain = s[9]
		inventory.append(it)
	_save_inventory()

# ── Varelager UI ─────────────────────────────────────────────
func _refresh_inventory_ui() -> void:
	for child in inventory_row.get_children():
		child.queue_free()
	for item in inventory:
		if item.is_sold: continue
		var btn := Button.new()
		var sel := item in selected
		btn.text = "%s%s\n%s | %s kr" % [
			"✓ " if sel else "",
			item.name,
			ItemData.condition_label(item.condition),
			_fmt(item.sell_price)
		]
		btn.custom_minimum_size = Vector2(160, 90)
		btn.pressed.connect(_on_item_selected.bind(item))
		var style := StyleBoxFlat.new()
		style.bg_color = (Color(0.1, 0.4, 0.1) if sel
			else ItemData.condition_color(item.condition).darkened(0.4))
		for corner in ["top_left","top_right","bottom_left","bottom_right"]:
			style.set("corner_radius_" + corner, 6)
		btn.add_theme_stylebox_override("normal", style)
		inventory_row.add_child(btn)

# ── Arbeidsbord – valg ────────────────────────────────────────
func _on_item_selected(item: ItemData) -> void:
	if item in selected:
		selected.erase(item)
	else:
		selected.append(item)
	wb_panel.visible = true
	_refresh_workbench_ui()
	_refresh_inventory_ui()

func _close_workbench() -> void:
	selected.clear()
	wb_panel.visible = false
	_refresh_inventory_ui()

func _refresh_workbench_ui() -> void:
	if selected.is_empty():
		_close_workbench()
		return

	var primary := selected[0]

	if selected.size() == 1:
		wb_item_name.text  = primary.name
		wb_condition.text  = "Tilstand: %s (%d/100)" % [ItemData.condition_label(primary.condition), primary.condition_value]
		wb_sell_price.text = "Salgspris: %s kr" % _fmt(primary.sell_price)
		wb_wash_btn.disabled   = primary.is_washed or primary.wash_cost == 0
		wb_repair_btn.disabled = primary.is_repaired or primary.repair_cost == 0
		wb_shelf_btn.disabled  = primary.is_on_shelf
		wb_wash_btn.text   = ("Allerede vasket" if primary.is_washed
			else "Vask (%s kr)  +%d" % [_fmt(primary.wash_cost), primary.wash_condition_gain])
		wb_repair_btn.text = ("Allerede reparert" if primary.is_repaired
			else "Reparer (%s kr)  +%d" % [_fmt(primary.repair_cost), primary.repair_condition_gain])
		# "Ta med hjem" for C64-utstyr og sett
		var is_homeable : bool = (primary.category in ["Elektronikk/Retro", "Sett"])
		wb_home_btn.visible = is_homeable
		if is_homeable:
			var already : bool = SaveManager.game_data.get("home_computer", false)
			wb_home_btn.text = ("🏠 Allerede hjemme – erstatt?" if already else "🏠 Ta med hjem")
	else:
		wb_item_name.text  = "%d varer valgt" % selected.size()
		wb_condition.text  = ""
		var total_val: int = 0
		for si in selected: total_val += si.sell_price
		wb_sell_price.text = "Samlet verdi: %s kr" % _fmt(total_val)
		wb_wash_btn.disabled   = true
		wb_repair_btn.disabled = true
		wb_shelf_btn.disabled  = true
		wb_home_btn.visible    = false

	_check_set_match()

# ── Sett-sjekk ───────────────────────────────────────────────
func _check_set_match() -> void:
	if selected.size() < 2:
		wb_set_status.text    = "Velg flere varer for å sjekke sett"
		wb_combine_btn.disabled = true
		return

	var selected_ids := selected.map(func(i): return i.id)
	var best_set_id  := ""
	var best_name    := ""
	var best_bonus   := 1.0
	var best_required: Array = []

	for set_id in DataLoader.sets:
		var s : Dictionary = DataLoader.sets[set_id]
		var required : Array = s.get("required_item_ids", "").split(",")
		required = required.map(func(x): return x.strip_edges())
		var all_present := required.all(func(r): return r in selected_ids)
		if all_present:
			var bonus := float(s.get("bonus_multiplier", 1.0))
			if bonus > best_bonus:
				best_set_id  = set_id
				best_name    = s.get("name", set_id)
				best_bonus   = bonus
				best_required = required

	if best_set_id != "":
		var base_val: int = 0
		for si2 in selected: base_val += si2.sell_price
		var set_val: int = int(base_val * best_bonus)
		wb_set_status.text = "🎉 %s\nVerdi: %s kr (×%.1f bonus!)" % [best_name, _fmt(set_val), best_bonus]
		wb_combine_btn.disabled = false
		wb_combine_btn.set_meta("set_id",    best_set_id)
		wb_combine_btn.set_meta("set_name",  best_name)
		wb_combine_btn.set_meta("set_value", set_val)
	else:
		wb_set_status.text    = "Ingen kjente sett matcher utvalget"
		wb_combine_btn.disabled = true

# ── Kombiner sett ────────────────────────────────────────────
func _on_combine_set() -> void:
	var set_name  : String = wb_combine_btn.get_meta("set_name",  "Sett")
	var set_value : int    = wb_combine_btn.get_meta("set_value", 0)

	var set_item := ItemData.new()
	set_item.id             = wb_combine_btn.get_meta("set_id", "set")
	set_item.name           = set_name
	set_item.category       = "Sett"
	var cond_sum: int = 0
	for si3 in selected: cond_sum += si3.condition_value
	set_item.condition_value = cond_sum / selected.size()
	set_item.base_sell_price = set_value
	set_item.description    = "Komplett sett satt sammen på arbeidsbordet"

	for item in selected:
		inventory.erase(item)
	inventory.append(set_item)
	_save_inventory()
	_update_hud()
	selected.clear()
	wb_panel.visible = false
	_refresh_inventory_ui()

# ── Ta med hjem ──────────────────────────────────────────────
func _on_take_home() -> void:
	var item := selected[0] if selected.size() == 1 else null
	if not item: return
	inventory.erase(item)
	var home_items : Array = SaveManager.game_data.get("home_items", [])
	home_items.append(item.to_dict())
	SaveManager.game_data["home_items"]    = home_items
	SaveManager.game_data["home_computer"] = true
	_save_inventory()
	SaveManager.save_game()
	_update_hud()
	selected.clear()
	wb_panel.visible = false
	_refresh_inventory_ui()

# ── Vask / Reparer / Hylle ───────────────────────────────────
func _on_wash() -> void:
	var item := selected[0] if selected.size() == 1 else null
	if not item: return
	var money : int = SaveManager.game_data.get("money", 0)
	if money < item.wash_cost:
		wb_condition.text = "Ikke nok penger!"; return
	SaveManager.game_data["money"] = money - item.wash_cost
	item.wash()
	_save_inventory(); _update_hud(); _refresh_workbench_ui(); _refresh_inventory_ui()

func _on_repair() -> void:
	var item := selected[0] if selected.size() == 1 else null
	if not item: return
	var money : int = SaveManager.game_data.get("money", 0)
	if money < item.repair_cost:
		wb_condition.text = "Ikke nok penger!"; return
	SaveManager.game_data["money"] = money - item.repair_cost
	item.repair()
	_save_inventory(); _update_hud(); _refresh_workbench_ui(); _refresh_inventory_ui()

func _on_place_on_shelf() -> void:
	var item := selected[0] if selected.size() == 1 else null
	if not item: return
	item.is_on_shelf = true
	_save_inventory()
	selected.clear()
	wb_panel.visible = false
	_refresh_inventory_ui()

# ── Navigasjon ───────────────────────────────────────────────
func _on_go_cleanup() -> void:
	SaveManager.game_data["current_location"] = "Ekebergveien 12, Oslo"
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://scenes/cleanup/Cleanup.tscn")

func _on_go_home() -> void:
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://scenes/home/Home.tscn")

func _on_main_menu() -> void:
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")
