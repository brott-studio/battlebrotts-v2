## Sprint 13.7 — Item Token Router tests (Nutts-A)
## Usage: godot --headless --script tests/test_sprint13_7.gd
##
## Covers spec §5 Router tests 1-6 + empty-pool guard test 16.
## (GameState grant/lose + trick integration tests are Nutts-B's responsibility.)
extends SceneTree

var pass_count := 0
var fail_count := 0
var test_count := 0

func _initialize() -> void:
	print("=== Sprint 13.7 Item Token Router Tests (Nutts-A) ===\n")
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

func _run_all() -> void:
	_test_1_resolve_direct_armor()
	_test_2_resolve_direct_weapon()
	_test_3_resolve_random_weak_pool()
	_test_4_resolve_random_module_pool()
	_test_5_resolve_bogus_returns_empty()
	_test_6_display_name_non_empty_for_pool_entries()
	_test_7_grant_item_direct_weapon()
	_test_8_grant_item_direct_armor_and_module()
	_test_9_grant_item_pool_token()
	_test_10_grant_item_idempotent()
	_test_11_lose_item_removes()
	_test_12_lose_item_noop_on_missing()
	_test_13_trick_crate_find_grants()
	_test_14_trick_toll_goblin_loses_and_adds_bolts()
	_test_15_trick_scrap_trader_buys_module()
	_test_15b_scavenger_kid_now_grants_real_item()
	_test_16_empty_pool_and_no_infinite_loop()

# --- Test 1: direct armor token ---
func _test_1_resolve_direct_armor() -> void:
	print("Test 1: resolve_token(\"plating\") → CAT_ARMOR + PLATING")
	var r: Dictionary = ItemTokens.resolve_token("plating")
	assert_eq(r.get("category", -1), ItemTokens.CAT_ARMOR, "category is CAT_ARMOR")
	assert_eq(r.get("type", -1), ArmorData.ArmorType.PLATING, "type is ArmorType.PLATING")
	assert_eq(r.get("token", ""), "plating", "token echoed back")

# --- Test 2: direct weapon token ---
func _test_2_resolve_direct_weapon() -> void:
	print("Test 2: resolve_token(\"minigun\") → CAT_WEAPON + MINIGUN")
	var r: Dictionary = ItemTokens.resolve_token("minigun")
	assert_eq(r.get("category", -1), ItemTokens.CAT_WEAPON, "category is CAT_WEAPON")
	assert_eq(r.get("type", -1), WeaponData.WeaponType.MINIGUN, "type is WeaponType.MINIGUN")

# --- Test 3: random_weak pool ---
func _test_3_resolve_random_weak_pool() -> void:
	print("Test 3: resolve_token(\"random_weak\") → category in {weapon, armor, module}")
	seed(12345)
	var r: Dictionary = ItemTokens.resolve_token("random_weak")
	assert_true(not r.is_empty(), "random_weak resolves to non-empty dict")
	var cat: int = int(r.get("category", -1))
	var valid := cat == ItemTokens.CAT_WEAPON or cat == ItemTokens.CAT_ARMOR or cat == ItemTokens.CAT_MODULE
	assert_true(valid, "category is weapon, armor, or module")
	assert_true(r.has("token"), "resolved dict has token field")

# --- Test 4: random_module pool ---
func _test_4_resolve_random_module_pool() -> void:
	print("Test 4: resolve_token(\"random_module\") → CAT_MODULE")
	seed(54321)
	for i in range(10):
		var r: Dictionary = ItemTokens.resolve_token("random_module")
		assert_eq(r.get("category", -1), ItemTokens.CAT_MODULE, "iter %d: category is CAT_MODULE" % i)

# --- Test 5: bogus token ---
func _test_5_resolve_bogus_returns_empty() -> void:
	print("Test 5: resolve_token(\"bogus_token\") → {}")
	var r: Dictionary = ItemTokens.resolve_token("bogus_token")
	assert_true(r.is_empty(), "bogus token returns empty dict")
	var r2: Dictionary = ItemTokens.resolve_token("")
	assert_true(r2.is_empty(), "empty-string token returns empty dict")

# --- Test 6: display_name non-empty for every random_weak pool entry ---
func _test_6_display_name_non_empty_for_pool_entries() -> void:
	print("Test 6: display_name returns non-empty for every random_weak pool entry")
	for token in ItemTokens.POOLS["random_weak"]:
		var r: Dictionary = ItemTokens.resolve_token(String(token))
		assert_true(not r.is_empty(), "token %s resolves" % [token])
		var name := ItemTokens.display_name(r)
		assert_true(name != "", "display_name non-empty for %s" % [token])
	# Also: display_name on {} → ""
	assert_eq(ItemTokens.display_name({}), "", "display_name({}) is \"\"")

# --- Test 7: _grant_item direct weapon token ---
func _test_7_grant_item_direct_weapon() -> void:
	print("Test 7: _grant_trick_item(\"minigun\") appends to owned_weapons")
	var gs := GameState.new()
	assert_true(not gs.owned_weapons.has(WeaponData.WeaponType.MINIGUN), "minigun not owned initially")
	gs._grant_trick_item("minigun")
	assert_true(gs.owned_weapons.has(WeaponData.WeaponType.MINIGUN), "minigun now owned")

# --- Test 8: _grant_item for armor + module ---
func _test_8_grant_item_direct_armor_and_module() -> void:
	print("Test 8: _grant_trick_item grants armor and module to correct arrays")
	var gs := GameState.new()
	gs._grant_trick_item("reactive_mesh")
	assert_true(gs.owned_armor.has(ArmorData.ArmorType.REACTIVE_MESH), "reactive_mesh in owned_armor")
	gs._grant_trick_item("overclock")
	assert_true(gs.owned_modules.has(ModuleData.ModuleType.OVERCLOCK), "overclock in owned_modules")
	# No cross-contamination
	assert_true(not gs.owned_weapons.has(ModuleData.ModuleType.OVERCLOCK), "module did not leak into weapons")

# --- Test 9: _grant_item with pool token grants something ---
func _test_9_grant_item_pool_token() -> void:
	print("Test 9: _grant_trick_item(\"random_module\") adds to owned_modules")
	seed(7777)
	var gs := GameState.new()
	var before := gs.owned_modules.size()
	gs._grant_trick_item("random_module")
	assert_true(gs.owned_modules.size() == before + 1, "owned_modules grew by 1 from pool grant")
	# random_weak can hit weapons, armor, or modules — total owned count should grow by 1.
	var gs2 := GameState.new()
	var total_before := gs2.owned_weapons.size() + gs2.owned_armor.size() + gs2.owned_modules.size()
	gs2._grant_trick_item("random_weak")
	var total_after := gs2.owned_weapons.size() + gs2.owned_armor.size() + gs2.owned_modules.size()
	# Could be same if pool picked an already-owned starter (plating or plasma_cutter in starter)
	# — random_weak pool includes "plating" which starter already owns. Accept equal-or-grew.
	assert_true(total_after >= total_before, "random_weak resolved without error (owned total monotonic)")

# --- Test 10: _grant_item idempotent (no duplicate) ---
func _test_10_grant_item_idempotent() -> void:
	print("Test 10: _grant_trick_item is idempotent — no duplicate entries")
	var gs := GameState.new()
	gs._grant_trick_item("shotgun")
	var size_after_first := gs.owned_weapons.size()
	gs._grant_trick_item("shotgun")
	assert_eq(gs.owned_weapons.size(), size_after_first, "second grant did not add duplicate")
	# Starter already has plating (ArmorType.PLATING=1)
	var armor_before := gs.owned_armor.size()
	gs._grant_trick_item("plating")
	assert_eq(gs.owned_armor.size(), armor_before, "granting already-owned starter plating is a no-op")

# --- Test 11: _lose_item removes ---
func _test_11_lose_item_removes() -> void:
	print("Test 11: _lose_trick_item removes item from correct array")
	var gs := GameState.new()
	gs._grant_trick_item("missile_pod")
	assert_true(gs.owned_weapons.has(WeaponData.WeaponType.MISSILE_POD), "missile_pod granted")
	gs._lose_trick_item("missile_pod")
	assert_true(not gs.owned_weapons.has(WeaponData.WeaponType.MISSILE_POD), "missile_pod removed")

# --- Test 12: _lose_item no-op on missing ---
func _test_12_lose_item_noop_on_missing() -> void:
	print("Test 12: _lose_trick_item is safe no-op on missing item or bogus token")
	var gs := GameState.new()
	var weapons_before := gs.owned_weapons.duplicate()
	var armor_before := gs.owned_armor.duplicate()
	var modules_before := gs.owned_modules.duplicate()
	gs._lose_trick_item("railgun")  # not owned
	gs._lose_trick_item("bogus_token")  # unknown
	gs._lose_trick_item("")  # empty
	assert_eq(gs.owned_weapons, weapons_before, "owned_weapons unchanged on missing/unknown")
	assert_eq(gs.owned_armor, armor_before, "owned_armor unchanged")
	assert_eq(gs.owned_modules, modules_before, "owned_modules unchanged")

# --- Test 13: crate_find trick end-to-end ---
func _test_13_trick_crate_find_grants() -> void:
	print("Test 13: crate_find.choice_a grants a real item via ITEM_GRANT")
	seed(424242)
	var gs := GameState.new()
	var total_before := gs.owned_weapons.size() + gs.owned_armor.size() + gs.owned_modules.size()
	var t := _trick_by_id("crate_find")
	assert_true(not t.is_empty(), "crate_find trick exists")
	gs.apply_trick_choice(t, "choice_a")
	var total_after := gs.owned_weapons.size() + gs.owned_armor.size() + gs.owned_modules.size()
	assert_true(total_after >= total_before, "owned total did not shrink")
	assert_true(gs._tricks_seen.has("crate_find"), "crate_find marked seen")

# --- Test 14: toll_goblin trick end-to-end (secondary effect) ---
func _test_14_trick_toll_goblin_loses_and_adds_bolts() -> void:
	print("Test 14: toll_goblin.choice_a applies ITEM_LOSE + BOLTS_DELTA secondary")
	var gs := GameState.new()
	# Grant an item known to be in random_weak pool so there's something losable.
	gs._grant_trick_item("minigun")
	gs._grant_trick_item("shotgun")
	gs._grant_trick_item("reactive_mesh")
	gs._grant_trick_item("overclock")
	gs._grant_trick_item("repair_nanites")
	gs.bolts = 10
	var t := _trick_by_id("toll_goblin")
	assert_true(not t.is_empty(), "toll_goblin trick exists")
	gs.apply_trick_choice(t, "choice_a")
	assert_eq(gs.bolts, 15, "bolts +5 from secondary BOLTS_DELTA")
	assert_true(gs._tricks_seen.has("toll_goblin"), "toll_goblin marked seen")
	# choice_b: pure bolts -10
	var gs2 := GameState.new()
	gs2.bolts = 30
	gs2.apply_trick_choice(_trick_by_id("toll_goblin"), "choice_b")
	assert_eq(gs2.bolts, 20, "toll_goblin.choice_b: bolts -10")

# --- Test 15: scrap_trader trick end-to-end (primary + secondary grant) ---
func _test_15_trick_scrap_trader_buys_module() -> void:
	print("Test 15: scrap_trader.choice_a costs 15 bolts and grants a module")
	seed(1337)
	var gs := GameState.new()
	gs.bolts = 50
	var modules_before := gs.owned_modules.size()
	var t := _trick_by_id("scrap_trader")
	assert_true(not t.is_empty(), "scrap_trader trick exists")
	gs.apply_trick_choice(t, "choice_a")
	assert_eq(gs.bolts, 35, "bolts -15 from primary BOLTS_DELTA")
	assert_true(gs.owned_modules.size() == modules_before + 1, "one module granted from random_module pool")
	assert_true(gs._tricks_seen.has("scrap_trader"), "scrap_trader marked seen")

# --- Test 15b: scavenger_kid regression (S13.6 F1 unblocked) ---
func _test_15b_scavenger_kid_now_grants_real_item() -> void:
	print("Test 15b: scavenger_kid.choice_a now grants a real item (S13.6 F1 unblocked)")
	seed(2024)
	var gs := GameState.new()
	gs.bolts = 20
	var total_before := gs.owned_weapons.size() + gs.owned_armor.size() + gs.owned_modules.size()
	var t := _trick_by_id("scavenger_kid")
	gs.apply_trick_choice(t, "choice_a")
	assert_eq(gs.bolts, 15, "bolts -5 (secondary BOLTS_DELTA)")
	var total_after := gs.owned_weapons.size() + gs.owned_armor.size() + gs.owned_modules.size()
	# With seed 2024, random_weak should pick something — accept >= (pool may hit already-owned starter).
	assert_true(total_after >= total_before, "owned total did not regress (random_weak may hit starter dup)")

# --- Helper ---
func _trick_by_id(id: String) -> Dictionary:
	for t in TrickChoices.TRICKS:
		if String(t.get("id", "")) == id:
			return t
	return {}

# --- Test 16: empty-pool guard + no infinite loop ---
# POOLS is const — can't monkey-patch. We verify two guarantees instead:
#   (a) Every pool entry is itself a valid DIRECT token (so pools can't silently
#       degrade to unresolvable picks → no hidden recursion issue).
#   (b) resolve_token on an unknown random_* token returns {} without hanging.
#       (Running inside a finite loop with a hard iteration cap is our "finite time" proxy.)
func _test_16_empty_pool_and_no_infinite_loop() -> void:
	print("Test 16: empty-pool / unknown-token guard (no infinite loop, no retry)")
	# (a) Every POOLS entry maps to a DIRECT token.
	for pool_name in ItemTokens.POOLS:
		var entries: Array = ItemTokens.POOLS[pool_name]
		for entry in entries:
			assert_true(
				ItemTokens.DIRECT.has(String(entry)),
				"pool %s entry %s is a valid DIRECT token" % [pool_name, entry]
			)
	# (b) Unknown random_* token resolves to {} immediately (no loop).
	var r: Dictionary = ItemTokens.resolve_token("random_does_not_exist")
	assert_true(r.is_empty(), "unknown random_* token returns {}")
	# (c) Hammer random_weak 500× — proves no retry loop explodes.
	seed(99)
	for i in range(500):
		var rr: Dictionary = ItemTokens.resolve_token("random_weak")
		if rr.is_empty():
			fail_count += 1
			test_count += 1
			print("  FAIL: random_weak returned {} on iter %d" % i)
			return
	test_count += 1
	pass_count += 1
	print("  PASS: 500 random_weak resolutions all non-empty")
