## Test harness for headless game testing
## Run: godot --headless --script res://tools/test_harness.gd
## Reads commands from tools/commands.json (or tools/playthrough.json via CLI arg)
## Saves screenshots to tools/screenshots/ and state log to tools/state_log.json
extends SceneTree

const TICKS_PER_SEC := 10
const SCREENSHOT_DIR := "res://tools/screenshots/"
const DEFAULT_COMMANDS := "res://tools/commands.json"
const STATE_LOG_PATH := "res://tools/state_log.json"

var game_flow: GameFlow
var sim: CombatSim
var arena_renderer: Node2D
var player_brott: BrottState
var enemy_brott: BrottState
var player_brain: BrottBrain

var commands: Array = []
var cmd_index: int = 0
var state_log: Array = []
var current_screen_name: String = "main_menu"
var viewport_size := Vector2i(1280, 720)

# Tick waiting
var wait_remaining: int = 0

func _init() -> void:
	# Ensure screenshot dir exists
	DirAccess.make_dir_recursive_absolute(SCREENSHOT_DIR.replace("res://", ""))

func _initialize() -> void:
	# Set up viewport
	root.content_scale_size = viewport_size
	root.size = viewport_size

	# Load commands
	var cmd_path := DEFAULT_COMMANDS
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.ends_with(".json"):
			cmd_path = arg
			break

	var file := FileAccess.open(cmd_path, FileAccess.READ)
	if file == null:
		printerr("ERROR: Cannot open command file: %s" % cmd_path)
		quit(1)
		return

	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		printerr("ERROR: Invalid JSON in %s: %s" % [cmd_path, json.get_error_message()])
		quit(1)
		return

	commands = json.data
	if not commands is Array:
		printerr("ERROR: Commands file must be a JSON array")
		quit(1)
		return

	# Initialize game flow
	game_flow = GameFlow.new()
	player_brain = null

	print("Test harness loaded %d commands from %s" % [commands.size(), cmd_path])
	_process_next_command()

func _process(delta: float) -> bool:
	# Handle tick waiting
	if wait_remaining > 0:
		if sim != null:
			sim.simulate_tick()
			if arena_renderer and arena_renderer.has_method("tick_visuals"):
				arena_renderer.tick_visuals()
		wait_remaining -= 1
		if wait_remaining <= 0:
			_log_state("wait_complete")
			_process_next_command()
		return false

	return false

func _process_next_command() -> void:
	if cmd_index >= commands.size():
		_finish()
		return

	var cmd: Dictionary = commands[cmd_index]
	cmd_index += 1
	var action: String = cmd.get("action", "")

	print("  [%d/%d] %s" % [cmd_index, commands.size(), action])

	match action:
		"navigate":
			_do_navigate(cmd.get("screen", ""))
			_process_next_command()
		"screenshot":
			_do_screenshot(cmd.get("file", "screenshot_%d.png" % cmd_index))
			_process_next_command()
		"action":
			_do_action(cmd.get("name", ""), cmd.get("params", {}))
			_process_next_command()
		"wait":
			var ticks: int = cmd.get("ticks", 10)
			wait_remaining = ticks
			_log_state("wait_start:%d" % ticks)
		"get_state":
			var state := _get_game_state()
			print("  State: %s" % JSON.stringify(state))
			_log_state("get_state")
			_process_next_command()
		_:
			printerr("  Unknown action: %s" % action)
			_process_next_command()

func _do_navigate(screen_name: String) -> void:
	current_screen_name = screen_name
	_clear_scene()

	match screen_name:
		"main_menu":
			game_flow.current_screen = GameFlow.Screen.MAIN_MENU
		"shop":
			game_flow.current_screen = GameFlow.Screen.SHOP
			# Auto-start new game if needed
			if game_flow.game_state == null:
				game_flow.new_game()
			_build_ui_screen(screen_name)
		"loadout":
			game_flow.current_screen = GameFlow.Screen.LOADOUT
			_build_ui_screen(screen_name)
		"brottbrain":
			game_flow.current_screen = GameFlow.Screen.BROTTBRAIN_EDITOR
			_build_ui_screen(screen_name)
		"opponent_select":
			game_flow.current_screen = GameFlow.Screen.OPPONENT_SELECT
			_build_ui_screen(screen_name)
		"arena":
			_start_arena_match()
		"result":
			game_flow.current_screen = GameFlow.Screen.RESULT
			_build_ui_screen(screen_name)
		_:
			printerr("  Unknown screen: %s" % screen_name)

	_log_state("navigate:%s" % screen_name)

func _build_ui_screen(screen_name: String) -> void:
	var screen: Control = null
	match screen_name:
		"shop":
			var shop := ShopScreen.new()
			shop.setup(game_flow.game_state)
			screen = shop
		"loadout":
			var loadout := LoadoutScreen.new()
			loadout.setup(game_flow.game_state)
			screen = loadout
		"brottbrain":
			var brain_screen := BrottBrainScreen.new()
			brain_screen.setup(game_flow.game_state, player_brain)
			screen = brain_screen
		"opponent_select":
			var opp := OpponentSelectScreen.new()
			opp.setup(game_flow.game_state)
			screen = opp
		"result":
			var result := ResultScreen.new()
			result.setup(game_flow.game_state, game_flow.last_match_won, game_flow.last_bolts_earned)
			screen = result
		"main_menu":
			screen = MainMenuScreen.new()

	if screen:
		screen.set_anchors_preset(Control.PRESET_FULL_RECT)
		screen.size = Vector2(viewport_size)
		root.add_child(screen)

func _start_arena_match() -> void:
	current_screen_name = "arena"
	game_flow.current_screen = GameFlow.Screen.ARENA

	# Ensure game state exists
	if game_flow.game_state == null:
		game_flow.new_game()

	# Build player brott
	player_brott = game_flow.game_state.build_brott()
	player_brott.position = Vector2(4 * 32.0, 8 * 32.0)
	if player_brain != null:
		player_brott.brain = player_brain
	else:
		player_brott.brain = BrottBrain.default_for_chassis(game_flow.game_state.equipped_chassis)

	# Build enemy — use first opponent if no selection
	var opp_idx := game_flow.selected_opponent_index
	if opp_idx < 0:
		opp_idx = 0
	enemy_brott = OpponentData.build_opponent_brott(game_flow.game_state.current_league, opp_idx)
	enemy_brott.position = Vector2(12 * 32.0, 8 * 32.0)

	# Create sim
	sim = CombatSim.new(42)  # deterministic seed for testing
	sim.add_brott(player_brott)
	sim.add_brott(enemy_brott)

	# Create arena renderer
	# Use scene instantiation (not Script.new()) so _draw() works in web export
	var ArenaRendererScene = load("res://arena/arena_renderer.tscn")
	arena_renderer = ArenaRendererScene.instantiate()
	root.add_child(arena_renderer)
	arena_renderer.setup(sim, Vector2(384, 60))

	# Create HUD labels
	var player_info := Label.new()
	player_info.position = Vector2(20, 10)
	player_info.text = "PLAYER [%s] HP: %d/%d" % [player_brott.bot_name, int(player_brott.hp), player_brott.max_hp]
	root.add_child(player_info)

	var enemy_info := Label.new()
	enemy_info.position = Vector2(700, 10)
	enemy_info.text = "ENEMY [%s] HP: %d/%d" % [enemy_brott.bot_name, int(enemy_brott.hp), enemy_brott.max_hp]
	root.add_child(enemy_info)

	print("  Arena match started: %s vs %s" % [player_brott.bot_name, enemy_brott.bot_name])

func _clear_scene() -> void:
	for child in root.get_children():
		if child is Window:
			continue
		child.queue_free()
	arena_renderer = null
	sim = null

func _do_screenshot(filename: String) -> void:
	# Force a render frame
	if arena_renderer:
		arena_renderer.queue_redraw()

	# In headless mode, viewport texture may not be available
	# Try to capture anyway - will log warning if it fails
	var vp = root.get_viewport()
	if vp == null:
		# No viewport yet - create placeholder
		var placeholder = Image.create(viewport_size.x, viewport_size.y, false, Image.FORMAT_RGBA8)
		placeholder.fill(Color(0.1, 0.1, 0.1))
		var path := SCREENSHOT_DIR + filename
		placeholder.save_png(path)
		print("  Placeholder saved: %s (no viewport)" % path)
		return

	var tex = vp.get_texture()
	var img: Image = null
	if tex != null:
		img = tex.get_image()

	if img == null:
		# Headless mode: no real rendering. Create placeholder.
		var placeholder = Image.create(viewport_size.x, viewport_size.y, false, Image.FORMAT_RGBA8)
		placeholder.fill(Color(0.1, 0.1, 0.1))
		var path := SCREENSHOT_DIR + filename
		placeholder.save_png(path)
		print("  Placeholder saved: %s (headless - no render)" % path)
		return

	var path := SCREENSHOT_DIR + filename
	var err := img.save_png(path)
	if err != OK:
		printerr("  WARNING: Failed to save screenshot to %s (error %d)" % [path, err])
	else:
		var is_blank := _check_if_blank(img)
		var blank_str := " [BLANK!]" if is_blank else ""
		print("  Screenshot saved: %s (%dx%d)%s" % [path, img.get_width(), img.get_height(), blank_str])

func _check_if_blank(img: Image) -> bool:
	## Check if image is essentially blank (single color)
	if img.get_width() == 0 or img.get_height() == 0:
		return true
	var first_pixel := img.get_pixel(0, 0)
	# Sample a grid of pixels
	var sample_count := 0
	var same_count := 0
	for y in range(0, img.get_height(), img.get_height() / 10):
		for x in range(0, img.get_width(), img.get_width() / 10):
			sample_count += 1
			if img.get_pixel(x, y).is_equal_approx(first_pixel):
				same_count += 1
	return same_count == sample_count

func _do_action(action_name: String, params: Dictionary) -> void:
	match action_name:
		"new_game":
			game_flow.new_game()
			player_brain = null
		"buy_item":
			# params: {"item_id": "..."}
			pass  # Would need shop integration
		"equip_item":
			# params: {"slot": "weapon", "item_id": "..."}
			pass  # Would need loadout integration
		"start_match":
			_start_arena_match()
		"set_speed":
			# params: {"speed": 2}
			pass  # Only relevant in real-time mode
		"select_opponent":
			var idx: int = params.get("index", 0)
			game_flow.selected_opponent_index = idx
		_:
			print("  Unknown action: %s" % action_name)
	_log_state("action:%s" % action_name)

func _get_game_state() -> Dictionary:
	var state := {
		"screen": current_screen_name,
		"bolts": game_flow.game_state.bolts if game_flow.game_state else 0,
		"league": game_flow.game_state.current_league if game_flow.game_state else "scrapyard",
	}

	if sim != null:
		state["sim"] = {
			"tick": sim.tick_count,
			"match_over": sim.match_over,
			"winner_team": sim.winner_team,
			"overtime": sim.overtime_active,
		}
	if player_brott != null:
		state["player"] = {
			"hp": player_brott.hp,
			"max_hp": player_brott.max_hp,
			"energy": player_brott.energy,
			"alive": player_brott.alive,
			"position": {"x": player_brott.position.x, "y": player_brott.position.y},
		}
	if enemy_brott != null:
		state["enemy"] = {
			"hp": enemy_brott.hp,
			"max_hp": enemy_brott.max_hp,
			"energy": enemy_brott.energy,
			"alive": enemy_brott.alive,
			"position": {"x": enemy_brott.position.x, "y": enemy_brott.position.y},
		}

	return state

func _log_state(event: String) -> void:
	state_log.append({
		"event": event,
		"cmd_index": cmd_index,
		"state": _get_game_state(),
	})

func _finish() -> void:
	# Save state log
	var file := FileAccess.open(STATE_LOG_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(state_log, "  "))
		file.close()
		print("State log saved to %s" % STATE_LOG_PATH)

	print("Test harness complete. %d commands executed." % commands.size())
	quit(0)
