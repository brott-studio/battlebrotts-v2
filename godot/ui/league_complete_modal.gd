## S14.1 — League complete modal (bronze moment).
## Fires on the ResultScreen → Shop transition when the player has just
## cleared all three Scrapyard opponents. Fade-in, placeholder badge pulse,
## single "Continue" CTA. On Continue: tells GameState to advance league,
## emits modal_dismissed, frees self. No audio this sprint (S14.1 plan §3).
##
## S22.2c: extended with LEAGUE_COPY dict, setup(state, league_id) overload,
## and _apply_badge_color VFX beat (MESH_FAIL flash → SILVER settle for silver).
class_name LeagueCompleteModal
extends CanvasLayer

signal modal_dismissed

const BRONZE    := Color(0.804, 0.498, 0.196)  ## #CD7F32-ish, muted bronze
const SILVER    := Color(0.72, 0.76, 0.80)     ## cold chrome
const MESH_FAIL := Color(0.90, 0.25, 0.20)     ## hot red — "mesh burning out"
const FLASH_DUR := 0.10
const FADE_MS   := 400

## S22.2c: extensible league copy dict. Fallback key is "bronze" on unknown league.
const LEAGUE_COPY: Dictionary = {
	"scrapyard": {
		"header": "SCRAPYARD CLEARED",
		"copy":   "Your brott earned it. Welcome to Bronze.",
	},
	"bronze": {
		"header": "SCRAPYARD CLEARED",
		"copy":   "Your brott earned it. Welcome to Bronze.",
	},
	"silver": {
		"header": "BRONZE CLEARED",
		"copy":   "Reactive mesh loses its teeth up here. Silver runs hotter.",
	},
}

var _state: GameState
var _overlay: ColorRect
var _badge: ColorRect
var _header_label: Label
var _copy_label: Label
var _league_id: String = "bronze"

## S22.2c: accepts league_id to drive copy + VFX. Default "bronze" preserves
## existing call-sites that pass only state (e.g. scrapyard ceremony).
func setup(state: GameState, league_id: String = "bronze") -> void:
	_state = state
	_league_id = league_id

func _ready() -> void:
	layer = 110  # above any other modals/screens

	_overlay = ColorRect.new()
	_overlay.anchor_right = 1.0
	_overlay.anchor_bottom = 1.0
	_overlay.color = Color(0, 0, 0, 0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	var vbox := VBoxContainer.new()
	vbox.anchor_left = 0.5
	vbox.anchor_top = 0.5
	vbox.anchor_right = 0.5
	vbox.anchor_bottom = 0.5
	vbox.offset_left = -220.0
	vbox.offset_top = -180.0
	vbox.offset_right = 220.0
	vbox.offset_bottom = 180.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	_overlay.add_child(vbox)

	## S22.2c: header text is set after _ready via LEAGUE_COPY lookup.
	var header := Label.new()
	header.text = ""
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 28)
	vbox.add_child(header)
	_header_label = header

	# Badge — a ColorRect; color driven by _apply_badge_color().
	var badge_wrap := CenterContainer.new()
	vbox.add_child(badge_wrap)
	_badge = ColorRect.new()
	_badge.custom_minimum_size = Vector2(90, 90)
	_badge.color = BRONZE
	badge_wrap.add_child(_badge)

	## S22.2c: copy text is set after _ready via LEAGUE_COPY lookup.
	var copy := Label.new()
	copy.text = ""
	copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD
	copy.custom_minimum_size = Vector2(380, 0)
	vbox.add_child(copy)
	_copy_label = copy

	var btn := Button.new()
	btn.text = "Continue"
	btn.custom_minimum_size = Vector2(180, 40)
	btn.pressed.connect(_on_continue)
	var btn_row := CenterContainer.new()
	btn_row.add_child(btn)
	vbox.add_child(btn_row)

	## S22.2c: apply copy + VFX BEFORE fade-in animation.
	var entry: Dictionary = LEAGUE_COPY.get(_league_id, LEAGUE_COPY["bronze"])
	_header_label.text = entry["header"]
	_copy_label.text   = entry["copy"]
	_apply_badge_color(_league_id)
	_animate_in()

## S22.2c: Set badge color/VFX for the given league.
## For silver: 0-dur snap to MESH_FAIL ("mesh burning out") then FLASH_DUR
## settle to SILVER chrome. Called BEFORE _animate_in() in _ready().
func _apply_badge_color(league_id: String) -> void:
	if league_id != "silver":
		_badge.modulate = BRONZE
		return
	var tw := create_tween()
	tw.tween_property(_badge, "modulate", MESH_FAIL, 0.0)    # snap to red
	tw.tween_property(_badge, "modulate", SILVER, FLASH_DUR)  # settle to chrome

func _animate_in() -> void:
	# Fade overlay to dim; pulse the badge subtly.
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_overlay, "color:a", 0.7, float(FADE_MS) / 1000.0)
	# Badge idle pulse: modulate brightness, loop.
	var pulse := create_tween()
	pulse.set_loops()
	pulse.tween_property(_badge, "modulate", Color(1.15, 1.15, 1.15), 0.8)
	pulse.tween_property(_badge, "modulate", Color(0.85, 0.85, 0.85), 0.8)

func _on_continue() -> void:
	if _state != null:
		_state.advance_league()
	modal_dismissed.emit()
	queue_free()
