# Arc F Exit Criteria Verification

**Arc:** Arc F — Roguelike Core Loop
**Date:** 2026-04-25
**Sprint closing arc:** S25.9
**Status:** COMPLETE ✅

## Exit Criteria

| # | Criterion | Status | Evidence |
|---|---|---|---|
| 1 | Player can start a fresh run, navigate 15 battles, reach IRONCLAD PRIME | ✅ | S25.5 reward flow, S25.7 boss path, S25.9 integration test gate A |
| 2 | Reward pick screen: 3 deduped items, pick 1, applied to RunState | ✅ | S25.5 PR #304, test_reward_pick.gd |
| 3 | Retry mechanic: 3 retries per run, loss-all → run end, retry preserves build | ✅ | S25.5 PR #304, test_run_loop.gd paths B+C |
| 4 | Run-end screens: BROTT DOWN + RUN COMPLETE with build summary + stats | ✅ | S25.8 PR #307, test_run_end_screens.gd |
| 5 | Click-to-move: yellow diamond waypoint, bot navigates, resumes autonomous | ✅ | S25.2 PR #301, test_arena_renderer_multi.gd |
| 6 | Click-to-target: orange reticle, override active, latest click wins | ✅ | S25.2 PR #301, test_arena_renderer_multi.gd gate 4 |
| 7 | Multi-target arena renders up to 6 enemy bots simultaneously | ✅ | S25.2 PR #301, EncounterSpawn.positions_for(n), S25.7 N-enemy spawn |
| 8 | All 7 encounter archetypes authored in encounter pool | ✅ | S25.4 PR #303, ARCHETYPE_TEMPLATES (7 records) |
| 9 | combat_batch.gd sims pass against multi-target encounter templates | ✅ | S25.3 audit baseline: Scout 54%, Brawler 44%, Fortress 50% |
| 10 | Encounter variety rule: no two consecutive encounters same archetype | ✅ | S25.6 PR #305, test_encounter_generator.gd gate 1 (0 violations, 1000 runs) |
| 11 | Run guarantees: Small Swarm + Counter-Build Elite + Mini-boss+Escorts each ≥1/run | ✅ | S25.6 PR #305, test_encounter_generator.gd gate 2 (≥99% of runs) |
| 12 | No regressions on existing arena/combat tests | ✅ | S25.9 full test suite green: see test_runner.gd output |

## Boss AI (additional deliverable)
- IRONCLAD PRIME boss-specific AI: EMP on active player modules, Shield Projector at ≤40% HP, aggressive at full HP, no Afterburner flee, executioner mode (closes on player at HP < 30%)
- Evidence: S25.9 PR #308, brottbrain.gd `boss_ai()` factory, `_evaluate_boss()`

## Tier Tinting (additional deliverable)
- Reward pick screen background tints per tier: grey-blue (T1) → bronze (T2) → silver-white (T3/T4) → red/gold (pre-boss)
- Evidence: S25.9 PR #308, reward_pick_screen.gd `_bg_color_for_battle()`

## Arc F carry-forwards to Arc G
- `_farthest_threat_name` / `_best_kill_name` tracking (currently shows "—")
- `BuildSummaryComponent` extraction (currently inline on both end screens)
- League-era dormant code deletion (brottbrain_screen, shop_screen, opponent_select_screen, league test files)
