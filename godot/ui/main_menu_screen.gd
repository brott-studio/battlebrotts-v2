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

func _on_new_game() -> void:
	new_game_pressed.emit()
