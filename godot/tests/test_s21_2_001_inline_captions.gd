## S21.2 / T2 / #103 — Inline visible-by-default captions for 6 critical surfaces.
## Usage: godot --headless --script tests/test_s21_2_001_inline_captions.gd
## Specs:
##   - design/2026-04-23-s21.2-ux-bundle.md §Issue #103
##   - sprints/v2-sprint-21.2.md §T2 acceptance:
##       * captions render with no hover (visibility-only fixture per surface)
##       * brain trigger/action captions stay <=8 words and are present for
##         every non-hidden card type
##       * stance caption updates when default_stance changes
##       * weight caption changes copy across under/at/over states
##       * progress caption changes copy across pre-bronze, bronze-unlock-ready,
##         and post-unlock states
extends SceneTree

var pass_count := 0
var fail_count := 0
var test_count := 0

func _initialize() -> void:
	print("=== S21.2-001 Inline-caption tests ===\n")
	_test_brain_trigger_captions_visible_and_short()
	_test_brain_action_captions_visible_and_short()
	_test_stance_caption_initial_and_update()
	_test_opponent_subtitle_present()
	_test_weight_caption_states()
	_test_progress_caption_states()
	print("\n=== Results: %d passed, %d failed, %d total ===" % [pass_count, fail_count, test_count])
	quit(1 if fail_count > 0 else 0)

func _assert(cond: bool, msg: String) -> void:
	test_count += 1
	if cond:
		pass_count += 1
	else:
		fail_count += 1
		print("  FAIL: %s" % msg)

# --- Fixtures ---

func _mk_brain_screen() -> BrottBrainScreen:
	var gs := GameState.new()
	gs.equipped_chassis = ChassisData.ChassisType.BRAWLER
	gs.equipped_modules = []
	var brain := BrottBrain.default_for_chassis(gs.equipped_chassis)
	var s := BrottBrainScreen.new()
	s.tutorial_dismissed = true
	s.setup(gs, brain)
	return s

func _mk_opponent_screen() -> OpponentSelectScreen:
	var gs := GameState.new()
	gs.current_league = "scrapyard"
	var s := OpponentSelectScreen.new()
	s.setup(gs)
	return s

func _mk_loadout_screen(weight_total: int, weight_cap: int) -> LoadoutScreen:
	# We can't easily synthesize a real LoadoutScreen with arbitrary kg, so this
	# test exercises the pure helper functions (_weight_caption_text/_color)
	# which is the contract that matters per design §Issue #103 #4.
	var s := LoadoutScreen.new()
	return s

func _mk_result_screen(beat_ids: Array, league: String = "scrapyard", bronze_unlocked: bool = false) -> ResultScreen:
	var gs := GameState.new()
	gs.current_league = league
	gs.opponents_beaten = []
	for id in beat_ids:
		gs.opponents_beaten.append(String(id))
	gs.bronze_unlocked = bronze_unlocked
	var s := ResultScreen.new()
	s.setup(gs, true, 50)
	return s

# --- T2 #103 #1: trigger captions ---

func _test_brain_trigger_captions_visible_and_short() -> void:
	var s := _mk_brain_screen()
	var tray: Node = s.get_node_or_null("TrayScroll/tray_content")
	_assert(tray != null, "tray_content present for trigger captions")
	if tray == null:
		s.free()
		return
	var seen_indices: Array = []
	for c in tray.get_children():
		if c is Label and String(c.name).begins_with("trigger_caption_"):
			var idx := int(String(c.name).trim_prefix("trigger_caption_"))
			seen_indices.append(idx)
			var lbl: Label = c
			_assert(lbl.text != "", "trigger_caption_%d non-empty (visible by default)" % idx)
			_assert(lbl.text.split(" ").size() <= 8, "trigger_caption_%d <=8 words: '%s'" % [idx, lbl.text])
	# Every non-hidden trigger gets a caption.
	for i in range(BrottBrainScreen.TRIGGER_DISPLAY.size()):
		if i in BrottBrainScreen.HIDDEN_TRIGGERS:
			continue
		_assert(i in seen_indices, "trigger_caption_%d rendered" % i)
	s.free()

func _test_brain_action_captions_visible_and_short() -> void:
	var s := _mk_brain_screen()
	var tray: Node = s.get_node_or_null("TrayScroll/tray_content")
	if tray == null:
		_assert(false, "tray_content missing")
		s.free()
		return
	var seen_indices: Array = []
	for c in tray.get_children():
		if c is Label and String(c.name).begins_with("action_caption_"):
			var idx := int(String(c.name).trim_prefix("action_caption_"))
			seen_indices.append(idx)
			var lbl: Label = c
			_assert(lbl.text != "", "action_caption_%d non-empty" % idx)
			_assert(lbl.text.split(" ").size() <= 8, "action_caption_%d <=8 words: '%s'" % [idx, lbl.text])
	for i in range(BrottBrainScreen.ACTION_DISPLAY.size()):
		if i in BrottBrainScreen.HIDDEN_ACTIONS:
			continue
		_assert(i in seen_indices, "action_caption_%d rendered" % i)
	s.free()

# --- T2 #103 #5: stance caption ---

func _test_stance_caption_initial_and_update() -> void:
	var s := _mk_brain_screen()
	var cap_node: Node = s.get_node_or_null("stance_caption")
	_assert(cap_node != null, "stance_caption label exists")
	if cap_node == null:
		s.free()
		return
	var cap: Label = cap_node
	_assert(cap.text != "", "stance_caption non-empty initially")
	# Find the OptionButton and emit item_selected to verify the caption updates.
	var opt: OptionButton = null
	for c in s.get_children():
		if c is OptionButton:
			opt = c
			break
	_assert(opt != null, "default-stance OptionButton exists")
	if opt != null:
		var initial := cap.text
		# Pick a different stance index than current.
		var new_idx := (opt.selected + 1) % BrottBrainScreen.STANCE_NAMES.size()
		opt.item_selected.emit(new_idx)
		_assert(cap.text != initial, "stance_caption text changes after item_selected (%s -> %s)" % [initial, cap.text])
	s.free()

# --- T2 #103 #3: opponent subtitle ---

func _test_opponent_subtitle_present() -> void:
	var s := _mk_opponent_screen()
	var lc: Node = s.get_node_or_null("ListScroll/list_content")
	_assert(lc != null, "list_content exists for opponent subtitle test")
	if lc == null:
		s.free()
		return
	var seen := 0
	for c in lc.get_children():
		if c is Label and String(c.name).begins_with("opponent_subtitle_"):
			seen += 1
			var lbl: Label = c
			_assert(lbl.text != "", "%s non-empty" % c.name)
			# <=10 words per design.
			_assert(lbl.text.split(" ").size() <= 10, "%s <=10 words: '%s'" % [c.name, lbl.text])
	_assert(seen == 3, "3 opponent subtitles rendered (got %d)" % seen)
	s.free()

# --- T2 #103 #4: weight caption ---

func _test_weight_caption_states() -> void:
	var s := _mk_loadout_screen(0, 0)
	# Pure helpers — no scene needed.
	var under: String = s.call("_weight_caption_text", 30, 50)
	var atcap: String = s.call("_weight_caption_text", 50, 50)
	var over: String = s.call("_weight_caption_text", 60, 50)
	_assert(under.contains("headroom"), "under-cap caption mentions headroom: '%s'" % under)
	_assert(atcap.contains("capacity"), "at-cap caption mentions capacity: '%s'" % atcap)
	_assert(over.contains("Over") and over.contains("penalty"), "over-cap caption flags penalty: '%s'" % over)
	# Color: over-cap should be red-ish (R > G).
	var over_color: Color = s.call("_weight_caption_color", 60, 50)
	_assert(over_color.r > over_color.g, "over-cap caption color is red-tinted")
	s.free()

# --- T2 #103 #6: result-screen progress caption ---

func _test_progress_caption_states() -> void:
	# Pre-bronze, no wins.
	var s1 := _mk_result_screen([], "scrapyard", false)
	var p1_node: Node = s1.get_node_or_null("league_progress_caption")
	_assert(p1_node != null, "league_progress_caption exists in fresh state")
	if p1_node != null:
		var p1: Label = p1_node
		_assert(p1.text.contains("Scrapyard") and p1.text.contains("0/3"), "fresh progress text: '%s'" % p1.text)
		_assert(p1.text.contains("3 wins") or p1.text.contains("wins to Bronze"), "fresh state mentions Bronze gate: '%s'" % p1.text)
	s1.free()
	# One win away.
	var s2 := _mk_result_screen(["scrapyard_0", "scrapyard_1"], "scrapyard", false)
	var p2_node: Node = s2.get_node_or_null("league_progress_caption")
	if p2_node != null:
		var p2: Label = p2_node
		_assert(p2.text.contains("2/3"), "2/3 progress: '%s'" % p2.text)
		_assert(p2.text.contains("1 win to Bronze"), "one-away mentions BrottBrain: '%s'" % p2.text)
	s2.free()
	# Bronze unlocked.
	var s3 := _mk_result_screen(["scrapyard_0", "scrapyard_1", "scrapyard_2"], "scrapyard", true)
	var p3_node: Node = s3.get_node_or_null("league_progress_caption")
	if p3_node != null:
		var p3: Label = p3_node
		_assert(p3.text.contains("3/3"), "post-unlock 3/3: '%s'" % p3.text)
		# After bronze_unlocked, suffix should NOT add "wins to Bronze" since gate
		# is closed; it just shows the count.
		_assert(not p3.text.contains("wins to Bronze"), "post-unlock omits gate hint: '%s'" % p3.text)
	s3.free()
