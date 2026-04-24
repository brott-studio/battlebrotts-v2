## Main Menu screen — title and New Game button
class_name MainMenuScreen
extends Control

signal new_game_pressed

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Title
	var title := Label.new()
	title.text = "⚔️ BATTLEBROTTS ⚔️"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.position = Vector2(340, 150)
	title.size = Vector2(600, 80)
	add_child(title)
	
	# Subtitle
	var subtitle := Label.new()
	subtitle.text = "Build. Teach. Fight."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.position = Vector2(440, 240)
	subtitle.size = Vector2(400, 40)
	add_child(subtitle)
	
	# New Game button
	var btn := Button.new()
	btn.text = "⚡ NEW GAME"
	btn.position = Vector2(515, 350)
	btn.size = Vector2(250, 60)
	btn.add_theme_font_size_override("font_size", 24)
	btn.pressed.connect(_on_new_game)
	add_child(btn)

	# [S24.2] Settings button — opens mixer panel as modal overlay.
	var settings_btn := Button.new()
	settings_btn.name = "SettingsButton"
	settings_btn.text = "⚙ SETTINGS"
	settings_btn.position = Vector2(515, 430)
	settings_btn.size = Vector2(250, 60)
	settings_btn.add_theme_font_size_override("font_size", 24)
	settings_btn.pressed.connect(_on_settings)
	add_child(settings_btn)

func _on_new_game() -> void:
	new_game_pressed.emit()

# [S24.2] Open the mixer settings panel as a modal overlay on the main menu.
func _on_settings() -> void:
	# Guard: only one panel at a time.
	if get_node_or_null("MixerSettingsPanel") != null:
		return
	var panel_scene: PackedScene = load("res://ui/mixer_settings_panel.tscn")
	if panel_scene == null:
		# Fallback: instantiate from script if scene not loadable in headless/test.
		var panel := MixerSettingsPanel.new()
		panel.name = "MixerSettingsPanel"
		panel.set_anchors_preset(Control.PRESET_CENTER)
		panel.position = Vector2(390, 200)
		panel.size = Vector2(500, 400)
		add_child(panel)
		return
	var panel := panel_scene.instantiate() as Control
	panel.name = "MixerSettingsPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(390, 200)
	panel.size = Vector2(500, 400)
	add_child(panel)
