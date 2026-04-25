## test_run_state_init.gd — S25.1 RunState initialization tests
extends SceneTree

func _init() -> void:
	var pass_count := 0
	var fail_count := 0

	# T1: Default construction
	var rs := RunState.new()
	assert(rs.retry_count == 3, "retry_count default should be 3")
	assert(rs.current_battle_index == 0, "current_battle_index default should be 0")
	assert(rs.battles_won == 0, "battles_won default should be 0")
	assert(rs.equipped_weapons.size() == 0, "equipped_weapons should be empty")
	assert(rs.equipped_armor == 0, "equipped_armor should be NONE (0)")
	assert(rs.equipped_modules.size() == 0, "equipped_modules should be empty")
	assert(rs._last_encounter_archetype == -1, "_last_encounter_archetype should be -1")
	pass_count += 7

	# T2: Chassis construction
	var rs2 := RunState.new(2, 42)  # Fortress, seed=42
	assert(rs2.equipped_chassis == 2, "equipped_chassis should be set from constructor")
	assert(rs2.seed == 42, "seed should be set from constructor")
	assert(rs2.equipped_weapons.size() == 0, "weapons empty on init even with chassis set")
	pass_count += 3

	# T3: build_player_brott produces valid BrottState
	var rs3 := RunState.new(0, 0)  # Scout
	var bs := rs3.build_player_brott()
	assert(bs != null, "build_player_brott should return a BrottState")
	assert(bs.team == 0, "player brott team should be 0")
	assert(bs.chassis_type == 0, "chassis_type should match RunState")
	assert(bs.weapon_types.size() == 0, "weapon_types should be empty (chassis-only start)")
	pass_count += 4

	print("test_run_state_init: %d passed, %d failed" % [pass_count, fail_count])
	if fail_count > 0:
		quit(1)
	else:
		quit(0)
