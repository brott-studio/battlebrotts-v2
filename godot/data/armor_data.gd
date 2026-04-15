## Static armor definitions
class_name ArmorData
extends RefCounted

enum ArmorType { NONE, PLATING, REACTIVE_MESH, ABLATIVE_SHELL }

const ARMORS := {
	ArmorType.NONE: {
		"name": "None",
		"reduction": 0.0,
		"weight": 0,
		"special": "",
	},
	ArmorType.PLATING: {
		"name": "Plating",
		"reduction": 0.20,
		"weight": 15,
		"special": "",
	},
	ArmorType.REACTIVE_MESH: {
		"name": "Reactive Mesh",
		"reduction": 0.10,
		"weight": 8,
		"special": "reflect",   # 5 flat damage back to attacker
	},
	ArmorType.ABLATIVE_SHELL: {
		"name": "Ablative Shell",
		"reduction": 0.40,
		"weight": 25,
		"special": "ablative",  # drops to 10% below 30% HP
	},
}

static func get_armor(type: ArmorType) -> Dictionary:
	return ARMORS[type]

## Returns effective reduction accounting for ablative special
static func effective_reduction(type: ArmorType, hp_pct: float) -> float:
	var a: Dictionary = ARMORS[type]
	if a["special"] == "ablative" and hp_pct < 0.3:
		return 0.10
	return a["reduction"]
