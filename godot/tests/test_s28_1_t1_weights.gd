## test_s28_1_t1_weights.gd — verifies T1 archetype weight shift (Arc J #314 fix; updated M.2).
## Sprint-28.1 SI1-003.
# M.2 updated: standard_duel 60→45, brawler_rush 10→25 (over-soft T1 win rate correction)
extends SceneTree

func _init() -> void:
	var pass_count := 0
	var fail_count := 0

	var t1: Dictionary = OpponentLoadouts.ARCHETYPE_WEIGHTS_BY_TIER.get(1, {})

	# standard_duel: M.2 60→45 (reduce easy mirror duels, shift weight to brawler_rush)
	if t1.get("standard_duel", -1) != 45:
		print("FAIL: T1 standard_duel expected 45, got ", t1.get("standard_duel", "missing"))
		fail_count += 1
	else:
		print("PASS: T1 standard_duel == 45 (M.2: 60→45)")
	pass_count += 1 - (fail_count if fail_count == 1 else 0)

	# small_swarm: 30 → 15
	var prev := fail_count
	if t1.get("small_swarm", -1) != 15:
		print("FAIL: T1 small_swarm expected 15, got ", t1.get("small_swarm", "missing"))
		fail_count += 1
	else:
		print("PASS: T1 small_swarm == 15")

	# large_swarm: 15 → 10 (J.2 updated)
	prev = fail_count
	if t1.get("large_swarm", -1) != 10:
		print("FAIL: T1 large_swarm expected 10, got ", t1.get("large_swarm", "missing"))
		fail_count += 1
	else:
		print("PASS: T1 large_swarm == 10 (J.2 updated)")

	# glass_cannon_blitz: 15→5 (J.5.2: Fortress T1 survivability fix)
	prev = fail_count
	if t1.get("glass_cannon_blitz", -1) != 5:
		print("FAIL: T1 glass_cannon_blitz expected 5, got ", t1.get("glass_cannon_blitz", "missing"))
		fail_count += 1
	else:
		print("PASS: T1 glass_cannon_blitz == 5 (J.5.2: 15→5)")

	# brawler_rush: M.2 10->25 (harder Shotgun encounter; Scout/Brawler pressure)
	prev = fail_count
	if t1.get("brawler_rush", -1) != 25:
		print("FAIL: T1 brawler_rush expected 25, got ", t1.get("brawler_rush", "missing"))
		fail_count += 1
	else:
		print("PASS: T1 brawler_rush == 25 (M.2: 10->25)")

	# T2 spot-check: standard_duel unchanged at 30
	var t2: Dictionary = OpponentLoadouts.ARCHETYPE_WEIGHTS_BY_TIER.get(2, {})
	prev = fail_count
	if t2.get("standard_duel", -1) != 30:
		print("FAIL: T2 standard_duel expected 30, got ", t2.get("standard_duel", "missing"))
		fail_count += 1
	else:
		print("PASS: T2 standard_duel == 30 (unchanged)")

	# Recalculate pass_count cleanly
	pass_count = 6 - fail_count

	print("test_s28_1_t1_weights: %d passed, %d failed" % [pass_count, fail_count])
	if fail_count > 0:
		quit(1)
	else:
		quit(0)
