## test_s28_1_t1_hp_baseline.gd — verifies T1 baseline HP (Arc J #314 fix; updated M.4).
## Sprint-28.1 SI1-002. M.4: HP 150→80 per sprint-m.4 rebalance.
extends SceneTree

func _init() -> void:
	var pass_count := 0
	var fail_count := 0

	# T1 target: 80 (was 150; M.4 rebalance)
	var hp1 := OpponentLoadouts._baseline_hp_for_tier(1)
	if hp1 != 80:
		print("FAIL: _baseline_hp_for_tier(1) expected 80, got ", hp1)
		fail_count += 1
	else:
		print("PASS: _baseline_hp_for_tier(1) == 80 (M.4: 150→80)")
	pass_count += 1 - fail_count

	# T2+ should be unchanged (120, 160, 200, 240)
	var expected := {2: 120, 3: 160, 4: 200}
	for tier in expected:
		var prev_fail := fail_count
		var hp := OpponentLoadouts._baseline_hp_for_tier(tier)
		if hp != expected[tier]:
			print("FAIL: _baseline_hp_for_tier(%d) expected %d, got %d" % [tier, expected[tier], hp])
			fail_count += 1
		else:
			print("PASS: _baseline_hp_for_tier(%d) == %d (unchanged)" % [tier, expected[tier]])
		pass_count += 1 - (fail_count - prev_fail)

	print("test_s28_1_t1_hp_baseline: %d passed, %d failed" % [pass_count, fail_count])
	if fail_count > 0:
		quit(1)
	else:
		quit(0)
