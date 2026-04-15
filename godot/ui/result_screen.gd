## Result screen — win/loss, Bolts earned, repair cost
class_name ResultScreen
extends Control

signal continue_pressed
signal rematch_pressed

var won: bool = false
var bolts_earned: int = 0
var game_state: GameState

func setup(state: GameState, match_won: bool, earned: int) -> void:
	game_state = state
	won = match_won
	bolts_earned = earned
	_build_ui()

func _build_ui() -> void:
	for c in get_children():
		c.queue_free()
	
	# Result banner
	var banner := Label.new()
	banner.text = "🏆 VICTORY!" if won else "💀 DEFEAT"
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 48)
	if won:
		banner.add_theme_color_override("font_color", Color.GOLD)
	else:
		banner.add_theme_color_override("font_color", Color.RED)
	banner.position = Vector2(340, 100)
	banner.size = Vector2(600, 80)
	add_child(banner)
	
	# Bolts info
	var repair := 20 if won else 50
	var gross := bolts_earned + repair
	
	var info := Label.new()
	info.text = "Bolts earned: %d 🔩\nRepair cost: -%d 🔩\nNet: %d 🔩\n\nTotal Bolts: %d 🔩" % [
		gross, repair, bolts_earned, game_state.bolts
	]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 20)
	info.position = Vector2(440, 220)
	info.size = Vector2(400, 200)
	add_child(info)
	
	# Bronze unlock message
	if game_state.bronze_unlocked and game_state.brottbrain_unlocked:
		var unlock := Label.new()
		unlock.text = "🧠 BrottBrain Editor UNLOCKED!\nNew items available in the shop!"
		unlock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		unlock.add_theme_font_size_override("font_size", 18)
		unlock.add_theme_color_override("font_color", Color.CYAN)
		unlock.position = Vector2(390, 420)
		unlock.size = Vector2(500, 60)
		add_child(unlock)
	
	# Buttons
	var rematch_btn := Button.new()
	rematch_btn.text = "🔄 Rematch"
	rematch_btn.position = Vector2(440, 530)
	rematch_btn.size = Vector2(180, 50)
	rematch_btn.add_theme_font_size_override("font_size", 18)
	rematch_btn.pressed.connect(func(): rematch_pressed.emit())
	add_child(rematch_btn)
	
	var cont_btn := Button.new()
	cont_btn.text = "Continue →"
	cont_btn.position = Vector2(660, 530)
	cont_btn.size = Vector2(180, 50)
	cont_btn.add_theme_font_size_override("font_size", 18)
	cont_btn.pressed.connect(func(): continue_pressed.emit())
	add_child(cont_btn)
