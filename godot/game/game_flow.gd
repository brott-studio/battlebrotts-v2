## Game flow manager — coordinates screens and game state
## Flow: Menu → Shop → Loadout → BrottBrain → Opponent → Arena → Result → loop
class_name GameFlow
extends RefCounted

enum Screen {
	MAIN_MENU,
	SHOP,
	LOADOUT,
	BROTTBRAIN_EDITOR,
	OPPONENT_SELECT,
	ARENA,
	RESULT,
}

var game_state: GameState
var current_screen: int = Screen.MAIN_MENU
var selected_opponent_index: int = -1
var last_match_won: bool = false
var last_bolts_earned: int = 0

func _init() -> void:
	game_state = GameState.new()

func new_game() -> void:
	game_state = GameState.new()
	current_screen = Screen.SHOP

func go_to_shop() -> void:
	current_screen = Screen.SHOP

func go_to_loadout() -> void:
	current_screen = Screen.LOADOUT

func go_to_brottbrain() -> void:
	if game_state.brottbrain_unlocked:
		current_screen = Screen.BROTTBRAIN_EDITOR
	else:
		# Skip to opponent select if brain not unlocked
		go_to_opponent_select()

func go_to_opponent_select() -> void:
	current_screen = Screen.OPPONENT_SELECT

func select_opponent(index: int) -> void:
	selected_opponent_index = index
	current_screen = Screen.ARENA

func finish_match(won: bool) -> void:
	last_match_won = won
	var opp_id: String = "scrapyard_%d" % selected_opponent_index
	last_bolts_earned = game_state.apply_match_result(won, opp_id)
	current_screen = Screen.RESULT

func continue_from_result() -> void:
	current_screen = Screen.SHOP
