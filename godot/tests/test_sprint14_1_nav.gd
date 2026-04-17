## Sprint 14.1-B — Wall-stuck nav fix tests.
## Usage: godot --headless --script tests/test_sprint14_1_nav.gd
## Spec: docs/design/sprint14.1-loop-closure.md §4
extends SceneTree

var pass_count := 0
var fail_count := 0
var test_count := 0

const TILE: float = 32.0
const STUCK_WINDOW_TICKS: int = 15   # must match combat_sim constant

func _initialize() -> void:
	print("=== Sprint 14.1-B Wall-stuck Nav Tests ===\n")
	_test_bot_does_not_freeze_against_wall_15s()
	_test_bot_repaths_on_invalid_target()
	_test_stuck_detection_threshold_2s()
	_test_unstick_pushes_away_from_wall()
	print("\n=== Results: %d passed, %d failed, %d total ===" % [pass_count, fail_count, test_count])
	quit(1 if fail_count > 0 else 0)

func _assert(cond: bool, msg: String) -> void:
	test_count += 1
	if cond: pass_count += 1
	else:
		fail_count += 1
		print("  FAIL: %s" % msg)

func _mk(chassis: ChassisData.ChassisType, team: int, n: String) -> BrottState:
	var b := BrottState.new()
	b.chassis_type = chassis
	b.weapon_types = [WeaponData.WeaponType.MINIGUN]
	b.armor_type = ArmorData.ArmorType.NONE
	b.module_types = []
	b.team = team; b.bot_name = n; b.setup()
	return b

## Longest contiguous window where displacement from window-start stays <min_px.
func _max_frozen(positions: Array[Vector2], min_px: float) -> int:
	var longest := 0
	for start in range(positions.size()):
		var streak := 1
		for i in range(start + 1, positions.size()):
			if positions[i].distance_to(positions[start]) < min_px:
				streak = i - start + 1
			else: break
		if streak > longest: longest = streak
	return longest

## T1 — Reproduces the playtest bug: scouts near a wall in a 15s fight must
## never sit stationary for >2s. Regression target for the root-cause fix.
func _test_bot_does_not_freeze_against_wall_15s() -> void:
	var sim := CombatSim.new(1337)
	var a := _mk(ChassisData.ChassisType.SCOUT, 0, "A")
	var b := _mk(ChassisData.ChassisType.SCOUT, 1, "B")
	a.position = Vector2(5.0 * TILE, 0.6 * TILE)
	b.position = Vector2(7.5 * TILE, 0.6 * TILE)
	a.target = b; b.target = a
	sim.add_brott(a); sim.add_brott(b)
	var pa: Array[Vector2] = []
	var pb: Array[Vector2] = []
	for _i in range(150):
		sim.simulate_tick()
		if a.alive: pa.append(a.position)
		if b.alive: pb.append(b.position)
	_assert(_max_frozen(pa, 10.0) <= 20, "T1 bot A no >2s freeze (longest=%d)" % _max_frozen(pa, 10.0))
	_assert(_max_frozen(pb, 10.0) <= 20, "T1 bot B no >2s freeze (longest=%d)" % _max_frozen(pb, 10.0))

## T2 — Bot cornered with pillar between it and its target must eventually repath
## away from the corner (unstick triggers, bot moves >1 tile from start).
func _test_bot_repaths_on_invalid_target() -> void:
	var sim := CombatSim.new(42)
	var a := _mk(ChassisData.ChassisType.BRAWLER, 0, "A")
	var b := _mk(ChassisData.ChassisType.BRAWLER, 1, "B")
	a.position = Vector2(0.5 * TILE, 0.5 * TILE)
	b.position = Vector2(7.0 * TILE, 7.0 * TILE)
	a.target = b; b.target = a
	sim.add_brott(a); sim.add_brott(b)
	var start := a.position
	for _i in range(100):
		sim.simulate_tick()
		if not a.alive: break
	_assert(a.position.distance_to(start) > TILE, "T2 cornered bot repaths (moved %.1fpx)" % a.position.distance_to(start))

## T3 — Stuck detection fires at the 1.5s (15-tick) threshold, not before.
## Detection is armed only near geometry (see _is_near_geometry in combat_sim),
## so pin bot against the left wall to ensure the gate is open.
func _test_stuck_detection_threshold_2s() -> void:
	var sim := CombatSim.new(7)
	var a := _mk(ChassisData.ChassisType.BRAWLER, 0, "A")
	var b := _mk(ChassisData.ChassisType.BRAWLER, 1, "B")
	a.position = Vector2(0.5 * TILE, 8.0 * TILE)
	b.position = Vector2(10.0 * TILE, 8.0 * TILE)
	a.target = b; b.target = a
	sim.add_brott(a); sim.add_brott(b)
	var fired_at := -1
	for i in range(25):
		sim.simulate_tick()
		a.position = Vector2(0.5 * TILE, 8.0 * TILE)  # pin against left wall
		if a._unstick_timer > 0.0 and fired_at < 0: fired_at = i + 1
	_assert(fired_at >= 15 and fired_at <= 17, "T3 stuck fires at ~1.5s (tick %d)" % fired_at)

## T4 — Unstick against a wall pushes bot away from the wall.
func _test_unstick_pushes_away_from_wall() -> void:
	var sim := CombatSim.new(99)
	var a := _mk(ChassisData.ChassisType.BRAWLER, 0, "A")
	var b := _mk(ChassisData.ChassisType.BRAWLER, 1, "B")
	a.position = Vector2(0.5 * TILE, 8.0 * TILE)
	b.position = Vector2(12.0 * TILE, 8.0 * TILE)
	a.target = b; b.target = a
	sim.add_brott(a); sim.add_brott(b)
	for _i in range(STUCK_WINDOW_TICKS + 1):
		sim.simulate_tick()
		a.position.x = 0.5 * TILE  # pin to left wall
	var x0 := a.position.x
	for _i in range(8): sim.simulate_tick()
	_assert(a.position.x > x0 + 4.0, "T4 unstick moves away from wall (x %.1f -> %.1f)" % [x0, a.position.x])
