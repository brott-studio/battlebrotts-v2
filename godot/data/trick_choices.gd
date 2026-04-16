extends Node
class_name TrickChoices

enum EffectType { BOLTS_DELTA, ITEM_GRANT, ITEM_LOSE, NEXT_FIGHT_PELLET_MOD, HP_DELTA }

const TRICKS := [
	{
		"id": "rusty_launcher",
		"brottbrain_text": "Looks shady.",
		"prompt": "A rusty pellet launcher half-buried in the scrap. Might work. Might blow up in your face.",
		"choice_a": {"label": "Take it", "effect_type": EffectType.NEXT_FIGHT_PELLET_MOD, "effect_value": 1, "flavor_line": "Stuffed it in the pack. You'll find out next fight."},
		"choice_b": {"label": "Burn it for scrap", "effect_type": EffectType.BOLTS_DELTA, "effect_value": 10, "flavor_line": "Smart. +10 bolts."},
	},
	{
		"id": "scavenger_kid",
		"brottbrain_text": "I don't trust that kid.",
		"prompt": "A scrawny scavenger waves a mystery bundle at you. \"Five bolts. No peeking.\"",
		"choice_a": {"label": "Buy mystery (-5 bolts)", "effect_type": EffectType.ITEM_GRANT, "effect_value": "random_weak", "effect_type_2": EffectType.BOLTS_DELTA, "effect_value_2": -5, "flavor_line": "Ugh, of course it's that."},
		"choice_b": {"label": "Walk away", "effect_type": EffectType.BOLTS_DELTA, "effect_value": 0, "flavor_line": "Good call. That kid's a menace."},
	},
	{
		"id": "risk_for_reward",
		"brottbrain_text": "Tempting, but...",
		"prompt": "A spring-loaded crate rig. Three extra pellets if it doesn't snap your paw off.",
		"choice_a": {"label": "Grab the pellets", "effect_type": EffectType.NEXT_FIGHT_PELLET_MOD, "effect_value": 3, "effect_type_2": EffectType.HP_DELTA, "effect_value_2": -5, "flavor_line": "Got 'em. Lost some fur. -5 HP."},
		"choice_b": {"label": "No risk", "effect_type": EffectType.BOLTS_DELTA, "effect_value": 0, "flavor_line": "Wise. Boring, but wise."},
	},
]
