class_name ItemData
extends Resource
## ItemData – én vare i spillet.
## Opprett via DataLoader eller direkte i kode.

## ── Tilstandsnivåer ──────────────────────────────────────────
enum Condition {
	DESTROYED  = 0,  # Ødelagt   (0–20)
	WORN       = 1,  # Slitt     (21–40)
	USED       = 2,  # Brukt     (41–60)
	GOOD       = 3,  # God       (61–80)
	EXCELLENT  = 4,  # Utmerket  (81–100)
}

static func condition_label(c: Condition) -> String:
	match c:
		Condition.DESTROYED: return "Ødelagt"
		Condition.WORN:      return "Slitt"
		Condition.USED:      return "Brukt"
		Condition.GOOD:      return "God"
		Condition.EXCELLENT: return "Utmerket"
	return "Ukjent"

static func condition_color(c: Condition) -> Color:
	match c:
		Condition.DESTROYED: return Color(0.8, 0.1, 0.1)   # Rød
		Condition.WORN:      return Color(0.9, 0.5, 0.1)   # Oransje
		Condition.USED:      return Color(0.9, 0.85, 0.1)  # Gul
		Condition.GOOD:      return Color(0.3, 0.75, 0.3)  # Grønn
		Condition.EXCELLENT: return Color(0.2, 0.6, 1.0)   # Blå
	return Color.WHITE

## ── Basisdata (fra CSV) ──────────────────────────────────────
@export var id: String = ""
@export var name: String = ""
@export var category: String = ""
@export var description: String = ""
@export var set_id: String = ""        # Tom = ikke del av sett

## ── Tilstand (0–100) ─────────────────────────────────────────
@export var condition_value: int = 50  # Starttilstand

var condition: Condition:
	get:
		if condition_value <= 20: return Condition.DESTROYED
		elif condition_value <= 40: return Condition.WORN
		elif condition_value <= 60: return Condition.USED
		elif condition_value <= 80: return Condition.GOOD
		else: return Condition.EXCELLENT

## ── Priser ───────────────────────────────────────────────────
@export var base_buy_price: int = 0    # Hva du betalte / fant det for
@export var base_sell_price: int = 0   # Grunnpris ved God tilstand

## Salgspris justert etter tilstand
var sell_price: int:
	get:
		var multiplier: float = [0.1, 0.4, 0.7, 1.0, 1.35][int(condition)]
		return int(base_sell_price * multiplier)

## ── Vask og reparasjon ───────────────────────────────────────
@export var wash_cost: int = 0         # Kroner å vaske
@export var wash_condition_gain: int = 10  # Tilstandsøkning ved vask
@export var repair_cost: int = 0       # Kroner å reparere
@export var repair_condition_gain: int = 20  # Tilstandsøkning ved rep.
@export var max_condition: int = 100   # Noen varer kan ikke bli perfekte

## ── Status ───────────────────────────────────────────────────
var is_washed: bool = false
var is_repaired: bool = false
var is_on_shelf: bool = false
var is_sold: bool = false

## ── Metoder ──────────────────────────────────────────────────
func wash() -> bool:
	if is_washed or wash_cost == 0:
		return false
	condition_value = mini(condition_value + wash_condition_gain, max_condition)
	is_washed = true
	return true

func repair() -> bool:
	if is_repaired or repair_cost == 0:
		return false
	condition_value = mini(condition_value + repair_condition_gain, max_condition)
	is_repaired = true
	return true

func to_dict() -> Dictionary:
	return {
		"id": id, "name": name, "category": category,
		"condition_value": condition_value,
		"is_washed": is_washed, "is_repaired": is_repaired,
		"is_on_shelf": is_on_shelf, "is_sold": is_sold,
		"set_id": set_id
	}

static func from_dict(d: Dictionary) -> ItemData:
	var item := ItemData.new()
	item.id = d.get("id", "")
	item.name = d.get("name", "")
	item.category = d.get("category", "")
	item.condition_value = d.get("condition_value", 50)
	item.is_washed = d.get("is_washed", false)
	item.is_repaired = d.get("is_repaired", false)
	item.is_on_shelf = d.get("is_on_shelf", false)
	item.is_sold = d.get("is_sold", false)
	item.set_id = d.get("set_id", "")
	return item
