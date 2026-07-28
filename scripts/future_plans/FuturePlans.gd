extends Node2D
## Void Miner – Fremtidsplaner
## Inneholder ideer for kommende funksjoner (placeholder-side).

var _time : float = 0.0

const SECTIONS : Array = [
	{
		"title": "👥  Crew-system",
		"ideas": [
			"Ansett besetningsmedlemmer med ulike ferdigheter (pilot, ingeniør, gruvearbeider).",
			"Besetning øker effektiviteten i bestemte oppgaver (f.eks. raskere reparasjon, bedre drill).",
			"Besetningsmedlemmer kan skades eller permitteres. Moral-system.",
			"Maks antall besetning avhenger av skipsklasse.",
		],
	},
	{
		"title": "🔧  Reparasjonsminispill",
		"ideas": [
			"Håndtert reparasjon via et minispill i stedet for automatisk tidsbasert.",
			"Match-the-symbol-mekanikk for å reparere komponenter raskere.",
			"Feilreparasjon kan forverre skaden – risiko vs. belønning.",
			"Spesialverktøy låser opp vanskeligere (men mer effektive) reparasjonsalternativer.",
		],
	},
	{
		"title": "📋  Oppdragssystem",
		"ideas": [
			"Tradere gir tidsbegrensede oppdrag: lever X enheter av Y innen dag Z.",
			"Vellykket oppdrag gir bonus-kreditter og omdømmepunkter.",
			"Mislykkede oppdrag senker rykte og kan stenge deg ute fra tradere.",
			"Sjeldne oppdrag: utforsk en ny sone, beseir en bestemt pirat.",
		],
	},
	{
		"title": "⭐  Ryktesystem",
		"ideas": [
			"Rykte-poeng (0–100) bygges opp ved vellykkede handler og oppdrag.",
			"Høyt rykte: bedre priser, tilgang til eksklusive varer, hjelp fra fremmede skip.",
			"Lavt rykte: piratrater øker, tradere nekter handel.",
			"Rykte degraderes sakte over tid – du må holde deg aktiv.",
		],
	},
	{
		"title": "🏗  Base-ekspansjon",
		"ideas": [
			"Utvid månebassen med ekstra moduler: hangar, kantine, laboratorium.",
			"Laboratoriet kan foredle råmineraler til mer verdifulle produkter.",
			"Hangaren gir raskere lasting/lossing og plass til et sekundærskip.",
			"Moduler koster mye, men gir passive fordeler hvert spill-dag.",
		],
	},
	{
		"title": "💀  Sjef-pirat (Boss)",
		"ideas": [
			"Etter dag 20 dukker den legendariske piratten 'Voidlord Krax' opp.",
			"Mye sterkere enn vanlige pirater – krever taktisk bruk av alle torpedotyper.",
			"Nedseiret Krax gir en massiv belønning og en unik tittel.",
			"Kun én sjanse – taper du, er det permanent game over (høy risiko).",
		],
	},
]

func _ready() -> void:
	$UI/BackButton.pressed.connect(_go_back)
	_build_ui()

func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")

func _build_ui() -> void:
	var scroll_vbox : VBoxContainer = $UI/ScrollArea/ContentVBox
	for section in SECTIONS:
		# Seksjonstittel
		var title_lbl := Label.new()
		title_lbl.text = section["title"]
		title_lbl.add_theme_font_size_override("font_size", 16)
		title_lbl.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
		scroll_vbox.add_child(title_lbl)

		# Ideer
		for idea : String in section["ideas"]:
			var idea_lbl := Label.new()
			idea_lbl.text = "  •  " + idea
			idea_lbl.add_theme_font_size_override("font_size", 12)
			idea_lbl.add_theme_color_override("font_color", Color(0.75, 0.80, 0.85))
			idea_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			idea_lbl.custom_minimum_size = Vector2(900, 0)
			scroll_vbox.add_child(idea_lbl)

		# Skillelinje
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 12)
		scroll_vbox.add_child(spacer)

		var sep := ColorRect.new()
		sep.custom_minimum_size = Vector2(920, 1)
		sep.color = Color(0.2, 0.25, 0.35, 0.5)
		scroll_vbox.add_child(sep)

		var spacer2 := Control.new()
		spacer2.custom_minimum_size = Vector2(0, 12)
		scroll_vbox.add_child(spacer2)

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.03, 0.04, 0.09))
	for i in 80:
		var sf : float = float(i) * 19.71
		var sx : float = fmod(sf * 127.4, 1280.0)
		var sy : float = fmod(sf * 241.8, 720.0)
		draw_circle(Vector2(sx, sy), fmod(sf * 0.013, 1.2) + 0.3, Color(1, 1, 1, 0.22))
