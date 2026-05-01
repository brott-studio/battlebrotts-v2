## test_s28_1_t1_hp_baseline.gd — verifies T1 baseline HP (Arc J #314 fix; updated M.4/M.4b/M.4c/M.4d).
## Sprint-28.1 SI1-002. M.4: HP 150→80 per sprint-m.4 rebalance. M.4b: T2/T3/T4 HP reduced. M.4c: T3/T4 further reduced. M.4d: T3 110→90, T4 140→115.
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

	# T2+ updated in M.4b: 120→90, 160→130, 200→165. M.4c: T3 130→110, T4 165→140. M.4d: T3 110→90, T4 140→115.
	var expected := {2: 90, 3: 90, 4: 115}
	for tier in expected:
		var prev_fail := fail_count
		var hp := OpponentLoadouts._baseline_hp_for_tier(tier)
		if hp != expected[tier]:
			print("FAIL: _baseline_hp_for_tier(%d) expected %d, got %d" % [tier, expected[tier], hp])
			fail_count += 1
		else:
			print("PASS: _baseline_hp_for_tier(%d) == %d (M.4d)" % [tier, expected[tier]])
		pass_count += 1 - (fail_count - prev_fail)

	print("test_s28_1_t1_hp_baseline: %d passed, %d failed" % [pass_count, fail_count])
	if fail_count > 0:
		quit(1)
	else:
		quit(0)
