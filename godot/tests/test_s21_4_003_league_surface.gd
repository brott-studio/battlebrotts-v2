## S21.4 / T3 / #108 — League progression surfacing on two surfaces.
## Usage: godot --headless --script tests/test_s21_4_003_league_surface.gd
##
## Spec Invariants tested:
##   I-C1. Final-win reveals next-league path (both surfaces).
##         After league final-win, NextLeaguePathIndicator MUST be visible
##         on ResultScreen AND LeagueProgressIndicator MUST be visible on
##         OpponentSelectScreen.
##   I-C2. Two-surface anchoring required.
##         Both indicators exist as named children of their respective screens.
##   I-C3. Optic structural assert (two-surface) — same fixture verifies
##         parent node-type via get_parent() chain.
##   I-C4. Nutts tests (two-surface):
##     (a) Fire league final-win, assert NextLeaguePathIndicator visible
##         and anchored on ResultScreen (parent-chain check).
##     (b) Set league-progressed state, load OpponentSelectScreen, assert
##         LeagueProgressIndicator visible and anchored on OpponentSelectScreen.
##   Negative: indicators NOT visible when no league-progression state.
##   Name-match: indicator node names match expected constants.
extends SceneTree

var pass_count := 0
var fail_count := 0
var test_count := 0

func _initialize() -> void:
	print("=== S21.4-003 League Progression Two-Surface Tests ===\n")
	_test_ic4a_result_screen_indicator_visible_on_final_win()
	_test_ic4b_opponent_select_indicator_visible_on_league_progressed()
	_test_negative_indicators_hidden_without_progression()
	_test_node_name_match()
	print("\n=== Results: %d passed, %d failed, %d total ===" % [pass_count, fail_count, test_count])
	quit(1 if fail_count > 0 else 0)

# --- Assertion helpers ---

func _assert(cond: bool, msg: String) -> void:
	test_count += 1
	if cond:
		pass_count += 1
	else:
		fail_count += 1
		print("  FAIL: %s" % msg)

# --- Fixtures ---

## Build a GameState in "league final-win" state:
## all 3 scrapyard opponents beaten, bronze just unlocked.
## current_league is still "scrapyard" (advance_league() is called by modal later).
func _mk_final_win_game_state() -> GameState:
	var gs := GameState.new()
	gs.current_league = "scrapyard"
	gs.opponents_beaten = ["scrapyard_0", "scrapyard_1", "scrapyard_2"]
	gs.bronze_unlocked = true
	gs.brottbrain_unlocked = true
	return gs

## Build a GameState in "league-progressed" state:
## bronze unlocked, current_league advanced to "bronze".
func _mk_league_progressed_game_state() -> GameState:
	var gs := GameState.new()
	gs.current_league = "bronze"
	gs.opponents_beaten = ["scrapyard_0", "scrapyard_1", "scrapyard_2"]
	gs.bronze_unlocked = true
	gs.brottbrain_unlocked = true
	return gs

## Build a fresh/starter GameState: no progression, no beats.
func _mk_fresh_game_state() -> GameState:
	var gs := GameState.new()
	gs.current_league = "scrapyard"
	gs.opponents_beaten = []
	gs.bronze_unlocked = false
	return gs

# --- Test I-C4a: ResultScreen indicator visible on final-win ---

## I-C4a: Simulate league-final-win state, load ResultScreen, assert
## NextLeaguePathIndicator is visible AND its parent (via get_parent() chain)
## is an instance of ResultScreen.
func _test_ic4a_result_screen_indicator_visible_on_final_win() -> void:
	print("--- I-C4a: ResultScreen NextLeaguePathIndicator on final-win ---")
	var gs := _mk_final_win_game_state()
	var s := ResultScreen.new()
	root.add_child(s)
	s.setup(gs, true, 80)

	var indicator: Node = s.get_node_or_null("NextLeaguePathIndicator")
	_assert(indicator != null, "NextLeaguePathIndicator exists on ResultScreen")

	if indicator != null:
		_assert(indicator.visible, "NextLeaguePathIndicator.visible == true on final-win")
		# I-C3(a): parent-chain anchor check — direct parent is ResultScreen.
		var parent := indicator.get_parent()
		_assert(parent is ResultScreen, "NextLeaguePathIndicator parent is ResultScreen (got %s)" % (parent.get_class() if parent else "null"))
		# Sanity: text is non-empty when visible.
		var lbl: Label = indicator as Label
		_assert(lbl != null and lbl.text != "", "NextLeaguePathIndicator has non-empty text")

	root.remove_child(s)
	s.free()

# --- Test I-C4b: OpponentSelectScreen indicator visible on league-progressed ---

## I-C4b: Set league-progressed state, load OpponentSelectScreen, assert
## LeagueProgressIndicator is visible AND its parent is an instance of
## OpponentSelectScreen.
func _test_ic4b_opponent_select_indicator_visible_on_league_progressed() -> void:
	print("--- I-C4b: OpponentSelectScreen LeagueProgressIndicator on league-progressed ---")
	var gs := _mk_league_progressed_game_state()
	var s := OpponentSelectScreen.new()
	root.add_child(s)
	s.setup(gs)

	var indicator: Node = s.get_node_or_null("LeagueProgressIndicator")
	_assert(indicator != null, "LeagueProgressIndicator exists on OpponentSelectScreen")

	if indicator != null:
		_assert(indicator.visible, "LeagueProgressIndicator.visible == true on league-progressed")
		# I-C3(b): parent-chain anchor check — direct parent is OpponentSelectScreen.
		var parent := indicator.get_parent()
		_assert(parent is OpponentSelectScreen, "LeagueProgressIndicator parent is OpponentSelectScreen (got %s)" % (parent.get_class() if parent else "null"))
		# Sanity: text is non-empty when visible.
		var lbl: Label = indicator as Label
		_assert(lbl != null and lbl.text != "", "LeagueProgressIndicator has non-empty text")

	root.remove_child(s)
	s.free()

# --- Test: Negative — indicators hidden without progression (I-C1 negative) ---

## I-C1 negative: indicators NOT visible when no league-progression state.
## ResultScreen on non-final-win; OpponentSelectScreen on first-ever match.
func _test_negative_indicators_hidden_without_progression() -> void:
	print("--- I-C1 negative: indicators hidden on fresh state ---")

	# ResultScreen: fresh state, not a final win.
	var gs1 := _mk_fresh_game_state()
	var rs := ResultScreen.new()
	root.add_child(rs)
	rs.setup(gs1, true, 50)

	var rs_indicator: Node = rs.get_node_or_null("NextLeaguePathIndicator")
	_assert(rs_indicator != null, "NextLeaguePathIndicator exists even in non-final-win state (hidden)")
	if rs_indicator != null:
		_assert(not rs_indicator.visible, "NextLeaguePathIndicator.visible == false on non-final-win")

	root.remove_child(rs)
	rs.free()

	# OpponentSelectScreen: fresh state, first match.
	var gs2 := _mk_fresh_game_state()
	var oss := OpponentSelectScreen.new()
	root.add_child(oss)
	oss.setup(gs2)

	var oss_indicator: Node = oss.get_node_or_null("LeagueProgressIndicator")
	_assert(oss_indicator != null, "LeagueProgressIndicator exists even on first-ever match (hidden)")
	if oss_indicator != null:
		_assert(not oss_indicator.visible, "LeagueProgressIndicator.visible == false on first-ever match")

	root.remove_child(oss)
	oss.free()

# --- Test: Name-match assert (I-C2) ---

## I-C2 name-match: indicator node names are exactly as expected on both surfaces.
func _test_node_name_match() -> void:
	print("--- I-C2 name-match: indicator node names on both surfaces ---")

	var gs := _mk_final_win_game_state()

	# ResultScreen
	var rs := ResultScreen.new()
	root.add_child(rs)
	rs.setup(gs, true, 80)
	var rs_ind: Node = rs.get_node_or_null("NextLeaguePathIndicator")
	_assert(rs_ind != null, "Node named 'NextLeaguePathIndicator' exists on ResultScreen")
	if rs_ind != null:
		_assert(rs_ind.name == "NextLeaguePathIndicator",
			"ResultScreen indicator name == 'NextLeaguePathIndicator' (got '%s')" % rs_ind.name)
	root.remove_child(rs)
	rs.free()

	# OpponentSelectScreen (use league-progressed state for name test)
	var gs2 := _mk_league_progressed_game_state()
	var oss := OpponentSelectScreen.new()
	root.add_child(oss)
	oss.setup(gs2)
	var oss_ind: Node = oss.get_node_or_null("LeagueProgressIndicator")
	_assert(oss_ind != null, "Node named 'LeagueProgressIndicator' exists on OpponentSelectScreen")
	if oss_ind != null:
		_assert(oss_ind.name == "LeagueProgressIndicator",
			"OpponentSelectScreen indicator name == 'LeagueProgressIndicator' (got '%s')" % oss_ind.name)
	root.remove_child(oss)
	oss.free()
