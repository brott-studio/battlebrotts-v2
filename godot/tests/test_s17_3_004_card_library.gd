## Sprint 17.3-004 — Card-library curation roster compliance.
## Usage: godot --headless --script tests/test_s17_3_004_card_library.gd
## Spec: sprints/sprint-17.3.md §"Task specs" → "S17.3-004" AND
##       §"Card-library roster diff (Gizmo canon — Nutts implements verbatim)"
##
## Covers (acceptance for S17.3-004):
##   - TRIGGER_DISPLAY shown count == 11 (12 entries minus 1 hidden).
##   - ACTION_DISPLAY shown count  == 7  (8 entries minus 1 hidden).
##   - Hidden enums WHEN_CLOCK_SAYS + GET_TO_COVER still exist (save-compat).
##   - Hidden enums still have display entries (indexed lookup doesn't crash
##     on load of existing saves that reference those cards).
##   - New enums WHEN_THEYRE_RUNNING, WHEN_I_JUST_HIT_THEM, CHASE_TARGET,
##     FOCUS_WEAKEST exist and have display entries.
##   - WHEN_LOW_ENERGY label reworded "Low on Juice" → "Low on Energy".
##   - Selected-row overlay uses Color(0.3, 0.6, 1.0, 0.3) for selected row
##     and Color(1, 1, 1, 0.01) for non-selected rows.
##
## Strategy: load the display-dict consts via preload and inspect them as
## plain data. Selected-row overlay is checked against a live rebuilt UI.
extends SceneTree

const BrottBrainScreenRef = preload("res://ui/brottbrain_screen.gd")

var pass_count := 0
var fail_count := 0
var test_count := 0

func _initialize() -> void:
	print("=== S17.3-004 Card Library Curation Tests ===\n")
	_test_trigger_display_shown_count_is_11()
	_test_action_display_shown_count_is_7()
	_test_hidden_trigger_enums_exist()
	_test_hidden_action_enums_exist()
	_test_hidden_trigger_entries_retained_for_save_compat()
	_test_hidden_action_entries_retained_for_save_compat()
	_test_new_trigger_enums_have_display_entries()
	_test_new_action_enums_have_display_entries()
	_test_when_low_energy_reworded()
	_test_selected_row_overlay_color_when_selected()
	_test_selected_row_overlay_color_when_not_selected()
	print("\n=== Results: %d passed, %d failed, %d total ===" % [pass_count, fail_count, test_count])
	quit(1 if fail_count > 0 else 0)

func _assert(cond: bool, msg: String) -> void:
	test_count += 1
	if cond:
		pass_count += 1
	else:
		fail_count += 1
		print("  FAIL: %s" % msg)

# --- shown-count tests ---

func _test_trigger_display_shown_count_is_11() -> void:
	var total: int = BrottBrainScreenRef.TRIGGER_DISPLAY.size()
	var hidden: int = BrottBrainScreenRef.HIDDEN_TRIGGERS.size()
	var shown: int = total - hidden
	_assert(shown == 11,
		"TRIGGER_DISPLAY shown count: expected 11 (per roster diff), got %d (total=%d, hidden=%d)" % [shown, total, hidden])

func _test_action_display_shown_count_is_7() -> void:
	var total: int = BrottBrainScreenRef.ACTION_DISPLAY.size()
	var hidden: int = BrottBrainScreenRef.HIDDEN_ACTIONS.size()
	var shown: int = total - hidden
	_assert(shown == 7,
		"ACTION_DISPLAY shown count: expected 7 (per roster diff), got %d (total=%d, hidden=%d)" % [shown, total, hidden])

# --- save-compat: enum values still exist and are in the hidden list ---

func _test_hidden_trigger_enums_exist() -> void:
	# Must be reachable via BrottBrain.Trigger and present in HIDDEN_TRIGGERS.
	var clock_enum: int = BrottBrain.Trigger.WHEN_CLOCK_SAYS
	_assert(clock_enum >= 0, "BrottBrain.Trigger.WHEN_CLOCK_SAYS enum still defined")
	_assert(clock_enum in BrottBrainScreenRef.HIDDEN_TRIGGERS,
		"WHEN_CLOCK_SAYS is listed in HIDDEN_TRIGGERS (tray-hidden, save-compat kept)")

func _test_hidden_action_enums_exist() -> void:
	var cover_enum: int = BrottBrain.Action.GET_TO_COVER
	_assert(cover_enum >= 0, "BrottBrain.Action.GET_TO_COVER enum still defined")
	_assert(cover_enum in BrottBrainScreenRef.HIDDEN_ACTIONS,
		"GET_TO_COVER is listed in HIDDEN_ACTIONS (tray-hidden, save-compat kept)")

# --- save-compat: hidden enums still have display entries so indexed lookup doesn't crash ---

func _test_hidden_trigger_entries_retained_for_save_compat() -> void:
	# TRIGGER_DISPLAY is indexed by enum ordinal in brottbrain_screen.gd
	# (e.g., `TRIGGER_DISPLAY[card.trigger]`). Removing entries would misalign
	# indices for saves referencing hidden cards.
	var clock_idx: int = BrottBrain.Trigger.WHEN_CLOCK_SAYS
	_assert(clock_idx < BrottBrainScreenRef.TRIGGER_DISPLAY.size(),
		"TRIGGER_DISPLAY has an entry at WHEN_CLOCK_SAYS's index (save-compat)")

func _test_hidden_action_entries_retained_for_save_compat() -> void:
	var cover_idx: int = BrottBrain.Action.GET_TO_COVER
	_assert(cover_idx < BrottBrainScreenRef.ACTION_DISPLAY.size(),
		"ACTION_DISPLAY has an entry at GET_TO_COVER's index (save-compat)")

# --- new enums present and in display dicts ---

func _test_new_trigger_enums_have_display_entries() -> void:
	var running: int = BrottBrain.Trigger.WHEN_THEYRE_RUNNING
	var just_hit: int = BrottBrain.Trigger.WHEN_I_JUST_HIT_THEM
	_assert(running < BrottBrainScreenRef.TRIGGER_DISPLAY.size(),
		"WHEN_THEYRE_RUNNING has a TRIGGER_DISPLAY entry")
	_assert(just_hit < BrottBrainScreenRef.TRIGGER_DISPLAY.size(),
		"WHEN_I_JUST_HIT_THEM has a TRIGGER_DISPLAY entry")
	# And not hidden (must appear in tray).
	_assert(not (running in BrottBrainScreenRef.HIDDEN_TRIGGERS),
		"WHEN_THEYRE_RUNNING is NOT hidden (new, shown in tray)")
	_assert(not (just_hit in BrottBrainScreenRef.HIDDEN_TRIGGERS),
		"WHEN_I_JUST_HIT_THEM is NOT hidden (new, shown in tray)")

func _test_new_action_enums_have_display_entries() -> void:
	var chase: int = BrottBrain.Action.CHASE_TARGET
	var weakest: int = BrottBrain.Action.FOCUS_WEAKEST
	_assert(chase < BrottBrainScreenRef.ACTION_DISPLAY.size(),
		"CHASE_TARGET has an ACTION_DISPLAY entry")
	_assert(weakest < BrottBrainScreenRef.ACTION_DISPLAY.size(),
		"FOCUS_WEAKEST has an ACTION_DISPLAY entry")
	_assert(not (chase in BrottBrainScreenRef.HIDDEN_ACTIONS),
		"CHASE_TARGET is NOT hidden (new, shown in tray)")
	_assert(not (weakest in BrottBrainScreenRef.HIDDEN_ACTIONS),
		"FOCUS_WEAKEST is NOT hidden (new, shown in tray)")

# --- label rewording ---

func _test_when_low_energy_reworded() -> void:
	var idx: int = BrottBrain.Trigger.WHEN_LOW_ENERGY
	var entry: Array = BrottBrainScreenRef.TRIGGER_DISPLAY[idx]
	var label: String = str(entry[1])
	_assert(label == "When I'm Low on Energy",
		'WHEN_LOW_ENERGY label is "When I\'m Low on Energy", got "%s"' % label)
	_assert(not label.contains("Juice"),
		'WHEN_LOW_ENERGY label must not contain "Juice" (reworded per S17.1-004 bar copy)')

# --- selected-row overlay ---

func _mk_screen_with_cards(card_count: int, selected: int = -1) -> BrottBrainScreen:
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
	# Set selection BEFORE setup() so the initial _build_ui() uses it.
	# (setup()/\_build_ui() uses queue_free for rebuilds, which is deferred;
	# calling _build_ui() mid-test leaves stale children in the tree until
	# the next frame, so we avoid that pattern.)
	screen.selected_card_index = selected
	screen.setup(gs, brain)
	return screen

# Find the N-th select overlay button (full-row, flat, empty text) drawn by _draw_card.
# _draw_card order per row: panel, num_lbl, trig_lbl, arrow, act_lbl, hint, del_btn, select_btn.
# So the select overlays are the flat empty-text buttons sized 590x50.
# Note: _build_ui() uses queue_free() (deferred) when rebuilding, so after a
# mid-test rebuild the old children are still reachable until the next frame.
# We filter out queued-for-deletion nodes to see only the current UI.
func _find_select_overlays(screen: BrottBrainScreen) -> Array:
	var out: Array = []
	for child in screen.get_children():
		if child is Button and not child.is_queued_for_deletion():
			var btn: Button = child
			if btn.flat and btn.text == "" and int(btn.size.x) == 590 and int(btn.size.y) == 50:
				out.append(btn)
	return out

func _test_selected_row_overlay_color_when_selected() -> void:
	var screen := _mk_screen_with_cards(3, 1)
	var overlays: Array = _find_select_overlays(screen)
	_assert(overlays.size() == 3, "Found 3 select overlays (one per card), got %d" % overlays.size())
	if overlays.size() == 3:
		var selected_btn: Button = overlays[1]
		var expected := Color(0.3, 0.6, 1.0, 0.3)
		_assert(selected_btn.modulate.is_equal_approx(expected),
			"Selected row (index 1) modulate == Color(0.3, 0.6, 1.0, 0.3), got %s" % str(selected_btn.modulate))
	screen.queue_free()

func _test_selected_row_overlay_color_when_not_selected() -> void:
	var screen := _mk_screen_with_cards(3, 1)
	var overlays: Array = _find_select_overlays(screen)
	if overlays.size() == 3:
		var non_selected_btn: Button = overlays[0]
		var expected := Color(1, 1, 1, 0.01)
		_assert(non_selected_btn.modulate.is_equal_approx(expected),
			"Non-selected row modulate == Color(1, 1, 1, 0.01), got %s" % str(non_selected_btn.modulate))
	screen.queue_free()
