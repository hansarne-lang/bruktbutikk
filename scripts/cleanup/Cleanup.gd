extends Node2D
## Del 2: Rydding av dødsbo
## Klikk på gjenstander, vurder om de skal i bilen eller kastes.
## Bilen har begrenset kapasitet – kjør til butikk eller søppelplass.

const CAR_CAPACITY := 10

@onready var location_label   : Label         = $UI/HUD/LocationLabel
@onready var day_label        : Label         = $UI/HUD/DayLabel
@onready var car_capacity_lbl : Label         = $UI/CarPanel/CarVBox/CarCapacityLabel
@onready var car_bar          : ProgressBar   = $UI/CarPanel/CarVBox/CarProgressBar
@onready var car_item_list    : VBoxContainer = $UI/CarPanel/CarVBox/CarItemList
@onready var item_panel                       = $UI/ItemPanel
@onready var item_name_lbl    : Label         = $UI/ItemPanel/ItemVBox/ItemName
@onready var item_cond_lbl    : Label         = $UI/ItemPanel/ItemVBox/ItemCondition
@onready var item_value_lbl   : Label         = $UI/ItemPanel/ItemVBox/ItemEstValue
@onready var item_weight_lbl  : Label         = $UI/ItemPanel/ItemVBox/ItemWeight
@onready var item_desc_lbl    : Label         = $UI/ItemPanel/ItemVBox/ItemDesc
@onready var take_btn         : Button        = $UI/ItemPanel/ItemVBox/ItemButtons/TakeButton
@onready var throw_btn        : Button        = $UI/ItemPanel/ItemVBox/ItemButtons/ThrowButton
@onready var status_label     : Label         = $UI/StatusLabel
@onready var room_cleared_panel               = $UI/RoomClearedPanel
@onready var items_node                       = $Items

var current_item : ItemData = null
var car_items    : Array[ItemData] = []
var car_load     : int = 0
var room_items   : Array[ItemData] = []

const ROOM_LAYOUT := [
	["sofa_01",       120, 360, 220, 110, Color(0.40, 0.18, 0.12)],
	["table_01",      420, 390, 160,  80, Color(0.50, 0.35, 0.15)],
	["lamp_01",       660, 300,  60, 160, Color(0.65, 0.60, 0.20)],
	["book_lot",      820, 370, 120,  90, Color(0.25, 0.25, 0.45)],
	["chair_01",      100, 200,  90, 120, Color(0.35, 0.20, 0.10)],
	["wardrobe_01",   280, 150, 140, 280, Color(0.30, 0.22, 0.12)],
	["breakout_cart", 190, 420,  55,  35, Color(0.15, 0.10, 0.35)],  # kassett bak sofaen
]

func _ready() -> void:
	var data := SaveManager.game_data
	day_label.text      = "Dag %d" % data.get("day", 1)
	location_label.text = "📍 %s" % data.get("current_location", "Ukjent adresse")

	$UI/HUD/ShopButton.pressed.connect(_on_go_shop)
	$UI/HUD/MainMenuButton.pressed.connect(_on_main_menu)
	$UI/CarPanel/CarVBox/CarButtons/DriveShopButton.pressed.connect(_on_drive_to_shop)
	$UI/CarPanel/CarVBox/CarButtons/DriveDumpButton.pressed.connect(_on_drive_to_dump)
	take_btn.pressed.connect(_on_take_item)
	throw_btn.pressed.connect(_on_throw_item)
	$UI/ItemPanel/ItemVBox/CloseItemButton.pressed.connect(func(): item_panel.visible = false)

	_spawn_room_items()
	_update_car_ui()

# ── Spawn gjenstander ─────────────────────────────────────────
func _spawn_room_items() -> void:
	for layout in ROOM_LAYOUT:
		var item := _make_item(layout[0])
		room_items.append(item)

		var rect := ColorRect.new()
		rect.color    = layout[5]
		rect.position = Vector2(layout[1], layout[2])
		rect.size     = Vector2(layout[3], layout[4])
		rect.set_meta("item_id", item.id)
		items_node.add_child(rect)

		var area  := Area2D.new()
		var col   := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size   = rect.size
		col.shape    = shape
		col.position = rect.position + rect.size / 2.0
		area.add_child(col)
		area.input_pickable = true
		area.input_event.connect(_on_item_clicked.bind(item, rect))
		items_node.add_child(area)

		var lbl := Label.new()
		lbl.text     = item.name
		lbl.position = rect.position + Vector2(4, rect.size.y / 2.0 - 10)
		lbl.add_theme_font_size_override("font_size", 11)
		items_node.add_child(lbl)

func _make_item(id: String) -> ItemData:
	var item := ItemData.new()
	item.id = id
	var csv : Dictionary = DataLoader.items.get(id, {})
	item.name                  = csv.get("name", id)
	item.category              = csv.get("category", "Ukjent")
	item.description           = csv.get("description", "")
	item.base_sell_price       = int(csv.get("base_sell_price", 200))
	item.wash_cost             = int(csv.get("wash_cost", 50))
	item.wash_condition_gain   = int(csv.get("wash_condition_gain", 10))
	item.repair_cost           = int(csv.get("repair_cost", 100))
	item.repair_condition_gain = int(csv.get("repair_condition_gain", 20))
	item.condition_value       = randi_range(10, 70)
	return item

# ── Klikk ────────────────────────────────────────────────────
func _on_item_clicked(_vp, event, _shape, item: ItemData, _rect: ColorRect) -> void:
	if not event is InputEventMouseButton: return
	if not (event as InputEventMouseButton).pressed: return
	if item.is_sold or item.is_on_shelf: return

	current_item        = item
	item_name_lbl.text  = item.name
	item_cond_lbl.text  = "Tilstand: %s (%d/100)" % [ItemData.condition_label(item.condition), item.condition_value]
	item_value_lbl.text = "Anslått verdi: ca. %d kr" % item.sell_price
	item_weight_lbl.text = "Størrelse: 1 enhet"
	item_desc_lbl.text  = item.description
	take_btn.disabled   = car_load >= CAR_CAPACITY
	item_panel.visible  = true

# ── Legg i bil ───────────────────────────────────────────────
func _on_take_item() -> void:
	if not current_item or car_load >= CAR_CAPACITY: return
	current_item.is_on_shelf = true
	car_items.append(current_item)
	car_load += 1
	_dim_item(current_item, Color(0.2, 0.5, 0.2, 0.6))
	_update_car_ui()
	item_panel.visible = false
	_check_room_cleared()

# ── Kast ─────────────────────────────────────────────────────
func _on_throw_item() -> void:
	if not current_item: return
	current_item.is_sold = true
	_dim_item(current_item, Color(0.4, 0.1, 0.1, 0.6))
	item_panel.visible = false
	_set_status("🗑 %s ble kastet." % current_item.name)
	_check_room_cleared()

func _dim_item(item: ItemData, tint: Color) -> void:
	for child in items_node.get_children():
		if child is ColorRect and child.get_meta("item_id", "") == item.id:
			child.color = tint

# ── Bil UI ───────────────────────────────────────────────────
func _update_car_ui() -> void:
	car_capacity_lbl.text = "Kapasitet: %d / %d" % [car_load, CAR_CAPACITY]
	car_bar.value         = car_load
	for child in car_item_list.get_children():
		child.queue_free()
	for it in car_items:
		var lbl := Label.new()
		lbl.text = "• %s (%s)" % [it.name, ItemData.condition_label(it.condition)]
		lbl.add_theme_font_size_override("font_size", 12)
		car_item_list.add_child(lbl)

# ── Kjør til butikk ──────────────────────────────────────────
func _on_drive_to_shop() -> void:
	if car_items.is_empty():
		_set_status("Bilen er tom – legg noe i den først.")
		return
	var inventory : Array = SaveManager.game_data.get("inventory", [])
	for item in car_items:
		item.is_on_shelf = false
		inventory.append(item.to_dict())
	SaveManager.game_data["inventory"] = inventory
	_set_status("✅ %d ting levert til butikken!" % car_items.size())
	car_items.clear()
	car_load = 0
	_update_car_ui()
	SaveManager.save_game()

# ── Kjør til søppelplass ─────────────────────────────────────
func _on_drive_to_dump() -> void:
	if car_items.is_empty():
		_set_status("Bilen er tom.")
		return
	_set_status("🗑 %d ting kjørt til søppelplassen." % car_items.size())
	car_items.clear()
	car_load = 0
	_update_car_ui()

# ── Rom ryddet ───────────────────────────────────────────────
func _check_room_cleared() -> void:
	if room_items.all(func(i): return i.is_sold or i.is_on_shelf):
		room_cleared_panel.visible = true

func _set_status(msg: String) -> void:
	status_label.text = msg

# ── Navigasjon ───────────────────────────────────────────────
func _on_go_shop() -> void:
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://scenes/shop/Shop.tscn")

func _on_main_menu() -> void:
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")
