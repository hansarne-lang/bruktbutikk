extends Node2D
## Del 2: Rydding av dødsbo
## Tre rom side om side: stue, soverom, kjøkken.
## Klikk på gjenstander, vurder om de skal i bilen eller kastes.

const CAR_CAPACITY := 10

const FurnitureSprite = preload("res://scripts/cleanup/FurnitureSprite.gd")
const RoomBackground  = preload("res://scripts/cleanup/RoomBackground.gd")

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

var current_item  : ItemData = null
var car_items     : Array[ItemData] = []
var car_load      : int = 0
var room_items    : Array[ItemData] = []
var _item_sprites : Dictionary = {}   # item.id -> Node2D sprite

# ── Rompooler ─────────────────────────────────────────────────
# Format: [item_id, rel_x, rel_y, bredde, høyde, optional=false]
const ROOM_SECTIONS := [
	{
		"label": "STUE", "x_start": 10, "opt_chance": 0.40,
		"items": [
			["sofa_01",    18, 320, 220,  82],
			["lamp_01",   225, 220,  40, 135],
			["chair_01",   18, 212,  74, 102],
			["book_lot",  140, 360,  95,  68],
			["breakout_cart", 52, 396, 52, 30, true],
		],
	},
	{
		"label": "SOVEROM", "x_start": 304, "opt_chance": 0.55,
		"items": [
			["wardrobe_01",  8,  96, 118, 268],
			["lamp_01",    202, 240,  38, 120],
			["chair_01",   152, 322,  70,  98],
			["book_lot",    12, 368,  88,  64],
			["c64_computer", 122, 364,  95,  54, true],
			["c64_datasette", 30, 392,  72,  40, true],
			["c64_joystick", 208, 392,  54,  36, true],
		],
	},
	{
		"label": "KJØKKEN", "x_start": 598, "opt_chance": 0.40,
		"items": [
			["table_01",   52, 344, 164,  62],
			["chair_01",  172, 258,  70,  94],
			["lamp_01",    12, 238,  38, 124],
			["book_lot",   12, 364,  84,  62],
			["c64_box",   200, 372,  60,  44, true],
		],
	},
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
	# Romsbakgrunn
	var bg := RoomBackground.new()
	items_node.add_child(bg)

	for sec in ROOM_SECTIONS:
		var xo : int = sec["x_start"]

		for entry in sec["items"]:
			var item_id  : String = entry[0]
			var optional : bool   = entry.size() > 5 and entry[5] == true
			if optional and randf() > sec["opt_chance"]:
				continue

			var item := _make_item(item_id)
			room_items.append(item)

			var rel_x  : int = entry[1]
			var rel_y  : int = entry[2]
			var w      : int = entry[3]
			var h      : int = entry[4]
			var world_x := xo + rel_x
			var world_y := rel_y

			# Møbel-sprite
			var sprite := FurnitureSprite.new()
			sprite.position = Vector2(world_x, world_y)
			sprite.setup(item_id, Vector2(w, h))
			sprite.set_meta("item_id", item.id)
			items_node.add_child(sprite)
			_item_sprites[item.id] = sprite

			# Klikk-area
			var area  := Area2D.new()
			var col   := CollisionShape2D.new()
			var shape := RectangleShape2D.new()
			shape.size   = Vector2(w, h)
			col.shape    = shape
			col.position = Vector2(world_x + w / 2.0, world_y + h / 2.0)
			area.add_child(col)
			area.input_pickable = true
			area.input_event.connect(_on_item_clicked.bind(item))
			items_node.add_child(area)

			# Navnelapp
			var lbl := Label.new()
			lbl.text     = item.name
			lbl.position = Vector2(world_x + 3, world_y + h / 2.0 - 8)
			lbl.add_theme_font_size_override("font_size", 10)
			lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.78))
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

# ── Prisantydning ─────────────────────────────────────────────
func _value_hint(item: ItemData) -> String:
	var v := item.condition_value
	if v >= 80:   return "✨ Ser svært verdifull ut!"
	elif v >= 62: return "👍 Ganske fin stand"
	elif v >= 45: return "😐 Middels – litt bruk og slit"
	elif v >= 25: return "😕 Nokså slitt og medtatt"
	else:          return "😬 Veldig dårlig stand"

# ── Klikk ────────────────────────────────────────────────────
func _on_item_clicked(_vp, event, _shape, item: ItemData) -> void:
	if not event is InputEventMouseButton: return
	if not (event as InputEventMouseButton).pressed: return
	if item.is_sold or item.is_on_shelf: return

	SoundManager.play("item_click")
	current_item          = item
	item_name_lbl.text    = item.name
	item_cond_lbl.text    = "Tilstand: %s (%d/100)" % [
		ItemData.condition_label(item.condition), item.condition_value
	]
	item_value_lbl.text  = _value_hint(item)
	item_weight_lbl.text = "Størrelse: 1 enhet"
	item_desc_lbl.text   = item.description
	take_btn.disabled    = car_load >= CAR_CAPACITY
	item_panel.visible   = true

# ── Legg i bil ───────────────────────────────────────────────
func _on_take_item() -> void:
	if not current_item or car_load >= CAR_CAPACITY: return
	SoundManager.play("item_take")
	current_item.is_on_shelf = true
	car_items.append(current_item)
	car_load += 1
	_tint_sprite(current_item.id, Color(0.30, 1.0, 0.30, 0.62))
	_update_car_ui()
	item_panel.visible = false
	_check_room_cleared()

# ── Kast ─────────────────────────────────────────────────────
func _on_throw_item() -> void:
	if not current_item: return
	SoundManager.play("item_throw")
	current_item.is_sold = true
	_tint_sprite(current_item.id, Color(1.0, 0.30, 0.30, 0.55))
	item_panel.visible = false
	_set_status("🗑 %s ble kastet." % current_item.name)
	_check_room_cleared()

func _tint_sprite(id: String, col: Color) -> void:
	if id in _item_sprites:
		_item_sprites[id].modulate = col

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
	SoundManager.play("door_open")
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
	SoundManager.play("item_throw")
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
