extends Node2D
## UI-kontroller for testscenen

@onready var summary_lbl : Label          = $UI/SummaryLabel
@onready var result_lbl  : Label          = $UI/Scroll/ResultLabel
@onready var runner      : Node           = $TestRunner

func _ready() -> void:
	$UI/BackButton.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn"))
	$UI/RunAgainButton.pressed.connect(_run)
	runner.tests_done.connect(_on_done)
	_run()

func _run() -> void:
	summary_lbl.text             = "Kjører 50 tester..."
	summary_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 1))
	result_lbl.text              = ""
	runner.run_all()

func _on_done(summary: String, results: Array) -> void:
	# BUG-FIX 1: "50 / 50" inneholder "0 /" → bruk "(0 feilet)" i stedet
	# BUG-FIX 2: typed lambda func(s: String) på untyped Array → bruk func(s)
	var all_pass : bool = summary.contains("(0 feilet)") and \
		results.filter(func(s) -> bool: return str(s).begins_with("❌")).is_empty()

	if all_pass:
		summary_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4, 1))
	else:
		summary_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3, 1))
	summary_lbl.text = summary

	result_lbl.text = "\n".join(Array(results).map(func(s) -> String: return str(s)))
