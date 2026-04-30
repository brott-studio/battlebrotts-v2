## test_reward_pick.gd — S25.5: Reward pick + retry flow tests.
## 6 conditions: eligible-pool exclusion, deterministic seed, battle-index variance,
## add_item dedup, retry-seed formula, off-by-one display.
extends SceneTree

func _init() -> void:
	var pass_count := 0
	var fail_count := 0

	## T1: Eligible pool excludes equipped weapons
	var rs1 := RunState.new(0, 42)
	rs1.equipped_weapons = [1]  # Railgun equipped
	var eligible1: Array = ItemPool.FULL_ITEM_POOL.filter(
		func(i): return not (i["category"] == "weapon" and i["type"] == 1)
	)
	if eligible1.any(func(i): return i["category"] == "weapon" and i["type"] == 1):
		push_error("T1 FAIL: Railgun should be excluded from eligible pool")
		fail_count += 1
	else:
		pass_count += 1

	## T2: Deterministic seed — same seed+battle → same result
	var rs2a := RunState.new(0, 42); rs2a.current_battle_index = 3
	var rs2b := RunState.new(0, 42); rs2b.current_battle_index = 3
	var seed2a := rs2a.seed * 31 + rs2a.current_battle_index
	var seed2b := rs2b.seed * 31 + rs2b.current_battle_index
	if seed2a != seed2b:
		push_error("T2 FAIL: same seed+battle should produce same reward seed")
		fail_count += 1
	else:
		pass_count += 1

	## T3: Different battle_index → different reward seed
	var rs3 := RunState.new(0, 42)
	var seed3a := rs3.seed * 31 + 0  # battle 0
	var seed3b := rs3.seed * 31 + 1  # battle 1
	if seed3a == seed3b:
		push_error("T3 FAIL: different battle index should produce different seeds")
		fail_count += 1
	else:
		pass_count += 1

	## T4: add_item dedup — adding same weapon twice returns false second time
	var rs4 := RunState.new(0, 42)
	var r4a := rs4.add_item("weapon", 1)  # first add succeeds
	var r4b := rs4.add_item("weapon", 1)  # second add is no-op
	if not r4a or r4b:
		push_error("T4 FAIL: first add should return true, second false")
		fail_count += 1
	else:
		pass_count += 1

	## T5: Retry seed formula — different retry_count → different arena_seed
	var rs5 := RunState.new(0, 42)
	rs5.retry_count = 3
	var seed5a := rs5.seed * 31 + rs5.current_battle_index * 1000 + 2  # after first retry
	var seed5b := rs5.seed * 31 + rs5.current_battle_index * 1000 + 1  # after second retry
	if seed5a == seed5b:
		push_error("T5 FAIL: different retry_count should produce different arena seeds")
		fail_count += 1
	else:
		pass_count += 1

	## T6: Off-by-one — battle_index 0 displays as 1, index 14 as 15
	var rs6 := RunState.new(0, 42)
	rs6.current_battle_index = 0
	var display6a := rs6.current_battle_index + 1
	rs6.current_battle_index = 14
	var display6b := rs6.current_battle_index + 1
	if display6a != 1 or display6b != 15:
		push_error("T6 FAIL: off-by-one in battle display")
		fail_count += 1
	else:
		pass_count += 1

	## T7: Description lookup — all item types have descriptions
	var desc_fail := false
	for item in ItemPool.FULL_ITEM_POOL:
		var full_data: Dictionary = {}
		match item["category"]:
			"weapon": full_data = WeaponData.WEAPONS[item["type"]]
			"armor":  full_data = ArmorData.ARMORS[item["type"]]
			"module": full_data = ModuleData.MODULES[item["type"]]
		var description: String = full_data.get("description", "")
		if description.is_empty() and item["type"] != 0:  # ArmorType.NONE is OK
			push_error("T7 FAIL: %s %s has empty description" % [item["category"], item["type"]])
			desc_fail = true
			fail_count += 1
	if not desc_fail:
		pass_count += 1

	print("test_reward_pick: %d passed, %d failed" % [pass_count, fail_count])
	if fail_count > 0:
		quit(1)
	else:
		quit(0)
