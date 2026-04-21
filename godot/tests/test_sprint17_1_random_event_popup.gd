## S17.1-005 — Random-event popup redesign (skip + preview)
## Usage: godot --headless --script tests/test_sprint17_1_random_event_popup.gd
##
## Covers design §7 acceptance tests:
##   1. Skip button present + wired (source + scene).
##   2. ESC = skip (source grep on _unhandled_input + ui_cancel).
##   3. Skip path does NOT call apply_trick_choice (source grep on the
##      "skip" branch + return ordering in shop_screen.gd).
##   4. Pre-commit preview renders resolved item name for ITEM_LOSE.
##   5. Pre-commit preview renders resolved item name for ITEM_GRANT.
##   6. No preview for pure bolts/HP tricks.
##
## Plus S13.8 regression: _trick_shown guard and queue_free() precedence
## preserved.
extends SceneTree

var pass_count := 0
var fail_count := 0
var test_count := 0

func _initialize() -> void:
	print("=== S17.1-005 Random-event popup tests ===\n")
	_run_all()
	print("\n=== Results: %d passed, %d failed, %d total ===" % [pass_count, fail_count, test_count])
	if fail_count > 0:
		quit(1)
	else:
		quit(0)

func assert_eq(a, b, msg: String) -> void:
	test_count += 1
	if a == b:
		pass_count += 1
	else:
		fail_count += 1
		print("  FAIL: %s (got %s, expected %s)" % [msg, str(a), str(b)])

func assert_true(cond: bool, msg: String) -> void:
	test_count += 1
	if cond:
		pass_count += 1
	else:
		fail_count += 1
		print("  FAIL: %s" % msg)

func _read_source(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var txt: String = f.get_as_text()
	f.close()
	return txt

func _run_all() -> void:
	_test_scene_declares_skip_button()
	_test_scene_declares_preview_row()
	_test_modal_script_wires_skip()
	_test_modal_script_wires_esc()
	_test_shop_skip_branch_bypasses_apply()
	_test_preview_item_lose()
	_test_preview_item_grant()
	_test_preview_hidden_for_bolts_only()
	_test_preview_trade()
	_test_s13_8_regressions_preserved()

## AC1 — Skip button present in scene.
func _test_scene_declares_skip_button() -> void:
	print("Scene: trick_choice_modal.tscn declares Skip button")
	var src: String = _read_source("res://ui/trick_choice_modal.tscn")
	assert_true(src.find("[node name=\"Skip\" type=\"Button\"") != -1, "Skip Button node present")
	assert_true(src.find("Not now") != -1, "Skip label = 'Not now'")
	assert_true(src.find("color = Color(0, 0, 0, 0.45)") != -1, "Overlay alpha lowered to 0.45")

## Preview row wiring in scene.
func _test_scene_declares_preview_row() -> void:
	print("Scene: PreviewRow with PreviewA/PreviewB present")
	var src: String = _read_source("res://ui/trick_choice_modal.tscn")
	assert_true(src.find("[node name=\"PreviewRow\"") != -1, "PreviewRow node present")
	assert_true(src.find("[node name=\"PreviewA\"") != -1, "PreviewA label present")
	assert_true(src.find("[node name=\"PreviewB\"") != -1, "PreviewB label present")

## AC1 — Skip wired in modal script.
func _test_modal_script_wires_skip() -> void:
	print("Source: modal script wires _btn_skip -> _on_skip and emits 'skip'")
	var src: String = _read_source("res://ui/trick_choice_modal.gd")
	assert_true(src.find("_btn_skip") != -1, "_btn_skip declared")
	assert_true(src.find("_btn_skip.pressed.connect") != -1, "_btn_skip.pressed connected")
	assert_true(src.find("func _on_skip()") != -1, "_on_skip handler exists")
	assert_true(src.find("resolved.emit(tid, \"skip\")") != -1, "skip emits resolved(id, \"skip\")")

## AC2 — ESC == skip.
func _test_modal_script_wires_esc() -> void:
	print("Source: modal script handles ui_cancel (ESC) via _unhandled_input")
	var src: String = _read_source("res://ui/trick_choice_modal.gd")
	assert_true(src.find("_unhandled_input") != -1, "_unhandled_input handler declared")
	assert_true(src.find("ui_cancel") != -1, "ui_cancel action checked")
	# ESC calls _on_skip (not a second emit path).
	var esc_block_ok: bool = false
	var idx: int = src.find("ui_cancel")
	if idx != -1:
		var tail: String = src.substr(idx, 200)
		esc_block_ok = tail.find("_on_skip()") != -1
	assert_true(esc_block_ok, "ui_cancel branch calls _on_skip()")
	assert_true(src.find("_resolving") != -1, "one-shot _resolving guard declared")

## AC3 — Skip branch in shop_screen.gd bypasses apply_trick_choice.
func _test_shop_skip_branch_bypasses_apply() -> void:
	print("Source: shop_screen.gd skip branch bypasses apply_trick_choice")
	var src: String = _read_source("res://ui/shop_screen.gd")
	var skip_idx: int = src.find("if choice_key == \"skip\":")
	var apply_idx: int = src.find("apply_trick_choice(patched, choice_key)")
	var qfree_idx: int = src.find("modal.queue_free()")
	assert_true(skip_idx != -1, "skip branch present")
	assert_true(apply_idx != -1, "apply_trick_choice call still present for non-skip paths")
	assert_true(qfree_idx != -1, "queue_free still present")
	# Ordering: queue_free < skip-branch < apply_trick_choice (skip returns
	# before apply can run; S13.8 invariant preserved for A/B paths).
	assert_true(qfree_idx < skip_idx, "queue_free() precedes skip branch (S13.8 kept)")
	assert_true(skip_idx < apply_idx, "skip branch precedes apply_trick_choice call")
	# The skip branch must contain a `return` before apply_trick_choice.
	var between: String = src.substr(skip_idx, apply_idx - skip_idx)
	assert_true(between.find("return") != -1, "skip branch returns before apply_trick_choice")

## AC4 — Preview for ITEM_LOSE renders the resolved item name.
func _test_preview_item_lose() -> void:
	print("Preview: ITEM_LOSE with a direct token renders '- You lose your <name>.'")
	var script := load("res://ui/trick_choice_modal.gd")
	# Pick a direct item token from the scrap_tinker pool so resolve_token
	# returns a stable display name without RNG.
	var tok := "minigun"
	var resolved: Dictionary = ItemTokens.resolve_token(tok)
	var expected_name: String = ItemTokens.display_name(resolved) if not resolved.is_empty() else ""
	var choice: Dictionary = {
		"label": "Hand something over",
		"effect_type": TrickChoices.EffectType.ITEM_LOSE,
		"effect_value": tok,
	}
	var line: String = script._preview_for_choice(choice)
	if expected_name != "":
		assert_true(line.find(expected_name) != -1, "preview contains resolved name '%s' (got '%s')" % [expected_name, line])
		assert_true(line.begins_with("−") or line.begins_with("- "), "lose line starts with a minus glyph (got '%s')" % line)
	else:
		# Token unresolvable in this build — preview must be empty per design.
		assert_eq(line, "", "unresolvable token yields empty preview")

## AC5 — Preview for ITEM_GRANT renders the resolved item name; equals
## what apply_trick_choice would produce for this patched choice.
func _test_preview_item_grant() -> void:
	print("Preview: ITEM_GRANT with a direct token renders '+ You receive a <name>.'")
	var script := load("res://ui/trick_choice_modal.gd")
	var tok := "overclock"
	var resolved: Dictionary = ItemTokens.resolve_token(tok)
	var expected_name: String = ItemTokens.display_name(resolved) if not resolved.is_empty() else ""
	var choice: Dictionary = {
		"label": "Crack it",
		"effect_type": TrickChoices.EffectType.ITEM_GRANT,
		"effect_value": tok,
		"flavor_line": "Nice. Found a {item_name}.",
	}
	var line: String = script._preview_for_choice(choice)
	if expected_name != "":
		assert_true(line.find(expected_name) != -1, "preview contains granted name '%s' (got '%s')" % [expected_name, line])
		assert_true(line.begins_with("+"), "grant line starts with a plus glyph (got '%s')" % line)
	else:
		assert_eq(line, "", "unresolvable token yields empty preview")

## AC6 — No preview for pure bolts/HP tricks.
func _test_preview_hidden_for_bolts_only() -> void:
	print("Preview: pure BOLTS_DELTA / HP_DELTA choices yield empty preview")
	var script := load("res://ui/trick_choice_modal.gd")
	var bolts_choice: Dictionary = {
		"label": "Walk past",
		"effect_type": TrickChoices.EffectType.BOLTS_DELTA,
		"effect_value": 0,
	}
	assert_eq(script._preview_for_choice(bolts_choice), "", "bolts-only preview is empty")
	var hp_choice: Dictionary = {
		"label": "Snap it up",
		"effect_type": TrickChoices.EffectType.HP_DELTA,
		"effect_value": -5,
	}
	assert_eq(script._preview_for_choice(hp_choice), "", "hp-only preview is empty")
	var combo: Dictionary = {
		"label": "Grab pellets",
		"effect_type": TrickChoices.EffectType.NEXT_FIGHT_PELLET_MOD,
		"effect_value": 3,
		"effect_type_2": TrickChoices.EffectType.HP_DELTA,
		"effect_value_2": -5,
	}
	assert_eq(script._preview_for_choice(combo), "", "pellet+hp preview is empty")
	assert_eq(script._preview_for_choice({}), "", "empty choice preview is empty")

## Trade preview: ITEM_LOSE + ITEM_GRANT renders both names in one line.
func _test_preview_trade() -> void:
	print("Preview: ITEM_LOSE + ITEM_GRANT renders trade template")
	var script := load("res://ui/trick_choice_modal.gd")
	var tok_lose := "minigun"
	var tok_grant := "overclock"
	var lose_name := ItemTokens.display_name(ItemTokens.resolve_token(tok_lose))
	var grant_name := ItemTokens.display_name(ItemTokens.resolve_token(tok_grant))
	if lose_name == "" or grant_name == "":
		print("  SKIP: token names unresolvable in this build")
		return
	var trade_choice: Dictionary = {
		"label": "Trade",
		"effect_type": TrickChoices.EffectType.ITEM_LOSE,
		"effect_value": tok_lose,
		"effect_type_2": TrickChoices.EffectType.ITEM_GRANT,
		"effect_value_2": tok_grant,
	}
	var line: String = script._preview_for_choice(trade_choice)
	assert_true(line.begins_with("You trade your"), "trade line starts with 'You trade your' (got '%s')" % line)

## Regression: S13.8 guards preserved after S17.1-005 changes.
func _test_s13_8_regressions_preserved() -> void:
	print("Regression: _trick_shown guard still works + queue_free ordering kept")
	var script := load("res://ui/trick_choice_modal.gd")
	var modal = script.new()
	assert_true(modal != null, "modal instantiates via script.new()")
	assert_eq(modal._trick_shown, false, "_trick_shown defaults to false")
	modal._trick_shown = true
	modal.show_trick({"id": "dummy"})
	assert_eq(modal._trick_shown, true, "_trick_shown remains true after re-entry")
	assert_true(modal._trick.is_empty(), "_trick not overwritten on re-entry (no-op)")
	modal.free()
	# _resolving defaults false on a fresh modal.
	var m2 = script.new()
	assert_eq(m2._resolving, false, "_resolving defaults to false")
	m2.free()
