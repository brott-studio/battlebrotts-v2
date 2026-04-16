## Sprint 13.7 — Item Token Router (Nutts-A)
## Central resolver: string token → {category, type, token} dict.
## Pool tokens (e.g. "random_weak") resolve by picking a direct token, then recursing.
## Unknown tokens or empty pools return {} — callers null-check. Never loops on empty pools.
class_name ItemTokens
extends RefCounted

const CAT_WEAPON  := 0
const CAT_ARMOR   := 1
const CAT_MODULE  := 2
const CAT_CHASSIS := 3

## Direct tokens: one token → one concrete {category, type}.
## Tokens match the enum names lowercased (see WeaponData/ArmorData/ModuleData).
const DIRECT := {
	# Weapons (WeaponData.WeaponType)
	"minigun":        {"category": CAT_WEAPON, "type": WeaponData.WeaponType.MINIGUN},
	"railgun":        {"category": CAT_WEAPON, "type": WeaponData.WeaponType.RAILGUN},
	"shotgun":        {"category": CAT_WEAPON, "type": WeaponData.WeaponType.SHOTGUN},
	"missile_pod":    {"category": CAT_WEAPON, "type": WeaponData.WeaponType.MISSILE_POD},
	"plasma_cutter":  {"category": CAT_WEAPON, "type": WeaponData.WeaponType.PLASMA_CUTTER},
	"arc_emitter":    {"category": CAT_WEAPON, "type": WeaponData.WeaponType.ARC_EMITTER},
	"flak_cannon":    {"category": CAT_WEAPON, "type": WeaponData.WeaponType.FLAK_CANNON},
	# Armor (ArmorData.ArmorType) — NONE excluded; it's not a grantable item.
	"plating":        {"category": CAT_ARMOR, "type": ArmorData.ArmorType.PLATING},
	"reactive_mesh":  {"category": CAT_ARMOR, "type": ArmorData.ArmorType.REACTIVE_MESH},
	"ablative_shell": {"category": CAT_ARMOR, "type": ArmorData.ArmorType.ABLATIVE_SHELL},
	# Modules (ModuleData.ModuleType)
	"overclock":         {"category": CAT_MODULE, "type": ModuleData.ModuleType.OVERCLOCK},
	"repair_nanites":    {"category": CAT_MODULE, "type": ModuleData.ModuleType.REPAIR_NANITES},
	"shield_projector":  {"category": CAT_MODULE, "type": ModuleData.ModuleType.SHIELD_PROJECTOR},
	"sensor_array":      {"category": CAT_MODULE, "type": ModuleData.ModuleType.SENSOR_ARRAY},
	"afterburner":       {"category": CAT_MODULE, "type": ModuleData.ModuleType.AFTERBURNER},
	"emp_charge":        {"category": CAT_MODULE, "type": ModuleData.ModuleType.EMP_CHARGE},
}

## Pool tokens: pick one direct entry, then resolve it.
const POOLS := {
	"random_weak": [
		"minigun", "shotgun",
		"plating", "reactive_mesh",
		"overclock", "repair_nanites",
	],
	"random_module": [
		"overclock", "repair_nanites", "shield_projector",
		"sensor_array", "afterburner", "emp_charge",
	],
}

## Resolve a token to {category, type, token} or {} on unknown/empty-pool.
## `rng` (optional): any object with randi_range(a,b). Falls back to global randi().
static func resolve_token(token: String, rng = null) -> Dictionary:
	if POOLS.has(token):
		var pool: Array = POOLS[token]
		if pool.is_empty():
			return {}
		var idx: int
		if rng != null:
			idx = rng.randi_range(0, pool.size() - 1)
		else:
			idx = randi() % pool.size()
		return resolve_token(String(pool[idx]), rng)
	if DIRECT.has(token):
		var entry: Dictionary = DIRECT[token]
		return {
			"category": entry["category"],
			"type": entry["type"],
			"token": token,
		}
	return {}

## Human-readable name for toasts. Returns "" on empty/invalid dict.
static func display_name(resolved: Dictionary) -> String:
	if resolved.is_empty() or not resolved.has("category") or not resolved.has("type"):
		return ""
	var cat: int = int(resolved["category"])
	var t: int = int(resolved["type"])
	match cat:
		CAT_WEAPON:
			if WeaponData.WEAPONS.has(t):
				return String(WeaponData.WEAPONS[t].get("name", ""))
		CAT_ARMOR:
			if ArmorData.ARMORS.has(t):
				return String(ArmorData.ARMORS[t].get("name", ""))
		CAT_MODULE:
			if ModuleData.MODULES.has(t):
				return String(ModuleData.MODULES[t].get("name", ""))
		CAT_CHASSIS:
			# No chassis tokens in DIRECT yet; reserved for future.
			return ""
	return ""
