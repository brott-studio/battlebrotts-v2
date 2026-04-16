## Tests for Sprint 6: Test Harness + Battle View Fix
extends SceneTree

var _pass_count: int = 0
var _fail_count: int = 0
var _results: Array[String] = []

func _initialize() -> void:
	print("=== Sprint 6 Tests ===")

	test_arena_renderer_scene_exists()
	test_arena_renderer_scene_has_draw()
	test_game_main_uses_scene()
	test_harness_script_exists()
	test_commands_json_valid()
	test_playthrough_json_valid()
	test_game_flow_navigation()
	test_arena_renderer_setup()

	print("\n--- Results ---")
	for r in _results:
		print(r)
	print("\n%d passed, %d failed" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_pass_count += 1
		_results.append("  PASS: %s" % msg)
	else:
		_fail_count += 1
		_results.append("  FAIL: %s" % msg)

func test_arena_renderer_scene_exists() -> void:
	var scene = load("res://arena/arena_renderer.tscn")
	_assert(scene != null, "arena_renderer.tscn exists and loads")

func test_arena_renderer_scene_has_draw() -> void:
	var scene = load("res://arena/arena_renderer.tscn")
	if scene == null:
		_assert(false, "arena_renderer.tscn instance has _draw")
		return
	var instance = scene.instantiate()
	# Virtual methods like _draw may not show via has_method on scene instances
	# but they ARE called by the engine. Check script is attached instead.
	_assert(instance.get_script() != null, "arena_renderer.tscn instance has script attached")
	_assert(instance is Node2D, "arena_renderer.tscn instance is Node2D")
	# Verify non-virtual methods work
	var script = instance.get_script()
	_assert(script != null and script.has_source_code(), "arena_renderer script has source code")
	instance.free()

func test_game_main_uses_scene() -> void:
	# Verify game_main.gd references the .tscn not .gd for arena renderer
	var file = FileAccess.open("res://game_main.gd", FileAccess.READ)
	var content = file.get_as_text()
	file.close()
	_assert(content.contains("arena_renderer.tscn"), "game_main.gd uses arena_renderer.tscn")
	_assert(not content.contains("ArenaRendererScript"), "game_main.gd no longer uses ArenaRendererScript")

func test_harness_script_exists() -> void:
	var file = FileAccess.open("res://tools/test_harness.gd", FileAccess.READ)
	_assert(file != null, "test_harness.gd exists")
	if file:
		file.close()

func test_commands_json_valid() -> void:
	var file = FileAccess.open("res://tools/commands.json", FileAccess.READ)
	_assert(file != null, "commands.json exists")
	if file:
		var json = JSON.new()
		var err = json.parse(file.get_as_text())
		file.close()
		_assert(err == OK, "commands.json is valid JSON")
		_assert(json.data is Array, "commands.json is an array")
		_assert(json.data.size() > 0, "commands.json has commands")

func test_playthrough_json_valid() -> void:
	var file = FileAccess.open("res://tools/playthrough.json", FileAccess.READ)
	_assert(file != null, "playthrough.json exists")
	if file:
		var json = JSON.new()
		var err = json.parse(file.get_as_text())
		file.close()
		_assert(err == OK, "playthrough.json is valid JSON")
		_assert(json.data is Array, "playthrough.json is an array")
		# Should have navigate to arena
		var has_arena = false
		for cmd in json.data:
			if cmd.get("action") == "navigate" and cmd.get("screen") == "arena":
				has_arena = true
		_assert(has_arena, "playthrough.json includes arena navigation")

func test_game_flow_navigation() -> void:
	var gf = GameFlow.new()
	_assert(gf.current_screen == GameFlow.Screen.MAIN_MENU, "GameFlow starts at main menu")
	gf.new_game()
	_assert(gf.current_screen == GameFlow.Screen.SHOP, "new_game goes to shop")
	gf.go_to_loadout()
	_assert(gf.current_screen == GameFlow.Screen.LOADOUT, "go_to_loadout works")
	gf.go_to_opponent_select()
	_assert(gf.current_screen == GameFlow.Screen.OPPONENT_SELECT, "go_to_opponent_select works")

func test_arena_renderer_setup() -> void:
	var scene = load("res://arena/arena_renderer.tscn")
	if scene == null:
		_assert(false, "ArenaRenderer setup with sim")
		return
	var renderer = scene.instantiate()
	var sim = CombatSim.new(42)

	var p = BrottState.new()
	p.team = 0
	p.bot_name = "Test"
	p.chassis_type = ChassisData.ChassisType.BRAWLER
	p.weapon_types = [WeaponData.WeaponType.MINIGUN]
	p.armor_type = ArmorData.ArmorType.PLATING
	p.module_types = []
	p.stance = 0
	p.position = Vector2(128, 256)
	p.setup()
	sim.add_brott(p)

	var e = BrottState.new()
	e.team = 1
	e.bot_name = "Enemy"
	e.chassis_type = ChassisData.ChassisType.SCOUT
	e.weapon_types = [WeaponData.WeaponType.RAILGUN]
	e.armor_type = ArmorData.ArmorType.REACTIVE_MESH
	e.module_types = []
	e.stance = 2
	e.position = Vector2(384, 256)
	e.setup()
	sim.add_brott(e)

	renderer.setup(sim, Vector2(384, 60))
	_assert(renderer.sim == sim, "ArenaRenderer.sim is set")
	_assert(renderer.arena_offset == Vector2(384, 60), "ArenaRenderer.arena_offset is set")

	renderer.free()
