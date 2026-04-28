## test_s28_1_t1_weights.gd — verifies T1 archetype weight shift (Arc J #314 fix).
## Sprint-28.1 SI1-003.
extends SceneTree

func _init() -> void:
	var pass_count := 0
	var fail_count := 0

	var t1: Dictionary = OpponentLoadouts.ARCHETYPE_WEIGHTS_BY_TIER.get(1, {})

	# standard_duel: 40 → 55
	if t1.get("standard_duel", -1) != 55:
		print("FAIL: T1 standard_duel expected 55, got ", t1.get("standard_duel", "missing"))
		fail_count += 1
	else:
		print("PASS: T1 standard_duel == 55")
	pass_count += 1 - (fail_count if fail_count == 1 else 0)

	# small_swarm: 30 → 15
	var prev := fail_count
	if t1.get("small_swarm", -1) != 15:
		print("FAIL: T1 small_swarm expected 15, got ", t1.get("small_swarm", "missing"))
		fail_count += 1
	else:
		print("PASS: T1 small_swarm == 15")

	# large_swarm: 15 (unchanged guard)
	prev = fail_count
	if t1.get("large_swarm", -1) != 15:
		print("FAIL: T1 large_swarm expected 15, got ", t1.get("large_swarm", "missing"))
		fail_count += 1
	else:
		print("PASS: T1 large_swarm == 15 (unchanged)")

	# glass_cannon_blitz: 15 (unchanged guard)
	prev = fail_count
	if t1.get("glass_cannon_blitz", -1) != 15:
		print("FAIL: T1 glass_cannon_blitz expected 15, got ", t1.get("glass_cannon_blitz", "missing"))
		fail_count += 1
	else:
		print("PASS: T1 glass_cannon_blitz == 15 (unchanged)")

	# T2 spot-check: standard_duel unchanged at 30
	var t2: Dictionary = OpponentLoadouts.ARCHETYPE_WEIGHTS_BY_TIER.get(2, {})
	prev = fail_count
	if t2.get("standard_duel", -1) != 30:
		print("FAIL: T2 standard_duel expected 30, got ", t2.get("standard_duel", "missing"))
		fail_count += 1
	else:
		print("PASS: T2 standard_duel == 30 (unchanged)")

	# Recalculate pass_count cleanly
	pass_count = 5 - fail_count

	print("test_s28_1_t1_weights: %d passed, %d failed" % [pass_count, fail_count])
	if fail_count > 0:
		quit(1)
	else:
		quit(0)
