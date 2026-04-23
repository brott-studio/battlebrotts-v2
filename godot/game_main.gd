## Game main — orchestrates all screens and the full game flow
## Flow: Menu → Shop → Loadout → BrottBrain → Opponent → Arena → Result → loop
extends Node2D

const ARENA_OFFSET := Vector2(384, 60)
const TICKS_PER_SEC := 10

# [S21.2 / #107] First-encounter overlay keys, parameterizing the S17.1-004
# FirstRunState scaffolding to 4 surfaces total. `energy_explainer` is the
# original S17.1-004 key (reused so existing player saves carry the dismissal
# forward into the real-flow combat entry). Keep these as flat strings; the
# autoload schema is keyless beyond the [seen] section.
const FE_KEY_SHOP := "shop_first_visit"
const FE_KEY_BROTTBRAIN := "brottbrain_first_visit"
const FE_KEY_OPPONENT := "opponent_first_visit"
const FE_KEY_ENERGY := "energy_explainer"

# [S21.2 / #107] Plain-language overlay copy per surface. <=2 short sentences,
# BrottBrain voice. Anchored top-center of the screen.
const FE_COPY := {
	"shop_first_visit": "🛍️ Welcome to the Shop. Spend Bolts on chassis, weapons, armor, and modules — then head to Loadout.",
	"brottbrain_first_visit": "🧠 BrottBrain teaches your bot what to do. Build WHEN → THEN rules from the tray below.",
	"opponent_first_visit": "⚔️ Pick an opponent to fight. Beating all 3 in this league unlocks the next tier.",
	"energy_explainer": "⚡ The blue bar is your Energy — it powers your weapons and regenerates over time.",
}
const FE_TICK_BUDGET := 360  # ~6 seconds @ 60 fps before auto-dismiss

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

## S14.1: when a league unlocks, stash the id here so the next
## ResultScreen → Shop transition shows the ceremony modal first.
var _pending_league_ceremony: String = ""
var _league_signal_connected: bool = false
var _concede_confirm: AcceptDialog = null

func _ready() -> void:
	game_flow = GameFlow.new()
	_connect_league_signal()
	# URL parameter routing for web builds (enables Playwright screen tests)
	if OS.has_feature("web"):
		var screen_param = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('screen')")
		if screen_param == "battle":
			_start_demo_match()
			return
		if screen_param == "shop":
			# S13.4: route ?screen=shop for shop card grid screenshot tests.
			game_flow.new_game()
			var bolts_param = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('bolts')")
			if typeof(bolts_param) == TYPE_STRING and String(bolts_param).is_valid_int():
				game_flow.game_state.bolts = int(bolts_param)
			_show_shop()
			return
	# Default: show main menu (also handles ?screen=menu and ?screen=dashboard)
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
	# [S21.2 / #107] Tear down any active first-encounter overlay so it does
	# not leak across screen transitions. Mark-seen still happens via the
	# dismiss path; here we just clean the orphan node.
	if _fe_overlay != null:
		_fe_overlay.queue_free()
		_fe_overlay = null
		_fe_ticks = 0
		_fe_active_key = ""
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
	_league_signal_connected = false
	_pending_league_ceremony = ""
	_connect_league_signal()
	_show_shop()

## S14.1: connect to GameState.league_unlocked so we can gate the next
## _show_shop call on a ceremony modal. GameState is re-instantiated on
## new_game(), so this must be called again after new_game().
func _connect_league_signal() -> void:
	if game_flow == null or game_flow.game_state == null:
		return
	if _league_signal_connected:
		return
	game_flow.game_state.league_unlocked.connect(_on_league_unlocked)
	_league_signal_connected = true

func _on_league_unlocked(league_id: String) -> void:
	_pending_league_ceremony = league_id

func _show_shop() -> void:
	# S14.1: if a league just unlocked, the ceremony modal gates shop reveal.
	# On Continue, modal calls GameState.advance_league() then emits
	# modal_dismissed; we then proceed into the shop normally.
	if _pending_league_ceremony != "":
		var ceremony := _pending_league_ceremony
		_pending_league_ceremony = ""
		var modal_scene: PackedScene = load("res://ui/league_complete_modal.tscn")
		var modal := modal_scene.instantiate()
		modal.setup(game_flow.game_state)
		add_child(modal)
		modal.modal_dismissed.connect(_show_shop)
		return
	_clear_screen()
	var shop := ShopScreen.new()
	shop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wrap_in_scroll(shop)
	shop.setup(game_flow.game_state)
	shop.continue_pressed.connect(_show_loadout)
	_maybe_spawn_first_encounter(FE_KEY_SHOP)

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
	_maybe_spawn_first_encounter(FE_KEY_BROTTBRAIN)

func _show_opponent_select() -> void:
	_clear_screen()
	var opp_screen := OpponentSelectScreen.new()
	opp_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wrap_in_scroll(opp_screen)
	opp_screen.setup(game_flow.game_state)
	opp_screen.opponent_selected.connect(_start_match)
	opp_screen.back_pressed.connect(_show_loadout)
	_maybe_spawn_first_encounter(FE_KEY_OPPONENT)

func _start_demo_match() -> void:
	## Start a hardcoded demo match for URL-param routing (?screen=battle).
	## Uses the same brotts as main.gd's _setup_match() for consistency.
	_clear_screen()
	
	# Player: Brawler with Shotgun + Minigun, Plating, Repair Nanites + Overclock
	player_brott = BrottState.new()
	player_brott.team = 0
	player_brott.bot_name = "Player Bot"
	player_brott.chassis_type = ChassisData.ChassisType.BRAWLER
	player_brott.weapon_types = [WeaponData.WeaponType.SHOTGUN, WeaponData.WeaponType.MINIGUN]
	player_brott.armor_type = ArmorData.ArmorType.PLATING
	player_brott.module_types = [ModuleData.ModuleType.REPAIR_NANITES, ModuleData.ModuleType.OVERCLOCK]
	player_brott.stance = 0
	player_brott.position = Vector2(4 * 32.0, 8 * 32.0)
	player_brott.setup()
	
	# Enemy: Scout with Railgun + Plasma Cutter, Reactive Mesh
	enemy_brott = BrottState.new()
	enemy_brott.team = 1
	enemy_brott.bot_name = "Enemy Bot"
	enemy_brott.chassis_type = ChassisData.ChassisType.SCOUT
	enemy_brott.weapon_types = [WeaponData.WeaponType.RAILGUN, WeaponData.WeaponType.PLASMA_CUTTER]
	enemy_brott.armor_type = ArmorData.ArmorType.REACTIVE_MESH
	enemy_brott.module_types = [ModuleData.ModuleType.AFTERBURNER, ModuleData.ModuleType.SHIELD_PROJECTOR, ModuleData.ModuleType.SENSOR_ARRAY]
	enemy_brott.stance = 2
	enemy_brott.position = Vector2(12 * 32.0, 8 * 32.0)
	enemy_brott.setup()
	
	# Create sim
	sim = CombatSim.new(42)  # deterministic seed
	sim.add_brott(player_brott)
	sim.add_brott(enemy_brott)
	sim.on_match_end.connect(_on_match_end)
	
	# Instantiate arena renderer from scene (KB: no set_script/Script.new in web)
	arena_renderer = ArenaRendererScene.instantiate()
	add_child(arena_renderer)
	arena_renderer.setup(sim, ARENA_OFFSET)
	
	# Create HUD
	_create_arena_hud()
	
	in_arena = true
	speed_multiplier = 1.0
	tick_accumulator = 0.0

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
	enemy_brott = OpponentData.build_opponent_brott(game_flow.game_state.current_league, opponent_index, game_flow.game_state)
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

	# S14.1: concede pill — tucked top-right, low-contrast. No pause menu.
	# Two-step confirm: tap → "Throw in the wrench? Yes / No" → Yes applies loss.
	var concede := Button.new()
	concede.text = "Concede"
	concede.name = "ConcedeButton"
	concede.position = Vector2(1180, 10)
	concede.size = Vector2(80, 24)
	concede.modulate = Color(1, 1, 1, 0.55)
	concede.flat = true
	concede.pressed.connect(_on_concede_pressed)
	add_child(concede)
	# [S21.2 / #107] Combat-entry energy explainer — reuses the S17.1-004
	# `energy_explainer` key so any prior demo dismissal carries forward.
	_maybe_spawn_first_encounter(FE_KEY_ENERGY)

func _on_concede_pressed() -> void:
	if not in_arena or sim == null or sim.match_over:
		return
	if _concede_confirm != null and is_instance_valid(_concede_confirm):
		return
	_concede_confirm = AcceptDialog.new()
	_concede_confirm.dialog_text = "Throw in the wrench?"
	_concede_confirm.title = "Concede"
	_concede_confirm.ok_button_text = "Yes"
	_concede_confirm.add_cancel_button("No")
	_concede_confirm.confirmed.connect(_concede_fight)
	_concede_confirm.canceled.connect(_on_concede_cancel)
	_concede_confirm.close_requested.connect(_on_concede_cancel)
	add_child(_concede_confirm)
	_concede_confirm.popup_centered()

func _on_concede_cancel() -> void:
	if _concede_confirm != null and is_instance_valid(_concede_confirm):
		_concede_confirm.queue_free()
	_concede_confirm = null

## S14.1: concede = reuse existing loss path. We drive CombatSim into the
## match-over state with the enemy team as winner; _on_match_end handles
## bolts/progression/result screen identically to HP-zero loss.
func _concede_fight() -> void:
	_concede_confirm = null
	if not in_arena or sim == null or sim.match_over:
		return
	var enemy_team := 1 if (enemy_brott != null and enemy_brott.team == 1) else 1
	sim.match_over = true
	_on_match_end(enemy_team)

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
	# [S21.2 / #107] Tick-budget auto-dismiss for any active first-encounter
	# overlay (parameterized version of S17.1-004's _energy_explainer_ticks).
	if _fe_overlay != null:
		_fe_ticks += 1
		if _fe_ticks >= FE_TICK_BUDGET:
			_dismiss_first_encounter()
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

# [S21.2 / #107] Generic first-encounter overlay scaffolding. Parameterized
# from S17.1-004's _spawn_energy_explainer pattern. Spawns a dismiss-only
# panel anchored top-center if FirstRunState[key] is unset; marks-seen on
# either button press or tick-budget expiry. Only one overlay active at a
# time — repeat calls while one is up are no-ops.
var _fe_overlay: Control = null
var _fe_ticks: int = 0
var _fe_active_key: String = ""

func _maybe_spawn_first_encounter(key: String) -> void:
	if _fe_overlay != null:
		return
	if not FE_COPY.has(key):
		push_warning("[FirstEncounter] no copy registered for key=%s" % key)
		return
	if not Engine.has_singleton("FirstRunState") and get_node_or_null("/root/FirstRunState") == null:
		# Headless/test path with no autoload — silently skip.
		return
	var frs: Node = get_node_or_null("/root/FirstRunState")
	if frs == null:
		return
	if frs.call("has_seen", key):
		return
	_spawn_first_encounter(key, String(FE_COPY[key]))

func _spawn_first_encounter(key: String, copy: String) -> void:
	var panel := Panel.new()
	panel.name = "FirstEncounterOverlay_" + key
	panel.position = Vector2(330, 60)
	panel.size = Vector2(620, 100)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	
	var body := Label.new()
	body.name = "Body"
	body.text = copy
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.position = Vector2(16, 12)
	body.size = Vector2(580, 56)
	panel.add_child(body)
	
	var btn := Button.new()
	btn.name = "GotItButton"
	btn.text = "Got it!"
	btn.position = Vector2(508, 64)
	btn.size = Vector2(96, 28)
	btn.pressed.connect(_on_first_encounter_dismissed)
	panel.add_child(btn)
	
	add_child(panel)
	_fe_overlay = panel
	_fe_ticks = 0
	_fe_active_key = key

func _dismiss_first_encounter() -> void:
	if _fe_overlay == null:
		return
	var frs: Node = get_node_or_null("/root/FirstRunState")
	if frs != null and _fe_active_key != "":
		frs.call("mark_seen", _fe_active_key)
	_fe_overlay.queue_free()
	_fe_overlay = null
	_fe_ticks = 0
	_fe_active_key = ""

func _on_first_encounter_dismissed() -> void:
	_dismiss_first_encounter()
