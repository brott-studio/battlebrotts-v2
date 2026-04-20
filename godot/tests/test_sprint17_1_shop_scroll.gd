## Sprint 17.1-001 — Shop scroll position preservation
## Usage: godot --headless --script tests/test_sprint17_1_shop_scroll.gd
## Design: docs/design/s17.1-001-shop-scroll.md
## Covers (per design §6):
##   AC-1 — scroll-to-middle → click item → scroll preserved
##   AC-2 — scroll preserved on collapse
##   AC-3 — scroll preserved across buy
##   AC-4 — initial build starts at 0
##   AC-5 — defensive max-clamp on absurd restore value
extends SceneTree

const SCROLL_TOLERANCE := 2  # px tolerance for int/float rounding

var pass_count := 0
var fail_count := 0
var test_count := 0

func _initialize() -> void:
	print("=== Sprint 17.1-001 Shop Scroll Tests ===\n")
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

func assert_near(a: int, b: int, tol: int, msg: String) -> void:
	test_count += 1
	if abs(a - b) <= tol:
		pass_count += 1
	else:
		fail_count += 1
		print("  FAIL: %s (got %d, expected ~%d ± %d)" % [msg, a, b, tol])

func _cleanup() -> void:
	for c in root.get_children():
		if c is ShopScreen:
			root.remove_child(c)
			c.free()

func _make_shop(bolts: int = 9999) -> ShopScreen:
	_cleanup()
	ShopScreen._seen_shop_items = {}
	var gs := GameState.new()
	gs.bolts = bolts
	var shop := ShopScreen.new()
	root.add_child(shop)
	shop.setup_for_viewport(gs, 1280)
	return shop

func _scroll(shop: ShopScreen) -> ScrollContainer:
	return shop.get_node_or_null("ScrollArea") as ScrollContainer

func _find_first_unowned_card(shop: ShopScreen) -> Button:
	var cards := shop.find_children("Card_*", "Button", true, false)
	for c in cards:
		if c is Button and not c.get_meta("owned"):
			return c as Button
	return null

func _find_buy_button(shop: ShopScreen) -> Button:
	var nodes := shop.find_children("BuyButton", "Button", true, false)
	if nodes.size() > 0:
		return nodes[0] as Button
	return null

## Drain two idle frames so call_deferred("_restore_scroll") fires and any
## subsequent layout ticks settle.
func _drain_deferred(shop: ShopScreen) -> void:
	# In --script SceneTree mode the main loop doesn't pump on its own. We
	# flush pending deferred calls manually via MessageQueue, then force two
	# process_frame ticks so ScrollContainer clamps against finalized layout.
	await process_frame
	await process_frame

func _run_all() -> void:
	_test_ac4_initial_build_starts_at_zero()
	_test_ac1_scroll_preserved_on_card_tap()
	_test_ac2_scroll_preserved_on_collapse()
	_test_ac3_scroll_preserved_across_buy()
	_test_ac5_defensive_clamp()

# --- AC-4: initial build starts at 0 ---
func _test_ac4_initial_build_starts_at_zero() -> void:
	print("AC-4: initial _build_ui starts with scroll_vertical = 0")
	var shop := _make_shop()
	var s := _scroll(shop)
	assert_true(s != null, "ScrollArea exists after first build")
	if s != null:
		assert_eq(s.scroll_vertical, 0, "initial scroll_vertical is 0")
	_cleanup()

# --- AC-1: card tap preserves scroll ---
func _test_ac1_scroll_preserved_on_card_tap() -> void:
	print("AC-1: scroll-to-middle → click card → scroll preserved")
	var shop := _make_shop()
	var s := _scroll(shop)
	assert_true(s != null, "ScrollArea exists")
	if s == null:
		_cleanup()
		return
	# Force content tall enough that scroll has room (VBox min size drives max scroll).
	s.scroll_vertical = 400
	var before := s.scroll_vertical
	assert_true(before > 0, "set a non-zero scroll baseline (got %d)" % before)

	var card := _find_first_unowned_card(shop)
	assert_true(card != null, "found an unowned card")
	if card == null:
		_cleanup()
		return
	card.pressed.emit()

	# Drain deferred + one extra frame for layout settle.
	await process_frame
	await process_frame

	var s2 := _scroll(shop)
	assert_true(s2 != null, "ScrollArea exists after rebuild")
	if s2 != null:
		assert_near(s2.scroll_vertical, before, SCROLL_TOLERANCE, "scroll preserved across card tap")
	_cleanup()

# --- AC-2: collapse preserves scroll ---
func _test_ac2_scroll_preserved_on_collapse() -> void:
	print("AC-2: scroll preserved on collapse")
	var shop := _make_shop()
	var card := _find_first_unowned_card(shop)
	assert_true(card != null, "found an unowned card to expand")
	if card == null:
		_cleanup()
		return
	# Expand
	card.pressed.emit()
	await process_frame
	await process_frame
	var s := _scroll(shop)
	if s == null:
		assert_true(false, "no scroll area after expand")
		_cleanup()
		return
	s.scroll_vertical = 400
	var before := s.scroll_vertical

	# Collapse by re-pressing the same card (find by key since it was rebuilt).
	var card2 := _find_first_unowned_card(shop)
	if card2 != null:
		card2.pressed.emit()
	await process_frame
	await process_frame

	var s2 := _scroll(shop)
	if s2 != null:
		assert_near(s2.scroll_vertical, before, SCROLL_TOLERANCE, "scroll preserved across collapse")
	_cleanup()

# --- AC-3: buy preserves scroll ---
func _test_ac3_scroll_preserved_across_buy() -> void:
	print("AC-3: scroll preserved across buy")
	var shop := _make_shop(99999)
	var card := _find_first_unowned_card(shop)
	assert_true(card != null, "found an unowned card to buy")
	if card == null:
		_cleanup()
		return
	# Expand the card so BuyButton exists.
	card.pressed.emit()
	await process_frame
	await process_frame

	var s := _scroll(shop)
	if s == null:
		assert_true(false, "no scroll area after expand")
		_cleanup()
		return
	s.scroll_vertical = 300
	var before := s.scroll_vertical

	var bb := _find_buy_button(shop)
	assert_true(bb != null, "BuyButton exists after expand")
	if bb == null:
		_cleanup()
		return
	bb.pressed.emit()
	await process_frame
	await process_frame

	var s2 := _scroll(shop)
	if s2 != null:
		assert_near(s2.scroll_vertical, before, SCROLL_TOLERANCE, "scroll preserved across buy")
	# Sanity: card is now owned (buy path not regressed).
	var owned_any := false
	for c in shop.find_children("Card_*", "Button", true, false):
		if c is Button and c.get_meta("owned"):
			owned_any = true
			break
	assert_true(owned_any, "at least one card now owned after buy")
	_cleanup()

# --- AC-5: defensive clamp on absurd restore value ---
func _test_ac5_defensive_clamp() -> void:
	print("AC-5: _restore_scroll clamps absurd values safely")
	var shop := _make_shop()
	shop._saved_scroll_v = 999999
	shop._restore_scroll()
	var s := _scroll(shop)
	assert_true(s != null, "ScrollArea exists")
	if s != null:
		var max_v := int(s.get_v_scroll_bar().max_value)
		assert_true(s.scroll_vertical >= 0, "scroll_vertical >= 0 after absurd restore")
		assert_true(s.scroll_vertical <= max_v, "scroll_vertical <= max (%d <= %d)" % [s.scroll_vertical, max_v])
	_cleanup()
