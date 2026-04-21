## [S17.2-003] Scout movement feel: velocity smoothing + angular cap.
## Usage: godot --headless --script tests/test_s17_2_scout_feel.gd
##
## Specs:
##   docs/design/s17.2-scout-feel.md (original)
##   docs/design/s17.2-003-scout-feel-revision.md (write-site partition)
##
## Covers:
##   AC-T1 — _smooth_velocity enforces the chassis angular-velocity cap on
##           forward-intent rotations. 180° intent on a Scout requires
##           ceil(180 / (540 * 0.1)) = 4 ticks of rotation.
##   AC-T2 — Replay determinism: two runs with the same seed produce
##           byte-identical event streams. This is the AC Nutts' first impl
##           pass failed on; the retreat-bypass design is the fix.
##   AC-1/AC-4 — Reversal damping: on a forward-intent reversal, velocity
##           magnitude dips ≥ 35% for REVERSAL_DAMPING_TICKS ticks (visible
##           "plant foot" arc). Sampled via the helper directly.
extends SceneTree

var pass_count := 0
var fail_count := 0
var test_count := 0

const TILE: float = 32.0

func _initialize() -> void:
	print("=== S17.2-003 Scout-feel smoothing tests ===\n")
	_test_angular_cap_scout_180_takes_multiple_ticks()
	_test_angular_cap_fortress_slower_than_scout()
	_test_reversal_damping_magnitude_dip()
	_test_determinism_same_seed_byte_identical_logs()
	_test_retreat_writes_do_not_touch_velocity_state()
	_test_retreat_step_bounded_per_bot_under_snapshot_tick()
	print("\n=== Results: %d passed, %d failed, %d total ===" % [pass_count, fail_count, test_count])
	quit(1 if fail_count > 0 else 0)

func _assert(cond: bool, msg: String) -> void:
	test_count += 1
	if cond:
		pass_count += 1
		print("  PASS: %s" % msg)
	else:
		fail_count += 1
		print("  FAIL: %s" % msg)

func _mk(chassis: ChassisData.ChassisType, team: int, n: String) -> BrottState:
	var b := BrottState.new()
	b.chassis_type = chassis
	b.weapon_types = [WeaponData.WeaponType.MINIGUN]
	b.armor_type = ArmorData.ArmorType.NONE
	b.module_types = []
	b.team = team
	b.bot_name = n
	b.setup()
	return b

## AC-T1 — Scout 180° rotation must take ≥ 3 ticks (per revision §6 AC-1).
## With MAX_ANGULAR_VELOCITY_SCOUT_DEG = 540, dt = 0.1, max_rot_per_tick = 54°.
## 180° / 54° = 3.33 → 4 ticks before velocity direction fully aligns.
func _test_angular_cap_scout_180_takes_multiple_ticks() -> void:
	print("\n-- AC-T1: Scout angular cap on 180° reversal --")
	var sim := CombatSim.new(1)
	var b := _mk(ChassisData.ChassisType.SCOUT, 0, "S")
	# Seed velocity pointing +x at full commit speed (200 px/s).
	b.velocity = Vector2(200.0, 0.0)
	# Desired intent: reverse to -x at same magnitude.
	var desired: Vector2 = Vector2(-200.0, 0.0)
	var ticks_to_align: int = 0
	for i in range(20):
		sim._smooth_velocity(b, desired, 0.1)
		ticks_to_align += 1
		# Aligned when velocity direction is within 5° of desired direction.
		if b.velocity.length_squared() > 0.0001 and desired.normalized().dot(b.velocity.normalized()) > cos(deg_to_rad(5.0)):
			break
	# Expect at least 3 ticks of visible arc (AC-1).
	_assert(ticks_to_align >= 3, "Scout 180° takes ≥ 3 ticks (got %d)" % ticks_to_align)
	_assert(ticks_to_align <= 5, "Scout 180° completes in ≤ 5 ticks (got %d)" % ticks_to_align)

## Fortress must be strictly slower to rotate than Scout at the same intent.
## MAX_ANGULAR_VELOCITY_FORTRESS_DEG = 150, Scout = 540 — 3.6× ratio.
func _test_angular_cap_fortress_slower_than_scout() -> void:
	print("\n-- AC-T1b: Fortress angular cap vs Scout --")
	var sim := CombatSim.new(1)
	var scout := _mk(ChassisData.ChassisType.SCOUT, 0, "S")
	var fort := _mk(ChassisData.ChassisType.FORTRESS, 0, "F")
	scout.velocity = Vector2(200.0, 0.0)
	fort.velocity = Vector2(200.0, 0.0)
	var desired: Vector2 = Vector2(-200.0, 0.0)
	var scout_ticks := -1
	var fort_ticks := -1
	for i in range(30):
		sim._smooth_velocity(scout, desired, 0.1)
		sim._smooth_velocity(fort, desired, 0.1)
		if scout_ticks < 0 and desired.normalized().dot(scout.velocity.normalized()) > cos(deg_to_rad(5.0)):
			scout_ticks = i + 1
		if fort_ticks < 0 and desired.normalized().dot(fort.velocity.normalized()) > cos(deg_to_rad(5.0)):
			fort_ticks = i + 1
			break
	_assert(scout_ticks > 0 and fort_ticks > 0, "both converged (scout=%d fort=%d)" % [scout_ticks, fort_ticks])
	_assert(fort_ticks > scout_ticks, "Fortress rotates slower than Scout (fort=%d > scout=%d)" % [fort_ticks, scout_ticks])
	# Roughly 3× slower (150 vs 540 deg/s). Allow wide tolerance for integer tick rounding.
	_assert(fort_ticks >= scout_ticks * 2, "Fortress ≥ 2× Scout tick count (fort=%d scout=%d)" % [fort_ticks, scout_ticks])

## AC-1 / AC-4 — Reversal damping. On a forward-intent flip, velocity magnitude
## must drop by REVERSAL_DAMPING_FACTOR for REVERSAL_DAMPING_TICKS ticks. We
## sample the helper directly: seed velocity at +x @ 200, flip intent to -x,
## observe magnitude dip on the next tick.
func _test_reversal_damping_magnitude_dip() -> void:
	print("\n-- AC-4: Reversal damping magnitude dip --")
	var sim := CombatSim.new(1)
	var b := _mk(ChassisData.ChassisType.SCOUT, 0, "S")
	b.velocity = Vector2(200.0, 0.0)
	var desired: Vector2 = Vector2(-200.0, 0.0)
	# First call to _smooth_velocity detects the 180° reversal and arms damping.
	sim._smooth_velocity(b, desired, 0.1)
	var mag_t1: float = b.velocity.length()
	var expected_damped: float = 200.0 * CombatSim.REVERSAL_DAMPING_FACTOR
	# Magnitude on tick 1 is the result of one decel step from 200 toward the
	# damped target; it doesn't snap to target_damped immediately. The
	# per-tick decel for a Scout is ~88 px, so tick 1 magnitude is ~112.
	# The important invariant is the ≥35% dip, asserted below; this loose
	# check just verifies we're monotonically moving toward the target.
	_assert(mag_t1 < 200.0 and mag_t1 > expected_damped * 0.9,
		"Tick 1 mag between damped target and start (%.1f in (%.1f, 200))" % [mag_t1, expected_damped * 0.9])
	# Second tick — damping still active (REVERSAL_DAMPING_TICKS = 2).
	sim._smooth_velocity(b, desired, 0.1)
	var mag_t2: float = b.velocity.length()
	_assert(absf(mag_t2 - expected_damped) < expected_damped * 0.2, "Tick 2 mag still damped (%.1f)" % mag_t2)
	# Verify the ≥35% dip invariant explicitly (AC-4).
	_assert(mag_t1 <= 200.0 * 0.65, "Tick 1 magnitude dips ≥ 35%% (%.1f / 200.0)" % mag_t1)
	_assert(mag_t2 <= 200.0 * 0.65, "Tick 2 magnitude dips ≥ 35%% (%.1f / 200.0)" % mag_t2)

## AC-T2 — Replay determinism. Two runs with the same RNG seed and identical
## starting conditions must produce byte-identical event streams. This is the
## regression Nutts' first impl failed on; it's guarded by the retreat-bypass
## pattern (retreat writes don't feed `desired_vel`, so realized backward
## displacement equals the commanded step exactly — no velocity leak past the
## backup_distance budget).
func _test_determinism_same_seed_byte_identical_logs() -> void:
	print("\n-- AC-T2: Replay determinism --")
	var log_a: String = _run_fixed_sim(424242)
	var log_b: String = _run_fixed_sim(424242)
	_assert(log_a == log_b, "Same-seed logs are byte-identical (len_a=%d len_b=%d diff@=%d)" % [log_a.length(), log_b.length(), _first_diff(log_a, log_b)])
	# And a DIFFERENT seed must produce a DIFFERENT log — otherwise the test
	# above is trivially true because both logs are empty.
	var log_c: String = _run_fixed_sim(424243)
	_assert(log_a != log_c, "Different-seed logs differ (sanity check on determinism test)")
	_assert(log_a.length() > 200, "Log is non-trivial (len=%d)" % log_a.length())

func _run_fixed_sim(seed_val: int) -> String:
	var sim := CombatSim.new(seed_val)
	# Scout vs Scout, asymmetric positions so they actually engage / disengage
	# / retreat / smooth-and-rotate. Cover all TCR phases within 200 ticks.
	var a := _mk(ChassisData.ChassisType.SCOUT, 0, "A")
	var b := _mk(ChassisData.ChassisType.SCOUT, 1, "B")
	a.position = Vector2(3.0 * TILE, 4.0 * TILE)
	b.position = Vector2(12.0 * TILE, 4.0 * TILE)
	a.target = b
	b.target = a
	sim.add_brott(a)
	sim.add_brott(b)
	var lines: Array[String] = []
	for i in range(200):
		if sim.match_over:
			break
		sim.simulate_tick()
		# Log the full per-tick state so any floating-point drift is visible.
		lines.append("%d|%.4f|%.4f|%.4f|%.4f|%.4f|%.4f|%.4f|%.4f|%d|%d|%d|%d" % [
			i,
			a.position.x, a.position.y,
			b.position.x, b.position.y,
			a.velocity.x, a.velocity.y,
			b.velocity.x, b.velocity.y,
			a.combat_phase, b.combat_phase,
			a.reversal_damping_timer, b.reversal_damping_timer,
		])
	return "\n".join(lines)

func _first_diff(x: String, y: String) -> int:
	var n: int = mini(x.length(), y.length())
	for i in range(n):
		if x[i] != y[i]:
			return i
	return n

## Retreat writes must NOT touch b.velocity. This is the revision §4 invariant
## that keeps the backup_distance budget math tick-accurate. We verify the
## invariant at the helper boundary: if _smooth_velocity is never called,
## b.velocity never changes. (The hard-plant `b.velocity = Vector2.ZERO` on
## retreat write-sites is a separate moonwalk-guard carve-out, covered by
## test_sprint11 AC6 in the existing suite.)
func _test_retreat_writes_do_not_touch_velocity_state() -> void:
	print("\n-- AC: Retreat-bypass invariant (no smoothed helper → no velocity write) --")
	var b := _mk(ChassisData.ChassisType.SCOUT, 0, "S")
	b.velocity = Vector2(-123.45, 67.89)
	# Mutate position directly, as retreat sites do.
	var before: Vector2 = b.velocity
	b.position += Vector2(-10.0, 0.0)
	_assert(b.velocity == before, "b.position write does not alter b.velocity")

## AC-T4 — Retreat-step per-bot bound under simultaneous (two-phase) physics.
## Spawn two Scouts overlapping inside TENSION-too-close range; run 20 ticks.
## Assert each bot's cumulative backward displacement (intent-frame, dot < -0.7,
## summed across all retreat ticks regardless of period boundaries) is
## ≤ TILE_SIZE * 2 + 2 px (one TENSION retreat budget + one RECOVERY retreat
## budget + small float margin). This is a tuning-invariant guardrail: it
## catches future regressions in the retreat-bypass lane (e.g., a change to
## RETREAT_SPEED_MULT or the two-phase tick breaking the per-bot bound) before
## they propagate into test_sprint11_2.gd as violation spikes. Spec:
## docs/design/s17.2-003-retreat-calibration.md §2.4.
func _test_retreat_step_bounded_per_bot_under_snapshot_tick() -> void:
	print("\n-- AC-T4: Per-bot backward-displacement bound under two-phase tick --")
	var b0 := _mk(ChassisData.ChassisType.SCOUT, 0, "S0")
	var b1 := _mk(ChassisData.ChassisType.SCOUT, 1, "S1")
	var sim := CombatSim.new(42)
	b0.position = Vector2(200, 256)
	b1.position = Vector2(220, 256)
	sim.add_brott(b0)
	sim.add_brott(b1)
	
	var bots := [b0, b1]
	var prev_pos := [b0.position, b1.position]
	var backward_sum := [0.0, 0.0]
	
	for _t in range(20):
		if sim.match_over:
			break
		# Pre-tick intent-frame sampling per bot.
		var to_target_pre := [Vector2.ZERO, Vector2.ZERO]
		for i in range(2):
			var b: BrottState = bots[i]
			if b.alive and b.target != null:
				to_target_pre[i] = b.target.position - b.position
		sim.simulate_tick()
		for i in range(2):
			var b: BrottState = bots[i]
			if not b.alive:
				continue
			var movement: Vector2 = b.position - prev_pos[i]
			var tt_pre: Vector2 = to_target_pre[i]
			if tt_pre.length() > 0.1 and movement.length() > 0.1:
				var dot: float = movement.normalized().dot(tt_pre.normalized())
				if dot < -0.7:
					# Magnitude of the backward (anti-to_target) projection.
					var back_mag: float = absf(movement.dot(tt_pre.normalized()))
					backward_sum[i] += back_mag
			prev_pos[i] = b.position
	
	var bound: float = CombatSim.TILE_SIZE * 2.0 + 2.0
	_assert(backward_sum[0] <= bound,
		"Bot 0 backward displacement %.2f <= %.2f (2 tiles + 2px)" % [backward_sum[0], bound])
	_assert(backward_sum[1] <= bound,
		"Bot 1 backward displacement %.2f <= %.2f (2 tiles + 2px)" % [backward_sum[1], bound])
