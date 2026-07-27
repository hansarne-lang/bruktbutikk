class_name SetData
extends Resource
## SetData – et komplett sett av varer.
## Eksempel: "Stueinnredning" = sofa + salongbord + lampe

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var required_item_ids: Array[String] = []  # Item-IDer som må være med
@export var bonus_multiplier: float = 1.3          # 30% bonuspris for komplett sett

## Sjekk om en samling varer utgjør dette settet
func is_complete(items: Array[ItemData]) -> bool:
	var item_ids := items.map(func(i): return i.id)
	for required in required_item_ids:
		if required not in item_ids:
			return false
	return true

## Beregn totalverdi for settet (med bonus hvis komplett)
func total_value(items: Array[ItemData]) -> int:
	var base := 0
	for item in items:
		if item.id in required_item_ids:
			base += item.sell_price
	if is_complete(items):
		return int(base * bonus_multiplier)
	return base
