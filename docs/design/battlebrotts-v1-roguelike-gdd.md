# BattleBrotts v1.0 — Roguelike GDD

**Status:** Awaiting HCD review on 7 open design questions (marked ⚠️)  
**Pivot source:** [`memory/2026-04-25-battlebrotts-v1-roguelike-pivot.md`](../../..) — locked 2026-04-25 04:22 UTC by HCD  
**Author:** Gizmo (design lead), spawned 2026-04-25 13:00 UTC  
**Replaces:** `docs/gdd.md` §6 League Structure — roguelike loop supersedes league climb. All other GDD sections (§3 Customization, §4 BrottBrain, §5 Combat, §8 Arena, §10 Art Direction) remain in force unless explicitly overridden here.

---

## The Core Truth

The fun is **watching battles happen**. The pull is **"I want to battle / try again."** Everything else is scaffolding. The roguelike framing serves this truth: every run is a fresh sequence of battles with a progressively wilder build. Short. Self-contained. Replayable.

---

## The Roguelike Loop (Locked)

```
Start Run
  → Player picks starter chassis (random 3-pick? or player choice — see §A.7)
  → Battle 1 → watch autobattle
      Win  → Pick 1 of 3 random reward items
      Lose → Spend a retry (3 total per run)
             Retry: restart this battle with current build (see §A.4)
  → Battle 2 → reward pick → ...
  → [Battles 3–14, same pattern]
  → Battle 15 → FINAL BOSS
      Win  → Run complete → win screen
      Lose → Retries or run ends
  → Run over → new run (fresh build, fresh encounter sequence)
```

Run length: **15 battles** (locking at upper end of the 10–15 range — HCD: "longer, or slightly longer").  
Total run time target: **30–50 minutes** at normal pace.  
4th loss (retries exhausted) = run ends immediately.

---

## Section A — Open Design Questions

### A.1 Final Boss Shape ⚠️

**Recommendation:** Fixed boss — a single handcrafted "Champion Brott" named **IRONCLAD PRIME** — Fortress chassis, max loadout (Railgun + Minigun, Ablative Shell, Shield Projector + Sensor Array + EMP Charge), bespoke BrottBrain with 8 Behavior Cards tuned to punish common player strategies.

**Why fixed:** Simple to build, no RNG in the most climactic moment, lets HCD tune it as a puzzle. The boss should feel *known* — players will talk about "beating IRONCLAD PRIME" not "beating a random boss." Personality > variety at the end of the run.

**Alternative:** Small pool of 3 bosses, randomly selected at run start — adds replayability at the cost of one sprint of extra work and the need to balance 3 distinct puzzles instead of 1.

---

### A.2 Run Difficulty Curve ⚠️

**Recommendation:** 4 difficulty tiers spread across 15 battles, using the existing `opponent_loadouts.gd` template pool (re-framed as an encounter pool, not a league ladder).

| Battles | Tier | Template pool | BrottBrain complexity |
|---------|------|---------------|----------------------|
| 1–3 | Tier 1 | `tank_tincan`, Scrapyard-legal pool | 0–1 Behavior Cards, single weapon |
| 4–7 | Tier 2 | Bronze-tier templates | 1–2 Behavior Cards, armor + 1 module |
| 8–11 | Tier 3 | Silver-tier templates | 3–4 Behavior Cards, full loadouts |
| 12–14 | Tier 4 | Silver-4 templates (Disruptor, Aegis, Chrono) | 5–6 Behavior Cards, counter-builds |
| 15 | Boss | IRONCLAD PRIME (or boss pool — see §A.1) | 8 Behavior Cards, max loadout |

**Key principle:** No stat inflation. Difficulty comes from harder BrottBrains and better loadouts, exactly as before — the same balance invariant from the original GDD §6.2 holds.

**Variety rule carries forward:** no two consecutive encounters share the same archetype (TANK/GLASS_CANNON/SKIRMISHER/BRUISER/CONTROLLER). State lives on `RunState._last_opponent_archetype` (new field on the new RunState; see §B).

**Alternative:** Purely random from the full pool each battle, letting difficulty vary wildly. Simpler code, but the ramp-up feel disappears — early battles can be unfair hard. Not recommended.

---

### A.3 Reward Pool Composition ⚠️

**Recommendation:** Tiered by run progress — same tier bands as the difficulty curve.

| Battles won | Legal reward items |
|-------------|-------------------|
| 1–3 | Tier 1–2 weapons, Plating/Reactive Mesh, Overclock/Repair Nanites/Sensor Array |
| 4–7 | + Tier 3 weapons (Flak Cannon, Arc Emitter), Shield Projector, Afterburner |
| 8–14 | Full item pool (Railgun, Missile Pod, Ablative Shell, EMP Charge) |
| Boss fight | No reward — run end |

**Why tiered:** Prevents first-battle Railgun pulls that skip the build arc. The power fantasy is building toward something — early rewards should feel like upgrades, not windfalls.

**Mechanics:** Present 3 random items from the legal pool (deduped against currently-owned items). Player picks 1. Unpicked options are discarded — no "bank" or "defer." If the player already owns all legal items in a tier, backfill from the tier below.

**Alternative:** Full item pool from battle 1. Simpler. Occasionally delightful (first-battle Railgun pick), occasionally feels unfair (Tier-4 enemy on battle 2). Post-1.0 candidate if the tiered approach feels too restrictive during playtesting.

---

### A.4 Retry Mechanic Specifics ⚠️

**Recommendation:** Retry restarts the **current battle only**, with the current build intact. No rewind to a prior battle. No item refund.

**Exact behavior:**
- Player loses the battle → "DEFEAT" flash → UI shows: retry count remaining (e.g., "2 retries left"), button "Retry Battle" vs "Accept Loss (run ends if 0 retries)"
- Retry: rematch against the same opponent template, same arena (re-rolled). Build is unchanged.
- After a retry win: battle counts as won — player gets the normal reward pick.
- When retries = 0 and the player loses: run ends immediately. No retry prompt.

**Why current-battle-only:** Simple to implement (reuse existing rematch flow). Rewind-to-prior-battle is more complex (must un-apply rewards) and potentially frustrating (losing two battles worth of progress). The player's build survives a retry, which is the meaningful form of "continuation."

**Note:** Retries are per-run, not per-battle. 3 retries is the total budget. A player who uses 2 retries on battle 7 has only 1 left for the rest of the run.

**Alternative:** Retry rewinds one full battle — lose the battle AND the previous reward pick. More punishing. Makes retry a heavier decision. Post-1.0 difficulty mode candidate.

---

### A.5 Run-End UX ⚠️

**Recommendation:** Two screens — Loss Screen and Win Screen — with a shared Build Summary component.

**Loss Screen ("BROTT DOWN"):**
```
╔═══════════════════════════════╗
║   💀 BROTT DOWN               ║
║   Fell at Battle [N] of 15    ║
║   ─────────────────────────── ║
║   YOUR BUILD                  ║
║   [Chassis icon]  [Weapon x2] ║
║   [Armor]  [Module x3]        ║
║   ─────────────────────────── ║
║   Battles Won: [N-1]          ║
║   Retries Used: [0-3]         ║
║   Farthest Threat: [name]     ║
║   ─────────────────────────── ║
║       [🔁 New Run]            ║
╚═══════════════════════════════╝
```

**Win Screen ("RUN COMPLETE"):**
```
╔═══════════════════════════════╗
║   🏆 RUN COMPLETE             ║
║   IRONCLAD PRIME defeated!    ║
║   ─────────────────────────── ║
║   YOUR BUILD                  ║
║   [full loadout display]      ║
║   ─────────────────────────── ║
║   Battles Won: 15 / 15        ║
║   Retries Used: [0-3]         ║
║   Best Kill: [name]           ║
║   ─────────────────────────── ║
║       [🔁 New Run]            ║
╚═══════════════════════════════╝
```

**Stats shown:** Battles won, retries used, farthest battle reached (loss) or full win flag. No elaborate stat tracking — just enough to tell the story of the run. No persistent leaderboard in v1.0.

**Single button:** "New Run" on both screens. No "Return to Menu." The loop is: play → result → play again.

**Alternative:** Show full battle log (who won each battle, what items were picked). More information, more screen complexity. Deferred to post-1.0 polish.

---

### A.6 Onboarding ⚠️

**Recommendation:** First-run contextual tooltips only. No tutorial battles, no forced teaching sequence.

**First run only (tracked by `first_run_state.gd`, already exists):**
1. **Run start screen:** One-sentence copy explaining the loop: *"Build your Brott. Battle 15 enemies. Die and you get 3 retries. Beat the boss to win the run."*
2. **First reward pick:** Tooltip overlay on the reward cards: *"Pick one — it's yours for this run."*
3. **First BrottBrain access:** If player opens the BrottBrain editor, tooltip: *"Drag cards to teach your Brott how to fight. It'll make its own decisions in battle."*
4. **First retry prompt:** Tooltip: *"You've got [N] retries left this run. Use one here, or accept the loss."*

**No league onboarding copy.** The S21.2–S21.4 HUD onboarding work (league-surface overlays, first-encounter tooltips, shop scroll nudges) is **cut**. The roguelike loop is self-explanatory enough with run-scoped context tooltips.

**Alternative:** Zero onboarding — just throw the player in. Battlebrotts is simple enough that this might work. Revisit after first playtest.

---

### A.7 Visual Identity for "This is a Run" ⚠️

**Recommendation:** Run HUD elements — persistent indicators that frame the run context while the player is mid-run.

**Run Status Bar (top of every non-arena screen during a run):**
```
[⚔️ Battle 6 of 15]  [💀 2 retries left]  [🔩 Build: Scout + Railgun + Ablative]
```
- Appears on: reward pick screen, BrottBrain editor, the "ready" screen before each battle
- Disappears on: loss screen, win screen, main menu
- Color shift: Battle counter turns amber at battle 12 (approaching boss zone), red at battle 14

**Run framing at menu:**
- Main menu shows "▶ Continue Run (Battle 6/15)" if a run is in progress — but note: v1.0 runs are **not persistent** (no save/resume). Once you close the browser tab, the run is gone. This button is for mid-session "go back to menu temporarily" only.

**Reward pick screen:** Background color shift per tier. Battles 1–3: grey-blue (salvage vibe). Battles 4–7: bronze tint. Battles 8–14: silver-white. Boss fight prep: red/gold.

**Why this works:** The run status bar is the single clearest signal. Players always know where they are. The background tinting adds atmosphere without requiring new art.

**Alternative:** No persistent run bar — just show a "Battle N / 15" label at the start of each arena match. Minimal. Works. But the player has no run-context between battles (during reward pick). Not recommended.

---

## Section B — Keep / Cut / Re-skin Code Inventory

### 🟩 KEEP

| System | File(s) | Rationale |
|--------|---------|-----------|
| **Battle engine** | `godot/arena/arena_renderer.gd`, `godot/arena/charm_anims.gd`, `godot/game/opponent_data.gd` | This IS the game. Polish target, not a cut candidate. |
| **Combat sim** | `godot/tests/combat_batch.gd`, `godot/tests/combat_batch_brain.gd` | Balance verification stays essential. |
| **Chassis system** | `godot/data/chassis_data.gd` | Scout / Brawler / Fortress archetypes unchanged. |
| **Weapon system** | `godot/data/weapon_data.gd` | Full weapon roster retained. |
| **Armor system** | `godot/data/armor_data.gd` | Full armor roster retained (league-degradation table becomes unused but harmless). |
| **Module system** | `godot/data/module_data.gd` | Full module roster retained. |
| **BrottBrain system** | `godot/ui/brottbrain_screen.gd` | The main player expression surface. Keep as-is; remove the "BrottBrain unlocks at Bronze" gate — it's always available from battle 1 in the roguelike. |
| **Behavior Cards** | All card data in `chassis_data.gd` / `brottbrain_screen.gd` | Keep all Trigger + Action cards. No cuts. |
| **Loadout display** | `godot/ui/loadout_screen.gd` | Becomes "Current Build" — minimal re-label, same data. |
| **Result screen** | `godot/ui/result_screen.gd` | Re-skin per §A.5 spec. Core structure (won/lost banner + continue button) stays; extend with build summary + run stats. |
| **Item data + token router** | `godot/data/item_tokens.gd` | Reward pick system will use this to grant items. |
| **Audio: SFX + menu music** | `godot/assets/audio/sfx/*`, `godot/assets/audio/music/menu_loop.ogg` | Menu loop applies to roguelike main menu. Hit/death/crit SFX stay. Win chime stays. |
| **BrottBrain Trick Choices** | `godot/ui/trick_choice_modal.gd`, `godot/data/trick_choices.gd` | These become **in-run random events** — a natural fit for the roguelike. Re-skin context copy, keep mechanic. |
| **Arena types** | Arena definitions (The Pit, Junkyard, Foundry) | All three arenas used as encounter rotation. Randomly assigned per battle. |
| **Main menu + settings** | `godot/ui/main_menu_screen.gd`, `godot/ui/mixer_settings_panel.gd` | Keep. Main menu needs minor run-framing additions (§A.7). Settings unchanged. |
| **Audio infrastructure** | `godot/tests/test_s21_5_*`, `test_s24_*` bus routing tests | Keep all audio tests — they verify infrastructure that doesn't change. |
| **Bot preview** | `godot/ui/bot_preview.gd` | Keep — used in loadout display and reward pick. |
| **`first_run_state.gd`** | `godot/ui/first_run_state.gd` | Keep — drives first-run tooltip logic (§A.6). |
| **Test infrastructure** | `godot/tests/test_runner.gd`, `test_util.gd`, `pacing_verify.gd` | All test infra kept. |

---

### 🟥 CUT

| System | File(s) | Rationale |
|--------|---------|-----------|
| **League Complete Modal** | `godot/ui/league_complete_modal.gd`, `godot/ui/league_complete_modal.tscn` | No leagues. Cut. |
| **Opponent Select Screen** | `godot/ui/opponent_select_screen.gd` | Opponents are served by the run engine, not player-selected. Cut. |
| **League progression logic** | `GameState._check_progression()`, `advance_league()`, `bronze_unlocked`, `silver_unlocked`, all `opponents_beaten` / `first_wins` logic | Replace with run-lifecycle methods on new `RunState`. |
| **Economy (Bolts / shop purchases)** | `GameState.buy_*()`, `WEAPON_PRICES`, `ARMOR_PRICES`, `MODULE_PRICES`, `CHASSIS_PRICES`, `bolts` field | No shop in v1.0 roguelike. Items come from reward picks, not purchase. |
| **Repair cost system** | `apply_match_result()` repair cost logic | No repair in roguelike. Win = reward pick. Lose = retry spend. |
| **Shop screen** | `godot/ui/shop_screen.gd` | No shop. Cut. (Item grant / trick system still exists but is not a purchasable storefront.) |
| **HUD onboarding (S21.2–S21.4)** | `godot/tests/test_s21_2_*`, `test_s21_4_*` — specifically league-surface and first-encounter overlays | League-surface tooltips, scroll-nudges, inline captions: cut. First-run state infra (`first_run_state.gd`) is kept; only the league-specific tooltip content is removed. |
| **League-degradation table** | `ArmorData.REFLECT_DAMAGE_BY_LEAGUE`, `reflect_damage_for_league()` | No leagues. Can be stripped or left dormant. Lean toward stripping to reduce confusion. |
| **BrottBrain unlock gate** | `GameState.brottbrain_unlocked`, `go_to_brottbrain()` unlock check in `game_flow.gd` | BrottBrain is always available from battle 1. Remove the gate entirely. |
| **Arc C narrative beats** | Any narrative beat copy, modal scripts, or event popups tied to league transitions | Cut. HCD confirmed: "cut regardless of design." |
| **Sentinel feature (Arc D)** | Any Arc D sentinel-related code if committed | Cut — does not serve the roguelike's battle-focused loop. |
| **`first_wins` bonus system** | `GameState.first_wins[]`, first-win bolt bonus logic | No economy. Cut. |
| **Multi-format matches (2v2, 3v3)** | `GameState` / `GameFlow` logic for team matches | v1.0 is 1v1 only. Cut the team format code. |

---

### 🟨 RE-SKIN

| System | Current | Becomes | Files to modify |
|--------|---------|---------|-----------------|
| **`opponent_loadouts.gd`** | League-gated template pool, `difficulty_for(league, index)` | **Run encounter pool** — `difficulty_for(battle_index)` maps battle 1–15 to tiers 1–4 (see §A.2). Remove `unlock_league` filter; add `battle_index_to_tier()` helper. | `godot/data/opponent_loadouts.gd` |
| **`GameState`** | Tracks bolts, owned items, league progression | **RunState (rename/replace)** — tracks current build (chassis + equipped items), retry count, battles won, current battle index. No economy. | `godot/game/game_state.gd` → `run_state.gd` |
| **`GameFlow`** | Menu → Shop → Loadout → BrottBrain → OpponentSelect → Arena → Result | **Run flow**: Menu → RunStart (chassis pick) → [RewardPick → BrottBrain? → Arena] × 15 → BossArena → RunEnd | `godot/game/game_flow.gd` |
| **`ResultScreen`** | "VICTORY / DEFEAT" + bolts earned | Per §A.5 — "BROTT DOWN / RUN COMPLETE" with build summary + run stats. Same file, significant copy/data changes. | `godot/ui/result_screen.gd` |
| **`MainMenuScreen`** | Title + New Game | + Run Status Bar (§A.7) + "Continue Run" (mid-session only) | `godot/ui/main_menu_screen.gd` |
| **Trick Choice Modal** | Scrapyard-only event; bolts/HP/item effects | **In-run random event** — fires occasionally between battles (every 3–4 battles, random). Same mechanic, same BrottBrain voice. Re-frame copy from "Scrapyard" to run context. | `godot/ui/trick_choice_modal.gd`, `godot/data/trick_choices.gd` — copy only |
| **`LoadoutScreen`** | Full inventory management + purchase flow | **Current Build display** — read-only view of current run loadout. No buy button. Equip/unequip still works (player can rearrange what they have). | `godot/ui/loadout_screen.gd` |
| **Reward Pick** | Does not exist (was shop) | **New screen: `reward_pick_screen.gd`** — presents 3 random items post-battle-win, player picks 1, item is immediately added to build. Uses `item_tokens.gd` for resolution. | NEW: `godot/ui/reward_pick_screen.gd` |
| **Run Start** | Does not exist (was "New Game → Shop") | **New screen: `run_start_screen.gd`** — picks starter chassis, shows first-run tooltip (§A.6). May offer a random 3-chassis pick (⚠️ design question embedded in §A.7 starter pick). | NEW: `godot/ui/run_start_screen.gd` |

---

## Section C — Roadmap Proposal

### Arc F — Roguelike Core Loop (Target: ~6–8 sub-sprints)

**Goal:** Wire the complete roguelike run loop end-to-end — run start → battles → reward pick → boss → run end screens. The full flow should be playable with no dead ends.

**Sub-sprint estimate:** 6–8 (new screens + flow rewire + RunState + encounter pool)

**Hard exit criteria:**
1. Player can start a run, battle through all 15 encounters, and reach the boss
2. Reward pick screen works — 3 items shown, 1 selected, immediately applied to build
3. Retry mechanic works — 3 retries tracked, run ends on 4th loss
4. Run end screens (loss + win) display correctly with build summary
5. `combat_batch.gd` simulations pass at >0% (engine still functional)
6. No regressions on existing arena / combat tests

**Key dependencies:**
- HCD approves §A.1–A.7 design questions before Arc F starts
- IRONCLAD PRIME boss loadout + BrottBrain authored (can be simple first pass)

---

### Arc G — Cut Pass (Target: ~3–4 sub-sprints)

**Goal:** Remove all dead code from the league-campaign era — shop, league progression, economy, opponent-select screen, narrative beats — leaving a clean codebase that only contains what the roguelike needs.

**Sub-sprint estimate:** 3–4 (systematic file deletions + test suite cleanup)

**Hard exit criteria:**
1. No references to `current_league`, `bronze_unlocked`, `opponents_beaten`, `bolts` in the active codebase (or they're harmlessly dormant and explicitly tagged `// DEPRECATED`)
2. All deleted files removed from CI test matrix — no test failures from missing files
3. `LeagueCompleteModal`, `OpponentSelectScreen`, `ShopScreen` scenes/scripts deleted
4. Combat simulations still pass

**Key dependencies:** Arc F complete (avoids cutting things that Arc F still references mid-build)

---

### Arc H — Boss + Run Polish (Target: ~4–5 sub-sprints)

**Goal:** IRONCLAD PRIME boss tuned to be a satisfying climax; visual run identity (§A.7) polished; first-playtest-ready build.

**Sub-sprint estimate:** 4–5

**Hard exit criteria:**
1. Boss is beatable but challenging — target <40% first-attempt win rate in combat sim at Tier-3 average player build
2. Run HUD bar (battle counter + retry indicator) visible and correct on all non-arena screens
3. Background tinting per tier band implemented
4. First-run tooltip flow works (§A.6)
5. HCD playtests the full run and signs off

**Key dependencies:** Arc F core loop complete; HCD available for playtest at arc close

---

### Arc I — Ship (Target: ~2–3 sub-sprints)

**Goal:** Final CI/deploy cleanup, performance verification, browser-export polish. Ship v1.0.

**Sub-sprint estimate:** 2–3

**Hard exit criteria:**
1. HTML5 export loads in <5s on a mid-range device
2. All CI tests green
3. No known P0/P1 bugs
4. HCD final sign-off

**Key dependencies:** Arc H complete + HCD playtest pass

---

**Total pipeline estimate:** ~15–20 sub-sprints, ~2 weeks of pipeline clock time.

---

## Section D — Anti-Scope-Creep Guardrails

If any of the following tripwires fires during Arcs F–I, Riv **must escalate to The Bott** before proceeding. No agent may self-authorize work that crosses a tripwire.

**Tripwire 1: No new items or weapons.**  
The existing item roster (7 weapons, 3 armors, 6 modules) is the v1.0 set. If any sprint plan proposes adding a new item type, new weapon, new chassis variant, or new module → STOP. Escalate.

**Tripwire 2: No meta-progression.**  
No persistent unlock trees, no "earned items carry across runs," no experience points, no persistent currency, no unlockable starting configurations. If any feature requires data that survives between runs → STOP. Escalate. (HCD locked this explicitly: "no, too complex.")

**Tripwire 3: No narrative content.**  
No cutscenes, no story beats, no opponent backstories, no dialogue beyond BrottBrain voice in trick events. If any sprint plan includes copy that advances a story → STOP. Escalate. (HCD locked: "cut regardless of design.")

**Tripwire 4: No new opponent archetypes or roster expansion.**  
The 19-template encounter pool is sufficient for v1.0. Difficulty comes from tier progression and BrottBrain complexity, not from new templates. If a sprint proposes a new opponent template beyond IRONCLAD PRIME → STOP. Escalate.

**Tripwire 5: No team formats.**  
v1.0 is 1v1 only. If any feature touches 2v2 or 3v3 logic → STOP. Escalate.

---

## Appendix: Files Touched by the Pivot (Quick Reference)

| Action | Files |
|--------|-------|
| Delete | `godot/ui/league_complete_modal.gd`, `league_complete_modal.tscn`, `opponent_select_screen.gd`, `shop_screen.gd` |
| Major rework | `godot/game/game_state.gd` → `run_state.gd`, `godot/game/game_flow.gd`, `godot/data/opponent_loadouts.gd`, `godot/ui/result_screen.gd` |
| New files | `godot/ui/reward_pick_screen.gd`, `godot/ui/run_start_screen.gd` |
| Minor rework | `godot/ui/main_menu_screen.gd`, `godot/ui/loadout_screen.gd`, `godot/ui/brottbrain_screen.gd` (remove BrottBrain unlock gate) |
| Likely delete (test cleanup) | `godot/tests/test_s21_2_*`, `test_s21_4_003_league_surface.gd` |
| Keep untouched | All arena, combat engine, BrottBrain card, audio, chassis/weapon/armor/module data files |

---

*This GDD is the design input for Arc F. HCD approves the 7 open design questions (§A.1–A.7), then Arc F planning begins.*
