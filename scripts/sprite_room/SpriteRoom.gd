extends Node2D
## Sprite-rom med bevegelig karakter og BASIC-terminal på gammel PC

const SPEED        := 225.0
const PC_X         := 900.0    # X-posisjon til datamaskinen
const INTERACT_DIST:= 130.0    # Avstand for å trigge interaksjon

@onready var player          : Sprite2D     = $Player
@onready var interact_prompt               = $UI/InteractPrompt
@onready var terminal                      = $UI/Terminal
@onready var output_label    : Label       = $UI/Terminal/TerminalVBox/ScreenBg/OutputScroll/OutputLabel
@onready var input_field     : LineEdit    = $UI/Terminal/TerminalVBox/ScreenBg/InputRow/InputField
@onready var output_scroll                 = $UI/Terminal/TerminalVBox/ScreenBg/OutputScroll
@onready var breakout_panel                = $UI/BreakoutPanel
@onready var breakout_canvas               = $UI/BreakoutPanel/BreakoutVBox/BreakoutCanvas

var terminal_open  : bool = false
var breakout_open  : bool = false

# ── BASIC-tolker ─────────────────────────────────────────────
var basic_vars     : Dictionary = {}   # variabellagring
var basic_program  : Dictionary = {}   # linjenummer → kode
var basic_output   : PackedStringArray = []

func _ready() -> void:
	$UI/HUD/BackButton.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/shop/Shop.tscn"))
	$UI/Terminal/TerminalVBox/CloseBar/CloseButton.pressed.connect(_close_terminal)
	input_field.text_submitted.connect(_on_input_submitted)
	breakout_canvas.game_closed.connect(_close_breakout)

	_print_to_terminal("    **** COMMODORE 64 BASIC V2 ****")
	_print_to_terminal("")
	_print_to_terminal(" 64K RAM SYSTEM  38911 BASIC BYTES FREE")
	_print_to_terminal("")
	_print_to_terminal("SKRIV HELP FOR KOMMANDOLISTE")
	_print_to_terminal("")

# ── Bevegelse og nærhet ───────────────────────────────────────
func _process(delta: float) -> void:
	if terminal_open:
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
	if breakout_open:
		return   # BreakoutCanvas håndterer input selv
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
			# LOAD "BREAKOUT" eller LOAD "BREAKOUT",8
			if cmd.begins_with("LOAD") and ("BREAKOUT" in cmd):
				_print_to_terminal("SEARCHING FOR BREAKOUT...")
				_print_to_terminal("LOADING FROM DRIVE 8...")
				_print_to_terminal("READY.")
				_print_to_terminal("")
				await get_tree().create_timer(0.8).timeout
				_open_breakout()
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
