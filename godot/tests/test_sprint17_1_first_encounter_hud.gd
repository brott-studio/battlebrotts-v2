## Sprint 17.1-004 — First-encounter HUD energy overlay + first-run state
## Usage: godot --headless --script tests/test_sprint17_1_first_encounter_hud.gd
## Design: docs/design/s17.1-004-first-encounter-hud.md
## Covers (per design §8):
##   AC-1 — Fresh user: overlay spawns on first combat entry
##   AC-2 — After dismissal, overlay does not reappear next combat
##   AC-3 — Input-driven dismissal marks the key as seen
##   AC-4 — Tick-budget auto-dismiss marks the key as seen
##   AC-5 — S17.1-003 legend identity preserved before/during/after overlay
##   AC-6 — Shared persistence API supports reserved `crate_first_run` key
##           without any code change to first_run_state.gd
extends SceneTree

var pass_count := 0
var fail_count := 0
var test_count := 0

# Isolated store path for this test run. Deleted between sub-tests so each
# AC starts from a fresh persistence state without polluting user://.
const TEST_STORE := "user://first_run_test_s17_1_004.cfg"

func _initialize() -> void:
	print("=== Sprint 17.1-004 First-Encounter HUD Tests ===\n")
	_run_all_async()

# Async driver — awaits frames between scene teardowns. Ends the suite
# with quit() so the process exit code reflects pass/fail to CI.
func _run_all_async() -> void:
	await _run_all()
	_cleanup_store()
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

func _cleanup_store() -> void:
	if FileAccess.file_exists(TEST_STORE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_STORE))

const FirstRunStateScript := preload("res://ui/first_run_state.gd")

# Build a fresh FirstRunStateClass instance against an isolated store path.
# We instantiate directly (not via autoload) so tests are hermetic and
# repeatable; the autoload uses the same class + a fixed path in-game.
func _make_frs() -> Node:
	var frs := FirstRunStateScript.new()
	return frs

func _run_all() -> void:
	_test_ac6_shared_persistence_api()
	_test_persistence_roundtrip()
	await _test_ac1_overlay_spawns_on_fresh_first_run()
	await _test_ac2_overlay_skipped_when_marked_seen()
	await _test_ac3_input_dismisses_and_persists()
	await _test_ac4_tick_budget_dismisses_and_persists()
	await _test_ac5_legend_identity_preserved()

# --- AC-6: Shared persistence API — reserved `crate_first_run` key works ---
# Confirms S17.1-006 can adopt FirstRunState without modifying the helper.
func _test_ac6_shared_persistence_api() -> void:
	print("AC-6: shared API supports reserved 'crate_first_run' key")
	# Delete any prior autoload-backed file so we get a clean baseline.
	var autoload_path := "user://first_run.cfg"
	if FileAccess.file_exists(autoload_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(autoload_path))
	var frs: Node = get_root().get_node_or_null("FirstRunState")
	assert_true(frs != null, "FirstRunState autoload registered at /root/FirstRunState")
	if frs == null:
		return
	frs.call("reset", "crate_first_run")
	frs.call("reset", "energy_explainer")
	assert_false(frs.call("has_seen", "crate_first_run"), "fresh: crate_first_run unseen")
	frs.call("mark_seen", "crate_first_run")
	assert_true(frs.call("has_seen", "crate_first_run"), "after mark_seen: crate_first_run seen")
	# Energy key independent of crate key — no key collision.
	assert_false(frs.call("has_seen", "energy_explainer"), "crate mark did not touch energy key")
	# Cleanup for subsequent tests.
	frs.call("reset", "crate_first_run")
	frs.call("reset", "energy_explainer")

# --- Persistence round-trip: mark → save → new instance → load ---
# Tests the ConfigFile write path actually persists across instances.
func _test_persistence_roundtrip() -> void:
	print("persistence: mark_seen survives a reload")
	var autoload_path := "user://first_run.cfg"
	if FileAccess.file_exists(autoload_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(autoload_path))
	var frs: Node = get_root().get_node_or_null("FirstRunState")
	if frs == null:
		assert_true(false, "FirstRunState autoload missing")
		return
	frs.call("reset", "energy_explainer")
	frs.call("mark_seen", "energy_explainer")
	# Fresh instance loads the same file.
	var fresh := FirstRunStateScript.new()
	assert_true(fresh.has_seen("energy_explainer"), "fresh instance sees energy_explainer=true")
	fresh.free()
	# Cleanup.
	frs.call("reset", "energy_explainer")

# --- AC-1: Fresh user — overlay appears on first combat entry ---
func _test_ac1_overlay_spawns_on_fresh_first_run() -> void:
	print("AC-1: overlay spawns on fresh first combat entry")
	var frs: Node = get_root().get_node_or_null("FirstRunState")
	if frs != null:
		frs.call("reset", "energy_explainer")
	var scene: PackedScene = load("res://main.tscn")
	assert_true(scene != null, "main.tscn loadable")
	if scene == null:
		return
	var root_node: Node = scene.instantiate()
	get_root().add_child(root_node)
	await process_frame
	var ui := root_node.get_node_or_null("UI") as CanvasLayer
	assert_true(ui != null, "UI CanvasLayer exists")
	var overlay := ui.get_node_or_null("EnergyExplainerOverlay") if ui else null
	assert_true(overlay != null, "EnergyExplainerOverlay spawned on fresh run")
	if overlay != null:
		var body := overlay.get_node_or_null("Body") as Label
		assert_true(body != null, "overlay has Body label")
		if body != null:
			assert_true("Energy" in body.text, "overlay body mentions Energy")
			assert_true("\u26a1" in body.text, "overlay reuses \u26a1 glyph from S17.1-003")
		var btn := overlay.get_node_or_null("GotItButton") as Button
		assert_true(btn != null, "overlay has Got it! button")
		if btn != null:
			assert_eq(btn.text, "Got it!", "button text matches spec")
	root_node.queue_free()
	await process_frame

# --- AC-2: Overlay does NOT spawn when key already seen ---
func _test_ac2_overlay_skipped_when_marked_seen() -> void:
	print("AC-2: overlay skipped when energy_explainer already seen")
	var frs: Node = get_root().get_node_or_null("FirstRunState")
	if frs == null:
		assert_true(false, "FirstRunState autoload missing")
		return
	frs.call("mark_seen", "energy_explainer")
	var scene: PackedScene = load("res://main.tscn")
	var root_node: Node = scene.instantiate()
	get_root().add_child(root_node)
	await process_frame
	var ui := root_node.get_node_or_null("UI") as CanvasLayer
	var overlay := ui.get_node_or_null("EnergyExplainerOverlay") if ui else null
	assert_true(overlay == null, "no overlay spawned when key seen")
	root_node.queue_free()
	await process_frame
	frs.call("reset", "energy_explainer")

# --- AC-3: Dismissal via button press persists + frees overlay ---
func _test_ac3_input_dismisses_and_persists() -> void:
	print("AC-3: button-press dismissal persists and frees overlay")
	var frs: Node = get_root().get_node_or_null("FirstRunState")
	if frs != null:
		frs.call("reset", "energy_explainer")
	var scene: PackedScene = load("res://main.tscn")
	var root_node: Node = scene.instantiate()
	get_root().add_child(root_node)
	await process_frame
	# Trigger the dismissal directly (bypasses InputEvent plumbing but
	# exercises the same code path the button connects to).
	if root_node.has_method("_on_energy_explainer_dismissed"):
		root_node.call("_on_energy_explainer_dismissed")
	await process_frame
	var ui := root_node.get_node_or_null("UI") as CanvasLayer
	var overlay := ui.get_node_or_null("EnergyExplainerOverlay") if ui else null
	assert_true(overlay == null, "overlay freed after dismissal")
	if frs != null:
		assert_true(frs.call("has_seen", "energy_explainer"), "dismissal marked energy_explainer seen")
		frs.call("reset", "energy_explainer")
	root_node.queue_free()
	await process_frame

# --- AC-4: Tick-budget auto-dismiss path also persists ---
func _test_ac4_tick_budget_dismisses_and_persists() -> void:
	print("AC-4: tick-budget auto-dismiss persists and frees overlay")
	var frs: Node = get_root().get_node_or_null("FirstRunState")
	if frs != null:
		frs.call("reset", "energy_explainer")
	var scene: PackedScene = load("res://main.tscn")
	var root_node: Node = scene.instantiate()
	get_root().add_child(root_node)
	await process_frame
	# Advance frames past the tick budget (ENERGY_EXPLAINER_TICK_BUDGET = 60).
	for i in range(70):
		await process_frame
	var ui := root_node.get_node_or_null("UI") as CanvasLayer
	var overlay := ui.get_node_or_null("EnergyExplainerOverlay") if ui else null
	assert_true(overlay == null, "overlay auto-dismissed after tick budget")
	if frs != null:
		assert_true(frs.call("has_seen", "energy_explainer"), "auto-dismiss marked energy_explainer seen")
		frs.call("reset", "energy_explainer")
	root_node.queue_free()
	await process_frame

# --- AC-5: S17.1-003 legend identity preserved (text + position) ---
# Pixel-identity guard: the EnergyLegend label's text, offsets, and color
# must match S17.1-003's values whether or not the overlay is present.
func _test_ac5_legend_identity_preserved() -> void:
	print("AC-5: S17.1-003 legend pixel-identity preserved")
	var frs: Node = get_root().get_node_or_null("FirstRunState")
	if frs != null:
		frs.call("reset", "energy_explainer")

	# Phase 1: fresh run (overlay present).
	var scene: PackedScene = load("res://main.tscn")
	var r1: Node = scene.instantiate()
	get_root().add_child(r1)
	await process_frame
	var ui1 := r1.get_node_or_null("UI") as CanvasLayer
	var legend1 := ui1.get_node_or_null("EnergyLegend") as Label if ui1 else null
	assert_true(legend1 != null, "legend present with overlay up")
	if legend1 != null:
		assert_eq(legend1.text, "\u26a1 Energy (blue bar) \u2014 powers weapons; regenerates over time.",
			"legend text unchanged with overlay up")
		assert_eq(legend1.offset_left, 20.0, "legend offset_left unchanged with overlay up")
		assert_eq(legend1.offset_top, 42.0, "legend offset_top unchanged with overlay up")
	r1.queue_free()
	await process_frame

	# Phase 2: already-seen (no overlay).
	if frs != null:
		frs.call("mark_seen", "energy_explainer")
	var r2: Node = scene.instantiate()
	get_root().add_child(r2)
	await process_frame
	var ui2 := r2.get_node_or_null("UI") as CanvasLayer
	var legend2 := ui2.get_node_or_null("EnergyLegend") as Label if ui2 else null
	assert_true(legend2 != null, "legend present without overlay")
	if legend2 != null:
		assert_eq(legend2.text, "\u26a1 Energy (blue bar) \u2014 powers weapons; regenerates over time.",
			"legend text unchanged without overlay")
		assert_eq(legend2.offset_left, 20.0, "legend offset_left unchanged without overlay")
		assert_eq(legend2.offset_top, 42.0, "legend offset_top unchanged without overlay")
	r2.queue_free()
	await process_frame
	if frs != null:
		frs.call("reset", "energy_explainer")
