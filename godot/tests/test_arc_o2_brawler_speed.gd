## test_arc_o2_brawler_speed.gd
## [Arc O.2] SO.2-001–004: Brawler chassis speed halved (120→60 px/s) with enemy speed_override.
## Usage: godot --headless --path godot/ --script res://tests/test_arc_o2_brawler_speed.gd

extends SceneTree

var pass_count := 0
var fail_count := 0
var test_count := 0

func _initialize() -> void:
	print("=== test_arc_o2_brawler_speed ===\n")
	_test_o2_brawler_chassis_speed()
	_test_o2_scout_unchanged()
	_test_o2_fortress_unchanged()
	_test_o2_brawler_rush_speed_override()
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

func _test_o2_brawler_chassis_speed() -> void:
	print("--- SO.2-001: Brawler chassis speed/accel/decel halved ---")
	var brawler := ChassisData.CHASSIS[ChassisData.ChassisType.BRAWLER]
	_assert(absf(float(brawler["speed"]) - 60.0) < 0.01, "Brawler speed == 60.0 px/s (O.2: was 120.0)")
	_assert(absf(float(brawler["accel"]) - 120.0) < 0.01, "Brawler accel == 120.0 px/s² (O.2: was 240.0)")
	_assert(absf(float(brawler["decel"]) - 180.0) < 0.01, "Brawler decel == 180.0 px/s² (O.2: was 360.0)")

func _test_o2_scout_unchanged() -> void:
	print("--- SO.2-002: Scout speed unchanged ---")
	var scout := ChassisData.CHASSIS[ChassisData.ChassisType.SCOUT]
	_assert(absf(float(scout["speed"]) - 220.0) < 0.01, "Scout speed == 220.0 px/s (unchanged by O.2)")

func _test_o2_fortress_unchanged() -> void:
	print("--- SO.2-003: Fortress speed unchanged ---")
	var fortress := ChassisData.CHASSIS[ChassisData.ChassisType.FORTRESS]
	_assert(absf(float(fortress["speed"]) - 60.0) < 0.01, "Fortress speed == 60.0 px/s (unchanged by O.2)")

func _test_o2_brawler_rush_speed_override() -> void:
	print("--- SO.2-004: brawler_rush enemy spec has speed_override == 120.0 ---")
	## compose_encounter resolves the enemy template and forwards override fields.
	## We verify the composed spec carries speed_override=120.0 so the enemy Brawler
	## keeps its original 120 px/s speed despite the chassis_data player change.
	var specs := OpponentLoadouts.compose_encounter("brawler_rush", 1, null)
	_assert(specs.size() > 0, "brawler_rush compose_encounter returns at least one spec")
	if specs.size() > 0:
		var spec: Dictionary = specs[0]
		_assert("speed_override" in spec, "brawler_rush spec has 'speed_override' field")
		if "speed_override" in spec:
			_assert(absf(float(spec["speed_override"]) - 120.0) < 0.01,
				"brawler_rush speed_override == 120.0 (enemy retains pre-O.2 speed)")
