## Main Menu screen — title and New Game button
class_name MainMenuScreen
extends Control

signal new_game_pressed
signal continue_run_pressed

## S25.7: Track new-run + settings buttons so setup_menu() can shift them
## down when a Continue Run button is added.
var _new_run_btn: Button
var _settings_btn: Button

# [S24.5] Menu music player — persists across Settings and any future overlay modals
# because they are added as modal children of the same parent (MainMenuScreen).
var _music_player: AudioStreamPlayer

func _ready() -> void:
	_build_ui()
	_setup_menu_music()

# [S24.5] Set up and start menu background music with a 0.5s fade-in.
func _setup_menu_music() -> void:
	var stream: AudioStream = load("res://assets/audio/music/menu_loop.ogg")
	if stream == null:
		push_warning("MainMenuScreen: could not load menu_loop.ogg")
		return
	stream.loop = true
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MenuMusicPlayer"
	_music_player.stream = stream
	_music_player.bus = "Music"
	_music_player.volume_db = -40.0
	add_child(_music_player)
	_music_player.play()
	# Fade in over 0.5s from -40 dB to 0 dB.
	var tween: Tween = create_tween()
	tween.tween_property(_music_player, "volume_db", 0.0, 0.5)

# [S24.5] Fade out and stop music on scene exit.
func _exit_tree() -> void:
	if _music_player == null or not _music_player.playing:
		return
	var tween: Tween = create_tween()
	tween.tween_property(_music_player, "volume_db", -40.0, 0.5)
	await tween.finished
	if is_instance_valid(_music_player):
		_music_player.stop()

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
	
	# New Run button — S25.1: roguelike entry point
	var btn := Button.new()
	btn.name = "NewRunButton"
	btn.text = "⚡ NEW RUN"
	btn.position = Vector2(515, 350)
	btn.size = Vector2(250, 60)
	btn.add_theme_font_size_override("font_size", 24)
	btn.pressed.connect(_on_new_game)
	add_child(btn)
	_new_run_btn = btn

	# [S24.2] Settings button — opens mixer panel as modal overlay.
	var settings_btn := Button.new()
	settings_btn.name = "SettingsButton"
	settings_btn.text = "⚙ SETTINGS"
	settings_btn.position = Vector2(515, 430)
	settings_btn.size = Vector2(250, 60)
	settings_btn.add_theme_font_size_override("font_size", 24)
	settings_btn.pressed.connect(_on_settings)
	add_child(settings_btn)
	_settings_btn = settings_btn

## S25.7: Add a "Continue Run" button at the top of the menu when a run is
## active. NEW RUN and SETTINGS are shifted down to make room.
func setup_menu(has_run: bool, battle_num: int) -> void:
	if not has_run:
		return
	if get_node_or_null("ContinueRunButton") != null:
		return  ## already added
	var cont_btn := Button.new()
	cont_btn.name = "ContinueRunButton"
	cont_btn.text = "▶ Continue Run (Battle %d/15)" % battle_num
	cont_btn.position = Vector2(430, 350)
	cont_btn.size = Vector2(420, 60)
	cont_btn.add_theme_font_size_override("font_size", 20)
	cont_btn.pressed.connect(func(): continue_run_pressed.emit())
	add_child(cont_btn)
	## Shift NEW RUN + SETTINGS down so they don't overlap.
	if _new_run_btn != null:
		_new_run_btn.position = Vector2(515, 430)
	if _settings_btn != null:
		_settings_btn.position = Vector2(515, 510)

func _on_new_game() -> void:
	new_game_pressed.emit()

# [S24.2] Open the mixer settings panel as a modal overlay on the main menu.
# [S26.2-001] Fix off-screen popup: previous code did
#   set_anchors_preset(PRESET_CENTER); position = Vector2(390, 200)
# With PRESET_CENTER, all 4 anchors land at the viewport center, and
# `position` then becomes an *offset from that center*, not an absolute
# top-left. At 1280×720 the panel ended up with its top-left at
# (640+390, 360+200) = (1030, 560) — entirely off-screen right/bottom.
# Fix: drop the centered anchors and place the panel using absolute
# viewport-centered math so it lives inside the visible rect at any
# resolution we ship (1280×720 and 1920×1080).
func _on_settings() -> void:
	# Guard: only one panel at a time.
	if get_node_or_null("MixerSettingsPanel") != null:
		return
	var panel_size := Vector2(500, 400)
	var panel_scene: PackedScene = load("res://ui/mixer_settings_panel.tscn")
	if panel_scene == null:
		# Fallback: instantiate from script if scene not loadable in headless/test.
		var panel := MixerSettingsPanel.new()
		panel.name = "MixerSettingsPanel"
		panel.size = panel_size
		## S26.2: centered via absolute viewport calc — PRESET_CENTER+offset was off-screen.
		_center_panel_in_viewport(panel, panel_size)
		add_child(panel)
		return
	var panel := panel_scene.instantiate() as Control
	panel.name = "MixerSettingsPanel"
	panel.size = panel_size
	## S26.2: centered via absolute viewport calc — PRESET_CENTER+offset was off-screen.
	_center_panel_in_viewport(panel, panel_size)
	add_child(panel)

## [S26.2-001] Center a Control inside the visible viewport rect.
## Falls back to a hardcoded 1280×720-centered position if the viewport
## isn't queryable yet (e.g., during early instantiation in headless tests).
func _center_panel_in_viewport(panel: Control, panel_size: Vector2) -> void:
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var vp := get_viewport()
	var vp_size := Vector2(1280, 720)
	if vp != null:
		var rect := vp.get_visible_rect()
		if rect.size.x > 0 and rect.size.y > 0:
			vp_size = rect.size
	panel.position = Vector2(
		(vp_size.x - panel_size.x) / 2.0,
		(vp_size.y - panel_size.y) / 2.0,
	)

