## Shop screen — buy weapons, armor, modules with Bolts
class_name ShopScreen
extends Control

signal item_purchased(category: String, type: int)
signal continue_pressed

var game_state: GameState

func setup(state: GameState) -> void:
	game_state = state
	_build_ui()

func _build_ui() -> void:
	# Clear children
	for c in get_children():
		c.queue_free()
	
	# Title + Bolts
	var header := Label.new()
	header.text = "🔩 SHOP — %d Bolts" % game_state.bolts
	header.add_theme_font_size_override("font_size", 28)
	header.position = Vector2(20, 10)
	header.size = Vector2(600, 40)
	add_child(header)
	
	var y_offset := 60
	
	# Weapons section
	y_offset = _add_section("WEAPONS", y_offset)
	for wt in GameState.WEAPON_PRICES.keys():
		var wd := WeaponData.get_weapon(wt)
		var price: int = GameState.WEAPON_PRICES[wt]
		var owned: bool = wt in game_state.owned_weapons
		y_offset = _add_shop_item(wd["name"], price, owned, "weapon", wt, y_offset)
	
	# Armor section
	y_offset = _add_section("ARMOR", y_offset + 10)
	for at in GameState.ARMOR_PRICES.keys():
		var ad := ArmorData.get_armor(at)
		var price: int = GameState.ARMOR_PRICES[at]
		var owned: bool = at in game_state.owned_armor
		y_offset = _add_shop_item(ad["name"], price, owned, "armor", at, y_offset)
	
	# Chassis section
	y_offset = _add_section("CHASSIS", y_offset + 10)
	for ct in GameState.CHASSIS_PRICES.keys():
		var cd := ChassisData.get_chassis(ct)
		var price: int = GameState.CHASSIS_PRICES[ct]
		var owned: bool = ct in game_state.owned_chassis
		y_offset = _add_shop_item(cd["name"], price, owned, "chassis", ct, y_offset)
	
	# Modules section
	y_offset = _add_section("MODULES", y_offset + 10)
	for mt in GameState.MODULE_PRICES.keys():
		var md := ModuleData.get_module(mt)
		var price: int = GameState.MODULE_PRICES[mt]
		var owned: bool = mt in game_state.owned_modules
		y_offset = _add_shop_item(md["name"], price, owned, "module", mt, y_offset)
	
	# Continue button
	var btn := Button.new()
	btn.text = "Continue →"
	btn.position = Vector2(1050, 650)
	btn.size = Vector2(200, 50)
	btn.add_theme_font_size_override("font_size", 18)
	btn.pressed.connect(func(): continue_pressed.emit())
	add_child(btn)

func _add_section(title: String, y: int) -> int:
	var lbl := Label.new()
	lbl.text = "— %s —" % title
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.position = Vector2(20, y)
	lbl.size = Vector2(300, 30)
	add_child(lbl)
	return y + 30

func _add_shop_item(item_name: String, price: int, owned: bool, category: String, type: int, y: int) -> int:
	var hbox := HBoxContainer.new()
	hbox.position = Vector2(40, y)
	hbox.size = Vector2(500, 30)
	
	var lbl := Label.new()
	if owned:
		lbl.text = "✅ %s" % item_name
	elif price == 0:
		lbl.text = "%s (Free)" % item_name
	else:
		lbl.text = "%s — %d 🔩" % [item_name, price]
	lbl.size = Vector2(300, 30)
	hbox.add_child(lbl)
	
	if not owned:
		var btn := Button.new()
		btn.text = "Buy" if price <= game_state.bolts else "Can't afford"
		btn.disabled = price > game_state.bolts
		btn.size = Vector2(120, 28)
		btn.pressed.connect(_on_buy.bind(category, type))
		hbox.add_child(btn)
	
	add_child(hbox)
	return y + 30

func _on_buy(category: String, type: int) -> void:
	var success := false
	match category:
		"weapon": success = game_state.buy_weapon(type)
		"armor": success = game_state.buy_armor(type)
		"chassis": success = game_state.buy_chassis(type)
		"module": success = game_state.buy_module(type)
	if success:
		item_purchased.emit(category, type)
		_build_ui()  # Rebuild to reflect changes
