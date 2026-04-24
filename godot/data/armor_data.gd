## Static armor definitions — Sprint 4: archetypes + descriptions added
class_name ArmorData
extends RefCounted

enum ArmorType { NONE, PLATING, REACTIVE_MESH, ABLATIVE_SHELL }

const ARMORS := {
	ArmorType.NONE: {
		"name": "None",
		"archetype": "",
		"description": "",
		"reduction": 0.0,
		"weight": 0,
		"special": "",
	},
	ArmorType.PLATING: {
		"name": "Plating",
		"archetype": "Light",
		"description": "Flat damage reduction. No surprises, no downsides. The safe pick.",
		"reduction": 0.20,
		"weight": 15,
		"special": "",
	},
	ArmorType.REACTIVE_MESH: {
		"name": "Reactive Mesh",
		"archetype": "Adaptive",
		"description": "Light protection, but attackers take damage too. Punishes rapid-fire weapons.",
		"reduction": 0.10,
		"weight": 8,
		"special": "reflect",   # 5 flat damage back to attacker
	},
	ArmorType.ABLATIVE_SHELL: {
		"name": "Ablative Shell",
		"archetype": "Heavy",
		"description": "Incredible protection — until it isn't. Crumbles when you're on your last legs.",
		"reduction": 0.40,
		"weight": 25,
		"special": "ablative",  # drops to 10% below 30% HP
	},
}

## S22.2c: Per-league reflect damage table. Bronze = 5.0 is canonical (S22.1 shipped).
## Silver degrades to 2.0 — player-side degradation as progression tax (GDD §League Scaling).
## Gold/Platinum reserved; fallback = bronze value for unknown leagues.
const REFLECT_DAMAGE_BY_LEAGUE: Dictionary = {
	"scrapyard": 5.0,
	"bronze":    5.0,   # CANONICAL — S22.1 shipped, MUST NOT CHANGE
	"silver":    2.0,   # degraded
	"gold":      1.0,   # future
	"platinum":  0.0,   # future
}

static func get_armor(type: ArmorType) -> Dictionary:
	return ARMORS[type]

## Returns effective reduction accounting for ablative special
static func effective_reduction(type: ArmorType, hp_pct: float) -> float:
	var a: Dictionary = ARMORS[type]
	if a["special"] == "ablative" and hp_pct < 0.3:
		return 0.10
	return a["reduction"]

## S22.2c: Returns reflect damage for the given armor type at the given league.
## Returns 0.0 for non-reflect armors. Unknown league falls back to bronze value.
static func reflect_damage_for_league(type: ArmorType, league: String) -> float:
	var armor: Dictionary = ARMORS[type]
	if str(armor.get("special", "")) != "reflect":
		return 0.0
	return float(REFLECT_DAMAGE_BY_LEAGUE.get(league, REFLECT_DAMAGE_BY_LEAGUE["bronze"]))
