## test_arc_r_marker_priority_refix.gd — Arc R: Click-to-move wins over combat AI.
##
## Root cause found (Arc R): b.velocity from combat AI (pointing toward enemy) was
## inherited when move_to_override activated. The angular-velocity cap in
## _smooth_velocity() meant it took up to 7 ticks (0.7s) to rotate 180° away from
## the enemy toward the waypoint. For Fortress (150°/s) this was up to 1.2s.
##
## Fix: Reset b.velocity = Vector2.ZERO and b.reversal_damping_timer = 0 on the
## FIRST tick of move_to_override (detected by _override_move_initial_dist < 0).
## The bot now immediately accelerates from rest toward the waypoint on tick 1.
##
## Gates:
##   R1: Bot moves TOWARD waypoint on tick 1 (not toward enemy) even when enemy is in range
##   R2: Bot makes net progress toward waypoint within 3 ticks (not stuck going toward enemy)
##   R3: All chassis (Scout/Brawler/Fortress) respond to override on tick 1 without angular delay
##   R4: velocity resets to zero on the first tick, allowing fresh direction toward waypoint
extends SceneTree

var pass_count := 0
var fail_count := 0

func _initialize() -> void:
	print("=== test_arc_r_marker_priority_refix ===\n")
	_test_r1_moves_toward_waypoint_not_enemy()
	_test_r2_net_progress_toward_waypoint_3_ticks()
	_test_r3_all_chassis_respond_on_tick1()
	_test_r4_velocity_resets_on_override_entry()
	print("\n=== Results: %d passed, %d failed ===" % [pass_count, fail_count])
	quit(1 if fail_count > 0 else 0)

func _assert(cond: bool, msg: String) -> void:
	if cond:
		pass_count += 1
		print("  PASS: %s" % msg)
	else:
		fail_count += 1
		print("  FAIL: %s" % msg)

## Helper: build a sim with a player and enemy positioned so that:
##   - Player at (256, 256), enemy at (350, 256) — enemy is to the RIGHT, in combat range
##   - Waypoint at (100, 256) — target is to the LEFT
## The enemy is within weapon range so TCR would be active without override.
## After a click, the bot MUST move LEFT (toward waypoint), not RIGHT (toward enemy).
func _make_sim_in_combat(chassis: int) -> Array:
	var sim := CombatSim.new(42)

	var player := BrottState.new()
	player.team = 0
	player.bot_name = "Player"
	player.chassis_type = chassis
	player.weapon_types.append(WeaponData.WeaponType.SHOTGUN)
	player.armor_type = ArmorData.ArmorType.NONE
	player.setup()
	player.position = Vector2(256.0, 256.0)
	player.brain = BrottBrain.default_for_chassis(chassis)
	sim.add_brott(player)

	var enemy := BrottState.new()
	enemy.team = 1
	enemy.bot_name = "Enemy"
	enemy.chassis_type = ChassisData.ChassisType.BRAWLER
	enemy.weapon_types.append(WeaponData.WeaponType.SHOTGUN)
	enemy.armor_type = ArmorData.ArmorType.NONE
	enemy.setup()
	## God-mode HP so the enemy survives all ticks
	enemy.max_hp = 99999
	enemy.hp = 99999.0
	## Enemy to the RIGHT of player, within weapon range (Shotgun range = 5 tiles = 160px)
	enemy.position = Vector2(356.0, 256.0)  # 100px away — within Shotgun range
	enemy.brain = BrottBrain.default_for_chassis(1)
	sim.add_brott(enemy)

	return [sim, player, enemy]

## ── R1: Bot moves TOWARD waypoint (left) not toward enemy (right) on tick 1 ──
func _test_r1_moves_toward_waypoint_not_enemy() -> void:
	print("--- R1: bot moves toward waypoint, not enemy, on tick 1 of override ---")
	var parts := _make_sim_in_combat(ChassisData.ChassisType.BRAWLER)
	var sim: CombatSim = parts[0]
	var player: BrottState = parts[1]
	var enemy: BrottState = parts[2]

	## Run 5 ticks to let combat AI arm (in_combat_movement, velocity pointing toward enemy)
	for _i in range(5):
		sim.simulate_tick()

	## Capture pre-override state
	var pos_before: Vector2 = player.position
	_assert(player.brain.movement_override == "" or player.brain.movement_override == "move_to_override",
		"pre-override: movement_override is normal combat state")

	## Click waypoint to the LEFT (x < player.x)
	var waypoint := Vector2(100.0, 256.0)
	player.brain.set_move_override(waypoint)

	## Run 1 tick
	sim.simulate_tick()

	var pos_after: Vector2 = player.position
	## Movement toward waypoint = x decreasing (LEFT)
	## Movement toward enemy = x increasing (RIGHT)
	var dx := pos_after.x - pos_before.x
	_assert(dx < 0.0,
		"tick 1 of override: moved LEFT (toward waypoint, x decreased by %.2fpx), not RIGHT (toward enemy)" % abs(dx))
	_assert(player.brain.movement_override == "move_to_override",
		"movement_override == 'move_to_override' after first tick")

## ── R2: Net progress toward waypoint within 3 ticks ─────────────────────────
func _test_r2_net_progress_toward_waypoint_3_ticks() -> void:
	print("--- R2: bot makes net progress toward waypoint within 3 ticks ---")
	var parts := _make_sim_in_combat(ChassisData.ChassisType.BRAWLER)
	var sim: CombatSim = parts[0]
	var player: BrottState = parts[1]
	var _enemy: BrottState = parts[2]

	## Run 5 ticks to build combat velocity
	for _i in range(5):
		sim.simulate_tick()

	var waypoint := Vector2(100.0, 256.0)
	var dist_before: float = player.position.distance_to(waypoint)
	player.brain.set_move_override(waypoint)

	## Run 3 ticks
	for _i in range(3):
		sim.simulate_tick()

	var dist_after: float = player.position.distance_to(waypoint)
	_assert(dist_after < dist_before,
		"after 3 ticks: distance to waypoint decreased (%.1f → %.1f)" % [dist_before, dist_after])

## ── R3: All chassis respond on tick 1 ───────────────────────────────────────
func _test_r3_all_chassis_respond_on_tick1() -> void:
	print("--- R3: all chassis (Scout/Brawler/Fortress) respond on tick 1 ---")

	var chassis_list := [
		[ChassisData.ChassisType.SCOUT, "Scout"],
		[ChassisData.ChassisType.BRAWLER, "Brawler"],
		[ChassisData.ChassisType.FORTRESS, "Fortress"],
	]

	for entry in chassis_list:
		var chassis: int = entry[0]
		var name: String = entry[1]

		var parts := _make_sim_in_combat(chassis)
		var sim: CombatSim = parts[0]
		var player: BrottState = parts[1]
		var _enemy: BrottState = parts[2]

		## Build up combat velocity for 5 ticks
		for _i in range(5):
			sim.simulate_tick()

		var pos_before: Vector2 = player.position
		var waypoint := Vector2(100.0, 256.0)
		player.brain.set_move_override(waypoint)

		sim.simulate_tick()

		var dx := player.position.x - pos_before.x
		_assert(dx < 0.0,
			"%s: tick 1 of override: moved toward waypoint (dx=%.2f)" % [name, dx])

## ── R4: velocity resets to zero on first tick of override ───────────────────
func _test_r4_velocity_resets_on_override_entry() -> void:
	print("--- R4: b.velocity resets to zero on first tick of move_to_override ---")
	var parts := _make_sim_in_combat(ChassisData.ChassisType.BRAWLER)
	var sim: CombatSim = parts[0]
	var player: BrottState = parts[1]
	var _enemy: BrottState = parts[2]

	## Run 5 ticks to build non-zero velocity toward enemy
	for _i in range(5):
		sim.simulate_tick()

	## Velocity should be non-zero after 5 ticks of combat
	_assert(player.velocity.length_squared() > 0.0,
		"pre-override: velocity is non-zero after 5 combat ticks (%.2f px/s)" % player.velocity.length())

	## Set override — this arms _override_move_initial_dist = -1 (unset)
	var waypoint := Vector2(100.0, 256.0)
	player.brain.set_move_override(waypoint)

	## Confirm override armed correctly
	_assert(player.brain._override_move_initial_dist < 0.0,
		"after set_move_override: _override_move_initial_dist == -1 (first-tick flag armed)")

	## Run 1 tick — velocity should be zero AFTER combat_sim resets it, then
	## the brott accelerates from rest toward the waypoint.
	## After _smooth_velocity from zero: velocity points toward waypoint (x < 0).
	sim.simulate_tick()

	## velocity.x should be negative (pointing toward waypoint at x=100, player at x≈256)
	_assert(player.velocity.x < 0.0,
		"after first override tick: velocity.x < 0 (pointing toward waypoint, not enemy) = %.2f" % player.velocity.x)
	## reversal_damping_timer should be 0 (reset on entry)
	_assert(player.reversal_damping_timer == 0,
		"after first override tick: reversal_damping_timer == 0 (no inherited damping)")
