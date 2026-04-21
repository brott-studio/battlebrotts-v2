## Sprint 17.4-002 — BrottBrain tray/nav overlap fix via ScrollContainer + fixed tray anchor.
## Usage: godot --headless --script tests/test_s17_4_002_tray_scroll_anchor.gd
## Specs:
##   - sprints/sprint-17.4.md §"Task specs" → "S17.4-002" (AC1-AC7)
##   - Closes #206 (BrottBrain tray/nav overlap at MAX_CARDS==8).
##
## Fix (Gizmo Phase 1 spec, verbatim):
##   - Card-draw region wrapped in ScrollContainer, size (770, 220),
##     position (20, 132), vertical_scroll_mode = SCROLL_MODE_AUTO.
##   - tray_y_base = 370 (fixed, independent of cards.size()).
##   - Reorder buttons btn_x = 820.
##
## Pixel-sample pattern reused from S17.4-001 (godot/tests/
## test_s17_4_001_selected_row_pixels.gd). See its header for the
## #207 rationale on tree-walk compositing vs viewport texture grab.
extends SceneTree

var pass_count := 0
var fail_count := 0
var test_count := 0

func _initialize() -> void:
	print("=== S17.4-002 BrottBrain tray-scroll-anchor tests ===\n")
	_test_scroll_container_shape_and_mode()
	_test_tray_decoupled_from_card_count_ac4()
	_test_no_tray_nav_overlap_at_max_cards_ac1()
	_test_nav_buttons_unchanged_at_y650_ac3()
	_test_card_region_overflows_at_5_cards_ac2()
	_test_no_scrollbar_whitespace_below_4_cards_ac5()
	_test_reorder_buttons_cleared_to_btn_x_820()
	_test_max_cards_8_pixel_sample_confirms_no_overlap_ac7()
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

func _mk_screen(card_count: int) -> BrottBrainScreen:
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
	screen.setup(gs, brain)
	return screen

# --- Tree walkers ---

func _find_by_name(node: Node, target: StringName) -> Node:
	if node.name == target:
		return node
	for child in node.get_children():
		var found := _find_by_name(child, target)
		if found != null:
			return found
	return null

func _find_scroll(screen: BrottBrainScreen) -> ScrollContainer:
	var n := _find_by_name(screen, StringName("card_scroll"))
	return n as ScrollContainer

func _find_content(screen: BrottBrainScreen) -> Control:
	var n := _find_by_name(screen, StringName("card_content"))
	return n as Control

# Absolute (screen-local) rect for a Control that lives anywhere in the
# screen's subtree. Walks up to the screen and sums `position` offsets.
# For our test fixture the screen itself is the reference origin.
func _abs_rect(screen: BrottBrainScreen, c: Control) -> Rect2:
	var origin := c.position
	var p := c.get_parent()
	while p != null and p != screen:
		if p is Control:
			origin += (p as Control).position
		p = p.get_parent()
	return Rect2(origin, c.size)

# Find the tray header Label "── Available Cards ──" — its y position is
# the tray's anchor point. Children of the screen (not nested).
func _find_tray_header(screen: BrottBrainScreen) -> Label:
	for child in screen.get_children():
		if child is Label and not child.is_queued_for_deletion():
			var lbl: Label = child
			if lbl.text == "── Available Cards ──":
				return lbl
	return null

# The tray is made up of: the header, the "WHEN:" / "THEN:" labels, and
# the trigger/action buttons. They're all direct children of the screen
# (not inside card_scroll). tray_end_y is the max y+height across every
# tray-associated child; we identify tray children by y >= tray_header.y.
func _tray_end_y(screen: BrottBrainScreen) -> float:
	var header := _find_tray_header(screen)
	if header == null:
		return -1.0
	var tray_top: float = header.position.y
	var end_y: float = tray_top + header.size.y
	for child in screen.get_children():
		if not (child is Control):
			continue
		if child.is_queued_for_deletion():
			continue
		# Skip the navigation buttons at y=650 (they're not tray).
		if child is Button:
			var btn_text := (child as Button).text
			if btn_text.begins_with("← ") or btn_text.ends_with(" →"):
				continue
		var c := child as Control
		if c.position.y < tray_top:
			continue
		# Skip the scroll container and its contents.
		if c.name == StringName("card_scroll"):
			continue
		var bottom: float = c.position.y + c.size.y
		if bottom > end_y:
			end_y = bottom
	return end_y

# Find the two nav buttons — "← Loadout" and "Fight! →" — at the bottom.
func _find_nav_buttons(screen: BrottBrainScreen) -> Array:
	var out: Array = []
	for child in screen.get_children():
		if child is Button and not child.is_queued_for_deletion():
			var btn: Button = child
			if btn.text.begins_with("← ") or btn.text.ends_with(" →"):
				out.append(btn)
	return out

# Find the ▲ Up / ▼ Down reorder buttons.
func _find_reorder_buttons(screen: BrottBrainScreen) -> Array:
	var out: Array = []
	for child in screen.get_children():
		if child is Button and not child.is_queued_for_deletion():
			var btn: Button = child
			if btn.text == "▲ Up" or btn.text == "▼ Down":
				out.append(btn)
	return out

# --- Tests ---

# AC5 spec check: ScrollContainer present at (20,132) sized (770,220)
# with vertical_scroll_mode == SCROLL_MODE_AUTO.
func _test_scroll_container_shape_and_mode() -> void:
	var screen := _mk_screen(3)
	var sc := _find_scroll(screen)
	_assert(sc != null, "ScrollContainer 'card_scroll' exists under the screen")
	if sc == null:
		screen.queue_free()
		return
	_assert(sc.position == Vector2(20, 132),
		"ScrollContainer position == (20, 132), got %s" % str(sc.position))
	_assert(sc.size == Vector2(770, 220),
		"ScrollContainer size == (770, 220), got %s" % str(sc.size))
	_assert(sc.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO,
		"ScrollContainer.vertical_scroll_mode == SCROLL_MODE_AUTO (AC5), got %d" % sc.vertical_scroll_mode)
	screen.queue_free()

# AC4: tray end-y at 0 cards vs 8 cards must match within ±5px.
# This proves tray_y_base is decoupled from cards.size().
func _test_tray_decoupled_from_card_count_ac4() -> void:
	var s0 := _mk_screen(0)
	var end_0: float = _tray_end_y(s0)
	s0.queue_free()
	var s8 := _mk_screen(8)
	var end_8: float = _tray_end_y(s8)
	s8.queue_free()
	_assert(end_0 > 0 and end_8 > 0,
		"Tray end-y computed for both fixtures (0-card=%.1f, 8-card=%.1f)" % [end_0, end_8])
	_assert(absf(end_0 - end_8) <= 5.0,
		"AC4: tray end-y at 0 cards (%.1f) matches tray end-y at 8 cards (%.1f) within ±5px (delta=%.1f)"
			% [end_0, end_8, absf(end_0 - end_8)])
	# Extra: math-verified target from spec — tray end-y ≈ 505, well
	# under nav y=650. Give +/- 40px of tolerance for tray-button
	# wrapping / row-height variance.
	_assert(end_8 < 600.0,
		"Tray end-y at 8 cards (%.1f) is clear of nav (y=650), below 600" % end_8)
	_assert(end_8 > 370.0,
		"Tray end-y at 8 cards (%.1f) is below the tray header anchor (y=370)" % end_8)

# AC1: at MAX_CARDS==8, zero pixel overlap between tray elements and
# nav buttons. Bounds-check form: no tray child's rect intersects any
# nav-button rect.
func _test_no_tray_nav_overlap_at_max_cards_ac1() -> void:
	var screen := _mk_screen(BrottBrain.MAX_CARDS)  # 8
	var header := _find_tray_header(screen)
	_assert(header != null, "Tray header exists at MAX_CARDS==8")
	if header == null:
		screen.queue_free()
		return
	var tray_top: float = header.position.y
	var nav := _find_nav_buttons(screen)
	_assert(nav.size() == 2, "Found 2 nav buttons, got %d" % nav.size())
	var overlap_count := 0
	for child in screen.get_children():
		if not (child is Control):
			continue
		if child.is_queued_for_deletion():
			continue
		var c := child as Control
		if c.position.y < tray_top:
			continue
		if c in nav:
			continue
		if c.name == StringName("card_scroll"):
			continue
		var c_rect := Rect2(c.position, c.size)
		for nbtn in nav:
			var n_rect := Rect2((nbtn as Button).position, (nbtn as Button).size)
			if c_rect.intersects(n_rect):
				overlap_count += 1
				print("  OVERLAP: tray child %s rect=%s intersects nav rect=%s"
					% [c.name, str(c_rect), str(n_rect)])
	_assert(overlap_count == 0,
		"AC1: zero pixel overlap between tray elements and nav buttons at MAX_CARDS==8 (got %d overlaps)" % overlap_count)
	screen.queue_free()

# AC3: nav buttons unchanged at y=650.
func _test_nav_buttons_unchanged_at_y650_ac3() -> void:
	var screen := _mk_screen(3)
	var nav := _find_nav_buttons(screen)
	_assert(nav.size() == 2, "Found 2 nav buttons")
	for btn in nav:
		_assert(int((btn as Button).position.y) == 650,
			"AC3: nav button '%s' at y=650 (got y=%.1f)" % [(btn as Button).text, (btn as Button).position.y])
	screen.queue_free()

# AC2: card-draw region scrolls when content overflows the (770, 220)
# viewport. With card height 55, five cards require 5*55 = 275px, which
# overflows 220 → scrollbar must be available.
func _test_card_region_overflows_at_5_cards_ac2() -> void:
	var screen := _mk_screen(5)
	var sc := _find_scroll(screen)
	var content := _find_content(screen)
	_assert(sc != null and content != null, "ScrollContainer + content both present at 5 cards")
	if sc == null or content == null:
		screen.queue_free()
		return
	# Content height should exceed viewport height (220). 5 cards * 55 =
	# 275 + 30 (empty slot indicator, since 5 < MAX_CARDS==8) = 305.
	var content_min_h: float = content.custom_minimum_size.y
	_assert(content_min_h > sc.size.y,
		"AC2: content custom_minimum_size.y (%.1f) > ScrollContainer viewport height (%.1f) → scrolls"
			% [content_min_h, sc.size.y])
	screen.queue_free()

# AC5: vertical_scroll_mode == SCROLL_MODE_AUTO means no scrollbar /
# whitespace when cards.size() < 4. We verify by checking that content
# height does NOT exceed the viewport at 3 cards.
func _test_no_scrollbar_whitespace_below_4_cards_ac5() -> void:
	var screen := _mk_screen(3)
	var sc := _find_scroll(screen)
	var content := _find_content(screen)
	if sc == null or content == null:
		screen.queue_free()
		return
	# 3 cards * 55 = 165 + 30 (empty slot) = 195, which is <= 220 viewport.
	# SCROLL_MODE_AUTO: no scrollbar visible. Verify the mode directly +
	# verify content fits.
	_assert(sc.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO,
		"AC5: vertical_scroll_mode == SCROLL_MODE_AUTO at 3 cards")
	_assert(content.custom_minimum_size.y <= sc.size.y,
		"AC5: content height (%.1f) <= viewport (%.1f) at 3 cards → no scrollbar, no whitespace"
			% [content.custom_minimum_size.y, sc.size.y])
	screen.queue_free()

# Spec check: reorder buttons moved from btn_x=680 to btn_x=820. Both
# at y=132 and y=168, size (90, 32).
func _test_reorder_buttons_cleared_to_btn_x_820() -> void:
	var screen := _mk_screen(3)
	var reorder := _find_reorder_buttons(screen)
	_assert(reorder.size() == 2, "Found ▲ Up + ▼ Down buttons (%d)" % reorder.size())
	for btn in reorder:
		var b: Button = btn
		_assert(int(b.position.x) == 820,
			"Reorder button '%s' at btn_x=820 (got x=%.1f)" % [b.text, b.position.x])
		# Ensure btn_x=820 + width 90 = 910 stays within the 1280 screen
		# and clears the 770-wide scroll container at x=20-790.
		_assert(b.position.x >= 790,
			"Reorder button '%s' x=%.1f clears ScrollContainer right edge (790)" % [b.text, b.position.x])
	screen.queue_free()

# AC7: pixel-sample assertion confirming AC1 at MAX_CARDS==8. Sample
# the center pixel of every nav-button rect and assert no ColorRect
# overlay from the card region overlaps it. In our fixture the card
# region's ColorRect overlays live inside card_scroll/card_content,
# whose absolute position stays at (20,132)-(790,352) regardless of
# card count — which is well above nav y=650.
func _test_max_cards_8_pixel_sample_confirms_no_overlap_ac7() -> void:
	var screen := _mk_screen(BrottBrain.MAX_CARDS)
	var nav := _find_nav_buttons(screen)
	var sc := _find_scroll(screen)
	_assert(sc != null, "ScrollContainer present for AC7 pixel-sample")
	if sc == null:
		screen.queue_free()
		return
	var sc_rect := Rect2(sc.position, sc.size)
	for nbtn in nav:
		var n_rect := Rect2((nbtn as Button).position, (nbtn as Button).size)
		# Sample the center of the nav button. Assert the ScrollContainer
		# rect does NOT contain it (and does not intersect).
		var center: Vector2 = n_rect.position + n_rect.size * 0.5
		_assert(not sc_rect.has_point(center),
			"AC7: center of nav button '%s' at %s is NOT inside ScrollContainer rect %s"
				% [(nbtn as Button).text, str(center), str(sc_rect)])
		_assert(not sc_rect.intersects(n_rect),
			"AC7: ScrollContainer rect %s does not intersect nav rect %s" % [str(sc_rect), str(n_rect)])
	# Also: the tray's bottom-most element must sit above every nav
	# button's top edge (pixel-true bounds check).
	var tray_end: float = _tray_end_y(screen)
	for nbtn in nav:
		var nav_top: float = (nbtn as Button).position.y
		_assert(tray_end <= nav_top,
			"AC7: tray end-y (%.1f) at MAX_CARDS==8 is at or above nav '%s' top (y=%.1f)"
				% [tray_end, (nbtn as Button).text, nav_top])
	screen.queue_free()
