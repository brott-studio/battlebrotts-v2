## BrottBrain editor — drag behavior cards into priority slots
## Simple list UI for prototype
class_name BrottBrainScreen
extends Control

signal continue_pressed
signal back_pressed

var game_state: GameState
var brain: BrottBrain
var card_list: ItemList
var trigger_option: OptionButton
var action_option: OptionButton
var trigger_param_input: SpinBox
var action_param_option: OptionButton

const TRIGGER_NAMES := [
	"When I'm Hurt", "When I'm Healthy", "When I'm Low on Juice",
	"When I'm Charged Up", "When They're Hurt", "When They're Close",
	"When They're Far", "When They're In Cover", "When Gadget Is Ready",
	"When the Clock Says"
]

const ACTION_NAMES := [
	"Switch Stance", "Use Gadget", "Pick a Target",
	"Weapons", "Get to Cover", "Hold the Center"
]

const STANCE_NAMES := ["Go Get 'Em!", "Play it Safe", "Hit & Run", "Lie in Wait"]
const TARGET_MODES := ["nearest", "weakest", "biggest_threat"]
const WEAPON_MODES := ["all_fire", "conserve", "hold_fire"]

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
	header.text = "🧠 BROTTBRAIN EDITOR"
	header.add_theme_font_size_override("font_size", 28)
	header.position = Vector2(20, 10)
	header.size = Vector2(600, 40)
	add_child(header)
	
	# Default stance
	var stance_lbl := Label.new()
	stance_lbl.text = "Default Stance:"
	stance_lbl.position = Vector2(20, 55)
	stance_lbl.size = Vector2(150, 30)
	add_child(stance_lbl)
	
	var stance_opt := OptionButton.new()
	for s in STANCE_NAMES:
		stance_opt.add_item(s)
	stance_opt.selected = brain.default_stance
	stance_opt.position = Vector2(170, 55)
	stance_opt.size = Vector2(200, 30)
	stance_opt.item_selected.connect(func(idx: int): brain.default_stance = idx)
	add_child(stance_opt)
	
	# Card list
	var list_label := Label.new()
	list_label.text = "Behavior Cards (top = highest priority, max %d):" % BrottBrain.MAX_CARDS
	list_label.position = Vector2(20, 95)
	list_label.size = Vector2(500, 25)
	add_child(list_label)
	
	card_list = ItemList.new()
	card_list.position = Vector2(20, 120)
	card_list.size = Vector2(700, 250)
	_refresh_card_list()
	add_child(card_list)
	
	# Move up/down/remove buttons
	var move_up := Button.new()
	move_up.text = "▲ Up"
	move_up.position = Vector2(730, 120)
	move_up.size = Vector2(100, 35)
	move_up.pressed.connect(_move_card_up)
	add_child(move_up)
	
	var move_down := Button.new()
	move_down.text = "▼ Down"
	move_down.position = Vector2(730, 160)
	move_down.size = Vector2(100, 35)
	move_down.pressed.connect(_move_card_down)
	add_child(move_down)
	
	var remove := Button.new()
	remove.text = "✕ Remove"
	remove.position = Vector2(730, 200)
	remove.size = Vector2(100, 35)
	remove.pressed.connect(_remove_card)
	add_child(remove)
	
	# Add card section
	var add_lbl := Label.new()
	add_lbl.text = "Add New Card:"
	add_lbl.add_theme_font_size_override("font_size", 18)
	add_lbl.position = Vector2(20, 385)
	add_lbl.size = Vector2(200, 30)
	add_child(add_lbl)
	
	# Trigger selector
	var t_lbl := Label.new()
	t_lbl.text = "WHEN:"
	t_lbl.position = Vector2(20, 420)
	t_lbl.size = Vector2(60, 30)
	add_child(t_lbl)
	
	trigger_option = OptionButton.new()
	for t in TRIGGER_NAMES:
		trigger_option.add_item(t)
	trigger_option.position = Vector2(80, 420)
	trigger_option.size = Vector2(250, 30)
	add_child(trigger_option)
	
	var tp_lbl := Label.new()
	tp_lbl.text = "Param:"
	tp_lbl.position = Vector2(340, 420)
	tp_lbl.size = Vector2(60, 30)
	add_child(tp_lbl)
	
	trigger_param_input = SpinBox.new()
	trigger_param_input.min_value = 0.1
	trigger_param_input.max_value = 120.0
	trigger_param_input.step = 0.1
	trigger_param_input.value = 0.5
	trigger_param_input.position = Vector2(400, 420)
	trigger_param_input.size = Vector2(100, 30)
	add_child(trigger_param_input)
	
	# Action selector
	var a_lbl := Label.new()
	a_lbl.text = "DO:"
	a_lbl.position = Vector2(20, 460)
	a_lbl.size = Vector2(40, 30)
	add_child(a_lbl)
	
	action_option = OptionButton.new()
	for a in ACTION_NAMES:
		action_option.add_item(a)
	action_option.position = Vector2(80, 460)
	action_option.size = Vector2(250, 30)
	add_child(action_option)
	
	var ap_lbl := Label.new()
	ap_lbl.text = "Param:"
	ap_lbl.position = Vector2(340, 460)
	ap_lbl.size = Vector2(60, 30)
	add_child(ap_lbl)
	
	action_param_option = OptionButton.new()
	for s in STANCE_NAMES:
		action_param_option.add_item(s)
	for m in TARGET_MODES:
		action_param_option.add_item(m)
	for w in WEAPON_MODES:
		action_param_option.add_item(w)
	action_param_option.position = Vector2(400, 460)
	action_param_option.size = Vector2(200, 30)
	add_child(action_param_option)
	
	var add_btn := Button.new()
	add_btn.text = "+ Add Card"
	add_btn.position = Vector2(620, 440)
	add_btn.size = Vector2(120, 40)
	add_btn.pressed.connect(_add_card)
	add_child(add_btn)
	
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

func _refresh_card_list() -> void:
	card_list.clear()
	for i in range(brain.cards.size()):
		var card: BrottBrain.BehaviorCard = brain.cards[i]
		var text := "#%d: WHEN %s (%s) → DO %s (%s)" % [
			i + 1,
			TRIGGER_NAMES[card.trigger],
			str(card.trigger_param),
			ACTION_NAMES[card.action],
			str(card.action_param)
		]
		card_list.add_item(text)

func _move_card_up() -> void:
	var sel := card_list.get_selected_items()
	if sel.size() == 0 or sel[0] == 0:
		return
	var idx: int = sel[0]
	var temp = brain.cards[idx]
	brain.cards[idx] = brain.cards[idx - 1]
	brain.cards[idx - 1] = temp
	_refresh_card_list()
	card_list.select(idx - 1)

func _move_card_down() -> void:
	var sel := card_list.get_selected_items()
	if sel.size() == 0 or sel[0] >= brain.cards.size() - 1:
		return
	var idx: int = sel[0]
	var temp = brain.cards[idx]
	brain.cards[idx] = brain.cards[idx + 1]
	brain.cards[idx + 1] = temp
	_refresh_card_list()
	card_list.select(idx + 1)

func _remove_card() -> void:
	var sel := card_list.get_selected_items()
	if sel.size() == 0:
		return
	brain.cards.remove_at(sel[0])
	_refresh_card_list()

func _add_card() -> void:
	if brain.cards.size() >= BrottBrain.MAX_CARDS:
		return
	
	var trigger_idx: int = trigger_option.selected
	var action_idx: int = action_option.selected
	var trigger_param: Variant = trigger_param_input.value
	
	# Determine action param based on action type
	var action_param: Variant
	var ap_idx := action_param_option.selected
	match action_idx:
		0:  # Switch Stance
			action_param = ap_idx if ap_idx < 4 else 0
		1:  # Use Gadget — use module name
			if game_state.equipped_modules.size() > 0:
				var mt = game_state.equipped_modules[0]
				action_param = ModuleData.get_module(mt)["name"]
			else:
				action_param = ""
		2:  # Pick Target
			action_param = TARGET_MODES[ap_idx - 4] if ap_idx >= 4 and ap_idx < 7 else "nearest"
		3:  # Weapons
			action_param = WEAPON_MODES[ap_idx - 7] if ap_idx >= 7 else "all_fire"
		_:
			action_param = null
	
	var card := BrottBrain.BehaviorCard.new(trigger_idx, trigger_param, action_idx, action_param)
	brain.add_card(card)
	_refresh_card_list()

func get_brain() -> BrottBrain:
	return brain
