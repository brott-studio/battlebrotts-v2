## Sprint 13.10 pre-stage — Boltz S13.9 nits: weight-cap + empty-pool guards.
## Usage: godot --headless --script tests/test_sprint13_10.gd
extends SceneTree

var pass_count := 0
var fail_count := 0
var test_count := 0

func _initialize() -> void:
	print("=== Sprint 13.10 Pre-Stage Tests (empty-pool + weight-cap) ===\n")
	_run_all()
	print("\n=== Results: %d passed, %d failed, %d total ===" % [pass_count, fail_count, test_count])
	quit(1 if fail_count > 0 else 0)

func assert_true(cond: bool, msg: String) -> void:
	test_count += 1
	if cond:
		pass_count += 1
	else:
		fail_count += 1
		print("  FAIL: %s" % msg)

func _run_all() -> void:
	_test_template_count_within_cap()
	_test_picker_empty_pool_returns_empty_dict()
	_test_picker_empty_pool_preserves_signature()
	_test_build_opponent_brott_handles_empty_pool()
	_test_build_opponent_brott_unknown_league_falls_back()

## T1 — TEMPLATES stays within the 40-cap (33% headroom over current 30 per Gizmo).
func _test_template_count_within_cap() -> void:
	var n := OpponentLoadouts.TEMPLATES.size()
	assert_true(n <= 40, "T1 TEMPLATES.size() <= 40 (got %d)" % n)

## T2 — Tier that matches nothing (tier=99) and no tier-1 fallback overlap → {}.
## Picker fallback adds tier-1 when pool.size() < 2, so tier=99 alone still yields tier-1 pool.
## To truly empty: tier=99 AND a variety strip that can't drain (variety strip only runs when
## last_archetype != -1 and doesn't empty pool). With tier=99, pool=tier-(99-1)=tier-98=[].
## So pool stays empty through all branches → picker must return {}.
func _test_picker_empty_pool_returns_empty_dict() -> void:
	var pick: Dictionary = OpponentLoadouts.pick_opponent_loadout(99, -1)
	assert_true(pick.is_empty(), "T2 picker returns {} for tier=99 (no matches, no tier-98 fallback)")

## T3 — Same with a hint/variety arg; still {} rather than crash.
func _test_picker_empty_pool_preserves_signature() -> void:
	var pick: Dictionary = OpponentLoadouts.pick_opponent_loadout(99, OpponentLoadouts.Archetype.TANK)
	assert_true(pick.is_empty(), "T3 picker returns {} even with last_archetype hint")

## T4 — Builder with no game_state still survives empty-pool via tier-1 fallback chain.
## We can't easily force an empty-pool via league (difficulty_for caps to known tiers),
## but we CAN verify the builder doesn't crash and always returns a valid brott for any
## known league/index combo (which exercises the fallback chain on any misconfiguration).
func _test_build_opponent_brott_handles_empty_pool() -> void:
	var b: BrottState = OpponentData.build_opponent_brott("scrapyard", 0, null)
	assert_true(b != null and b.bot_name != "", "T4 build_opponent_brott returns non-null brott (fallback chain intact)")

## T5 — Unknown league (difficulty_for → tier 1), builder should still succeed.
func _test_build_opponent_brott_unknown_league_falls_back() -> void:
	var b: BrottState = OpponentData.build_opponent_brott("nonexistent_league", 0, null)
	assert_true(b != null and b.bot_name != "", "T5 unknown league still produces a brott via tier-1 fallback")
