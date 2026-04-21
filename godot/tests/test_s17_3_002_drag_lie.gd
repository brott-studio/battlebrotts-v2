## Sprint 17.3-002 — Drag-lie fix (option A)
## Usage: godot --headless --script tests/test_s17_3_002_drag_lie.gd
## Spec: sprints/sprint-17.3.md §"Task specs" → "S17.3-002"
##
## Covers:
##   AC-1 — Empty-slot prompt text constant contains no "drag" (case-insensitive).
##   AC-2 — Empty-slot prompt uses click/tap copy.
##
## Doc-comment removal of "drag-to-reorder" is verified by file inspection
## (see commit diff); this test covers the runtime-visible string seam.
extends SceneTree

const BrottBrainScreenRef = preload("res://ui/brottbrain_screen.gd")

var pass_count := 0
var fail_count := 0
var test_count := 0

func _initialize() -> void:
	print("=== S17.3-002 Drag-Lie Fix Tests ===\n")
	_test_empty_slot_text_has_no_drag()
	_test_empty_slot_text_uses_tap_copy()
	print("\n=== Results: %d passed, %d failed, %d total ===" % [pass_count, fail_count, test_count])
	quit(1 if fail_count > 0 else 0)

func _assert(cond: bool, msg: String) -> void:
	test_count += 1
	if cond:
		pass_count += 1
	else:
		fail_count += 1
		print("  FAIL: %s" % msg)

func _test_empty_slot_text_has_no_drag() -> void:
	var text: String = BrottBrainScreenRef.EMPTY_SLOT_TEXT_TEMPLATE
	_assert(not text.to_lower().contains("drag"),
		"AC-1 empty-slot prompt has no 'drag' (got: %s)" % text)

func _test_empty_slot_text_uses_tap_copy() -> void:
	var text: String = BrottBrainScreenRef.EMPTY_SLOT_TEXT_TEMPLATE.to_lower()
	var has_click_or_tap := text.contains("tap") or text.contains("click")
	_assert(has_click_or_tap,
		"AC-2 empty-slot prompt uses click/tap copy (got: %s)"
			% BrottBrainScreenRef.EMPTY_SLOT_TEXT_TEMPLATE)
