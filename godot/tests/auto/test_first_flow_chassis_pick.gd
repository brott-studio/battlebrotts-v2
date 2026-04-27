## Arc I S(I).1 — TestFirstFlowChassisPick
## End-to-end user flow: boot → menu → new game → chassis pick → arena entry → first tick
##
## Acceptance criteria:
##   - exits 0 on clean run
##   - exits 1 if _on_chassis_picked is broken (or chassis does not arm the run)
##   - wall-clock under 15s
##
## Usage:
##   godot --headless --path godot/ --script "res://tests/auto/test_first_flow_chassis_pick.gd"

extends AutoDriver

func _run() -> void:
	# ── Step 1: boot and settle ───────────────────────────────────────────────
	# boot() already called by AutoDriver._initialize() before _run().
	# Advance 30 more frames to let _ready() + async initialisation complete.
	tick(30)

	# ── Step 2: assert we're on the main menu (run NOT active) ────────────────
	var run := get_run_state()
	if run.get("active", false):
		_failures.append("After boot: expected run.active==false, got true")

	# ── Step 3: trigger New Game (same signal path as the button) ─────────────
	# MainMenuScreen emits new_game_pressed; game_main._on_new_game() is the handler.
	# We call the handler directly to avoid needing to locate the button node.
	if not game_main.has_method("_on_new_game"):
		_failures.append("game_main missing _on_new_game — cannot trigger new game")
		finish()
		return
	game_main.call("_on_new_game")

	# ── Step 4: settle into RunStartScreen ───────────────────────────────────
	tick(15)

	# ── Step 5: assert current_screen == RUN_START ───────────────────────────
	# GameFlow.Screen.RUN_START = 7 (enum index from game_flow.gd declaration order)
	# MAIN_MENU=0, SHOP=1, LOADOUT=2, BROTTBRAIN_EDITOR=3, OPPONENT_SELECT=4,
	# ARENA=5, RESULT=6, RUN_START=7, REWARD_PICK=8, RETRY_PROMPT=9,
	# BOSS_ARENA=10, RUN_COMPLETE=11
	var gf: Object = game_main.get("game_flow")
	if gf == null:
		_failures.append("After _on_new_game: game_main.game_flow is null")
		finish()
		return
	var screen: int = gf.get("current_screen")
	var expected_screen: int = 7  # GameFlow.Screen.RUN_START
	if screen != expected_screen:
		_failures.append("After _on_new_game: expected screen RUN_START(7), got %d" % screen)
		# Don't return — keep going to collect more state info.

	# ── Step 6: pick chassis 0 (Scout) ───────────────────────────────────────
	click_chassis(0)

	# ── Step 7: settle into arena ─────────────────────────────────────────────
	tick(60)

	# ── Step 8: assert run is active, chassis == 0, in_arena == true ─────────
	assert_state("run.active", true)
	assert_state("run.equipped_chassis", 0)
	assert_state("arena.in_arena", true)

	# ── Step 9: advance more frames and assert sim is ticking ─────────────────
	tick(60)
	assert_cmp("arena.tick_count", "gte", 1)

	# ── Done ──────────────────────────────────────────────────────────────────
	finish()
