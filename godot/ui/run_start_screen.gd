## Run Start screen — chassis selection for the roguelike run loop
## S25.1: Player picks one of 3 shuffled chassis to begin a new run.
## Arc N: Chassis select replaced with single Brawler starter; select restored in Arc O.
class_name RunStartScreen
extends Control

signal start_run_requested(chassis_type: int)

var _rng: RandomNumberGenerator
var _chassis_order: Array[int] = []

func setup(rng_seed: int = 0) -> void:
	# CUT:ArcN — chassis select restored for Arc O
	# _rng = RandomNumberGenerator.new()
	# if rng_seed == 0:
	# 	_rng.randomize()
	# else:
	# 	_rng.seed = rng_seed
	# # Shuffle-and-show-all-3: pool is exactly [Scout=0, Brawler=1, Fortress=2]
	# _chassis_order = [0, 1, 2]
	# # Fisher-Yates shuffle using seeded rng
	# for i in range(_chassis_order.size() - 1, 0, -1):
	# 	var j := _rng.randi_range(0, i)
	# 	var tmp := _chassis_order[i]
	# 	_chassis_order[i] = _chassis_order[j]
	# 	_chassis_order[j] = tmp
	# /CUT:ArcN
	_build_ui()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# CUT:ArcN — chassis select UI restored for Arc O
	# var title_old := Label.new()
	# title_old.text = "⚡ CHOOSE YOUR BROTT"
	# title_old.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# title_old.add_theme_font_size_override("font_size", 36)
	# title_old.position = Vector2(290, 100)
	# title_old.size = Vector2(700, 60)
	# add_child(title_old)

	# var subtitle_old := Label.new()
	# subtitle_old.text = "Pick a chassis to begin your run. Weapons and armor earned through battle."
	# subtitle_old.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# subtitle_old.add_theme_font_size_override("font_size", 16)
	# subtitle_old.position = Vector2(290, 170)
	# subtitle_old.size = Vector2(700, 30)
	# add_child(subtitle_old)

	# # Three chassis cards side by side
	# var card_names := ["Scout", "Brawler", "Fortress"]
	# var card_descs := [
	# 	"Fast and light.\nLow HP. High speed.\nDodge-focused.",
	# 	"Balanced fighter.\nMedium HP. 2 weapon slots.",
	# 	"Heavy tank.\n High HP. Slow.\n3 weapon slots, 3 modules.",
	# ]
	# var card_x_positions := [130.0, 440.0, 750.0]

	# for i in range(3):
	# 	var chassis_type := _chassis_order[i]
	# 	var btn_c := Button.new()
	# 	btn_c.name = "ChassisBtn_%d" % chassis_type
	# 	btn_c.text = "⚙ %s" % card_names[chassis_type]
	# 	btn_c.position = Vector2(card_x_positions[i], 280)
	# 	btn_c.size = Vector2(250, 200)
	# 	btn_c.add_theme_font_size_override("font_size", 20)

	# 	# Description label inside the button area
	# 	var desc_c := Label.new()
	# 	desc_c.text = card_descs[chassis_type]
	# 	desc_c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 	desc_c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# 	desc_c.add_theme_font_size_override("font_size", 13)
	# 	desc_c.position = Vector2(card_x_positions[i], 490)
	# 	desc_c.size = Vector2(250, 80)
	# 	add_child(desc_c)

	# 	var ct := chassis_type  # capture for closure
	# 	# [S26.7 diagnostic] Replace lambda with bind() to sidestep any GDScript
	# 	# closure-capture issues; emit print so we can verify the click lands.
	# 	btn_c.pressed.connect(_on_card_pressed.bind(ct))
	# 	add_child(btn_c)
	# /CUT:ArcN

	## Arc N: fixed Brawler starter — single "Start Run" button.
	## chassis_type=1 (Brawler) always emitted; chassis select restored in Arc O.
	var title := Label.new()
	title.text = "⚡ START YOUR RUN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.position = Vector2(290, 100)
	title.size = Vector2(700, 60)
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "You are a Brawler. Weapons and armor earned through battle."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.position = Vector2(290, 170)
	subtitle.size = Vector2(700, 30)
	add_child(subtitle)

	var btn := Button.new()
	btn.name = "StartRunBtn"
	btn.text = "▶ Start Run"
	btn.position = Vector2(440, 280)
	btn.size = Vector2(400, 100)
	btn.add_theme_font_size_override("font_size", 28)
	btn.pressed.connect(_on_start_run_pressed)
	add_child(btn)

# CUT:ArcN — _on_card_pressed restored for Arc O
# func _on_card_pressed(chassis_type: int) -> void:
# 	print("[S26.7] RunStartScreen: card pressed, ct=", chassis_type)
# 	start_run_requested.emit(chassis_type)

## Arc N: "Start Run" handler — always emits Brawler (chassis_type=1).
func _on_start_run_pressed() -> void:
	print("[ArcN] RunStartScreen: Start Run pressed — emitting Brawler (chassis_type=1)")
	start_run_requested.emit(1)
