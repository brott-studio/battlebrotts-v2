## Sprint 17.1-002 — Loadout UI footer overlap fix
## Usage: godot --headless --script tests/test_sprint17_1_loadout_overlap.gd
## Design: docs/design/s17.1-002-loadout-overlap.md
## Covers (per design §6):
##   AC-1 — ScrollContainer exists and is sized correctly
##   AC-2 — Shop button reachable at inventory = 0, 5, 20, 50
##   AC-3 — Continue button reachable at same inventory sizes
##   AC-4 — Scroll range grows with inventory
##   AC-5 — Signal contract preserved
##   AC-6 — Empty-state layout unchanged (no awkward gap)
extends SceneTree

var pass_count := 0
var fail_count := 0
var test_count := 0

var _signal_back_fired := false
var _signal_continue_fired := false

func _initialize() -> void:
	print("=== Sprint 17.1-002 Loadout Overlap Tests ===\n")
	_run_all()
	print("\n=== Results: %d passed, %d failed, %d total ===" % [pass_count, fail_count, test_count])
	if fail_count > 0:
		quit(1)
	else:
		quit(0)

func assert_eq(a, b, msg: String) -> void:
	test_count += 1
	if a == b:
		pass_count += 1
	else:
		fail_count += 1
		print("  FAIL: %s (got %s, expected %s)" % [msg, str(a), str(b)])

func assert_true(cond: bool, msg: String) -> void:
	test_count += 1
	if cond:
		pass_count += 1
	else:
		fail_count += 1
		print("  FAIL: %s" % msg)

func _cleanup(screen: LoadoutScreen) -> void:
	if screen and screen.get_parent():
		screen.get_parent().remove_child(screen)
	if screen:
		screen.free()

## Build a GameState whose total inventory (weapons + armor + modules) sums to
## roughly inv_size. Distribution favors weapons since weapon slots drive
## empty-slot indicator count. Type duplicates are legal — loadout UI iterates
## the arrays directly and renders one card per entry.
func _build_fixture_state(inv_size: int) -> GameState:
	var gs := GameState.new()
	gs.owned_chassis = [0, 1, 2]
	gs.equipped_chassis = 0
	gs.owned_weapons = []
	gs.owned_armor = []
	gs.owned_modules = []
	gs.equipped_weapons = []
	gs.equipped_armor = 0
	gs.equipped_modules = []

	if inv_size <= 0:
		return gs
	var n_weapons := int(round(inv_size * 0.6))
	var n_armor := int(round(inv_size * 0.2))
	var n_modules := inv_size - n_weapons - n_armor
	for i in range(n_weapons):
		gs.owned_weapons.append(i % 7)
	for i in range(n_armor):
		gs.owned_armor.append((i % 3) + 1)
	for i in range(n_modules):
		gs.owned_modules.append(i % 6)
	return gs

func _make_screen(inv_size: int) -> LoadoutScreen:
	var gs := _build_fixture_state(inv_size)
	var screen := LoadoutScreen.new()
	screen.size = Vector2(1280, 720)
	root.add_child(screen)
	screen.setup(gs)
	return screen

func _find_button(screen: LoadoutScreen, prefix: String) -> Button:
	for c in screen.get_children():
		if c is Button and (c as Button).text.begins_with(prefix):
			return c as Button
	return null

func _run_all() -> void:
	_test_ac1_scroll_area_shape()
	_test_ac2_back_button_reachable_across_sizes()
	_test_ac3_continue_button_reachable_across_sizes()
	_test_ac4_scroll_range_grows_with_inventory()
	_test_ac5_signal_contract_preserved()
	_test_ac6_empty_state_no_gap()

# --- AC-1: ScrollContainer exists and is sized correctly ---
func _test_ac1_scroll_area_shape() -> void:
	print("AC-1: ScrollArea exists, bounded, horizontal disabled, follow_focus on")
	var screen := _make_screen(5)
	var scroll := screen.get_node_or_null("ScrollArea") as ScrollContainer
	assert_true(scroll != null, "ScrollArea exists")
	if scroll != null:
		assert_eq(scroll.size.y, 520.0, "ScrollArea.size.y == 520")
		assert_eq(scroll.position.y, 120.0, "ScrollArea.position.y == 120")
		assert_eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED, "horizontal scroll disabled")
		assert_true(scroll.follow_focus, "follow_focus = true")
		var content := scroll.get_node_or_null("Content")
		assert_true(content != null and content is VBoxContainer, "Content VBox exists inside ScrollArea")
	_cleanup(screen)

# --- AC-2: Shop button reachable at inventory = 0, 5, 20, 50 ---
# Structural invariant: footer buttons are direct children of LoadoutScreen
# at pinned y=650, and the ScrollContainer bounded to y=120 + height=520 (i.e.
# bottom edge at y=640) cannot overlap the footer regardless of content size.
# The ScrollContainer clips its children, so any overflow is visually clipped
# and input-shielded away from the footer.
func _test_ac2_back_button_reachable_across_sizes() -> void:
	print("AC-2: ← Shop button reachable and non-overlapped at inv_size ∈ {0,5,20,50}")
	for inv_size in [0, 5, 20, 50]:
		var screen := _make_screen(inv_size)
		var back_btn := _find_button(screen, "← Shop")
		assert_true(back_btn != null, "back_btn present at inv_size=%d" % inv_size)
		if back_btn == null:
			_cleanup(screen)
			continue
		assert_eq(back_btn.position, Vector2(20, 650), "back_btn pinned at (20,650) inv_size=%d" % inv_size)
		var scroll := screen.get_node_or_null("ScrollArea") as ScrollContainer
		assert_true(scroll != null, "ScrollArea exists inv_size=%d" % inv_size)
		if scroll != null:
			var scroll_rect := Rect2(scroll.position, scroll.size)
			var back_rect := Rect2(back_btn.position, back_btn.size)
			assert_true(not scroll_rect.intersects(back_rect), "ScrollArea rect does not overlap back_btn at inv_size=%d (scroll=%s back=%s)" % [inv_size, str(scroll_rect), str(back_rect)])
		_cleanup(screen)

# --- AC-3: Continue button reachable at same inventory sizes ---
func _test_ac3_continue_button_reachable_across_sizes() -> void:
	print("AC-3: Continue → button reachable and non-overlapped at inv_size ∈ {0,5,20,50}")
	for inv_size in [0, 5, 20, 50]:
		var screen := _make_screen(inv_size)
		var cont_btn := _find_button(screen, "Continue")
		assert_true(cont_btn != null, "continue btn present at inv_size=%d" % inv_size)
		if cont_btn == null:
			_cleanup(screen)
			continue
		assert_eq(cont_btn.position, Vector2(1050, 650), "continue pinned at (1050,650) inv_size=%d" % inv_size)
		var scroll := screen.get_node_or_null("ScrollArea") as ScrollContainer
		if scroll != null:
			var scroll_rect := Rect2(scroll.position, scroll.size)
			var cont_rect := Rect2(cont_btn.position, cont_btn.size)
			assert_true(not scroll_rect.intersects(cont_rect), "ScrollArea rect does not overlap continue_btn at inv_size=%d" % inv_size)
		_cleanup(screen)

# --- AC-4: Scroll range grows with inventory ---
# Uses await to let VBox minimum_size propagate through layout before reading
# the v_scroll_bar.max_value. This is the only test that needs a frame.
func _test_ac4_scroll_range_grows_with_inventory() -> void:
	print("AC-4: scroll range > 0 under inventory pressure")
	var screen := _make_screen(50)
	# Allow layout to settle — VBox child min-sizes need a frame to propagate.
	await process_frame
	await process_frame
	var scroll := screen.get_node_or_null("ScrollArea") as ScrollContainer
	assert_true(scroll != null, "ScrollArea exists")
	if scroll != null:
		var v_bar := scroll.get_v_scroll_bar()
		assert_true(v_bar != null, "v_scroll_bar exists")
		if v_bar != null:
			assert_true(v_bar.max_value > 0, "v_scroll_bar.max_value > 0 at inv_size=50 (got %s)" % str(v_bar.max_value))
	_cleanup(screen)

# --- AC-5: Signal contract preserved ---
func _test_ac5_signal_contract_preserved() -> void:
	print("AC-5: back_pressed / continue_pressed signals still emit")
	var screen := _make_screen(5)
	_signal_back_fired = false
	_signal_continue_fired = false
	screen.back_pressed.connect(func(): _signal_back_fired = true)
	screen.continue_pressed.connect(func(): _signal_continue_fired = true)
	var back_btn := _find_button(screen, "← Shop")
	var cont_btn := _find_button(screen, "Continue")
	assert_true(back_btn != null, "back_btn exists for signal test")
	assert_true(cont_btn != null, "cont_btn exists for signal test")
	if back_btn != null:
		back_btn.pressed.emit()
	if cont_btn != null:
		cont_btn.pressed.emit()
	assert_true(_signal_back_fired, "back_pressed signal fired")
	assert_true(_signal_continue_fired, "continue_pressed signal fired")
	_cleanup(screen)

# --- AC-6: Empty-state layout unchanged ---
func _test_ac6_empty_state_no_gap() -> void:
	print("AC-6: empty state — content starts at top, no awkward gap")
	var screen := _make_screen(0)
	var scroll := screen.get_node_or_null("ScrollArea") as ScrollContainer
	assert_true(scroll != null, "ScrollArea exists")
	if scroll != null:
		var content := scroll.get_node_or_null("Content") as VBoxContainer
		assert_true(content != null, "Content VBox exists")
		if content != null:
			assert_true(content.get_child_count() > 0, "Content has children (chassis list minimum)")
			var first := content.get_child(0)
			assert_true(first is Label, "first child is a section Label")
			if first is Label:
				assert_true((first as Label).text.begins_with("CHASSIS"), "first label is CHASSIS header (got '%s')" % (first as Label).text)
	_cleanup(screen)
