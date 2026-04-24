## S22.2c unit tests — per-league reflect-damage lever.
## 6 tests, 8 assertions per Gizmo §A.2.
## Register in test_runner.gd::SPRINT_TEST_FILES.
extends Node

var pass_count := 0
var fail_count := 0


func _ready() -> void:
	print("--- S22.2c unit tests ---")
	_test_reflect_bronze()
	_test_reflect_silver()
	_test_reflect_non_mesh()
	_test_reflect_unknown_league_fallback()
	_test_reflect_scrapyard_equals_bronze()
	_test_silver_sim_lower_reflect_than_bronze()
	print("S22.2c unit tests: %d passed, %d failed" % [pass_count, fail_count])
	if fail_count > 0:
		print("S22.2c FAIL")
	else:
		print("S22.2c PASS")


func _assert(cond: bool, msg: String) -> void:
	if cond:
		pass_count += 1
		print("  PASS: %s" % msg)
	else:
		fail_count += 1
		print("  FAIL: %s" % msg)


# T1: Bronze reflect == 5.0 (canonical; MUST NOT CHANGE)
func _test_reflect_bronze() -> void:
	var val := ArmorData.reflect_damage_for_league(ArmorData.ArmorType.REACTIVE_MESH, "bronze")
	_assert(val == 5.0, "T1: bronze reflect == 5.0 (got %s)" % val)


# T2: Silver reflect == 2.0
func _test_reflect_silver() -> void:
	var val := ArmorData.reflect_damage_for_league(ArmorData.ArmorType.REACTIVE_MESH, "silver")
	_assert(val == 2.0, "T2: silver reflect == 2.0 (got %s)" % val)


# T3: Non-reflect armor returns 0.0 regardless of league (2 assertions)
func _test_reflect_non_mesh() -> void:
	var val_silver := ArmorData.reflect_damage_for_league(ArmorData.ArmorType.PLATING, "silver")
	_assert(val_silver == 0.0, "T3a: PLATING at silver returns 0.0 (got %s)" % val_silver)
	var val_bronze := ArmorData.reflect_damage_for_league(ArmorData.ArmorType.NONE, "bronze")
	_assert(val_bronze == 0.0, "T3b: NONE at bronze returns 0.0 (got %s)" % val_bronze)


# T4: Unknown league falls back to bronze value (5.0)
func _test_reflect_unknown_league_fallback() -> void:
	var val := ArmorData.reflect_damage_for_league(ArmorData.ArmorType.REACTIVE_MESH, "diamond")
	_assert(val == 5.0, "T4: unknown league 'diamond' fallback == 5.0 (got %s)" % val)


# T5: Scrapyard reflect == bronze reflect (both 5.0; shared floor)
func _test_reflect_scrapyard_equals_bronze() -> void:
	var bronze_val := ArmorData.reflect_damage_for_league(ArmorData.ArmorType.REACTIVE_MESH, "bronze")
	var scrap_val := ArmorData.reflect_damage_for_league(ArmorData.ArmorType.REACTIVE_MESH, "scrapyard")
	_assert(bronze_val == scrap_val,
		"T5: scrapyard (%s) == bronze (%s)" % [scrap_val, bronze_val])


# T6: Silver-league reflect damage < Bronze-league reflect damage (directional invariant)
# Uses a proxy fight: same brotts, bronze vs silver, compare HP lost by player.
func _test_silver_sim_lower_reflect_than_bronze() -> void:
	var player_b := _make_mesh_brott(0, "bronze")
	var opp_b := _make_mesh_brott(1, "bronze")
	var bronze_hp_lost := _run_fight_hp_lost(player_b, opp_b)

	var player_s := _make_mesh_brott(0, "silver")
	var opp_s := _make_mesh_brott(1, "silver")
	var silver_hp_lost := _run_fight_hp_lost(player_s, opp_s)

	_assert(silver_hp_lost < bronze_hp_lost,
		"T6: silver HP-lost (%s) < bronze HP-lost (%s) — reflect degrades correctly" % [silver_hp_lost, bronze_hp_lost])


func _make_mesh_brott(team: int, league: String) -> BrottState:
	var b := BrottState.new()
	b.team = team
	b.chassis_type = ChassisData.ChassisType.SCOUT
	b.weapon_types = [WeaponData.WeaponType.MINIGUN] as Array[WeaponData.WeaponType]
	b.armor_type = ArmorData.ArmorType.REACTIVE_MESH
	b.module_types = [] as Array[ModuleData.ModuleType]
	b.stance = 0
	b.current_league = league
	b.setup()
	b.brain = BrottBrain.default_for_chassis(int(ChassisData.ChassisType.SCOUT))
	return b


## Run one fight and return total HP lost by team-0 brott (player).
func _run_fight_hp_lost(player: BrottState, opp: BrottState) -> float:
	var sim := CombatSim.new(42)
	player.position = Vector2(64, 256)
	opp.position = Vector2(448, 256)
	sim.add_brott(player)
	sim.add_brott(opp)
	var player_hp_start: float = player.hp
	for _t in 800:
		if sim.match_over:
			break
		sim.simulate_tick()
	return player_hp_start - player.hp
