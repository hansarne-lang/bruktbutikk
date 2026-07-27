extends Node2D
## Tegner tre romseksjoner: stue, soverom, kjøkken

const WALL_TOP  := 58
const FLOOR_TOP := 410
const WALL_BOT  := 490
const PILLAR_W  := 14

const SECTIONS := [
	{
		"label": "STUE",
		"x": 10, "w": 280,
		"wall":  Color(0.22, 0.15, 0.09),
		"floor": Color(0.42, 0.30, 0.16),
		"trim":  Color(0.32, 0.22, 0.10),
	},
	{
		"label": "SOVEROM",
		"x": 304, "w": 280,
		"wall":  Color(0.14, 0.17, 0.24),
		"floor": Color(0.28, 0.24, 0.34),
		"trim":  Color(0.22, 0.18, 0.30),
	},
	{
		"label": "KJOKKEN",
		"x": 598, "w": 280,
		"wall":  Color(0.20, 0.22, 0.18),
		"floor": Color(0.44, 0.40, 0.36),
		"trim":  Color(0.32, 0.28, 0.24),
	},
]

func _draw() -> void:
	var font := ThemeDB.fallback_font

	for i in SECTIONS.size():
		var s : Dictionary = SECTIONS[i]
		var x : int = s.x
		var w : int = s.w

		# Vegg
		draw_rect(Rect2(x, WALL_TOP, w, FLOOR_TOP - WALL_TOP), s.wall)
		# Gulv
		draw_rect(Rect2(x, FLOOR_TOP, w, WALL_BOT - FLOOR_TOP), s.floor)
		# Gulvlist
		draw_rect(Rect2(x, FLOOR_TOP - 7, w, 7), s.trim)
		# Taklist
		draw_rect(Rect2(x, WALL_TOP, w, 5), s.trim.lightened(0.15))

		# Etikett-bakgrunn
		draw_rect(Rect2(x, WALL_TOP, w, 22), Color(0, 0, 0, 0.38))
		draw_string(font, Vector2(x + 7, WALL_TOP + 16),
			s.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.90))

		# Skillevegg mellom rom
		if i < SECTIONS.size() - 1:
			var px : int = x + w
			draw_rect(Rect2(px, WALL_TOP, PILLAR_W, WALL_BOT - WALL_TOP),
				Color(0.09, 0.07, 0.05))
			# Lyspanel-detalj
			draw_rect(Rect2(px + 2, WALL_TOP + 30, PILLAR_W - 4, 100),
				Color(0.14, 0.11, 0.08))
