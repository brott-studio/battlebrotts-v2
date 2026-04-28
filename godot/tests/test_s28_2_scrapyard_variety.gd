## test_s28_2_scrapyard_variety.gd — Sprint-28.2 SI2-003
## Two variety tests for Scrapyard opponent pool and T1 archetype scheduling.
## Test 1: Legacy TEMPLATES pool — 200-run sim, 3-battle Scrapyard runs, ≥95% get ≥2 distinct archetypes.
## Test 2: T1 archetype_for() variety — 200-run sim, 3-battle schedule, ≥95% get ≥2 distinct archetype IDs.
extends SceneTree

func _init() -> void:
	var fail_count := 0

	# ── Test 1: Legacy TEMPLATES variety (200-run sim) ──────────────────────────
	var t1_variety_pass := 0
	var t1_arch_histogram: Dictionary = {}

	for run_i in range(200):
		var archetypes_seen: Dictionary = {}
		var all_non_empty := true

		for battle_idx in range(3):
			var tier: int = OpponentLoadouts.difficulty_for("scrapyard", battle_idx)
			var last_arch: int = -1
			var t: Dictionary = OpponentLoadouts.pick_opponent_loadout(tier, "scrapyard", last_arch)

			if t.is_empty():
				all_non_empty = false
				break

			var arch = t.get("archetype", -1)
			archetypes_seen[arch] = archetypes_seen.get(arch, 0) + 1
			last_arch = arch

			var arch_key := str(arch)
			t1_arch_histogram[arch_key] = t1_arch_histogram.get(arch_key, 0) + 1

		if all_non_empty and archetypes_seen.size() >= 2:
			t1_variety_pass += 1

	var t1_pass_rate: float = float(t1_variety_pass) / 200.0
	if t1_pass_rate >= 0.95:
		print("PASS: Test1 legacy TEMPLATES variety — pass_rate=%.3f (threshold 0.95)" % t1_pass_rate)
	else:
		print("FAIL: Test1 legacy TEMPLATES variety — pass_rate=%.3f < 0.95" % t1_pass_rate)
		print("  Archetype histogram: ", t1_arch_histogram)
		fail_count += 1

	# ── Test 2: T1 archetype_for() variety (200-run sim) ────────────────────────
	var t2_variety_pass := 0
	var t2_arch_histogram: Dictionary = {}

	for run_i in range(200):
		var rng := RandomNumberGenerator.new()
		rng.seed = run_i

		var run_state := RunState.new()
		# Reset the encounter schedule so each run is fresh
		run_state.encounter_schedule = []

		var arch_ids_seen: Dictionary = {}

		for battle_idx in range(3):
			var arch_id: String = OpponentLoadouts.archetype_for(battle_idx, run_state, rng)
			arch_ids_seen[arch_id] = arch_ids_seen.get(arch_id, 0) + 1
			t2_arch_histogram[arch_id] = t2_arch_histogram.get(arch_id, 0) + 1

		if arch_ids_seen.size() >= 2:
			t2_variety_pass += 1

	var t2_pass_rate: float = float(t2_variety_pass) / 200.0
	if t2_pass_rate >= 0.95:
		print("PASS: Test2 T1 archetype_for variety — pass_rate=%.3f (threshold 0.95)" % t2_pass_rate)
	else:
		print("FAIL: Test2 T1 archetype_for variety — pass_rate=%.3f < 0.95" % t2_pass_rate)
		print("  Archetype ID histogram: ", t2_arch_histogram)
		fail_count += 1

	print("test_s28_2_scrapyard_variety: %s" % ("ALL PASSED" if fail_count == 0 else "%d FAILED" % fail_count))
	if fail_count > 0:
		quit(1)
	else:
		quit(0)
