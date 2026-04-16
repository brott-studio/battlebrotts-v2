# Sprint 13.10 — Arc Wrap + Polish

**Type:** WRAP sprint (not a build sprint)
**Arc:** Sprint 13.x (13.3 → 13.10)
**Size target:** ~100 LoC production, ~10–15 tests
**Posture:** Close things. Do not open things.

---

## §1 Scope

### In scope
1. Three small carry-forward items from prior sprints (counter-play, empty-pool guard, weight-cap test).
2. A manual playtest run (human-driven by Eric) with observations captured to disk.
3. At most 2–3 **critical-only** fixes discovered by the playtest.
4. Optional: legacy `test_sprint2.gd` cleanup decision.
5. Specc-owned arc rollup audit (separate deliverable — see §8).

### 🚨 DO NOT EXCEED — HARD REJECTS 🚨

**Wrap sprints die from scope creep. Reviewer and Nutts: reject on sight.**

- ❌ **NO new tricks.** The trick library is frozen for the arc.
- ❌ **NO new chassis.** Five archetypes is the arc's answer.
- ❌ **NO new opponents / templates.** 30 templates (6×5) is the arc's answer.
- ❌ **NO audio work.** Still parked. Still parked next sprint too. Stop asking.
- ❌ **NO new combat mechanics.** TCR balance, outcome system, trick choices — all done.
- ❌ **NO refactors** unless they directly fix a critical playtest finding.
- ❌ **NO speculative work.** "While I'm in here…" is the phrase that ends the sprint.
- ❌ **NO new content of any kind.** If it's additive, it belongs in S14.
- ❌ **NO tuning passes** beyond the critical fixes bucket. Broad tuning is S14 material.

**If a change doesn't map to §2, §3, or §8 — it doesn't belong in 13.10.**

---

## §2 Carry-forward items

### 2.1 Counter-play implementation (~50 LoC)

**Goal:** When the player leans heavy on one archetype for 3+ consecutive fights, the opponent picker occasionally ships a counter matchup.

**Counter map (const, easy-tune):**
```
TANK         → CONTROLLER
GLASS_CANNON → SKIRMISHER
SKIRMISHER   → BRUISER
BRUISER      → GLASS_CANNON
CONTROLLER   → TANK
```
(Rock-paper-scissors-ish; exact tuning is a guess — make the map and the threshold constants.)

**Implementation hints:**

- **`godot/game/game_state.gd`**
  - Add `var _recent_player_archetypes: Array[int] = []` (tracks last N fights; N = 5 cap).
  - Add `const PLAYER_ARCHETYPE_HISTORY_CAP := 5` and `const COUNTER_PLAY_STREAK_THRESHOLD := 3`.
  - In `apply_match_result()` (or wherever the post-match hook fires), derive current player archetype from `equipped_chassis` via `ChassisData.get_chassis(equipped_chassis).archetype` and append to `_recent_player_archetypes`. Trim to cap.
  - Add `func get_player_archetype_hint() -> int`: returns the archetype if the last `COUNTER_PLAY_STREAK_THRESHOLD` entries are all equal, else `-1`.
  - `clear_run_state()` must reset `_recent_player_archetypes`.

- **`godot/data/opponent_loadouts.gd`**
  - Add `const COUNTER_MAP := { TANK: CONTROLLER, GLASS_CANNON: SKIRMISHER, SKIRMISHER: BRUISER, BRUISER: GLASS_CANNON, CONTROLLER: TANK }` (use `Archetype` enum values).
  - Add `const COUNTER_PLAY_CHANCE := 0.5` (50% when hint is active — "occasionally" per brief; tune later).
  - In `pick_opponent_loadout()`, when `_player_archetype_hint != -1`:
    - Roll against `COUNTER_PLAY_CHANCE`.
    - If hit: filter pool to templates whose archetype equals `COUNTER_MAP[_player_archetype_hint]`. If non-empty, use that filtered pool for the rest of variety logic. If empty, fall through to normal logic (don't force it).
  - Counter filtering happens **before** `last_archetype` variety filtering so variety still applies within the countered pool.

- **Caller wiring (wherever `pick_opponent_loadout` is called — likely shop/match flow):**
  - Pass `GameState.get_player_archetype_hint()` as the 3rd arg. Grep for existing call sites; there should be 1–2.

**Determinism note:** All RNG must use the project's seeded RNG pattern (consistent with S13.9 variety picker). No bare `randf()`.

### 2.2 Picker empty-pool guard (~10 LoC)

**Location:** `godot/data/opponent_loadouts.gd` → `pick_opponent_loadout`.

```gdscript
if pool.is_empty():
    push_warning("pick_opponent_loadout: empty pool at tier %d" % difficulty_tier)
    return {}
```

**Caller handling:** Grep for callers. If any caller dereferences the result without guarding, add:
```gdscript
var loadout := OpponentLoadouts.pick_opponent_loadout(...)
if loadout.is_empty():
    # fallback: synthesize a default opponent or reuse last_opponent
    loadout = OpponentLoadouts.get_fallback_loadout(difficulty_tier)
```
Implement `get_fallback_loadout(difficulty_tier)` to return the first template matching the tier, or the lowest-tier template if none match. This should be unreachable in practice but prevents a crash if the data file is ever malformed.

### 2.3 Weight-cap validation test (~5 LoC)

**Location:** `godot/tests/test_sprint13_10.gd` (new file).

```gdscript
func test_template_count_under_cap():
    const CAP := 20
    # Current expected: 30 templates (6×5). Wait — brief says cap 20 but we ship 30.
    # See note below: the actual cap must reflect reality.
```

**⚠️ Spec note to Nutts:** Brief says "≤ 20" but S13.9 shipped 6 templates × 5 archetypes = **30 templates**. The cap exists to catch *future* runaway growth, not to fail today. Set cap to **40** (current + ~30% headroom). If Nutts finds a different template count on inspection, round up to next 10 above current. Document the chosen cap in a code comment referencing this spec. This is the only tuning decision Nutts gets to make autonomously.

---

## §3 Polish protocol

### 3.1 Playtest run

**Who:** Eric (human). Nutts cannot do this — it requires a person actually playing the game.

**When:** After items 2.1–2.3 are merged and green. Playtest runs on the merged branch, not a feature branch.

**What:** Single start-to-finish run. Scrapyard → Bronze → as far as the player gets or wants to go. One run only.

**Capture:** Notes go to `docs/playtest/sprint13.10-arc-wrap.md`. Template:

```markdown
# Sprint 13.10 Playtest — Arc Wrap

**Date:** <YYYY-MM-DD>
**Player:** Eric
**Build:** <git sha>
**Run outcome:** <win / loss / abandoned @ tier>

## Flow
- Scrapyard: <observations>
- Bronze: <observations>
- <later tiers if reached>

## Findings

### Critical (ship-blocking / broken)
- [ ] <finding> — repro: <steps>

### Important but not critical (defer to S14)
- <finding>

### Nits (noted, no action)
- <finding>

## Tuning observations
<subjective feel notes — do not act on these this sprint>
```

### 3.2 Critical-only fixes

**Definition of "critical":**
- Soft-lock or hard crash
- Broken UX that makes a feature unusable (not just awkward)
- Regression from a previous sprint (something that worked before and now doesn't)

**Explicit non-critical (defer to S14 backlog):**
- Tuning nits ("this feels too hard")
- Polish wants ("this could use a better animation")
- Feature gaps ("I wish there were X")
- Anything that requires new content or a new mechanic

**Budget:** Up to 3 fixes, ~30 LoC each. If the playtest produces zero criticals, **ship without.** Do not invent criticals to fill the budget.

**Process:** Each fix gets its own test in `test_sprint13_10.gd` and a brief entry in the playtest doc under "Findings → Critical" with a checkbox.

### 3.3 Playtest dependency fallback

If Eric can't playtest inside the sprint window (illness, schedule, whatever):
- Ship items 2.1 / 2.2 / 2.3 only.
- Mark playtest + critical fixes as **deferred to a post-arc patch** (13.10.1).
- Arc rollup (§8) still proceeds — it doesn't depend on playtest.
- Ett and Boltz should green-light this path explicitly rather than leaving it ambiguous.

### 3.4 Legacy `test_sprint2.gd` (optional)

- Inspect the file. If it still exercises live code paths, retrofit to current APIs.
- If it tests dead/replaced systems, delete it and add a one-line entry to `MIGRATION.md` noting the removal and the sprint it originally covered.
- **No urgency.** If scope is tight, skip and roll to S14.

---

## §4 Acceptance criteria

1. ✅ `pick_opponent_loadout` uses `_player_archetype_hint` when non-`-1`; swaps pool to countered archetype with probability `COUNTER_PLAY_CHANCE`; falls through cleanly if countered pool is empty.
2. ✅ `GameState` tracks player archetype per fight, caps history at 5, and `get_player_archetype_hint()` returns the streaked archetype when last-3 entries match, else `-1`. `clear_run_state()` resets it.
3. ✅ Empty-pool guard in `pick_opponent_loadout` returns `{}` with a `push_warning`; caller handles via `get_fallback_loadout()` without crashing.
4. ✅ Template-count assertion test exists and passes at current count; would fail if count exceeds chosen cap.
5. ✅ Playtest executed (OR explicitly deferred per §3.3); notes filed at `docs/playtest/sprint13.10-arc-wrap.md`.
6. ✅ ≤3 critical fixes from playtest applied (or zero if none found or playtest deferred).
7. ✅ `godot/tests/test_sprint13_10.gd` covers all code changes above (~10–15 tests).
8. ✅ All prior tests green, CI green on merged branch (per KB #70 — reviewer verifies post-merge, not just local).
9. 🟡 (optional) `test_sprint2.gd` decision documented (retrofit / delete / defer).

---

## §5 Tests — `godot/tests/test_sprint13_10.gd`

Target: 12–15 tests.

**Counter-play — GameState (4–5 tests):**
1. `test_player_archetype_history_starts_empty`
2. `test_apply_match_result_appends_player_archetype` — one match → one entry matching equipped chassis's archetype.
3. `test_player_archetype_history_caps_at_5` — 7 matches → length 5, oldest evicted.
4. `test_get_player_archetype_hint_returns_minus_one_when_streak_lt_3`
5. `test_get_player_archetype_hint_returns_archetype_when_streak_ge_3`
6. `test_clear_run_state_resets_player_archetype_history`

**Counter-play — picker (3–4 tests):**
7. `test_pick_opponent_hint_minus_one_behaves_like_s13_9` — regression guard: no hint → identical behavior to S13.9.
8. `test_pick_opponent_hint_tank_can_yield_controller` — seed RNG, hint=TANK, assert chosen archetype is CONTROLLER within N deterministic rolls.
9. `test_pick_opponent_hint_counter_pool_empty_falls_through` — if countered archetype has no tier-valid templates, picker uses normal pool (no crash, no empty return).
10. `test_counter_map_covers_all_archetypes` — every archetype enum value is a key in `COUNTER_MAP`.

**Empty-pool guard (2 tests):**
11. `test_pick_opponent_empty_pool_returns_empty_dict` — force-inject empty pool (or request impossible tier) → `{}`.
12. `test_get_fallback_loadout_returns_valid_template` — non-empty dict with required schema fields.

**Weight-cap (1 test):**
13. `test_template_count_under_cap` — asserts `OpponentLoadouts.TEMPLATES.size() <= CAP`.

**Critical fixes (0–3 tests):**
14–16. One per critical fix applied. Named `test_fix_<short_slug>`.

**Determinism guard (1 test):**
17. `test_counter_play_is_deterministic_with_seeded_rng` — same seed + same hint → same pick across runs.

---

## §6 Risks / flags for Ett

1. **🔴 Playtest is a human dependency.** Eric has to actually play. If his window collapses, the sprint still closes via the §3.3 fallback, but Ett should confirm with Eric up front whether a playtest slot exists. **No slot → declare §3.3 path at plan time**, not at merge time.

2. **🟡 Counter-play tuning is subjective.** "3+ fights" streak threshold and `COUNTER_PLAY_CHANCE = 0.5` are guesses. Constants are extracted for easy tuning, but no one should pretend these numbers are right on first try. Real tuning comes from the playtest *after* this sprint ships — likely S14 or a patch.

3. **🔴 Scope creep is the single biggest failure mode for wrap sprints.** Every item in §1's DO-NOT list is a realistic temptation. Reviewer must reject additive work on sight with a pointer back to §1. If Nutts proposes "while I'm in here…" — the answer is no, log it for S14.

4. **🟡 KB #72 (design-time noun verification).** Spec already verified: `_player_archetype_hint` param exists in `pick_opponent_loadout` signature; `GameState._last_opponent_archetype` exists as the natural neighbor for new state; `ChassisData.get_chassis(type).archetype` is the archetype lookup path. Nutts should re-verify at implementation time; these bindings can drift.

5. **🟡 KB #70 (merge-time CI).** Wrap sprints sometimes get sloppy on final verification because "it's just polish." Reviewer must confirm CI green on the merged branch, not just Nutts's feature branch.

6. **🟢 `test_sprint2.gd` scope risk.** If Nutts starts retrofitting and it balloons, kill the retrofit and switch to delete-with-note. No sprint should die on a legacy-test refactor.

---

## §7 Split-spawn recommendation

**Primary recommendation: single Nutts.**

Total production LoC: ~70–100 (50 counter-play + 10 empty-pool guard + 5 cap test + up to 90 critical fixes if all three land). Test LoC: ~200 (12–15 tests). This is well inside a single-Nutts budget and the items are tightly coupled (all touch picker/GameState).

**Fallback split (only if Eric actively wants parallelism):**
- **Nutts-A:** Carry-forward (§2.1, §2.2, §2.3) + their tests. Blocks nothing. Can start immediately.
- **Nutts-B:** Playtest-driven critical fixes (§3.2) + their tests. **Blocks on playtest completion** — spawn only after Eric's playtest notes land. If playtest is deferred per §3.3, Nutts-B doesn't spawn at all.

The fallback only pays off if Eric playtests mid-sprint instead of at the end. Default to single Nutts unless there's a reason to split.

---

## §8 Arc rollup deliverable (Specc owns, separate audit)

**Location:** `audits/battlebrotts-v2/v2-arc-13.x-rollup.md`
**Owner:** Specc (not Nutts, not Gizmo)
**Blocks on:** Sprint 13.10 merge (so the rollup reflects the closed arc).

**Required sections:**
1. **Arc summary** — one-paragraph recap of what Sprint 13.3 → 13.10 accomplished.
2. **Pillar progress** — for each game pillar, where did the arc move the needle? Explicit before/after.
3. **Process patterns codified this arc** — KB #68 (plan-time spec verification), KB #70 (merge-time CI), KB #72 (design-time noun verification). Short explainer of each and the incident that motivated it.
4. **Debt closed** — list items that entered the arc as debt and left resolved (e.g., S13.3 deferred opponent work → closed in S13.9; Boltz nits → closed in 13.10).
5. **Debt opened / carried** — honest accounting of what S13.x created or punted. Audio still parked. Counter-play tuning unsourced. Legacy `test_sprint2.gd` if not resolved in 13.10. Any criticals deferred to post-arc patch per §3.3.
6. **Carry-into S14** — prioritized list. Tuning pass informed by 13.10 playtest goes at the top.
7. **Retrospective notes** — what worked in this arc's process, what didn't. Candid.

**Not this sprint's problem, but:** Specc should start collecting material now so the rollup doesn't become a post-hoc fiction exercise after merge.

---

## Appendix — What success looks like

A wrap sprint succeeds when:
- The arc's loose ends are tied off (✅ carry-forward done).
- The game has been touched by a human and we know what it feels like (✅ playtest).
- We know what we're carrying into the next arc (✅ rollup).
- We resisted the urge to build anything new (✅ DO-NOT list held).

A wrap sprint fails when it turns into a stealth build sprint. Don't do that.
