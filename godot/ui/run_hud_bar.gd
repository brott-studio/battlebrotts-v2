## run_hud_bar.gd — S25.5: Persistent run status bar shown on reward + retry screens.
## Read-only display; never mutates RunState.
class_name RunHudBar
extends Control

var _run_state: RunState = null
var _battle_label: Label
var _retry_label: Label
var _build_label: Label
var _bg_panel: Panel

func setup(run_state: RunState) -> void:
	_run_state = run_state
	if _run_state.run_state_changed.is_connected(_on_state_changed):
		_run_state.run_state_changed.disconnect(_on_state_changed)
	_run_state.run_state_changed.connect(_on_state_changed)
	_build_ui()
	_refresh()

func _build_ui() -> void:
	## Background panel
	_bg_panel = Panel.new()
	_bg_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg_panel)

	## Battle counter
	_battle_label = Label.new()
	_battle_label.add_theme_font_size_override("font_size", 14)
	_battle_label.position = Vector2(8, 4)
	_battle_label.size = Vector2(160, 24)
	add_child(_battle_label)

	## Retry count
	_retry_label = Label.new()
	_retry_label.add_theme_font_size_override("font_size", 14)
	_retry_label.position = Vector2(180, 4)
	_retry_label.size = Vector2(120, 24)
	add_child(_retry_label)

	## Build summary
	_build_label = Label.new()
	_build_label.add_theme_font_size_override("font_size", 12)
	_build_label.position = Vector2(320, 4)
	_build_label.size = Vector2(400, 24)
	add_child(_build_label)

func _refresh() -> void:
	if _run_state == null:
		return
	var battle_num := _run_state.current_battle_index + 1
	_battle_label.text = "⚔️ Battle %d/15" % battle_num
	## S25.7: Apply per-battle color shift to the battle label.
	_battle_label.add_theme_color_override("font_color", _color_for_battle(battle_num))
	_retry_label.text = "💀 %d retries" % _run_state.retry_count

	## Build summary
	var wn := "%d W" % _run_state.equipped_weapons.size()
	var an := "A:%d" % _run_state.equipped_armor
	var mn := "%d M" % _run_state.equipped_modules.size()
	_build_label.text = "🔩 %s | %s | %s" % [wn, an, mn]

	## Color threshold (0-indexed battle_index)
	var idx := _run_state.current_battle_index
	if idx >= 13:  ## battle 14 = red
		modulate = Color(1.0, 0.4, 0.4)
	elif idx >= 11:  ## battle 12 = amber
		modulate = Color(1.0, 0.75, 0.2)
	else:
		modulate = Color.WHITE

## S25.7: Color coding per battle count (1-indexed).
static func _color_for_battle(battle_num: int) -> Color:
	if battle_num >= 15:
		return Color(1.0, 0.84, 0.0)  ## gold (#FFD700)
	if battle_num >= 14:
		return Color(0.957, 0.263, 0.212)  ## red (#F44336)
	if battle_num >= 12:
		return Color(1.0, 0.757, 0.027)  ## amber (#FFC107)
	return Color.WHITE

func _on_state_changed() -> void:
	_refresh()

func _exit_tree() -> void:
	if _run_state != null and _run_state.run_state_changed.is_connected(_on_state_changed):
		_run_state.run_state_changed.disconnect(_on_state_changed)
