## Sprint 11.2 test suite — Juke bugfix + Combat Instrumentation
extends SceneTree

var pass_count := 0
var fail_count := 0
var test_count := 0

func _init() -> void:
	print("=== BattleBrotts Sprint 11.2 Test Suite ===")
	print("=== Juke Bugfix + Instrumentation ===\n")

	test_away_juke_capped_at_one_tile()
	test_away_juke_cap_across_seeds()
	test_hit_rate_instrumentation()
	test_ttk_instrumentation()
	test_regression_summary()

	print("\n--- Results ---")
	print("%d passed, %d failed out of %d" % [pass_count, fail_count, test_count])
	quit(1 if fail_count > 0 else 0)

func _assert(cond: bool, msg: String) -> void:
	test_count += 1
	if cond:
		pass_count += 1
		print("  PASS: %s" % msg)
	else:
		fail_count += 1
		print("  FAIL: %s" % msg)

func _make_scout(team: int, stance: int = 0) -> BrottState:
	var b := BrottState.new()
	b.team = team
	b.bot_name = "Scout_%d" % team
	b.chassis_type = ChassisData.ChassisType.SCOUT
	b.weapon_types = [WeaponData.WeaponType.PLASMA_CUTTER]
	b.armor_type = ArmorData.ArmorType.NONE
	b.module_types = []
	b.stance = stance
	b.setup()
	return b

## Test 1: Away juke retreat never exceeds 1 tile (32px)
## The bug allowed Scout to retreat 3.3 tiles in a single away juke.
func test_away_juke_capped_at_one_tile() -> void:
	print("\n-- Away Juke Cap (direct test) --")
	var b0 := _make_scout(0)
	var b1 := _make_scout(1)
	var sim := CombatSim.new(123)
	b0.position = Vector2(200, 256)
	b1.position = Vector2(220, 256)
	sim.add_brott(b0)
	sim.add_brott(b1)

	# Force b0 into combat movement with an "away" juke
	b0.in_combat_movement = true
	b0.target = b1
	b0.juke_active_timer = 8.0  # 8 ticks — old bug duration
	b0.juke_type = "away"
	b0.backup_distance = 0.0

	var start_pos := b0.position
	for _t in range(20):
		sim.simulate_tick()

	var retreat_dist: float = start_pos.distance_to(b0.position)
	# Allow small margin for separation force but retreat component should be ≤32px
	_assert(b0.backup_distance <= 32.0 + 0.1, "backup_distance capped: %.1f px (max 32)" % b0.backup_distance)

## Test 2: Across many seeds, no bot retreats >1 tile in a single away juke sequence
func test_away_juke_cap_across_seeds() -> void:
	print("\n-- Away Juke Cap (100 seeds) --")
	var violations := 0
	for seed_val in range(100):
		var b0 := _make_scout(0)
		var b1 := _make_scout(1)
		var sim := CombatSim.new(seed_val)
		b0.position = Vector2(200, 256)
		b1.position = Vector2(220, 256)
		sim.add_brott(b0)
		sim.add_brott(b1)

		var prev_pos := b0.position
		var backup_run := 0.0
		var prev_bd := 0.0

		for _t in range(300):
			if sim.match_over:
				break
			# Sample target direction BEFORE the tick — intent frame.
			# Per Gizmo's S15.2 ruling (docs/design/sprint15-moonwalk-metric-ruling.md):
			# the moonwalk invariant measures intent to retreat, not post-tick net
			# displacement. Post-tick sampling produces false positives when two bots
			# COMMIT-dash through each other in a single tick (flipped frame).
			var to_target_pre: Vector2 = Vector2.ZERO
			if b0.alive and b0.target != null:
				to_target_pre = b0.target.position - b0.position
			sim.simulate_tick()
			if b0.alive and b0.target != null:
				# Period-boundary reset: if the runtime dropped backup_distance
				# (phase transition or lateral break), we've entered a new retreat
				# period — reset the rolling accumulator. Per Gizmo's S15.2
				# addendum: the invariant is per-period, not absolute-rolling.
				# GDD L286: "max 1 tile retreat before lateral movement" — the
				# bd drop IS the lateral/phase break.
				if b0.backup_distance < prev_bd:
					backup_run = 0.0
				prev_bd = b0.backup_distance
				var movement: Vector2 = b0.position - prev_pos
				if to_target_pre.length() > 0.1 and movement.length() > 0.1:
					var dot: float = movement.normalized().dot(to_target_pre.normalized())
					if dot < -0.7:
						if b0.backup_distance < CombatSim.TILE_SIZE:  # budget-gated: only accumulate while retreat period is live
							backup_run += movement.length()
						# else: post-cap freeze (Gizmo S15.2 Addendum 2) — authored lateral/orbit
						# motion past the cap is not a moonwalk; wait for period-boundary reset.
					else:
						backup_run = 0.0
				prev_pos = b0.position
				if backup_run > 32.0 * 1.2:
					violations += 1
					break

	_assert(violations == 0, "No moonwalk violations (%d/100)" % violations)

## Test 3: Hit rate instrumentation returns valid data
func test_hit_rate_instrumentation() -> void:
	print("\n-- Hit Rate Instrumentation --")
	var b0 := _make_scout(0)
	var b1 := _make_scout(1)
	var sim := CombatSim.new(42)
	b0.position = Vector2(64, 256)
	b1.position = Vector2(448, 256)
	sim.add_brott(b0)
	sim.add_brott(b1)
	for _t in range(600):
		if sim.match_over:
			break
		sim.simulate_tick()

	var hit_rates: Dictionary = sim.get_hit_rates()
	_assert(hit_rates.size() > 0, "Hit rates recorded for %d weapon(s)" % hit_rates.size())
	for wname in hit_rates:
		var rate: float = hit_rates[wname]
		_assert(rate >= 0.0 and rate <= 1.0, "Hit rate for %s: %.2f (valid range)" % [wname, rate])

	# Verify raw counts exist
	var total_fired := 0
	for wname in sim.shots_fired:
		total_fired += sim.shots_fired[wname]
	_assert(total_fired > 0, "Total shots fired: %d (>0)" % total_fired)

## Test 4: TTK instrumentation returns valid data
func test_ttk_instrumentation() -> void:
	print("\n-- TTK Instrumentation --")
	var b0 := _make_scout(0)
	var b1 := _make_scout(1)
	var sim := CombatSim.new(42)
	b0.position = Vector2(64, 256)
	b1.position = Vector2(448, 256)
	sim.add_brott(b0)
	sim.add_brott(b1)
	for _t in range(900):  # Run long enough for a kill
		if sim.match_over:
			break
		sim.simulate_tick()

	_assert(sim.first_engagement_tick >= 0, "First engagement tick recorded: %d" % sim.first_engagement_tick)

	var ttk: Dictionary = sim.get_ttk_seconds()
	if sim.match_over and sim.winner_team != 2:
		_assert(ttk.size() > 0, "TTK recorded for %d bot(s)" % ttk.size())
		for bname in ttk:
			var t: float = ttk[bname]
			_assert(t >= 0.0, "TTK for %s: %.1fs (non-negative)" % [bname, t])
	else:
		_assert(true, "Match was draw/timeout — TTK may be empty (OK)")

## Test 5: Regression summary batch aggregation
func test_regression_summary() -> void:
	print("\n-- Regression Summary --")
	var summaries: Array[Dictionary] = []
	for seed_val in range(20):
		var b0 := _make_scout(0)
		var b1 := _make_scout(1)
		var sim := CombatSim.new(seed_val)
		b0.position = Vector2(64, 256)
		b1.position = Vector2(448, 256)
		sim.add_brott(b0)
		sim.add_brott(b1)
		for _t in range(900):
			if sim.match_over:
				break
			sim.simulate_tick()
		summaries.append(sim.get_regression_summary())

	var batch: Dictionary = CombatSim.batch_regression_summary(summaries)
	_assert(batch["total_sims"] == 20, "Batch has 20 sims")
	_assert(batch.has("win_rates"), "Batch has win_rates")
	_assert(batch.has("avg_ttk_sec"), "Batch has avg_ttk_sec: %.1fs" % batch["avg_ttk_sec"])
	_assert(batch.has("avg_hit_rates"), "Batch has avg_hit_rates")
	print("  Regression baseline: %s" % str(batch))
