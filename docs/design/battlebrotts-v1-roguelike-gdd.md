# BattleBrotts v1.0 — Roguelike GDD v2

**Status:** HCD decisions incorporated. Ready for greenlight review.  
**v2 revision:** 2026-04-25 ~16:26 UTC — incorporating HCD decisions from addendum  
**Pivot source:** [`memory/2026-04-25-battlebrotts-v1-roguelike-pivot.md`](../../..) — locked 2026-04-25 04:22 UTC by HCD  
_HCD decisions: see `memory/2026-04-25-hcd-decisions-on-gdd-v1.md`_  
**Author:** Gizmo (design lead)  
**Replaces:** `docs/gdd.md` §6 League Structure — roguelike loop supersedes league climb. All other GDD sections (§3 Customization, §5 Combat, §8 Arena, §10 Art Direction) remain in force unless explicitly overridden here. §4 BrottBrain is **superseded entirely** — see §A.8.

---

## The Core Truth

The fun is **watching battles happen**. The pull is **"I want to battle / try again."** Everything else is scaffolding. The roguelike framing serves this truth: every run is a fresh sequence of battles with a progressively wilder build. Short. Self-contained. Replayable.

---

## The Roguelike Loop (Locked)

```
Start Run
  → Player picks starter chassis (random 3-pick — see §A.7)
  → Battle 1 → watch autobattle (player can click to direct — see §A.8)
      Win  → Pick 1 of 3 random reward items
      Lose → Spend a retry (3 total per run)
             Retry: restart this battle with current build (see §A.4)
  → Battle 2 → reward pick → ...
  → [Battles 3–14, same pattern — encounter shapes vary per §A.9]
  → Battle 15 → FINAL BOSS (CEO Brott)
      Win  → Run complete → win screen
      Lose → Retries or run ends
  → Run over → new run (fresh build, fresh encounter sequence)
```

Run length: **15 battles** (locking at upper end of the 10–15 range — HCD: "longer, or slightly longer").  
Total run time target: **30–50 minutes** at normal pace.  
4th loss (retries exhausted) = run ends immediately.

---

## Section A — Design Decisions

### A.1 Final Boss Shape
_Locked by HCD 2026-04-25_

**Decision:** Fixed boss — a single handcrafted "Champion Brott" named **CEO Brott** (locked by HCD 2026-04-25 17:07 UTC) — Fortress chassis, max loadout (Railgun + Minigun, Ablative Shell, Shield Projector + Sensor Array + EMP Charge), hardcoded baseline AI (see §A.8) tuned to punish common player strategies. Visual identity: tiny corporate tie on the Fortress chassis (Arc H polish item).

**Naming convention (NEW — locked by HCD 2026-04-25 17:09 UTC):** All 15 opponents in a run use **corporate-ladder titles**, scaled to tier:
- Tier 1 (battles 1–3): Junior / Intern / Associate (e.g., "Junior Associate Brott", "Intern Brott")
- Tier 2 (battles 4–7): Mid-management / Specialist (e.g., "Brott from Accounting", "Senior Specialist Brott")
- Tier 3 (battles 8–11): Director / VP (e.g., "Director of Operations Brott", "VP of Engineering Brott")
- Tier 4 (battles 12–14): C-suite / Executive (e.g., "CFO Brott", "COO Brott", "Chief Strategy Brott")
- Battle 15: **CEO Brott** (always)

Gizmo to produce a corporate-ladder title library (~15–25 titles) at S25.4 (encounter pool re-skin), mapped to (tier, archetype). Titles should lean into archetype flavor — e.g., Glass-Cannon Blitz at Tier 3 → "VP of Aggressive Sales Brott"; Mini-Boss + Escorts at Tier 4 → "CFO Brott + 2 Auditors". This makes the run feel like a labor-ladder revenge fantasy in tone, without committing to explicit narrative beats.

**Why fixed:** Simple to build, no RNG in the most climactic moment, lets HCD tune it as a puzzle. The boss should feel *known* — players will talk about "beating [the boss]" not "beating a random boss." Personality > variety at the end of the run.

**Boss AI behavior (hardcoded rules):**  
Kites low-HP players. Fires EMP when player's modules are active. Engages aggressively at full health, switches to shield-projection when below 40%. Prioritizes distance management — never lets the player dictate the range. Multi-target rules do not apply (1v1 encounter only).

**Name TBD:** HCD to workshop the boss name. Design structure is locked; only the name is pending.

---

### A.2 Run Difficulty Curve
_Locked by HCD 2026-04-25 (expanded from v1 recommendation to incorporate encounter shapes; further refined 2026-04-25 16:40 UTC: shape decoupled from difficulty)_

**Decision:** 4 difficulty tiers spread across 15 battles. **Difficulty (stats / loadout / AI quality) tracks tiers; encounter shape varies freely from Tier 1 onward.** Any archetype can appear in any tier as long as the constituent opponents are scaled to the tier's difficulty band. A Small Swarm in Tier 1 is just three *weak* bots; the shape doesn't carry the difficulty.

**Refinement vs the v2 first pass (2026-04-25 16:40 UTC HCD note):** Earlier draft over-weighted Standard Duel in Tier 1 (80%) on the assumption that swarm shapes were inherently harder. They aren't — a swarm is only as hard as the bots in it. Shape variety is a player-experience lever; difficulty is a separate stat-and-AI lever. They should be tuned independently.

| Battles | Tier | Encounter archetype distribution | Opponent loadout tier |
|---------|------|----------------------------------|----------------------|
| 1–3 | Tier 1 | Free shape mix (any archetype except Boss). Suggested seed: ~40% Standard Duel / ~25% Small Swarm / ~15% Glass-Cannon Blitz / ~10% Large Swarm / ~10% Mini-boss+Escorts | Single-weapon, 0–1 modules; opponents in swarms are individually weak |
| 4–7 | Tier 2 | Free shape mix; ~30% Standard Duel / balance across other archetypes | Full weapon + armor + 1–2 modules |
| 8–11 | Tier 3 | Free shape mix; introduce Counter-Build Elite | Full loadouts, counter-tuned |
| 12–14 | Tier 4 | Free shape mix; weighted toward Counter-Build Elite + Large Swarm + Mini-boss+Escorts for climactic feel | Silver-tier templates, Disruptor/Aegis/Chrono builds |
| 15 | Boss | CEO Brott (always) | Max loadout, hardcoded boss AI |

The distributions above are *seeds* for the encounter generator, not hard quotas. Final tuning happens during Arc F + Arc H playtesting.

**Key principle:** No stat inflation. Difficulty comes from opponent loadout strength + AI behavior quality + encounter density (a swarm of T2 bots is harder than a swarm of T1 bots, not because the *shape* changed but because the bots got stronger). The balance invariant holds.

**Variety rule:** No two consecutive encounters may share the same archetype. State tracked on `RunState._last_encounter_archetype` (new field). If the archetype picker would repeat, re-roll once.

**Run guarantee:** Each run guarantees at least one occurrence of: Small Swarm, Counter-Build Elite, and Mini-boss+Escorts (the three most tactically novel archetypes). Seeded into slots 5, 9, 12 at run generation, then shuffled within-tier constraints.

**Multi-target implication:** The hardcoded baseline AI (§A.8) must handle swarm and escort encounters from battle 1 onward. Bot behavior in multi-target fights uses the priority system defined in §A.8. Renderer must support multi-bot from Arc F's earliest sub-sprints, not as a Tier-3 add.

---

### A.3 Reward Pool Composition
_Locked by HCD 2026-04-25 — **UNTIERED** (overrides Gizmo v1 tiered recommendation)_

**Decision:** Full item pool available from battle 1. No tier gates on rewards.

**Rationale (HCD):** Windfall delight over tiered build-arc feel. A first-battle Railgun pull is exciting, not unfair — the player still has to win 14 more battles with whatever they've assembled.

**Mechanics:** Present 3 random items from the full legal pool (deduped against currently-owned items). Player picks 1. Unpicked options discarded — no bank, no defer. If the player owns all items, backfill with a random item they already own (displayed as "Duplicate — spare parts" with no effect; a graceful edge case for long runs).

**Swarm encounter rule:** "Battle won" = all enemies in the encounter are defeated. One reward pick per encounter regardless of encounter shape. Killing 3 swarm bots = one pick, not three.

**Post-1.0 note:** If playtesting shows early-windfall creates trivially easy runs (Railgun on battle 1 makes everything face-rollable), revisit tiering then — not now. HCD locked this; don't second-guess it pre-playtest.

---

### A.4 Retry Mechanic Specifics
_Locked by HCD 2026-04-25_

**Decision:** Retry restarts the **current battle only**, with the current build intact. No rewind. No item refund.

**Exact behavior:**
- Player loses the battle → "DEFEAT" flash → UI shows: retry count remaining (e.g., "2 retries left"), button "Retry Battle" vs "Accept Loss (run ends if 0 retries)"
- Retry: rematch against the same opponent template, same encounter shape, new arena seed. Build is unchanged.
- After a retry win: battle counts as won — player gets the normal reward pick.
- When retries = 0 and the player loses: run ends immediately. No retry prompt.

**Note:** Retries are per-run, not per-battle. A player who burns 2 retries on battle 7 has 1 left for the rest of the run.

---

### A.5 Run-End UX
_Locked by HCD 2026-04-25_

**Decision:** Two screens — Loss Screen ("BROTT DOWN") and Win Screen ("RUN COMPLETE") — with shared Build Summary component. Single "New Run" button on both.

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
║   CEO Brott defeated!         ║
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

**Stats shown:** Battles won, retries used, farthest battle reached (loss) or full win flag. No persistent leaderboard in v1.0. Single "New Run" button on both — no "Return to Menu."

---

### A.6 Onboarding
_Locked by HCD 2026-04-25 — cuts S21.2–S21.4 entirely_

**Decision:** First-run contextual tooltips only. No tutorial battles. No forced teaching sequence.

**First run only (tracked by `first_run_state.gd`):**
1. **Run start screen:** *"Build your Brott. Battle 15 enemies. Die and you get 3 retries. Beat the boss to win the run."*
2. **First battle (before round starts):** *"Click the arena to send your Brott somewhere. Click an enemy to target them. Or just watch — it'll fight on its own."*
3. **First reward pick:** Tooltip overlay on the reward cards: *"Pick one — it's yours for this run."*
4. **First retry prompt:** *"You've got [N] retries left this run. Use one here, or accept the loss."*

**No BrottBrain editor tooltip** — the editor is cut. No mention of cards, programming, or BrottBrain as a player-facing concept.

**No league onboarding copy.** S21.2–S21.4 HUD onboarding work is cut entirely.

---

### A.7 Visual Identity for "This is a Run"
_Locked by HCD 2026-04-25_

**Decision:** Run HUD elements — persistent indicators that frame the run context while the player is mid-run.

**Run Status Bar (top of every non-arena screen during a run):**
```
[⚔️ Battle 6 of 15]  [💀 2 retries left]  [🔩 Build: Scout + Railgun + Ablative]
```
- Appears on: reward pick screen, run start screen, the "ready" screen before each battle
- Disappears on: loss screen, win screen, main menu
- Color shift: Battle counter turns amber at battle 12 (approaching boss zone), red at battle 14

**Reward pick screen:** Background color shift per tier. Battles 1–3: grey-blue (salvage vibe). Battles 4–7: bronze tint. Battles 8–14: silver-white. Boss fight prep: red/gold.

**Main menu:** Shows "▶ Continue Run (Battle 6/15)" if a run is in progress mid-session. Note: v1.0 runs are **not persistent** (no save/resume across sessions). In-session only.

---

### A.8 Bot Arena Control Scheme & Baseline AI
_Q2 — Locked by HCD 2026-04-25 — **replaces BrottBrain editor entirely**_

**Decision:** Bot Arena two-click control during battle. BrottBrain editor is cut in full. The bot fights autonomously via hardcoded baseline AI; the player has exactly two direct intervention affordances.

#### Two-click affordances

**Click 1 — Click-to-Move:** Click anywhere on the arena floor → player bot navigates to that point. Once at the waypoint, bot resumes autonomous behavior (engage nearest enemy, apply baseline AI rules).

**Click 2 — Click-to-Target:** Click on an enemy bot → that enemy becomes the forced target. Bot fights autonomously against it until the target dies or the player issues a new override.

Player can intervene at any time or sit back entirely and watch autonomous combat. The two affordances correspond exactly to the two interventions a player naturally wants: *"go over there"* and *"shoot that one."* In swarm encounters, click-to-target becomes a genuine tactical decision (prioritize escorts or boss?). The scheme holds cleanly at 1v1, 1v3, and 1v8.

#### Q2-derivative design decisions (all resolved)

| # | Question | Decision |
|---|---|---|
| 1 | Click-to-move duration | Bot moves to waypoint then resumes autonomous. No timer. Override ends on arrival. |
| 2 | Click-to-target duration | Until target dies OR player issues a new move or target override. |
| 3 | Visual feedback | **Waypoint:** yellow diamond marker at clicked floor position, fades on arrival. **Target:** orange reticle ring on targeted enemy, persists while override active. **Bot state:** pulsing outline on player bot during any active override (yellow = moving, orange = targeting). |
| 4 | Module triggering | **Auto-fired by baseline AI.** Repair Nanites fire at <30% HP. EMP fires when enemy is within 3 tiles. Afterburner fires when HP <40% and enemy is adjacent. No player-facing module buttons. Simplest viable. |
| 5 | Click rate-limit | **Unlimited.** No cooldown. Rapid clicks = player engaged and tactics. Never punish engagement. |
| 6 | Click priority hierarchy | **Latest click wins entirely.** No queue. New click immediately cancels prior override and executes. If you click move mid-target-override, bot abandons target and moves. If you click target mid-move, bot stops and targets. Clean, instant, no ambiguity. |

#### Hardcoded baseline AI behavior

The BrottBrain *runtime* concept is preserved — bots still have internal AI making decisions — but the card-driven system is replaced with hardcoded rules. The player cannot modify these rules.

**Default engagement loop:**
1. Identify closest enemy within attack range → attack
2. If no enemy in range → advance toward nearest enemy
3. If HP < 40% and enemy is melee range → attempt to create distance (kite)
4. Apply module auto-fire rules (see above)

**Multi-target priority (swarm/escort encounters):**
- Default: attack nearest enemy
- If an enemy is within melee range of the player bot, it becomes the priority target (override nearest rule)
- If two enemies are equidistant, attack the lower-HP one (focus-fire the weakest)
- Player click-to-target overrides all priority rules for the duration of the override

**Boss AI (CEO Brott):** Separate hardcoded behavior set — see §A.1. Does not share baseline AI rules.

#### What is cut

The BrottBrain editor (card-based visual editor) is **cut entirely**. No drag-and-drop, no Trigger/Action cards, no 8-slot system, no BrottBrain unlock gate, no BrottBrain editor onboarding tooltips. The word "BrottBrain" does not appear in any player-facing UI.

The underlying `brottbrain.gd` class is **re-implemented** as a hardcoded baseline AI engine (same class name, same interface, different internals). See Section B for full cut/re-skin inventory.

---

### A.9 Encounter Shape Library
_NEW — Locked by HCD 2026-04-25 ("anything is fair game for Gizmo to design")_

Encounters are no longer exclusively 1v1. Seven encounter archetypes form the shape vocabulary for all 15 battles. Each archetype has distinct tactical characteristics, implementation requirements, and a defined place in the tier distribution (§A.2).

---

#### Archetype 1: Standard Duel
**Format:** 1 vs 1  
**Example composition:** Player Brott vs one opponent template (tier-matched)  
**What makes it distinctive:** The baseline. No multi-target complexity. Pure 1v1 combat performance — loadout vs loadout, AI vs AI (with player click-to-target intervention).  
**Design intent:** Establish baseline difficulty. Comfortable early on; by Tier 4, the Tier-4 opponent is a genuine threat even 1v1. Common but not dominant in Tier 1 — shape variety is an early-run lever, not just a late-run reward.

---

#### Archetype 2: Small Swarm
**Format:** 1 vs 3  
**Example composition:** Player vs 3 Scout-class bots, each at ~45% normal HP (individual threat low, collective DPS moderate)  
**What makes it distinctive:** First encounter with multi-target combat. Click-to-target becomes a real decision — pick the nearest flanker, the one that's low, or the one that's kiting you. Baseline AI prioritizes nearest; player can override.  
**Design intent:** Introduce multi-target mechanics gently. The swarm is beatable by watching the AI handle it, but optimal play (target the weakest first, avoid letting them surround) rewards engagement. Three enemies die in roughly 3 distinct phases.

---

#### Archetype 3: Large Swarm
**Format:** 1 vs 5–6  
**Example composition:** Player vs 5 Micro-Scout-class bots, each at ~20% normal HP (individually trivial, collectively lethal if ignored)  
**What makes it distinctive:** Pure chaos. The arena is full of bots. Click-to-target matters a lot here — the baseline AI will pick off bots one at a time; good targeting focuses the weakest cluster to prevent being surrounded. Audio is a stress test (lots of hit SFX). Visually overwhelming by design.  
**Design intent:** Peak variety encounter. Short but intense. Should feel like a "holy shit" moment. Can appear from Tier 1 onward; difficulty is governed by the per-bot loadout tier (a Tier-1 Large Swarm is six *very* weak bots), not by gating the shape itself.

---

#### Archetype 4: Mini-Boss + Escorts
**Format:** 1 vs 1 (strong) + 2 (weak)  
**Example composition:** Player vs one Fortress-class bot at ~130% normal HP + 2 Scout flankers at ~60% normal HP  
**What makes it distinctive:** Forces a target priority decision with real consequences. Kill escorts first (remove flanking pressure, then 1v1 the Fortress) or burn down the Fortress fast (ignore escorts' chip damage). Neither is obviously correct — depends on player build. Click-to-target is the key skill expression.  
**Design intent:** The tactically richest standard encounter. Tests whether the player is engaged or just watching. The "correct" priority depends on the player's chassis and loadout, creating implicit build-narrative moments.

---

#### Archetype 5: Counter-Build Elite
**Format:** 1 vs 1 (hand-tuned)  
**Example composition:** Player vs one hand-authored opponent designed to punish the most common player build strategies:
- *Anti-Range Elite:* Fortress chassis, EMP Charge + high mobility module — punishes players sitting at range with Railgun/Missile Pod
- *Anti-Melee Elite:* Scout chassis, Afterburner + Sensor Array — punishes players rushing in with Shotgun/Flak Cannon
- *Anti-Module Elite:* EMP-heavy Brawler that strips modules aggressively  

At encounter generation time, the system picks the elite type that counters the player's current build. If no strong counter exists (player build is balanced), pick Anti-Range as default.  
**What makes it distinctive:** It "knows" your build. Players will feel targeted — in a fun way. Teaches that no build is perfectly universal.  
**Design intent:** Pressure-test the player's adaptation reflex. The encounter is beatable even by the "wrong" build if the player uses click-to-target intelligently (kite, control range, pick off before the counter advantage kicks in).

---

#### Archetype 6: Glass-Cannon Blitz
**Format:** 1 vs 1 (fragile / high offense)  
**Example composition:** Player vs Scout chassis, 2 weapons (Flak Cannon + Arc Emitter), no armor, no modules — maximum DPS, paper-thin HP (≈40% normal HP)  
**What makes it distinctive:** An all-or-nothing opponent. If left to fire freely for 10 seconds, it shreds. But it dies extremely fast. Tests the player's ability to immediately engage (click-to-target + click-to-advance) rather than letting the AI manage pace. Opposite feel from a Fortress duel.  
**Design intent:** Introduce time pressure. Great for mid-Tier variety (Tier 2–4). Rewards an aggressive approach. Very satisfying kill once the player learns "go at it immediately."

---

#### Archetype 7: Boss
**Format:** 1 vs 1 (CEO Brott)  
**Example composition:** Fortress chassis, Railgun + Minigun, Ablative Shell, Shield Projector + Sensor Array + EMP Charge. Hardcoded boss AI (§A.1).  
**What makes it distinctive:** The climax. Always battle 15. Always this opponent. Hand-tuned to be hard but fair at a median run build (target: <40% first-attempt win rate at Tier-3 average build in combat sim).  
**Design intent:** The conversation-worthy moment. "I finally beat [boss name]" is the loop closer. Players should feel they earned it.

---

**Archetype implementation checklist (for Arc F planning):**

| Archetype | Arena renderer changes | Baseline AI changes | Data requirements |
|---|---|---|---|
| Standard Duel | None (existing 1v1) | None | None |
| Small Swarm | Render 3 enemy bots | Multi-target priority rules | 3x lightweight templates |
| Large Swarm | Render 5–6 enemy bots | Same as swarm, optimized for density | 5–6x micro templates |
| Mini-boss + Escorts | Render 3 enemy bots, mixed chassis sizes | Multi-target priority (distinguish escort vs boss) | 1x Fortress template, 2x Scout templates |
| Counter-Build Elite | None (1v1 renderer) | None (hardcoded opponent AI) | 3 authored elite loadouts |
| Glass-Cannon Blitz | None (1v1 renderer) | None | 1 authored loadout |
| Boss | None (1v1 renderer) | Boss-specific hardcoded rules | 1 authored boss loadout |

Multi-target archetypes (Swarms, Mini-boss) require arena renderer extension (§B Re-skin) and multi-target baseline AI (§A.8). These are the core new implementation work in Arc F.

---

## Section B — Keep / Cut / Re-skin Code Inventory

### 🟩 KEEP

| System | File(s) | Rationale |
|--------|---------|-----------|
| **Battle engine** | `godot/arena/arena_renderer.gd`, `godot/arena/charm_anims.gd`, `godot/game/opponent_data.gd` | This IS the game. Polish target. |
| **Combat sim** | `godot/tests/combat_batch.gd`, `godot/tests/combat_batch_brain.gd` | Balance verification stays essential. Update to support multi-target encounters. |
| **Chassis system** | `godot/data/chassis_data.gd` | Scout / Brawler / Fortress archetypes unchanged. |
| **Weapon system** | `godot/data/weapon_data.gd` | Full weapon roster retained. |
| **Armor system** | `godot/data/armor_data.gd` | Full armor roster retained (league-degradation table becomes unused but harmless). |
| **Module system** | `godot/data/module_data.gd` | Full module roster retained. |
| **Loadout display** | `godot/ui/loadout_screen.gd` | Becomes "Current Build" — minimal re-label, same data. |
| **Result screen** | `godot/ui/result_screen.gd` | Re-skin per §A.5 spec. Core structure stays; extend with build summary + run stats. |
| **Item data + token router** | `godot/data/item_tokens.gd` | Reward pick system will use this to grant items. |
| **Audio: SFX + menu music** | `godot/assets/audio/sfx/*`, `godot/assets/audio/music/menu_loop.ogg` | Menu loop applies to roguelike main menu. All combat SFX stay. |
| **BrottBrain Trick Choices** | `godot/ui/trick_choice_modal.gd`, `godot/data/trick_choices.gd` | In-run random events — natural roguelike fit. Re-skin context copy, keep mechanic. |
| **Arena types** | Arena definitions (The Pit, Junkyard, Foundry) | All three arenas used as encounter rotation. Randomly assigned per battle. |
| **Main menu + settings** | `godot/ui/main_menu_screen.gd`, `godot/ui/mixer_settings_panel.gd` | Keep. Main menu needs minor run-framing additions (§A.7). |
| **Bot preview** | `godot/ui/bot_preview.gd` | Keep — used in loadout display and reward pick. |
| **`first_run_state.gd`** | `godot/ui/first_run_state.gd` | Keep — drives first-run tooltip logic (§A.6). |
| **Test infrastructure** | `godot/tests/test_runner.gd`, `test_util.gd`, `pacing_verify.gd` | All test infra kept. |
| **Opponent template data** | `godot/data/opponent_loadouts.gd` (data only) | Re-skinned (see below) — template records kept, league indexing replaced. |

---

### 🟥 CUT

| System | File(s) | Rationale |
|--------|---------|-----------|
| **BrottBrain editor screen** | `godot/ui/brottbrain_screen.gd` + all associated `.tscn` scenes | Editor cut in full. Replaced by hardcoded baseline AI. No player-facing editor. |
| **BrottBrain unlock gate** | `GameState.brottbrain_unlocked`, unlock check in `game_flow.gd` | Editor doesn't exist. Gate is moot. Remove. |
| **Behavior Card content** | All Trigger/Action card definitions in `brottbrain_screen.gd` `TRIGGER_DISPLAY` / `ACTION_DISPLAY` tables | No longer player-facing. Cut as UI content. Underlying `BrottBrain.Trigger` / `Action` enums may be repurposed or deleted. |
| **League Complete Modal** | `godot/ui/league_complete_modal.gd`, `.tscn` | No leagues. Cut. |
| **Opponent Select Screen** | `godot/ui/opponent_select_screen.gd` | Opponents served by run engine, not player-selected. Cut. |
| **League progression logic** | `GameState._check_progression()`, `advance_league()`, `bronze_unlocked`, `silver_unlocked`, `opponents_beaten`, `first_wins` | Replace with run-lifecycle on new `RunState`. |
| **Economy (Bolts / shop)** | `GameState.buy_*()`, all price tables, `bolts` field, `shop_screen.gd` | No shop. Items from reward picks only. |
| **Repair cost system** | `apply_match_result()` repair cost logic | No repair in roguelike. |
| **HUD onboarding (S21.2–S21.4)** | `godot/tests/test_s21_2_*`, `test_s21_4_003_league_surface.gd`, `test_s21_3_arena_onboarding.gd` | League-surface onboarding fully cut. `first_run_state.gd` infra kept; only league-specific content removed. |
| **League-degradation table** | `ArmorData.REFLECT_DAMAGE_BY_LEAGUE`, `reflect_damage_for_league()` | No leagues. Strip to reduce confusion. |
| **Arc C narrative beats** | Any league-transition story modals, narrative copy, popup scripts | HCD: "cut regardless of design." |
| **Sentinel feature (Arc D)** | Any committed Arc D sentinel code | Does not serve battle-focused loop. |
| **BrottBrain editor onboarding** | S21.2–S21.4 editor-specific tutorial work | Editor cut; onboarding is moot. Subsumed by §A.6 two-click tooltip. |
| **Multi-format matches** | 2v2 / 3v3 logic in GameState / GameFlow | v1.0 is 1vN (player solo always). Team format code cut. |
| **`first_wins` bonus system** | `GameState.first_wins[]`, first-win bolt bonus logic | No economy. Cut. |

---

### 🟨 RE-SKIN

| System | Current | Becomes | Files to modify |
|--------|---------|---------|-----------------|
| **`brottbrain.gd`** | Card-driven behavior engine (evaluates Trigger/Action cards) | **Hardcoded baseline AI** — same class name, same public API (`get_action()`, `set_target()`), completely different internals. New multi-target priority logic (§A.8). | `godot/brain/brottbrain.gd` — gut and rewrite internals |
| **`arena_renderer.gd`** | Renders exactly 2 bots (1 player, 1 enemy) | **Multi-target renderer** — render N enemy bots (up to 8). Add click-overlay layer: waypoint diamond, target reticle, bot override-active indicator. | `godot/arena/arena_renderer.gd` — extend bot array, add click layer |
| **`opponent_loadouts.gd`** | League-gated template pool | **Run encounter pool** — `difficulty_for(battle_index)` maps 1–15 to tiers. Add encounter archetype tags per template. Add `archetype_for(battle_index, last_archetype)` generator with no-repeat rule. | `godot/data/opponent_loadouts.gd` |
| **`GameState`** | Tracks bolts, owned items, league progression | **RunState (rename)** — tracks current build, retry count, battles won, current battle index, last encounter archetype. | `godot/game/game_state.gd` → `run_state.gd` |
| **`GameFlow`** | Menu → Shop → Loadout → BrottBrain → OpponentSelect → Arena → Result | **Run flow**: Menu → RunStart → [RewardPick → Arena] × 15 → BossArena → RunEnd | `godot/game/game_flow.gd` |
| **`ResultScreen`** | "VICTORY / DEFEAT" + bolts earned | Per §A.5 — "BROTT DOWN / RUN COMPLETE" with build summary + run stats. | `godot/ui/result_screen.gd` |
| **`LoadoutScreen`** | Full inventory management + purchase flow | **Current Build display** — read-only view of run loadout. No buy button. Equip/unequip for item rearrangement only. | `godot/ui/loadout_screen.gd` |
| **Reward Pick** | Does not exist (was shop) | **New screen: `reward_pick_screen.gd`** — 3 random items post-battle-win, player picks 1, immediately added to build. Full pool from battle 1 (§A.3). | NEW: `godot/ui/reward_pick_screen.gd` |
| **Run Start** | Does not exist (was "New Game → Shop") | **New screen: `run_start_screen.gd`** — random 3-chassis pick, first-run tooltip. | NEW: `godot/ui/run_start_screen.gd` |
| **Trick Choice Modal** | Scrapyard-only event | **In-run random event** — fires every 3–4 battles. Re-frame copy from "Scrapyard" to run context. | `godot/ui/trick_choice_modal.gd`, `godot/data/trick_choices.gd` — copy only |

---

## Section C — Roadmap

### Arc F — Roguelike Core Loop (Target: ~8–10 sub-sprints)
_Up from v1's 6–8: +2 sub-sprints for encounter shape implementation, multi-target AI, and click-overlay_

**Goal:** Wire the complete roguelike run loop end-to-end — run start → battles (all encounter shapes) → reward pick → boss → run end. Multi-target encounters playable. Click-to-move and click-to-target functional.

**Sub-sprint breakdown:**
- RunState + GameFlow rewire (2 sub-sprints)
- RewardPick screen + RunStart screen (2 sub-sprints)
- Hardcoded baseline AI + multi-target priority (2 sub-sprints)
- Arena renderer extension (N enemies + click overlay layer) (2 sub-sprints)
- Encounter archetype system + distribution logic (1 sub-sprint)
- Boss loadout authoring + CEO Brott AI (1 sub-sprint)

**Hard exit criteria:**
1. Player can start a run, battle through all 15 encounters (including ≥1 swarm + ≥1 mini-boss), and reach the boss
2. Reward pick screen works — 3 items shown, 1 selected, immediately applied
3. Retry mechanic works — 3 retries tracked, run ends on 4th loss
4. Run end screens work with build summary
5. Click-to-move and click-to-target functional in arena with correct visual feedback
6. Multi-target renderer works for up to 6 enemies simultaneously
7. `combat_batch.gd` simulations pass against multi-target encounter templates
8. No regressions on existing arena / combat tests

**Key dependencies:** HCD greenlights this GDD (all 9 sections) before Arc F starts.

---

### Arc G — Cut Pass (Target: ~4–5 sub-sprints)
_Up from v1's 3–4: +1 sub-sprint for the larger BrottBrain editor cut_

**Goal:** Remove all dead code — BrottBrain editor, league progression, shop, economy, opponent-select screen, narrative beats, S21.2–S21.4 test files, and associated test suite cleanup.

**Hard exit criteria:**
1. No references to `current_league`, `bronze_unlocked`, `opponents_beaten`, `bolts` in active codebase
2. `BrottBrainScreen`, `LeagueCompleteModal`, `OpponentSelectScreen`, `ShopScreen` scenes/scripts deleted
3. All deleted files removed from CI test matrix — no test failures from missing files
4. Behavior Card `TRIGGER_DISPLAY` / `ACTION_DISPLAY` tables removed from codebase
5. Combat simulations still pass

**Key dependencies:** Arc F complete (avoid cutting things Arc F still references mid-build)

---

### Arc H — Boss + Run Polish (Target: ~4–5 sub-sprints)

**Goal:** CEO Brott tuned to be satisfying climax; visual run identity (§A.7) polished; first-playtest-ready build. Corporate tie on Fortress chassis is an Arc H polish item.

**Hard exit criteria:**
1. Boss beatable but challenging — <40% first-attempt win rate in combat sim at Tier-3 average player build
2. Run HUD bar (battle counter + retry indicator) visible and correct on all non-arena screens
3. Background tinting per tier implemented
4. First-run tooltip flow works (§A.6) including new two-click arena tooltip
5. All 7 encounter archetypes authored and tested
6. HCD playtests full run and signs off

---

### Arc I — Ship (Target: ~2–3 sub-sprints)

**Goal:** Final CI/deploy cleanup, performance verification, browser-export polish. Ship v1.0.

**Hard exit criteria:**
1. HTML5 export loads in <5s on a mid-range device
2. All CI tests green
3. No known P0/P1 bugs
4. HCD final sign-off

---

**Total pipeline estimate:** ~17–22 sub-sprints (up from v1's 15–20). Increase absorbed by encounter shape design + multi-target systems + larger BrottBrain cut.

---

## Section D — Anti-Scope-Creep Guardrails

If any of the following tripwires fires during Arcs F–I, Riv **must escalate to The Bott** before proceeding. No agent may self-authorize work that crosses a tripwire.

**Tripwire 1: No new items or weapons.**  
The existing item roster (7 weapons, 3 armors, 6 modules) is the v1.0 set. Any proposal to add a new item type, weapon, chassis variant, or module → STOP. Escalate.

**Tripwire 2: No meta-progression.**  
No persistent unlock trees, no items that carry across runs, no experience points, no persistent currency. Any feature requiring data that survives between runs → STOP. Escalate.

**Tripwire 3: No narrative content.**  
No cutscenes, story beats, opponent backstories, dialogue beyond BrottBrain voice in trick events. Any sprint plan including story-advancing copy → STOP. Escalate.

**Tripwire 4: No new opponent archetypes or roster expansion beyond the authored elite/boss set.**  
The encounter pool + 3 authored elites + CEO Brott is sufficient for v1.0. Any proposal for additional opponent templates beyond these → STOP. Escalate.

**Tripwire 5: No team formats.**  
v1.0 is 1vN (player solo). Any feature touching 2v2 or player-team logic → STOP. Escalate.

**Tripwire 6: No BrottBrain editor revival. No new Behavior Card content.**  
The card-based editor is cut. No drag-and-drop UI, no card slots, no Trigger/Action card system in any form, no "lite editor" or "minimal card system" variant. Any sprint plan that resurrects BrottBrain as a player-facing editor → STOP. Escalate. HCD rejected the editor explicitly and permanently; do not relitigate.

---

## Appendix: Files Touched by v1.0 Pivot + v2 Updates

| Action | Files |
|--------|-------|
| Delete | `godot/ui/brottbrain_screen.gd` + scenes, `league_complete_modal.gd/.tscn`, `opponent_select_screen.gd`, `shop_screen.gd` |
| Gut + rewrite | `godot/brain/brottbrain.gd` (keep API, replace internals with baseline AI) |
| Extend | `godot/arena/arena_renderer.gd` (N-enemy renderer + click overlay) |
| Major rework | `godot/game/game_state.gd` → `run_state.gd`, `godot/game/game_flow.gd`, `godot/data/opponent_loadouts.gd`, `godot/ui/result_screen.gd` |
| New files | `godot/ui/reward_pick_screen.gd`, `godot/ui/run_start_screen.gd` |
| Minor rework | `godot/ui/main_menu_screen.gd`, `godot/ui/loadout_screen.gd` |
| Delete (test cleanup) | `godot/tests/test_s21_2_*`, `test_s21_4_003_league_surface.gd`, `test_s21_3_arena_onboarding.gd` |
| Keep untouched | All chassis/weapon/armor/module data files, audio assets, combat SFX, `first_run_state.gd`, `trick_choice_modal.gd` |

---

*This GDD v2 incorporates HCD decisions from `memory/2026-04-25-hcd-decisions-on-gdd-v1.md`. Ready for HCD greenlight review. On greenlight, Arc F planning begins.*
