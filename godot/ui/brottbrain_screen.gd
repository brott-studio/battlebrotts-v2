## BrottBrain editor — card-based visual editor (Sprint 4).
## Reorder model is button-based: tap a card to select, then use ▲/▼ to move it.
## Each card: [emoji] "When..." → [emoji] "Then..."
## 8 slots, button-based reorder, smart defaults, tutorial on first visit.
## [S17.3-002] Removed "drag-to-reorder" claim — UI has no drag handlers; click/tap is the honest UX.
class_name BrottBrainScreen
extends Control

signal continue_pressed
signal back_pressed

var game_state: GameState
var brain: BrottBrain
var tutorial_dismissed: bool = false  # persists per session; ideally save to disk

# Trigger display data: [emoji, label, param_type, default_param]
# param_type: "pct" (0-100% slider), "tiles" (distance), "seconds" (time), "module" (dropdown), "none", "tiles_per_sec" (S14.2)
# Display table is indexed by Trigger enum value — entries must stay aligned with BrottBrain.Trigger.
# HIDDEN_TRIGGERS lists enum values that remain in the table (so existing saves render) but are omitted from the Available Cards tray.
const TRIGGER_DISPLAY := [
	["💔", "When I'm Hurt", "pct", 0.4],
	["💪", "When I'm Healthy", "pct", 0.7],
	["🔋", "When I'm Low on Energy", "pct", 0.3],
	["⚡", "When I'm Charged Up", "pct", 0.8],
	["💔", "When They're Hurt", "pct", 0.3],
	["📏", "When They're Close", "tiles", 3],
	["📏", "When They're Far", "tiles", 8],
	["🧱", "When They're In Cover", "none", 0],
	["✅", "When Gadget Is Ready", "module", ""],
	["⏱️", "When the Clock Says", "seconds", 30],  # S14.2: hidden from tray (see HIDDEN_TRIGGERS), retained for save-compat.
	["🏃", "When They're Running", "tiles_per_sec", 4],  # S14.2 Slice B
	["🎯", "When I Just Hit Them", "seconds", 2],       # S14.2 Slice B
]

# Action display data: [emoji, label, param_type, default_param]
const ACTION_DISPLAY := [
	["🔄", "Switch Stance", "stance", 0],
	["🔧", "Use Gadget", "module", ""],
	["🎯", "Pick a Target", "target", "nearest"],
	["🔫", "Weapons", "weapon_mode", "all_fire"],
	["🧱", "Get to Cover", "none", null],       # S14.2: hidden from tray (see HIDDEN_ACTIONS), retained for save-compat.
	["📍", "Hold the Center", "none", null],
	["🏃", "Chase Them", "none", null],         # S14.2 Slice B
	["🎯", "Focus the Weakest", "none", null],   # S14.2 Slice B
]

# S14.2 Slices B/C: enum values intentionally omitted from the Available Cards tray.
# Entries remain present in the display tables above so that existing saves referencing
# these cards still render with correct labels, and evaluate without crashing.
const HIDDEN_TRIGGERS := [BrottBrain.Trigger.WHEN_CLOCK_SAYS]
const HIDDEN_ACTIONS := [BrottBrain.Action.GET_TO_COVER]

const STANCE_NAMES := ["🔥 Go Get 'Em!", "🛡️ Play it Safe", "🔄 Hit & Run", "🕳️ Lie in Wait"]
const TARGET_MODES := ["nearest", "weakest", "biggest_threat"]
const WEAPON_MODES := ["all_fire", "conserve", "hold_fire"]

# [S17.3-002] Empty-slot prompt text. Must not contain the word "drag" —
# reordering is button-based, cards are added by tapping a WHEN then a THEN.
# Tested by tests/test_s17_3_002_drag_lie.gd.
const EMPTY_SLOT_TEXT_TEMPLATE := "  %d. ┌ ─ ─  + Tap to add card  ─ ─ ┐"

# [S17.3-003] Delete button affordance — red tint at rest, darker red on hover.
# Pulled directly from sprint-17.3.md §"Task specs" → "S17.3-003".
const DELETE_BTN_MODULATE_REST: Color = Color(1.0, 0.4, 0.4)
const DELETE_BTN_MODULATE_HOVER: Color = Color(1.0, 0.2, 0.2)
const DELETE_BTN_TOOLTIP: String = "Delete this card"

var selected_card_index: int = -1

func setup(state: GameState, existing_brain: BrottBrain = null) -> void:
	game_state = state
	if existing_brain != null:
		brain = existing_brain
	else:
		brain = BrottBrain.default_for_chassis(state.equipped_chassis)
	_build_ui()

func _build_ui() -> void:
	for c in get_children():
		c.queue_free()
	
	# Header
	var header := Label.new()
	header.text = "🧠 BrottBrain Editor"
	header.add_theme_font_size_override("font_size", 28)
	header.position = Vector2(20, 10)
	header.size = Vector2(500, 40)
	add_child(header)
	
	# Help button
	var help_btn := Button.new()
	help_btn.text = "?"
	help_btn.position = Vector2(530, 15)
	help_btn.size = Vector2(30, 30)
	help_btn.pressed.connect(_show_tutorial)
	add_child(help_btn)
	
	# Default stance selector
	var stance_lbl := Label.new()
	stance_lbl.text = "Default Stance:"
	stance_lbl.position = Vector2(20, 55)
	stance_lbl.size = Vector2(140, 30)
	add_child(stance_lbl)
	
	var stance_opt := OptionButton.new()
	for s in STANCE_NAMES:
		stance_opt.add_item(s)
	stance_opt.selected = brain.default_stance
	stance_opt.position = Vector2(160, 55)
	stance_opt.size = Vector2(220, 30)
	stance_opt.item_selected.connect(func(idx: int): brain.default_stance = idx)
	add_child(stance_opt)
	
	# Tutorial banner for smart defaults
	var banner := Label.new()
	banner.text = "These are your Brott's instincts. Change them, reorder them, or add more!"
	banner.add_theme_font_size_override("font_size", 11)
	banner.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	banner.position = Vector2(20, 88)
	banner.size = Vector2(700, 20)
	add_child(banner)
	
	# Priority list header
	var list_hdr := Label.new()
	list_hdr.text = "Priority List (top = highest priority, max %d):" % BrottBrain.MAX_CARDS
	list_hdr.add_theme_font_size_override("font_size", 14)
	list_hdr.position = Vector2(20, 108)
	list_hdr.size = Vector2(500, 22)
	add_child(list_hdr)
	
	# Draw card slots
	var y := 132
	for i in range(brain.cards.size()):
		y = _draw_card(i, y)
	
	# Empty slot indicator
	if brain.cards.size() < BrottBrain.MAX_CARDS:
		var empty := Label.new()
		empty.text = EMPTY_SLOT_TEXT_TEMPLATE % (brain.cards.size() + 1)
		empty.add_theme_font_size_override("font_size", 12)
		empty.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		empty.position = Vector2(30, y)
		empty.size = Vector2(600, 25)
		add_child(empty)
		y += 30
	
	# Reorder / remove buttons (right side)
	var btn_x := 680
	var move_up := Button.new()
	move_up.text = "▲ Up"
	move_up.position = Vector2(btn_x, 132)
	move_up.size = Vector2(90, 32)
	move_up.pressed.connect(_move_card_up)
	add_child(move_up)
	
	var move_down := Button.new()
	move_down.text = "▼ Down"
	move_down.position = Vector2(btn_x, 168)
	move_down.size = Vector2(90, 32)
	move_down.pressed.connect(_move_card_down)
	add_child(move_down)
	
	# Available cards tray
	var tray_y: int = maxi(y + 15, 380)
	var tray_hdr := Label.new()
	tray_hdr.text = "── Available Cards ──"
	tray_hdr.add_theme_font_size_override("font_size", 14)
	tray_hdr.position = Vector2(20, tray_y)
	tray_hdr.size = Vector2(400, 22)
	add_child(tray_hdr)
	tray_y += 25
	
	# Trigger cards
	var trig_lbl := Label.new()
	trig_lbl.text = "WHEN:"
	trig_lbl.add_theme_font_size_override("font_size", 11)
	trig_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	trig_lbl.position = Vector2(25, tray_y)
	trig_lbl.size = Vector2(50, 20)
	add_child(trig_lbl)
	
	var tx := 80
	for i in range(TRIGGER_DISPLAY.size()):
		if i in HIDDEN_TRIGGERS:
			continue
		var td: Array = TRIGGER_DISPLAY[i]
		var tbtn := Button.new()
		tbtn.text = "%s %s" % [td[0], td[1].replace("When ", "")]
		tbtn.add_theme_font_size_override("font_size", 10)
		tbtn.position = Vector2(tx, tray_y)
		tbtn.size = Vector2(110, 24)
		tbtn.pressed.connect(_start_add_trigger.bind(i))
		add_child(tbtn)
		tx += 115
		if tx > 700:
			tx = 80
			tray_y += 28
	tray_y += 30
	
	# Action cards
	var act_lbl := Label.new()
	act_lbl.text = "THEN:"
	act_lbl.add_theme_font_size_override("font_size", 11)
	act_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	act_lbl.position = Vector2(25, tray_y)
	act_lbl.size = Vector2(50, 20)
	add_child(act_lbl)
	
	var ax := 80
	for i in range(ACTION_DISPLAY.size()):
		if i in HIDDEN_ACTIONS:
			continue
		var ad: Array = ACTION_DISPLAY[i]
		var abtn := Button.new()
		abtn.text = "%s %s" % [ad[0], ad[1]]
		abtn.add_theme_font_size_override("font_size", 10)
		abtn.position = Vector2(ax, tray_y)
		abtn.size = Vector2(120, 24)
		abtn.pressed.connect(_start_add_action.bind(i))
		add_child(abtn)
		ax += 125
		if ax > 700:
			ax = 80
			tray_y += 28
	
	# Navigation
	var back_btn := Button.new()
	back_btn.text = "← Loadout"
	back_btn.position = Vector2(20, 650)
	back_btn.size = Vector2(150, 50)
	back_btn.pressed.connect(func(): back_pressed.emit())
	add_child(back_btn)
	
	var cont_btn := Button.new()
	cont_btn.text = "Fight! →"
	cont_btn.position = Vector2(1050, 650)
	cont_btn.size = Vector2(200, 50)
	cont_btn.add_theme_font_size_override("font_size", 18)
	cont_btn.pressed.connect(func(): continue_pressed.emit())
	add_child(cont_btn)
	
	# Show tutorial on first visit
	if not tutorial_dismissed:
		_show_tutorial()

func _draw_card(index: int, y: int) -> int:
	var card: BrottBrain.BehaviorCard = brain.cards[index]
	var td: Array = TRIGGER_DISPLAY[card.trigger]
	var ad: Array = ACTION_DISPLAY[card.action]
	
	# Card background panel
	var panel := Panel.new()
	panel.position = Vector2(30, y)
	panel.size = Vector2(640, 50)
	add_child(panel)
	
	# Priority number
	var num_lbl := Label.new()
	num_lbl.text = "%d." % (index + 1)
	num_lbl.add_theme_font_size_override("font_size", 14)
	num_lbl.position = Vector2(35, y + 5)
	num_lbl.size = Vector2(25, 40)
	add_child(num_lbl)
	
	# Trigger side: [emoji] "When..." + param
	var trig_text := "%s %s" % [td[0], td[1]]
	var param_text := _format_trigger_param(card.trigger, card.trigger_param)
	if param_text != "":
		trig_text += " %s" % param_text
	
	var trig_lbl := Label.new()
	trig_lbl.text = trig_text
	trig_lbl.add_theme_font_size_override("font_size", 12)
	trig_lbl.position = Vector2(60, y + 5)
	trig_lbl.size = Vector2(260, 20)
	add_child(trig_lbl)
	
	# Arrow
	var arrow := Label.new()
	arrow.text = "→"
	arrow.add_theme_font_size_override("font_size", 18)
	arrow.position = Vector2(320, y + 8)
	arrow.size = Vector2(30, 30)
	add_child(arrow)
	
	# Action side: [emoji] "Then..." + param
	var act_text := "%s %s" % [ad[0], ad[1]]
	var aparam_text := _format_action_param(card.action, card.action_param)
	if aparam_text != "":
		act_text += " (%s)" % aparam_text
	
	var act_lbl := Label.new()
	act_lbl.text = act_text
	act_lbl.add_theme_font_size_override("font_size", 12)
	act_lbl.position = Vector2(355, y + 5)
	act_lbl.size = Vector2(260, 20)
	add_child(act_lbl)
	
	# Param edit hint (smaller text)
	var hint := Label.new()
	hint.text = "tap to edit params"
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hint.position = Vector2(60, y + 28)
	hint.size = Vector2(200, 15)
	add_child(hint)
	
	# Delete button — [S17.3-003] red tint + tooltip + pointer cursor.
	# Spec: sprints/sprint-17.3.md §"Task specs" → "S17.3-003".
	var del_btn := Button.new()
	del_btn.text = "✕"
	del_btn.position = Vector2(625, y + 10)
	del_btn.size = Vector2(35, 28)
	del_btn.modulate = DELETE_BTN_MODULATE_REST
	del_btn.tooltip_text = DELETE_BTN_TOOLTIP
	del_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	del_btn.mouse_entered.connect(_on_delete_btn_mouse_entered.bind(del_btn))
	del_btn.mouse_exited.connect(_on_delete_btn_mouse_exited.bind(del_btn))
	del_btn.pressed.connect(_remove_card.bind(index))
	add_child(del_btn)
	
	# Select for reorder on click
	var select_btn := Button.new()
	select_btn.text = ""
	select_btn.flat = true
	select_btn.position = Vector2(30, y)
	select_btn.size = Vector2(590, 50)
	select_btn.modulate = Color(1, 1, 1, 0.01)  # nearly invisible overlay
	select_btn.pressed.connect(func(): selected_card_index = index)
	add_child(select_btn)
	
	return y + 55

func _format_trigger_param(trigger: int, param: Variant) -> String:
	var td: Array = TRIGGER_DISPLAY[trigger]
	match td[2]:
		"pct":
			return "below %d%%" % int(float(param) * 100) if trigger in [0, 2, 4] else "above %d%%" % int(float(param) * 100)
		"tiles":
			return "within %s tiles" % str(param) if trigger == 5 else "beyond %s tiles" % str(param)
		"tiles_per_sec":
			return "at %s tiles/sec" % str(param)
		"seconds":
			# S14.2: WHEN_I_JUST_HIT_THEM reads as a grace window, not a timestamp.
			if trigger == BrottBrain.Trigger.WHEN_I_JUST_HIT_THEM:
				return "within last %ss" % str(param)
			return "after %ss" % str(param)
		"module":
			return str(param) if str(param) != "" else ""
	return ""

func _format_action_param(action: int, param: Variant) -> String:
	match action:
		0:  # Switch Stance
			var idx := int(param) if param != null else 0
			return STANCE_NAMES[idx] if idx < STANCE_NAMES.size() else str(param)
		1:  # Use Gadget
			return str(param) if str(param) != "" else "none"
		2:  # Pick Target
			return str(param)
		3:  # Weapons
			return str(param)
	return ""

# --- Card manipulation ---

var _pending_trigger: int = -1

func _start_add_trigger(trigger_idx: int) -> void:
	if brain.cards.size() >= BrottBrain.MAX_CARDS:
		return
	_pending_trigger = trigger_idx

func _start_add_action(action_idx: int) -> void:
	if _pending_trigger < 0:
		# No trigger selected, can't add action alone
		return
	if brain.cards.size() >= BrottBrain.MAX_CARDS:
		return
	
	var td: Array = TRIGGER_DISPLAY[_pending_trigger]
	var ad: Array = ACTION_DISPLAY[action_idx]
	var trigger_param: Variant = td[3]
	var action_param: Variant = ad[3]
	
	# Smart defaults for module params
	if td[2] == "module" and game_state.equipped_modules.size() > 0:
		trigger_param = ModuleData.get_module(game_state.equipped_modules[0])["name"]
	if ad[2] == "module" and game_state.equipped_modules.size() > 0:
		action_param = ModuleData.get_module(game_state.equipped_modules[0])["name"]
	
	var card := BrottBrain.BehaviorCard.new(_pending_trigger, trigger_param, action_idx, action_param)
	brain.add_card(card)
	_pending_trigger = -1
	_build_ui()

func _remove_card(index: int) -> void:
	brain.cards.remove_at(index)
	if selected_card_index >= brain.cards.size():
		selected_card_index = brain.cards.size() - 1
	_build_ui()

# [S17.3-003] Hover handlers for the per-row delete button. Kept as named
# funcs (not inline lambdas) so tests can invoke them directly without having
# to synthesize a mouse_entered signal against a live viewport.
func _on_delete_btn_mouse_entered(btn: Button) -> void:
	btn.modulate = DELETE_BTN_MODULATE_HOVER

func _on_delete_btn_mouse_exited(btn: Button) -> void:
	btn.modulate = DELETE_BTN_MODULATE_REST

func _move_card_up() -> void:
	if selected_card_index <= 0 or selected_card_index >= brain.cards.size():
		return
	var temp = brain.cards[selected_card_index]
	brain.cards[selected_card_index] = brain.cards[selected_card_index - 1]
	brain.cards[selected_card_index - 1] = temp
	selected_card_index -= 1
	_build_ui()

func _move_card_down() -> void:
	if selected_card_index < 0 or selected_card_index >= brain.cards.size() - 1:
		return
	var temp = brain.cards[selected_card_index]
	brain.cards[selected_card_index] = brain.cards[selected_card_index + 1]
	brain.cards[selected_card_index + 1] = temp
	selected_card_index += 1
	_build_ui()

func _show_tutorial() -> void:
	# Simple tutorial overlay
	var overlay := Panel.new()
	overlay.position = Vector2(150, 200)
	overlay.size = Vector2(500, 200)
	overlay.name = "TutorialOverlay"
	add_child(overlay)
	
	var step1 := Label.new()
	step1.text = "1️⃣ Your Brott checks these rules top to bottom every moment.\n   First match wins!"
	step1.add_theme_font_size_override("font_size", 13)
	step1.position = Vector2(170, 220)
	step1.size = Vector2(460, 40)
	add_child(step1)
	
	var step2 := Label.new()
	step2.text = "2️⃣ Each rule is simple: WHEN something happens → DO something."
	step2.add_theme_font_size_override("font_size", 13)
	step2.position = Vector2(170, 270)
	step2.size = Vector2(460, 30)
	add_child(step2)
	
	var step3 := Label.new()
	step3.text = "3️⃣ Click a WHEN card, then a THEN card to add new rules.\n   You can have up to 8!"
	step3.add_theme_font_size_override("font_size", 13)
	step3.position = Vector2(170, 310)
	step3.size = Vector2(460, 40)
	add_child(step3)
	
	var got_it := Button.new()
	got_it.text = "Got it!"
	got_it.position = Vector2(350, 360)
	got_it.size = Vector2(100, 35)
	got_it.pressed.connect(func():
		tutorial_dismissed = true
		_build_ui()
	)
	add_child(got_it)

func get_brain() -> BrottBrain:
	return brain
