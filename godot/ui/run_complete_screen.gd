## run_complete_screen.gd — S25.7: Victory screen after boss is defeated.
class_name RunCompleteScreen
extends Control

signal return_to_menu_pressed

func setup(run_state: RunState) -> void:
	_build_ui(run_state)

func _build_ui(rs: RunState) -> void:
	var title := Label.new()
	title.text = "🏆 RUN COMPLETE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.position = Vector2(290, 80)
	title.size = Vector2(700, 70)
	add_child(title)

	var boss_lbl := Label.new()
	boss_lbl.text = "Boss Defeated: IRONCLAD PRIME"
	boss_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_lbl.add_theme_font_size_override("font_size", 20)
	boss_lbl.position = Vector2(340, 165)
	boss_lbl.size = Vector2(600, 40)
	add_child(boss_lbl)

	var summary := Label.new()
	summary.text = "Battles Won: %d / 15\nRetries Used: %d / 3\nItems Collected: %d" % [
		rs.battles_won,
		max(0, 3 - rs.retry_count),
		rs.equipped_weapons.size() + (1 if rs.equipped_armor > 0 else 0) + rs.equipped_modules.size()
	]
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_font_size_override("font_size", 18)
	summary.position = Vector2(390, 230)
	summary.size = Vector2(500, 120)
	add_child(summary)

	var btn := Button.new()
	btn.text = "↩ Return to Main Menu"
	btn.position = Vector2(465, 390)
	btn.size = Vector2(350, 60)
	btn.add_theme_font_size_override("font_size", 20)
	btn.pressed.connect(func(): return_to_menu_pressed.emit())
	add_child(btn)
