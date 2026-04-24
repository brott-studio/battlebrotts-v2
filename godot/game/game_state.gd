## Game state — tracks player inventory, bolts, progression
class_name GameState
extends RefCounted

## S14.1: fires exactly once on the false→true edge of a league-unlock flag.
## Payload is the league id being unlocked (e.g. "bronze").
signal league_unlocked(league_id: String)

## Economy
var bolts: int = 0

## Owned items (by name string for simplicity)
var owned_chassis: Array[int] = []  # ChassisData.ChassisType values
var owned_weapons: Array[int] = []  # WeaponData.WeaponType values
var owned_armor: Array[int] = []    # ArmorData.ArmorType values
var owned_modules: Array[int] = []  # ModuleData.ModuleType values

## Current loadout
var equipped_chassis: int = 0  # ChassisData.ChassisType.SCOUT
var equipped_weapons: Array[int] = []
var equipped_armor: int = 0  # ArmorData.ArmorType.NONE
var equipped_modules: Array[int] = []

## Progression
var current_league: String = "scrapyard"

## S13.9: tracks previous opponent archetype for variety-preserving picker.
## OpponentLoadouts.Archetype enum value, or -1 when unset (fresh run).
var _last_opponent_archetype: int = -1

var opponents_beaten: Array[String] = []  # "scrapyard_0", "scrapyard_1", etc.
var first_wins: Array[String] = []  # Tracks first-win bonus
var bronze_unlocked: bool = false
var silver_unlocked: bool = false  ## S22.2c: edge-detect flag for silver ceremony.
var brottbrain_unlocked: bool = false

## S13.6: BrottBrain Trick Choice (Scrapyard)
## Run-scoped: naturally cleared when GameFlow.new_game() constructs a fresh
## GameState. No separate reset hook needed — see clear_run_state() for an
## explicit path if future code ever reuses a GameState across runs.
var _tricks_seen: Array[String] = []
var _next_fight_pellet_mod: int = 0  ## applied to pellet count on next fight
var _pending_hp_delta: int = 0       ## HP_DELTA carryover, applied to BrottState next fight

## Item prices
const CHASSIS_PRICES := {
	0: 0,    # Scout — free starter
	1: 200,  # Brawler
	2: 400,  # Fortress
}

const WEAPON_PRICES := {
	0: 50,   # Minigun
	1: 300,  # Railgun
	2: 120,  # Shotgun
	3: 350,  # Missile Pod
	4: 0,    # Plasma Cutter — free starter
	5: 150,  # Arc Emitter
	6: 200,  # Flak Cannon
}

const ARMOR_PRICES := {
	1: 0,    # Plating — free starter (NONE=0 not purchasable)
	2: 150,  # Reactive Mesh
	3: 300,  # Ablative Shell
}

const MODULE_PRICES := {
	0: 100,  # Overclock
	1: 120,  # Repair Nanites
	2: 200,  # Shield Projector
	3: 150,  # Sensor Array
	4: 180,  # Afterburner
	5: 250,  # EMP Charge
}

func _init() -> void:
	# Starter items
	owned_chassis = [0]  # Scout
	owned_weapons = [4]  # Plasma Cutter
	owned_armor = [1]    # Plating
	owned_modules = []
	
	equipped_chassis = 0
	equipped_weapons = [4]  # Plasma Cutter
	equipped_armor = 1      # Plating
	equipped_modules = []

## Purchase an item. Returns true if successful.
func buy_chassis(type: int) -> bool:
	if type in owned_chassis:
		return false
	var price: int = CHASSIS_PRICES.get(type, -1)
	if price < 0 or bolts < price:
		return false
	bolts -= price
	owned_chassis.append(type)
	return true

func buy_weapon(type: int) -> bool:
	if type in owned_weapons:
		return false
	var price: int = WEAPON_PRICES.get(type, -1)
	if price < 0 or bolts < price:
		return false
	bolts -= price
	owned_weapons.append(type)
	return true

func buy_armor(type: int) -> bool:
	if type in owned_armor:
		return false
	var price: int = ARMOR_PRICES.get(type, -1)
	if price < 0 or bolts < price:
		return false
	bolts -= price
	owned_armor.append(type)
	return true

func buy_module(type: int) -> bool:
	if type in owned_modules:
		return false
	var price: int = MODULE_PRICES.get(type, -1)
	if price < 0 or bolts < price:
		return false
	bolts -= price
	owned_modules.append(type)
	return true

## Apply match result. Returns bolts earned (after repair).
func apply_match_result(won: bool, opponent_id: String) -> int:
	var earned: int = 100 if won else 40
	
	# First-win bonus
	if won and opponent_id not in first_wins:
		first_wins.append(opponent_id)
		earned = 200
	
	# Repair cost
	var repair: int = 20 if won else 50
	
	bolts += earned - repair
	
	# Track beaten opponents
	if won and opponent_id not in opponents_beaten:
		opponents_beaten.append(opponent_id)
	
	# Check league progression
	_check_progression()
	
	return earned - repair

func _check_progression() -> void:
	if current_league == "scrapyard":
		# S14.1: edge-detect false→true so league_unlocked emits exactly once,
		# even if apply_match_result is called again after the 3rd scrapyard win.
		var was_unlocked := bronze_unlocked
		var all_beaten := true
		for i in 3:
			if ("scrapyard_%d" % i) not in opponents_beaten:
				all_beaten = false
				break
		if all_beaten:
			bronze_unlocked = true
			brottbrain_unlocked = true
			if not was_unlocked:
				emit_signal("league_unlocked", "bronze")
	## S22.2c: silver unlock — fires once when all 7 Bronze opponents are beaten.
	if current_league == "bronze":
		var was_silver_unlocked := silver_unlocked
		var all_bronze_beaten := true
		for i in 7:  # 7 Silver templates from S22.1
			if ("bronze_%d" % i) not in opponents_beaten:
				all_bronze_beaten = false
				break
		if all_bronze_beaten:
			silver_unlocked = true
			if not was_silver_unlocked:
				emit_signal("league_unlocked", "silver")

## S14.1: transition current_league past scrapyard once the bronze moment
## ceremony has been shown. Caller (game_main) also clears its pending-
## ceremony flag; we no-op if already advanced.
## S22.2c: extended to advance bronze → silver once silver_unlocked is true.
func advance_league() -> void:
	if current_league == "scrapyard" and bronze_unlocked:
		current_league = "bronze"
	elif current_league == "bronze" and silver_unlocked:
		current_league = "silver"

## S13.6: Apply a resolved trick choice (data-driven). Caller owns the modal
## lifecycle; GameState only mutates session state.
func apply_trick_choice(trick: Dictionary, choice_key: String) -> void:
	var choice: Dictionary = trick[choice_key]
	_apply_trick_effect(choice.get("effect_type"), choice.get("effect_value"))
	if choice.has("effect_type_2"):
		_apply_trick_effect(choice["effect_type_2"], choice["effect_value_2"])
	var tid: String = String(trick.get("id", ""))
	if tid != "" and not _tricks_seen.has(tid):
		_tricks_seen.append(tid)

func _apply_trick_effect(t, v) -> void:
	match t:
		TrickChoices.EffectType.BOLTS_DELTA:
			bolts = max(0, bolts + int(v))
		TrickChoices.EffectType.HP_DELTA:
			_pending_hp_delta += int(v)
		TrickChoices.EffectType.NEXT_FIGHT_PELLET_MOD:
			_next_fight_pellet_mod += int(v)
		TrickChoices.EffectType.ITEM_GRANT:
			_grant_trick_item(v)
		TrickChoices.EffectType.ITEM_LOSE:
			_lose_trick_item(v)

## S13.7: wired via ItemTokens router. Accepts direct tokens
## (e.g. "minigun") and pool tokens (e.g. "random_weak").
## Unknown tokens → silent no-op. Grants are idempotent.
func _grant_trick_item(token) -> void:
	var resolved: Dictionary = ItemTokens.resolve_token(String(token))
	if resolved.is_empty():
		return
	var t: int = int(resolved["type"])
	match int(resolved["category"]):
		ItemTokens.CAT_WEAPON:
			if not owned_weapons.has(t):
				owned_weapons.append(t)
		ItemTokens.CAT_ARMOR:
			if not owned_armor.has(t):
				owned_armor.append(t)
		ItemTokens.CAT_MODULE:
			if not owned_modules.has(t):
				owned_modules.append(t)
		ItemTokens.CAT_CHASSIS:
			if not owned_chassis.has(t):
				owned_chassis.append(t)

func _lose_trick_item(token) -> void:
	var resolved: Dictionary = ItemTokens.resolve_token(String(token))
	if resolved.is_empty():
		return
	var t: int = int(resolved["type"])
	match int(resolved["category"]):
		ItemTokens.CAT_WEAPON:
			owned_weapons.erase(t)
		ItemTokens.CAT_ARMOR:
			owned_armor.erase(t)
		ItemTokens.CAT_MODULE:
			owned_modules.erase(t)
		ItemTokens.CAT_CHASSIS:
			owned_chassis.erase(t)

## S13.6: Pick a trick the player hasn't seen this run; fall back to the
## full pool once exhausted (no crash).
func pick_unseen_trick() -> Dictionary:
	var pool: Array = []
	for t in TrickChoices.TRICKS:
		if not _tricks_seen.has(String(t.get("id", ""))):
			pool.append(t)
	if pool.is_empty():
		pool = TrickChoices.TRICKS
	return pool[randi() % pool.size()]

## S13.6: Explicit run-reset hook. Current code doesn't need to call this
## (GameFlow.new_game() re-instantiates GameState) but it's here for future
## reuse paths (e.g. "continue" flows that keep the same GameState).
func clear_run_state() -> void:
	_tricks_seen.clear()
	_next_fight_pellet_mod = 0
	_pending_hp_delta = 0

## Validate current loadout against chassis constraints
func validate_loadout() -> Dictionary:
	var ch := ChassisData.get_chassis(equipped_chassis)
	var errors: Array[String] = []
	
	# Check weapon slots
	if equipped_weapons.size() > ch["weapon_slots"]:
		errors.append("Too many weapons: %d/%d" % [equipped_weapons.size(), ch["weapon_slots"]])
	
	# Check module slots
	if equipped_modules.size() > ch["module_slots"]:
		errors.append("Too many modules: %d/%d" % [equipped_modules.size(), ch["module_slots"]])
	
	# Check weight
	var total_weight: int = 0
	for wt in equipped_weapons:
		total_weight += WeaponData.get_weapon(wt)["weight"]
	if equipped_armor > 0:
		total_weight += ArmorData.get_armor(equipped_armor)["weight"]
	for mt in equipped_modules:
		total_weight += ModuleData.get_module(mt)["weight"]
	
	if total_weight > ch["weight_cap"]:
		errors.append("Overweight: %d/%d kg" % [total_weight, ch["weight_cap"]])
	
	# Check ownership
	for wt in equipped_weapons:
		if wt not in owned_weapons:
			errors.append("Weapon not owned: %d" % wt)
	if equipped_armor > 0 and equipped_armor not in owned_armor:
		errors.append("Armor not owned: %d" % equipped_armor)
	for mt in equipped_modules:
		if mt not in owned_modules:
			errors.append("Module not owned: %d" % mt)
	if equipped_chassis not in owned_chassis:
		errors.append("Chassis not owned: %d" % equipped_chassis)
	
	return {"valid": errors.size() == 0, "errors": errors, "weight": total_weight, "weight_cap": ch["weight_cap"]}

## Build a BrottState from current loadout
func build_brott() -> BrottState:
	var b := BrottState.new()
	b.team = 0
	b.bot_name = "Player Bot"
	b.chassis_type = equipped_chassis
	for wt in equipped_weapons:
		b.weapon_types.append(wt)
	b.armor_type = equipped_armor
	for mt in equipped_modules:
		b.module_types.append(mt)
	b.stance = 0  # Default aggressive, brain will override
	# S22.2c: Set player league so reflect-damage scales correctly.
	b.current_league = current_league
	b.setup()
	# S13.6: Apply pending trick effects accumulated between matches.
	# HP_DELTA shifts starting hp (and max_hp so the HUD bar matches);
	# NEXT_FIGHT_PELLET_MOD carries into the BrottState for per-shot application.
	# Both are single-use: cleared after consumption so they do not leak to
	# subsequent matches (or to rematches that rebuild the brott).
	if _pending_hp_delta != 0:
		var new_max: int = max(1, b.max_hp + _pending_hp_delta)
		b.max_hp = new_max
		b.hp = float(new_max)
		_pending_hp_delta = 0
	if _next_fight_pellet_mod != 0:
		b.pellet_mod = _next_fight_pellet_mod
		_next_fight_pellet_mod = 0
	return b
