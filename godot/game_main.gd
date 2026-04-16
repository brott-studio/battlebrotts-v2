## Game main — orchestrates all screens and the full game flow
## Flow: Menu → Shop → Loadout → BrottBrain → Opponent → Arena → Result → loop
extends Node2D

const ARENA_OFFSET := Vector2(384, 60)
const TICKS_PER_SEC := 10

var game_flow: GameFlow
var sim: CombatSim
var player_brain: BrottBrain

# Preload arena renderer SCENE (not script!) so _draw() virtual is properly
# registered in web/HTML5 export. Script.new() can miss virtual methods.
var ArenaRendererScene = preload("res://arena/arena_renderer.tscn")

# Screens (created dynamically)
var current_ui: Control = null
var arena_renderer: Node2D = null
# ScrollContainer wrapper for UI screens
var ui_scroll: ScrollContainer = null

# Arena mode state
var speed_multiplier: float = 1.0
var tick_accumulator: float = 0.0
var in_arena: bool = false

# UI nodes for arena HUD
var player_info: Label
var enemy_info: Label
var time_label: Label
var speed_label: Label
var player_brott: BrottState
var enemy_brott: BrottState

func _ready() -> void:
	game_flow = GameFlow.new()
	_show_main_menu()

func _clear_screen() -> void:
	if ui_scroll:
		ui_scroll.queue_free()
		ui_scroll = null
	if current_ui:
		current_ui.queue_free()
		current_ui = null
	if arena_renderer:
		arena_renderer.queue_free()
		arena_renderer = null
	# Clear HUD labels
	for child in get_children():
		if child is Label:
			child.queue_free()
	in_arena = false

func _wrap_in_scroll(screen: Control) -> void:
	## Wraps a UI screen in a ScrollContainer so content can scroll if it
	## overflows the viewport. The ScrollContainer is full-viewport sized.
	ui_scroll = ScrollContainer.new()
	ui_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_scroll.size = get_viewport().get_visible_rect().size
	ui_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ui_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(ui_scroll)
	ui_scroll.add_child(screen)
	# Let screen expand vertically to fit content
	screen.custom_minimum_size.x = ui_scroll.size.x
	current_ui = screen

func _show_main_menu() -> void:
	_clear_screen()
	var menu := MainMenuScreen.new()
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wrap_in_scroll(menu)
	menu.new_game_pressed.connect(_on_new_game)

func _on_new_game() -> void:
	game_flow.new_game()
	player_brain = null
	_show_shop()

func _show_shop() -> void:
	_clear_screen()
	var shop := ShopScreen.new()
	shop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wrap_in_scroll(shop)
	shop.setup(game_flow.game_state)
	shop.continue_pressed.connect(_show_loadout)

func _show_loadout() -> void:
	_clear_screen()
	var loadout := LoadoutScreen.new()
	loadout.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wrap_in_scroll(loadout)
	loadout.setup(game_flow.game_state)
	loadout.continue_pressed.connect(_show_brottbrain)
	loadout.back_pressed.connect(_show_shop)

func _show_brottbrain() -> void:
	if not game_flow.game_state.brottbrain_unlocked:
		# Skip to opponent select in Scrapyard
		_show_opponent_select()
		return
	_clear_screen()
	var brain_screen := BrottBrainScreen.new()
	brain_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wrap_in_scroll(brain_screen)
	brain_screen.setup(game_flow.game_state, player_brain)
	brain_screen.continue_pressed.connect(func():
		player_brain = brain_screen.get_brain()
		_show_opponent_select()
	)
	brain_screen.back_pressed.connect(_show_loadout)

func _show_opponent_select() -> void:
	_clear_screen()
	var opp_screen := OpponentSelectScreen.new()
	opp_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wrap_in_scroll(opp_screen)
	opp_screen.setup(game_flow.game_state)
	opp_screen.opponent_selected.connect(_start_match)
	opp_screen.back_pressed.connect(_show_loadout)

func _start_match(opponent_index: int) -> void:
	_clear_screen()
	game_flow.selected_opponent_index = opponent_index
	
	# Build player brott
	player_brott = game_flow.game_state.build_brott()
	player_brott.position = Vector2(4 * 32.0, 8 * 32.0)
	if player_brain != null:
		player_brott.brain = player_brain
	else:
		player_brott.brain = BrottBrain.default_for_chassis(game_flow.game_state.equipped_chassis)
	
	# Build enemy brott
	enemy_brott = OpponentData.build_opponent_brott(game_flow.game_state.current_league, opponent_index)
	enemy_brott.position = Vector2(12 * 32.0, 8 * 32.0)
	
	# Create sim
	sim = CombatSim.new(randi())
	sim.add_brott(player_brott)
	sim.add_brott(enemy_brott)
	sim.on_match_end.connect(_on_match_end)
	
	# Instantiate from scene so _draw() virtual is properly registered in web export
	# (Script.new() and set_script() both fail to register _draw in HTML5 builds)
	arena_renderer = ArenaRendererScene.instantiate()
	add_child(arena_renderer)
	arena_renderer.setup(sim, ARENA_OFFSET)
	
	# Create HUD
	_create_arena_hud()
	
	in_arena = true
	speed_multiplier = 1.0
	tick_accumulator = 0.0

func _create_arena_hud() -> void:
	player_info = Label.new()
	player_info.position = Vector2(20, 10)
	player_info.size = Vector2(500, 30)
	add_child(player_info)
	
	enemy_info = Label.new()
	enemy_info.position = Vector2(700, 10)
	enemy_info.size = Vector2(500, 30)
	add_child(enemy_info)
	
	time_label = Label.new()
	time_label.position = Vector2(600, 10)
	time_label.size = Vector2(100, 30)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(time_label)
	
	speed_label = Label.new()
	speed_label.position = Vector2(600, 680)
	speed_label.size = Vector2(100, 30)
	add_child(speed_label)

func _on_match_end(winner_team: int) -> void:
	var won := winner_team == 0
	game_flow.finish_match(won)
	# Show result after a brief delay (let death animation play)
	await get_tree().create_timer(1.0).timeout
	_show_result()

func _show_result() -> void:
	_clear_screen()
	var result := ResultScreen.new()
	result.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wrap_in_scroll(result)
	result.setup(game_flow.game_state, game_flow.last_match_won, game_flow.last_bolts_earned)
	result.continue_pressed.connect(_show_shop)
	result.rematch_pressed.connect(func(): _start_match(game_flow.selected_opponent_index))

func _process(delta: float) -> void:
	if not in_arena or sim == null or sim.match_over:
		return
	
	tick_accumulator += delta * speed_multiplier
	var tick_delta := 1.0 / float(TICKS_PER_SEC)
	
	while tick_accumulator >= tick_delta:
		tick_accumulator -= tick_delta
		# Check slow-mo from death sequence
		var time_scale := 1.0
		if arena_renderer and arena_renderer.has_method("get_time_scale"):
			time_scale = arena_renderer.get_time_scale()
		if time_scale < 1.0:
			tick_accumulator -= tick_delta  # effectively halve tick rate during slow-mo
		sim.simulate_tick()
		if arena_renderer and arena_renderer.has_method("tick_visuals"):
			arena_renderer.tick_visuals()
	
	_update_arena_ui()
	if arena_renderer:
		arena_renderer.queue_redraw()

func _update_arena_ui() -> void:
	if player_info and player_brott:
		player_info.text = "PLAYER [%s] HP: %d/%d  EN: %d" % [
			player_brott.bot_name, int(player_brott.hp), player_brott.max_hp, int(player_brott.energy)]
	if enemy_info and enemy_brott:
		enemy_info.text = "ENEMY [%s] HP: %d/%d  EN: %d" % [
			enemy_brott.bot_name, int(enemy_brott.hp), enemy_brott.max_hp, int(enemy_brott.energy)]
	if time_label and sim:
		var secs: int = sim.tick_count / TICKS_PER_SEC
		time_label.text = "%d:%02d" % [secs / 60, secs % 60]
	if speed_label:
		speed_label.text = "Speed: %dx" % [int(speed_multiplier)]

func _unhandled_input(event: InputEvent) -> void:
	if not in_arena:
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: speed_multiplier = 1.0
			KEY_2: speed_multiplier = 2.0
			KEY_5: speed_multiplier = 5.0
