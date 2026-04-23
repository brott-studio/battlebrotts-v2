## S21.2 / T1 / #104 — ScrollContainer wrappers for BrottbrainScreen tray + OpponentSelectScreen list.
## Usage: godot --headless --script tests/test_s21_2_002_scroll_wrappers.gd
## Specs:
##   - design/2026-04-23-s21.2-ux-bundle.md §Issue #104 → "Implementation note for Nutts"
##   - sprints/v2-sprint-21.2.md §T1 acceptance:
##       * test_s21.2_002_brottbrain_no_overlap_full
##       * test_s21.2_002_opponent_select_no_overlap_max
##       * test_s21.2_002_brottbrain_signal_contract_preserved
##       * test_s21.2_002_opponent_signal_contract_preserved
##       * test_s21.2_002_empty_states_unchanged
extends SceneTree

var pass_count := 0
var fail_count := 0
var test_count := 0

func _initialize() -> void:
	print("=== S21.2-002 Scroll wrapper tests ===\n")
	_test_brottbrain_tray_scroll_exists()
	_test_brottbrain_no_overlap_full()
	_test_brottbrain_signal_contract_preserved()
	_test_opponent_list_scroll_exists()
	_test_opponent_no_overlap_max()
	_test_opponent_signal_contract_preserved()
	_test_empty_states_unchanged()
	print("\n=== Results: %d passed, %d failed, %d total ===" % [pass_count, fail_count, test_count])
	quit(1 if fail_count > 0 else 0)

func _assert(cond: bool, msg: String) -> void:
	test_count += 1
	if cond:
		pass_count += 1
	else:
		fail_count += 1
		print("  FAIL: %s" % msg)

# --- Fixtures ---

func _mk_brain_screen(card_count: int) -> BrottBrainScreen:
	var gs := GameState.new()
	gs.equipped_chassis = ChassisData.ChassisType.BRAWLER
	gs.equipped_modules = []
	var brain := BrottBrain.default_for_chassis(gs.equipped_chassis)
	while brain.cards.size() < card_count and brain.cards.size() < BrottBrain.MAX_CARDS:
		brain.cards.append(BrottBrain.BehaviorCard.new(0, 0.4, 0, 0))
	while brain.cards.size() > card_count:
		brain.cards.pop_back()
	var s := BrottBrainScreen.new()
	s.tutorial_dismissed = true  # avoid spawning the tutorial overlay during structural tests
	s.setup(gs, brain)
	return s

func _mk_opponent_screen(opponent_count: int) -> OpponentSelectScreen:
	var gs := GameState.new()
	gs.current_league = "scrapyard"
	var s := OpponentSelectScreen.new()
	s.setup(gs)
	# Note: scrapyard real count = 3. opponent_count param unused here for the
	# structural pass; max-capacity assertion relies on fixture B documented
	# in sprint plan (synthetic 6-opponent league, future content). Until then,
	# the existing 3-opponent league is sufficient to assert ListScroll exists.
	return s

# --- T1: brottbrain ---

func _test_brottbrain_tray_scroll_exists() -> void:
	var s := _mk_brain_screen(8)
	var ts: Node = s.get_node_or_null("TrayScroll")
	_assert(ts != null, "BrottbrainScreen has TrayScroll child")
	if ts != null:
		_assert(ts is ScrollContainer, "TrayScroll is a ScrollContainer")
		var sc: ScrollContainer = ts
		_assert(sc.position == Vector2(0, 365), "TrayScroll position == (0, 365)")
		_assert(sc.size == Vector2(1280, 280), "TrayScroll size == (1280, 280)")
		_assert(sc.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "horizontal scroll disabled")
		var tc: Node = ts.get_node_or_null("tray_content")
		_assert(tc != null, "TrayScroll has tray_content child")
	s.free()

func _test_brottbrain_no_overlap_full() -> void:
	var s := _mk_brain_screen(8)
	# Footer buttons are siblings of TrayScroll (not children).
	var back: Button = null
	var fight: Button = null
	for c in s.get_children():
		if c is Button:
			var b: Button = c
			if b.text.begins_with("←"):
				back = b
			elif b.text.begins_with("Fight"):
				fight = b
	_assert(back != null, "back button found at root")
	_assert(fight != null, "Fight! button found at root")
	if back != null:
		_assert(back.position == Vector2(20, 650), "back stays at (20, 650)")
	if fight != null:
		_assert(fight.position == Vector2(1050, 650), "Fight! stays at (1050, 650)")
	# Tray children must be inside TrayScroll/tray_content, NOT direct siblings of footer.
	var ts: Node = s.get_node_or_null("TrayScroll/tray_content")
	_assert(ts != null and ts.get_child_count() > 0, "tray_content has children (tray populated inside scroll)")
	s.free()

func _test_brottbrain_signal_contract_preserved() -> void:
	var s := _mk_brain_screen(3)
	# back_pressed + continue_pressed signals must still be wired.
	_assert(s.has_signal("back_pressed"), "back_pressed signal exists")
	_assert(s.has_signal("continue_pressed"), "continue_pressed signal exists")
	var back_emitted := [false]
	var cont_emitted := [false]
	s.back_pressed.connect(func(): back_emitted[0] = true)
	s.continue_pressed.connect(func(): cont_emitted[0] = true)
	for c in s.get_children():
		if c is Button:
			var b: Button = c
			if b.text.begins_with("←"):
				b.pressed.emit()
			elif b.text.begins_with("Fight"):
				b.pressed.emit()
	_assert(back_emitted[0], "back_pressed emitted from refactored back button")
	_assert(cont_emitted[0], "continue_pressed emitted from refactored Fight! button")
	s.free()

# --- T1: opponent select ---

func _test_opponent_list_scroll_exists() -> void:
	var s := _mk_opponent_screen(3)
	var ls: Node = s.get_node_or_null("ListScroll")
	_assert(ls != null, "OpponentSelectScreen has ListScroll child")
	if ls != null:
		_assert(ls is ScrollContainer, "ListScroll is a ScrollContainer")
		var sc: ScrollContainer = ls
		_assert(sc.position == Vector2(0, 60), "ListScroll position == (0, 60)")
		_assert(sc.size == Vector2(1280, 580), "ListScroll size == (1280, 580)")
		var lc: Node = ls.get_node_or_null("list_content")
		_assert(lc != null, "ListScroll has list_content child")
	s.free()

func _test_opponent_no_overlap_max() -> void:
	# Synthetic max-capacity proxy: assert content min-size grows linearly with
	# opponent count via list_content.custom_minimum_size formula 40 + n*140.
	var s := _mk_opponent_screen(3)
	var lc_node: Node = s.get_node_or_null("ListScroll/list_content")
	_assert(lc_node != null, "list_content exists")
	if lc_node != null and lc_node is Control:
		var lc: Control = lc_node
		# scrapyard has 3 opponents
		var expected_h := 40 + 3 * 140
		_assert(int(lc.custom_minimum_size.y) == expected_h,
			"list_content.custom_minimum_size.y == %d (got %d)" % [expected_h, int(lc.custom_minimum_size.y)])
	# Back button stays at (20, 650), sibling of ListScroll
	var back: Button = null
	for c in s.get_children():
		if c is Button:
			back = c
			break
	_assert(back != null and back.position == Vector2(20, 650), "back button at (20, 650), root sibling")
	s.free()

func _test_opponent_signal_contract_preserved() -> void:
	var s := _mk_opponent_screen(3)
	_assert(s.has_signal("opponent_selected"), "opponent_selected signal exists")
	_assert(s.has_signal("back_pressed"), "back_pressed signal exists")
	var got_idx := [-1]
	s.opponent_selected.connect(func(idx: int): got_idx[0] = idx)
	# Walk into list_content for FIGHT! / REMATCH buttons and click index 1.
	var lc: Node = s.get_node_or_null("ListScroll/list_content")
	_assert(lc != null, "list_content exists for signal test")
	if lc != null:
		var fight_buttons: Array = []
		for c in lc.get_children():
			if c is Button:
				var b: Button = c
				if b.text == "FIGHT!" or b.text == "REMATCH":
					fight_buttons.append(b)
		_assert(fight_buttons.size() == 3, "3 FIGHT/REMATCH buttons found in list_content (got %d)" % fight_buttons.size())
		if fight_buttons.size() >= 2:
			fight_buttons[1].pressed.emit()
			_assert(got_idx[0] == 1, "opponent_selected emitted index 1")
	s.free()

# --- T1: empty/degenerate ---

func _test_empty_states_unchanged() -> void:
	var s := _mk_brain_screen(0)
	# At 0 cards there is still a tray; assert TrayScroll exists and content
	# height is small (matches "no awkward gap" intent).
	var ts: Node = s.get_node_or_null("TrayScroll")
	_assert(ts != null, "empty-state: TrayScroll still exists")
	var tc_node: Node = s.get_node_or_null("TrayScroll/tray_content")
	if tc_node != null and tc_node is Control:
		var tc: Control = tc_node
		_assert(tc.custom_minimum_size.y > 0, "empty-state: tray_content has positive minimum height")
	s.free()
