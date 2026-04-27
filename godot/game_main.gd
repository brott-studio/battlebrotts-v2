## Game main — orchestrates all screens and the full game flow
## Flow: Menu → Shop → Loadout → BrottBrain → Opponent → Arena → Result → loop
extends Node2D

## S22.2c: emitted after a league-ceremony modal is dismissed. Lets analytics
## and tutorial hooks listen without coupling to the modal lifecycle.
signal ceremony_complete(league_id: String)

const ARENA_OFFSET := Vector2(384, 60)
const TICKS_PER_SEC := 10

# [S21.4 / #106] Minimum interval between random-event popups (seconds).
# No magic numbers inline — all dampening checks reference this constant.
const RANDOM_EVENT_MIN_INTERVAL_SEC := 15.0

# [S21.2 / #107] First-encounter overlay keys, parameterizing the S17.1-004
# FirstRunState scaffolding to 4 surfaces total. `energy_explainer` is the
# original S17.1-004 key (reused so existing player saves carry the dismissal
# forward into the real-flow combat entry). Keep these as flat strings; the
# autoload schema is keyless beyond the [seen] section.
const FE_KEY_RUN_START := "run_start_first_visit"      ## S25.8: roguelike run start intro (was FE_KEY_SHOP)
const FE_KEY_FIRST_REWARD_PICK := "first_reward_pick"  ## S25.8: first reward pick intro (was FE_KEY_BROTTBRAIN)
const FE_KEY_FIRST_RETRY_PROMPT := "first_retry_prompt" ## S25.8: first retry prompt intro (was FE_KEY_OPPONENT)
const FE_KEY_ENERGY := "energy_explainer"

# [S21.3 / #245 / #107] Arena onboarding keys — in-arena HUD-element overlays.
# Fixed order: click_controls → energy → combatants → time → concede (one per arena entry).
# `energy_explainer` reuses the S17.1-004 key for save-carryforward.
const FE_KEY_CLICK_CONTROLS := "click_controls_explainer"  ## S25.8: two-click affordances (first in sequence)
const FE_KEY_COMBATANTS := "combatants_explainer"
const FE_KEY_TIME := "time_explainer"
const FE_KEY_CONCEDE := "concede_explainer"

# Fixed arena sequence — order is invariant, do not reorder.
# S25.8: click_controls_explainer prepended as the first arena overlay.
const ARENA_SEQUENCE: Array = ["click_controls_explainer", "energy_explainer", "combatants_explainer", "time_explainer", "concede_explainer"]

# ~12 s at 60 fps for arena overlays (vs 6 s for screen overlays).
const ARENA_FE_TICK_BUDGET := 720

# [S21.2 / #107] Plain-language overlay copy per surface. <=2 short sentences,
# BrottBrain voice. Screen overlays anchored top-center; arena overlays use
# ARENA_FE_COPY (below).
const FE_COPY := {
	"run_start_first_visit": "⚔️ A new run begins. Pick your chassis — that's your bot's body. Weapons and armor come from rewards you earn in battle.",
	"first_reward_pick": "🎁 You won! Pick one reward to add to your build. It stays with you for the whole run.",
	"first_retry_prompt": "💀 Your Brott went down. You have retries — use them to try that battle again with the same build. No retries left? The run is over.",
	"energy_explainer": "⚡ The blue bar is your Energy — it powers your weapons and regenerates over time.",
}
const FE_TICK_BUDGET := 360  # ~6 seconds @ 60 fps before auto-dismiss (screen overlays)

# [S21.3 / #245 / #107] Arena onboarding copy — 4 keys in ARENA_SEQUENCE order.
# Kept separate from FE_COPY to preserve the S21.2 FE_COPY.size()==4 invariant.
const ARENA_FE_COPY := {
	"click_controls_explainer": "👆 Click the arena to send your Brott somewhere. Click an enemy to target them. Or just watch — it'll fight on its own.",
	"energy_explainer": "⚡ The blue bar is your Energy — it powers your weapons and regenerates over time.",
	"combatants_explainer": "⚔️ These panels show each fighter's HP and Energy. The first to reach zero loses.",
	"time_explainer": "⏱️ The match timer counts up. Damage leader wins if neither bot is destroyed before 100s.",
	"concede_explainer": "🏳️ Tap Concede to forfeit the fight. Use it when the match is clearly lost.",
}

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

# [S21.4 / #106] Random-event popup controller state.
# _re_popup: active popup node (null when none visible).
# _re_last_shown_time: Time.get_ticks_msec() / 1000.0 at last popup show; -inf on reset.
# Used for dampening: a second trigger within RANDOM_EVENT_MIN_INTERVAL_SEC is suppressed.
var _re_popup: Control = null
var _re_last_shown_time: float = -INF

# [S21.5] Popup whoosh SFX — reused long-lived player to avoid node leaks.
const POPUP_WHOOSH: AudioStream = preload("res://assets/audio/sfx/popup_whoosh.ogg")
var _popup_whoosh_player: AudioStreamPlayer = null

# [S24.3] Combat SFX — hit (on_damage) + projectile launch (on_projectile_spawned).
const HIT_SFX: AudioStream = preload("res://assets/audio/sfx/hit.ogg")
const PROJECTILE_LAUNCH_SFX: AudioStream = preload("res://assets/audio/sfx/projectile_launch.ogg")
var _hit_sfx_player: AudioStreamPlayer = null
var _projectile_launch_sfx_player: AudioStreamPlayer = null
# Threshold guard: only play hit SFX for meaningful damage (≥5.0) to avoid
# boundary-tick / splash / reflect spam (risk register §5 risk #1).
const HIT_SFX_MIN_AMOUNT: float = 5.0

# [S24.4] Combat SFX — critical hit + death.
const CRITICAL_HIT_SFX: AudioStream = preload("res://assets/audio/sfx/critical_hit.ogg")
const DEATH_SFX: AudioStream = preload("res://assets/audio/sfx/death.ogg")
var _critical_hit_sfx_player: AudioStreamPlayer = null
var _death_sfx_player: AudioStreamPlayer = null
var _death_sfx_cooldown_active: bool = false  # guard: prevent mass-death frame spam

func _ready() -> void:
	game_flow = GameFlow.new()
	_connect_league_signal()
	_apply_audio_settings()  # [S21.5] apply persisted mute on canonical main-flow entry
	# [S24.3] Initialize combat SFX players once at scene load.
	_init_combat_sfx_players()
	# URL parameter routing for web builds (enables Playwright screen tests)
	if OS.has_feature("web"):
		var screen_param = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('screen')")
		if screen_param == "battle":
			_start_demo_match()
			return
		## [S26.3] Test hook: drive the roguelike chassis-pick → battle path
		## directly via URL param so headless CI smoke tests exercise the same
		## code path that produced the blank-screen P0. ?screen=run_battle&chassis=N
		## bypasses the menu but still invokes _on_chassis_picked (the buggy
		## path pre-S26.1). Defaults to chassis=0 (BRAWLER) when omitted.
		if screen_param == "run_battle":
			var chassis_param = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('chassis')")
			var chassis_idx := 0
			if chassis_param != null and str(chassis_param) != "":
				chassis_idx = int(str(chassis_param))
				if chassis_idx < 0 or chassis_idx > 2:
					chassis_idx = 0
			print("[S26.3] run_battle URL hook — chassis=%d" % chassis_idx)
			_on_chassis_picked(chassis_idx)
			return
		## [S(I).6] Test hook: land directly on RunStartScreen via ?screen=run_start.
		## bb_test.click_chassis(N) then drives the chassis-pick → arena flow.
		if screen_param == "run_start":
			print("[S(I).6] run_start URL hook")
			_show_run_start()
			return
	# Default: show main menu (also handles ?screen=menu and ?screen=dashboard)
	_show_main_menu()

# [S21.5] Mirrors main.gd — applies persisted mute state from FirstRunState to
# the Master bus (bus 0) on scene load. Called from _ready() so mute state is
# honoured on the canonical game flow (Menu → Shop → … → Arena).
func _apply_audio_settings() -> void:
	var frs := get_node_or_null("/root/FirstRunState")
	if frs == null:
		return
	var muted: bool = frs.call("get_audio_muted")
	AudioServer.set_bus_mute(0, muted)
	# [S24.2] Apply persisted bus volumes (additive — mute logic above unchanged).
	AudioServer.set_bus_volume_db(0, frs.call("get_master_db"))
	AudioServer.set_bus_volume_db(1, frs.call("get_sfx_db"))
	AudioServer.set_bus_volume_db(2, frs.call("get_music_db"))

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
	# [S21.3 / #245] Tear down any active arena first-encounter overlay.
	if _arena_fe_overlay != null:
		_arena_fe_overlay.queue_free()
		_arena_fe_overlay = null
		_arena_fe_ticks = 0
		_arena_fe_active_key = ""
		speed_multiplier = _arena_fe_pre_slowdown_speed
	# [S21.4 / #106] Tear down any visible random-event popup on arena exit.
	if _re_popup != null and is_instance_valid(_re_popup):
		_re_popup.queue_free()
	_re_popup = null
	_re_last_shown_time = -INF
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
	## S25.7: Continue Run if active run exists
	if game_flow.has_active_run():
		var battle_num := game_flow.run_state.current_battle_index + 1
		menu.setup_menu(true, battle_num)
		menu.continue_run_pressed.connect(_on_continue_run)

## [S26.1-003] Visible error screen for catastrophic run-start failures.
## Replaces the old silent-fail-as-blank-screen path. Always paired with
## a push_error() so CI / browser console captures the underlying cause.
func _show_run_error(msg: String) -> void:
	_clear_screen()
	var lbl := Label.new()
	lbl.text = msg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.position = Vector2(290, 300)
	lbl.size = Vector2(700, 60)
	add_child(lbl)
	var btn := Button.new()
	btn.text = "← Back to Menu"
	btn.position = Vector2(515, 380)
	btn.size = Vector2(250, 50)
	btn.pressed.connect(_show_main_menu)
	add_child(btn)

func _on_continue_run() -> void:
	## S25.7: Resume run from last_screen
	var ls: int = game_flow.run_state.last_screen if game_flow.run_state != null else -1
	match ls:
		GameFlow.Screen.REWARD_PICK:
			_show_reward_pick()
		GameFlow.Screen.RETRY_PROMPT:
			_show_retry_prompt()
		GameFlow.Screen.ARENA, GameFlow.Screen.BOSS_ARENA:
			## Mid-arena resume → treat as retry prompt (can't restore sim)
			_show_retry_prompt()
		_:
			## Unknown or RUN_START → go to run start screen
			_show_run_start()

## S25.7: Save current screen to run_state.last_screen while run is active.
func _save_last_screen() -> void:
	if game_flow.has_active_run():
		game_flow.run_state.last_screen = game_flow.current_screen

func _on_new_game() -> void:
	## S25.1: new-game now starts the roguelike run flow.
	## Old league/BrottBrain state cleared; GameState left dormant.
	player_brain = null
	_pending_league_ceremony = ""
	_show_run_start()

func _show_run_start() -> void:
	_clear_screen()
	game_flow.current_screen = GameFlow.Screen.RUN_START
	_save_last_screen()
	var run_start := RunStartScreen.new()
	run_start.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wrap_in_scroll(run_start)
	run_start.setup(0)  # time-based seed for production
	run_start.start_run_requested.connect(_on_chassis_picked)
	_maybe_spawn_first_encounter(FE_KEY_RUN_START)  ## S25.8: roguelike run-start intro

func _on_chassis_picked(chassis_type: int) -> void:
	## [S26.7 diagnostic] Confirm signal reached game_main and chassis_type is sane.
	print("[S26.7] _on_chassis_picked: chassis_type=", chassis_type)
	game_flow.start_run(chassis_type)
	## S25.6: Pre-generate encounter schedule, set first encounter
	var archetype_id := OpponentLoadouts.archetype_for(0, game_flow.run_state)
	print("[S26.7] _on_chassis_picked: archetype_id='", archetype_id, "' run_state.equipped_chassis=", game_flow.run_state.equipped_chassis, " weapons=", game_flow.run_state.equipped_weapons)
	var arena_seed := game_flow.run_state.seed * 31
	game_flow.run_state.set_encounter(archetype_id, OpponentLoadouts.difficulty_for_battle(0), arena_seed)
	_start_roguelike_match()

func _start_roguelike_match() -> void:
	## [S26.7 diagnostic] Confirm we reached match start.
	var rs_status := "null" if game_flow.run_state == null else "ok chassis=" + str(game_flow.run_state.equipped_chassis)
	print("[S26.7] _start_roguelike_match: ENTERED run_state=", rs_status)
	## [S26.1-003] Hard error surface: never enter the arena with a null
	## run_state. Pre-S26.1 a silent-fail here rendered as a blank screen
	## (battle started, sim couldn't build a player, view stayed empty).
	_clear_screen()
	if game_flow.run_state == null:
		push_error("[S26.1] _start_roguelike_match called with null run_state — showing error screen")
		_show_run_error("Run failed to start. Please try again.")
		return

	## S25.6: Ensure encounter is set (may already be set on retry path).
	## If unset, derive via the encounter generator + tier mapping.
	if game_flow.run_state.current_encounter["archetype_id"] == "":
		var idx := game_flow.run_state.current_battle_index
		var archetype_id := OpponentLoadouts.archetype_for(idx, game_flow.run_state)
		var tier := OpponentLoadouts.difficulty_for_battle(idx)
		var arena_seed := game_flow.run_state.seed * 31 + idx
		game_flow.run_state.set_encounter(archetype_id, tier, arena_seed)
	## S25.1: Stub arena — builds player BrottState inline from RunState.
	## Enemy uses OpponentData bronze/0 as stub; S25.4/S25.6 replaces.

	# Build player BrottState inline from RunState (do NOT use game_state.build_brott())
	player_brott = game_flow.run_state.build_player_brott()
	player_brott.position = Vector2(4 * 32.0, 8 * 32.0)
	player_brott.brain = BrottBrain.default_for_chassis(game_flow.run_state.equipped_chassis)

	## S25.7: Spawn enemies from encounter archetype (replaces stub).
	var arch_id: String = game_flow.run_state.current_encounter.get("archetype_id", "standard_duel")
	var battle_idx: int = game_flow.run_state.current_battle_index
	var enemy_specs: Array[Dictionary] = OpponentLoadouts.compose_encounter(arch_id, battle_idx, game_flow.run_state)
	print("[S26.7] _start_roguelike_match: arch_id='", arch_id, "' battle_idx=", battle_idx, " enemy_specs.size=", enemy_specs.size())

	if enemy_specs.is_empty():
		push_warning("[S25.7] compose_encounter returned empty for arch=%s idx=%d — falling back to single standard duel" % [arch_id, battle_idx])
		enemy_specs = OpponentLoadouts.compose_encounter("standard_duel", battle_idx, game_flow.run_state)

	var positions := EncounterSpawn.positions_for(enemy_specs.size())

	# Create sim
	var arena_seed_val: int = game_flow.run_state.current_encounter.get("arena_seed", randi())
	sim = CombatSim.new(arena_seed_val)
	sim.add_brott(player_brott)

	## Spawn each enemy from archetype specs
	for i in range(enemy_specs.size()):
		var spec: Dictionary = enemy_specs[i]
		var ebrott := BrottState.new()
		ebrott.team = 1
		ebrott.bot_name = "Enemy %d" % (i + 1)
		ebrott.chassis_type = spec.get("chassis", 0)
		for wt in spec.get("weapons", []):
			ebrott.weapon_types.append(wt)
		ebrott.armor_type = spec.get("armor", 0)
		for mt in spec.get("modules", []):
			ebrott.module_types.append(mt)
		ebrott.setup()
		## Apply archetype HP override
		var spec_hp: int = spec.get("hp", ebrott.max_hp)
		if spec_hp > 0:
			ebrott.max_hp = spec_hp
			ebrott.hp = float(spec_hp)
		ebrott.position = positions[i] if i < positions.size() else Vector2(12 * 32.0, 8 * 32.0)
		## Brain per enemy
		var chassis_t: int = spec.get("chassis", 0)
		ebrott.brain = BrottBrain.default_for_chassis(chassis_t)
		if ebrott.brain == null:
			push_warning("[S25.7] default_for_chassis(%d) returned null — using aggressive fallback" % chassis_t)
			ebrott.brain = BrottBrain.new()
			ebrott.brain.default_stance = 0
		## S25.9: Override with boss AI if this is the boss encounter.
		if arch_id == "boss":
			ebrott.brain = BrottBrain.boss_ai()
		sim.add_brott(ebrott)

	## Keep enemy_brott for HUD reference (last enemy spawned)
	enemy_brott = sim.brotts[sim.brotts.size() - 1] if sim.brotts.size() > 1 else null
	sim.on_match_end.connect(_on_roguelike_match_end)
	sim.on_damage.connect(_on_combat_damage)
	sim.on_projectile_spawned.connect(_on_projectile_spawned)
	sim.on_death.connect(_on_brott_death)

	arena_renderer = ArenaRendererScene.instantiate()
	add_child(arena_renderer)
	arena_renderer.setup(sim, ARENA_OFFSET)
	print("[S26.7] _start_roguelike_match: arena_renderer added, sim.brotts.size=", sim.brotts.size())
	# S25.2: Wire player brain into renderer for click dispatch.
	if player_brott != null and player_brott.brain != null and arena_renderer.has_method("set_player_brain"):
		arena_renderer.set_player_brain(player_brott.brain)

	_create_arena_hud()

	in_arena = true
	speed_multiplier = 1.0
	tick_accumulator = 0.0

func _on_roguelike_match_end(winner_team: int) -> void:
	## S25.7: Debug log for multi-enemy match verification
	if sim != null:
		var alive_per_team := {0: 0, 1: 0}
		for b in sim.brotts:
			if b.alive:
				alive_per_team[b.team] = alive_per_team.get(b.team, 0) + 1
		print("[S25.7] match_end: winner=%d alive=%s" % [winner_team, str(alive_per_team)])
	var won := winner_team == 0
	await get_tree().create_timer(1.0).timeout
	if won:
		## S25.7: Boss win (battle 15 / index 14) → RUN_COMPLETE, not reward pick
		if game_flow.current_screen == GameFlow.Screen.BOSS_ARENA:
			game_flow.run_state.battles_won += 1
			_show_run_complete()
		else:
			game_flow.advance_battle()
			_show_reward_pick()
	else:
		_show_retry_prompt()

func _show_reward_pick() -> void:
	_clear_screen()
	game_flow.current_screen = GameFlow.Screen.REWARD_PICK
	_save_last_screen()
	var reward := RewardPickScreen.new()
	reward.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wrap_in_scroll(reward)
	reward.setup(game_flow.run_state)
	reward.picked.connect(func(_item): _advance_to_next_battle())
	_maybe_spawn_first_encounter(FE_KEY_FIRST_REWARD_PICK)  ## S25.8: first reward pick intro

func _show_retry_prompt() -> void:
	_clear_screen()
	game_flow.current_screen = GameFlow.Screen.RETRY_PROMPT
	_save_last_screen()
	var retry := RetryPromptScreen.new()
	retry.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wrap_in_scroll(retry)
	retry.setup(game_flow.run_state)
	retry.retry_chosen.connect(_start_roguelike_match)
	retry.accept_loss.connect(_show_brott_down)  ## S25.8: GDD §A.5 — loss → BROTT DOWN (end_run() called from "New Run" button)
	_maybe_spawn_first_encounter(FE_KEY_FIRST_RETRY_PROMPT)  ## S25.8: first retry prompt intro

## S25.8: Terminal loss screen (GDD §A.5 — both loss paths converge here).
## end_run() is NOT called on entry — BROTT DOWN needs run_state alive for stats.
## run_ended flag marks the run over; full clear happens on "New Run" button.
func _show_brott_down() -> void:
	_clear_screen()
	var battle_num := (game_flow.run_state.current_battle_index + 1) if game_flow.run_state != null else 1
	## Mark run as ended (but keep run_state alive for stats display)
	if game_flow.run_state != null:
		game_flow.run_state.run_ended = true
	var screen := BrottDownScreen.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wrap_in_scroll(screen)
	screen.setup(game_flow.run_state, battle_num)
	screen.new_run_pressed.connect(func():
		game_flow.end_run()  ## Now fully clear run_state
		_show_run_start()
	)

func _advance_to_next_battle() -> void:
	## S25.6: Use encounter generator (replaces standard_duel stub)
	var next_idx := game_flow.run_state.current_battle_index
	var archetype_id := OpponentLoadouts.archetype_for(next_idx, game_flow.run_state)
	var tier := OpponentLoadouts.difficulty_for_battle(next_idx)
	var arena_seed := game_flow.run_state.seed * 31 + next_idx
	game_flow.run_state.set_encounter(archetype_id, tier, arena_seed)
	## S25.7: Battle 15 (index 14) goes to boss arena, not standard match
	if next_idx >= 14:
		_show_boss_arena()
	else:
		_start_roguelike_match()

func _show_boss_arena() -> void:
	## S25.7: Boss battle uses same match machinery, different screen state
	game_flow.current_screen = GameFlow.Screen.BOSS_ARENA
	_save_last_screen()
	_start_roguelike_match()

func _show_run_complete() -> void:
	_clear_screen()
	game_flow.current_screen = GameFlow.Screen.RUN_COMPLETE
	var rc := RunCompleteScreen.new()
	rc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wrap_in_scroll(rc)
	rc.setup(game_flow.run_state)
	rc.new_run_pressed.connect(func():
		game_flow.end_run()
		_show_run_start()
	)

func _show_stub_result(won: bool) -> void:
	## DEPRECATED S25.5 — stub result no longer used in roguelike flow.
	## Kept temporarily for any external callers; remove in Arc G cleanup.
	_clear_screen()
	var result_lbl := Label.new()
	result_lbl.text = "⚔️ %s\n\nBattle %d — Stub result.\nFull reward/retry flow arrives next sprint." % [
		"VICTORY!" if won else "DEFEAT",
		game_flow.run_state.current_battle_index if game_flow.run_state else 1
	]
	result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_lbl.add_theme_font_size_override("font_size", 24)
	result_lbl.position = Vector2(240, 200)
	result_lbl.size = Vector2(800, 200)
	add_child(result_lbl)

	var btn := Button.new()
	btn.text = "↩ Back to Menu"
	btn.position = Vector2(515, 450)
	btn.size = Vector2(250, 60)
	btn.add_theme_font_size_override("font_size", 20)
	btn.pressed.connect(_show_main_menu)
	add_child(btn)

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
	#
	# S22.2c: for silver (and any future league), fire-once guard checked via
	# FirstRunState before showing modal. ceremony_complete signal emitted on dismiss.
	if _pending_league_ceremony != "":
		var ceremony := _pending_league_ceremony
		_pending_league_ceremony = ""
		# S22.2c: fire-once guard for silver ceremony.
		if ceremony == "silver":
			var frs: Node = get_node_or_null("/root/FirstRunState")
			if frs != null and frs.call("has_seen", "silver_unlocked_modal_seen"):
				# Already seen — skip ceremony, go straight to shop.
				_show_shop()
				return
		var modal_scene: PackedScene = load("res://ui/league_complete_modal.tscn")
		var modal := modal_scene.instantiate()
		modal.setup(game_flow.game_state, ceremony)
		add_child(modal)
		modal.modal_dismissed.connect(_on_ceremony_dismissed.bind(ceremony))
		return
	_clear_screen()
	var shop := ShopScreen.new()
	shop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wrap_in_scroll(shop)
	shop.setup(game_flow.game_state)
	shop.continue_pressed.connect(_show_loadout)
	_maybe_spawn_first_encounter(FE_KEY_RUN_START)  ## S25.8: legacy callsite — was FE_KEY_SHOP

## S22.2c: called when a league ceremony modal is dismissed (via modal_dismissed
## signal). Marks silver ceremony seen (fire-once guard), emits ceremony_complete
## signal, then proceeds to shop.
func _on_ceremony_dismissed(league_id: String) -> void:
	if league_id == "silver":
		var frs: Node = get_node_or_null("/root/FirstRunState")
		if frs != null:
			frs.call("mark_seen", "silver_unlocked_modal_seen")
	# Mirror Bronze: emit ceremony_complete so any listener (analytics, tutorial) can hook.
	emit_signal("ceremony_complete", league_id)
	_show_shop()

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
	_maybe_spawn_first_encounter(FE_KEY_FIRST_REWARD_PICK)  ## S25.8: legacy callsite — was FE_KEY_BROTTBRAIN

func _show_opponent_select() -> void:
	_clear_screen()
	var opp_screen := OpponentSelectScreen.new()
	opp_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wrap_in_scroll(opp_screen)
	opp_screen.setup(game_flow.game_state)
	opp_screen.opponent_selected.connect(_start_match)
	opp_screen.back_pressed.connect(_show_loadout)
	_maybe_spawn_first_encounter(FE_KEY_FIRST_RETRY_PROMPT)  ## S25.8: legacy callsite — was FE_KEY_OPPONENT

func _start_demo_match() -> void:
	## Start a hardcoded demo match for URL-param routing (?screen=battle).
	## Uses the same brotts as main.gd's _setup_match() for consistency.
	_clear_screen()
	
	# Player: Brawler with Shotgun + Minigun, Plating, Repair Nanites + Overclock
	# Demo route — league-agnostic; default "bronze" applies.
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
	# Demo route — league-agnostic; default "bronze" applies.
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
	# [S24.3] Wire combat SFX signals.
	sim.on_damage.connect(_on_combat_damage)
	sim.on_projectile_spawned.connect(_on_projectile_spawned)
	# [S24.4] Wire death SFX signal.
	sim.on_death.connect(_on_brott_death)
	
	# Instantiate arena renderer from scene (KB: no set_script/Script.new in web)
	arena_renderer = ArenaRendererScene.instantiate()
	add_child(arena_renderer)
	arena_renderer.setup(sim, ARENA_OFFSET)
	print("[S26.7] _start_roguelike_match: arena_renderer added, sim.brotts.size=", sim.brotts.size())
	# S25.2: Wire player brain into renderer for click dispatch.
	if player_brott != null and player_brott.brain != null and arena_renderer.has_method("set_player_brain"):
		arena_renderer.set_player_brain(player_brott.brain)
	
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
	# [S24.3] Wire combat SFX signals.
	sim.on_damage.connect(_on_combat_damage)
	sim.on_projectile_spawned.connect(_on_projectile_spawned)
	# [S24.4] Wire death SFX signal.
	sim.on_death.connect(_on_brott_death)
	
	# Instantiate from scene so _draw() virtual is properly registered in web export
	# (Script.new() and set_script() both fail to register _draw in HTML5 builds)
	arena_renderer = ArenaRendererScene.instantiate()
	add_child(arena_renderer)
	arena_renderer.setup(sim, ARENA_OFFSET)
	print("[S26.7] _start_roguelike_match: arena_renderer added, sim.brotts.size=", sim.brotts.size())
	# S25.2: Wire player brain into renderer for click dispatch.
	if player_brott != null and player_brott.brain != null and arena_renderer.has_method("set_player_brain"):
		arena_renderer.set_player_brain(player_brott.brain)
	
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
	# [S21.3 / #245 / #107] Create a named EnergyLegend anchor label so the
	# arena onboarding sequencer can anchor the energy_explainer overlay to a
	# real HUD element node (not a CanvasLayer). Reuses S17.1-003/004 copy.
	var energy_legend := Label.new()
	energy_legend.name = "EnergyLegend"
	energy_legend.text = "⚡ Energy"
	energy_legend.add_theme_font_size_override("font_size", 13)
	energy_legend.add_theme_color_override("font_color", Color(0.2, 0.7, 1.0))
	energy_legend.position = Vector2(20.0, 42.0)
	energy_legend.size = Vector2(120.0, 20.0)
	add_child(energy_legend)
	# [S21.4 / #106] Named anchor for random-event popup positioning.
	# Mirrors S21.3 EnergyLegend sibling pattern: Node2D child of GameMain,
	# created imperatively here, named EXACTLY "RandomEventPopupAnchor".
	# Positioned below the HUD top-row cluster (PlayerInfo/EnemyInfo/TimeLabel
	# bottom edge is y=40; anchor sits at y=50 to satisfy I-B3/I-B4c).
	var re_anchor := Node2D.new()
	re_anchor.name = "RandomEventPopupAnchor"
	re_anchor.position = Vector2(384.0, 50.0)
	add_child(re_anchor)
	# [S21.3 / #245 / #107] Start the arena-entry onboarding sequence.
	# This is the arena-entry hook (per-match entry, not screen show/enter).
	# Replaces the S21.2 per-screen FE_KEY_ENERGY spawn so the overlay
	# anchors to the real EnergyLegend HUD node rather than top-center.
	_start_arena_onboarding()

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

## DEPRECATED S25.8 — league-era result screen retired.
## ResultScreen class was renamed to BrottDownScreen; legacy demo route now
## bounces back to main menu. Kept as stub so existing _on_match_end callers
## (?screen=battle demo) compile. Remove with _on_match_end in Arc G.
func _show_result() -> void:
	_clear_screen()
	_show_main_menu()

func _process(delta: float) -> void:
	# [S21.2 / #107] Tick-budget auto-dismiss for any active first-encounter
	# overlay (parameterized version of S17.1-004's _energy_explainer_ticks).
	if _fe_overlay != null:
		_fe_ticks += 1
		if _fe_ticks >= FE_TICK_BUDGET:
			_dismiss_first_encounter()
	# [S21.3 / #245] Tick-budget auto-dismiss for arena onboarding overlay.
	if _arena_fe_overlay != null:
		_arena_fe_ticks += 1
		if _arena_fe_ticks >= ARENA_FE_TICK_BUDGET:
			_dismiss_arena_first_encounter()
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

# [S21.3 / #245 / #107] Arena-entry onboarding sequencer.
# Called once per arena entry (from _create_arena_hud) — NOT from
# _ready or screen show/enter callbacks. Advances through ARENA_SEQUENCE
# to the next unseen key and spawns that overlay anchored to the matching
# HUD element node. One overlay per arena entry maximum.
#
# sim-slowdown: 0.25× while overlay visible, restored on dismiss.
# tick-budget: ARENA_FE_TICK_BUDGET (~12 s) auto-dismiss.
var _arena_fe_overlay: Control = null
var _arena_fe_ticks: int = 0
var _arena_fe_active_key: String = ""
var _arena_fe_pre_slowdown_speed: float = 1.0

func _start_arena_onboarding() -> void:
	# Guard: if an overlay is somehow already active (re-entrant call), skip.
	if _arena_fe_overlay != null:
		return
	# FRS lookup: try direct path first (in-tree node), then fall back to
	# Engine.get_main_loop().root (works even when this node is not in the tree,
	# e.g. headless test instantiation).
	var frs: Node = get_node_or_null("/root/FirstRunState")
	if frs == null:
		var ml := Engine.get_main_loop() as SceneTree
		if ml != null and ml.root != null:
			frs = ml.root.get_node_or_null("FirstRunState")
	if frs == null:
		return
	# Advance to next unseen key in ARENA_SEQUENCE.
	for key in ARENA_SEQUENCE:
		if not frs.call("has_seen", key):
			_spawn_arena_first_encounter(key)
			return
	# All keys seen — nothing to show.

func _spawn_arena_first_encounter(key: String) -> Control:
	# Resolve anchor: the HUD element node for this key.
	# anchor_target is a real Node reference, not a CanvasLayer / screen root.
	var anchor: Control = null
	match key:
		"click_controls_explainer":
			## S25.8: Anchors to player_info HUD label as a stable top-of-arena anchor.
			## The overlay copy is about clicking the arena, not a specific HUD element,
			## but we still need a valid Control anchor for placement.
			anchor = player_info
		"energy_explainer":
			anchor = _resolve_energy_legend_node()
		"combatants_explainer":
			anchor = _resolve_combatants_panel_node()
		"time_explainer":
			anchor = time_label
		"concede_explainer":
			anchor = _find_concede_button()

	if anchor == null:
		# Anchor not found (e.g. concede button missing) — skip this key
		# gracefully so remaining overlays still fire.
		# The concede-button absence is handled by the caller (backlog issue filed).
		return null

	# Build overlay positioned relative to the anchor's global rect.
	var panel := Panel.new()
	panel.name = "ArenaFEOverlay_" + key
	panel.z_index = 10
	panel.mouse_filter = Control.MOUSE_FILTER_PASS

	# Panel is 400 × 110; we position it below (or above if near bottom) the anchor.
	var panel_w := 400.0
	var panel_h := 110.0
	var anchor_global := anchor.get_global_rect()
	var anchor_center_x := anchor_global.position.x + anchor_global.size.x * 0.5

	# Default: position panel left edge so it centres on the anchor (clamped to viewport).
	var vp := get_viewport()
	var viewport_size := vp.get_visible_rect().size if vp != null else Vector2(1280.0, 720.0)
	var panel_x := clampf(anchor_center_x - panel_w * 0.5, 8.0, viewport_size.x - panel_w - 8.0)

	# Default: panel sits BELOW the anchor (pointer ▲ points up at anchor).
	# If the anchor is in the bottom half, flip to above.
	var ARROW_H := 18.0
	var panel_y: float
	var arrow_text: String
	var arrow_inside_y: float
	if anchor_global.position.y > viewport_size.y * 0.5:
		# Anchor is in bottom half — panel goes ABOVE. ▼ pointer at bottom of panel.
		panel_y = anchor_global.position.y - panel_h - ARROW_H - 4.0
		arrow_text = "▼"
		arrow_inside_y = panel_h - 2.0
	else:
		# Panel goes BELOW anchor. ▲ pointer at top of panel.
		panel_y = anchor_global.position.y + anchor_global.size.y + ARROW_H + 4.0
		arrow_text = "▲"
		arrow_inside_y = -ARROW_H

	panel.position = Vector2(panel_x, panel_y)
	panel.size = Vector2(panel_w, panel_h)

	# ▲/▼ pointer — anchor arrow node (stable name for tests: "AnchorArrow").
	var arrow := Label.new()
	arrow.name = "AnchorArrow"
	arrow.text = arrow_text
	arrow.add_theme_font_size_override("font_size", 18)
	arrow.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	# Position: horizontally centred on the anchor within the panel's local space.
	var arrow_local_x := clampf(
		(anchor_center_x - panel_x) - 10.0, 8.0, panel_w - 24.0)
	arrow.position = Vector2(arrow_local_x, arrow_inside_y)
	arrow.size = Vector2(20.0, ARROW_H)
	panel.add_child(arrow)

	# Body copy.
	var body := Label.new()
	body.name = "Body"
	body.text = String(ARENA_FE_COPY.get(key, ""))
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.position = Vector2(12.0, 10.0)
	body.size = Vector2(panel_w - 24.0, 60.0)
	panel.add_child(body)

	# "Got it!" dismiss button.
	var btn := Button.new()
	btn.name = "GotItButton"
	btn.text = "Got it!"
	btn.position = Vector2(panel_w - 104.0, panel_h - 36.0)
	btn.size = Vector2(96.0, 28.0)
	btn.pressed.connect(_on_arena_fe_dismissed)
	panel.add_child(btn)

	# Store anchor reference as metadata so tests can read it.
	panel.set_meta("anchor_target", anchor)

	add_child(panel)
	_arena_fe_overlay = panel
	_arena_fe_ticks = 0
	_arena_fe_active_key = key

	# Apply 0.25× sim slowdown.
	_arena_fe_pre_slowdown_speed = speed_multiplier
	speed_multiplier *= 0.25
	return panel

func _dismiss_arena_first_encounter() -> void:
	if _arena_fe_overlay == null:
		return
	var frs: Node = get_node_or_null("/root/FirstRunState")
	if frs != null and _arena_fe_active_key != "":
		frs.call("mark_seen", _arena_fe_active_key)
	_arena_fe_overlay.queue_free()
	_arena_fe_overlay = null
	_arena_fe_ticks = 0
	_arena_fe_active_key = ""
	# Restore sim speed.
	speed_multiplier = _arena_fe_pre_slowdown_speed

func _on_arena_fe_dismissed() -> void:
	_dismiss_arena_first_encounter()

# Resolve the EnergyLegend node. In game_main.gd it is created dynamically
# inside _create_arena_hud as a child of this node (not inside a CanvasLayer).
func _resolve_energy_legend_node() -> Control:
	# Look for an existing EnergyLegend label child.
	for child in get_children():
		if child is Label and child.name == "EnergyLegend":
			return child as Control
	# Not yet created — synthesise one so we have a real anchor node.
	# (In practice _create_arena_hud creates it before calling this.)
	var legend := Label.new()
	legend.name = "EnergyLegend"
	legend.text = "⚡ Energy"
	legend.position = Vector2(20.0, 42.0)
	legend.size = Vector2(200.0, 20.0)
	add_child(legend)
	return legend

# Resolve combatants panel: the PlayerInfo + EnemyInfo pair. We expose this
# as the player_info label (left anchor) for overlay positioning; the
# panel name is CombatantsPanel if we wrap them, or we use player_info directly.
func _resolve_combatants_panel_node() -> Control:
	# Try to find a named CombatantsPanel first (forward-compatible).
	var cp: Node = get_node_or_null("CombatantsPanel")
	if cp is Control:
		return cp as Control
	# Fall back to player_info (set by _create_arena_hud).
	if player_info != null:
		return player_info
	return null

func _find_concede_button() -> Control:
	for child in get_children():
		if child.name == "ConcedeButton" and child is Button:
			return child as Control
	return null

# ─────────────────────────────────────────────────────────────────────────────
# [S21.4 / #106] Random-event popup controller
# "Interruption → Flow" redesign: popup is skippable, dampened, and anchored
# to a named node so Optic can verify structure without screenshots.
#
# Public entry point: show_random_event(event_data: Dictionary)
#   event_data keys (all optional):
#     "title"   : String  — heading text (default: "Random Event")
#     "body"    : String  — body copy
#     "choices" : Array   — reserved for future choice-branch wiring (not in S21.4)
#
# Invariants satisfied:
#   I-B1: SkipButton present, visible, enabled; pressing it frees popup.
#   I-B2: Dampening interval is RANDOM_EVENT_MIN_INTERVAL_SEC (named const above).
#   I-B3: RandomEventPopupAnchor node exists as add_child(self) sibling in _create_arena_hud().
#   I-B5: SkipButton visible + disabled=false at popup show moment.
#   I-B6: Second trigger within interval is suppressed (dampening).
#   I-B7: No SFX wiring.
# ─────────────────────────────────────────────────────────────────────────────

## Trigger a random-event popup. Respects dampening interval (I-B2/I-B6).
## If a popup is already visible, or the interval has not elapsed, call is a no-op.
func show_random_event(event_data: Dictionary = {}) -> void:
	# Dampening check (I-B6): suppress if within RANDOM_EVENT_MIN_INTERVAL_SEC.
	var now := Time.get_ticks_msec() / 1000.0
	if now - _re_last_shown_time < RANDOM_EVENT_MIN_INTERVAL_SEC:
		return
	# Guard: only one popup at a time.
	if _re_popup != null and is_instance_valid(_re_popup):
		return
	_re_last_shown_time = now
	# [S21.5] Play popup whoosh BEFORE building and adding popup node.
	_play_popup_whoosh()
	_re_popup = _build_random_event_popup(event_data)
	add_child(_re_popup)

# [S21.5] Play popup whoosh via a single long-lived AudioStreamPlayer.
# Reuses the player instance to avoid accumulating nodes on rapid calls.
func _play_popup_whoosh() -> void:
	if _popup_whoosh_player == null or not is_instance_valid(_popup_whoosh_player):
		_popup_whoosh_player = AudioStreamPlayer.new()
		_popup_whoosh_player.name = "PopupWhooshPlayer"
		_popup_whoosh_player.stream = POPUP_WHOOSH
		_popup_whoosh_player.bus = "SFX"
		add_child(_popup_whoosh_player)
	_popup_whoosh_player.play()

# [S24.3] Initialise combat SFX players once at scene load.
# .bus = "SFX" is set BEFORE add_child per S21.5 ordering convention.
func _init_combat_sfx_players() -> void:
	_hit_sfx_player = AudioStreamPlayer.new()
	_hit_sfx_player.name = "HitSfxPlayer"
	_hit_sfx_player.bus = "SFX"
	_hit_sfx_player.stream = HIT_SFX
	add_child(_hit_sfx_player)

	_projectile_launch_sfx_player = AudioStreamPlayer.new()
	_projectile_launch_sfx_player.name = "ProjectileLaunchSfxPlayer"
	_projectile_launch_sfx_player.bus = "SFX"
	_projectile_launch_sfx_player.stream = PROJECTILE_LAUNCH_SFX
	add_child(_projectile_launch_sfx_player)

	# [S24.4] Critical hit SFX player.
	_critical_hit_sfx_player = AudioStreamPlayer.new()
	_critical_hit_sfx_player.name = "CriticalHitSfxPlayer"
	_critical_hit_sfx_player.bus = "SFX"  # MUST be set BEFORE add_child per S21.5 convention
	_critical_hit_sfx_player.stream = CRITICAL_HIT_SFX
	add_child(_critical_hit_sfx_player)

	# [S24.4] Death SFX player.
	_death_sfx_player = AudioStreamPlayer.new()
	_death_sfx_player.name = "DeathSfxPlayer"
	_death_sfx_player.bus = "SFX"  # MUST be set BEFORE add_child per S21.5 convention
	_death_sfx_player.stream = DEATH_SFX
	add_child(_death_sfx_player)

# [S24.3] Signal handler: on_damage — play hit SFX for meaningful hits.
# [S24.4] Crit branch: critical hits always play critical_hit SFX; normal hits guarded by threshold.
func _on_combat_damage(_target, amount: float, is_crit: bool, _pos: Vector2) -> void:
	if is_crit:
		if _critical_hit_sfx_player != null and is_instance_valid(_critical_hit_sfx_player):
			_critical_hit_sfx_player.play()
	elif amount >= HIT_SFX_MIN_AMOUNT:
		if _hit_sfx_player != null and is_instance_valid(_hit_sfx_player):
			_hit_sfx_player.play()

# [S24.4] Signal handler: on_death — play death SFX once per match-end window.
# Cooldown guard: on_death fires per-brott; in mass-death scenarios multiple brotts
# die in the same tick. Guard prevents overlapping playback — only the first death
# in a 600ms window plays. This is intentional: one death sound per match-end cluster
# is more impactful than 2-3 overlapping. Cooldown auto-resets after 600ms.
func _on_brott_death(_brott) -> void:
	if _death_sfx_cooldown_active:
		return
	if _death_sfx_player != null and is_instance_valid(_death_sfx_player):
		_death_sfx_cooldown_active = true
		_death_sfx_player.play()
		# Reset cooldown after 600ms to allow future matches to play death SFX.
		await get_tree().create_timer(0.6).timeout
		_death_sfx_cooldown_active = false

# [S24.3] Signal handler: on_projectile_spawned — play launch SFX per projectile.
func _on_projectile_spawned(_proj) -> void:
	if _projectile_launch_sfx_player != null and is_instance_valid(_projectile_launch_sfx_player):
		_projectile_launch_sfx_player.play()

## Build the popup node subtree.
## Returns a Panel with: TitleLabel, BodyLabel, SkipButton, anchor_target metadata.
func _build_random_event_popup(event_data: Dictionary) -> Panel:
	var title_text: String = event_data.get("title", "Random Event") as String
	var body_text: String = event_data.get("body", "") as String

	# Locate anchor — RandomEventPopupAnchor must exist (created in _create_arena_hud).
	var anchor: Node = get_node_or_null("RandomEventPopupAnchor")
	if anchor == null:
		# Fallback: synthesise so popup still shows (graceful degradation).
		anchor = Node2D.new()
		anchor.name = "RandomEventPopupAnchor"
		anchor.set_meta("synthesised", true)
		add_child(anchor)

	var panel := Panel.new()
	panel.name = "RandomEventPopup"
	panel.z_index = 20
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	# Size / position: centred below anchor.
	var popup_w := 480.0
	var popup_h := 140.0
	var anchor_pos: Vector2 = anchor.position if anchor.has_method("get_global_transform") == false else anchor.global_position
	# Centre the popup on the anchor x; push down 8px from anchor y.
	panel.position = Vector2(anchor_pos.x - popup_w * 0.5, anchor_pos.y + 8.0)
	panel.size = Vector2(popup_w, popup_h)

	# Store anchor reference as metadata for Optic structural asserts (I-B3/I-B4).
	panel.set_meta("anchor_target", anchor)

	# Title label.
	var title_lbl := Label.new()
	title_lbl.name = "TitleLabel"
	title_lbl.text = title_text
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.3))
	title_lbl.position = Vector2(16.0, 12.0)
	title_lbl.size = Vector2(popup_w - 32.0, 24.0)
	panel.add_child(title_lbl)

	# Body label.
	var body_lbl := Label.new()
	body_lbl.name = "BodyLabel"
	body_lbl.text = body_text
	body_lbl.add_theme_font_size_override("font_size", 13)
	body_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.position = Vector2(16.0, 42.0)
	body_lbl.size = Vector2(popup_w - 32.0, 52.0)
	panel.add_child(body_lbl)

	# Skip button (I-B1 / I-B5): visible, enabled, wired to dismiss.
	var skip_btn := Button.new()
	skip_btn.name = "SkipButton"
	skip_btn.text = "Skip"
	skip_btn.visible = true        # I-B5: visible at show moment
	skip_btn.disabled = false      # I-B5: enabled at show moment
	skip_btn.position = Vector2(popup_w - 104.0, popup_h - 36.0)
	skip_btn.size = Vector2(88.0, 28.0)
	skip_btn.pressed.connect(_on_random_event_skipped)
	panel.add_child(skip_btn)

	return panel

## Called when the player presses SkipButton (I-B1).
func _on_random_event_skipped() -> void:
	_dismiss_random_event_popup()

## Dismiss the active random-event popup (I-B1: frees from scene tree).
func _dismiss_random_event_popup() -> void:
	if _re_popup == null:
		return
	if is_instance_valid(_re_popup):
		_re_popup.queue_free()
	_re_popup = null
