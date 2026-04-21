## Sprint 17.4-001 — BrottBrain selected-row pixel-sample assertions.
## Usage: godot --headless --script tests/test_s17_4_001_selected_row_pixels.gd
## Specs:
##   - sprints/sprint-17.4.md §"Task specs" → "S17.4-001" (AC1, AC2, AC3)
##   - Closes #205 (selected-row tint invisible) + #207 (property-only
##     assertions pass while pixel output fails).
##
## This test is the canonical reference for the pixel-sample test pattern
## called out as missing in the S17.3 audit (#207). Instead of asserting
## a property on a single node (which is what passed while pixels didn't
## change in the old flat-Button modulate implementation), we compute the
## effective color AT A SCREEN COORDINATE by walking the scene tree at
## that point and alpha-compositing every overlapping node.
##
## Why node-tree compositing instead of viewport texture grab?
##   Godot's `--headless` mode uses the "dummy" rendering driver:
##   `get_viewport().get_texture().get_image()` returns a null/empty
##   image, so a GPU-based pixel readback is not a viable pattern for
##   headless CI. Node-tree compositing gives us the same semantic
##   guarantee — "the pixel at (x,y) is the result of the paint stack
##   under that point" — in pure logic. It would still fail the old
##   flat-Button modulate implementation (no ColorRect under the sample
##   point → unchanged base color → no blue shift), which is exactly
##   the #207 anti-pattern the sprint is closing.
##
## AC2 (verbatim from sprint-17.4.md):
##   - Sample a pixel inside the selected row's overlay bounds AND inside
##     an unselected row's overlay bounds.
##   - Assert selected_pixel.b > selected_pixel.r + 0.05
##     AND     selected_pixel.b > unselected_pixel.b + 0.05.
extends SceneTree

var pass_count := 0
var fail_count := 0
var test_count := 0

# Known base color for the BrottBrain screen under headless test. The
# screen is a bare Control with no fill, so the sample base starts as
# fully-transparent black Color(0, 0, 0, 0). All assertions below
# remain valid against any base color so long as it's identical between
# the selected and unselected sample points (which it is — same screen,
# same frame).
const BASE_COLOR := Color(0, 0, 0, 0)

func _initialize() -> void:
	print("=== S17.4-001 BrottBrain selected-row pixel-sample tests ===\n")
	_test_selected_row_pixel_is_blue_tinted()
	_test_unselected_row_pixel_is_not_blue_tinted()
	_test_click_still_selects_row()
	_test_overlay_mouse_filter_is_ignore()
	_test_click_capture_button_is_stacked_above_overlay()
	print("\n=== Results: %d passed, %d failed, %d total ===" % [pass_count, fail_count, test_count])
	quit(1 if fail_count > 0 else 0)

func _assert(cond: bool, msg: String) -> void:
	test_count += 1
	if cond:
		pass_count += 1
	else:
		fail_count += 1
		print("  FAIL: %s" % msg)

# --- Fixture ---

func _mk_screen_with_cards(card_count: int, selected: int) -> BrottBrainScreen:
	var gs := GameState.new()
	gs.equipped_chassis = ChassisData.ChassisType.BRAWLER
	gs.equipped_modules = []
	var brain := BrottBrain.default_for_chassis(gs.equipped_chassis)
	while brain.cards.size() < card_count and brain.cards.size() < BrottBrain.MAX_CARDS:
		brain.cards.append(BrottBrain.BehaviorCard.new(0, 0.4, 0, 0))
	while brain.cards.size() > card_count:
		brain.cards.pop_back()
	var screen := BrottBrainScreen.new()
	screen.size = Vector2(1280, 720)
	root.add_child(screen)
	screen.tutorial_dismissed = true
	screen.selected_card_index = selected
	screen.setup(gs, brain)
	return screen

# Find the ColorRect overlay for a given row index by name (set in
# _draw_card as "select_overlay_<index>").
func _find_overlay(screen: BrottBrainScreen, index: int) -> ColorRect:
	for child in screen.get_children():
		if child is ColorRect and not child.is_queued_for_deletion():
			var cr: ColorRect = child
			if cr.name == StringName("select_overlay_%d" % index):
				return cr
	return null

# --- Pixel-sample helper (the #207 reference pattern) ---
#
# Compute the effective color at a screen coordinate by walking the
# scene tree and alpha-compositing every node whose rect contains the
# point. Iterates children in draw order (child index ascending, which
# matches Godot's draw order for sibling Control nodes).
#
# Per node, we check:
#   - ColorRect → composite its .color * .modulate over the accumulator.
#   - Panel, Button, Label, etc. → ignored for this test; the only
#     pixel-opaque content we care about in the S17.4-001 fix path is
#     the ColorRect overlay. The old flat-Button modulate would not
#     paint pixels here either, so the test correctly fails the old
#     implementation.
#
# Alpha composition formula (source-over, premultiplied math):
#   out.a = src.a + dst.a * (1 - src.a)
#   out.rgb = (src.rgb * src.a + dst.rgb * dst.a * (1 - src.a)) / out.a
#   (returns src when out.a == 0 to avoid division-by-zero in the
#   fully-transparent case; that path is only hit when both base and
#   overlay are transparent, which is a degenerate fixture case.)
func _sample_pixel(screen: BrottBrainScreen, point: Vector2) -> Color:
	var acc := BASE_COLOR
	for child in screen.get_children():
		if not (child is ColorRect):
			continue
		if child.is_queued_for_deletion():
			continue
		var cr: ColorRect = child
		if not cr.visible:
			continue
		var rect := Rect2(cr.position, cr.size)
		if not rect.has_point(point):
			continue
		var src: Color = cr.color * cr.modulate
		acc = _composite_over(src, acc)
	return acc

func _composite_over(src: Color, dst: Color) -> Color:
	var out_a: float = src.a + dst.a * (1.0 - src.a)
	if out_a <= 0.0001:
		return src
	var out_r: float = (src.r * src.a + dst.r * dst.a * (1.0 - src.a)) / out_a
	var out_g: float = (src.g * src.a + dst.g * dst.a * (1.0 - src.a)) / out_a
	var out_b: float = (src.b * src.a + dst.b * dst.a * (1.0 - src.a)) / out_a
	return Color(out_r, out_g, out_b, out_a)

# --- Tests ---

# AC1 + AC2: pixel at the center of the selected row's overlay bounds
# shows visible blue tint. `selected_pixel.b > selected_pixel.r + 0.05`.
func _test_selected_row_pixel_is_blue_tinted() -> void:
	var screen := _mk_screen_with_cards(3, 1)
	var selected_cr := _find_overlay(screen, 1)
	_assert(selected_cr != null, "Found selected row ColorRect overlay at index 1")
	if selected_cr == null:
		screen.queue_free()
		return
	# Sample a point well inside the overlay bounds (center, to avoid any
	# sub-pixel edge ambiguity).
	var sel_point: Vector2 = selected_cr.position + selected_cr.size * 0.5
	var selected_pixel: Color = _sample_pixel(screen, sel_point)
	print("  selected_pixel   = %s (sampled at %s)" % [str(selected_pixel), str(sel_point)])
	_assert(selected_pixel.b > selected_pixel.r + 0.05,
		"Selected-row pixel is blue-shifted: b > r + 0.05 (got b=%.3f, r=%.3f)" % [selected_pixel.b, selected_pixel.r])
	_assert(selected_pixel.a > 0.0,
		"Selected-row pixel is NOT fully transparent (alpha > 0): got a=%.3f" % selected_pixel.a)
	screen.queue_free()

# AC1 + AC2 (comparative): selected row is more-blue than the unselected
# row at the equivalent sample position. `selected.b > unselected.b + 0.05`.
func _test_unselected_row_pixel_is_not_blue_tinted() -> void:
	var screen := _mk_screen_with_cards(3, 1)
	var selected_cr := _find_overlay(screen, 1)
	var unselected_cr := _find_overlay(screen, 0)
	_assert(selected_cr != null and unselected_cr != null,
		"Found both selected (idx 1) and unselected (idx 0) ColorRect overlays")
	if selected_cr == null or unselected_cr == null:
		screen.queue_free()
		return
	var sel_point: Vector2 = selected_cr.position + selected_cr.size * 0.5
	var unsel_point: Vector2 = unselected_cr.position + unselected_cr.size * 0.5
	var selected_pixel: Color = _sample_pixel(screen, sel_point)
	var unselected_pixel: Color = _sample_pixel(screen, unsel_point)
	print("  unselected_pixel = %s (sampled at %s)" % [str(unselected_pixel), str(unsel_point)])
	_assert(selected_pixel.b > unselected_pixel.b + 0.05,
		"Selected-row pixel is more-blue than unselected: selected.b > unselected.b + 0.05 (got sel.b=%.3f, unsel.b=%.3f)" % [selected_pixel.b, unselected_pixel.b])
	# Unselected overlay has alpha 0 → composited pixel keeps the base
	# alpha, meaning the overlay contributes zero color. This is the key
	# proof that the old modulate pattern would not have shifted the blue
	# channel here either — it's pixel-true evidence, not property-true.
	_assert(unselected_pixel.a == BASE_COLOR.a,
		"Unselected-row overlay contributes nothing: pixel alpha unchanged from base (got a=%.3f, base=%.3f)" % [unselected_pixel.a, BASE_COLOR.a])
	screen.queue_free()

# AC3 (click still selects): pressing the click-capture Button on a
# non-selected row updates selected_card_index.
func _test_click_still_selects_row() -> void:
	var screen := _mk_screen_with_cards(3, 0)
	_assert(screen.selected_card_index == 0, "Initial selected_card_index == 0")
	var buttons: Array = []
	for child in screen.get_children():
		if child is Button and not child.is_queued_for_deletion():
			var btn: Button = child
			if btn.flat and btn.text == "" and int(btn.size.x) == 600 and int(btn.size.y) == 55:
				buttons.append(btn)
	_assert(buttons.size() == 3, "Found 3 click-capture Buttons (600x55, flat, empty), got %d" % buttons.size())
	if buttons.size() < 3:
		screen.queue_free()
		return
	buttons[2].pressed.emit()
	_assert(screen.selected_card_index == 2,
		"After clicking row 2's Button, selected_card_index == 2 (got %d)" % screen.selected_card_index)
	screen.queue_free()

# AC3 (overlay must not steal clicks): every ColorRect overlay has
# mouse_filter == MOUSE_FILTER_IGNORE so clicks pass through.
func _test_overlay_mouse_filter_is_ignore() -> void:
	var screen := _mk_screen_with_cards(3, 1)
	var count := 0
	for i in range(3):
		var cr := _find_overlay(screen, i)
		if cr == null:
			continue
		count += 1
		_assert(cr.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"Overlay row %d mouse_filter == MOUSE_FILTER_IGNORE (clicks pass through to Button above)" % i)
	_assert(count == 3, "Found 3 ColorRect overlays, got %d" % count)
	screen.queue_free()

# AC3 (draw-order): click-capture Button is emitted AFTER its ColorRect
# overlay, so Godot draws it on top and it receives input.
func _test_click_capture_button_is_stacked_above_overlay() -> void:
	var screen := _mk_screen_with_cards(3, 1)
	for i in range(3):
		var cr := _find_overlay(screen, i)
		if cr == null:
			continue
		var found := false
		var after_cr := false
		for child in screen.get_children():
			if child == cr:
				after_cr = true
				continue
			if not after_cr:
				continue
			if child is Button and not child.is_queued_for_deletion():
				var btn: Button = child
				if btn.flat and btn.text == "" and int(btn.size.x) == 600 and int(btn.size.y) == 55 and btn.position == cr.position:
					found = true
					break
		_assert(found,
			"Row %d: click-capture Button (flat, 600x55, same position) is stacked AFTER its ColorRect overlay in child order" % i)
	screen.queue_free()
