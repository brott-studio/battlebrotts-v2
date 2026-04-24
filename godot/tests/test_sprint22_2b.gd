## Sprint 22.2b — Silver loadout targeted retune tests (pass-1 + pass-2 combined).
## Usage: godot --headless --script tests/test_sprint22_2b.gd
## Spec: memory/2026-04-24-s22.2b-gizmo-retune-spec.md (pass-1);
##       memory/2026-04-24-s22.2b-gizmo-retune-spec-pass2.md §2, §8 (pass-2);
##       memory/2026-04-24-s22.2b-ett-sprint-plan.md §5.
##
## Tests (10 test functions):
##   t1  weight_budget_all_silver    — all 6 retuned Silver templates within chassis cap
##   t2  module_presence_pass2       — per-template module add/remove checks (pass-2 state)
##   t3  armor_changes_pass2         — Enforcer=Reactive, Chrono=None, Harrier=None
##   t4  stances_pass2               — Bulwark=0, Disruptor=2, Aegis=2, Enforcer=2, Chrono=2
##   t5  chrono_weight_and_modules   — Chrono 24kg, 2 modules, Overclock restored
##   t6  harrier_afterburner         — Harrier has Afterburner, 3 modules, 28kg
##   t7  trueshot_unchanged          — Trueshot armor/weapons/modules/stance = pass-1 values
##   t8  bcard_no_orphan_pass2       — no BCard references a module removed in pass-2
##   t9  bcard_pass2_triggers        — BCard data-hygiene for pass-2 templates
##   t10 trueshot_bcard_intact       — Trueshot BCards untouched
##
## #258 guard: assert_eq with concrete counts on every test so a GDScript parse
## error producing 0 assertions is detected by CI as a regression.
extends SceneTree

var pass_count := 0
var fail_count := 0
var test_count := 0

const RETUNED_IDS_PASS2 := [
	"tank_bulwark",
	"bruiser_enforcer",
	"control_disruptor",
	"tank_aegis",
	"glass_chrono",
	"skirmish_harrier",
]

# Modules removed from each template by pass-2 retune
const REMOVED_MODULES_PASS2 := {
	"tank_bulwark":      [],  # no module removal in pass-2
	"bruiser_enforcer":  [],  # no module removal in pass-2
	"control_disruptor": [],  # no module removal in pass-2
	"tank_aegis":        [],  # no module removal in pass-2
	"glass_chrono":      [],  # Overclock RESTORED in pass-2 (was removed in pass-1)
	"skirmish_harrier":  [],  # Reactive Mesh removed (armor field, not a module)
}

func _initialize() -> void:
	print("=== Sprint 22.2b Silver retune tests (pass-2) ===\n")
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

func assert_false(cond: bool, msg: String) -> void:
	assert_true(not cond, msg)

func assert_eq(a, b, msg: String) -> void:
	test_count += 1
	if a == b:
		pass_count += 1
	else:
		fail_count += 1
		print("  FAIL: %s (got %s, expected %s)" % [msg, str(a), str(b)])

# ── Helpers ──────────────────────────────────────────────────────────────────

func _get_template(id: String) -> Dictionary:
	for t in OpponentLoadouts.TEMPLATES:
		if t.get("id", "") == id:
			return t
	return {}

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

func _template_total_weight(t: Dictionary) -> float:
	var total: float = 0.0
	for w in t["weapons"]:
		total += _item_weight(WeaponData.WEAPONS, w)
	total += _item_weight(ArmorData.ARMORS, t["armor"])
	for m in t["modules"]:
		total += _item_weight(ModuleData.MODULES, m)
	return total

# ── Tests ────────────────────────────────────────────────────────────────────

func _run_all() -> void:
	_t1_weight_budget_all_silver()
	_t2_module_presence_pass2()
	_t3_armor_changes_pass2()
	_t4_stances_pass2()
	_t5_chrono_weight_and_modules()
	_t6_harrier_afterburner()
	_t7_trueshot_unchanged()
	_t8_bcard_no_orphan_pass2()
	_t9_bcard_pass2_triggers()
	_t10_trueshot_bcard_intact()

func _t1_weight_budget_all_silver() -> void:
	# All 6 pass-2 retuned templates must be within their chassis weight cap.
	# Expected weights: Bulwark=44, Enforcer=44, Disruptor=41, Aegis=47, Chrono=24, Harrier=28
	print("T1 weight_budget_all_silver")
	var found := 0
	for id in RETUNED_IDS_PASS2:
		var t: Dictionary = _get_template(id)
		assert_false(t.is_empty(), "T1 template found: %s" % id)
		if t.is_empty():
			continue
		found += 1
		var cap: float = _chassis_cap(t["chassis"])
		var total: float = _template_total_weight(t)
		assert_true(total <= cap,
			"T1 weight_budget %s: total=%.0f <= cap=%.0f" % [id, total, cap])
	assert_eq(found, 6, "T1 found all 6 retuned templates in TEMPLATES")
	# Spot-check exact weights per Gizmo pass-2 §2
	var bulwark   := _get_template("tank_bulwark")
	var enforcer  := _get_template("bruiser_enforcer")
	var disruptor := _get_template("control_disruptor")
	var aegis     := _get_template("tank_aegis")
	var chrono    := _get_template("glass_chrono")
	var harrier   := _get_template("skirmish_harrier")
	assert_eq(int(_template_total_weight(bulwark)),   44, "T1 bulwark weight == 44")
	assert_eq(int(_template_total_weight(enforcer)),  44, "T1 enforcer weight == 44")
	assert_eq(int(_template_total_weight(disruptor)), 41, "T1 disruptor weight == 41")
	assert_eq(int(_template_total_weight(aegis)),     47, "T1 aegis weight == 47")
	assert_eq(int(_template_total_weight(chrono)),    24, "T1 chrono weight == 24 (Reactive reverted + Overclock restored)")
	assert_eq(int(_template_total_weight(harrier)),   28, "T1 harrier weight == 28 (Reactive removed + Afterburner added)")

func _t2_module_presence_pass2() -> void:
	# Per pass-2 spec §2 module state for all 6 templates.
	print("T2 module_presence_pass2")

	# tank_bulwark: REPAIR_NANITES + SENSOR_ARRAY; no SHIELD_PROJECTOR (pass-1 removal holds)
	var bulwark := _get_template("tank_bulwark")
	assert_true(bulwark.get("modules", []).has(ModuleData.ModuleType.REPAIR_NANITES),
		"T2 bulwark has REPAIR_NANITES")
	assert_true(bulwark.get("modules", []).has(ModuleData.ModuleType.SENSOR_ARRAY),
		"T2 bulwark has SENSOR_ARRAY")
	assert_false(bulwark.get("modules", []).has(ModuleData.ModuleType.SHIELD_PROJECTOR),
		"T2 bulwark no SHIELD_PROJECTOR")

	# control_disruptor: OVERCLOCK + SENSOR_ARRAY; no SHIELD_PROJECTOR
	var disruptor := _get_template("control_disruptor")
	assert_true(disruptor.get("modules", []).has(ModuleData.ModuleType.OVERCLOCK),
		"T2 disruptor has OVERCLOCK")
	assert_true(disruptor.get("modules", []).has(ModuleData.ModuleType.SENSOR_ARRAY),
		"T2 disruptor has SENSOR_ARRAY")
	assert_false(disruptor.get("modules", []).has(ModuleData.ModuleType.SHIELD_PROJECTOR),
		"T2 disruptor no SHIELD_PROJECTOR")

	# tank_aegis: SHIELD_PROJECTOR + SENSOR_ARRAY; no REPAIR_NANITES
	var aegis := _get_template("tank_aegis")
	assert_true(aegis.get("modules", []).has(ModuleData.ModuleType.SHIELD_PROJECTOR),
		"T2 aegis has SHIELD_PROJECTOR")
	assert_true(aegis.get("modules", []).has(ModuleData.ModuleType.SENSOR_ARRAY),
		"T2 aegis has SENSOR_ARRAY")
	assert_false(aegis.get("modules", []).has(ModuleData.ModuleType.REPAIR_NANITES),
		"T2 aegis no REPAIR_NANITES")

	# bruiser_enforcer: SHIELD_PROJECTOR + OVERCLOCK (unchanged by pass-2)
	var enforcer := _get_template("bruiser_enforcer")
	assert_true(enforcer.get("modules", []).has(ModuleData.ModuleType.SHIELD_PROJECTOR),
		"T2 enforcer has SHIELD_PROJECTOR")
	assert_true(enforcer.get("modules", []).has(ModuleData.ModuleType.OVERCLOCK),
		"T2 enforcer has OVERCLOCK")

	# glass_chrono: SENSOR_ARRAY + OVERCLOCK (Overclock restored in pass-2); exactly 2 modules
	var chrono := _get_template("glass_chrono")
	assert_true(chrono.get("modules", []).has(ModuleData.ModuleType.SENSOR_ARRAY),
		"T2 chrono has SENSOR_ARRAY")
	assert_true(chrono.get("modules", []).has(ModuleData.ModuleType.OVERCLOCK),
		"T2 chrono has OVERCLOCK (restored in pass-2)")
	assert_eq(chrono.get("modules", []).size(), 2, "T2 chrono exactly 2 modules")

	# skirmish_harrier: SENSOR_ARRAY + OVERCLOCK + AFTERBURNER; 3 modules
	var harrier := _get_template("skirmish_harrier")
	assert_true(harrier.get("modules", []).has(ModuleData.ModuleType.SENSOR_ARRAY),
		"T2 harrier has SENSOR_ARRAY")
	assert_true(harrier.get("modules", []).has(ModuleData.ModuleType.OVERCLOCK),
		"T2 harrier has OVERCLOCK")
	assert_true(harrier.get("modules", []).has(ModuleData.ModuleType.AFTERBURNER),
		"T2 harrier has AFTERBURNER (added in pass-2)")
	assert_eq(harrier.get("modules", []).size(), 3, "T2 harrier exactly 3 modules (Scout slot cap)")

func _t3_armor_changes_pass2() -> void:
	# pass-2 armor state:
	#   bruiser_enforcer: REACTIVE_MESH (unchanged from pass-1)
	#   glass_chrono: NONE (reverted from pass-1 Reactive Mesh — reflect-trap fix)
	#   skirmish_harrier: NONE (was Reactive Mesh; reflect-trap prevention per §0.2)
	print("T3 armor_changes_pass2")
	var enforcer := _get_template("bruiser_enforcer")
	assert_eq(enforcer.get("armor", -1), ArmorData.ArmorType.REACTIVE_MESH,
		"T3 enforcer armor == REACTIVE_MESH")
	var chrono := _get_template("glass_chrono")
	assert_eq(chrono.get("armor", -1), ArmorData.ArmorType.NONE,
		"T3 chrono armor == NONE (Reactive reverted in pass-2)")
	var harrier := _get_template("skirmish_harrier")
	assert_eq(harrier.get("armor", -1), ArmorData.ArmorType.NONE,
		"T3 harrier armor == NONE (Reactive removed in pass-2)")

func _t4_stances_pass2() -> void:
	# pass-2 stance values per Gizmo spec §2:
	#   Bulwark:   0 Aggressive (was 1 Defensive)
	#   Disruptor: 2 Kiting     (was 1 Defensive)
	#   Aegis:     2 Kiting     (was 1 Defensive)
	#   Enforcer:  2 Kiting     (was 1 Defensive)
	#   Chrono:    2 Kiting     (was 3 Ambush)
	#   Harrier:   2 Kiting     (unchanged)
	print("T4 stances_pass2")
	var bulwark   := _get_template("tank_bulwark")
	var disruptor := _get_template("control_disruptor")
	var aegis     := _get_template("tank_aegis")
	var enforcer  := _get_template("bruiser_enforcer")
	var chrono    := _get_template("glass_chrono")
	var harrier   := _get_template("skirmish_harrier")
	assert_eq(bulwark.get("stance", -1),   0, "T4 bulwark stance == 0 (Aggressive)")
	assert_eq(disruptor.get("stance", -1), 2, "T4 disruptor stance == 2 (Kiting)")
	assert_eq(aegis.get("stance", -1),     2, "T4 aegis stance == 2 (Kiting)")
	assert_eq(enforcer.get("stance", -1),  2, "T4 enforcer stance == 2 (Kiting)")
	assert_eq(chrono.get("stance", -1),    2, "T4 chrono stance == 2 (Kiting; was Ambush)")
	assert_eq(harrier.get("stance", -1),   2, "T4 harrier stance == 2 (Kiting; unchanged)")

func _t5_chrono_weight_and_modules() -> void:
	# Chrono pass-2: Scout · Railgun(15) · None(0) · Sensor(4)+Overclock(5) = 24kg <= 30kg Scout cap
	print("T5 chrono_weight_and_modules")
	var chrono := _get_template("glass_chrono")
	assert_false(chrono.is_empty(), "T5 chrono template found")
	var cap: float = _chassis_cap(chrono["chassis"])
	var total: float = _template_total_weight(chrono)
	assert_true(total <= cap, "T5 chrono weight %.0f <= Scout cap %.0f" % [total, cap])
	assert_eq(int(total), 24, "T5 chrono exact weight == 24")
	assert_eq(chrono.get("modules", []).size(), 2, "T5 chrono 2 modules")
	assert_true(chrono.get("modules", []).has(ModuleData.ModuleType.OVERCLOCK),
		"T5 chrono has OVERCLOCK (restored in pass-2)")
	assert_eq(chrono.get("armor", -1), ArmorData.ArmorType.NONE,
		"T5 chrono armor == NONE")

func _t6_harrier_afterburner() -> void:
	# Harrier pass-2: Scout · Flak(13) · None(0) · Sensor(4)+Overclock(5)+Afterburner(6) = 28kg <= 30kg
	print("T6 harrier_afterburner")
	var harrier := _get_template("skirmish_harrier")
	assert_false(harrier.is_empty(), "T6 harrier template found")
	var total: float = _template_total_weight(harrier)
	var cap: float = _chassis_cap(harrier["chassis"])
	assert_true(total <= cap, "T6 harrier weight %.0f <= Scout cap %.0f" % [total, cap])
	assert_eq(int(total), 28, "T6 harrier exact weight == 28")
	assert_true(harrier.get("modules", []).has(ModuleData.ModuleType.AFTERBURNER),
		"T6 harrier has AFTERBURNER (added in pass-2)")
	assert_eq(harrier.get("modules", []).size(), 3, "T6 harrier 3 modules (Scout slot cap)")
	assert_eq(harrier.get("armor", -1), ArmorData.ArmorType.NONE,
		"T6 harrier armor == NONE")

func _t7_trueshot_unchanged() -> void:
	# glass_trueshot must be entirely unchanged from S22.1 / pass-1 state.
	# NO-CHANGE per Gizmo pass-2 §2.6: 47% opp-WR is in-band and stable.
	print("T7 trueshot_unchanged")
	var trueshot := _get_template("glass_trueshot")
	assert_false(trueshot.is_empty(), "T7 trueshot template found")
	assert_eq(trueshot.get("armor", -1), ArmorData.ArmorType.NONE,
		"T7 trueshot armor == NONE (unchanged)")
	assert_eq(trueshot.get("stance", -1), 2,
		"T7 trueshot stance == 2 Kiting (unchanged)")
	assert_eq(trueshot.get("chassis", -1), ChassisData.ChassisType.SCOUT,
		"T7 trueshot chassis == SCOUT (unchanged)")
	assert_true(trueshot.get("weapons", []).has(WeaponData.WeaponType.RAILGUN),
		"T7 trueshot has RAILGUN (unchanged)")
	assert_true(trueshot.get("modules", []).has(ModuleData.ModuleType.SENSOR_ARRAY),
		"T7 trueshot has SENSOR_ARRAY (unchanged)")
	assert_true(trueshot.get("modules", []).has(ModuleData.ModuleType.OVERCLOCK),
		"T7 trueshot has OVERCLOCK (unchanged)")
	assert_eq(trueshot.get("modules", []).size(), 2,
		"T7 trueshot exactly 2 modules (unchanged)")
	var total: float = _template_total_weight(trueshot)
	assert_eq(int(total), 24, "T7 trueshot weight == 24 (unchanged)")

func _t8_bcard_no_orphan_pass2() -> void:
	# No BCard on pass-2 retuned templates may reference a module removed in pass-2.
	# (BCards ignored at runtime per #243 but orphan refs are data-corruption smells.)
	print("T8 bcard_no_orphan_pass2")
	var all_ok := true
	var first_fail := ""
	for id in RETUNED_IDS_PASS2:
		var t: Dictionary = _get_template(id)
		if t.is_empty():
			continue
		var removed: Array = REMOVED_MODULES_PASS2.get(id, [])
		for card in t.get("behavior_cards", []):
			var action: Dictionary = card.get("action", {})
			if action.get("kind", "") == "use_gadget":
				var mod_val = action.get("value", -1)
				if removed.has(mod_val):
					all_ok = false
					if first_fail == "":
						first_fail = "%s BCard refs removed module %s" % [id, str(mod_val)]
	assert_true(all_ok,
		"T8 bcard_no_orphan pass-2: no BCard uses a removed module (first fail: %s)" % first_fail)
	assert_eq(RETUNED_IDS_PASS2.size(), 6, "T8 checked 6 retuned templates")

func _t9_bcard_pass2_triggers() -> void:
	# BCard data-hygiene spot checks for pass-2 templates.
	# BCards are cosmetic (ignored at runtime per #243).
	print("T9 bcard_pass2_triggers")

	# Bulwark: should retain enemy_hp_below_pct:50 → pick_target:weakest (pass-1 addition)
	var bulwark := _get_template("tank_bulwark")
	var bulwark_has_card := false
	for card in bulwark.get("behavior_cards", []):
		if (card.get("trigger", {}).get("kind") == "enemy_hp_below_pct"
				and card.get("trigger", {}).get("value") == 50
				and card.get("action", {}).get("kind") == "pick_target"
				and card.get("action", {}).get("value") == "weakest"):
			bulwark_has_card = true
	assert_true(bulwark_has_card,
		"T9 bulwark retains enemy_hp_below_pct:50->pick_target:weakest")

	# Disruptor: should have self_energy_above_pct:70 → use_gadget:OVERCLOCK
	var disruptor := _get_template("control_disruptor")
	var disruptor_has_card := false
	for card in disruptor.get("behavior_cards", []):
		if (card.get("trigger", {}).get("kind") == "self_energy_above_pct"
				and card.get("trigger", {}).get("value") == 70
				and card.get("action", {}).get("kind") == "use_gadget"
				and card.get("action", {}).get("value") == ModuleData.ModuleType.OVERCLOCK):
			disruptor_has_card = true
	assert_true(disruptor_has_card,
		"T9 disruptor has self_energy_above_pct:70->use_gadget:OVERCLOCK")

	# Aegis: should have self_hp_below_pct:60 → use_gadget:SHIELD_PROJECTOR
	var aegis := _get_template("tank_aegis")
	var aegis_has_card := false
	for card in aegis.get("behavior_cards", []):
		if (card.get("trigger", {}).get("kind") == "self_hp_below_pct"
				and card.get("trigger", {}).get("value") == 60
				and card.get("action", {}).get("kind") == "use_gadget"
				and card.get("action", {}).get("value") == ModuleData.ModuleType.SHIELD_PROJECTOR):
			aegis_has_card = true
	assert_true(aegis_has_card,
		"T9 aegis has self_hp_below_pct:60->use_gadget:SHIELD_PROJECTOR")

	# Harrier: should retain self_hp_below_pct:40 → pick_target:farthest (existing card)
	var harrier := _get_template("skirmish_harrier")
	var harrier_has_card := false
	for card in harrier.get("behavior_cards", []):
		if (card.get("trigger", {}).get("kind") == "self_hp_below_pct"
				and card.get("trigger", {}).get("value") == 40
				and card.get("action", {}).get("kind") == "pick_target"
				and card.get("action", {}).get("value") == "farthest"):
			harrier_has_card = true
	assert_true(harrier_has_card,
		"T9 harrier retains self_hp_below_pct:40->pick_target:farthest")

func _t10_trueshot_bcard_intact() -> void:
	# Trueshot BCards must match exactly the 3 pass-1 entries — NO-CHANGE template.
	print("T10 trueshot_bcard_intact")
	var trueshot := _get_template("glass_trueshot")
	assert_false(trueshot.is_empty(), "T10 trueshot found")
	var has_pick      := false  # enemy_beyond_tiles:6 → pick_target:weakest
	var has_overclock := false  # self_energy_above_pct:70 → use_gadget:OVERCLOCK
	var has_stance    := false  # enemy_within_tiles:3 → switch_stance:2
	for card in trueshot.get("behavior_cards", []):
		var trig: Dictionary = card.get("trigger", {})
		var act: Dictionary  = card.get("action", {})
		if (trig.get("kind") == "enemy_beyond_tiles" and trig.get("value") == 6
				and act.get("kind") == "pick_target" and act.get("value") == "weakest"):
			has_pick = true
		if (trig.get("kind") == "self_energy_above_pct" and trig.get("value") == 70
				and act.get("kind") == "use_gadget"
				and act.get("value") == ModuleData.ModuleType.OVERCLOCK):
			has_overclock = true
		if (trig.get("kind") == "enemy_within_tiles" and trig.get("value") == 3
				and act.get("kind") == "switch_stance"):
			has_stance = true
	assert_true(has_pick,     "T10 trueshot has enemy_beyond_tiles:6->pick_target:weakest BCard")
	assert_true(has_overclock,"T10 trueshot has self_energy_above_pct:70->OVERCLOCK BCard")
	assert_true(has_stance,   "T10 trueshot has enemy_within_tiles:3->switch_stance BCard")
	assert_eq(trueshot.get("behavior_cards", []).size(), 3,
		"T10 trueshot has exactly 3 BCards (unchanged)")
