## S21.3 / #245 / #107 — Arena onboarding HUD-element overlays.
## Usage: godot --headless --path godot/ --script res://tests/test_s21_3_arena_onboarding.gd
##
## Covers the 7 assertion classes required by the sprint plan:
##   1. anchor_target node-type asserts ×4 keys (positive + negative)
##   2. sequencing order (fixed 4-key order, one-per-entry)
##   3. arena-entry trigger (not screen-entry)
##   4. energy_explainer S17.1-004 save-carryforward (don't re-show if seen)
##   5. ▲-pointer presence assertion
##   6. one-per-entry invariant
##   7. placement invariant (not top-center; computed relative to anchor)
##
## Strategy: instantiate GameMainScript directly (not the full scene tree);
## synthesise real Control anchor nodes so _spawn_arena_first_encounter can
## run without a live viewport. FirstRunState autoload is exercised via
## get_root().get_node_or_null("/root/FirstRunState") — present when Godot
## runs with the project open (the project.godot autoload entry wires it).
## Tests that strictly require the autoload guard-skip gracefully.

extends SceneTree

var pass_count := 0
var fail_count := 0
var test_count := 0

const TEST_STORE := "user://first_run_test_s21_3.cfg"
const FirstRunStateScript := preload("res://ui/first_run_state.gd")
const GameMainScript := preload("res://game_main.gd")

func _initialize() -> void:
	print("=== S21.3 Arena Onboarding Tests ===\n")
	_reset_all_arena_keys()
	_test_arena_sequence_constants()
	_test_anchor_node_type_energy_explainer()
	_test_anchor_node_type_combatants_explainer()
	_test_anchor_node_type_time_explainer()
	_test_anchor_node_type_concede_explainer()
	_test_sequencing_order()
	_test_one_per_entry()
	_test_save_carryforward()
	_test_pointer_presence()
	_test_placement_not_top_center()
	_test_trigger_arena_entry_only()
	_cleanup_store()
	print("\n=== Results: %d passed, %d failed, %d total ===" % [pass_count, fail_count, test_count])
	quit(1 if fail_count > 0 else 0)

# ─── helpers ─────────────────────────────────────────────────────────────────

func _assert(cond: bool, msg: String) -> void:
	test_count += 1
	if cond:
		pass_count += 1
	else:
		fail_count += 1
		print("  FAIL: %s" % msg)

func _assert_eq(a: Variant, b: Variant, msg: String) -> void:
	_assert(a == b, "%s (got %s, expected %s)" % [msg, str(a), str(b)])

func _assert_ne(a: Variant, b: Variant, msg: String) -> void:
	_assert(a != b, "%s (expected values to differ, both = %s)" % [msg, str(a)])

func _cleanup_store() -> void:
	if FileAccess.file_exists(TEST_STORE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_STORE))

func _reset_all_arena_keys() -> void:
	var frs: Node = get_root().get_node_or_null("FirstRunState")
	if frs == null:
		return
	for k in GameMainScript.ARENA_SEQUENCE:
		frs.call("reset", k)

## Build a minimal GameMain-like node with real Label/Button HUD children so
## _spawn_arena_first_encounter can resolve anchors without a live viewport.
## The node is NOT added to the SceneTree to avoid viewport dependencies;
## tests call _spawn_arena_first_encounter directly.
func _make_game_main_with_hud() -> Node2D:
	var gm: Node2D = GameMainScript.new()
	gm.name = "GameMain"

	# EnergyLegend
	var el := Label.new()
	el.name = "EnergyLegend"
	el.text = "⚡ Energy"
	el.position = Vector2(20.0, 42.0)
	el.size = Vector2(120.0, 20.0)
	gm.add_child(el)

	# PlayerInfo (combatants anchor)
	var pi := Label.new()
	pi.name = "PlayerInfo"
	pi.position = Vector2(20.0, 10.0)
	pi.size = Vector2(300.0, 30.0)
	gm.add_child(pi)
	gm.set("player_info", pi)

	# TimeLabel
	var tl := Label.new()
	tl.name = "TimeLabel"
	tl.position = Vector2(600.0, 10.0)
	tl.size = Vector2(100.0, 30.0)
	gm.add_child(tl)
	gm.set("time_label", tl)

	# ConcedeButton
	var cb := Button.new()
	cb.name = "ConcedeButton"
	cb.text = "Concede"
	cb.position = Vector2(1180.0, 10.0)
	cb.size = Vector2(80.0, 24.0)
	gm.add_child(cb)

	return gm

# ─── 0. ARENA_SEQUENCE constant shape ────────────────────────────────────────

func _test_arena_sequence_constants() -> void:
	print("--- Arena sequence constants ---")
	# [S25.8] ARENA_SEQUENCE prepended with click_controls_explainer (5 keys total).
	_assert_eq(GameMainScript.ARENA_SEQUENCE.size(), 5,
		"ARENA_SEQUENCE has exactly 5 keys (S25.8: click_controls prepended)")
	_assert_eq(GameMainScript.ARENA_SEQUENCE[0], "click_controls_explainer",
		"ARENA_SEQUENCE[0] = click_controls_explainer (S25.8)")
	_assert_eq(GameMainScript.ARENA_SEQUENCE[1], "energy_explainer",
		"ARENA_SEQUENCE[1] = energy_explainer")
	_assert_eq(GameMainScript.ARENA_SEQUENCE[2], "combatants_explainer",
		"ARENA_SEQUENCE[2] = combatants_explainer")
	_assert_eq(GameMainScript.ARENA_SEQUENCE[3], "time_explainer",
		"ARENA_SEQUENCE[3] = time_explainer")
	_assert_eq(GameMainScript.ARENA_SEQUENCE[4], "concede_explainer",
		"ARENA_SEQUENCE[4] = concede_explainer")
	# All 5 keys present in ARENA_FE_COPY.
	for k in GameMainScript.ARENA_SEQUENCE:
		_assert(GameMainScript.ARENA_FE_COPY.has(k),
			"ARENA_FE_COPY has arena key: %s" % k)
	# S17.1-004 save key unchanged.
	_assert_eq(GameMainScript.FE_KEY_ENERGY, "energy_explainer",
		"FE_KEY_ENERGY unchanged from S17.1-004")
	# S25.8: click controls key constant.
	_assert_eq(GameMainScript.FE_KEY_CLICK_CONTROLS, "click_controls_explainer",
		"FE_KEY_CLICK_CONTROLS = click_controls_explainer (S25.8)")

# ─── 1. Anchor node-type asserts ×4 keys ─────────────────────────────────────

func _test_anchor_node_type_energy_explainer() -> void:
	print("--- Anchor node-type: energy_explainer ---")
	var gm := _make_game_main_with_hud()
	var overlay: Control = gm.call("_spawn_arena_first_encounter", "energy_explainer") as Control
	_assert(overlay != null, "energy_explainer: overlay spawned")
	if overlay == null:
		gm.queue_free(); return
	var anchor: Variant = overlay.get_meta("anchor_target", null)
	_assert(anchor != null, "energy_explainer: anchor_target metadata present")
	_assert(anchor is Control,
		"energy_explainer: anchor_target is Control node")
	_assert(anchor is Label,
		"energy_explainer: anchor_target is a Label (HUD element)")
	_assert_eq((anchor as Node).name, "EnergyLegend",
		"energy_explainer: anchor_target.name = EnergyLegend (HUD element)")
	_assert(not (anchor is CanvasLayer),
		"energy_explainer: anchor_target is NOT CanvasLayer")
	# Negative: anchor is not the script root itself.
	_assert(anchor != gm,
		"energy_explainer: anchor_target is not the scene root (gm)")
	gm.queue_free()

func _test_anchor_node_type_combatants_explainer() -> void:
	print("--- Anchor node-type: combatants_explainer ---")
	var gm := _make_game_main_with_hud()
	var overlay: Control = gm.call("_spawn_arena_first_encounter", "combatants_explainer") as Control
	_assert(overlay != null, "combatants_explainer: overlay spawned")
	if overlay == null:
		gm.queue_free(); return
	var anchor: Variant = overlay.get_meta("anchor_target", null)
	_assert(anchor != null, "combatants_explainer: anchor_target present")
	_assert(anchor is Control,
		"combatants_explainer: anchor_target is Control node")
	# Must be a HUD element node, not CanvasLayer / viewport.
	_assert(not (anchor is CanvasLayer),
		"combatants_explainer: anchor_target is NOT CanvasLayer")
	_assert(anchor != gm,
		"combatants_explainer: anchor_target is not the scene root")
	# Name should be a combatants-related HUD node (PlayerInfo or CombatantsPanel).
	var anchor_name: String = (anchor as Node).name
	_assert(anchor_name in ["PlayerInfo", "CombatantsPanel", "EnemyInfo"],
		"combatants_explainer: anchor_target.name is a combatants HUD node (got %s)" % anchor_name)
	gm.queue_free()

func _test_anchor_node_type_time_explainer() -> void:
	print("--- Anchor node-type: time_explainer ---")
	var gm := _make_game_main_with_hud()
	var overlay: Control = gm.call("_spawn_arena_first_encounter", "time_explainer") as Control
	_assert(overlay != null, "time_explainer: overlay spawned")
	if overlay == null:
		gm.queue_free(); return
	var anchor: Variant = overlay.get_meta("anchor_target", null)
	_assert(anchor != null, "time_explainer: anchor_target present")
	_assert(anchor is Control,
		"time_explainer: anchor_target is Control node")
	_assert_eq((anchor as Node).name, "TimeLabel",
		"time_explainer: anchor_target.name = TimeLabel (HUD element)")
	_assert(not (anchor is CanvasLayer),
		"time_explainer: anchor_target is NOT CanvasLayer")
	_assert(anchor != gm,
		"time_explainer: anchor_target is not the scene root")
	gm.queue_free()

func _test_anchor_node_type_concede_explainer() -> void:
	print("--- Anchor node-type: concede_explainer ---")
	var gm := _make_game_main_with_hud()
	var overlay: Control = gm.call("_spawn_arena_first_encounter", "concede_explainer") as Control
	_assert(overlay != null, "concede_explainer: overlay spawned")
	if overlay == null:
		gm.queue_free(); return
	var anchor: Variant = overlay.get_meta("anchor_target", null)
	_assert(anchor != null, "concede_explainer: anchor_target present")
	_assert(anchor is Control,
		"concede_explainer: anchor_target is Control node")
	_assert_eq((anchor as Node).name, "ConcedeButton",
		"concede_explainer: anchor_target.name = ConcedeButton (HUD element)")
	_assert(not (anchor is CanvasLayer),
		"concede_explainer: anchor_target is NOT CanvasLayer")
	_assert(anchor != gm,
		"concede_explainer: anchor_target is not the scene root")
	gm.queue_free()

# ─── 2. Sequencing order ─────────────────────────────────────────────────────

func _test_sequencing_order() -> void:
	print("--- Sequencing order (5 arena entries, fresh save) ---")
	var frs: Node = get_root().get_node_or_null("FirstRunState")
	if frs == null:
		print("  SKIP: no FirstRunState autoload (headless without project autoloads)")
		return
	# Reset all to fresh.
	for k in GameMainScript.ARENA_SEQUENCE:
		frs.call("reset", k)

	var shown: Array = []
	for _entry in range(5):  ## S25.8: 5 entries (click_controls prepended)
		var gm := _make_game_main_with_hud()
		# Simulate arena entry: call _start_arena_onboarding.
		gm.call("_start_arena_onboarding")
		var ov: Variant = gm.get("_arena_fe_overlay")
		if ov != null:
			shown.append(str(gm.get("_arena_fe_active_key")))
			# Mark-seen simulates dismiss so next entry advances.
			frs.call("mark_seen", str(gm.get("_arena_fe_active_key")))
		gm.queue_free()

	_assert_eq(shown.size(), 5,
		"sequencing: exactly 5 overlays shown across 5 arena entries (got %d)" % shown.size())
	if shown.size() == 5:
		_assert_eq(shown[0], "click_controls_explainer","sequencing: entry 1 = click_controls_explainer (S25.8)")
		_assert_eq(shown[1], "energy_explainer",   "sequencing: entry 2 = energy_explainer")
		_assert_eq(shown[2], "combatants_explainer","sequencing: entry 3 = combatants_explainer")
		_assert_eq(shown[3], "time_explainer",      "sequencing: entry 4 = time_explainer")
		_assert_eq(shown[4], "concede_explainer",   "sequencing: entry 5 = concede_explainer")
	# Cleanup.
	for k in GameMainScript.ARENA_SEQUENCE:
		frs.call("reset", k)

# ─── 3. One-per-entry invariant ───────────────────────────────────────────────

func _test_one_per_entry() -> void:
	print("--- One overlay per arena entry ---")
	var frs: Node = get_root().get_node_or_null("FirstRunState")
	if frs == null:
		print("  SKIP: no FirstRunState autoload")
		return
	for k in GameMainScript.ARENA_SEQUENCE:
		frs.call("reset", k)

	var gm := _make_game_main_with_hud()
	gm.call("_start_arena_onboarding")
	# Count active overlays by iterating children.
	var overlay_count := 0
	for child in gm.get_children():
		if child.name.begins_with("ArenaFEOverlay_"):
			overlay_count += 1
	_assert_eq(overlay_count, 1,
		"one-per-entry: exactly 1 arena overlay after first arena entry (got %d)" % overlay_count)

	# Calling _start_arena_onboarding again (simulating duplicate entry) must be a no-op.
	gm.call("_start_arena_onboarding")
	var overlay_count2 := 0
	for child in gm.get_children():
		if child.name.begins_with("ArenaFEOverlay_"):
			overlay_count2 += 1
	_assert_eq(overlay_count2, 1,
		"one-per-entry: re-entry while overlay active does not spawn a second overlay")

	gm.queue_free()
	for k in GameMainScript.ARENA_SEQUENCE:
		frs.call("reset", k)

# ─── 4. Save-carryforward: energy_explainer ──────────────────────────────────

func _test_save_carryforward() -> void:
	print("--- Save-carryforward: energy_explainer (S17.1-004) ---")
	var frs: Node = get_root().get_node_or_null("FirstRunState")
	if frs == null:
		print("  SKIP: no FirstRunState autoload")
		return
	for k in GameMainScript.ARENA_SEQUENCE:
		frs.call("reset", k)
	# [S25.8] Pre-seed click_controls_explainer (S25.8 prepended) AND
	# energy_explainer (S17.1-004 carry-forward). Sequencing should now start at
	# combatants_explainer (the next unseen key after both).
	frs.call("mark_seen", "click_controls_explainer")
	frs.call("mark_seen", "energy_explainer")

	var gm := _make_game_main_with_hud()
	gm.call("_start_arena_onboarding")
	var active_key: String = str(gm.get("_arena_fe_active_key"))
	_assert(active_key != "energy_explainer",
		"save-carryforward: energy_explainer NOT re-shown when already seen")
	_assert(active_key != "click_controls_explainer",
		"save-carryforward: click_controls_explainer NOT re-shown when already seen (S25.8)")
	_assert_eq(active_key, "combatants_explainer",
		"save-carryforward: sequencing starts at combatants_explainer when energy + click_controls seen")
	gm.queue_free()
	for k in GameMainScript.ARENA_SEQUENCE:
		frs.call("reset", k)

# ─── 5. ▲-pointer presence ───────────────────────────────────────────────────

func _test_pointer_presence() -> void:
	print("--- Pointer presence (AnchorArrow) ---")
	for key in GameMainScript.ARENA_SEQUENCE:
		var gm := _make_game_main_with_hud()
		var overlay: Control = gm.call("_spawn_arena_first_encounter", key) as Control
		_assert(overlay != null,
			"pointer[%s]: overlay spawned" % key)
		if overlay != null:
			var arrow: Node = overlay.get_node_or_null("AnchorArrow")
			_assert(arrow != null,
				"pointer[%s]: AnchorArrow child present" % key)
			if arrow != null:
				_assert(arrow is Label,
					"pointer[%s]: AnchorArrow is a Label" % key)
				var arrow_text: String = (arrow as Label).text
				_assert(arrow_text in ["▲", "▼"],
					"pointer[%s]: AnchorArrow text is ▲ or ▼ (got '%s')" % [key, arrow_text])
		gm.queue_free()

# ─── 6. Trigger: arena-entry only, not screen-entry ──────────────────────────

func _test_trigger_arena_entry_only() -> void:
	print("--- Trigger: arena-entry only (not screen-entry) ---")
	var frs: Node = get_root().get_node_or_null("FirstRunState")
	if frs == null:
		print("  SKIP: no FirstRunState autoload")
		return
	for k in GameMainScript.ARENA_SEQUENCE:
		frs.call("reset", k)

	# Create a game_main but do NOT call _create_arena_hud / _start_arena_onboarding.
	# Simulate what happens when non-arena screen transitions occur:
	# _show_shop, _show_brottbrain, _show_opponent_select each call
	# _maybe_spawn_first_encounter with screen-only keys.
	var gm: Node2D = GameMainScript.new()
	# Call the screen-overlay path directly (simulates _show_shop etc).
	# None of the arena keys should be spawned.
	gm.call("_maybe_spawn_first_encounter", GameMainScript.FE_KEY_RUN_START)        ## S25.8: was FE_KEY_SHOP
	gm.call("_maybe_spawn_first_encounter", GameMainScript.FE_KEY_FIRST_REWARD_PICK)  ## S25.8: was FE_KEY_BROTTBRAIN
	gm.call("_maybe_spawn_first_encounter", GameMainScript.FE_KEY_FIRST_RETRY_PROMPT) ## S25.8: was FE_KEY_OPPONENT

	# Arena onboarding overlay (_arena_fe_overlay) must be nil here.
	_assert(gm.get("_arena_fe_overlay") == null,
		"trigger: arena onboarding overlay is NOT spawned by screen-entry hooks")
	_assert(gm.get("_arena_fe_active_key") == "",
		"trigger: arena active key remains empty after screen transitions")

	# Now confirm arena overlays DO spawn when _start_arena_onboarding is called.
	var pi2 := Label.new()
	pi2.name = "PlayerInfo"
	pi2.position = Vector2(20.0, 10.0)
	pi2.size = Vector2(300.0, 30.0)
	gm.add_child(pi2)
	gm.set("player_info", pi2)
	var tl := Label.new()
	tl.name = "TimeLabel"
	tl.position = Vector2(600.0, 10.0)
	tl.size = Vector2(100.0, 30.0)
	gm.add_child(tl)
	gm.set("time_label", tl)
	var el := Label.new()
	el.name = "EnergyLegend"
	el.position = Vector2(20.0, 42.0)
	el.size = Vector2(120.0, 20.0)
	gm.add_child(el)
	var cb := Button.new()
	cb.name = "ConcedeButton"
	cb.position = Vector2(1180.0, 10.0)
	cb.size = Vector2(80.0, 24.0)
	gm.add_child(cb)

	gm.call("_start_arena_onboarding")
	_assert(gm.get("_arena_fe_overlay") != null,
		"trigger: arena overlay IS spawned by _start_arena_onboarding (arena-entry hook)")

	gm.queue_free()
	for k in GameMainScript.ARENA_SEQUENCE:
		frs.call("reset", k)

# ─── 7. Placement invariant (not top-center) ─────────────────────────────────

func _test_placement_not_top_center() -> void:
	print("--- Placement: not top-center; relative to anchor ---")
	for key in GameMainScript.ARENA_SEQUENCE:
		var gm := _make_game_main_with_hud()
		var overlay: Control = gm.call("_spawn_arena_first_encounter", key) as Control
		_assert(overlay != null,
			"placement[%s]: overlay spawned" % key)
		if overlay == null:
			gm.queue_free(); continue
		# S21.3 invariant: placement is NOT top-center (not pinned at y~0 or y~60).
		# The S21.2 screen overlays used position=(330,60); arena overlays must differ.
		var overlay_pos: Vector2 = overlay.position
		_assert_ne(overlay_pos.y, 0.0,
			"placement[%s]: overlay.position.y != 0 (not top-center pinned)" % key)
		# The overlay must be positioned relative to its anchor.
		var anchor: Variant = overlay.get_meta("anchor_target", null)
		if anchor != null:
			var anchor_node := anchor as Control
			var anchor_y: float = anchor_node.position.y
			# Overlay is placed near (above or below) the anchor, not floating at top.
			# We assert it is within 200px of the anchor's y position.
			var delta_y := absf(overlay_pos.y - anchor_y)
			_assert(delta_y < 200.0,
				"placement[%s]: overlay is within 200px of anchor y (delta=%.1f)" % [key, delta_y])
		gm.queue_free()
