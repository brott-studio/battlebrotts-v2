## Arc I S(I).2 — TestSettingsFlow
## End-to-end user flow: boot → main menu → open settings panel (SettingsButton)
## → panel visible → close → panel gone → main menu still intact.
##
## Acceptance criteria:
##   - exits 0 on clean run
##   - exits 1 if MixerSettingsPanel fails to open or close
##   - wall-clock under 15s
##
## Usage:
##   godot --headless --path godot/ --script "res://tests/auto/test_settings_flow.gd"

extends AutoDriver

var _step: int = 0

func _initialize() -> void:
	var packed: PackedScene = load("res://game_main.tscn")
	game_main = packed.instantiate()
	root.add_child(game_main)
	_setup_test_environment()
	_ticks_remaining = 40  # boot + settle

func _drive_flow_step() -> void:
	match _step:
		0:
			# Assert MAIN_MENU state after boot
			var gf: Object = game_main.get("game_flow")
			var screen: int = gf.get("current_screen") if gf != null else -1
			if screen != 0:
				_failures.append("Expected MAIN_MENU(0) after boot, got %d" % screen)
			assert_state("run.active", false)
			# Find the MainMenuScreen and its SettingsButton
			var menu_screen := _find_child_of_type(game_main, "MainMenuScreen")
			if menu_screen == null:
				_failures.append("MainMenuScreen not found after boot")
				_flow_done = true
				finish(1)
				return
			var settings_btn: Button = menu_screen.get_node_or_null("SettingsButton") as Button
			if settings_btn == null:
				_failures.append("SettingsButton not found in MainMenuScreen")
				_flow_done = true
				finish(1)
				return
			settings_btn.emit_signal("pressed")
			_ticks_remaining = 10
			_step += 1

		1:
			# Assert MixerSettingsPanel is now visible
			var menu_screen := _find_child_of_type(game_main, "MainMenuScreen")
			if menu_screen == null:
				_failures.append("MainMenuScreen lost after settings open")
				_flow_done = true
				finish(1)
				return
			var panel: Control = menu_screen.get_node_or_null("MixerSettingsPanel") as Control
			if panel == null:
				_failures.append("MixerSettingsPanel not found after SettingsButton pressed")
				_flow_done = true
				finish(1)
				return
			# Close via the Close button
			var close_btn: Button = panel.get_node_or_null("VBoxContainer/Close") as Button
			if close_btn == null:
				# Fallback: try direct child search for any Button with text "Close"
				close_btn = _find_close_button(panel)
			if close_btn == null:
				_failures.append("Close button not found in MixerSettingsPanel")
				_flow_done = true
				finish(1)
				return
			close_btn.emit_signal("pressed")
			_ticks_remaining = 10
			_step += 1

		2:
			# Assert panel is gone (queue_free'd)
			var menu_screen := _find_child_of_type(game_main, "MainMenuScreen")
			if menu_screen == null:
				_failures.append("MainMenuScreen lost after settings close")
				_flow_done = true
				finish(1)
				return
			var panel_after: Node = menu_screen.get_node_or_null("MixerSettingsPanel")
			if panel_after != null:
				_failures.append("MixerSettingsPanel still present after Close pressed")
			# Main menu should still be on MAIN_MENU screen
			var gf: Object = game_main.get("game_flow")
			var screen: int = gf.get("current_screen") if gf != null else -1
			if screen != 0:
				_failures.append("Expected MAIN_MENU(0) after settings close, got %d" % screen)
			_flow_done = true
			finish()

## Scan direct children for a Button whose text is "Close".
## mixer_settings_panel uses a VBoxContainer; the close button is the last
## item in that VBox, but node path may vary across refactors.
func _find_close_button(parent: Node) -> Button:
	for child in parent.get_children():
		if child is Button and (child as Button).text == "Close":
			return child as Button
		var found: Button = _find_close_button(child)
		if found != null:
			return found
	return null
