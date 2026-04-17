## Sprint 14.2-A — BrottBrain UI polish tests.
## Usage: godot --headless --script tests/test_sprint14_2_ui.gd
## Spec: docs/design/sprint14.2-brottbrain-aggression.md §2 (AC1–AC5)
extends SceneTree

var pass_count := 0
var fail_count := 0
var test_count := 0

func _initialize() -> void:
	print("=== Sprint 14.2-A BrottBrain UI Polish Tests ===\n")
	_test_ac1_selected_row_has_distinct_modulate()
	_test_ac1_unselected_rows_remain_default()
	_test_ac2_reorder_buttons_disabled_without_selection()
	_test_ac2_up_disabled_at_top_down_disabled_at_bottom()
	_test_ac2_both_enabled_in_the_middle()
	_test_ac3_delete_button_distinct_and_separated_from_select()
	_test_ac3_delete_clears_selection_of_removed_row()
	_test_ac4_tray_does_not_overlap_card_list_at_8_cards()
	_test_ac5_tutorial_copy_matches_button_reorder_model()
	print("\n=== Results: %d passed, %d failed, %d total ===" % [pass_count, fail_count, test_count])
	quit(1 if fail_count > 0 else 0)

func _assert(cond: bool, msg: String) -> void:
	test_count += 1
	if cond: pass_count += 1
	else:
		fail_count += 1
		print("  FAIL: %s" % msg)

# --- helpers ---

func _mk_screen(card_count: int) -> BrottBrainScreen:
	var gs := GameState.new()
	gs.equipped_chassis = ChassisData.ChassisType.BRAWLER
	gs.equipped_modules = []
	var brain := BrottBrain.default_for_chassis(gs.equipped_chassis)
	# Pad or trim to exactly `card_count` cards so tests can drive a known state.
	while brain.cards.size() < card_count and brain.cards.size() < BrottBrain.MAX_CARDS:
		brain.cards.append(BrottBrain.BehaviorCard.new(0, 0.4, 0, 0))
	while brain.cards.size() > card_count:
		brain.cards.pop_back()
	var screen := BrottBrainScreen.new()
	screen.size = Vector2(1280, 720)
	root.add_child(screen)
	# Tutorial overlay would clutter child list; pretend it's already dismissed.
	screen.tutorial_dismissed = true
	screen.setup(gs, brain)
	return screen

# Find all Panel children whose meta "card_index" is set — these are card row panels.
func _card_panels(screen: BrottBrainScreen) -> Array:
	var out := []
	for c in screen.get_children():
		if c is Panel and c.has_meta("card_index"):
			out.append(c)
	return out

# Find all Button children whose text starts with "✕" — delete buttons.
func _delete_buttons(screen: BrottBrainScreen) -> Array:
	var out := []
	for c in screen.get_children():
		if c is Button and c.text == "✕":
			out.append(c)
	return out

# Find select overlays (flat buttons with "select_for_index" meta).
func _select_overlays(screen: BrottBrainScreen) -> Array:
	var out := []
	for c in screen.get_children():
		if c is Button and c.has_meta("select_for_index"):
			out.append(c)
	return out

# All tray-related controls: the tray header, WHEN/THEN labels, and every
# trigger/action button. We identify by Y position (anything at or below the
# tray origin that isn't a card row or the nav bar).
func _tray_controls(screen: BrottBrainScreen) -> Array:
	var out := []
	for c in screen.get_children():
		if not (c is Control): continue
		if c is Panel and c.has_meta("card_index"): continue
		# Skip navigation buttons (Back / Fight!) which live far below the tray.
		if c is Button:
			var t: String = c.text
			if t.begins_with("← ") or t.begins_with("Fight!"): continue
		# Skip ▲/▼ reorder buttons — those live alongside the card list, not the tray.
			if t == "▲ Up" or t == "▼ Down": continue
		if c.position.y >= BrottBrainScreen.TRAY_TOP - 1:
			out.append(c)
	return out

func _rect_of(ctrl: Control) -> Rect2:
	return Rect2(ctrl.position, ctrl.size)

# --- tests ---

func _test_ac1_selected_row_has_distinct_modulate() -> void:
	var screen := _mk_screen(4)
	screen._select_card(2)
	var panels := _card_panels(screen)
	_assert(panels.size() == 4, "AC1 four card panels rendered (got %d)" % panels.size())
	var selected: Panel = null
	for p in panels:
		if p.get_meta("card_index") == 2: selected = p; break
	_assert(selected != null, "AC1 panel with card_index=2 exists")
	if selected != null:
		var m: Color = selected.modulate
		# Distinct from default (1,1,1,1) — we tint blue-ish; any of R/G/B below 0.95 counts.
		_assert(m != Color(1, 1, 1, 1), "AC1 selected panel modulate is non-default (got %s)" % str(m))
		_assert(m.b > m.r, "AC1 selected panel has a blue-ish tint (r=%.2f b=%.2f)" % [m.r, m.b])
	screen.queue_free()

func _test_ac1_unselected_rows_remain_default() -> void:
	var screen := _mk_screen(3)
	screen._select_card(0)
	for p in _card_panels(screen):
		if p.get_meta("card_index") != 0:
			_assert(p.modulate == Color(1, 1, 1, 1),
				"AC1 non-selected panel index %d retains default modulate" % p.get_meta("card_index"))
	screen.queue_free()

func _test_ac2_reorder_buttons_disabled_without_selection() -> void:
	var screen := _mk_screen(3)
	# Default state — no selection.
	_assert(screen.selected_card_index == -1, "AC2 initial selection is -1")
	_assert(screen._move_up_btn.disabled, "AC2 ▲ Up disabled when nothing selected")
	_assert(screen._move_down_btn.disabled, "AC2 ▼ Down disabled when nothing selected")
	screen.queue_free()

func _test_ac2_up_disabled_at_top_down_disabled_at_bottom() -> void:
	var screen := _mk_screen(4)
	screen._select_card(0)
	_assert(screen._move_up_btn.disabled, "AC2 ▲ Up disabled at top row (idx 0)")
	_assert(not screen._move_down_btn.disabled, "AC2 ▼ Down enabled at top row")
	screen._select_card(3)
	_assert(not screen._move_up_btn.disabled, "AC2 ▲ Up enabled at bottom row")
	_assert(screen._move_down_btn.disabled, "AC2 ▼ Down disabled at bottom row (idx 3)")
	screen.queue_free()

func _test_ac2_both_enabled_in_the_middle() -> void:
	var screen := _mk_screen(5)
	screen._select_card(2)
	_assert(not screen._move_up_btn.disabled, "AC2 ▲ Up enabled mid-list")
	_assert(not screen._move_down_btn.disabled, "AC2 ▼ Down enabled mid-list")
	screen.queue_free()

func _test_ac3_delete_button_distinct_and_separated_from_select() -> void:
	var screen := _mk_screen(3)
	var dels := _delete_buttons(screen)
	var sels := _select_overlays(screen)
	_assert(dels.size() == 3, "AC3 three delete buttons (got %d)" % dels.size())
	_assert(sels.size() == 3, "AC3 three select overlays (got %d)" % sels.size())
	# Distinct visual: red tint (R > G and R > B).
	var d: Button = dels[0]
	_assert(d.modulate.r > d.modulate.g and d.modulate.r > d.modulate.b,
		"AC3 delete button has red-ish tint (modulate=%s)" % str(d.modulate))
	# Wider hit area than the stock 35x28.
	_assert(d.size.x >= 40 and d.size.y >= 30,
		"AC3 delete button has wider hit area (size=%s)" % str(d.size))
	# Non-overlapping hit regions: the select overlay for the same row must stop
	# before the delete button's x starts — clicking ✕ should never land on select.
	for i in range(3):
		var del_for_i: Button = null
		for b in dels:
			var row_y: float = b.position.y
			# Delete button y sits at (card_y + 3); find its row by position ordering.
			if int(row_y) == int(i) * BrottBrainScreen.CARD_ROW_HEIGHT + BrottBrainScreen.CARD_LIST_TOP + 3:
				del_for_i = b; break
		var sel_for_i: Button = null
		for s in sels:
			if s.get_meta("select_for_index") == i: sel_for_i = s; break
		if del_for_i == null or sel_for_i == null: continue
		var sel_right := sel_for_i.position.x + sel_for_i.size.x
		_assert(sel_right <= del_for_i.position.x,
			"AC3 select overlay (right=%d) does not reach delete button (left=%d) for row %d"
				% [int(sel_right), int(del_for_i.position.x), i])
	screen.queue_free()

func _test_ac3_delete_clears_selection_of_removed_row() -> void:
	var screen := _mk_screen(4)
	screen._select_card(2)
	_assert(screen.selected_card_index == 2, "AC3 pre: idx 2 selected")
	screen._remove_card(2)
	# After removal the same numeric index would land on a different logical card.
	# Deletion should clear selection rather than silently slide it.
	_assert(screen.selected_card_index == -1,
		"AC3 delete of selected row clears selection (got %d)" % screen.selected_card_index)
	_assert(screen.brain.cards.size() == 3, "AC3 card count decremented to 3")
	screen.queue_free()

func _test_ac4_tray_does_not_overlap_card_list_at_8_cards() -> void:
	var screen := _mk_screen(8)
	var panels := _card_panels(screen)
	_assert(panels.size() == 8, "AC4 eight card rows rendered (got %d)" % panels.size())
	var card_rects: Array = []
	for p in panels: card_rects.append(_rect_of(p))
	var tray := _tray_controls(screen)
	_assert(tray.size() >= 10, "AC4 tray rendered (got %d controls)" % tray.size())
	var overlaps := 0
	for t in tray:
		var tr := _rect_of(t)
		for cr in card_rects:
			if tr.intersects(cr):
				overlaps += 1
				print("  AC4 overlap: tray '%s' rect=%s vs card rect=%s" % [
					(t.text if (t is Button or t is Label) else "?"), str(tr), str(cr)])
	_assert(overlaps == 0, "AC4 no tray/card overlaps at 8 cards (found %d)" % overlaps)
	screen.queue_free()

func _test_ac5_tutorial_copy_matches_button_reorder_model() -> void:
	# Source the tutorial copy from _show_tutorial() by invoking it and scanning labels.
	var screen := _mk_screen(0)
	# tutorial_dismissed was set true, so _build_ui skipped it — call directly.
	screen._show_tutorial()
	var matched := false
	for c in screen.get_children():
		if c is Label:
			var t: String = c.text
			# Must mention button-based reorder (▲/▼) or ✕ removal — not drag.
			if t.contains("▲") or t.contains("▼") or t.contains("✕"):
				matched = true
				_assert(not t.to_lower().contains("drag"),
					"AC5 tutorial copy doesn't claim drag (got: %s)" % t)
	_assert(matched, "AC5 tutorial mentions ▲/▼/✕ button-reorder controls")
	screen.queue_free()
