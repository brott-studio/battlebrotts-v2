## Loadout screen — equip chassis, weapons, armor, modules
class_name LoadoutScreen
extends Control

signal continue_pressed
signal back_pressed

var game_state: GameState

func setup(state: GameState) -> void:
	game_state = state
	_build_ui()

func _build_ui() -> void:
	for c in get_children():
		c.queue_free()
	
	var ch := ChassisData.get_chassis(game_state.equipped_chassis)
	var validation := game_state.validate_loadout()
	
	# Header
	var header := Label.new()
	header.text = "🔧 LOADOUT — %s" % ch["name"]
	header.add_theme_font_size_override("font_size", 28)
	header.position = Vector2(20, 10)
	header.size = Vector2(600, 40)
	add_child(header)
	
	# Weight indicator
	var weight_lbl := Label.new()
	weight_lbl.text = "Weight: %d / %d kg" % [validation["weight"], validation["weight_cap"]]
	if not validation["valid"]:
		weight_lbl.add_theme_color_override("font_color", Color.RED)
	weight_lbl.position = Vector2(20, 50)
	weight_lbl.size = Vector2(400, 30)
	add_child(weight_lbl)
	
	var y := 90
	
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
	
	# Weapon selector
	y = _add_label("WEAPONS (slots: %d/%d):" % [game_state.equipped_weapons.size(), ch["weapon_slots"]], y + 10)
	for wt in game_state.owned_weapons:
		var wd := WeaponData.get_weapon(wt)
		var equipped := wt in game_state.equipped_weapons
		var btn := Button.new()
		btn.text = ("✓ " if equipped else "  ") + "%s (dmg:%d rng:%d wt:%dkg)" % [wd["name"], wd["damage"], wd["range_tiles"], wd["weight"]]
		btn.position = Vector2(40, y)
		btn.size = Vector2(500, 30)
		btn.pressed.connect(_toggle_weapon.bind(wt))
		add_child(btn)
		y += 32
	
	# Armor selector
	y = _add_label("ARMOR (one):", y + 10)
	# Add "None" option
	var none_btn := Button.new()
	none_btn.text = ("▶ " if game_state.equipped_armor == 0 else "  ") + "None"
	none_btn.position = Vector2(40, y)
	none_btn.size = Vector2(500, 30)
	none_btn.pressed.connect(_select_armor.bind(0))
	add_child(none_btn)
	y += 32
	for at in game_state.owned_armor:
		var ad := ArmorData.get_armor(at)
		var selected := at == game_state.equipped_armor
		var btn := Button.new()
		btn.text = ("▶ " if selected else "  ") + "%s (-%d%% wt:%dkg)" % [ad["name"], int(ad["reduction"] * 100), ad["weight"]]
		btn.position = Vector2(40, y)
		btn.size = Vector2(500, 30)
		btn.pressed.connect(_select_armor.bind(at))
		add_child(btn)
		y += 32
	
	# Module selector
	y = _add_label("MODULES (slots: %d/%d):" % [game_state.equipped_modules.size(), ch["module_slots"]], y + 10)
	for mt in game_state.owned_modules:
		var md := ModuleData.get_module(mt)
		var equipped := mt in game_state.equipped_modules
		var btn := Button.new()
		btn.text = ("✓ " if equipped else "  ") + "%s (wt:%dkg)" % [md["name"], md["weight"]]
		btn.position = Vector2(40, y)
		btn.size = Vector2(500, 30)
		btn.pressed.connect(_toggle_module.bind(mt))
		add_child(btn)
		y += 32
	
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
	
	var cont_btn := Button.new()
	cont_btn.text = "Continue →"
	cont_btn.position = Vector2(1050, 650)
	cont_btn.size = Vector2(200, 50)
	cont_btn.disabled = not validation["valid"]
	cont_btn.pressed.connect(func(): continue_pressed.emit())
	add_child(cont_btn)

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
	if wt in game_state.equipped_weapons:
		game_state.equipped_weapons.erase(wt)
	else:
		game_state.equipped_weapons.append(wt)
	_build_ui()

func _select_armor(at: int) -> void:
	game_state.equipped_armor = at
	_build_ui()

func _toggle_module(mt: int) -> void:
	if mt in game_state.equipped_modules:
		game_state.equipped_modules.erase(mt)
	else:
		game_state.equipped_modules.append(mt)
	_build_ui()
