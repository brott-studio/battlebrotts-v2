## Sprint 17.3-003 — Delete interaction redesign (red tint + tooltip + pointer cursor)
## Usage: godot --headless --script tests/test_s17_3_003_delete_redesign.gd
## Spec: sprints/sprint-17.3.md §"Task specs" → "S17.3-003"
##
## Covers (acceptance):
##   AC-1a — Delete button resting modulate is Color(1.0, 0.4, 0.4).
##   AC-1b — Hover handler sets modulate to Color(1.0, 0.2, 0.2).
##   AC-2  — Cursor is CURSOR_POINTING_HAND on the delete button.
##   AC-3  — Tooltip text is "Delete this card" (no hotkey text).
##
## Strategy: build a real BrottBrainScreen with a handful of cards, locate each
## delete button by its text "✕", and assert the properties set in
## `_draw_card`. Hover state is verified by calling the hover-in/hover-out
## handlers directly (the live `mouse_entered` signal would require a real
## cursor over the control, which headless SceneTree can't simulate).
extends SceneTree

const BrottBrainScreenRef = preload("res://ui/brottbrain_screen.gd")

var pass_count := 0
var fail_count := 0
var test_count := 0

func _initialize() -> void:
	print("=== S17.3-003 Delete Redesign Tests ===\n")
	_test_constants()
	_test_rest_modulate_on_live_button()
	_test_tooltip_on_live_button()
	_test_cursor_on_live_button()
	_test_hover_handler_sets_hover_color()
	_test_exit_handler_restores_rest_color()
	print("\n=== Results: %d passed, %d failed, %d total ===" % [pass_count, fail_count, test_count])
	quit(1 if fail_count > 0 else 0)

func _assert(cond: bool, msg: String) -> void:
	test_count += 1
	if cond:
		pass_count += 1
	else:
		fail_count += 1
		print("  FAIL: %s" % msg)

# --- helpers ---

func _mk_screen(card_count: int) -> BrottBrainScreen:
	var gs := GameState.new()
	gs.equipped_chassis = ChassisData.ChassisType.BRAWLER
	gs.equipped_modules = []
	var brain := BrottBrain.default_for_chassis(gs.equipped_chassis)
	while brain.cards.size() < card_count and brain.cards.size() < BrottBrain.MAX_CARDS:
		brain.cards.append(BrottBrain.BehaviorCard.new(0, 0.4, 0, 0))
	while brain.cards.size() > card_count:
		brain.cards.pop_back()
	var screen := BrottBrainScreen.new()
	screen.size = Vector2(1280, 720)
	root.add_child(screen)
	screen.tutorial_dismissed = true
	screen.setup(gs, brain)
	return screen

func _delete_buttons(screen: BrottBrainScreen) -> Array:
	var out := []
	# [S17.4-002] Cards now live inside a ScrollContainer's content node,
	# so walk the scene tree recursively instead of scanning direct children.
	_collect_delete_buttons(screen, out)
	return out

func _collect_delete_buttons(node: Node, out: Array) -> void:
	if node is Button and not node.is_queued_for_deletion():
		if (node as Button).text == "✕":
			out.append(node)
	for child in node.get_children():
		_collect_delete_buttons(child, out)

# --- tests ---

func _test_constants() -> void:
	_assert(BrottBrainScreenRef.DELETE_BTN_MODULATE_REST == Color(1.0, 0.4, 0.4),
		"AC-1a constant DELETE_BTN_MODULATE_REST == Color(1.0, 0.4, 0.4) (got %s)"
			% str(BrottBrainScreenRef.DELETE_BTN_MODULATE_REST))
	_assert(BrottBrainScreenRef.DELETE_BTN_MODULATE_HOVER == Color(1.0, 0.2, 0.2),
		"AC-1b constant DELETE_BTN_MODULATE_HOVER == Color(1.0, 0.2, 0.2) (got %s)"
			% str(BrottBrainScreenRef.DELETE_BTN_MODULATE_HOVER))
	_assert(BrottBrainScreenRef.DELETE_BTN_TOOLTIP == "Delete this card",
		"AC-3 constant DELETE_BTN_TOOLTIP == 'Delete this card' (got: %s)"
			% BrottBrainScreenRef.DELETE_BTN_TOOLTIP)

func _test_rest_modulate_on_live_button() -> void:
	var screen := _mk_screen(3)
	var dels := _delete_buttons(screen)
	_assert(dels.size() == 3, "three delete buttons rendered (got %d)" % dels.size())
	for b in dels:
		_assert(b.modulate == Color(1.0, 0.4, 0.4),
			"AC-1a live button resting modulate == Color(1.0, 0.4, 0.4) (got %s)"
				% str(b.modulate))
	screen.queue_free()

func _test_tooltip_on_live_button() -> void:
	var screen := _mk_screen(2)
	for b in _delete_buttons(screen):
		_assert(b.tooltip_text == "Delete this card",
			"AC-3 tooltip_text == 'Delete this card' (got: %s)" % b.tooltip_text)
		# No hotkey copy smell: tooltip should not contain 'del', 'key', 'ctrl',
		# or parentheses commonly used for hotkey hints.
		var t: String = b.tooltip_text.to_lower()
		_assert(not t.contains("("), "AC-3 tooltip has no hotkey-style parentheses")
	screen.queue_free()

func _test_cursor_on_live_button() -> void:
	var screen := _mk_screen(2)
	for b in _delete_buttons(screen):
		_assert(b.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND,
			"AC-2 mouse_default_cursor_shape == CURSOR_POINTING_HAND (got %d)"
				% b.mouse_default_cursor_shape)
	screen.queue_free()

func _test_hover_handler_sets_hover_color() -> void:
	var screen := _mk_screen(1)
	var dels := _delete_buttons(screen)
	_assert(dels.size() == 1, "one delete button rendered for hover test")
	if dels.size() < 1:
		screen.queue_free()
		return
	var b: Button = dels[0]
	screen._on_delete_btn_mouse_entered(b)
	_assert(b.modulate == Color(1.0, 0.2, 0.2),
		"AC-1b hover handler sets modulate to Color(1.0, 0.2, 0.2) (got %s)"
			% str(b.modulate))
	screen.queue_free()

func _test_exit_handler_restores_rest_color() -> void:
	var screen := _mk_screen(1)
	var dels := _delete_buttons(screen)
	if dels.size() < 1:
		screen.queue_free()
		return
	var b: Button = dels[0]
	screen._on_delete_btn_mouse_entered(b)
	screen._on_delete_btn_mouse_exited(b)
	_assert(b.modulate == Color(1.0, 0.4, 0.4),
		"mouse_exited handler restores resting modulate (got %s)" % str(b.modulate))
	screen.queue_free()
