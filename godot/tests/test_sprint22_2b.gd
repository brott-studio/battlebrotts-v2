## Sprint 22.2b — Silver loadout targeted retune tests.
## Usage: godot --headless --script tests/test_sprint22_2b.gd
## Spec: memory/2026-04-24-s22.2b-gizmo-retune-spec.md §3.1–3.5;
##       memory/2026-04-24-s22.2b-ett-sprint-plan.md §5.
##
## Tests (6 test functions, ≥20 assertions total):
##   t1  weight_budget_retuned       — all 5 retuned templates within chassis cap
##   t2  module_presence_retuned     — per-template module add/remove checks
##   t3  armor_changes_retuned       — Enforcer=Reactive Mesh, Chrono=Reactive Mesh
##   t4  stance_change_enforcer      — bruiser_enforcer stance == 1 (Defensive)
##   t5  bcard_no_orphan_retuned     — no BCard action references a removed module
##   t6  bcard_new_triggers_present  — replacement BCard triggers are present
##
## #258 guard: assert_eq with concrete counts on every test so a GDScript parse
## error producing 0 assertions is detected by CI as a regression.
extends SceneTree

var pass_count := 0
var fail_count := 0
var test_count := 0

const RETUNED_IDS := [
	"tank_bulwark",
	"bruiser_enforcer",
	"control_disruptor",
	"tank_aegis",
	"glass_chrono",
]

# Modules removed from each template by this retune (orphan-check list)
const REMOVED_MODULES := {
	"tank_bulwark":      [ModuleData.ModuleType.SHIELD_PROJECTOR],
	"bruiser_enforcer":  [],  # no module removal; Plating→Reactive armor swap only
	"control_disruptor": [ModuleData.ModuleType.SHIELD_PROJECTOR],
	"tank_aegis":        [ModuleData.ModuleType.REPAIR_NANITES],
	"glass_chrono":      [ModuleData.ModuleType.OVERCLOCK],
}

func _initialize() -> void:
	print("=== Sprint 22.2b Silver retune tests ===\n")
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
	_t1_weight_budget_retuned()
	_t2_module_presence_retuned()
	_t3_armor_changes_retuned()
	_t4_stance_change_enforcer()
	_t5_bcard_no_orphan_retuned()
	_t6_bcard_new_triggers_present()

func _t1_weight_budget_retuned() -> void:
	# All 5 retuned templates must remain within their chassis weight cap.
	# Expected: Bulwark=44, Enforcer=44, Disruptor=41, Aegis=47, Chrono=27 (all <= cap)
	print("T1 weight_budget_retuned")
	var found := 0
	for id in RETUNED_IDS:
		var t: Dictionary = _get_template(id)
		assert_false(t.is_empty(), "T1 template found: %s" % id)
		if t.is_empty():
			continue
		found += 1
		var cap: float = _chassis_cap(t["chassis"])
		var total: float = _template_total_weight(t)
		assert_true(total <= cap,
			"T1 weight_budget %s: total=%.0f <= cap=%.0f" % [id, total, cap])
	# Guard: ensure all 5 were found (parse-error / ID-typo detection)
	assert_eq(found, 5, "T1 found all 5 retuned templates in TEMPLATES")
	# Spot-check expected sums (concrete values per Gizmo §3.1–3.5)
	var bulwark := _get_template("tank_bulwark")
	var enforcer := _get_template("bruiser_enforcer")
	var disruptor := _get_template("control_disruptor")
	var aegis := _get_template("tank_aegis")
	var chrono := _get_template("glass_chrono")
	assert_eq(int(_template_total_weight(bulwark)),   44, "T1 bulwark weight == 44")
	assert_eq(int(_template_total_weight(enforcer)),  44, "T1 enforcer weight == 44")
	assert_eq(int(_template_total_weight(disruptor)), 41, "T1 disruptor weight == 41")
	assert_eq(int(_template_total_weight(aegis)),     47, "T1 aegis weight == 47")
	assert_eq(int(_template_total_weight(chrono)),    27, "T1 chrono weight == 27")

func _t2_module_presence_retuned() -> void:
	# Per-template module add/remove assertions per Gizmo §3.1–3.5
	print("T2 module_presence_retuned")

	# tank_bulwark: must have SENSOR_ARRAY; must NOT have SHIELD_PROJECTOR
	var bulwark := _get_template("tank_bulwark")
	assert_true(bulwark.get("modules", []).has(ModuleData.ModuleType.SENSOR_ARRAY),
		"T2 bulwark has SENSOR_ARRAY")
	assert_true(bulwark.get("modules", []).has(ModuleData.ModuleType.REPAIR_NANITES),
		"T2 bulwark has REPAIR_NANITES")
	assert_false(bulwark.get("modules", []).has(ModuleData.ModuleType.SHIELD_PROJECTOR),
		"T2 bulwark no SHIELD_PROJECTOR")

	# control_disruptor: must have OVERCLOCK; must NOT have SHIELD_PROJECTOR
	var disruptor := _get_template("control_disruptor")
	assert_true(disruptor.get("modules", []).has(ModuleData.ModuleType.OVERCLOCK),
		"T2 disruptor has OVERCLOCK")
	assert_true(disruptor.get("modules", []).has(ModuleData.ModuleType.SENSOR_ARRAY),
		"T2 disruptor has SENSOR_ARRAY")
	assert_false(disruptor.get("modules", []).has(ModuleData.ModuleType.SHIELD_PROJECTOR),
		"T2 disruptor no SHIELD_PROJECTOR")

	# tank_aegis: must have SHIELD_PROJECTOR + SENSOR_ARRAY; must NOT have REPAIR_NANITES
	var aegis := _get_template("tank_aegis")
	assert_true(aegis.get("modules", []).has(ModuleData.ModuleType.SHIELD_PROJECTOR),
		"T2 aegis has SHIELD_PROJECTOR")
	assert_true(aegis.get("modules", []).has(ModuleData.ModuleType.SENSOR_ARRAY),
		"T2 aegis has SENSOR_ARRAY")
	assert_false(aegis.get("modules", []).has(ModuleData.ModuleType.REPAIR_NANITES),
		"T2 aegis no REPAIR_NANITES")

	# bruiser_enforcer: must have SHIELD_PROJECTOR + OVERCLOCK (modules unchanged by retune)
	var enforcer := _get_template("bruiser_enforcer")
	assert_true(enforcer.get("modules", []).has(ModuleData.ModuleType.SHIELD_PROJECTOR),
		"T2 enforcer has SHIELD_PROJECTOR")
	assert_true(enforcer.get("modules", []).has(ModuleData.ModuleType.OVERCLOCK),
		"T2 enforcer has OVERCLOCK")

	# glass_chrono: must have SENSOR_ARRAY; must NOT have OVERCLOCK (dropped for weight)
	var chrono := _get_template("glass_chrono")
	assert_true(chrono.get("modules", []).has(ModuleData.ModuleType.SENSOR_ARRAY),
		"T2 chrono has SENSOR_ARRAY")
	assert_false(chrono.get("modules", []).has(ModuleData.ModuleType.OVERCLOCK),
		"T2 chrono no OVERCLOCK")
	# Chrono one-module: exactly 1 module in slot (loadout-legal per Gizmo §3.5)
	assert_eq(chrono.get("modules", []).size(), 1, "T2 chrono exactly 1 module")

func _t3_armor_changes_retuned() -> void:
	# bruiser_enforcer: Plating → Reactive Mesh
	# glass_chrono: None → Reactive Mesh
	print("T3 armor_changes_retuned")
	var enforcer := _get_template("bruiser_enforcer")
	assert_eq(enforcer.get("armor", -1), ArmorData.ArmorType.REACTIVE_MESH,
		"T3 enforcer armor == REACTIVE_MESH")
	var chrono := _get_template("glass_chrono")
	assert_eq(chrono.get("armor", -1), ArmorData.ArmorType.REACTIVE_MESH,
		"T3 chrono armor == REACTIVE_MESH (not NONE)")

func _t4_stance_change_enforcer() -> void:
	# bruiser_enforcer: Aggressive (0) → Defensive (1)
	print("T4 stance_change_enforcer")
	var enforcer := _get_template("bruiser_enforcer")
	assert_eq(enforcer.get("stance", -1), 1,
		"T4 enforcer stance == 1 (Defensive)")

func _t5_bcard_no_orphan_retuned() -> void:
	# No BCard on the 5 retuned templates may reference a module that was removed
	# from that template's modules array. Engine ignores BCards today (#243) but
	# orphan references are data-corruption smells that would break when #243 wires.
	print("T5 bcard_no_orphan_retuned")
	var all_ok := true
	var first_fail := ""
	for id in RETUNED_IDS:
		var t: Dictionary = _get_template(id)
		if t.is_empty():
			continue
		var removed: Array = REMOVED_MODULES.get(id, [])
		for card in t.get("behavior_cards", []):
			var action: Dictionary = card.get("action", {})
			if action.get("kind", "") == "use_gadget":
				var mod_val = action.get("value", -1)
				if removed.has(mod_val):
					all_ok = false
					if first_fail == "":
						first_fail = "%s BCard references removed module %s" % [id, str(mod_val)]
	assert_true(all_ok, "T5 bcard_no_orphan — no BCard uses a removed module (fail: %s)" % first_fail)
	# Count assertion guard: 5 templates checked (parse-error detection)
	assert_eq(RETUNED_IDS.size(), 5, "T5 checked 5 retuned templates")

func _t6_bcard_new_triggers_present() -> void:
	# Verify the replacement BCards specified by Gizmo §3.1–3.5 are actually present.
	print("T6 bcard_new_triggers_present")

	# Bulwark: must have enemy_hp_below_pct:50 → pick_target:weakest
	var bulwark := _get_template("tank_bulwark")
	var bulwark_has_new_bcard := false
	for card in bulwark.get("behavior_cards", []):
		if (card.get("trigger", {}).get("kind") == "enemy_hp_below_pct"
				and card.get("trigger", {}).get("value") == 50
				and card.get("action", {}).get("kind") == "pick_target"
				and card.get("action", {}).get("value") == "weakest"):
			bulwark_has_new_bcard = true
	assert_true(bulwark_has_new_bcard,
		"T6 bulwark has enemy_hp_below_pct:50->pick_target:weakest BCard")

	# Disruptor: must have self_energy_above_pct:70 → use_gadget:OVERCLOCK
	var disruptor := _get_template("control_disruptor")
	var disruptor_has_new_bcard := false
	for card in disruptor.get("behavior_cards", []):
		if (card.get("trigger", {}).get("kind") == "self_energy_above_pct"
				and card.get("trigger", {}).get("value") == 70
				and card.get("action", {}).get("kind") == "use_gadget"
				and card.get("action", {}).get("value") == ModuleData.ModuleType.OVERCLOCK):
			disruptor_has_new_bcard = true
	assert_true(disruptor_has_new_bcard,
		"T6 disruptor has self_energy_above_pct:70->use_gadget:OVERCLOCK BCard")

	# Aegis: must have enemy_beyond_tiles:6 → pick_target:weakest
	var aegis := _get_template("tank_aegis")
	var aegis_has_new_bcard := false
	for card in aegis.get("behavior_cards", []):
		if (card.get("trigger", {}).get("kind") == "enemy_beyond_tiles"
				and card.get("trigger", {}).get("value") == 6
				and card.get("action", {}).get("kind") == "pick_target"
				and card.get("action", {}).get("value") == "weakest"):
			aegis_has_new_bcard = true
	assert_true(aegis_has_new_bcard,
		"T6 aegis has enemy_beyond_tiles:6->pick_target:weakest BCard")

	# Chrono: must have enemy_within_tiles:4 → switch_stance:2
	var chrono := _get_template("glass_chrono")
	var chrono_has_new_bcard := false
	for card in chrono.get("behavior_cards", []):
		if (card.get("trigger", {}).get("kind") == "enemy_within_tiles"
				and card.get("trigger", {}).get("value") == 4
				and card.get("action", {}).get("kind") == "switch_stance"
				and card.get("action", {}).get("value") == 2):
			chrono_has_new_bcard = true
	assert_true(chrono_has_new_bcard,
		"T6 chrono has enemy_within_tiles:4->switch_stance:2 BCard")
