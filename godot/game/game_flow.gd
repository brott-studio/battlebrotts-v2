## Game flow manager — coordinates screens and game state
## S25.1: Reworked for roguelike run loop. League-era flow replaced.
## Old Screen entries (SHOP, LOADOUT, BROTTBRAIN_EDITOR, OPPONENT_SELECT)
## left as dormant enum values — Arc G removes them.
class_name GameFlow
extends RefCounted

enum Screen {
	MAIN_MENU,
	SHOP,              # CUT: Arc G — dormant, do not route to
	LOADOUT,           # CUT: Arc G — dormant, do not route to
	BROTTBRAIN_EDITOR, # CUT: Arc G — dormant, do not route to
	OPPONENT_SELECT,   # CUT: Arc G — dormant, do not route to
	ARENA,
	RESULT,
	RUN_START,         # S25.1: new
	REWARD_PICK,       # S25.5: post-battle reward selection
	RETRY_PROMPT,      # S25.5: post-loss retry or accept
}

## S25.1: RunState is the new source of truth for run-scoped data.
var run_state: RunState = null

## S25.1: GameState kept as dormant property — Arc G removes.
## Active code paths in S25.1 do NOT reference this.
var game_state: GameState

## S25.1: kept as dormant fields — used by tools/test_harness.gd (Arc G removes).
var selected_opponent_index: int = -1
var last_bolts_earned: int = 0

var current_screen: int = Screen.MAIN_MENU
var last_match_won: bool = false

func _init() -> void:
	game_state = GameState.new()  # dormant — kept for Arc G cleanup

## Start a new run with the given chassis selection.
func start_run(chassis_type: int, rng_seed: int = 0) -> void:
	run_state = RunState.new(chassis_type, rng_seed)
	current_screen = Screen.ARENA

## Increment battle index after a battle resolves.
func advance_battle() -> void:
	if run_state != null:
		run_state.advance_battle_index()

## S25.5: Go to reward pick screen after a won battle.
func to_reward_pick() -> void:
	current_screen = Screen.REWARD_PICK

## S25.5: Go to retry prompt screen after a lost battle.
func to_retry_prompt() -> void:
	current_screen = Screen.RETRY_PROMPT

## End the current run (returns to main menu state).
func end_run() -> void:
	run_state = null
	current_screen = Screen.MAIN_MENU

## True if a run is in progress this session.
func has_active_run() -> bool:
	return run_state != null

## S25.1: go_to_run_start — route from main menu.
func go_to_run_start() -> void:
	current_screen = Screen.RUN_START

## S25.1: dormant compatibility shims for tools/test_harness.gd.
## These do not participate in the active S25.1 flow. Arc G removes.
func new_game() -> void:
	game_state = GameState.new()
	current_screen = Screen.SHOP

func go_to_shop() -> void:
	current_screen = Screen.SHOP

func go_to_loadout() -> void:
	current_screen = Screen.LOADOUT

func go_to_brottbrain() -> void:
	current_screen = Screen.BROTTBRAIN_EDITOR

func go_to_opponent_select() -> void:
	current_screen = Screen.OPPONENT_SELECT

func select_opponent(index: int) -> void:
	selected_opponent_index = index
	current_screen = Screen.ARENA

func finish_match(won: bool) -> void:
	last_match_won = won
	current_screen = Screen.RESULT

func continue_from_result() -> void:
	current_screen = Screen.MAIN_MENU
