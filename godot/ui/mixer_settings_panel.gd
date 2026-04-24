## [S24.2] Mixer Settings Panel — 3-bus volume sliders + mute integration.
##
## Extends PanelContainer. Opened from MainMenuScreen as a modal overlay.
## Volume scale: linear dB, -40.0 to +6.0 dB, step 0.5.
## Note: linear dB is used (not log-taper) to keep implementation within LOC
## budget. A log-taper utility may be added in Arc F if desired.
##
## Bus indices (from default_bus_layout.tres — do not change):
##   0 = Master, 1 = SFX, 2 = Music
##
## Changes are live: value_changed writes to AudioServer + FirstRunState immediately.
## No Apply/Save button. Close button at bottom dismisses the panel.
class_name MixerSettingsPanel
extends PanelContainer

const COLOR_CREAM := Color("#F4E4BC")
const COLOR_MUTED := Color("#A0A0A0")
const COLOR_BG := Color("#2A2A2A")

const SLIDER_MIN := -40.0
const SLIDER_MAX := 6.0
const SLIDER_STEP := 0.5

var _master_slider: HSlider
var _sfx_slider: HSlider
var _music_slider: HSlider
var _mute_check: CheckBox

# Suppress signal feedback loops during _ready() initialisation.
var _initialising: bool = false

func _ready() -> void:
	_initialising = true
	_build_panel()
	_init_from_state()
	_initialising = false

func _build_panel() -> void:
	# Panel background style — rounded, dark, EVE-pillar compliant.
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 24.0
	style.content_margin_right = 24.0
	style.content_margin_top = 20.0
	style.content_margin_bottom = 20.0
	add_theme_stylebox_override("panel", style)

	# Outer VBox.
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	add_child(vbox)

	# Title label.
	var title_lbl := Label.new()
	title_lbl.text = "AUDIO SETTINGS"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_lbl.add_theme_color_override("font_color", COLOR_CREAM)
	vbox.add_child(title_lbl)

	# Three bus rows.
	_master_slider = _make_slider_row(vbox, "Master")
	_sfx_slider    = _make_slider_row(vbox, "SFX")
	_music_slider  = _make_slider_row(vbox, "Music")

	# Mute checkbox row.
	var mute_row := HBoxContainer.new()
	mute_row.add_theme_constant_override("separation", 8)
	vbox.add_child(mute_row)

	_mute_check = CheckBox.new()
	_mute_check.text = "Mute all audio"
	_mute_check.add_theme_font_size_override("font_size", 18)
	_mute_check.add_theme_color_override("font_color", COLOR_CREAM)
	_mute_check.toggled.connect(_on_mute_toggled)
	mute_row.add_child(_mute_check)

	# Close button.
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.pressed.connect(_on_close)
	vbox.add_child(close_btn)

func _make_slider_row(parent: VBoxContainer, bus_label: String) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = bus_label
	lbl.custom_minimum_size = Vector2(72, 0)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", COLOR_CREAM)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = SLIDER_MIN
	slider.max_value = SLIDER_MAX
	slider.step = SLIDER_STEP
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(val: float): _on_slider_changed(bus_label, val))
	row.add_child(slider)

	return slider

func _init_from_state() -> void:
	# Read initial values from AudioServer — never hardcoded.
	_master_slider.value = AudioServer.get_bus_volume_db(0)
	_sfx_slider.value    = AudioServer.get_bus_volume_db(1)
	_music_slider.value  = AudioServer.get_bus_volume_db(2)

	var frs := get_node_or_null("/root/FirstRunState")
	if frs != null:
		_mute_check.button_pressed = bool(frs.call("get_audio_muted"))

func _on_slider_changed(bus_label: String, value: float) -> void:
	if _initialising:
		return
	match bus_label:
		"Master":
			AudioServer.set_bus_volume_db(0, value)
			_write_frs("set_master_db", value)
		"SFX":
			AudioServer.set_bus_volume_db(1, value)
			_write_frs("set_sfx_db", value)
		"Music":
			AudioServer.set_bus_volume_db(2, value)
			_write_frs("set_music_db", value)

func _on_mute_toggled(toggled: bool) -> void:
	if _initialising:
		return
	var frs := get_node_or_null("/root/FirstRunState")
	if frs != null:
		frs.call("set_audio_muted", toggled)
	# Trigger _apply_audio_settings on the active route node.
	_call_apply_audio_settings()

func _call_apply_audio_settings() -> void:
	# Try game_main (canonical game flow), then main (demo/direct scene).
	var route := get_node_or_null("/root/GameMain")
	if route == null:
		route = get_node_or_null("/root/Main")
	if route != null and route.has_method("_apply_audio_settings"):
		route.call("_apply_audio_settings")
	else:
		# Fallback: apply directly.
		var frs := get_node_or_null("/root/FirstRunState")
		if frs != null:
			var muted: bool = bool(frs.call("get_audio_muted"))
			AudioServer.set_bus_mute(0, muted)

func _write_frs(method: String, value: float) -> void:
	var frs := get_node_or_null("/root/FirstRunState")
	if frs != null:
		frs.call(method, value)

func _on_close() -> void:
	queue_free()
