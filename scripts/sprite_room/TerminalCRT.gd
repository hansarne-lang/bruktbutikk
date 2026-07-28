extends Control
## Subtile CRT-scanlines – ingen gradient

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 20

func _draw() -> void:
	var w := size.x
	var h := size.y
	var y := 0.0
	while y < h:
		draw_rect(Rect2(0, y, w, 1.0), Color(0, 0, 0, 0.14))
		y += 3.0
