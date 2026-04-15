## Sprint 2 test suite — BrottBrain, Economy, Loadout, Progression, Overclock
## Usage: godot --headless --script tests/test_sprint2.gd
extends SceneTree

var pass_count := 0
var fail_count := 0
var test_count := 0

func _init() -> void:
	print("=== BattleBrotts Sprint 2 Test Suite ===\n")
	
	_test_brottbrain_triggers()
	_test_brottbrain_actions()
	_test_brottbrain_card_priority()
	_test_brottbrain_max_cards()
	_test_brottbrain_defaults()
	_test_brottbrain_integration()
	_test_economy_init()
	_test_economy_earn()
	_test_economy_buy()
	_test_economy_repair()
	_test_economy_first_win()
	_test_shop_prices()
	_test_loadout_validation()
	_test_loadout_weight()
	_test_loadout_slots()
	_test_loadout_ownership()
	_test_progression_scrapyard()
	_test_progression_bronze_unlock()
	_test_opponent_data()
	_test_opponent_build()
	_test_overclock_cooldown()
	_test_overclock_recovery_clears()
	_test_weapon_modes()
	_test_target_priority()
	_test_movement_override()
	_test_game_flow()
	
	print("\n=== Results: %d passed, %d failed, %d total ===" % [pass_count, fail_count, test_count])
	
	if fail_count > 0:
		quit(1)
	else:
		quit(0)

func assert_eq(a: Variant, b: Variant, msg: String) -> void:
	test_count += 1
	if a == b:
		pass_count += 1
	else:
		fail_count += 1
		print("  FAIL: %s (got %s, expected %s)" % [msg, str(a), str(b)])

func assert_near(a: float, b: float, tol: float, msg: String) -> void:
	test_count += 1
	if absf(a - b) <= tol:
		pass_count += 1
	else:
		fail_count += 1
		print("  FAIL: %s (got %f, expected %f ± %f)" % [msg, a, b, tol])

func assert_true(val: bool, msg: String) -> void:
	test_count += 1
	if val:
		pass_count += 1
	else:
		fail_count += 1
		print("  FAIL: %s (expected true)" % msg)

func assert_false(val: bool, msg: String) -> void:
	assert_true(not val, msg)

## ===== HELPERS =====

func _make_brott(team: int, chassis: ChassisData.ChassisType) -> BrottState:
	var b := BrottState.new()
	b.team = team
	b.chassis_type = chassis
	b.weapon_types = [WeaponData.WeaponType.PLASMA_CUTTER]
	b.armor_type = ArmorData.ArmorType.NONE
	b.module_types = []
	b.position = Vector2(128, 128)
	b.setup()
	return b

## ===== BROTTBRAIN TRIGGER TESTS =====

func _test_brottbrain_triggers() -> void:
	print("--- BrottBrain Triggers ---")
	
	var brain := BrottBrain.new()
	var b := _make_brott(0, ChassisData.ChassisType.SCOUT)
	var enemy := _make_brott(1, ChassisData.ChassisType.BRAWLER)
	enemy.position = Vector2(256, 128)
	
	# WHEN_IM_HURT — below 40% HP
	b.hp = 30.0  # 30/100 = 30% < 40%
	var card := BrottBrain.BehaviorCard.new(BrottBrain.Trigger.WHEN_IM_HURT, 0.4, BrottBrain.Action.SWITCH_STANCE, 1)
	brain.add_card(card)
	var fired := brain.evaluate(b, enemy, 0.0)
	assert_true(fired, "WHEN_IM_HURT fires at 30% HP (threshold 40%)")
	
	brain.clear_cards()
	b.hp = 60.0  # 60% > 40%
	brain.add_card(BrottBrain.BehaviorCard.new(BrottBrain.Trigger.WHEN_IM_HURT, 0.4, BrottBrain.Action.SWITCH_STANCE, 1))
	fired = brain.evaluate(b, enemy, 0.0)
	assert_false(fired, "WHEN_IM_HURT doesn't fire at 60% HP (threshold 40%)")
	
	# WHEN_IM_HEALTHY — above 70%
	brain.clear_cards()
	b.hp = 80.0
	brain.add_card(BrottBrain.BehaviorCard.new(BrottBrain.Trigger.WHEN_IM_HEALTHY, 0.7, BrottBrain.Action.SWITCH_STANCE, 0))
	fired = brain.evaluate(b, enemy, 0.0)
	assert_true(fired, "WHEN_IM_HEALTHY fires at 80% HP (threshold 70%)")
	
	# WHEN_LOW_ENERGY
	brain.clear_cards()
	b.energy = 15.0
	brain.add_card(BrottBrain.BehaviorCard.new(BrottBrain.Trigger.WHEN_LOW_ENERGY, 0.2, BrottBrain.Action.WEAPONS, "conserve"))
	fired = brain.evaluate(b, enemy, 0.0)
	assert_true(fired, "WHEN_LOW_ENERGY fires at 15% energy (threshold 20%)")
	
	# WHEN_CHARGED_UP
	brain.clear_cards()
	b.energy = 90.0
	brain.add_card(BrottBrain.BehaviorCard.new(BrottBrain.Trigger.WHEN_CHARGED_UP, 0.8, BrottBrain.Action.WEAPONS, "all_fire"))
	fired = brain.evaluate(b, enemy, 0.0)
	assert_true(fired, "WHEN_CHARGED_UP fires at 90% energy (threshold 80%)")
	
	# WHEN_THEYRE_HURT
	brain.clear_cards()
	enemy.hp = 30.0  # 30/150 = 20% < 30%
	brain.add_card(BrottBrain.BehaviorCard.new(BrottBrain.Trigger.WHEN_THEYRE_HURT, 0.3, BrottBrain.Action.SWITCH_STANCE, 0))
	fired = brain.evaluate(b, enemy, 0.0)
	assert_true(fired, "WHEN_THEYRE_HURT fires when enemy at 20% HP")
	
	# WHEN_THEYRE_CLOSE — within 3 tiles
	brain.clear_cards()
	enemy.hp = 150.0
	enemy.position = Vector2(192, 128)  # ~2 tiles away
	brain.add_card(BrottBrain.BehaviorCard.new(BrottBrain.Trigger.WHEN_THEYRE_CLOSE, 3, BrottBrain.Action.SWITCH_STANCE, 2))
	fired = brain.evaluate(b, enemy, 0.0)
	assert_true(fired, "WHEN_THEYRE_CLOSE fires at 2 tiles (threshold 3)")
	
	# WHEN_THEYRE_FAR — beyond 8 tiles
	brain.clear_cards()
	enemy.position = Vector2(512, 128)  # ~12 tiles
	brain.add_card(BrottBrain.BehaviorCard.new(BrottBrain.Trigger.WHEN_THEYRE_FAR, 8, BrottBrain.Action.HOLD_CENTER, null))
	fired = brain.evaluate(b, enemy, 0.0)
	assert_true(fired, "WHEN_THEYRE_FAR fires at 12 tiles (threshold 8)")
	
	# WHEN_CLOCK_SAYS — match time > 60s
	brain.clear_cards()
	brain.add_card(BrottBrain.BehaviorCard.new(BrottBrain.Trigger.WHEN_CLOCK_SAYS, 60, BrottBrain.Action.SWITCH_STANCE, 0))
	fired = brain.evaluate(b, enemy, 65.0)
	assert_true(fired, "WHEN_CLOCK_SAYS fires at 65s (threshold 60s)")
	
	brain.clear_cards()
	brain.add_card(BrottBrain.BehaviorCard.new(BrottBrain.Trigger.WHEN_CLOCK_SAYS, 60, BrottBrain.Action.SWITCH_STANCE, 0))
	fired = brain.evaluate(b, enemy, 30.0)
	assert_false(fired, "WHEN_CLOCK_SAYS doesn't fire at 30s (threshold 60s)")
	
	# WHEN_GADGET_READY
	brain.clear_cards()
	b.module_types = [ModuleData.ModuleType.OVERCLOCK]
	b.module_cooldowns = [0.0]
	b.module_active_timers = [0.0]
	brain.add_card(BrottBrain.BehaviorCard.new(BrottBrain.Trigger.WHEN_GADGET_READY, "Overclock", BrottBrain.Action.USE_GADGET, "Overclock"))
	fired = brain.evaluate(b, enemy, 0.0)
	assert_true(fired, "WHEN_GADGET_READY fires when Overclock is off cooldown")
	
	# Gadget on cooldown
	brain.clear_cards()
	b.module_cooldowns = [20.0]
	brain.add_card(BrottBrain.BehaviorCard.new(BrottBrain.Trigger.WHEN_GADGET_READY, "Overclock", BrottBrain.Action.USE_GADGET, "Overclock"))
	fired = brain.evaluate(b, enemy, 0.0)
	assert_false(fired, "WHEN_GADGET_READY doesn't fire when Overclock on cooldown")

## ===== BROTTBRAIN ACTION TESTS =====

func _test_brottbrain_actions() -> void:
	print("--- BrottBrain Actions ---")
	
	var brain := BrottBrain.new()
	var b := _make_brott(0, ChassisData.ChassisType.SCOUT)
	var enemy := _make_brott(1, ChassisData.ChassisType.BRAWLER)
	enemy.position = Vector2(256, 128)
	
	# SWITCH_STANCE
	b.stance = 0
	b.hp = 20.0
	brain.add_card(BrottBrain.BehaviorCard.new(BrottBrain.Trigger.WHEN_IM_HURT, 0.4, BrottBrain.Action.SWITCH_STANCE, 1))
	brain.evaluate(b, enemy, 0.0)
	assert_eq(b.stance, 1, "SWITCH_STANCE changes stance to Defensive")
	
	# USE_GADGET — sets pending gadget
	brain.clear_cards()
	b.hp = 20.0
	b.module_types = [ModuleData.ModuleType.SHIELD_PROJECTOR]
	b.module_cooldowns = [0.0]
	b.module_active_timers = [0.0]
	brain.add_card(BrottBrain.BehaviorCard.new(BrottBrain.Trigger.WHEN_IM_HURT, 0.4, BrottBrain.Action.USE_GADGET, "Shield Projector"))
	brain.evaluate(b, enemy, 0.0)
	assert_eq(b._pending_gadget, "Shield Projector", "USE_GADGET sets pending gadget")
	
	# PICK_TARGET
	brain.clear_cards()
	brain.add_card(BrottBrain.BehaviorCard.new(BrottBrain.Trigger.WHEN_IM_HURT, 0.4, BrottBrain.Action.PICK_TARGET, "weakest"))
	brain.evaluate(b, enemy, 0.0)
	assert_eq(brain.target_priority, "weakest", "PICK_TARGET sets target priority")
	
	# WEAPONS mode
	brain.clear_cards()
	brain.add_card(BrottBrain.BehaviorCard.new(BrottBrain.Trigger.WHEN_IM_HURT, 0.4, BrottBrain.Action.WEAPONS, "hold_fire"))
	brain.evaluate(b, enemy, 0.0)
	assert_eq(brain.weapon_mode, "hold_fire", "WEAPONS sets weapon mode")
	
	# HOLD_CENTER
	brain.clear_cards()
	brain.add_card(BrottBrain.BehaviorCard.new(BrottBrain.Trigger.WHEN_IM_HURT, 0.4, BrottBrain.Action.HOLD_CENTER, null))
	brain.evaluate(b, enemy, 0.0)
	assert_eq(brain.movement_override, "center", "HOLD_CENTER sets movement override")
	
	# GET_TO_COVER
	brain.clear_cards()
	brain.add_card(BrottBrain.BehaviorCard.new(BrottBrain.Trigger.WHEN_IM_HURT, 0.4, BrottBrain.Action.GET_TO_COVER, null))
	brain.evaluate(b, enemy, 0.0)
	assert_eq(brain.movement_override, "cover", "GET_TO_COVER sets movement override")

## ===== CARD PRIORITY =====

func _test_brottbrain_card_priority() -> void:
	print("--- BrottBrain Card Priority ---")
	
	var brain := BrottBrain.new()
	var b := _make_brott(0, ChassisData.ChassisType.SCOUT)
	b.hp = 20.0  # Low HP triggers both cards
	b.energy = 10.0
	var enemy := _make_brott(1, ChassisData.ChassisType.BRAWLER)
	enemy.position = Vector2(256, 128)
	
	# Card 1: low HP → switch to defensive
	brain.add_card(BrottBrain.BehaviorCard.new(BrottBrain.Trigger.WHEN_IM_HURT, 0.4, BrottBrain.Action.SWITCH_STANCE, 1))
	# Card 2: low energy → conserve
	brain.add_card(BrottBrain.BehaviorCard.new(BrottBrain.Trigger.WHEN_LOW_ENERGY, 0.2, BrottBrain.Action.WEAPONS, "conserve"))
	
	b.stance = 0
	brain.evaluate(b, enemy, 0.0)
	# First card should fire (HP check), not second
	assert_eq(b.stance, 1, "First matching card fires (HP check wins over energy check)")
	assert_eq(brain.weapon_mode, "all_fire", "Second card doesn't fire when first matches")

## ===== MAX CARDS =====

func _test_brottbrain_max_cards() -> void:
	print("--- BrottBrain Max Cards ---")
	
	var brain := BrottBrain.new()
	for i in 8:
		var ok := brain.add_card(BrottBrain.BehaviorCard.new(0, 0.5, 0, 0))
		assert_true(ok, "Card %d added successfully" % (i + 1))
	
	var overflow := brain.add_card(BrottBrain.BehaviorCard.new(0, 0.5, 0, 0))
	assert_false(overflow, "9th card rejected (max 8)")
	assert_eq(brain.cards.size(), 8, "Brain has exactly 8 cards")

## ===== SMART DEFAULTS =====

func _test_brottbrain_defaults() -> void:
	print("--- BrottBrain Smart Defaults ---")
	
	var scout_brain := BrottBrain.default_for_chassis(0)
	assert_eq(scout_brain.default_stance, 2, "Scout default stance = Kiting")
	assert_true(scout_brain.cards.size() > 0, "Scout has default cards")
	
	var brawler_brain := BrottBrain.default_for_chassis(1)
	assert_eq(brawler_brain.default_stance, 0, "Brawler default stance = Aggressive")
	assert_true(brawler_brain.cards.size() > 0, "Brawler has default cards")
	
	var fortress_brain := BrottBrain.default_for_chassis(2)
	assert_eq(fortress_brain.default_stance, 0, "Fortress default stance = Aggressive")
	assert_true(fortress_brain.cards.size() > 0, "Fortress has default cards")

## ===== BRAIN + COMBAT INTEGRATION =====

func _test_brottbrain_integration() -> void:
	print("--- BrottBrain Integration ---")
	
	var sim := CombatSim.new(42)
	var b := _make_brott(0, ChassisData.ChassisType.SCOUT)
	b.position = Vector2(64, 128)
	b.brain = BrottBrain.new()
	b.brain.default_stance = 2  # Kiting
	# When hurt below 40%, switch to defensive
	b.brain.add_card(BrottBrain.BehaviorCard.new(BrottBrain.Trigger.WHEN_IM_HURT, 0.4, BrottBrain.Action.SWITCH_STANCE, 1))
	
	var enemy := _make_brott(1, ChassisData.ChassisType.BRAWLER)
	enemy.position = Vector2(256, 128)
	sim.add_brott(b)
	sim.add_brott(enemy)
	
	# Initially shouldn't be hurt enough
	b.stance = 2
	b.hp = 80.0
	sim.simulate_tick()
	assert_eq(b.stance, 2, "Stance unchanged at 80% HP")
	
	# Drop HP to trigger card
	b.hp = 30.0
	sim.simulate_tick()
	assert_eq(b.stance, 1, "Stance switched to Defensive at 30% HP")

## ===== ECONOMY =====

func _test_economy_init() -> void:
	print("--- Economy Init ---")
	
	var gs := GameState.new()
	assert_eq(gs.bolts, 0, "Starting bolts = 0")
	assert_true(0 in gs.owned_chassis, "Scout owned at start")
	assert_true(4 in gs.owned_weapons, "Plasma Cutter owned at start")
	assert_true(1 in gs.owned_armor, "Plating owned at start")

func _test_economy_earn() -> void:
	print("--- Economy Earn ---")
	
	var gs := GameState.new()
	var net := gs.apply_match_result(true, "scrapyard_0")
	# First win: 200 earned - 20 repair = 180
	assert_eq(net, 180, "First win net = 180 (200 - 20)")
	assert_eq(gs.bolts, 180, "Bolts after first win = 180")
	
	# Second win vs same opponent: 100 - 20 = 80
	net = gs.apply_match_result(true, "scrapyard_0")
	assert_eq(net, 80, "Repeat win net = 80 (100 - 20)")
	assert_eq(gs.bolts, 260, "Bolts = 260 after two wins")

func _test_economy_buy() -> void:
	print("--- Economy Buy ---")
	
	var gs := GameState.new()
	gs.bolts = 300
	
	# Buy Minigun (50 Bolts)
	var ok := gs.buy_weapon(0)
	assert_true(ok, "Can buy Minigun")
	assert_eq(gs.bolts, 250, "250 Bolts after buying Minigun")
	assert_true(0 in gs.owned_weapons, "Minigun owned")
	
	# Can't buy again
	ok = gs.buy_weapon(0)
	assert_false(ok, "Can't buy Minigun twice")
	assert_eq(gs.bolts, 250, "Bolts unchanged on duplicate buy")
	
	# Can't afford Railgun (300)
	ok = gs.buy_weapon(1)
	assert_false(ok, "Can't afford Railgun at 250 Bolts")

func _test_economy_repair() -> void:
	print("--- Economy Repair ---")
	
	var gs := GameState.new()
	# Loss: 40 earned - 50 repair = -10 net
	var net := gs.apply_match_result(false, "scrapyard_0")
	# First time loss is still first_win? No — first_wins only on win
	# Loss: 40 - 50 = -10
	assert_eq(net, -10, "Loss net = -10 (40 - 50)")
	assert_eq(gs.bolts, -10, "Can go negative on bolts")

func _test_economy_first_win() -> void:
	print("--- Economy First Win ---")
	
	var gs := GameState.new()
	# First win vs opponent 0: 200 bonus
	gs.apply_match_result(true, "scrapyard_0")
	assert_true("scrapyard_0" in gs.first_wins, "First win tracked")
	
	# First win vs opponent 1: another 200
	gs.apply_match_result(true, "scrapyard_1")
	assert_eq(gs.first_wins.size(), 2, "Two first wins tracked")
	
	# Repeat win vs 0: no bonus
	var old_bolts := gs.bolts
	gs.apply_match_result(true, "scrapyard_0")
	assert_eq(gs.bolts, old_bolts + 80, "Repeat win = 100 - 20 = 80")

func _test_shop_prices() -> void:
	print("--- Shop Prices ---")
	
	assert_eq(GameState.WEAPON_PRICES[0], 50, "Minigun costs 50")
	assert_eq(GameState.WEAPON_PRICES[4], 0, "Plasma Cutter is free")
	assert_eq(GameState.CHASSIS_PRICES[0], 0, "Scout is free")
	assert_eq(GameState.CHASSIS_PRICES[1], 200, "Brawler costs 200")
	assert_eq(GameState.CHASSIS_PRICES[2], 400, "Fortress costs 400")
	assert_eq(GameState.ARMOR_PRICES[1], 0, "Plating is free")
	assert_eq(GameState.MODULE_PRICES[0], 100, "Overclock costs 100")

## ===== LOADOUT VALIDATION =====

func _test_loadout_validation() -> void:
	print("--- Loadout Validation ---")
	
	var gs := GameState.new()
	# Default: Scout + Plasma Cutter + Plating
	var v := gs.validate_loadout()
	assert_true(v["valid"], "Default loadout is valid")

func _test_loadout_weight() -> void:
	print("--- Loadout Weight ---")
	
	var gs := GameState.new()
	# Scout weight cap = 30 kg
	# Plasma Cutter = 8 kg, Plating = 15 kg → 23 kg (ok)
	var v := gs.validate_loadout()
	assert_eq(v["weight"], 23, "Default weight = 23 kg")
	assert_eq(v["weight_cap"], 30, "Scout weight cap = 30 kg")
	
	# Add heavy weapons to exceed
	gs.owned_weapons.append(1)  # Railgun = 15 kg
	gs.equipped_weapons.append(1)
	v = gs.validate_loadout()
	# 8 + 15 + 15 = 38 > 30
	assert_false(v["valid"], "Overweight loadout is invalid")

func _test_loadout_slots() -> void:
	print("--- Loadout Slots ---")
	
	var gs := GameState.new()
	# Scout has 2 weapon slots
	gs.owned_weapons.append(0)  # Minigun
	gs.owned_weapons.append(2)  # Shotgun
	gs.equipped_weapons = [4, 0, 2]  # 3 weapons > 2 slots
	var v := gs.validate_loadout()
	assert_false(v["valid"], "Too many weapons is invalid")
	assert_true(v["errors"].size() > 0, "Has error messages")

func _test_loadout_ownership() -> void:
	print("--- Loadout Ownership ---")
	
	var gs := GameState.new()
	gs.equipped_weapons = [1]  # Railgun — not owned
	var v := gs.validate_loadout()
	assert_false(v["valid"], "Equipping unowned weapon is invalid")

## ===== PROGRESSION =====

func _test_progression_scrapyard() -> void:
	print("--- Progression Scrapyard ---")
	
	var gs := GameState.new()
	assert_eq(gs.current_league, "scrapyard", "Start in Scrapyard")
	assert_false(gs.bronze_unlocked, "Bronze not unlocked at start")
	assert_false(gs.brottbrain_unlocked, "BrottBrain not unlocked at start")

func _test_progression_bronze_unlock() -> void:
	print("--- Progression Bronze Unlock ---")
	
	var gs := GameState.new()
	gs.apply_match_result(true, "scrapyard_0")
	assert_false(gs.bronze_unlocked, "Bronze not unlocked after 1 win")
	
	gs.apply_match_result(true, "scrapyard_1")
	assert_false(gs.bronze_unlocked, "Bronze not unlocked after 2 wins")
	
	gs.apply_match_result(true, "scrapyard_2")
	assert_true(gs.bronze_unlocked, "Bronze unlocked after beating all 3 Scrapyard opponents")
	assert_true(gs.brottbrain_unlocked, "BrottBrain unlocked with Bronze")

## ===== OPPONENT DATA =====

func _test_opponent_data() -> void:
	print("--- Opponent Data ---")
	
	assert_eq(OpponentData.get_league_size("scrapyard"), 3, "Scrapyard has 3 opponents")
	
	var opp0 := OpponentData.get_opponent("scrapyard", 0)
	assert_eq(opp0["name"], "Rusty", "Opponent 0 is Rusty")
	assert_eq(opp0["chassis"], ChassisData.ChassisType.SCOUT, "Rusty uses Scout")
	
	var opp2 := OpponentData.get_opponent("scrapyard", 2)
	assert_eq(opp2["name"], "Crusher", "Opponent 2 is Crusher")
	assert_eq(opp2["chassis"], ChassisData.ChassisType.BRAWLER, "Crusher uses Brawler")
	assert_eq(opp2["weapons"].size(), 2, "Crusher has 2 weapons")

func _test_opponent_build() -> void:
	print("--- Opponent Build ---")
	
	var b := OpponentData.build_opponent_brott("scrapyard", 0)
	assert_true(b != null, "Can build Scrapyard opponent 0")
	assert_eq(b.team, 1, "Opponent is team 1")
	assert_eq(b.bot_name, "Rusty", "Bot name is Rusty")
	assert_true(b.alive, "Bot starts alive")
	assert_true(b.brain != null, "Bot has default brain")

## ===== OVERCLOCK BUG FIXES =====

func _test_overclock_cooldown() -> void:
	print("--- Overclock Cooldown ---")
	
	var mdata := ModuleData.get_module(ModuleData.ModuleType.OVERCLOCK)
	assert_near(mdata["cooldown"], 3.0, 0.01, "Overclock cooldown = 3.0s (not 7.0s)")
	assert_near(mdata["duration"], 4.0, 0.01, "Overclock duration = 4.0s")

func _test_overclock_recovery_clears() -> void:
	print("--- Overclock Recovery Clears ---")
	
	var sim := CombatSim.new(1)
	var b := _make_brott(0, ChassisData.ChassisType.BRAWLER)
	b.module_types = [ModuleData.ModuleType.OVERCLOCK]
	b.module_cooldowns = [0.0]
	b.module_active_timers = [0.0]
	b.position = Vector2(64, 128)
	
	var enemy := _make_brott(1, ChassisData.ChassisType.FORTRESS)
	enemy.position = Vector2(400, 400)
	sim.add_brott(b)
	sim.add_brott(enemy)
	
	# Activate overclock
	sim._activate_module(b, 0)
	assert_true(b.overclock_active, "Overclock active after activation")
	assert_false(b.overclock_recovery, "Not in recovery yet")
	
	# Run 80 ticks (4 seconds) — overclock should deactivate
	for i in 80:
		sim._tick_modules(b)
	assert_false(b.overclock_active, "Overclock deactivated after 4s")
	assert_true(b.overclock_recovery, "In recovery after deactivation")
	
	# Run 60 more ticks (3 seconds) — recovery should clear
	for i in 60:
		sim._tick_modules(b)
	assert_false(b.overclock_recovery, "Recovery cleared after 3s cooldown")
	assert_near(b.get_fire_rate_multiplier(), 1.0, 0.01, "Fire rate back to normal after recovery")

## ===== WEAPON MODES =====

func _test_weapon_modes() -> void:
	print("--- Weapon Modes ---")
	
	var sim := CombatSim.new(1)
	var b := _make_brott(0, ChassisData.ChassisType.BRAWLER)
	b.position = Vector2(64, 128)
	b.weapon_types = [WeaponData.WeaponType.MINIGUN]
	b.weapon_cooldowns = [0.0]
	b.brain = BrottBrain.new()
	b.brain.weapon_mode = "hold_fire"
	
	var enemy := _make_brott(1, ChassisData.ChassisType.BRAWLER)
	enemy.position = Vector2(96, 128)  # Close range
	sim.add_brott(b)
	sim.add_brott(enemy)
	
	var start_hp := enemy.hp
	for i in 20:
		sim.simulate_tick()
	assert_near(enemy.hp, start_hp, 0.01, "Hold fire: enemy takes no damage")
	
	# Switch to all_fire
	b.brain.weapon_mode = "all_fire"
	for i in 20:
		sim.simulate_tick()
	assert_true(enemy.hp < start_hp, "All fire: enemy takes damage")

## ===== TARGET PRIORITY =====

func _test_target_priority() -> void:
	print("--- Target Priority ---")
	
	var sim := CombatSim.new(1)
	var b := _make_brott(0, ChassisData.ChassisType.BRAWLER)
	b.position = Vector2(128, 128)
	
	# Two enemies — one near, one far but lower HP
	var near := _make_brott(1, ChassisData.ChassisType.BRAWLER)
	near.position = Vector2(160, 128)  # 1 tile
	near.hp = 100.0
	
	var weak := _make_brott(1, ChassisData.ChassisType.SCOUT)
	weak.position = Vector2(256, 128)  # 4 tiles
	weak.hp = 10.0
	
	sim.add_brott(b)
	sim.add_brott(near)
	sim.add_brott(weak)
	
	# Default: nearest
	var target := sim._find_target(b)
	assert_eq(target, near, "Default target = nearest")
	
	# Weakest
	target = sim._find_target_by_priority(b, "weakest")
	assert_eq(target, weak, "Weakest target = low HP enemy")

## ===== MOVEMENT OVERRIDE =====

func _test_movement_override() -> void:
	print("--- Movement Override ---")
	
	var sim := CombatSim.new(1)
	var b := _make_brott(0, ChassisData.ChassisType.BRAWLER)
	b.position = Vector2(64, 64)
	b.brain = BrottBrain.new()
	b.brain.movement_override = "center"
	b.weapon_types = []
	b.weapon_cooldowns = []
	
	var enemy := _make_brott(1, ChassisData.ChassisType.BRAWLER)
	enemy.position = Vector2(400, 400)
	enemy.weapon_types = []
	enemy.weapon_cooldowns = []
	sim.add_brott(b)
	sim.add_brott(enemy)
	
	var center := Vector2(256, 256)  # 8 * 32
	var start_dist := b.position.distance_to(center)
	for i in 20:
		# Re-set override each tick since evaluate resets it
		b.brain.movement_override = "center"
		sim.simulate_tick()
	var end_dist := b.position.distance_to(center)
	assert_true(end_dist < start_dist, "Movement override: closer to center")

## ===== GAME FLOW =====

func _test_game_flow() -> void:
	print("--- Game Flow ---")
	
	var flow := GameFlow.new()
	assert_eq(flow.current_screen, GameFlow.Screen.MAIN_MENU, "Start at main menu")
	
	flow.new_game()
	assert_eq(flow.current_screen, GameFlow.Screen.SHOP, "New game → Shop")
	
	flow.go_to_loadout()
	assert_eq(flow.current_screen, GameFlow.Screen.LOADOUT, "Go to Loadout")
	
	flow.go_to_brottbrain()
	# Should skip since brain not unlocked
	assert_eq(flow.current_screen, GameFlow.Screen.OPPONENT_SELECT, "Brain skipped → Opponent Select")
	
	flow.select_opponent(0)
	assert_eq(flow.current_screen, GameFlow.Screen.ARENA, "Select opponent → Arena")
	
	flow.finish_match(true)
	assert_eq(flow.current_screen, GameFlow.Screen.RESULT, "Match end → Result")
	assert_true(flow.last_match_won, "Win tracked")
	
	flow.continue_from_result()
	assert_eq(flow.current_screen, GameFlow.Screen.SHOP, "Continue → Shop")
