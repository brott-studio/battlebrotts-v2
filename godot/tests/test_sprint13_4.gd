## Sprint 13.4 — Shop card grid UI tests
## Usage: godot --headless --script tests/test_sprint13_4.gd
## Validates structural properties of ShopScreen against Gizmo's 15 acceptance
## criteria (see docs/design/sprint13.4-shop-card-grid.md §4): card sizes,
## section order, column counts at different viewport widths, expand/collapse
## state, owned / unaffordable rendering, buy flow, continue signal contract.
extends SceneTree

var pass_count := 0
var fail_count := 0
var test_count := 0

func _init() -> void:
	pass

func _initialize() -> void:
	print("=== Sprint 13.4 Shop Card Grid Tests ===\n")
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

func _make_shop(viewport_w: int, bolts: int = 500) -> ShopScreen:
	# Clean up any leftover children from previous tests (queue_free is deferred,
	# so old shops can still be in the tree when the next test scans).
	for c in root.get_children():
		if c is ShopScreen:
			root.remove_child(c)
			c.free()
	var gs := GameState.new()
	gs.bolts = bolts
	var shop := ShopScreen.new()
	root.add_child(shop)
	shop.setup_for_viewport(gs, viewport_w)
	return shop

func _find_recursive(node: Node, name_prefix: String, out: Array) -> void:
	if node.name.begins_with(name_prefix):
		out.append(node)
	for c in node.get_children():
		_find_recursive(c, name_prefix, out)

func _run_all() -> void:
	_test_columns_desktop()
	_test_columns_mobile()
	_test_card_dimensions()
	_test_section_order()
	_test_all_items_present()
	_test_bolts_counter_font_size()
	_test_continue_signal_contract()
	_test_unaffordable_price_color()
	_test_owned_state_rendering()
	_test_archetype_tag_format()
	_test_expand_card_inline()
	_test_only_one_card_expanded()
	_test_buy_flow()
	_test_buy_button_disabled_when_unaffordable()
	_test_armor_archetype_values()

# AC #1
func _test_columns_desktop() -> void:
	print("test_columns_desktop")
	var shop := _make_shop(1280)
	var rows: Array = []
	_find_recursive(shop, "Row_WEAPONS_", rows)
	assert_true(rows.size() > 0, "at least one weapons row exists")
	var first_row: Node = rows[0]
	var cards := 0
	for c in first_row.get_children():
		if c.name.begins_with("Card_"):
			cards += 1
	assert_eq(cards, 3, "desktop 1280w → 3 columns in first weapons row")
	shop.queue_free()

# AC #2
func _test_columns_mobile() -> void:
	print("test_columns_mobile")
	var shop := _make_shop(720)
	var rows: Array = []
	_find_recursive(shop, "Row_WEAPONS_", rows)
	var first_row: Node = rows[0]
	var cards := 0
	for c in first_row.get_children():
		if c.name.begins_with("Card_"):
			cards += 1
	assert_eq(cards, 2, "mobile 720w → 2 columns in first weapons row")
	shop.queue_free()

# AC #3
func _test_card_dimensions() -> void:
	print("test_card_dimensions")
	var shop := _make_shop(1280)
	var cards: Array = []
	_find_recursive(shop, "Card_", cards)
	assert_true(cards.size() > 0, "cards exist")
	var sample: Control = cards[0]
	assert_eq(int(sample.custom_minimum_size.x), 200, "card width = 200")
	assert_eq(int(sample.custom_minimum_size.y), 240, "card height = 240")
	shop.queue_free()

# AC #4
func _test_section_order() -> void:
	print("test_section_order")
	var shop := _make_shop(1280)
	var sections: Array = []
	_find_recursive(shop, "Section_", sections)
	var order: Array = []
	for s in sections:
		order.append(String(s.name).replace("Section_", ""))
	assert_eq(order, ["WEAPONS", "ARMOR", "CHASSIS", "MODULES"], "section order WEAPONS→ARMOR→CHASSIS→MODULES")
	shop.queue_free()

# AC #5
func _test_all_items_present() -> void:
	print("test_all_items_present")
	var shop := _make_shop(1280)
	var cards: Array = []
	_find_recursive(shop, "Card_", cards)
	var expected := GameState.WEAPON_PRICES.size() \
		+ GameState.ARMOR_PRICES.size() \
		+ GameState.CHASSIS_PRICES.size() \
		+ GameState.MODULE_PRICES.size()
	assert_eq(cards.size(), expected, "all catalog items rendered (%d)" % expected)
	shop.queue_free()

# AC #6
func _test_bolts_counter_font_size() -> void:
	print("test_bolts_counter_font_size")
	var shop := _make_shop(1280, 1240)
	var b: Label = shop.find_child("BoltsCounter", true, false)
	assert_true(b != null, "BoltsCounter label exists")
	assert_eq(b.get_theme_font_size("font_size"), 36, "bolts counter font_size = 36")
	assert_true(String(b.text).begins_with("1240"), "bolts text shows current bolts")
	shop.queue_free()

# AC #7
func _test_continue_signal_contract() -> void:
	print("test_continue_signal_contract")
	var shop := _make_shop(1280)
	var emitted := [false]
	shop.continue_pressed.connect(func(): emitted[0] = true)
	var btn: Button = shop.find_child("ContinueButton", true, false)
	assert_true(btn != null, "ContinueButton exists")
	btn.pressed.emit()
	assert_eq(emitted[0], true, "continue_pressed emitted on button press")
	shop.queue_free()

# AC #8, #9
func _test_unaffordable_price_color() -> void:
	print("test_unaffordable_price_color")
	var shop := _make_shop(1280, 100)
	var cards: Array = []
	_find_recursive(shop, "Card_", cards)
	var found_unaffordable := false
	var found_affordable := false
	for card in cards:
		var pl: Label = card.find_child("Price", true, false)
		if pl == null:
			continue
		if bool(card.get_meta("owned")):
			continue
		var price: int = int(card.get_meta("price"))
		if price > 100 and price > 0:
			var col: Color = pl.get_theme_color("font_color")
			if col.r > 0.8 and col.g < 0.4:
				found_unaffordable = true
		elif price > 0 and price <= 100:
			found_affordable = true
	assert_true(found_unaffordable, "at least one unaffordable card shows red price")
	assert_true(found_affordable, "at least one affordable card exists at bolts=100")
	shop.queue_free()

# AC #10
func _test_owned_state_rendering() -> void:
	print("test_owned_state_rendering")
	var shop := _make_shop(1280)
	var cards: Array = []
	_find_recursive(shop, "Card_", cards)
	var owned_count := 0
	var badges_count := 0
	for card in cards:
		if bool(card.get_meta("owned")):
			owned_count += 1
			var badge = card.find_child("OwnedBadge", true, false)
			if badge != null:
				badges_count += 1
			var pl: Label = card.find_child("Price", true, false)
			assert_true(String(pl.text) == "✓ Owned", "owned card shows ✓ Owned")
			# 50% opacity
			assert_true(abs(card.modulate.a - 0.5) < 0.01, "owned card opacity = 0.5")
	assert_true(owned_count >= 3, "at least 3 items owned by default")
	assert_eq(badges_count, owned_count, "every owned card has ✓ badge")
	shop.queue_free()

# AC #11
func _test_archetype_tag_format() -> void:
	print("test_archetype_tag_format")
	var shop := _make_shop(1280)
	var cards: Array = []
	_find_recursive(shop, "Card_", cards)
	var weapon_checked := false
	var armor_checked := false
	for card in cards:
		if String(card.get_meta("category")) == "weapon" and not weapon_checked:
			var tag: Label = card.find_child("Tag", true, false)
			assert_true(String(tag.text).find("• Weapon") >= 0, "weapon card tag contains '• Weapon'")
			weapon_checked = true
		if String(card.get_meta("category")) == "armor" and not armor_checked:
			var tag2: Label = card.find_child("Tag", true, false)
			var t := String(tag2.text)
			assert_true(t.find("Light") >= 0 or t.find("Adaptive") >= 0 or t.find("Heavy") >= 0, "armor card tag shows Light/Adaptive/Heavy")
			armor_checked = true
	assert_true(weapon_checked, "found a weapon card to check")
	assert_true(armor_checked, "found an armor card to check")
	shop.queue_free()

# AC #12
func _test_expand_card_inline() -> void:
	print("test_expand_card_inline")
	var shop := _make_shop(1280)
	var panels: Array = []
	_find_recursive(shop, "ExpandPanel_", panels)
	assert_eq(panels.size(), 0, "no panel expanded initially")
	var cards: Array = []
	_find_recursive(shop, "Card_", cards)
	var target: Control = null
	for card in cards:
		if String(card.get_meta("category")) == "weapon" and String(card.get_meta("name")) == "Railgun":
			target = card
			break
	assert_true(target != null, "Railgun card found")
	var wt := int(target.get_meta("type"))
	shop._toggle_expand({"category": "weapon", "type": wt, "data": WeaponData.get_weapon(wt), "price": int(target.get_meta("price")), "owned": bool(target.get_meta("owned")), "name": "Railgun", "archetype": ""})
	panels = []
	_find_recursive(shop, "ExpandPanel_", panels)
	assert_eq(panels.size(), 1, "exactly one panel after expand")
	shop.queue_free()

# AC #13
func _test_only_one_card_expanded() -> void:
	print("test_only_one_card_expanded")
	var shop := _make_shop(1280)
	shop._toggle_expand({"category": "weapon", "type": 0, "data": WeaponData.get_weapon(0), "price": int(GameState.WEAPON_PRICES[0]), "owned": 0 in shop.game_state.owned_weapons, "name": "x", "archetype": ""})
	shop._toggle_expand({"category": "weapon", "type": 1, "data": WeaponData.get_weapon(1), "price": int(GameState.WEAPON_PRICES[1]), "owned": 1 in shop.game_state.owned_weapons, "name": "y", "archetype": ""})
	var panels: Array = []
	_find_recursive(shop, "ExpandPanel_", panels)
	assert_eq(panels.size(), 1, "only one panel expanded at a time")
	assert_eq(shop._expanded_key, "weapon_1", "expanded_key reflects second toggle")
	shop.queue_free()

# AC #14
func _test_buy_flow() -> void:
	print("test_buy_flow")
	var shop := _make_shop(1280, 1000)
	var gs: GameState = shop.game_state
	var target_wt := -1
	var target_price := 99999
	for wt in GameState.WEAPON_PRICES.keys():
		if not (wt in gs.owned_weapons):
			var p: int = int(GameState.WEAPON_PRICES[wt])
			if p < target_price:
				target_price = p
				target_wt = wt
	assert_true(target_wt >= 0, "found a purchasable weapon")
	var bolts_before: int = gs.bolts
	shop._on_buy("weapon", target_wt)
	assert_true(target_wt in gs.owned_weapons, "weapon owned after buy")
	assert_eq(gs.bolts, bolts_before - target_price, "bolts decremented by price")
	var cards: Array = []
	_find_recursive(shop, "Card_", cards)
	var found_owned_card := false
	for card in cards:
		if String(card.get_meta("category")) == "weapon" and int(card.get_meta("type")) == target_wt:
			if bool(card.get_meta("owned")):
				found_owned_card = true
				break
	assert_true(found_owned_card, "card re-renders as owned after buy")
	shop.queue_free()

# AC #15
func _test_buy_button_disabled_when_unaffordable() -> void:
	print("test_buy_button_disabled_when_unaffordable")
	var shop := _make_shop(1280, 10)
	var wt := WeaponData.WeaponType.RAILGUN
	shop._toggle_expand({"category": "weapon", "type": int(wt), "data": WeaponData.get_weapon(wt), "price": int(GameState.WEAPON_PRICES[wt]), "owned": wt in shop.game_state.owned_weapons, "name": "Railgun", "archetype": ""})
	var buy: Button = shop.find_child("BuyButton", true, false)
	assert_true(buy != null, "BuyButton exists in expanded panel")
	assert_eq(buy.disabled, true, "buy button disabled when unaffordable")
	assert_true(String(buy.text).find("Need") >= 0, "button text says 'Need X more'")
	shop.queue_free()

# Bonus: verify archetype data values
func _test_armor_archetype_values() -> void:
	print("test_armor_archetype_values")
	assert_eq(ArmorData.get_armor(ArmorData.ArmorType.PLATING)["archetype"], "Light", "Plating archetype = Light")
	assert_eq(ArmorData.get_armor(ArmorData.ArmorType.REACTIVE_MESH)["archetype"], "Adaptive", "Reactive Mesh archetype = Adaptive")
	assert_eq(ArmorData.get_armor(ArmorData.ArmorType.ABLATIVE_SHELL)["archetype"], "Heavy", "Ablative Shell archetype = Heavy")
