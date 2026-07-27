extends Node2D
## Tegner møbler som vektorgrafikk basert på item_id.

var item_id   : String  = ""
var item_size : Vector2 = Vector2(80, 60)
var tint      : Color   = Color.GRAY

# Faste bokhøyder for deterministisk tegning
const BOOK_HEIGHTS := [0.55, 0.43, 0.62, 0.40, 0.53, 0.58]
const BOOK_COLORS  := [
	Color(0.72, 0.20, 0.20), Color(0.20, 0.50, 0.72),
	Color(0.72, 0.66, 0.12), Color(0.18, 0.62, 0.30),
	Color(0.62, 0.18, 0.72), Color(0.82, 0.40, 0.10),
]

func setup(id: String, sz: Vector2) -> void:
	item_id   = id
	item_size = sz
	tint      = _item_tint(id)
	queue_redraw()

static func _item_tint(id: String) -> Color:
	match id:
		"sofa_01":       return Color(0.46, 0.23, 0.11)
		"chair_01":      return Color(0.39, 0.21, 0.09)
		"table_01":      return Color(0.56, 0.38, 0.17)
		"wardrobe_01":   return Color(0.36, 0.24, 0.11)
		"lamp_01":       return Color(0.63, 0.58, 0.22)
		"book_lot":      return Color(0.35, 0.31, 0.44)
		"breakout_cart": return Color(0.14, 0.09, 0.34)
		"c64_computer":  return Color(0.55, 0.55, 0.44)
		"c64_datasette": return Color(0.50, 0.50, 0.42)
		"c64_joystick":  return Color(0.18, 0.18, 0.18)
		"c64_box":       return Color(0.62, 0.55, 0.37)
		_:               return Color(0.45, 0.40, 0.34)

func _draw() -> void:
	var w := item_size.x
	var h := item_size.y
	match item_id:
		"sofa_01":        _sofa(w, h)
		"chair_01":       _chair(w, h)
		"table_01":       _table(w, h)
		"lamp_01":        _lamp(w, h)
		"wardrobe_01":    _wardrobe(w, h)
		"book_lot":       _books(w, h)
		"breakout_cart":  _cassette(w, h)
		"c64_computer":   _computer(w, h)
		"c64_datasette":  _datasette(w, h)
		"c64_joystick":   _joystick(w, h)
		"c64_box":        _box(w, h)
		_:                draw_rect(Rect2(0, 0, w, h), tint)

# ── Møbeltegninger ────────────────────────────────────────────

func _sofa(w: float, h: float) -> void:
	# Sete
	draw_rect(Rect2(0, h * 0.42, w, h * 0.58), tint)
	# Rygg
	draw_rect(Rect2(0, 0, w, h * 0.46), tint.darkened(0.22))
	# Armlen venstre og høyre
	draw_rect(Rect2(0, 0, w * 0.10, h), tint.darkened(0.16))
	draw_rect(Rect2(w * 0.90, 0, w * 0.10, h), tint.darkened(0.16))
	# Sittemadrasseenheter (tre puter)
	for i in 3:
		draw_rect(Rect2(w * 0.112 + i * (w * 0.259), h * 0.46, w * 0.235, h * 0.34),
			tint.lightened(0.16))
	# Ben
	for bx in [w * 0.05, w * 0.86]:
		draw_rect(Rect2(bx, h * 0.88, w * 0.07, h * 0.12), tint.darkened(0.42))

func _chair(w: float, h: float) -> void:
	# Rygg
	draw_rect(Rect2(w * 0.06, 0, w * 0.88, h * 0.50), tint.darkened(0.22))
	# Sete
	draw_rect(Rect2(w * 0.06, h * 0.47, w * 0.88, h * 0.28), tint)
	# Ben (to foran)
	draw_rect(Rect2(w * 0.10, h * 0.74, w * 0.13, h * 0.26), tint.darkened(0.36))
	draw_rect(Rect2(w * 0.77, h * 0.74, w * 0.13, h * 0.26), tint.darkened(0.36))

func _table(w: float, h: float) -> void:
	# Bordplate med kant
	draw_rect(Rect2(0, 0, w, h * 0.20), tint.lightened(0.12))
	draw_rect(Rect2(0, h * 0.16, w, h * 0.06), tint.darkened(0.10))
	# Ben (fire stk)
	var lw := w * 0.07
	for bx in [w * 0.05, w * 0.88]:
		draw_rect(Rect2(bx, h * 0.22, lw, h * 0.78), tint.darkened(0.30))
	# Underligger
	draw_rect(Rect2(w * 0.12, h * 0.56, w * 0.76, h * 0.09), tint.darkened(0.18))

func _lamp(w: float, h: float) -> void:
	# Fot
	draw_rect(Rect2(w * 0.32, h * 0.86, w * 0.36, h * 0.14), tint.darkened(0.25))
	# Stang
	draw_rect(Rect2(w * 0.44, h * 0.32, w * 0.12, h * 0.55), tint.darkened(0.32))
	# Skjerm (trapesform)
	draw_colored_polygon(PackedVector2Array([
		Vector2(w * 0.08, h * 0.34), Vector2(w * 0.92, h * 0.34),
		Vector2(w * 0.76, 0.0),       Vector2(w * 0.24, 0.0),
	]), Color(0.86, 0.80, 0.50))
	# Lysgløgg
	draw_circle(Vector2(w * 0.50, h * 0.17), w * 0.13, Color(1.0, 0.97, 0.80, 0.55))

func _wardrobe(w: float, h: float) -> void:
	# Korpus
	draw_rect(Rect2(0, 0, w, h), tint)
	# Dørskille
	draw_line(Vector2(w * 0.50, h * 0.04), Vector2(w * 0.50, h * 0.95),
		tint.darkened(0.40), 2.0)
	# Lister
	draw_rect(Rect2(0, 0, w, h * 0.04), tint.darkened(0.26))
	draw_rect(Rect2(0, h * 0.94, w, h * 0.06), tint.darkened(0.26))
	draw_rect(Rect2(0, 0, h * 0.025, h), tint.darkened(0.20))
	draw_rect(Rect2(w - h * 0.025, 0, h * 0.025, h), tint.darkened(0.20))
	# Håndtak
	for hx in [w * 0.30, w * 0.66]:
		draw_circle(Vector2(hx, h * 0.50), w * 0.055, Color(0.72, 0.62, 0.40))
		draw_circle(Vector2(hx, h * 0.50), w * 0.025, Color(0.50, 0.44, 0.28))

func _books(w: float, h: float) -> void:
	# Kasse
	draw_rect(Rect2(0, h * 0.34, w, h * 0.66), tint.darkened(0.16))
	# Bokrygger
	var n  := BOOK_COLORS.size()
	var bw := w / n
	for i in n:
		var bh : float = h * BOOK_HEIGHTS[i]
		draw_rect(Rect2(i * bw + 2.0, h * 0.34 - bh, bw - 3.0, bh), BOOK_COLORS[i])
		# Tittellinje
		draw_rect(Rect2(i * bw + 3.0, h * 0.34 - bh + 5.0, bw - 5.0, 3.0),
			BOOK_COLORS[i].lightened(0.35))

func _cassette(w: float, h: float) -> void:
	# Kassettdeksel
	draw_rect(Rect2(0, 0, w, h), tint)
	draw_rect(Rect2(w * 0.03, h * 0.03, w * 0.94, h * 0.94), tint.lightened(0.08))
	# Kassettvindu
	draw_rect(Rect2(w * 0.18, h * 0.18, w * 0.64, h * 0.46), Color(0.12, 0.12, 0.12))
	# Spoler
	draw_circle(Vector2(w * 0.33, h * 0.41), w * 0.13, Color(0.28, 0.28, 0.28))
	draw_circle(Vector2(w * 0.67, h * 0.41), w * 0.13, Color(0.28, 0.28, 0.28))
	draw_circle(Vector2(w * 0.33, h * 0.41), w * 0.055, Color(0.08, 0.08, 0.08))
	draw_circle(Vector2(w * 0.67, h * 0.41), w * 0.055, Color(0.08, 0.08, 0.08))
	# Label
	draw_rect(Rect2(w * 0.10, h * 0.66, w * 0.80, h * 0.22), Color(0.86, 0.82, 0.70))
	draw_string(ThemeDB.fallback_font, Vector2(w * 0.14, h * 0.84),
		"BREAKOUT", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.2, 0.2, 0.6))

func _computer(w: float, h: float) -> void:
	# Hoveddel (tastatur + kropp)
	draw_rect(Rect2(0, 0, w, h), Color(0.56, 0.56, 0.46))
	# Skjerm (øverst til venstre)
	draw_rect(Rect2(w * 0.02, h * 0.05, w * 0.56, h * 0.65), Color(0.20, 0.20, 0.40))
	draw_rect(Rect2(w * 0.05, h * 0.10, w * 0.50, h * 0.54), Color(0.10, 0.12, 0.30))
	# Skjerm-gløgg
	draw_rect(Rect2(w * 0.07, h * 0.13, w * 0.20, h * 0.10), Color(0.35, 0.40, 0.80, 0.4))
	# Tastatur (høyre del)
	for row in 3:
		for col in 5:
			draw_rect(Rect2(
				w * 0.62 + col * w * 0.072, h * 0.30 + row * h * 0.17,
				w * 0.056, h * 0.13
			), Color(0.46, 0.46, 0.38))
	# Commodore-logo-farge (regnbuestripe)
	var rainbow := [Color(0.9,0,0), Color(1,0.6,0), Color(1,1,0),
		Color(0,0.8,0), Color(0,0.5,1), Color(0.6,0,1)]
	for ri in rainbow.size():
		draw_rect(Rect2(w * 0.62, h * 0.06 + ri * h * 0.04, w * 0.08, h * 0.036),
			rainbow[ri])

func _datasette(w: float, h: float) -> void:
	draw_rect(Rect2(0, 0, w, h), Color(0.52, 0.52, 0.44))
	# Kassettvindu
	draw_rect(Rect2(w * 0.08, h * 0.14, w * 0.58, h * 0.50), Color(0.16, 0.16, 0.16))
	# Spoler
	draw_circle(Vector2(w * 0.24, h * 0.39), w * 0.12, Color(0.28, 0.28, 0.28))
	draw_circle(Vector2(w * 0.52, h * 0.39), w * 0.12, Color(0.28, 0.28, 0.28))
	draw_circle(Vector2(w * 0.24, h * 0.39), w * 0.05, Color(0.10, 0.10, 0.10))
	draw_circle(Vector2(w * 0.52, h * 0.39), w * 0.05, Color(0.10, 0.10, 0.10))
	# Knapper
	for i in 5:
		draw_rect(Rect2(w * 0.70 + i * w * 0.005, h * 0.60, w * 0.042, h * 0.22),
			Color(0.30, 0.30, 0.28))

func _joystick(w: float, h: float) -> void:
	# Base
	draw_rect(Rect2(w * 0.08, h * 0.52, w * 0.84, h * 0.48), Color(0.15, 0.15, 0.15))
	# Stikke
	draw_rect(Rect2(w * 0.42, h * 0.12, w * 0.16, h * 0.44), Color(0.22, 0.22, 0.22))
	# Kuletop
	draw_circle(Vector2(w * 0.50, h * 0.14), w * 0.16, Color(0.18, 0.18, 0.18))
	draw_circle(Vector2(w * 0.44, h * 0.10), w * 0.07, Color(0.28, 0.28, 0.28))
	# Brannknapp (rød)
	draw_circle(Vector2(w * 0.76, h * 0.68), w * 0.13, Color(0.75, 0.10, 0.10))
	draw_circle(Vector2(w * 0.76, h * 0.68), w * 0.06, Color(0.95, 0.30, 0.30))

func _box(w: float, h: float) -> void:
	# Boks
	draw_rect(Rect2(0, h * 0.14, w, h * 0.86), Color(0.62, 0.56, 0.38))
	# Lokk
	draw_rect(Rect2(0, 0, w, h * 0.19), Color(0.52, 0.46, 0.28))
	# Trykk/bilde på siden
	draw_rect(Rect2(w * 0.12, h * 0.26, w * 0.76, h * 0.52), Color(0.46, 0.38, 0.24))
	draw_string(ThemeDB.fallback_font, Vector2(w * 0.16, h * 0.58),
		"C64", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.88, 0.55))
