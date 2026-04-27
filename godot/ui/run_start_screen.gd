## Run Start screen — chassis selection for the roguelike run loop
## S25.1: Player picks one of 3 shuffled chassis to begin a new run.
class_name RunStartScreen
extends Control

signal start_run_requested(chassis_type: int)

var _rng: RandomNumberGenerator
var _chassis_order: Array[int] = []

func setup(rng_seed: int = 0) -> void:
	_rng = RandomNumberGenerator.new()
	if rng_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = rng_seed
	# Shuffle-and-show-all-3: pool is exactly [Scout=0, Brawler=1, Fortress=2]
	_chassis_order = [0, 1, 2]
	# Fisher-Yates shuffle using seeded rng
	for i in range(_chassis_order.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := _chassis_order[i]
		_chassis_order[i] = _chassis_order[j]
		_chassis_order[j] = tmp
	_build_ui()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var title := Label.new()
	title.text = "⚡ CHOOSE YOUR BROTT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.position = Vector2(290, 100)
	title.size = Vector2(700, 60)
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Pick a chassis to begin your run. Weapons and armor earned through battle."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.position = Vector2(290, 170)
	subtitle.size = Vector2(700, 30)
	add_child(subtitle)

	# Three chassis cards side by side
	var card_names := ["Scout", "Brawler", "Fortress"]
	var card_descs := [
		"Fast and light.\nLow HP. High speed.\nDodge-focused.",
		"Balanced fighter.\nMedium HP. 2 weapon slots.",
		"Heavy tank.\n High HP. Slow.\n3 weapon slots, 3 modules.",
	]
	var card_x_positions := [130.0, 440.0, 750.0]

	for i in range(3):
		var chassis_type := _chassis_order[i]
		var btn := Button.new()
		btn.name = "ChassisBtn_%d" % chassis_type
		btn.text = "⚙ %s" % card_names[chassis_type]
		btn.position = Vector2(card_x_positions[i], 280)
		btn.size = Vector2(250, 200)
		btn.add_theme_font_size_override("font_size", 20)

		# Description label inside the button area
		var desc := Label.new()
		desc.text = card_descs[chassis_type]
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 13)
		desc.position = Vector2(card_x_positions[i], 490)
		desc.size = Vector2(250, 80)
		add_child(desc)

		var ct := chassis_type  # capture for closure
		# [S26.7 diagnostic] Replace lambda with bind() to sidestep any GDScript
		# closure-capture issues; emit print so we can verify the click lands.
		btn.pressed.connect(_on_card_pressed.bind(ct))
		add_child(btn)

# [S26.7 diagnostic] Real method handler (instead of lambda) so chassis-type
# binding is unambiguous. Also prints so we can confirm the button signal
# fires through to game_main.
func _on_card_pressed(chassis_type: int) -> void:
	print("[S26.7] RunStartScreen: card pressed, ct=", chassis_type)
	start_run_requested.emit(chassis_type)
