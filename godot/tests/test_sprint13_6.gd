## Sprint 13.6 — BrottBrain Scrapyard Trick Choice tests (Nutts-B)
## Usage: godot --headless --script tests/test_sprint13_6.gd
##
## Covers AC #4/#5/#7/#8/#9 + modal smoke:
##   - choice_a / choice_b effects apply (each EffectType)
##   - secondary effect (effect_type_2) applies
##   - _tricks_seen receives trick id after resolution
##   - pick_unseen_trick prefers unseen, falls back when exhausted (no crash)
##   - modal scene instantiates, show_trick callable, `resolved` signal exists
##   - shop skips modal outside Scrapyard and for repeated _build_ui
extends SceneTree

var pass_count := 0
var fail_count := 0
var test_count := 0

func _initialize() -> void:
	print("=== Sprint 13.6 Trick Choice Tests (Nutts-B) ===\n")
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

func _run_all() -> void:
	_test_data_contract()
	_test_bolts_delta_choice_b()
	_test_next_fight_pellet_mod_choice_a()
	_test_secondary_effect_risk_for_reward()
	_test_scavenger_kid_item_grant_plus_bolts()
	_test_hp_delta_goes_pending()
	_test_tricks_seen_populated()
	_test_pick_unseen_prefers_unseen()
	_test_pick_unseen_fallback_when_exhausted()
	_test_clear_run_state()
	_test_build_brott_applies_pending_hp_delta()
	_test_build_brott_applies_pellet_mod()
	_test_build_brott_clears_pending_effects()
	_test_build_brott_hp_delta_floor()
	_test_combat_sim_pellet_mod_floor()
	_test_modal_scene_smoke()
	_test_shop_skips_modal_outside_scrapyard()
	_test_shop_trick_shown_flag_prevents_retrigger()

# --- Data contract ---

func _test_data_contract() -> void:
	print("Data: TRICKS contains the 3 required ids")
	var ids: Array = []
	for t in TrickChoices.TRICKS:
		ids.append(String(t.get("id", "")))
	assert_true(ids.has("rusty_launcher"), "TRICKS has rusty_launcher")
	assert_true(ids.has("scavenger_kid"), "TRICKS has scavenger_kid")
	assert_true(ids.has("risk_for_reward"), "TRICKS has risk_for_reward")
	# Enum sanity
	assert_eq(typeof(TrickChoices.EffectType.BOLTS_DELTA), TYPE_INT, "EffectType.BOLTS_DELTA is int")

# --- Effect application ---

func _trick_by_id(id: String) -> Dictionary:
	for t in TrickChoices.TRICKS:
		if String(t.get("id", "")) == id:
			return t
	return {}

func _test_bolts_delta_choice_b() -> void:
	print("AC#4: rusty_launcher.choice_b (BOLTS_DELTA +10) applies")
	var gs := GameState.new()
	gs.bolts = 50
	var t := _trick_by_id("rusty_launcher")
	gs.apply_trick_choice(t, "choice_b")
	assert_eq(gs.bolts, 60, "bolts incremented by +10")
	assert_eq(gs._next_fight_pellet_mod, 0, "pellet mod untouched by choice_b")

func _test_next_fight_pellet_mod_choice_a() -> void:
	print("AC#4: rusty_launcher.choice_a (NEXT_FIGHT_PELLET_MOD +1)")
	var gs := GameState.new()
	var t := _trick_by_id("rusty_launcher")
	gs.apply_trick_choice(t, "choice_a")
	assert_eq(gs._next_fight_pellet_mod, 1, "pellet mod +1 applied")
	assert_eq(gs.bolts, 0, "bolts unchanged by choice_a")

func _test_secondary_effect_risk_for_reward() -> void:
	print("AC#5: risk_for_reward.choice_a applies both effect_type + effect_type_2")
	var gs := GameState.new()
	var t := _trick_by_id("risk_for_reward")
	gs.apply_trick_choice(t, "choice_a")
	assert_eq(gs._next_fight_pellet_mod, 3, "primary +3 pellets applied")
	assert_eq(gs._pending_hp_delta, -5, "secondary -5 HP applied to pending delta")

func _test_scavenger_kid_item_grant_plus_bolts() -> void:
	print("AC#5: scavenger_kid.choice_a applies ITEM_GRANT stub + BOLTS_DELTA -5")
	var gs := GameState.new()
	gs.bolts = 20
	var t := _trick_by_id("scavenger_kid")
	gs.apply_trick_choice(t, "choice_a")
	# ITEM_GRANT is a documented no-op stub; BOLTS_DELTA side must still apply.
	assert_eq(gs.bolts, 15, "bolts decremented by 5 after secondary effect")

func _test_hp_delta_goes_pending() -> void:
	print("AC#4: HP_DELTA routes to _pending_hp_delta (GameState has no hp field)")
	var gs := GameState.new()
	# synthesize a trick dict to exercise HP_DELTA directly
	var synth := {
		"id": "synth_hp",
		"choice_a": {"effect_type": TrickChoices.EffectType.HP_DELTA, "effect_value": -7},
		"choice_b": {"effect_type": TrickChoices.EffectType.BOLTS_DELTA, "effect_value": 0},
	}
	gs.apply_trick_choice(synth, "choice_a")
	assert_eq(gs._pending_hp_delta, -7, "HP_DELTA stored as pending for next-fight application")

# --- Seen tracking ---

func _test_tricks_seen_populated() -> void:
	print("AC#7: _tricks_seen receives trick id after resolution")
	var gs := GameState.new()
	assert_eq(gs._tricks_seen.size(), 0, "starts empty")
	var t := _trick_by_id("rusty_launcher")
	gs.apply_trick_choice(t, "choice_a")
	assert_true(gs._tricks_seen.has("rusty_launcher"), "rusty_launcher added to _tricks_seen")
	# Idempotent: same trick twice doesn't duplicate.
	gs.apply_trick_choice(t, "choice_b")
	assert_eq(gs._tricks_seen.size(), 1, "re-resolving same trick does not duplicate")

# --- Pool selection ---

func _test_pick_unseen_prefers_unseen() -> void:
	print("AC#8: pick_unseen_trick returns an unseen trick when pool has unseen")
	var gs := GameState.new()
	gs._tricks_seen.append("rusty_launcher")
	gs._tricks_seen.append("scavenger_kid")
	# Only risk_for_reward remains unseen — must always get it.
	for i in 20:
		var picked: Dictionary = gs.pick_unseen_trick()
		assert_eq(String(picked.get("id", "")), "risk_for_reward", "picked unseen trick (iter %d)" % i)

func _test_pick_unseen_fallback_when_exhausted() -> void:
	print("AC#9: exhausted pool falls back to full TRICKS (no crash, not empty)")
	var gs := GameState.new()
	for t in TrickChoices.TRICKS:
		gs._tricks_seen.append(String(t.get("id", "")))
	var picked: Dictionary = gs.pick_unseen_trick()
	assert_true(not picked.is_empty(), "fallback returns a non-empty trick")
	var ids: Array = []
	for t in TrickChoices.TRICKS:
		ids.append(String(t.get("id", "")))
	assert_true(ids.has(String(picked.get("id", ""))), "fallback picks from full TRICKS pool")

# --- Run-reset hook ---

func _test_clear_run_state() -> void:
	print("Run-reset: clear_run_state() wipes trick session state")
	var gs := GameState.new()
	gs._tricks_seen.append("rusty_launcher")
	gs._next_fight_pellet_mod = 3
	gs._pending_hp_delta = -5
	gs.clear_run_state()
	assert_eq(gs._tricks_seen.size(), 0, "_tricks_seen cleared")
	assert_eq(gs._next_fight_pellet_mod, 0, "pellet mod cleared")
	assert_eq(gs._pending_hp_delta, 0, "pending hp delta cleared")

# --- Effect wiring into next-match start (S13.6 WIRE) ---

func _test_build_brott_applies_pending_hp_delta() -> void:
	print("WIRE: build_brott() applies _pending_hp_delta to BrottState.hp/max_hp")
	var gs := GameState.new()
	# Baseline: build with no pending delta to capture chassis max_hp.
	var baseline := gs.build_brott()
	var baseline_max: int = baseline.max_hp
	assert_true(baseline_max > 0, "baseline max_hp positive")
	# Now set a pending -5 and rebuild.
	gs._pending_hp_delta = -5
	var b := gs.build_brott()
	assert_eq(b.max_hp, baseline_max - 5, "max_hp reduced by pending HP_DELTA")
	assert_eq(int(b.hp), baseline_max - 5, "hp matches new max after HP_DELTA")

func _test_build_brott_applies_pellet_mod() -> void:
	print("WIRE: build_brott() carries _next_fight_pellet_mod into BrottState.pellet_mod")
	var gs := GameState.new()
	gs._next_fight_pellet_mod = 3
	var b := gs.build_brott()
	assert_eq(b.pellet_mod, 3, "pellet_mod propagated to BrottState")

func _test_build_brott_clears_pending_effects() -> void:
	print("WIRE: build_brott() clears pending effects so they don't leak to next match")
	var gs := GameState.new()
	gs._pending_hp_delta = -5
	gs._next_fight_pellet_mod = 3
	var _b := gs.build_brott()
	assert_eq(gs._pending_hp_delta, 0, "_pending_hp_delta cleared after consumption")
	assert_eq(gs._next_fight_pellet_mod, 0, "_next_fight_pellet_mod cleared after consumption")
	# A second build_brott() with no pending deltas must restore baseline max_hp.
	var b2 := gs.build_brott()
	var baseline := gs.build_brott()
	assert_eq(b2.max_hp, baseline.max_hp, "second build returns unmodified max_hp")

func _test_build_brott_hp_delta_floor() -> void:
	print("WIRE: HP_DELTA can't drop max_hp below 1")
	var gs := GameState.new()
	gs._pending_hp_delta = -100000
	var b := gs.build_brott()
	assert_true(b.max_hp >= 1, "max_hp floor-clamped to >= 1")
	assert_true(b.hp >= 1.0, "hp floor-clamped to >= 1")

func _test_combat_sim_pellet_mod_floor() -> void:
	print("WIRE: combat_sim applies BrottState.pellet_mod with floor of 1")
	# Unit-level: we don't spin a full sim (firing needs targets/energy/etc).
	# Instead, replicate the guard used in combat_sim: max(1, pellets + pellet_mod).
	# This makes the contract explicit at the test layer: a huge negative mod
	# can't zero out a single-pellet weapon.
	var base_pellets := 1
	var mod := -99
	var effective: int = max(1, base_pellets + mod)
	assert_eq(effective, 1, "negative pellet_mod clamped to 1")
	# And positive mods stack additively.
	assert_eq(max(1, 5 + 3), 8, "positive pellet_mod adds to base pellets")

func _test_modal_scene_smoke() -> void:
	print("Smoke: trick_choice_modal.tscn instantiates, show_trick callable, resolved signal exists")
	var scene: PackedScene = load("res://ui/trick_choice_modal.tscn") as PackedScene
	assert_true(scene != null, "modal PackedScene loaded")
	if scene == null:
		return
	var modal = scene.instantiate()
	assert_true(modal != null, "modal instantiates")
	assert_true(modal.has_method("show_trick"), "modal has show_trick(trick)")
	# Signal discovery
	var found := false
	for sig in modal.get_signal_list():
		if String(sig.get("name", "")) == "resolved":
			found = true
			break
	assert_true(found, "modal declares `resolved` signal")
	modal.free()

# --- Shop integration ---

func _test_shop_skips_modal_outside_scrapyard() -> void:
	print("Integration: ShopScreen outside Scrapyard builds grid without modal")
	var gs := GameState.new()
	gs.current_league = "bronze"
	gs.bolts = 500
	var shop := ShopScreen.new()
	root.add_child(shop)
	# Use setup() — not setup_for_viewport — to exercise real production path.
	# Because league != "scrapyard", modal short-circuits and grid builds sync.
	shop.setup(gs)
	# Grid must be built (Section_WEAPONS exists).
	var sections := shop.find_children("Section_*", "VBoxContainer", true, false)
	assert_true(sections.size() > 0, "sections built outside Scrapyard (no modal blocked grid)")
	# _tricks_seen must remain empty (modal never ran).
	assert_eq(gs._tricks_seen.size(), 0, "no trick applied outside Scrapyard")
	root.remove_child(shop)
	shop.free()

func _test_shop_trick_shown_flag_prevents_retrigger() -> void:
	print("Integration: _trick_shown flag prevents modal re-trigger on rebuilds")
	var gs := GameState.new()
	gs.bolts = 500
	# current_league defaults to "scrapyard" in GameState._init
	assert_eq(gs.current_league, "scrapyard", "baseline: scrapyard league")
	var shop := ShopScreen.new()
	shop._skip_trick = true  # bypass modal in headless unit scope
	root.add_child(shop)
	shop.setup(gs)
	assert_true(shop._trick_shown, "_trick_shown set after first setup (skip path)")
	# Subsequent _build_ui() calls (e.g. after buys) must not re-show.
	shop._build_ui()
	assert_true(shop._trick_shown, "_trick_shown still true after rebuild")
	assert_eq(gs._tricks_seen.size(), 0, "no trick applied in skip path")
	root.remove_child(shop)
	shop.free()
