## Sprint 17.1-006 — First-run crate contextual framing
## Usage: godot --headless --script tests/test_sprint17_1_first_run_crate.gd
## Design: docs/design/s17.1-006-first-run-crate.md
##
## Covers design §7 acceptance tests:
##   AC-1 — First-run framing appears for `crate_find`.
##   AC-2 — Second-run framing suppressed (mark_seen already set).
##   AC-3 — Non-crate trick never shows framing, never marks key.
##   AC-4 — Framing marks seen on show (not on resolve).
##   AC-5 — Choice resolution unchanged (resolved signal parity).
##   AC-6 — Framing copy matches spec verbatim.
##
## Tests instantiate the packed scene (not script.new()) so @onready refs
## resolve. Each test resets `crate_first_run` before + after.
extends SceneTree

var pass_count := 0
var fail_count := 0
var test_count := 0

const MODAL_SCENE_PATH := "res://ui/trick_choice_modal.tscn"
const CRATE_KEY := "crate_first_run"
const EXPECTED_COPY := "Crates are optional loot. Opening might give you an item \u2014 or nothing."

func _initialize() -> void:
	print("=== S17.1-006 First-run crate framing tests ===\n")
	_run_all_async()

func _run_all_async() -> void:
	await _run_all()
	_reset_key()
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

func assert_false(cond: bool, msg: String) -> void:
	assert_true(not cond, msg)

func _frs() -> Node:
	return get_root().get_node_or_null("FirstRunState")

func _reset_key() -> void:
	var frs := _frs()
	if frs != null:
		frs.call("reset", CRATE_KEY)

func _crate_trick() -> Dictionary:
	return {
		"id": "crate_find",
		"brottbrain_text": "...looks like a crate.",
		"prompt": "Pry it open?",
		"choice_a": {"label": "Crack it", "flavor_line": "Nice."},
		"choice_b": {"label": "Walk past", "flavor_line": "Ok."},
	}

func _non_crate_trick() -> Dictionary:
	return {
		"id": "risk_for_reward",
		"brottbrain_text": "Hmm.",
		"prompt": "Take the risk?",
		"choice_a": {"label": "Yes", "flavor_line": "bold."},
		"choice_b": {"label": "No", "flavor_line": "safe."},
	}

func _spawn_modal() -> Node:
	var scene: PackedScene = load(MODAL_SCENE_PATH)
	if scene == null:
		return null
	var modal: Node = scene.instantiate()
	get_root().add_child(modal)
	return modal

func _run_all() -> void:
	await _test_ac1_first_run_framing_appears()
	await _test_ac2_second_run_framing_suppressed()
	await _test_ac3_non_crate_trick_never_shows_framing()
	await _test_ac4_framing_marks_seen_on_show()
	await _test_ac5_choice_resolution_unchanged()
	await _test_ac6_framing_copy_matches_spec()

# --- AC-1 ---
func _test_ac1_first_run_framing_appears() -> void:
	print("AC-1: first-run framing appears for crate_find")
	_reset_key()
	var modal := _spawn_modal()
	assert_true(modal != null, "modal scene instantiates")
	if modal == null:
		return
	await process_frame
	modal.call("show_trick", _crate_trick())
	await process_frame
	var framing: Label = modal.get_node_or_null("Overlay/Panel/VBox/FirstRunFraming")
	assert_true(framing != null, "FirstRunFraming label exists in scene")
	if framing != null:
		assert_true(framing.visible, "framing is visible on first run")
		assert_true(framing.text != "", "framing text is non-empty")
	modal.queue_free()
	await process_frame
	_reset_key()

# --- AC-2 ---
func _test_ac2_second_run_framing_suppressed() -> void:
	print("AC-2: framing suppressed when key already seen")
	_reset_key()
	var frs := _frs()
	assert_true(frs != null, "FirstRunState autoload present")
	if frs == null:
		return
	frs.call("mark_seen", CRATE_KEY)
	var modal := _spawn_modal()
	if modal == null:
		return
	await process_frame
	modal.call("show_trick", _crate_trick())
	await process_frame
	var framing: Label = modal.get_node_or_null("Overlay/Panel/VBox/FirstRunFraming")
	if framing != null:
		assert_false(framing.visible, "framing is hidden on second run")
	modal.queue_free()
	await process_frame
	_reset_key()

# --- AC-3 ---
func _test_ac3_non_crate_trick_never_shows_framing() -> void:
	print("AC-3: non-crate trick never shows framing, never marks key")
	_reset_key()
	var modal := _spawn_modal()
	if modal == null:
		return
	await process_frame
	modal.call("show_trick", _non_crate_trick())
	await process_frame
	var framing: Label = modal.get_node_or_null("Overlay/Panel/VBox/FirstRunFraming")
	if framing != null:
		assert_false(framing.visible, "framing is hidden for non-crate trick")
	var frs := _frs()
	if frs != null:
		assert_false(bool(frs.call("has_seen", CRATE_KEY)), "crate_first_run remains unseen after non-crate trick")
	modal.queue_free()
	await process_frame
	_reset_key()

# --- AC-4 ---
func _test_ac4_framing_marks_seen_on_show() -> void:
	print("AC-4: framing marks key seen on show (before any button press)")
	_reset_key()
	var frs := _frs()
	if frs == null:
		return
	assert_false(bool(frs.call("has_seen", CRATE_KEY)), "baseline: key unseen")
	var modal := _spawn_modal()
	if modal == null:
		return
	await process_frame
	modal.call("show_trick", _crate_trick())
	await process_frame
	# No button press has occurred; key must already be flipped.
	assert_true(bool(frs.call("has_seen", CRATE_KEY)), "key marked seen on show, not on resolve")
	modal.queue_free()
	await process_frame
	_reset_key()

# --- AC-5 ---
func _test_ac5_choice_resolution_unchanged() -> void:
	print("AC-5: resolved signal still fires with (trick_id, choice_key) for crate_find")
	_reset_key()
	var modal := _spawn_modal()
	if modal == null:
		return
	await process_frame
	modal.call("show_trick", _crate_trick())
	await process_frame
	# Press Choice A directly. `_on_choice` is async (awaits tween timers)
	# totaling ~1.25s. Await the `resolved` signal instead of polling.
	modal.call("_on_choice", "choice_a")
	var result: Array = await modal.resolved
	var tid: String = String(result[0]) if result.size() > 0 else ""
	var key: String = String(result[1]) if result.size() > 1 else ""
	assert_eq(tid, "crate_find", "resolved tid == crate_find")
	assert_eq(key, "choice_a", "resolved key == choice_a")
	modal.queue_free()
	await process_frame
	_reset_key()

# --- AC-6 ---
func _test_ac6_framing_copy_matches_spec() -> void:
	print("AC-6: framing copy matches §4.2 verbatim")
	_reset_key()
	var modal := _spawn_modal()
	if modal == null:
		return
	await process_frame
	modal.call("show_trick", _crate_trick())
	await process_frame
	var framing: Label = modal.get_node_or_null("Overlay/Panel/VBox/FirstRunFraming")
	if framing != null:
		assert_eq(framing.text, EXPECTED_COPY, "framing text matches spec")
	modal.queue_free()
	await process_frame
	_reset_key()
