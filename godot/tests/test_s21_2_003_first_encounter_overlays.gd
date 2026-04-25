## S21.2 / T3 / #107 — First-encounter overlay parameterization (4 keys total).
## Usage: godot --headless --script tests/test_s21_2_003_first_encounter_overlays.gd
## Specs:
##   - design/2026-04-23-s21.2-ux-bundle.md §Issue #107
##   - sprints/v2-sprint-21.2.md §T3 acceptance:
##       * fresh-save fixture: every key starts unset
##       * each key spawns its overlay exactly once and never twice
##       * dismiss path persists mark_seen for the active key
##       * tick-budget auto-dismiss persists mark_seen
##       * overlay is teardown-safe across _clear_screen calls
##
## Strategy: we test the FE_COPY registry + FirstRunState helper directly
## (not the full screen lifecycle, which requires an autoload + scene tree).
extends SceneTree

var pass_count := 0
var fail_count := 0
var test_count := 0

const TEST_STORE := "user://first_run_test_s21_2_107.cfg"

func _initialize() -> void:
	print("=== S21.2-003 First-encounter overlay tests ===\n")
	_test_fe_copy_registry_has_all_4_keys()
	_test_fe_keys_are_distinct_strings()
	_test_fe_copy_word_budget()
	_test_first_run_state_fresh_save_all_unset()
	_test_first_run_state_mark_seen_persists_per_key()
	_test_first_run_state_keys_independent()
	print("\n=== Results: %d passed, %d failed, %d total ===" % [pass_count, fail_count, test_count])
	_cleanup_store()
	quit(1 if fail_count > 0 else 0)

func _assert(cond: bool, msg: String) -> void:
	test_count += 1
	if cond:
		pass_count += 1
	else:
		fail_count += 1
		print("  FAIL: %s" % msg)

func _cleanup_store() -> void:
	if FileAccess.file_exists(TEST_STORE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_STORE))

const FirstRunStateScript := preload("res://ui/first_run_state.gd")
const GameMainScript := preload("res://game_main.gd")

func _make_frs() -> Node:
	return FirstRunStateScript.new()

# --- Registry / copy ---

func _test_fe_copy_registry_has_all_4_keys() -> void:
	# Read constants off the GameMain script to avoid scene instantiation.
	# [S25.8] FE_COPY keys retargeted to roguelike surfaces:
	# shop_first_visit → run_start_first_visit,
	# brottbrain_first_visit → first_reward_pick,
	# opponent_first_visit → first_retry_prompt,
	# energy_explainer carry-forward unchanged.
	var copy_dict: Dictionary = GameMainScript.FE_COPY
	_assert(copy_dict.has("run_start_first_visit"), "FE_COPY has run_start_first_visit (S25.8)")
	_assert(copy_dict.has("first_reward_pick"), "FE_COPY has first_reward_pick (S25.8)")
	_assert(copy_dict.has("first_retry_prompt"), "FE_COPY has first_retry_prompt (S25.8)")
	_assert(copy_dict.has("energy_explainer"), "FE_COPY has energy_explainer (S17.1-004 carry-forward)")
	_assert(copy_dict.size() == 4, "FE_COPY has exactly 4 keys (got %d)" % copy_dict.size())

	# Negative invariants: legacy league-era keys must NOT be present (S25.8).
	_assert(not copy_dict.has("shop_first_visit"), "FE_COPY no longer has legacy shop_first_visit (S25.8)")
	_assert(not copy_dict.has("brottbrain_first_visit"), "FE_COPY no longer has legacy brottbrain_first_visit (S25.8)")
	_assert(not copy_dict.has("opponent_first_visit"), "FE_COPY no longer has legacy opponent_first_visit (S25.8)")

func _test_fe_keys_are_distinct_strings() -> void:
	# [S25.8] Constants renamed: FE_KEY_SHOP/BROTTBRAIN/OPPONENT →
	# FE_KEY_RUN_START / FE_KEY_FIRST_REWARD_PICK / FE_KEY_FIRST_RETRY_PROMPT.
	var keys: Array = [
		GameMainScript.FE_KEY_RUN_START,
		GameMainScript.FE_KEY_FIRST_REWARD_PICK,
		GameMainScript.FE_KEY_FIRST_RETRY_PROMPT,
		GameMainScript.FE_KEY_ENERGY,
	]
	var unique := {}
	for k in keys:
		_assert(typeof(k) == TYPE_STRING and (k as String).length() > 0, "key %s is non-empty string" % str(k))
		unique[k] = true
	_assert(unique.size() == 4, "all 4 FE_KEY_* constants are distinct (got %d unique)" % unique.size())

func _test_fe_copy_word_budget() -> void:
	# Per design §Issue #107: <=2 short sentences per overlay; we proxy
	# the constraint with a 30-word ceiling.
	for k in GameMainScript.FE_COPY:
		var s: String = String(GameMainScript.FE_COPY[k])
		var w := s.split(" ").size()
		_assert(w <= 30, "FE_COPY[%s] <=30 words (got %d): '%s'" % [k, w, s])

# --- FirstRunState behavior ---

func _test_first_run_state_fresh_save_all_unset() -> void:
	_cleanup_store()
	var frs: Node = _make_frs()
	# Patch the store path via the underlying ConfigFile load — we can't
	# rebind the const STORE_PATH without subclassing, so we just exercise
	# has_seen on fresh keys against the default store after wiping it.
	for k in GameMainScript.FE_COPY:
		_assert(not frs.call("has_seen", k), "fresh-save: %s starts unset" % k)
	frs.queue_free()

func _test_first_run_state_mark_seen_persists_per_key() -> void:
	var frs: Node = _make_frs()
	var k: String = GameMainScript.FE_KEY_RUN_START  ## S25.8: was FE_KEY_SHOP
	_assert(not frs.call("has_seen", k), "run_start_first_visit unset before mark")
	frs.call("mark_seen", k)
	_assert(frs.call("has_seen", k), "run_start_first_visit set after mark")
	# Re-instantiate to confirm persistence to disk survives across instances.
	frs.queue_free()
	var frs2: Node = _make_frs()
	_assert(frs2.call("has_seen", k), "run_start_first_visit persisted across reload")
	# Reset for repeatability.
	frs2.call("reset", k)
	_assert(not frs2.call("has_seen", k), "reset clears the key")
	frs2.queue_free()

func _test_first_run_state_keys_independent() -> void:
	var frs: Node = _make_frs()
	# Reset all to baseline.
	for k in GameMainScript.FE_COPY:
		frs.call("reset", k)
	# [S25.8] Mark just first_reward_pick; assert others stay unset.
	frs.call("mark_seen", GameMainScript.FE_KEY_FIRST_REWARD_PICK)
	_assert(frs.call("has_seen", GameMainScript.FE_KEY_FIRST_REWARD_PICK), "first_reward_pick marked")
	for k in [GameMainScript.FE_KEY_RUN_START, GameMainScript.FE_KEY_FIRST_RETRY_PROMPT, GameMainScript.FE_KEY_ENERGY]:
		_assert(not frs.call("has_seen", k), "%s independent of first_reward_pick mark" % k)
	# Cleanup.
	frs.call("reset", GameMainScript.FE_KEY_FIRST_REWARD_PICK)
	frs.queue_free()
