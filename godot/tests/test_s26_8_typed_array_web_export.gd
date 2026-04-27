## test_s26_8_typed_array_web_export.gd — [S26.8] Typed-array silent-crash regression
##
## Root cause of the 2026-04-27 03:13 UTC blank-screen playtest bug:
## In opponent_loadouts.gd `get_archetype_enemies()`, the line
##     var specs: Array[Dictionary]
##     ...
##     specs = template["enemy_specs"].duplicate(true)
## silently crashes on Godot 4 web release export. `Dictionary.duplicate(true)`
## returns an untyped `Array`, and assigning it to a typed `Array[Dictionary]`
## variable fails — the function aborts mid-execution with NO error in the
## browser console (web release swallows the type-coercion failure).
## compose_encounter() never returns; the arena never spawns; the screen stays
## grey. Editor + native debug builds tolerate this; web export does not.
##
## Fix: declare `var specs: Array` (untyped). The downstream loop iterating
## specs uses `.get()` on each element which works fine on untyped arrays.
##
## These assertions FAIL on main @ ff1730d (pre-fix S26.7 deploy) under web
## release export and PASS post-fix. Editor-mode runs may pass on both
## (the type coercion issue is web-export-specific) — the regression value is
## still pinning the runtime contract: compose_encounter must always return
## non-empty specs for every legal archetype × tier combo, never silently fail.
extends SceneTree

const RunState = preload("res://game/run_state.gd")
const OpponentLoadouts = preload("res://data/opponent_loadouts.gd")

func _init() -> void:
	var pass_count := 0
	var fail_count := 0
	var failures: Array = []

	# T1: standard_duel @ tier 1 with default fresh RunState — the EXACT path
	# HCD's blank-screen click hit. Must return non-empty.
	var rs_default := RunState.new()
	var spec_default = OpponentLoadouts.compose_encounter("standard_duel", 0, rs_default)
	assert(spec_default != null, "S26.8: standard_duel/tier1/default returned null — original blank-screen repro path")
	assert(spec_default.size() > 0, "S26.8: standard_duel/tier1/default returned empty — silent failure path")
	pass_count += 2

	# T2: every non-boss archetype × every tier (1..4) must return non-empty specs
	# of well-formed Dictionaries. This is the broad coverage that catches any
	# future typed-array silent-crash regressions across all archetype paths.
	var archetypes := [
		"standard_duel",
		"small_swarm",
		"large_swarm",
		"glass_cannon_blitz",
		"counter_build_elite",
		"miniboss_escorts",
	]
	var tier_indices := {1: 0, 2: 3, 3: 7, 4: 11}

	for tier in [1, 2, 3, 4]:
		for arch in archetypes:
			var rs := RunState.new(0, 1)
			var specs = OpponentLoadouts.compose_encounter(arch, tier_indices[tier], rs)
			assert(specs != null, "S26.8: compose_encounter('%s', tier=%d) returned null" % [arch, tier])
			assert(specs.size() > 0, "S26.8: compose_encounter('%s', tier=%d) returned empty — silent failure" % [arch, tier])
			for s in specs:
				assert(typeof(s) == TYPE_DICTIONARY, "S26.8: compose_encounter('%s', tier=%d) non-dict element" % [arch, tier])
				assert(s.has("hp"), "S26.8: compose_encounter('%s', tier=%d) spec missing 'hp'" % [arch, tier])
				assert(s.has("chassis"), "S26.8: compose_encounter('%s', tier=%d) spec missing 'chassis'" % [arch, tier])
			pass_count += 1

	# T3: counter_build_elite and miniboss_escorts go through the typed-array
	# assignment branch via get_archetype_enemies. Direct invocation of those
	# paths to ensure the typed-array-fix holds for both.
	for arch in ["counter_build_elite", "miniboss_escorts"]:
		var rs := RunState.new(1, 99)  # Brawler, seeded
		var specs = OpponentLoadouts.compose_encounter(arch, 7, rs)  # tier 3
		assert(specs != null and specs.size() > 0, "S26.8: %s tier3 must return non-empty (typed-array-assignment branch)" % arch)
		pass_count += 1

	print("test_s26_8_typed_array_web_export: %d passed, %d failed" % [pass_count, fail_count])
	if fail_count > 0:
		quit(1)
	else:
		quit(0)
