## test_arc_o1_click_override.gd — Arc O.1 assertions.
##
## Gates:
##   O1-1: set_move_override arms _override_ticks_remaining = 25
##   O1-2: each evaluate() with active override decrements counter, keeps movement_override = "move_to_override"
##   O1-3: after 25 ticks override expires: _override_move_pos = INF, _override_ticks_remaining = 0
##   O1-4: new click while override active resets counter to 25 (latest-wins)
##   O1-5: clear_move_override() resets both _override_move_pos and _override_ticks_remaining
##   O1-6: target override (_override_target_id) is unaffected by tick-suppression change
##   O1-7: weapon_mode is NOT changed by any override path
extends SceneTree

var pass_count := 0
var fail_count := 0

func _initialize() -> void:
	print("=== test_arc_o1_click_override ===\n")
	_test_o1_1_set_move_override_arms_counter()
	_test_o1_2_evaluate_decrements_counter()
	_test_o1_3_override_expires_after_25_ticks()
	_test_o1_4_new_click_resets_counter()
	_test_o1_5_clear_move_override_resets_both()
	_test_o1_6_target_override_unaffected()
	_test_o1_7_weapon_mode_unaffected()
	print("\n=== Results: %d passed, %d failed ===" % [pass_count, fail_count])
	quit(1 if fail_count > 0 else 0)

func _assert(cond: bool, msg: String) -> void:
	if cond:
		pass_count += 1
		print("  PASS: %s" % msg)
	else:
		fail_count += 1
		print("  FAIL: %s" % msg)

func _make_sim_with_player_and_enemy() -> Array:
	var sim := CombatSim.new(1)

	var player := BrottState.new()
	player.team = 0
	player.bot_name = "Player"
	player.chassis_type = ChassisData.ChassisType.BRAWLER
	player.weapon_types.append(WeaponData.WeaponType.SHOTGUN)
	player.armor_type = ArmorData.ArmorType.NONE
	player.setup()
	player.position = Vector2(256.0, 256.0)
	player.brain = BrottBrain.default_for_chassis(1)
	sim.add_brott(player)

	var enemy := BrottState.new()
	enemy.team = 1
	enemy.bot_name = "Enemy"
	enemy.chassis_type = ChassisData.ChassisType.SCOUT
	enemy.weapon_types.append(WeaponData.WeaponType.PLASMA_CUTTER)
	enemy.armor_type = ArmorData.ArmorType.NONE
	enemy.setup()
	enemy.position = Vector2(500.0, 256.0)
	enemy.brain = BrottBrain.new()
	sim.add_brott(enemy)

	return [sim, player, enemy]

## ── O1-1: set_move_override arms _override_ticks_remaining = 25 ────────────
func _test_o1_1_set_move_override_arms_counter() -> void:
	print("--- O1-1: set_move_override arms _override_ticks_remaining = 25 ---")
	var brain := BrottBrain.new()
	brain.set_move_override(Vector2(100.0, 200.0))
	_assert(brain._override_ticks_remaining == 25, "_override_ticks_remaining == 25 after set_move_override")
	_assert(brain._override_move_pos == Vector2(100.0, 200.0), "_override_move_pos set correctly")
	_assert(brain._override_target_id == -1, "_override_target_id cleared to -1 (latest-wins)")

## ── O1-2: each evaluate() decrements counter and keeps movement_override = "move_to_override" ──
func _test_o1_2_evaluate_decrements_counter() -> void:
	print("--- O1-2: evaluate() decrements counter and sets move_to_override ---")
	var parts := _make_sim_with_player_and_enemy()
	var player: BrottState = parts[1]

	var waypoint := Vector2(400.0, 256.0)
	player.brain.set_move_override(waypoint)
	_assert(player.brain._override_ticks_remaining == 25, "pre-tick: _override_ticks_remaining == 25")

	## Run 1 tick — counter should drop to 24, movement_override should be "move_to_override"
	parts[0].simulate_tick()
	_assert(player.brain._override_ticks_remaining == 24, "after 1 tick: _override_ticks_remaining == 24")
	_assert(player.brain.movement_override == "move_to_override", "movement_override == 'move_to_override' after tick 1")

	## Run 4 more ticks — counter should be 20
	for _i in range(4):
		parts[0].simulate_tick()
	_assert(player.brain._override_ticks_remaining == 20, "after 5 total ticks: _override_ticks_remaining == 20")
	_assert(player.brain.movement_override == "move_to_override", "movement_override == 'move_to_override' after 5 ticks")

## ── O1-3: after 25 ticks override expires ────────────────────────────────────
func _test_o1_3_override_expires_after_25_ticks() -> void:
	print("--- O1-3: override expires after 25 ticks ---")
	var parts := _make_sim_with_player_and_enemy()
	var sim: CombatSim = parts[0]
	var player: BrottState = parts[1]

	## Place waypoint far enough that movement alone won't clear it
	var waypoint := Vector2(800.0, 256.0)
	player.brain.set_move_override(waypoint)

	## Run exactly 25 ticks
	for _i in range(25):
		sim.simulate_tick()

	## After 25 ticks: counter reaches 0 on last tick, then the elif branch fires on the NEXT tick
	## to clear state. Verify at this point: ticks_remaining should be 0.
	_assert(player.brain._override_ticks_remaining == 0, "after 25 ticks: _override_ticks_remaining == 0")

	## Run 1 more tick to trigger the expiry cleanup branch
	sim.simulate_tick()
	_assert(player.brain._override_move_pos == Vector2.INF, "after expiry cleanup tick: _override_move_pos == INF")
	_assert(player.brain._override_ticks_remaining == 0, "after expiry: _override_ticks_remaining == 0")

## ── O1-4: new click while override active resets counter to 25 (latest-wins) ─
func _test_o1_4_new_click_resets_counter() -> void:
	print("--- O1-4: new click resets counter to 25 (latest-wins) ---")
	var parts := _make_sim_with_player_and_enemy()
	var sim: CombatSim = parts[0]
	var player: BrottState = parts[1]

	player.brain.set_move_override(Vector2(400.0, 256.0))

	## Run 10 ticks — counter at 15
	for _i in range(10):
		sim.simulate_tick()
	_assert(player.brain._override_ticks_remaining == 15, "after 10 ticks: counter == 15")

	## New click — counter resets to 25
	player.brain.set_move_override(Vector2(350.0, 300.0))
	_assert(player.brain._override_ticks_remaining == 25, "after second click: counter reset to 25")

	## Run 5 more ticks — counter at 20 (not 10, because it was reset)
	for _i in range(5):
		sim.simulate_tick()
	_assert(player.brain._override_ticks_remaining == 20, "after 5 ticks from reset: counter == 20")

## ── O1-5: clear_move_override() resets both fields ───────────────────────────
func _test_o1_5_clear_move_override_resets_both() -> void:
	print("--- O1-5: clear_move_override() resets _override_move_pos and _override_ticks_remaining ---")
	var brain := BrottBrain.new()
	brain.set_move_override(Vector2(100.0, 100.0))
	_assert(brain._override_ticks_remaining == 25, "pre-clear: _override_ticks_remaining == 25")
	_assert(brain._override_move_pos != Vector2.INF, "pre-clear: _override_move_pos != INF")

	brain.clear_move_override()
	_assert(brain._override_move_pos == Vector2.INF, "post-clear: _override_move_pos == INF")
	_assert(brain._override_ticks_remaining == 0, "post-clear: _override_ticks_remaining == 0")

## ── O1-6: target override (_override_target_id) is unaffected ────────────────
func _test_o1_6_target_override_unaffected() -> void:
	print("--- O1-6: target override fires independently of tick-suppression ---")
	var parts := _make_sim_with_player_and_enemy()
	var sim: CombatSim = parts[0]
	var player: BrottState = parts[1]
	var enemy: BrottState = parts[2]

	## Set a target override (no move override)
	var enemy_idx: int = sim.brotts.find(enemy)
	player.brain.set_target_override(enemy_idx)
	_assert(player.brain._override_target_id == enemy_idx, "pre-tick: _override_target_id set")
	_assert(player.brain._override_move_pos == Vector2.INF, "no move override active")
	_assert(player.brain._override_ticks_remaining == 0, "_override_ticks_remaining not touched by set_target_override")

	## Run 1 tick — target override should fire, movement_override = "target_override"
	sim.simulate_tick()
	_assert(player.brain.movement_override == "target_override", "movement_override == 'target_override' after set_target_override")

	## Target override clears when target override is explicitly cleared
	player.brain.clear_target_override()
	_assert(player.brain._override_target_id == -1, "clear_target_override: _override_target_id == -1")
	## _override_ticks_remaining should still be 0 (unaffected)
	_assert(player.brain._override_ticks_remaining == 0, "clear_target_override: _override_ticks_remaining unchanged (0)")

## ── O1-7: weapon_mode is NOT changed by any override path ───────────────────
func _test_o1_7_weapon_mode_unaffected() -> void:
	print("--- O1-7: weapon_mode unaffected by any override path ---")
	var parts := _make_sim_with_player_and_enemy()
	var sim: CombatSim = parts[0]
	var player: BrottState = parts[1]
	var enemy: BrottState = parts[2]

	## Default weapon_mode is "all_fire"
	_assert(player.brain.weapon_mode == "all_fire", "pre-override: weapon_mode == 'all_fire'")

	## Set move override, run 5 ticks
	player.brain.set_move_override(Vector2(400.0, 256.0))
	for _i in range(5):
		sim.simulate_tick()
	_assert(player.brain.weapon_mode == "all_fire", "during move override: weapon_mode unchanged")

	## Set target override, run 5 ticks
	player.brain.clear_move_override()
	var enemy_idx: int = sim.brotts.find(enemy)
	player.brain.set_target_override(enemy_idx)
	for _i in range(5):
		sim.simulate_tick()
	_assert(player.brain.weapon_mode == "all_fire", "during target override: weapon_mode unchanged")
