## Loadout screen — Sprint 4: archetype + description, stats behind toggle
## Sprint 12.2: Equipped state styling + weight budget bar
class_name LoadoutScreen
extends Control

signal continue_pressed
signal back_pressed

var game_state: GameState
var details_expanded: Dictionary = {}

# --- S12.2 Style Constants ---
const EQUIPPED_BG := Color("#4A90D9")
const EQUIPPED_GLOW := Color("#4A90D9", 0.5)
const UNEQUIPPED_BG := Color("#3A3A3A")
const EQUIPPED_TEXT := Color.WHITE
const UNEQUIPPED_TEXT := Color("#AAAAAA")
const WEIGHT_GREEN := Color("#4CAF50")
const WEIGHT_YELLOW := Color("#FFC107")
const WEIGHT_RED := Color("#F44336")
const EMPTY_SLOT_COLOR := Color("#666666")

var _weight_bar: ProgressBar
var _weight_label: Label
var _weight_flash_timer: float = 0.0
var _is_overweight: bool = false
var _equip_button: Button

func setup(state: GameState) -> void:
	game_state = state
	_build_ui()

func _build_ui() -> void:
	for c in get_children():
		c.queue_free()

	var ch := ChassisData.get_chassis(game_state.equipped_chassis)
	var validation := game_state.validate_loadout()
	_is_overweight = not validation["valid"] and _has_weight_error(validation["errors"])

	# Header
	var header := Label.new()
	header.text = "🔧 LOADOUT — %s" % ch["name"]
	header.add_theme_font_size_override("font_size", 28)
	header.position = Vector2(20, 10)
	header.size = Vector2(600, 40)
	add_child(header)

	# Weight budget bar (S12.2)
	_build_weight_bar(validation, ch)

	var y := 120

	# Chassis selector
	y = _add_label("CHASSIS (select one):", y)
	for ct in game_state.owned_chassis:
		var cd := ChassisData.get_chassis(ct)
		var selected := ct == game_state.equipped_chassis
		var btn := Button.new()
		btn.text = ("▶ " if selected else "  ") + cd["name"] + " (HP:%d Spd:%d W:%d/%d)" % [cd["hp"], int(cd["speed"]), cd["weapon_slots"], cd["module_slots"]]
		btn.position = Vector2(40, y)
		btn.size = Vector2(500, 30)
		btn.pressed.connect(_select_chassis.bind(ct))
		add_child(btn)
		y += 32

	# Weapon selector with equipped styling
	y = _add_label("WEAPONS (slots: %d/%d):" % [game_state.equipped_weapons.size(), ch["weapon_slots"]], y + 10)

	# Empty weapon slot indicators (S12.2)
	var empty_weapon_slots: int = ch["weapon_slots"] - game_state.equipped_weapons.size()
	for i in range(max(0, empty_weapon_slots)):
		var slot_panel := _create_empty_slot_indicator("weapon")
		slot_panel.position = Vector2(40, y)
		add_child(slot_panel)
		y += 36

	for wt in game_state.owned_weapons:
		var wd := WeaponData.get_weapon(wt)
		var equipped := wt in game_state.equipped_weapons
		var card := _create_item_card(wd["name"], wd["archetype"], wd["description"], equipped)
		card.position = Vector2(40, y)
		card.get_node("Button").pressed.connect(_toggle_weapon.bind(wt))
		add_child(card)
		y += 36

	# Armor selector
	y = _add_label("ARMOR (one):", y + 10)
	# Add "None" option
	var none_equipped := game_state.equipped_armor == 0
	var none_card := _create_item_card("None", "", "", none_equipped)
	none_card.position = Vector2(40, y)
	none_card.get_node("Button").pressed.connect(_select_armor.bind(0))
	add_child(none_card)
	y += 36
	for at in game_state.owned_armor:
		var ad := ArmorData.get_armor(at)
		var selected := at == game_state.equipped_armor
		var card := _create_item_card(ad["name"], ad["archetype"], ad["description"], selected)
		card.position = Vector2(40, y)
		card.get_node("Button").pressed.connect(_select_armor.bind(at))
		add_child(card)
		y += 36

	# Module selector with equipped styling
	y = _add_label("MODULES (slots: %d/%d):" % [game_state.equipped_modules.size(), ch["module_slots"]], y + 10)

	# Empty module slot indicators (S12.2)
	var empty_module_slots: int = ch["module_slots"] - game_state.equipped_modules.size()
	for i in range(max(0, empty_module_slots)):
		var slot_panel := _create_empty_slot_indicator("module")
		slot_panel.position = Vector2(40, y)
		add_child(slot_panel)
		y += 36

	for mt in game_state.owned_modules:
		var md := ModuleData.get_module(mt)
		var equipped := mt in game_state.equipped_modules
		var card := _create_item_card(md["name"], md["archetype"], md["description"], equipped)
		card.position = Vector2(40, y)
		card.get_node("Button").pressed.connect(_toggle_module.bind(mt))
		add_child(card)
		y += 36

	# Error display
	if not validation["valid"]:
		for err in validation["errors"]:
			y = _add_label("⚠️ " + err, y + 5, Color.RED)

	# Navigation
	var back_btn := Button.new()
	back_btn.text = "← Shop"
	back_btn.position = Vector2(20, 650)
	back_btn.size = Vector2(150, 50)
	back_btn.pressed.connect(func(): back_pressed.emit())
	add_child(back_btn)

	_equip_button = Button.new()
	_equip_button.text = "Continue →"
	_equip_button.position = Vector2(1050, 650)
	_equip_button.size = Vector2(200, 50)
	_equip_button.disabled = not validation["valid"]
	_equip_button.pressed.connect(func(): continue_pressed.emit())
	add_child(_equip_button)

## S12.2: Build the weight budget bar below header
func _build_weight_bar(validation: Dictionary, ch: Dictionary) -> void:
	var total_weight: int = validation["weight"]
	var weight_cap: int = validation["weight_cap"]
	var ratio: float = float(total_weight) / float(weight_cap) if weight_cap > 0 else 0.0

	# Weight label
	_weight_label = Label.new()
	_weight_label.text = "%d / %d kg" % [total_weight, weight_cap]
	_weight_label.add_theme_font_size_override("font_size", 14)
	_weight_label.position = Vector2(20, 50)
	_weight_label.size = Vector2(200, 20)
	add_child(_weight_label)

	# Weight bar
	_weight_bar = ProgressBar.new()
	_weight_bar.name = "WeightBar"
	_weight_bar.min_value = 0.0
	_weight_bar.max_value = float(weight_cap)
	_weight_bar.value = float(total_weight)
	_weight_bar.position = Vector2(20, 72)
	_weight_bar.size = Vector2(400, 24)
	_weight_bar.show_percentage = false

	# Color based on thresholds
	var bar_color: Color = _get_weight_color(ratio)
	var style := StyleBoxFlat.new()
	style.bg_color = bar_color
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	_weight_bar.add_theme_stylebox_override("fill", style)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color("#222222")
	bg_style.corner_radius_top_left = 3
	bg_style.corner_radius_top_right = 3
	bg_style.corner_radius_bottom_left = 3
	bg_style.corner_radius_bottom_right = 3
	_weight_bar.add_theme_stylebox_override("background", bg_style)

	add_child(_weight_bar)

## S12.2: Get weight bar color by ratio
func _get_weight_color(ratio: float) -> Color:
	if ratio > 0.9:
		return WEIGHT_RED
	elif ratio > 0.7:
		return WEIGHT_YELLOW
	else:
		return WEIGHT_GREEN

## S12.2: Create a styled item card (equipped vs unequipped)
func _create_item_card(item_name: String, archetype: String, description: String, equipped: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size = Vector2(500, 32)

	var style := StyleBoxFlat.new()
	if equipped:
		style.bg_color = EQUIPPED_BG
		style.border_color = EQUIPPED_GLOW
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1
		style.shadow_color = Color(0, 0, 0, 0.4)
		style.shadow_size = 2
		style.shadow_offset = Vector2(0, 2)
		panel.add_theme_stylebox_override("panel", style)
	else:
		style.bg_color = UNEQUIPPED_BG
		style.border_width_left = 0
		style.border_width_right = 0
		style.border_width_top = 0
		style.border_width_bottom = 0
		panel.add_theme_stylebox_override("panel", style)

	var btn := Button.new()
	btn.name = "Button"
	btn.flat = true
	var display_text: String
	if archetype != "":
		display_text = "%s — %s" % [item_name, archetype]
	else:
		display_text = item_name

	if equipped:
		btn.text = "✓ " + display_text
		btn.add_theme_color_override("font_color", EQUIPPED_TEXT)
		btn.add_theme_color_override("font_hover_color", EQUIPPED_TEXT)
	else:
		btn.text = "  " + display_text
		btn.add_theme_color_override("font_color", UNEQUIPPED_TEXT)
		btn.add_theme_color_override("font_hover_color", UNEQUIPPED_TEXT)

	btn.tooltip_text = description
	btn.size = Vector2(500, 32)

	# Accessibility: equipped state in text for screen readers
	if equipped:
		btn.tooltip_text = "[Equipped] " + description

	panel.add_child(btn)
	return panel

## S12.2: Create empty slot indicator with dashed outline and "+" icon
func _create_empty_slot_indicator(slot_type: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size = Vector2(500, 32)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = EMPTY_SLOT_COLOR
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.draw_center = false
	panel.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	lbl.name = "SlotLabel"
	lbl.text = "  + Empty %s slot" % slot_type
	lbl.add_theme_color_override("font_color", EMPTY_SLOT_COLOR)
	lbl.size = Vector2(500, 32)
	panel.add_child(lbl)

	return panel

## S12.2: Flash weight bar when overweight
func _process(delta: float) -> void:
	if _is_overweight and _weight_bar:
		_weight_flash_timer += delta
		var alpha := 0.5 + 0.5 * sin(_weight_flash_timer * 6.0)
		_weight_bar.modulate.a = alpha
	elif _weight_bar:
		_weight_bar.modulate.a = 1.0

## S12.2: Check if validation errors include weight
func _has_weight_error(errors: Array) -> bool:
	for err in errors:
		if "Overweight" in err:
			return true
	return false

func _add_label(text: String, y: int, color: Color = Color.WHITE) -> int:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", color)
	lbl.position = Vector2(20, y)
	lbl.size = Vector2(600, 25)
	add_child(lbl)
	return y + 28

func _select_chassis(ct: int) -> void:
	game_state.equipped_chassis = ct
	_build_ui()

func _toggle_weapon(wt: int) -> void:
	# S12.2: Block equipping when overweight
	if wt not in game_state.equipped_weapons and _is_overweight:
		return
	if wt in game_state.equipped_weapons:
		game_state.equipped_weapons.erase(wt)
	else:
		game_state.equipped_weapons.append(wt)
	_build_ui()

func _select_armor(at: int) -> void:
	game_state.equipped_armor = at
	_build_ui()

func _toggle_module(mt: int) -> void:
	# S12.2: Block equipping when overweight
	if mt not in game_state.equipped_modules and _is_overweight:
		return
	if mt in game_state.equipped_modules:
		game_state.equipped_modules.erase(mt)
	else:
		game_state.equipped_modules.append(mt)
	_build_ui()
