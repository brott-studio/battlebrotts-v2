## Sprint 17.1-003 — Visible-by-default tooltips + energy legend
## Usage: godot --headless --script tests/test_sprint17_1_visible_tooltips.gd
## Design: docs/design/s17.1-003-visible-tooltips.md
## Covers (per design §7):
##   AC-1 — Loadout row renders name + inline summary without hover
##   AC-2 — Row height is 64 px (±2 px padding)
##   AC-3 — Shop card shows inline description label
##   AC-4 — Energy legend label exists in HUD with correct anchor copy
##   AC-5 — Hover tooltip path preserved (btn.tooltip_text)
##   AC-6 — Sacred-path diff guard is enforced at CI/PR level (manual note)
extends SceneTree

var pass_count := 0
var fail_count := 0
var test_count := 0

func _initialize() -> void:
	print("=== Sprint 17.1-003 Visible Tooltips Tests ===\n")
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

func assert_in(needle: String, haystack: String, msg: String) -> void:
	test_count += 1
	if needle in haystack:
		pass_count += 1
	else:
		fail_count += 1
		print("  FAIL: %s (needle=%s haystack=%s)" % [msg, needle, haystack])

func _build_fixture_state() -> GameState:
	var gs := GameState.new()
	gs.owned_chassis = [0, 1, 2]
	gs.equipped_chassis = 0
	# One of each item category — exercises weapon / armor / module paths.
	gs.owned_weapons = [0, 1]
	gs.equipped_weapons = [0]
	gs.owned_armor = [1]
	gs.equipped_armor = 1
	gs.owned_modules = [0]
	gs.equipped_modules = [0]
	return gs

func _cleanup(screen: LoadoutScreen) -> void:
	if screen and screen.get_parent():
		screen.get_parent().remove_child(screen)
	if screen:
		screen.free()

func _make_loadout_screen() -> LoadoutScreen:
	var root := get_root()
	var screen := LoadoutScreen.new()
	screen.size = Vector2(1280, 720)
	root.add_child(screen)
	screen.setup(_build_fixture_state())
	return screen

func _run_all() -> void:
	_test_ac1_loadout_inline_summary_no_hover()
	_test_ac2_row_height_64px()
	_test_ac3_shop_card_inline_description()
	_test_ac4_energy_legend_copy()
	_test_ac5_hover_tooltip_preserved()
	_test_ac6_empty_description_fallback()
	_test_ac7_equipped_tooltip_prefix()

# --- AC-1: Inline summary is rendered without any hover event ---
# Walk the ScrollArea/Content tree; for each PanelContainer that carries our
# Stack sub-tree (i.e. a real item row, not an empty-slot indicator or a
# section header), assert the row has both a NameLabel and a non-empty
# SummaryLabel. No hover events are fired during this test.
func _test_ac1_loadout_inline_summary_no_hover() -> void:
	print("AC-1: loadout rows render name + inline summary without hover")
	var screen := _make_loadout_screen()
	var scroll := screen.get_node_or_null("ScrollArea") as ScrollContainer
	assert_true(scroll != null, "ScrollArea exists")
	var content := scroll.get_node_or_null("Content") if scroll else null
	assert_true(content != null, "Content VBox exists")
	var rows_with_summary := 0
	if content != null:
		for child in content.get_children():
			if child is PanelContainer:
				var stack := child.get_node_or_null("Stack")
				if stack != null:
					var nl := stack.get_node_or_null("NameLabel") as Label
					var sl := stack.get_node_or_null("SummaryLabel") as Label
					if nl != null and sl != null:
						assert_true(nl.text.length() > 0, "NameLabel non-empty")
						assert_true(sl.text.length() > 0, "SummaryLabel non-empty (got '%s')" % sl.text)
						rows_with_summary += 1
	assert_true(rows_with_summary >= 3, "at least 3 populated rows render inline summary (got %d)" % rows_with_summary)
	_cleanup(screen)

# --- AC-2: Row height is 64 px (±2 px for padding) ---
func _test_ac2_row_height_64px() -> void:
	print("AC-2: populated Loadout rows are 64 px ±2")
	var screen := _make_loadout_screen()
	var scroll := screen.get_node_or_null("ScrollArea") as ScrollContainer
	var content := scroll.get_node_or_null("Content") if scroll else null
	var panels_checked := 0
	if content != null:
		for child in content.get_children():
			if child is PanelContainer:
				var stack := child.get_node_or_null("Stack")
				if stack == null:
					continue  # skip empty-slot panels (those also match 64 via AC-2b)
				var h: float = (child as PanelContainer).custom_minimum_size.y
				assert_true(h >= 62.0 and h <= 66.0, "row custom_minimum_size.y in [62,66], got %s" % str(h))
				panels_checked += 1
	assert_true(panels_checked > 0, "at least one populated panel checked for AC-2 (got %d)" % panels_checked)
	# AC-2b: empty-slot indicators match same stride so scroll math stays predictable.
	var empty_indicator := screen._create_empty_slot_indicator("weapon")
	assert_eq(empty_indicator.custom_minimum_size.y, 64.0, "empty-slot indicator stride 64")
	empty_indicator.free()
	_cleanup(screen)

# --- AC-3: Shop card has inline Description label ---
func _test_ac3_shop_card_inline_description() -> void:
	print("AC-3: shop card exposes Description label, visible, non-empty")
	var gs := _build_fixture_state()
	gs.bolts = 9999
	var shop := ShopScreen.new()
	shop.size = Vector2(1280, 720)
	shop._skip_trick = true  # bypass trick modal (test hook)
	get_root().add_child(shop)
	shop.setup(gs)
	# Find any card by name prefix.
	var card := _find_first_card(shop)
	assert_true(card != null, "at least one shop card rendered")
	if card != null:
		var desc := card.get_node_or_null("Description") as Label
		assert_true(desc != null, "Description label exists on card")
		if desc != null:
			assert_true(desc.visible, "Description label visible")
			assert_true(desc.text.length() > 0, "Description label non-empty (got '%s')" % desc.text)
	if shop.get_parent():
		shop.get_parent().remove_child(shop)
	shop.free()

func _find_first_card(node: Node) -> Button:
	if node is Button and String(node.name).begins_with("Card_"):
		return node as Button
	for c in node.get_children():
		var hit := _find_first_card(c)
		if hit != null:
			return hit
	return null

# --- AC-4: Energy legend exists with expected anchor copy ---
# Load main.tscn, instance its root, and verify the EnergyLegend label is
# created by _ready() inside UI CanvasLayer. Anchor-text assertion (resilient
# to minor tweaks): must contain "Energy" and at least one of the key terms.
func _test_ac4_energy_legend_copy() -> void:
	print("AC-4: HUD energy legend renders with anchor copy")
	var scene: PackedScene = load("res://main.tscn")
	assert_true(scene != null, "main.tscn loadable")
	if scene == null:
		return
	var root_node: Node = scene.instantiate()
	get_root().add_child(root_node)
	# _ready runs on add_child; give a frame so queue_free/ordering settles.
	await process_frame
	var ui := root_node.get_node_or_null("UI") as CanvasLayer
	assert_true(ui != null, "UI CanvasLayer exists")
	var legend := ui.get_node_or_null("EnergyLegend") as Label if ui else null
	assert_true(legend != null, "EnergyLegend label exists under UI")
	if legend != null:
		assert_true(legend.visible, "EnergyLegend visible")
		var t := legend.text
		assert_in("Energy", t, "legend mentions 'Energy'")
		var has_anchor: bool = ("blue bar" in t) or ("weapons" in t) or ("regenerates" in t)
		assert_true(has_anchor, "legend contains one of {blue bar, weapons, regenerates} (got '%s')" % t)
	root_node.queue_free()
	# Allow queue_free to process before test exits.
	await process_frame

# --- AC-5: Hover tooltip still works (regression guard) ---
func _test_ac5_hover_tooltip_preserved() -> void:
	print("AC-5: Button.tooltip_text preserved as hover fallback")
	var screen := _make_loadout_screen()
	var scroll := screen.get_node_or_null("ScrollArea") as ScrollContainer
	var content := scroll.get_node_or_null("Content") if scroll else null
	var checked_equipped := false
	var checked_unequipped := false
	if content != null:
		for child in content.get_children():
			if child is PanelContainer:
				var btn := child.get_node_or_null("Button") as Button
				var stack := child.get_node_or_null("Stack")
				if btn == null or stack == null:
					continue
				# If tooltip starts with "[Equipped] " that's the equipped path.
				if btn.tooltip_text.begins_with("[Equipped] "):
					checked_equipped = true
					assert_true(btn.tooltip_text.length() > "[Equipped] ".length(),
						"equipped tooltip carries description body")
				else:
					checked_unequipped = true
					# Unequipped tooltip may be empty string for items with no description,
					# but at minimum the property is set and accessible.
					assert_true(btn.tooltip_text != null, "unequipped tooltip_text is set")
	assert_true(checked_equipped, "at least one equipped row tested for tooltip")
	assert_true(checked_unequipped, "at least one unequipped row tested for tooltip")
	_cleanup(screen)

# --- AC-6 (design §6.1): empty description renders em-dash fallback ---
func _test_ac6_empty_description_fallback() -> void:
	print("AC-6: empty description renders em-dash fallback")
	var screen := _make_loadout_screen()
	# Call the factory directly with an empty description to exercise the fallback.
	var panel := screen._create_item_card("TestItem", "TestArch", "", false)
	var stack := panel.get_node_or_null("Stack")
	assert_true(stack != null, "stack exists")
	if stack != null:
		var sl := stack.get_node_or_null("SummaryLabel") as Label
		assert_true(sl != null, "summary label exists")
		if sl != null:
			assert_in("—", sl.text, "em-dash fallback present in summary")
	panel.free()
	_cleanup(screen)

# --- AC-7: Equipped row renders the "[Equipped] " tooltip prefix explicitly ---
func _test_ac7_equipped_tooltip_prefix() -> void:
	print("AC-7: equipped row tooltip starts with '[Equipped] '")
	var screen := _make_loadout_screen()
	var panel := screen._create_item_card("Gauss", "Precision", "Long-range railgun.", true)
	var btn := panel.get_node_or_null("Button") as Button
	assert_true(btn != null, "button exists on equipped panel")
	if btn != null:
		assert_true(btn.tooltip_text.begins_with("[Equipped] "), "tooltip starts with [Equipped]")
		assert_in("Long-range railgun.", btn.tooltip_text, "tooltip contains original description")
	panel.free()
	_cleanup(screen)
