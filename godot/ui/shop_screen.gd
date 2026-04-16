## Shop screen — Sprint 4: shows archetype + description, stats behind toggle
class_name ShopScreen
extends Control

signal item_purchased(category: String, type: int)
signal continue_pressed

var game_state: GameState
var details_expanded: Dictionary = {}  # track which items have stats expanded
var _item_container: Control  # scroll content container for shop items

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
	
	# ScrollContainer for shop items
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 60)
	scroll.size = Vector2(1280, 580)  # Leave room for header and continue button
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	
	var scroll_content := Control.new()
	scroll.add_child(scroll_content)
	_item_container = scroll_content
	
	var y_offset := 0
	
	# Weapons section
	y_offset = _add_section("WEAPONS", y_offset)
	for wt in GameState.WEAPON_PRICES.keys():
		var wd := WeaponData.get_weapon(wt)
		var price: int = GameState.WEAPON_PRICES[wt]
		var owned: bool = wt in game_state.owned_weapons
		y_offset = _add_shop_item_v2(wd, price, owned, "weapon", wt, y_offset)
	
	# Armor section
	y_offset = _add_section("ARMOR", y_offset + 10)
	for at in GameState.ARMOR_PRICES.keys():
		var ad := ArmorData.get_armor(at)
		var price: int = GameState.ARMOR_PRICES[at]
		var owned: bool = at in game_state.owned_armor
		y_offset = _add_shop_item_v2(ad, price, owned, "armor", at, y_offset)
	
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
		y_offset = _add_shop_item_v2(md, price, owned, "module", mt, y_offset)
	
	# Set scroll content height so ScrollContainer knows the full extent
	scroll_content.custom_minimum_size.y = y_offset
	
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
	_item_container.add_child(lbl)
	return y + 30

func _add_shop_item_v2(data: Dictionary, price: int, owned: bool, category: String, type: int, y: int) -> int:
	var item_name: String = data["name"]
	var archetype: String = data.get("archetype", "")
	var desc: String = data.get("description", "")
	var key: String = "%s_%d" % [category, type]
	
	# Main row: archetype + name + price/owned
	var hbox := HBoxContainer.new()
	hbox.position = Vector2(40, y)
	hbox.size = Vector2(700, 30)
	
	var lbl := Label.new()
	var display_text: String = ""
	if owned:
		display_text = "✅ %s — %s" % [item_name, archetype]
	elif price == 0:
		display_text = "%s — %s (Free)" % [item_name, archetype]
	else:
		display_text = "%s — %s — %d 🔩" % [item_name, archetype, price]
	lbl.text = display_text
	lbl.size = Vector2(400, 30)
	hbox.add_child(lbl)
	
	if not owned:
		var btn := Button.new()
		btn.text = "Buy" if price <= game_state.bolts else "Can't afford"
		btn.disabled = price > game_state.bolts
		btn.size = Vector2(120, 28)
		btn.pressed.connect(_on_buy.bind(category, type))
		hbox.add_child(btn)
	
	# Details toggle
	var det_btn := Button.new()
	det_btn.text = "📊" if not details_expanded.get(key, false) else "▲"
	det_btn.size = Vector2(40, 28)
	det_btn.pressed.connect(func():
		details_expanded[key] = not details_expanded.get(key, false)
		_build_ui()
	)
	hbox.add_child(det_btn)
	
	_item_container.add_child(hbox)
	y += 30
	
	# Description line
	if desc != "":
		var desc_lbl := Label.new()
		desc_lbl.text = desc
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		desc_lbl.position = Vector2(60, y)
		desc_lbl.size = Vector2(600, 20)
		_item_container.add_child(desc_lbl)
		y += 20
	
	# Expanded stats
	if details_expanded.get(key, false):
		for stat_key in data.keys():
			if stat_key in ["name", "archetype", "description"]:
				continue
			var stat_lbl := Label.new()
			stat_lbl.text = "  %s: %s" % [stat_key, str(data[stat_key])]
			stat_lbl.add_theme_font_size_override("font_size", 10)
			stat_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			stat_lbl.position = Vector2(70, y)
			stat_lbl.size = Vector2(500, 16)
			_item_container.add_child(stat_lbl)
			y += 16
	
	return y

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
	
	_item_container.add_child(hbox)
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
