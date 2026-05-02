## test_run_state_init.gd — S25.1 RunState initialization tests
extends SceneTree

func _init() -> void:
	var pass_count := 0
	var fail_count := 0

	# T1: Default construction (Scout chassis 0 → Plasma Cutter)
	var rs := RunState.new()
	assert(rs.retry_count == 3, "retry_count default should be 3")
	assert(rs.current_battle_index == 0, "current_battle_index default should be 0")
	assert(rs.battles_won == 0, "battles_won default should be 0")
	assert(rs.equipped_weapons.size() == 1, "equipped_weapons should contain the S26.1 starter weapon")
	assert(4 in rs.equipped_weapons, "S26.1: Scout default starter weapon must be Plasma Cutter (4)")
	assert(rs.equipped_armor == 0, "equipped_armor should be NONE (0)")
	assert(rs.equipped_modules.size() == 0, "equipped_modules should be empty")
	assert(rs._last_encounter_archetype == -1, "_last_encounter_archetype should be -1")
	pass_count += 7

	# T2: Fortress chassis construction — uses Flak Cannon (6) as starter [M.2b]
	# Plasma Cutter range 2.5 is unplayable at Fortress speed 60 px/s vs 150HP T1 opponents.
	var rs2 := RunState.new(2, 42)  # Fortress, seed=42
	assert(rs2.equipped_chassis == 2, "equipped_chassis should be set from constructor")
	assert(rs2.seed == 42, "seed should be set from constructor")
	assert(rs2.equipped_weapons.size() == 1, "M.2b: Fortress starter weapon present via constructor")
	assert(6 in rs2.equipped_weapons, "M.2b: Fortress starter weapon is Flak Cannon (6)")
	pass_count += 3

	# T3: build_player_brott produces valid BrottState (Scout)
	var rs3 := RunState.new(0, 0)  # Scout
	var bs := rs3.build_player_brott()
	assert(bs != null, "build_player_brott should return a BrottState")
	assert(bs.team == 0, "player brott team should be 0")
	assert(bs.chassis_type == 0, "chassis_type should match RunState")
	assert(bs.weapon_types.size() == 1, "S26.1: player BrottState built from Scout RunState carries the starter weapon")
	assert(4 in bs.weapon_types, "S26.1: Scout BrottState weapon is Plasma Cutter (4)")
	pass_count += 4

	print("test_run_state_init: %d passed, %d failed" % [pass_count, fail_count])
	if fail_count > 0:
		quit(1)
	else:
		quit(0)
