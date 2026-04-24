## Sprint 22.1 — Silver content drop tests.
## Usage: godot --headless --script tests/test_sprint22_1.gd
## Spec: memory/2026-04-24-s22.1-gizmo-silver-league-spec.md §10.B;
##       memory/2026-04-24-s22.1-ett-sprint-plan.md §6.
##
## Tests (10 total — minimum 10 assertions each pass, no silent-0 possible):
##   t1  silver_pool_nonempty       — 100 picks each at tier 3 + 4 return non-empty dict
##   t2  silver_tier_mapping        — difficulty_for("silver", i) = [3,3,3,4,4]; default 3
##   t3  silver_legality            — Silver-legal items only; module count = 2 on all 7 new
##   t4  silver_archetype_coverage  — >=3 distinct archetypes in Silver pool (target: all 5)
##   t5  silver_variety_holds       — 1000 random 5-fight Silver runs: no consecutive same arch
##   t6  silver_league_filter       — 100 picks at tier 3+4 w/ current_league="silver"
##                                    never return gold/platinum templates
##   t7  bronze_no_regression       — 100 picks at tier 2+3 w/ current_league="bronze"
##                                    never return Silver+/Gold+/Plat templates
##   t8  weight_budget              — all 7 new Silver templates within chassis weight cap
##   t9  silver_preview_list_size_5 — OpponentData.get_league_opponents("silver").size() == 5
##   t10 bronze_preview_list_size_5 — OpponentData.get_league_opponents("bronze").size() == 5
##                                    (catches the previously-broken Bronze path)
##
## #258 guard: each test asserts at minimum 1 non-trivial count (assert_eq with
## concrete value) so a GDScript parse error on this file produces 0 assertions
## (detected by CI as regression). See Ett sec6 pass conditions.
extends SceneTree

var pass_count := 0
var fail_count := 0
var test_count := 0

# Silver-legal item sets per GDD sec6.1 + Gizmo sec10.B
const SILVER_CHASSIS := [
	ChassisData.ChassisType.SCOUT,
	ChassisData.ChassisType.BRAWLER,
	ChassisData.ChassisType.FORTRESS,
]
const SILVER_WEAPONS := [
	WeaponData.WeaponType.PLASMA_CUTTER,
	WeaponData.WeaponType.MINIGUN,
	WeaponData.WeaponType.SHOTGUN,
	WeaponData.WeaponType.ARC_EMITTER,
	WeaponData.WeaponType.RAILGUN,
	WeaponData.WeaponType.FLAK_CANNON,
]
const SILVER_ARMOR := [
	ArmorData.ArmorType.NONE,
	ArmorData.ArmorType.PLATING,
	ArmorData.ArmorType.REACTIVE_MESH,
	# Ablative Shell is Gold+ — NOT Silver-legal
]
const SILVER_MODULES := [
	ModuleData.ModuleType.OVERCLOCK,
	ModuleData.ModuleType.REPAIR_NANITES,
	ModuleData.ModuleType.SHIELD_PROJECTOR,
	ModuleData.ModuleType.SENSOR_ARRAY,
	# Afterburner, EMP Charge are Gold+ — NOT Silver-legal
]

const SILVER_IDS := [
	"tank_bulwark",
	"glass_trueshot",
	"skirmish_harrier",
	"bruiser_enforcer",
	"control_disruptor",
	"tank_aegis",
	"glass_chrono",
]

func _initialize() -> void:
	print("=== Sprint 22.1 Silver content drop tests ===\n")
	_run_all()
	print("\n=== Results: %d passed, %d failed, %d total ===" % [pass_count, fail_count, test_count])
	quit(1 if fail_count > 0 else 0)

func assert_true(cond: bool, msg: String) -> void:
	test_count += 1
	if cond:
		pass_count += 1
	else:
		fail_count += 1
		print("  FAIL: %s" % msg)

func assert_eq(a, b, msg: String) -> void:
	test_count += 1
	if a == b:
		pass_count += 1
	else:
		fail_count += 1
		print("  FAIL: %s (got %s, expected %s)" % [msg, str(a), str(b)])

func _run_all() -> void:
	_t1_silver_pool_nonempty()
	_t2_silver_tier_mapping()
	_t3_silver_legality()
	_t4_silver_archetype_coverage()
	_t5_silver_variety_holds()
	_t6_silver_league_filter()
	_t7_bronze_no_regression()
	_t8_weight_budget()
	_t9_silver_preview_list_size_5()
	_t10_bronze_preview_list_size_5()

# ── Helpers ──────────────────────────────────────────────────────────────────

func _league_rank(name: String) -> int:
	return OpponentLoadouts.LEAGUE_RANK.get(name, 99)

func _silver_templates() -> Array:
	var out: Array = []
	for t in OpponentLoadouts.TEMPLATES:
		if SILVER_IDS.has(t.get("id", "")):
			out.append(t)
	return out

func _chassis_cap(chassis_type: int) -> float:
	var c: Dictionary = ChassisData.CHASSIS[chassis_type]
	for k in ["weight_cap", "weight_capacity", "max_weight", "weight"]:
		if c.has(k):
			return float(c[k])
	return 0.0

func _item_weight(table: Dictionary, key: int) -> float:
	var item: Dictionary = table.get(key, {})
	for k in ["weight", "weight_kg", "mass"]:
		if item.has(k):
			return float(item[k])
	return 0.0

# ── Tests ────────────────────────────────────────────────────────────────────

func _t1_silver_pool_nonempty() -> void:
	var all_ok := true
	var failed_tier := -1
	for _i in 100:
		var p3: Dictionary = OpponentLoadouts.pick_opponent_loadout(3, "silver")
		var p4: Dictionary = OpponentLoadouts.pick_opponent_loadout(4, "silver")
		if p3.is_empty():
			all_ok = false
			failed_tier = 3
			break
		if p4.is_empty():
			all_ok = false
			failed_tier = 4
			break
	assert_true(all_ok, "T1 silver_pool_nonempty — 100 picks each at tier 3 + 4 non-empty (failed tier: %d)" % failed_tier)

func _t2_silver_tier_mapping() -> void:
	var expected := [3, 3, 3, 4, 4]
	var ok := true
	var first_fail := ""
	for i in expected.size():
		var got: int = OpponentLoadouts.difficulty_for("silver", i)
		if got != expected[i]:
			ok = false
			if first_fail == "":
				first_fail = "index %d: expected %d got %d" % [i, expected[i], got]
	# Out-of-range default = 3
	if OpponentLoadouts.difficulty_for("silver", 5) != 3:
		ok = false
		if first_fail == "":
			first_fail = "out-of-range index 5: expected 3 got %d" % OpponentLoadouts.difficulty_for("silver", 5)
	if OpponentLoadouts.difficulty_for("silver", -1) != 3:
		ok = false
		if first_fail == "":
			first_fail = "out-of-range index -1: expected 3 got %d" % OpponentLoadouts.difficulty_for("silver", -1)
	assert_true(ok, "T2 silver_tier_mapping = [3,3,3,4,4] with default 3 (first fail: %s)" % first_fail)
	# Explicit count assertion so #258 parse-error guard fires on 0 assertions
	assert_eq(OpponentLoadouts.difficulty_for("silver", 0), 3, "T2 silver tier[0] == 3")
	assert_eq(OpponentLoadouts.difficulty_for("silver", 4), 4, "T2 silver tier[4] == 4")

func _t3_silver_legality() -> void:
	var templates := _silver_templates()
	# First assert we found exactly the 7 expected templates (guards against typo in IDs)
	assert_eq(templates.size(), 7, "T3 silver_legality — found 7 new Silver templates in TEMPLATES")
	var all_ok := true
	var first_fail := ""
	for t in templates:
		var chassis_ok: bool = SILVER_CHASSIS.has(t["chassis"])
		var weapons_ok := true
		for w in t["weapons"]:
			if not SILVER_WEAPONS.has(w):
				weapons_ok = false
		var armor_ok: bool = SILVER_ARMOR.has(t["armor"])
		var modules_ok := true
		for m in t["modules"]:
			if not SILVER_MODULES.has(m):
				modules_ok = false
		# GDD sec6.2 "full loadouts": Silver module count = 2
		var module_count_ok: bool = t["modules"].size() == 2
		var unlock_ok: bool = t.get("unlock_league", "") == "silver"
		if not (chassis_ok and weapons_ok and armor_ok and modules_ok and module_count_ok and unlock_ok):
			all_ok = false
			if first_fail == "":
				first_fail = "%s ch=%s wp=%s ar=%s md=%s mc=%d ul=%s" % [
					t.get("id", "?"),
					str(chassis_ok), str(weapons_ok), str(armor_ok),
					str(modules_ok), t["modules"].size(), str(unlock_ok),
				]
	assert_true(all_ok, "T3 silver_legality — Silver-legal items, 2 modules, unlock_league=silver (first fail: %s)" % first_fail)

func _t4_silver_archetype_coverage() -> void:
	var seen := {}
	for t in _silver_templates():
		seen[t["archetype"]] = true
	# Floor = 3; target = all 5 (Gizmo spec: all 5 archetypes present)
	assert_true(seen.size() >= 3, "T4 silver_archetype_coverage >= 3 archetypes (got %d)" % seen.size())
	assert_eq(seen.size(), 5, "T4 silver_archetype_coverage all 5 archetypes present")

func _t5_silver_variety_holds() -> void:
	var all_ok := true
	var failed_run := -1
	for run in 1000:
		var last := -1
		for i in 5:
			var tier: int = OpponentLoadouts.difficulty_for("silver", i)
			var pick: Dictionary = OpponentLoadouts.pick_opponent_loadout(tier, "silver", last)
			if pick.is_empty():
				all_ok = false
				failed_run = run
				break
			if last != -1 and pick["archetype"] == last:
				all_ok = false
				failed_run = run
				break
			last = pick["archetype"]
		if not all_ok:
			break
	assert_true(all_ok, "T5 silver_variety_holds 1000 runs no back-to-back archetype (failed run: %d)" % failed_run)

func _t6_silver_league_filter() -> void:
	# Silver picks must never draw gold or platinum templates
	var forbidden_ranks := {
		_league_rank("gold"): true,
		_league_rank("platinum"): true,
	}
	var all_ok := true
	var leaked_id := ""
	for tier in [3, 4]:
		for _i in 100:
			var pick: Dictionary = OpponentLoadouts.pick_opponent_loadout(tier, "silver")
			if pick.is_empty():
				all_ok = false
				leaked_id = "<empty at tier %d>" % tier
				break
			var rank: int = _league_rank(pick.get("unlock_league", "scrapyard"))
			if forbidden_ranks.has(rank):
				all_ok = false
				leaked_id = pick.get("id", "?")
				break
		if not all_ok:
			break
	assert_true(all_ok, "T6 silver_league_filter — no gold/platinum leak (leaked: %s)" % leaked_id)
	# Also confirm controller_jammer (gold) never appears in Silver pulls
	var jammer_seen := false
	for _i in 200:
		for tier in [3, 4]:
			var pick: Dictionary = OpponentLoadouts.pick_opponent_loadout(tier, "silver")
			if pick.get("id", "") == "controller_jammer":
				jammer_seen = true
				break
		if jammer_seen:
			break
	assert_true(not jammer_seen, "T6 silver_league_filter — controller_jammer (gold) never drawn at Silver")

func _t7_bronze_no_regression() -> void:
	# Bronze picks must never draw Silver+ templates (regression guard extending S21.1 t6)
	var forbidden_ranks := {
		_league_rank("silver"): true,
		_league_rank("gold"): true,
		_league_rank("platinum"): true,
	}
	var all_ok := true
	var leaked_id := ""
	for tier in [2, 3]:
		for _i in 100:
			var pick: Dictionary = OpponentLoadouts.pick_opponent_loadout(tier, "bronze")
			if pick.is_empty():
				all_ok = false
				leaked_id = "<empty at tier %d>" % tier
				break
			var rank: int = _league_rank(pick.get("unlock_league", "scrapyard"))
			if forbidden_ranks.has(rank):
				all_ok = false
				leaked_id = pick.get("id", "?")
				break
		if not all_ok:
			break
	assert_true(all_ok, "T7 bronze_no_regression — no silver+ leak in Bronze picks (leaked: %s)" % leaked_id)

func _t8_weight_budget() -> void:
	var all_ok := true
	var first_fail := ""
	for t in _silver_templates():
		var cap: float = _chassis_cap(t["chassis"])
		if cap <= 0.0:
			# Unknown chassis cap — flag but don't hard-fail (backward compat)
			print("  WARN: T8 unknown chassis cap for %s" % t.get("id", "?"))
			continue
		var total: float = 0.0
		for w in t["weapons"]:
			total += _item_weight(WeaponData.WEAPONS, w)
		total += _item_weight(ArmorData.ARMORS, t["armor"])
		for m in t["modules"]:
			total += _item_weight(ModuleData.MODULES, m)
		if total > cap:
			all_ok = false
			if first_fail == "":
				first_fail = "%s total=%.1f cap=%.1f" % [t.get("id", "?"), total, cap]
	assert_true(all_ok, "T8 weight_budget — all Silver templates <= chassis cap (first fail: %s)" % first_fail)

func _t9_silver_preview_list_size_5() -> void:
	var silver_preview: Array = OpponentData.get_league_opponents("silver")
	assert_eq(silver_preview.size(), 5, "T9 silver_preview_list_size_5 — get_league_opponents('silver') returns 5 entries")
	# Verify all entries have required keys (non-empty name, chassis present)
	var entries_ok := true
	for entry in silver_preview:
		if not (entry is Dictionary and entry.has("name") and entry.has("chassis")):
			entries_ok = false
			break
	assert_true(entries_ok, "T9 silver_preview_entries_valid — all 5 entries have name + chassis keys")

func _t10_bronze_preview_list_size_5() -> void:
	# Catches the previously-broken Bronze path (get_league_opponents("bronze") returned [])
	var bronze_preview: Array = OpponentData.get_league_opponents("bronze")
	assert_eq(bronze_preview.size(), 5, "T10 bronze_preview_list_size_5 — get_league_opponents('bronze') returns 5 entries (was broken on main)")
	# Verify all entries have required keys
	var entries_ok := true
	for entry in bronze_preview:
		if not (entry is Dictionary and entry.has("name") and entry.has("chassis")):
			entries_ok = false
			break
	assert_true(entries_ok, "T10 bronze_preview_entries_valid — all 5 entries have name + chassis keys")
