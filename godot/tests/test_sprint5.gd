## Sprint 5 test suite — Battle view rendering + UI viewport configuration
## Usage: godot --headless --script tests/test_sprint5.gd
extends SceneTree

var pass_count := 0
var fail_count := 0
var test_count := 0

func _init() -> void:
	print("=== BattleBrotts Sprint 5 Test Suite ===\n")
	
	# --- VIEWPORT CONFIGURATION TESTS ---
	_test_viewport_width()
	_test_viewport_height()
	_test_stretch_mode()
	_test_stretch_aspect()
	
	# --- ARENA RENDERER INSTANTIATION TESTS ---
	_test_arena_renderer_script_preloaded()
	_test_arena_renderer_is_node2d()
	_test_arena_renderer_has_draw_method()
	_test_arena_renderer_has_setup_method()
	_test_arena_renderer_has_tick_visuals()
	_test_arena_renderer_has_get_time_scale()
	
	# --- ARENA RENDERER SETUP TESTS ---
	_test_arena_renderer_setup_stores_sim()
	_test_arena_renderer_connects_damage_signal()
	
	# --- UI SCROLL WRAPPER TESTS ---
	_test_game_main_has_wrap_in_scroll()
	
	# Summary
	print("\n=== Results: %d passed, %d failed, %d total ===" % [pass_count, fail_count, test_count])
	if fail_count > 0:
		print("FAILED")
		quit(1)
	else:
		print("ALL PASSED")
		quit(0)

func _assert(condition: bool, name: String) -> void:
	test_count += 1
	if condition:
		pass_count += 1
		print("  PASS: %s" % name)
	else:
		fail_count += 1
		print("  FAIL: %s" % name)

# --- VIEWPORT CONFIGURATION ---

func _test_viewport_width() -> void:
	var settings := ProjectSettings.get_setting("display/window/size/viewport_width")
	_assert(settings == 1280, "Viewport width is 1280")

func _test_viewport_height() -> void:
	var settings := ProjectSettings.get_setting("display/window/size/viewport_height")
	_assert(settings == 720, "Viewport height is 720")

func _test_stretch_mode() -> void:
	var mode = ProjectSettings.get_setting("display/window/stretch/mode")
	_assert(mode == "canvas_items", "Stretch mode is canvas_items")

func _test_stretch_aspect() -> void:
	var aspect = ProjectSettings.get_setting("display/window/stretch/aspect")
	_assert(aspect == "keep", "Stretch aspect is 'keep' (maintains aspect ratio)")

# --- ARENA RENDERER INSTANTIATION ---

func _test_arena_renderer_script_preloaded() -> void:
	var script = load("res://arena/arena_renderer.gd")
	_assert(script != null, "arena_renderer.gd can be loaded")

func _test_arena_renderer_is_node2d() -> void:
	var script = load("res://arena/arena_renderer.gd")
	var instance = script.new()
	_assert(instance is Node2D, "ArenaRenderer instance is Node2D")
	instance.free()

func _test_arena_renderer_has_draw_method() -> void:
	var script = load("res://arena/arena_renderer.gd")
	var instance = script.new()
	_assert(instance.has_method("_draw"), "ArenaRenderer has _draw method")
	instance.free()

func _test_arena_renderer_has_setup_method() -> void:
	var script = load("res://arena/arena_renderer.gd")
	var instance = script.new()
	_assert(instance.has_method("setup"), "ArenaRenderer has setup method")
	instance.free()

func _test_arena_renderer_has_tick_visuals() -> void:
	var script = load("res://arena/arena_renderer.gd")
	var instance = script.new()
	_assert(instance.has_method("tick_visuals"), "ArenaRenderer has tick_visuals method")
	instance.free()

func _test_arena_renderer_has_get_time_scale() -> void:
	var script = load("res://arena/arena_renderer.gd")
	var instance = script.new()
	_assert(instance.has_method("get_time_scale"), "ArenaRenderer has get_time_scale method")
	instance.free()

# --- ARENA RENDERER SETUP ---

func _test_arena_renderer_setup_stores_sim() -> void:
	var script = load("res://arena/arena_renderer.gd")
	var renderer = script.new()
	var sim := CombatSim.new(42)
	renderer.setup(sim, Vector2(384, 60))
	_assert(renderer.sim == sim, "setup() stores sim reference")
	renderer.free()

func _test_arena_renderer_connects_damage_signal() -> void:
	var script = load("res://arena/arena_renderer.gd")
	var renderer = script.new()
	var sim := CombatSim.new(42)
	renderer.setup(sim, Vector2(384, 60))
	_assert(sim.on_damage.is_connected(renderer._on_damage), "setup() connects on_damage signal")
	renderer.free()

# --- UI SCROLL WRAPPER ---

func _test_game_main_has_wrap_in_scroll() -> void:
	var script = load("res://game_main.gd")
	var instance = script.new()
	_assert(instance.has_method("_wrap_in_scroll"), "game_main has _wrap_in_scroll method")
	instance.free()
