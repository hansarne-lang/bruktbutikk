extends Node2D
## Skipets maskinrom – proseduralt tegnet sci-fi interiør

const SPEED         := 225.0
const PC_X          := 900.0
const INTERACT_DIST := 130.0

# ── Romtegning ────────────────────────────────────────────────
var _porthole_stars : Array = []
var _time           : float = 0.0

@onready var player          : Sprite2D     = $Player
@onready var interact_prompt               = $UI/InteractPrompt
@onready var terminal                      = $UI/Terminal
@onready var output_label    : Label       = $UI/Terminal/TerminalVBox/ScreenBg/OutputScroll/OutputLabel
@onready var input_field     : LineEdit    = $UI/Terminal/TerminalVBox/ScreenBg/InputRow/InputField
@onready var output_scroll                 = $UI/Terminal/TerminalVBox/ScreenBg/OutputScroll
@onready var breakout_panel                = $UI/BreakoutPanel
@onready var breakout_canvas               = $UI/BreakoutPanel/BreakoutVBox/BreakoutCanvas
@onready var snake_panel                   = $UI/SnakePanel
@onready var snake_canvas                  = $UI/SnakePanel/SnakeVBox/SnakeCanvas
@onready var invaders_panel                = $UI/InvadersPanel
@onready var invaders_canvas               = $UI/InvadersPanel/InvadersVBox/InvadersCanvas
@onready var pong_panel                    = $UI/PongPanel
@onready var pong_canvas                   = $UI/PongPanel/PongVBox/PongCanvas

var terminal_open  : bool = false
var breakout_open  : bool = false
var snake_open     : bool = false
var invaders_open  : bool = false
var pong_open      : bool = false

# ── BASIC-tolker ─────────────────────────────────────────────
var basic_vars     : Dictionary = {}   # variabellagring
var basic_program  : Dictionary = {}   # linjenummer → kode
var basic_output   : PackedStringArray = []

func _ready() -> void:
	# Generer porthole-stjerner
	for i in 40:
		var angle := randf() * TAU
		var dist  := randf() * 54.0
		_porthole_stars.append({
			"x": cos(angle) * dist,
			"y": sin(angle) * dist,
			"r": randf_range(0.5, 1.5),
			"a": randf_range(0.4, 1.0),
		})

	$UI/HUD/BackButton.pressed.connect(func():
		SaveManager.save_game()
		get_tree().change_scene_to_file("res://scenes/base/Base.tscn"))
	$UI/HUD/MapButton.pressed.connect(_on_map)
	$UI/Terminal/TerminalVBox/CloseBar/CloseButton.pressed.connect(_close_terminal)
	$UI/Terminal/TerminalVBox/TitleBar/XButton.pressed.connect(_close_terminal)
	input_field.text_submitted.connect(_on_input_submitted)
	breakout_canvas.game_closed.connect(_close_breakout)
	snake_canvas.game_closed.connect(_close_snake)
	invaders_canvas.game_closed.connect(_close_invaders)
	pong_canvas.game_closed.connect(_close_pong)

	_print_to_terminal("    **** KOMMANDÅRE 64 BASIC V2 ****")
	_print_to_terminal("")
	_print_to_terminal(" 64K RAM SYSTEM  38911 BASIC BYTES FREE")
	_print_to_terminal("")
	_print_to_terminal("SKRIV HELP FOR KOMMANDOLISTE")
	_print_to_terminal("")

# ── Bevegelse og nærhet ───────────────────────────────────────
func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

	if terminal_open or snake_open or invaders_open or pong_open:
		return

	var dir := 0.0
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		dir = -1.0
		player.flip_h = true
	elif Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		dir = 1.0
		player.flip_h = false

	player.position.x = clamp(player.position.x + dir * SPEED * delta, 30, 1250)

	# Nærhet til PC
	var dist: float = abs(player.position.x - PC_X)
	if dist < INTERACT_DIST:
		interact_prompt.visible = true
		player.flip_h = player.position.x > PC_X
	else:
		interact_prompt.visible = false

# ── Tastaturhendelser ────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not event is InputEventKey: return
	var key := event as InputEventKey
	if not key.pressed or key.echo: return
	if breakout_open or snake_open or invaders_open or pong_open:
		return   # Spill-canvas håndterer input selv
	if terminal_open:
		if key.keycode == KEY_ESCAPE:
			_close_terminal()
	else:
		if key.keycode == KEY_E:
			var dist: float = abs(player.position.x - PC_X)
			if dist < INTERACT_DIST:
				_open_terminal()
				get_viewport().set_input_as_handled()

# ── Terminal åpne/lukke ───────────────────────────────────────
func _open_terminal() -> void:
	terminal_open    = true
	terminal.visible = true
	interact_prompt.visible = false
	input_field.text = ""
	input_field.grab_focus()
	# Vent én frame så E-tasten ikke skrives inn i feltet
	await get_tree().process_frame
	input_field.clear()

func _close_terminal() -> void:
	terminal_open    = false
	terminal.visible = false

func _on_map() -> void:
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://scenes/map/Map.tscn")

func _open_breakout() -> void:
	terminal_open          = false
	terminal.visible       = false
	breakout_open          = true
	breakout_panel.visible = true
	breakout_canvas.restart()

func _close_breakout() -> void:
	breakout_open          = false
	breakout_panel.visible = false
	terminal_open          = true
	terminal.visible       = true
	input_field.grab_focus()
	_print_to_terminal("BREAKOUT AVSLUTTET  SCORE: %d" % breakout_canvas.score)
	_print_to_terminal("")
	_print_to_terminal("READY.")

func _open_snake() -> void:
	terminal_open       = false
	terminal.visible    = false
	snake_open          = true
	snake_panel.visible = true
	snake_canvas.restart()

func _close_snake() -> void:
	snake_open          = false
	snake_panel.visible = false
	terminal_open       = true
	terminal.visible    = true
	input_field.grab_focus()
	_print_to_terminal("SNAKE AVSLUTTET  SCORE: %d" % snake_canvas.score)
	_print_to_terminal("")
	_print_to_terminal("READY.")

func _open_invaders() -> void:
	terminal_open          = false
	terminal.visible       = false
	invaders_open          = true
	invaders_panel.visible = true
	invaders_canvas.restart()

func _close_invaders() -> void:
	invaders_open          = false
	invaders_panel.visible = false
	terminal_open          = true
	terminal.visible       = true
	input_field.grab_focus()
	_print_to_terminal("SPACE INVADERS AVSLUTTET  SCORE: %d" % invaders_canvas.score)
	_print_to_terminal("")
	_print_to_terminal("READY.")

func _open_pong() -> void:
	terminal_open       = false
	terminal.visible    = false
	pong_open           = true
	pong_panel.visible  = true
	pong_canvas.restart()

func _close_pong() -> void:
	pong_open           = false
	pong_panel.visible  = false
	terminal_open       = true
	terminal.visible    = true
	input_field.grab_focus()
	_print_to_terminal("PONG AVSLUTTET")
	_print_to_terminal("")
	_print_to_terminal("READY.")

# ── Input-behandling ─────────────────────────────────────────
func _on_input_submitted(text: String) -> void:
	var cmd := text.strip_edges().to_upper()
	_print_to_terminal("] " + text)
	input_field.text = ""
	input_field.grab_focus()

	if cmd == "":
		return

	# Linjenummer-program (f.eks. "10 PRINT "HALLO"")
	var num_match := RegEx.new()
	num_match.compile(r"^(\d+)\s+(.*)")
	var m := num_match.search(cmd)
	if m:
		var lineno := int(m.get_string(1))
		var code   := m.get_string(2)
		basic_program[lineno] = code
		return

	_run_immediate(cmd)

func _run_immediate(cmd: String) -> void:
	match cmd:
		"HELP":
			_print_to_terminal("KOMMANDOER:")
			_print_to_terminal("  PRINT \"tekst\"      – skriv ut tekst")
			_print_to_terminal("  PRINT uttrykk      – skriv ut tall/regnestykke")
			_print_to_terminal("  LET X = verdi      – lagre variabel")
			_print_to_terminal("  LIST               – vis programmet")
			_print_to_terminal("  RUN                – kjør programmet")
			_print_to_terminal("  NEW                – slett programmet")
			_print_to_terminal("  CLS                – tøm skjermen")
			_print_to_terminal("  10 PRINT \"...\"    – lagre programlinje")
			_print_to_terminal("  LOAD \"BREAKOUT\"   – start Breakout-spillet")
			_print_to_terminal("  LOAD \"BREAKOUT\",8 – (alternativ syntaks)")
			_print_to_terminal("  LOAD \"SNAKE\"      – start Snake-spillet")
			_print_to_terminal("  LOAD \"INVADERS\"   – start Space Invaders")
			_print_to_terminal("  LOAD \"PONG\"       – start Pong (1 eller 2 spillere)")
		"CLS":
			basic_output.clear()
			output_label.text = ""
		"LIST":
			if basic_program.is_empty():
				_print_to_terminal("TOMT PROGRAM")
			else:
				var lines := basic_program.keys()
				lines.sort()
				for ln in lines:
					_print_to_terminal("%d %s" % [ln, basic_program[ln]])
		"NEW":
			basic_program.clear()
			basic_vars.clear()
			_print_to_terminal("OK")
		"RUN":
			_run_program()
		_:
			# LOAD "BREAKOUT" eller LOAD "SNAKE"
			if cmd.begins_with("LOAD") and ("BREAKOUT" in cmd):
				_print_to_terminal("SEARCHING FOR BREAKOUT...")
				_print_to_terminal("LOADING FROM DRIVE 8...")
				_print_to_terminal("READY.")
				_print_to_terminal("")
				await get_tree().create_timer(0.8).timeout
				_open_breakout()
			elif cmd.begins_with("LOAD") and ("SNAKE" in cmd):
				_print_to_terminal("SEARCHING FOR SNAKE...")
				_print_to_terminal("LOADING FROM DRIVE 8...")
				_print_to_terminal("READY.")
				_print_to_terminal("")
				await get_tree().create_timer(0.8).timeout
				_open_snake()
			elif cmd.begins_with("LOAD") and ("INVADERS" in cmd):
				_print_to_terminal("SEARCHING FOR INVADERS...")
				_print_to_terminal("LOADING FROM DRIVE 8...")
				_print_to_terminal("READY.")
				_print_to_terminal("")
				await get_tree().create_timer(0.8).timeout
				_open_invaders()
			elif cmd.begins_with("LOAD") and ("PONG" in cmd):
				_print_to_terminal("SEARCHING FOR PONG...")
				_print_to_terminal("LOADING FROM DRIVE 8...")
				_print_to_terminal("READY.")
				_print_to_terminal("")
				await get_tree().create_timer(0.8).timeout
				_open_pong()
			else:
				_eval_statement(cmd)

func _run_program() -> void:
	var lines := basic_program.keys()
	lines.sort()
	var i := 0
	var safety := 0
	while i < lines.size() and safety < 500:
		safety += 1
		var ln   : int    = lines[i]
		var code : String = basic_program[ln]

		# FOR–NEXT (enkel enkeltlinje-variant)
		if code.begins_with("FOR "):
			var for_re := RegEx.new()
			for_re.compile(r"FOR\s+(\w+)\s*=\s*(\d+)\s+TO\s+(\d+)")
			var fm := for_re.search(code)
			if fm:
				var vname := fm.get_string(1)
				var start := int(fm.get_string(2))
				var stop  := int(fm.get_string(3))
				# Finn NEXT og body-linjer
				var next_idx := -1
				for j in range(i+1, lines.size()):
					if basic_program[lines[j]].begins_with("NEXT"):
						next_idx = j; break
				if next_idx >= 0:
					for v in range(start, stop+1):
						basic_vars[vname] = v
						for j in range(i+1, next_idx):
							_eval_statement(basic_program[lines[j]])
					i = next_idx + 1
					continue
		_eval_statement(code)
		i += 1
	_print_to_terminal("")
	_print_to_terminal("READY.")

func _eval_statement(stmt: String) -> void:
	if stmt.begins_with("PRINT "):
		var arg := stmt.substr(6).strip_edges()
		# Streng
		if arg.begins_with("\""):
			_print_to_terminal(arg.trim_prefix("\"").trim_suffix("\""))
		elif arg in basic_vars:
			_print_to_terminal(str(basic_vars[arg]))
		else:
			# Prøv regnestykke med variabler
			var expr_str := arg
			for k in basic_vars:
				expr_str = expr_str.replace(k, str(basic_vars[k]))
			var result := _eval_expr(expr_str)
			_print_to_terminal(str(result))
	elif stmt.begins_with("LET "):
		var let_re := RegEx.new()
		let_re.compile(r"LET\s+(\w+)\s*=\s*(.+)")
		var lm := let_re.search(stmt)
		if lm:
			var vname  := lm.get_string(1)
			var valstr := lm.get_string(2).strip_edges()
			for k in basic_vars:
				valstr = valstr.replace(k, str(basic_vars[k]))
			basic_vars[vname] = _eval_expr(valstr)
	elif stmt.begins_with("REM"):
		pass  # Kommentar
	else:
		_print_to_terminal("?SYNTAX ERROR")

func _eval_expr(expr: String) -> float:
	# Enkel regneuttrykk-evaluering
	var e := Expression.new()
	var err := e.parse(expr)
	if err == OK:
		var result = e.execute()
		if not e.has_execute_failed():
			return float(result)
	return 0.0

func _print_to_terminal(line: String) -> void:
	basic_output.append(line)
	output_label.text = "\n".join(basic_output)
	# Scroll til bunn
	await get_tree().process_frame
	output_scroll.scroll_vertical = output_scroll.get_v_scroll_bar().max_value

# ── Prosedural romtegning ─────────────────────────────────────
func _draw() -> void:
	var C_BG     := Color(0.07, 0.09, 0.13)
	var C_WALL   := Color(0.11, 0.13, 0.18)
	var C_PANEL  := Color(0.13, 0.16, 0.22)
	var C_SEAM   := Color(0.06, 0.07, 0.10)
	var C_FLOOR  := Color(0.09, 0.11, 0.15)
	var C_GRID   := Color(0.14, 0.17, 0.22)
	var C_ACCENT := Color(0.25, 0.45, 0.80)

	# ── Bakgrunn ─────────────────────────────────────────────
	draw_rect(Rect2(0, 0, 1280, 720), C_BG)

	# ── Veggpaneler ──────────────────────────────────────────
	draw_rect(Rect2(0, 60, 1280, 440), C_WALL)
	for i in 9:
		var px : float = i * 142.0
		draw_rect(Rect2(px + 4, 70, 134, 420), C_PANEL)
		draw_rect(Rect2(px, 60, 4, 440), C_SEAM)
	# Horisontale søm-linjer
	draw_rect(Rect2(0, 130, 1280, 3), C_SEAM)
	draw_rect(Rect2(0, 350, 1280, 3), C_SEAM)

	# ── Tak ──────────────────────────────────────────────────
	draw_rect(Rect2(0, 0, 1280, 62), Color(0.05, 0.06, 0.09))
	# Rørledning øverst
	draw_rect(Rect2(0, 28, 1280, 20), Color(0.14, 0.18, 0.26))
	draw_rect(Rect2(0, 32, 1280, 5),  Color(0.20, 0.28, 0.42))
	draw_rect(Rect2(0, 46, 1280, 3),  Color(0.08, 0.10, 0.15))
	# Støttebraketter på røret
	for i in 7:
		var bx : float = 100.0 + i * 180.0
		draw_rect(Rect2(bx, 24, 14, 28), Color(0.18, 0.22, 0.32))
		draw_rect(Rect2(bx + 4, 18, 6, 10), Color(0.22, 0.28, 0.40))
	# Lysribber i taket
	for i in 6:
		var lx : float = 60.0 + i * 200.0
		draw_rect(Rect2(lx, 56, 110, 6), Color(0.6, 0.75, 1.0, 0.12))
		draw_rect(Rect2(lx + 8, 58, 94, 3), Color(0.7, 0.88, 1.0, 0.55))
		# Lys-spredning nedover veggen
		draw_colored_polygon(PackedVector2Array([
			Vector2(lx,       62),
			Vector2(lx + 110, 62),
			Vector2(lx + 150, 130),
			Vector2(lx - 40,  130),
		]), Color(0.5, 0.7, 1.0, 0.04))

	# ── Porthole-vindu (venstre) ──────────────────────────────
	var pw := Vector2(105, 230)
	draw_circle(pw, 72, Color(0.01, 0.03, 0.09))
	for s in _porthole_stars:
		var star_pos : Vector2 = pw + Vector2(s["x"], s["y"])
		draw_circle(star_pos, s["r"], Color(1, 1, 1, s["a"]))
	# Planet i porthole
	draw_circle(pw + Vector2(22, -18), 26, Color(0.30, 0.22, 0.42))
	draw_circle(pw + Vector2(22, -18), 26, Color(0.42, 0.30, 0.55, 0.5), false, 2.0)
	draw_circle(pw + Vector2(22, -18), 26, Color(0.20, 0.14, 0.32, 0.3), false, 5.0)
	# Vindusramme
	draw_circle(pw, 74, Color(0.22, 0.28, 0.40), false, 7.0)
	draw_circle(pw, 68, Color(0.16, 0.20, 0.30), false, 3.0)
	# Kryss-hår
	draw_line(pw + Vector2(-70, 0), pw + Vector2(70, 0), Color(0.18, 0.24, 0.36), 1.5)
	draw_line(pw + Vector2(0, -70), pw + Vector2(0, 70), Color(0.18, 0.24, 0.36), 1.5)
	# Gjenspeilning øverst
	draw_colored_polygon(PackedVector2Array([
		pw + Vector2(-48, -60),
		pw + Vector2(20,  -68),
		pw + Vector2(28,  -50),
		pw + Vector2(-42, -40),
	]), Color(1.0, 1.0, 1.0, 0.06))

	# ── Kontrollamper (høyre vegg) ────────────────────────────
	draw_rect(Rect2(1100, 145, 165, 190), Color(0.09, 0.11, 0.16))
	draw_rect(Rect2(1100, 145, 165, 6),   Color(C_ACCENT.r, C_ACCENT.g, C_ACCENT.b, 0.7))
	draw_rect(Rect2(1100, 329, 165, 6),   C_SEAM)
	# Mini-skjerm
	draw_rect(Rect2(1112, 158, 90, 58), Color(0.03, 0.10, 0.18))
	draw_rect(Rect2(1116, 162, 82, 50), Color(0.0,  0.22, 0.38, 0.4))
	# Enkel "grafikk" på skjermen (scan-linjer)
	for sl in 5:
		var sy : float = 166 + sl * 9.0
		var w2 : float = 40.0 + sin(_time * 1.2 + sl * 0.8) * 28.0
		draw_rect(Rect2(1120, sy, w2, 3), Color(0.2, 0.7, 1.0, 0.5))
	# Lamper
	var blink : bool = (int(_time * 1.5)) % 2 == 0
	var lamps : Array = [
		[1116, 228, Color(0.2, 1.0, 0.4)],
		[1136, 228, Color(1.0, 0.85, 0.2)],
		[1156, 228, Color(0.3, 0.6, 1.0)],
		[1176, 228, Color(1.0, 0.3, 0.3) if blink else Color(0.3, 0.08, 0.08)],
		[1196, 228, Color(1.0, 0.85, 0.2) if not blink else Color(0.28, 0.20, 0.05)],
	]
	for lamp in lamps:
		draw_circle(Vector2(lamp[0], lamp[1]), 6, lamp[2])
		draw_circle(Vector2(lamp[0], lamp[1]), 9, Color(lamp[2].r, lamp[2].g, lamp[2].b, 0.2))
	# Knapperader
	for row in 3:
		for col in 5:
			draw_rect(Rect2(1112 + col * 26, 252 + row * 18, 18, 11),
				Color(0.20, 0.25, 0.35))
			draw_rect(Rect2(1114 + col * 26, 254 + row * 18, 14, 7),
				Color(0.28, 0.34, 0.46))

	# ── Veggrør (horisontalt, midt-høyde) ────────────────────
	draw_rect(Rect2(200, 348, 750, 10), Color(0.16, 0.20, 0.28))
	draw_rect(Rect2(200, 350, 750, 4),  Color(0.22, 0.30, 0.44))
	for i in 6:
		var cx : float = 240.0 + i * 130.0
		draw_rect(Rect2(cx, 344, 12, 18), Color(0.20, 0.26, 0.36))

	# ── Gulv ──────────────────────────────────────────────────
	draw_rect(Rect2(0, 490, 1280, 230), C_FLOOR)
	# Grid-linjer
	for gx in range(0, 1281, 80):
		draw_line(Vector2(gx, 490), Vector2(gx, 620),
			Color(C_GRID.r, C_GRID.g, C_GRID.b, 0.8), 1.0)
	for gy in range(490, 621, 40):
		draw_line(Vector2(0, gy), Vector2(1280, gy),
			Color(C_GRID.r, C_GRID.g, C_GRID.b, 0.8), 1.0)
	# Gulvkant-glow (blå stripe)
	draw_rect(Rect2(0, 487, 1280, 5), Color(C_ACCENT.r, C_ACCENT.g, C_ACCENT.b, 0.45))
	draw_rect(Rect2(0, 490, 1280, 3), Color(C_ACCENT.r, C_ACCENT.g, C_ACCENT.b, 0.25))
	# Nødlys langs gulv (røde punkter)
	for nx in range(80, 1280, 160):
		var glow : float = (sin(_time * 2.0 + nx * 0.01) + 1.0) * 0.5
		draw_circle(Vector2(nx, 494), 5.0, Color(1.0, 0.2, 0.2, 0.5 + glow * 0.3))
