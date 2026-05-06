# BattleBrotts — Game Design Document

**Version:** 2.0
**Date:** 2026-04-14
**Engine:** Godot 4 (HTML5 export)
**Team Size:** 1–2 developers

---

## 1. Elevator Pitch

Build autonomous combat Brotts by choosing a chassis, bolting on weapons and armor, then teaching them how to fight with drag-and-drop Behavior Cards. Watch your creation fight in top-down arenas where strategy beats stats — two identical loadouts perform completely differently based on their BrottBrain. It's mech tinkering meets programming puzzles meets spectator sport.

---

## 2. Core Loop

> ⚠️ **DEPRECATED (Arc G):** This section describes the league-era game flow, superseded by §13 Roguelike Run Loop. The league screens are scheduled for removal in Arc G.

1. **Build** — Select chassis, equip weapons/armor/modules within weight budget
2. **Teach** — Arrange Behavior Cards in the BrottBrain that govern autonomous behavior
3. **Fight** — Deploy Brott into arena, watch the match play out (no direct control)
4. **Analyze** — Review combat log, identify what went wrong
5. **Iterate** — Tweak loadout or BrottBrain, re-queue

Average loop iteration: 3–5 minutes.

---

## 3. Brott Customization

### 3.1 Chassis Types

| Chassis | HP | Speed (px/s) | Weight Cap | Weapon Slots | Module Slots | Passive |
|---|---|---|---|---|---|---|
| **Scout** | 110 | 220 | 30 kg | 2 | 3 | 15% dodge chance |
| **Brawler** | 150 | 120 | 55 kg | 2 | 2 | — |
| **Fortress** | 220 | 60 | 80 kg | 2 | 1 | — |

> **Note (S13.3):** The combat engine applies a 1.5× pacing multiplier to HP
> values on load (see `godot/data/chassis_data.gd`) — effective in-engine HP
> is Scout 165 / Brawler 225 / Fortress 330. GDD values above are the design
> spec; engine values are tuned for match-length pacing.

Base chassis weight is excluded from the weight budget — only equipped items count against capacity.

### 3.2 Weapons

| Weapon | Damage | Range (tiles) | Fire Rate (shots/s) | Spread (°) | Energy/Shot | Weight (kg) |
|---|---|---|---|---|---|---|
| **Minigun** | 3 | 5 | 6 | 15 | 2 | 10 |
| **Railgun** | 45 | 12 | 0.6 | 0 | 16 | 15 |
| **Shotgun** | 6×5 pellets | 3 | 1.5 | 30 | 8 | 12 |
| **Missile Pod** | 30 (splash r=1 tile) | 8 | 0.8 | 5 | 12 | 18 |
| **Plasma Cutter** | 14 | 2.5 | 3 | 0 | 4 | 8 |
| **Arc Emitter** | 8 (chains to 1 extra target within 2 tiles) | 4 | 2 | 10 | 6 | 11 |
| **Flak Cannon** | 15 | 6 | 1.2 | 20 | 7 | 13 |

All Brotts share a single energy pool: **100 max energy**, regenerating at **5 energy/sec**.

### 3.3 Armor

| Armor | Damage Reduction | Weight (kg) | Special |
|---|---|---|---|
| **Plating** | 20% | 15 | None — reliable baseline |
| **Reactive Mesh** | 10% | 8 | Reflects 5 flat damage back to attacker on hit |
| **Ablative Shell** | 40% | 25 | Reduction drops to 10% once Brott is below 30% HP |

Only one armor type can be equipped at a time. Armor occupies no slot — it's a dedicated equip.

### 3.4 Modules

| Module | Effect | Weight (kg) |
|---|---|---|
| **Overclock** | +30% fire rate for 4 sec, then 3 sec cooldown where fire rate is −20%. Activated via Behavior Card. | 5 |
| **Repair Nanites** | Restores 3 HP/sec passively. | 7 |
| **Shield Projector** | Activated: absorbs next 40 damage within 5 sec, 20 sec cooldown. | 10 |
| **Sensor Array** | +3 tile sight range, reveals Brotts behind partial cover. | 4 |
| **Afterburner** | Activated: +80% move speed for 2 sec, 12 sec cooldown. | 6 |
| **EMP Charge** | Activated: disables target's modules for 3 sec, 25 sec cooldown. Range: 4 tiles. | 9 |

### 3.5 Slot System

- Each weapon or module occupies exactly **1 slot** of its type.
- Total equipped item weight must be ≤ chassis weight capacity.
- Armor has no slot cost but counts against weight.
- Example: Brawler (55 kg cap, 2 weapon slots, 2 module slots) could equip Minigun (10 kg) + Shotgun (12 kg) + Plating (15 kg) + Repair Nanites (7 kg) + Overclock (5 kg) = 49 kg ✓

---

## 4. BrottBrain System (THE TWIST)

> ⚠️ **DEPRECATED (Arc G):** The §4.1 Progressive Disclosure schedule (Scrapyard → Bronze → Silver+) describes the league-era unlock flow, superseded by §13 Roguelike Run Loop. The BrottBrain editor surface itself is retained; the league-gated unlock progression is scheduled for removal in Arc G.

The BrottBrain is your Brott's autonomous decision-making system, built with **drag-and-drop Behavior Cards**. Every chassis comes pre-loaded with a smart default BrottBrain so new players can jump straight into combat.

### 4.1 Progressive Disclosure

- **Scrapyard (Tutorial):** BrottBrain is hidden. Brotts fight using smart defaults. Players focus on chassis + weapons.
- **Bronze (Unlock):** After the first Bronze match, a prompt appears: *"Want to teach your Brott some tricks?"* — this unlocks the BrottBrain editor.
- **Silver+:** Full BrottBrain editor always available.

### 4.2 Behavior Cards

Each Behavior Card is a visual rule with an icon and plain-English label. Cards are arranged in a priority list — the Brott checks from top to bottom each tick and acts on the first card whose trigger is true. If no card fires, the Brott follows its current Stance.

**Trigger Cards (WHEN…):**

| Card | Icon + Label | Parameters |
|---|---|---|
| 💔 "When I'm Hurt" | My HP drops below threshold | 10–90% (step 10) |
| 💪 "When I'm Healthy" | My HP is above threshold | 10–90% |
| 🔋 "When I'm Low on Juice" | My energy drops below threshold | 10–90% |
| ⚡ "When I'm Charged Up" | My energy is above threshold | 10–90% |
| 💔 "When They're Hurt" | Enemy HP drops below threshold | 10–90% |
| 📏 "When They're Close" | Enemy is within distance | 1–12 tiles |
| 📏 "When They're Far" | Enemy is beyond distance | 1–12 tiles |
| 🧱 "When They're In Cover" | Enemy is behind cover | Boolean |
| ✅ "When Gadget Is Ready" | A specific module is off cooldown | Module name |
| ⏱️ "When the Clock Says" | Match time exceeds threshold | 10–120 seconds |

**Action Cards (DO…):**

| Card | Icon + Label | Description |
|---|---|---|
| 🔄 "Switch Stance" | Change to a named Stance | Specified stance |
| 🔧 "Use Gadget" | Activate a specific module | Module name |
| 🎯 "Pick a Target" | Change target priority | Nearest / Weakest / Biggest Threat |
| 🔫 "Weapons" | Set weapon firing mode | All Fire / Conserve / Hold Fire |
| 🧱 "Get to Cover" | Override movement: go to nearest cover | — |
| 📍 "Hold the Center" | Override movement: go to arena center | — |

Players build a BrottBrain by dragging up to **8 Behavior Cards** into a priority list. Each card pairs one Trigger with one Action.

### 4.3 Stances

Each Brott has exactly one active Stance at any time. Stances define default movement and engagement patterns. Players pick stances with friendly names:

| Stance | Friendly Name | Movement Behavior | Engagement Behavior |
|---|---|---|---|
| **Aggressive** | 🔥 "Go Get 'Em!" | Move toward nearest enemy. Enter combat movement at 65% of shortest weapon range (orbit + juke). | Fire all weapons as soon as in range. Prioritize DPS uptime. |
| **Defensive** | 🛡️ "Play it Safe" | Retreat to nearest cover. If no cover, maintain max weapon range from enemy. | Fire only when enemy is within 80% of max range. Prefer cover over optimal firing position. |
| **Kiting** | 💨 "Hit & Run" | Maintain distance between 60–80% of max weapon range. Circle-strafe clockwise. | Fire while moving. Disengage if enemy closes within 40% of max range. |
| **Ambush** | 🕳️ "Lie in Wait" | Move to nearest cover and hold position. Do not move unless condition triggers. | Fire only when enemy enters 50% of max range (point-blank alpha strike). |

### 4.4 Example BrottBrain Strategies

**"Glass Cannon" (Scout + Railgun)**
- Default Stance: 💨 "Hit & Run"

| # | Trigger Card | Action Card |
|---|---|---|
| 1 | 💔 "When I'm Hurt" (below 40%) | 🔧 "Use Gadget" → Shield Projector |
| 2 | 📏 "When They're Close" (within 3 tiles) | 🔧 "Use Gadget" → Afterburner |
| 3 | 📏 "When They're Close" (within 3 tiles) | 🔄 "Switch Stance" → 💨 "Hit & Run" |
| 4 | 💔 "When They're Hurt" (below 30%) | 🔄 "Switch Stance" → 🔥 "Go Get 'Em!" |
| 5 | 🔋 "When I'm Low on Juice" (below 20%) | 🔫 "Weapons" → Conserve |

*Strategy: Keep distance and snipe. Pop shield when hurt, boost away if they close in, go aggressive for the kill.*

**"Juggernaut" (Fortress + Minigun + Shotgun + Missile Pod)**
- Default Stance: 🔥 "Go Get 'Em!"

| # | Trigger Card | Action Card |
|---|---|---|
| 1 | 💔 "When I'm Hurt" (below 50%) | 🔧 "Use Gadget" → Shield Projector |
| 2 | 📏 "When They're Close" (within 2 tiles) | 🔫 "Weapons" → All Fire |
| 3 | 📏 "When They're Far" (beyond 6 tiles) | 🔫 "Weapons" → Conserve |
| 4 | 🧱 "When They're In Cover" | 🎯 "Pick a Target" → Nearest |
| 5 | ⏱️ "When the Clock Says" (above 60s) | 🔄 "Switch Stance" → 🔥 "Go Get 'Em!" |

*Strategy: March forward and overwhelm. Full firepower at close range, missiles only at distance, pop shield when things get rough.*

**"Roach" (Scout + Plasma Cutter + Repair Nanites + Afterburner + Sensor Array)**
- Default Stance: 🕳️ "Lie in Wait"

| # | Trigger Card | Action Card |
|---|---|---|
| 1 | 💔 "When I'm Hurt" (below 30%) | 🔄 "Switch Stance" → 🛡️ "Play it Safe" |
| 2 | 💪 "When I'm Healthy" (above 70%) | 🔄 "Switch Stance" → 🕳️ "Lie in Wait" |
| 3 | 📏 "When They're Close" (within 2 tiles) | 🔧 "Use Gadget" → Afterburner |
| 4 | 📏 "When They're Close" (within 2 tiles) | 🔄 "Switch Stance" → 💨 "Hit & Run" |
| 5 | ✅ "When Gadget Is Ready" (Afterburner) | 🔄 "Switch Stance" → 🕳️ "Lie in Wait" |

*Strategy: Hide, heal with nanites, ambush with plasma cutter, flee when caught. Outlast the enemy.*

---

## 5. Combat System

### 5.1 Tick System

- Simulation runs at **10 ticks/sec** (100 ms per tick).
- Each tick, in order:
  1. **BrottBrain evaluation** — check Behavior Cards top-to-bottom, fire first match
  2. **Energy regen** — +0.5 energy this tick (5/sec)
  3. **Module tick** — cooldown timers decrement, passive effects apply (e.g., Repair Nanites: +0.3 HP/tick)
  4. **Movement** — Brott moves according to Stance/override at its speed
  5. **Weapon fire** — each weapon checks fire rate timer, fires if ready and target in range/LoS
  6. **Projectile update** — projectiles advance, hit detection resolved
  7. **Damage application** — HP adjusted, death check
- Combat is **fully deterministic** given the same seed — enables headless replay and automated testing.

### 5.2 Damage Formula

```
effective_damage = base_damage × (1 - armor_reduction) × crit_multiplier

crit_chance = 5%
crit_multiplier = 1.5× (if crit) or 1.0× (if not)
```

- **Splash damage** (Missile Pod): full damage at impact tile, 50% damage at radius tiles.
- **Reactive Mesh reflect**: 5 flat damage applied to attacker after armor calc, ignores attacker's armor.
- **Minimum damage**: 1 (no attack deals 0).
- **Pellet weapons** (Shotgun): each pellet rolls independently. 6 damage × 5 pellets, each with its own hit check based on spread.

**Hit calculation for spread weapons:**
Each pellet/bullet has a random angle offset within ±(spread/2). If the offset ray intersects the target's hitbox (circle, radius = 12 px), it hits.

### 5.2.1 Hit Rate Instrumentation

Because spread weapons fire multiple projectiles per trigger pull, balance reports
track two hit-rate metrics that must never be conflated:

| Metric | Numerator | Denominator | Cap | Use |
|---|---|---|---|---|
| **Per-pellet** (canonical) | `pellets_hit` | `pellets_fired` | ≤ 100% | Balance tuning, comparable across all weapons |
| **Per-shot** | `shots_hit` | `shots_fired` | ≤ 100% | "Did any projectile from that trigger pull connect?" (narrative stat, not balance) |

- Single-projectile weapons (Plasma Cutter, Minigun, Railgun, Missile Pod, Flak
  Cannon, Arc Emitter) have identical per-shot and per-pellet rates.
- Shotgun (5 pellets per trigger) is the current spread weapon; both metrics differ.
- Prior to S13.3 the engine conflated the two, producing reported hit rates >100%
  for shotguns (Specc KB finding #3). As of S13.3 both numerators are deduplicated
  via shot IDs: multiple pellets from one trigger pull credit `shots_hit` exactly
  once, while each individual pellet that lands credits `pellets_hit`.

### 5.3 Movement & Targeting

- **Pathfinding**: A* on the tile grid (32×32 px tiles). Recalculated every 5 ticks (2×/sec).
- **Default target selection**: Nearest enemy (Euclidean distance). Overridable via 🎯 "Pick a Target":
  - `Nearest` — closest by distance
  - `Weakest` — lowest current HP
  - `Biggest Threat` — highest DPS output in last 20 ticks
- **Collision**: Brotts cannot overlap. Brotts colliding with walls or each other slide along the surface.
- **Circle-strafe** (💨 "Hit & Run" stance): Brott moves perpendicular to the line between itself and its target, maintaining range band.

### 5.3.1 Combat Movement

When a Brott has line of sight to its target and is within weapon range, it enters **combat movement** using the **Tension→Commit→Recovery (TCR)** cycle. This creates a structured combat rhythm where bots circle, dash in, and retreat — producing dynamic, watchable fights.

**Approach Phase:** Pre-engagement movement (before reaching weapon range) uses 80% of base speed.

**Commit speed cap (S13.3):** The COMMIT phase target speed is
`min(base_speed × 1.4, 200 px/s)`. The absolute cap (200 px/s) prevents Scout's
commit dash (220 × 1.4 = 308 px/s) from crossing the entire engagement band in
a single 0.8s window. Brawler (168 px/s) and Fortress (84 px/s) are unaffected
by the cap. Afterburner and overtime multipliers stack on top of the capped value.

**TCR State Machine (per-chassis timings, S13.3):** Each chassis has its own
combat rhythm. Phase durations below; all other TCR semantics are identical
across chassis.

| Chassis | TENSION | COMMIT | RECOVERY | Fantasy |
|---|---|---|---|---|
| **Scout** | 2.5–4.0s | 0.6s | 1.5s | Slippery, cautious, commits briefly |
| **Brawler** | 2.0–3.5s | 0.8s | 1.2s | Well-rounded baseline |
| **Fortress** | 1.5–2.5s | 1.2s | 0.9s | Relentless — short windups, long commits, quick reset |

**TCR phase semantics (common to all chassis):**

1. **TENSION** (duration per chassis — see table above):
   - Orbits at 55% base speed
   - Weapons fire normally
   - Small lateral drifts ±0.3 tiles perpendicular every 1.0s
   - When timer expires → COMMIT

2. **COMMIT** (duration per chassis):
   - Dashes toward target at `min(base_speed × 1.4, 200 px/s)` (S13.3 commit cap)
   - Closes to `ideal_engagement_distance - 1.5 tiles` (minimum 0.5 tiles from target)
   - Straight line — no orbit
   - Weapons fire at normal rate (spread weapons land more at close range)
   - When timer expires → RECOVERY

3. **RECOVERY** (duration per chassis):
   - Retreats away from target at 90% base speed
   - Weapons still fire (retreating fire)
   - Cannot re-enter COMMIT during recovery
   - Respects backup_distance cap (max 1 tile retreat before lateral movement)
   - When timer expires → TENSION

**Engagement distance tolerance bands:**
| Stance | Ideal Distance | Tolerance |
|---|---|---|
| Aggressive | shortest_weapon_range × 0.65 | ±0.5 tiles |
| Defensive | longest_weapon_range × 0.85 | ±1.0 tiles |
| Kiting | longest_weapon_range × 0.70 | ±1.0 tiles |
| Ambush | N/A (hold position) | N/A |

During TENSION: if farther than ideal + tolerance, approaches; if closer than ideal − tolerance, backs away (max 1 tile straight line, then lateral); if within band, orbits.

**Separation force:** If two Brotts' centers are within 1.0 tile (32 px), a repulsion force pushes them apart at 60% of their base move speed.

### 5.4 Line of Sight & Range

- **LoS**: Raycast from Brott center to target center on the tile grid. If the ray passes through a wall tile, LoS is blocked. Cover tiles block 50% of rays (randomly determined per shot — effectively a 50% miss chance).
- **Range bands** (for Stance behavior, in tiles):
  - **Melee**: 0–2
  - **Close**: 2–5
  - **Mid**: 5–8
  - **Long**: 8–12
- Weapons cannot fire beyond their listed range. No damage falloff within range.

---

## 6. Progression

> ⚠️ **DEPRECATED (Arc G):** This section describes the league-era progression (Scrapyard / Bronze / Silver / Gold), superseded by §13 Roguelike Run Loop. The league progression screens are scheduled for removal in Arc G. The §6.3 archetype taxonomy and §6.4 scaling notes still inform the roguelike encounter generator (see §13.4).

### 6.1 League Structure

| League | Opponents | Unlock Requirement | New Content Unlocked |
|---|---|---|---|
| **Scrapyard** (Tutorial) | 3 | Start of game | Scout chassis, Plasma Cutter, Plating |
| **Bronze** | 5 | Beat Scrapyard | Brawler chassis, Shotgun, Arc Emitter, Reactive Mesh, Overclock, Repair Nanites. **BrottBrain editor unlocks.** |
| **Silver** | 5 | Beat 3/5 Bronze | Fortress chassis, Railgun, Flak Cannon, Shield Projector, Sensor Array |
| **Gold** | 5 | Beat 3/5 Silver | Missile Pod, Ablative Shell, Afterburner, EMP Charge. **2v2 team battles introduced.** |
| **Platinum** | 5 | Beat 3/5 Gold | All items available. Enemy Brotts use advanced BrottBrains. **3v3 team battles.** |
| **Champion** | 3 | Beat 5/5 Platinum | Endgame. Handcrafted boss Brotts with unique loadouts. **3v3 team battles.** |

Total: **26 matches** to complete all leagues.

### 6.2 Difficulty Curve

- **Scrapyard**: Enemies use 1 weapon, no modules, 🔥 "Go Get 'Em!" stance only, no Behavior Cards. BrottBrain is hidden.
- **Bronze**: Enemies use armor + 1 module, 1–2 Behavior Cards.
- **Silver**: Full loadouts, 3–4 Behavior Cards, mix of Stances.
- **Gold**: Optimized builds, 5–6 Behavior Cards, counter-strategies to common player builds.
- **Platinum**: Near-optimal BrottBrains, adaptive target priority, 7–8 Behavior Cards.
- **Champion**: Bespoke designs that exploit specific weaknesses. Each is a puzzle.

Enemy Brott stat scaling: **none**. Enemies use the same items and stats as the player. Difficulty comes from better BrottBrains and loadout synergy.

### 6.3 Opponent Archetype Taxonomy (Sprint 13.9)

Opponent loadouts are now **template-driven**: each enemy match draws from a
pool of named templates (`godot/data/opponent_loadouts.gd`) filtered by
difficulty tier, with a variety guarantee preventing back-to-back archetype
repeats. Templates are the single source of truth for an opponent's name,
chassis, weapons, armor, modules, and stance.

**Archetypes** (5):

- **TANK** — Heavy armor, brawler stance, sustain modules. Punishes players with no sustain.
- **GLASS_CANNON** — No armor, long-range burst (railgun), kiting stance. Punishes players with no mobility.
- **SKIRMISHER** — Medium armor, flak + mobility modules, kiting stance. Generalist harasser; tests positional discipline.
- **BRUISER** — Medium armor, dual weapons, aggressive stance. Midrange pressure; rewards TCR-window commitment.
- **CONTROLLER** — Disruption (jammer / EMP / arc emitter), defensive stance. Punishes module-reliant player builds.

**Template pool** (19 total; 7 Bronze-legal, 7 Silver-new, 5 Silver+-grandfathered):

| ID | Name | Archetype | Tier | Unlock | Composition |
|---|---|---|---|---|---|
| `tank_tincan` | Tincan | TANK | 1 | Scrapyard | Scout + Plasma + Plating |
| `skirmish_wasp` | Wasp | SKIRMISHER | 1 | Silver | Scout + Flak/Plasma + Plating + Afterburner/Sensor/Overclock |
| `tank_ironclad` | Ironclad | TANK | 2 | Silver | Fortress + Shotgun/Flak + Ablative + Repair Nanites |
| `glass_sniper` | Pinprick | GLASS_CANNON | 2 | Silver | Scout + Railgun/Plasma + None + Overclock/Sensor/Afterburner |
| `bruiser_crusher` | Crusher-II | BRUISER | 2 | Bronze | Brawler + Shotgun/Minigun + Reactive + Overclock/Repair |
| `controller_jammer` | Jammer | CONTROLLER | 3 | Gold | Brawler + Arc/Missile + Reactive + EMP/Shield Projector |
| `tank_rustwall` | Rustwall | TANK | 2 | Bronze | Brawler + Shotgun + Minigun + Reactive + Repair Nanites |
| `glass_zap` | Zap | GLASS_CANNON | 2 | Bronze | Scout + Arc Emitter + Reactive + Overclock |
| `skirmish_scrapper` | Scrapper | SKIRMISHER | 2 | Bronze | Scout + Shotgun + Reactive + Overclock |
| `bruiser_clanker` | Clanker | BRUISER | 2 | Bronze | Brawler + Arc Emitter + Shotgun + Plating + Overclock |
| `control_static` | Static | CONTROLLER | 3 | Bronze | Brawler + Arc Emitter + Shotgun + Reactive + Repair Nanites |
| `control_prowler` | Prowler | CONTROLLER | 3 | Bronze | Scout + Arc Emitter + Reactive + Repair Nanites |
| `tank_bulwark` | Bulwark | TANK | 3 | Silver | Brawler + Shotgun + Flak Cannon + Reactive + Shield Projector + Repair Nanites |
| `glass_trueshot` | Trueshot | GLASS_CANNON | 3 | Silver | Scout + Railgun + None + Sensor Array + Overclock |
| `skirmish_harrier` | Harrier | SKIRMISHER | 3 | Silver | Scout + Flak Cannon + Reactive + Sensor Array + Overclock |
| `bruiser_enforcer` | Enforcer | BRUISER | 3 | Silver | Brawler + Minigun + Arc Emitter + Plating + Shield Projector + Overclock |
| `control_disruptor` | Disruptor | CONTROLLER | 4 | Silver | Brawler + Arc Emitter + Flak Cannon + Reactive + Shield Projector + Sensor Array |
| `tank_aegis` | Aegis | TANK | 4 | Silver | Brawler + Railgun + Minigun + Reactive + Shield Projector + Repair Nanites |
| `glass_chrono` | Chrono | GLASS_CANNON | 4 | Silver | Scout + Railgun + None + Sensor Array + Overclock |

**Difficulty tier mapping** (`OpponentLoadouts.difficulty_for(league, index)`):

- **Scrapyard** indices 0, 1, 2 → tiers **1, 1, 2**
- **Bronze** indices 0, 1, 2, 3, 4 → tiers **2, 2, 2, 3, 3** (populated at S21.1 — 5-opponent curve, tier-2 openers → tier-3 closers)
- **Silver** indices 0, 1, 2, 3, 4 → tiers **3, 3, 3, 4, 4** (populated at S22.1 — tier-3 openers, tier-4 closers; Silver introduces tier-4)

Picker fallback: when a tier's pool has fewer than 2 entries, tier-1-lower
templates are added. The variety strip (`last_archetype != pick.archetype`)
is applied last and skipped when it would empty the pool.

**Variety rule:** no two consecutive opponent builds within a run share the
same archetype. State lives on `GameState._last_opponent_archetype` and is
naturally cleared by `GameFlow.new_game()` (fresh GameState per run).

**Design notes:**

- Archetypes are a **template-level** concept, not a chassis-level one
  (per Ett, S13.9). Chassis data carries stats + TCR only; archetype
  personality comes from the template's weapon/armor/module combination.
- Counter-play hook reserved for **Sprint 13.10**: picker signature
  accepts `_player_archetype_hint` (currently unused) so tier/variety
  logic can later be composed with matchup-aware filtering.
- **League-gating (S21.1):** templates carry an `unlock_league` field
  (`scrapyard` | `bronze` | `silver` | `gold` | `platinum`). The picker
  accepts a `current_league` arg and filters out templates whose unlock
  exceeds the current league's rank, so Bronze players never face Silver+
  gear. Empty-string (backward-compat default) skips the filter, which
  is how the Scrapyard path continues to draw from the grandfathered
  tier-2 pool. Opponent templates also carry a `behavior_cards` field
  (data-only at S21.1; engine wiring tracked as carry-forward).
- **Silver content (S22.1):** Silver's 7 new templates lean TANK + GLASS_CANNON
  (4/7), versus Bronze's lean on BRUISER + CONTROLLER. This is intentional —
  Silver unlocks Fortress (available on grandfathered `tank_ironclad`), Railgun
  (GLASS_CANNON weapon), and Flak Cannon (area-deny weapon), so Silver's tonal
  identity is "specialist kit + long range" where Bronze's was "mid-range commit."
  New Silver TANK templates (Bulwark, Aegis) use Brawler chassis to satisfy the
  2-module-slot requirement; Fortress has only 1 module slot (engine-verified). Silver also requires
  `modules.size() == 2` per GDD §6.2 "full loadouts" rule; Bronze uses
  `modules.size() == 1`. Tier-4 is introduced at Silver for closing fights.

---

### 6.4 League Scaling — Player-Side Degradation

**Core principle.** Certain player defensive systems degrade as the player advances through leagues. This is an intentional progression tax: the climb costs something, and the player should feel it. Higher leagues are not simply harder opponents — they are environments where the player's current kit reads differently.

**Why player-side, not opponent-only.** S22.2b (2026-04-24) established the failure mode of opponent-only scaling. When opponents are tuned to compensate for a symmetric mechanic (both player and opponent benefit from Reactive Mesh reflect), the opponent pool loses archetype coherence — Brawler-wall templates shed their identity characteristic (Reactive Mesh) to suppress a damage number. The correct fix is a data-layer table at the mechanic's read-site so the mechanic itself degrades with league, leaving opponent loadouts free to be authored for archetype clarity.

**Bronze as canonical baseline.** All player defensive systems are at full strength in Bronze. Bronze is the design anchor — the league where each armor and module reads as intended. Balance tuning and WR targets for new armor/module introductions should be validated at Bronze first.

**Current implementation — Reactive Mesh reflect damage:**

| League     | Reflect HP per hit | Notes                          |
|------------|-------------------|--------------------------------|
| Scrapyard  | 5.0               | Pre-Bronze; matches Bronze     |
| Bronze     | **5.0**           | Canonical baseline — immutable |
| Silver     | 2.0               | Degraded; ~40% of Bronze       |
| Gold       | 1.0               | Future-proof (not yet live)    |
| Platinum   | 0.0               | Mesh "broken" — narrative arc  |

Implemented via `ArmorData.REFLECT_DAMAGE_BY_LEAGUE` dictionary + `reflect_damage_for_league(type, league)` helper. Combat-sim reads league from `BrottState.current_league` (default `"bronze"` for back-compat). One-line read-site change; no engine logic touched.

**Extensibility.** Dictionary pattern is open by key. Future tier-5 "Storm Mesh" armor with its own reflect curve registers a new entry without modifying the helper or the sim. Future defensive modules — Repair Nanites uptime, Overclock cooldown — follow the same per-league table pattern.

**Narrative-coupling rule.** Any player-side degradation introduced at a new league boundary must ship with a one-line modal beat on league entry explaining it. Silent nerfs are prohibited. S22.2c ships this for Silver via `league_complete_modal.gd` copy: *"Reactive mesh loses its teeth up here. Silver runs hotter."*

---

## 7. Economy

> ⚠️ **DEPRECATED (Arc G):** This section describes the league-era economy (Bolts shop, repair costs, item prices), superseded by §13 Roguelike Run Loop where weapons/armor/modules are earned via post-battle reward picks rather than purchased. The shop and repair UI are scheduled for removal in Arc G.

### 7.1 Currency

Single currency: **Bolts (🔩)**.

| Result | Bolts Earned |
|---|---|
| Win | 100 🔩 |
| Loss | 40 🔩 |
| Win (first time vs. opponent) | 200 🔩 (bonus) |

### 7.2 Item Costs

**Chassis:**
| Item | Cost |
|---|---|
| Scout | Free (starter) |
| Brawler | 200 🔩 |
| Fortress | 400 🔩 |

**Weapons:**
| Item | Cost |
|---|---|
| Minigun | 50 🔩 |
| Plasma Cutter | Free (starter) |
| Shotgun | 120 🔩 |
| Arc Emitter | 150 🔩 |
| Flak Cannon | 200 🔩 |
| Railgun | 300 🔩 |
| Missile Pod | 350 🔩 |

**Armor:**
| Item | Cost |
|---|---|
| Plating | Free (starter) |
| Reactive Mesh | 150 🔩 |
| Ablative Shell | 300 🔩 |

**Modules:**
| Item | Cost |
|---|---|
| Overclock | 100 🔩 |
| Repair Nanites | 120 🔩 |
| Sensor Array | 150 🔩 |
| Shield Projector | 200 🔩 |
| Afterburner | 180 🔩 |
| EMP Charge | 250 🔩 |

All purchases are permanent. No consumables.

### 7.3 Repair Costs

After each match, the Brott takes wear damage regardless of outcome:
- **Win**: Repair cost = 20 🔩 flat
- **Loss**: Repair cost = 50 🔩 flat
- Repair is mandatory before next match
- Flat costs prevent the death spiral where expensive builds become unsustainable

Example: Any Brott → 20 🔩 repair on win, 50 🔩 on loss, regardless of equipment value.

---

## 8. Arena Design

### 8.1 Arena Types

| Arena | Size (tiles) | Features | Strategy Impact |
|---|---|---|---|
| **The Pit** | 16×16 | Open floor, no cover, 4 pillars in center | Pure build vs build. Nowhere to hide. Favors DPS and armor. |
| **Junkyard** | 20×20 | Scattered cover blocks (8–10), 2 elevated platforms | Rewards 🛡️ "Play it Safe" / 🕳️ "Lie in Wait" stances. Cover-based play. |
| **Foundry** | 20×16 | Conveyor belts (push Brotts 1 tile/sec in belt direction), lava tiles (10 damage/sec on contact) | Environmental awareness matters. Kiting around hazards. |

### 8.2 Environmental Features

- **Walls**: Block movement and LoS completely.
- **Cover blocks**: Half-height. Block 50% of shots (per-shot random). Brotts can path around them. Destructible: 50 HP, removed when destroyed.
- **Pillars**: Indestructible cover. Block movement and LoS.
- **Conveyor belts**: Push any Brott on them 1 tile/sec in the indicated direction. Can push into walls (no damage) or hazards.
- **Lava tiles**: 10 damage/sec to any Brott standing on them. Ignores armor.

---

## 9. Match Format

- **1v1** — Scrapyard through Silver leagues
- **2v2** — Introduced in Gold (player deploys 2 Brotts vs 2 enemy Brotts)
- **3v3** — Platinum and Champion leagues (player deploys 3 Brotts vs 3 enemy Brotts)
- **Win condition**: Reduce all enemy Brotts' HP to 0
- **Loss condition**: All your Brotts reach 0 HP
- **Draw condition**: If neither side is eliminated after the **match timeout** (1v1: 100s, team: 120s), the side with higher total remaining HP% wins. If tied, it's a draw (counts as a loss for progression, but awards 40 🔩).
- **Overtime Aggression**: When the match timer exceeds the overtime threshold, all Brotts enter **Overtime** — their stance is forced to 🔥 "Go Get 'Em!" (overriding BrottBrain), movement speed increases by 20%, all weapons deal **1.5× damage**, the arena boundary starts **shrinking at 0.5 tiles/second** toward center, and an "OVERTIME!" banner appears on screen. Bots outside the shrinking boundary take **10 damage/second** (ignores armor, like lava). A red danger zone overlay and pulsing border visualize the shrinking safe area. At the **Sudden Death** threshold, damage amplification increases to **2× damage** and a "SUDDEN DEATH!" banner with red flash replaces the overtime banner. This multi-stage mechanic prevents stalemates from defensive/kiting builds and guarantees decisive outcomes within 15-30 seconds of overtime. Target: <5% timeout rate.

  | Mode | Overtime | Sudden Death | Match Timeout |
  |------|----------|--------------|---------------|
  | **1v1** | 45s | 60s | 100s |
  | **Team (2v2/3v3)** | 60s | 75s | 120s |

  *Note: 1v1 uses tighter timings to keep solo matches snappy. Team matches get more time due to multiple Brotts on each side. By ~20s after overtime starts, the arena is effectively zero — Brotts MUST fight.*
- **Target match length**: 30–60 seconds for 1v1, 45–90 seconds for 2v2/3v3. Match timeout prevents stalemate builds.

---

## 10. Art Direction

### Visual Style
- **Top-down 2D**, camera fixed overhead
- **Tile size**: 32×32 pixels
- **Brott size**: 24×24 pixels (fits within a tile with clearance)
- **Style**: Clean pixel art or simple vector shapes. Asset-pack friendly.
- **Color coding**: Player Brotts = blue tones. Enemy Brotts = red tones. Neutral environment = grey/brown.

### Camera
- Fixed camera showing the full arena. No scrolling needed (max arena 20×20 tiles = 640×640 px game area).
- UI panels on sides/bottom.

### UI Layout
```
┌─────────────────────────────────┐
│  [Player Brott Info] [Enemy]    │
│  HP ████████░░  HP ██████░░░░   │
│  EN ██████░░░░  EN ████░░░░░░   │
├─────────────────────────────────┤
│                                 │
│         ARENA VIEW              │
│        (640×640 px)             │
│                                 │
├─────────────────────────────────┤
│  [Combat Log ▼]  [Speed: 1x 2x]│
│  (collapsible — click to expand)│
└─────────────────────────────────┘
```

### Combat Spectacle
- **Screen shake**: On heavy hits (Railgun, Missile Pod explosions)
- **Slow-motion kills**: Brief 0.3s slow-mo when a Brott is destroyed, camera briefly zooms in
- **Particle effects**: Sparks on bullet impacts, smoke trails on missiles, energy crackle on Arc Emitter chains, explosion VFX on Brott destruction
- **Hit flash**: Brotts flash white for 1 frame when taking damage

### Visual Feedback
- **Damage numbers**: Float up from hit location, white for normal, yellow for crit
- **Projectiles**: Visible bullets/missiles traveling between Brotts
- **Shield**: Blue circle overlay when Shield Projector active
- **Health bar**: Above each Brott, green→yellow→red
- **Stance indicator**: Small icon below Brott showing current stance with friendly name

### Combat Log
The combat log is **optional and collapsible** — tucked away by default to keep the focus on the visual action. Available for players who want to analyze tick-by-tick details.

### Shop Card Grid (S13.4)

The shop is a **card grid**, not a text list. Cards are 200x240 px, arranged 3-wide on desktop and 2-wide on mobile (viewport <= 720 px wide). Each card shows:

- **Art tile** (120x120) — category-colored placeholder with monogram glyph (see Placeholder Art Palette below)
- **Name** (16pt bold)
- **Archetype tag** (11pt muted, e.g. `Sniper • Weapon`, `Light • Armor`)
- **Price** (18pt, bottom-right) — default color if affordable, red if unaffordable, `✓ Owned` in green if owned

Tap/click a card to expand an **inline stats panel** below that row (not a modal). The buy button lives inside the expanded panel, not on the card. Only one card is expanded at a time. Owned items render at 50% opacity with a green ✓ badge overlay but remain tappable so players can inspect stats.

**Section order:** WEAPONS → ARMOR → CHASSIS → MODULES (weapons first because weapons are what players shop for after a fight). The bolts counter is top-right of the shop header at 36pt.

Implementation note: the grid uses VBox-of-HBox rows rather than a GridContainer to keep reflow-on-expand deterministic (Ett flagged GridContainer as flaky for mid-grid full-width inserts).

### Placeholder Art Palette (S13.4)

Until commissioned art lands, item cards use category-colored tiles with a letter monogram (first letter of the last word of the item name — disambiguates "Plasma Cutter" vs "Plating"). The palette is intentional — color coding per category has meaning even after real art is in, so the palette carries forward as the card background or accent.

| Category | Fill | Border | Glyph |
|---|---|---|---|
| Weapon | `#8B2E2E` (rust red) | `#D4A84A` gold | 48pt cream (`#F4E4BC`) |
| Armor | `#2E5A8B` (steel blue) | `#8FAECB` light steel | same |
| Chassis | `#4A4A4A` (gunmetal) | `#A0A0A0` silver | same |
| Module | `#2E6B4A` (industrial green) | `#7BCA9E` mint | same |

The placeholder scheme is *intentionally* chunky — playtesters should read these as "not final art", not mistake them for shipped visuals. Animations, SFX, and real art swap-in are deferred to S13.5.

### Shop Polish (S13.5)

Polish pass on top of the S13.4 card grid. Scope: `godot/ui/shop_screen.gd` only (plus one new test file + this GDD note). No art, no balance, no new items.

**Animations:**
- **Buy confirmation pulse** — 120 ms scale pulse on the buy button after a successful purchase (1.0 → 1.12 → 1.0, `TRANS_QUAD`, ease out/in). Plays before `_build_ui()` rebuild via `await tween.finished`.
- **New-item pulse** — cards not yet seen this session get a cream-alpha (`#F4E4BC` @ 40%) overlay pulse for ~2 s (2 full loops) on first render. Tapping a pulsing card cancels its pulse. State lives on `shop_screen.gd` as `_seen_shop_items` (session-local; no GameState reset hook exists yet — cross-run persistence is a S13.6+ concern).

**Audio tokens** (safe-load, placeholder paths — real SFX commissioned in S14+):
- `SFX_BUY_SUCCESS` → `res://audio/sfx/shop_buy_success.ogg` — bright/confident register-close feel, 150–300 ms
- `SFX_BUY_FAIL` → `res://audio/sfx/shop_buy_fail.ogg` — muted thud, 100–200 ms
- `SFX_CARD_TAP` → `res://audio/sfx/shop_card_tap.ogg` — soft paper/card flip, 60–120 ms

All three wired through a single `ShopAudio: AudioStreamPlayer` child node via `_play_sfx(path)`. Missing files are a no-op (safe-load via `ResourceLoader.exists`). Volume target: -6 dBFS peak.

---

## 11. Key Metrics for Playtest Lead

### Balance Metrics
- **Win rate by chassis**: Should be 45–55% for each across all matchups
- **Weapon usage distribution**: No single weapon should appear in >60% of winning builds
- **Time-to-kill by tier**: Scrapyard 15–30s, Bronze 20–40s, Silver 25–50s, Gold/Platinum 30–60s
- **Economy flow**: Player should afford 1 new item every 2–3 matches
- **BrottBrain diversity**: Track how many distinct Behavior Card combinations lead to wins — more = better
- **Stance usage**: All 4 stances should appear in winning strategies

### Feel Metrics
- **Match length distribution**: Target bell curve centered at 45s (1v1), hard cap 100s (1v1) / 120s (team)
- **Pacing**: At least 1 significant event (stance switch, module activation, HP threshold crossed) every 5 seconds
- **Build diversity across leagues**: % of unique loadouts in player wins per league
- **Comeback rate**: % of matches where the Brott that took first damage wins — target ~35%
- **Stalemate rate**: % of matches hitting timeout (100s 1v1 / 120s team) — target <5%

### Simulation Tests
- Run 10,000 combat simulations per balance pass
- Test every weapon against every armor type
- Test every chassis matchup (Scout v Brawler, Scout v Fortress, Brawler v Fortress)
- Verify no item combination produces >70% win rate against the field
- Verify economy allows completing the game without grinding (target: <40 total matches)

### BrottBrain Trick Choices (S13.6)

Scrapyard-league runs open each shop visit with a one-tap **Trick Choice** from BrottBrain. Two options, clear tradeoffs, small deltas — the point is voice + risk-flavor, not balance pressure.

**System overview:**
- Pool of 3 session-scoped tricks in `data/trick_choices.gd` (`rusty_launcher`, `scavenger_kid`, `risk_for_reward`).
- On Scrapyard shop entry, `GameState.pick_unseen_trick()` prefers an unseen trick; once exhausted the full pool is re-offered (no crash).
- Modal (`ui/trick_choice_modal.tscn`) is presentation-only: it emits `resolved(trick_id, choice_key)` and the caller (`ShopScreen`) applies effects via `GameState.apply_trick_choice(trick, choice_key)`.
- `EffectType` supports `BOLTS_DELTA`, `NEXT_FIGHT_PELLET_MOD`, `HP_DELTA` (pending, applied next fight), `ITEM_GRANT`/`ITEM_LOSE` (stubbed — see PR notes).
- Secondary effects (`effect_type_2`/`effect_value_2`) compose with the primary so a single choice can read "gain X, pay Y."

**BrottBrain voice — cynical-but-caring:**
- Short. Dry. A little tired. BrottBrain has seen your nonsense before.
- Skepticism up front ("Looks shady." / "I don't trust that kid.") followed by a pragmatic flavor line on resolution.
- Never preachy. Never cheerleader. A mentor who'd rather you not get your paw snapped off, but will absolutely let you make the call.
- Good: "Smart. +10 bolts." / "Got 'em. Lost some fur." / "Wise. Boring, but wise."
- Bad (avoid): "Amazing choice!" / "You can do it!" / anything with an exclamation stack.

**Rematch semantics:** `HP_DELTA` and `NEXT_FIGHT_PELLET_MOD` effects are consumed on `build_brott()` at match start. On rematch, these are already applied and do not re-apply — trick outcomes are one-shot per shop visit. This is intentional.

**BrottBrain voice — expanded style guide (S13.8):**

*Tone pillars:*
- **Cynical-but-caring.** BrottBrain would rather you not get hurt, but won't stop you. Mentor energy, not parent energy.
- **Concise.** ≤2 sentences, ideally ≤20 words total. If you need a third sentence, rewrite.
- **Situational humor.** Dark is fine. Mean isn't. Laugh with the player, not at them.
- **Voice of experience.** BrottBrain has seen this exact scam / crate / goblin before. It shows.
- **Present tense, concrete imagery.** "Goblin grunts." "Crate creaks." Not "The entity emits a sound."

*Good examples (pulled from existing tricks):*
- `"...looks like a crate. Could be good, could be rats."` — `crate_find`. Sets stakes in one hedged sentence.
- `"Scrap trader. Module for 15 bolts, or a quick haggle."` — `scrap_trader`. Pure situation report, no editorializing.
- `"Smart. +10 bolts."` — `rusty_launcher.choice_b`. Validates a cautious player without sycophancy.
- `"Got 'em. Lost some fur. -5 HP."` — `risk_for_reward.choice_a`. Reward and cost in the same breath.
- `"Wise. Boring, but wise."` — `risk_for_reward.choice_b`. Acknowledges the trade-off with a wink.

*Anti-patterns — do not ship:*
- **Long exposition.** ❌ `"Back in my day we had to scavenge for weeks to find a working minigun, and even then it'd jam half the time..."` Cut it.
- **Corporate voice.** ❌ `"You have encountered a vendor NPC. Please select a transaction option."` BrottBrain is not a UX writer.
- **Direct moral lessons.** ❌ `"This is a good lesson about the value of caution."` Show, don't preach.
- **Exclamation stacks / hype.** ❌ `"Amazing choice!!!"` / `"You got this!"` BrottBrain doesn't cheerlead.
- **Modern slang, em-dashes, rhetorical questions.** ❌ `"Bestie, no cap — are we really doing this?"`

*Writing guidance for future trick authors:*
- Voice BrottBrain as a tired mechanic friend who's seen everything, not a narrator describing events from above.
- If the line could appear in a tutorial tooltip verbatim, rewrite it — BrottBrain is never explanatory prose.
- Use `{item_name}` placeholders in `ITEM_GRANT`/`ITEM_LOSE` flavor lines; `shop_screen.gd` substitutes them before the modal shows the toast. Non-item effects leave the literal `{item_name}` visible — that's an authoring bug, not a feature.
- Rubric for a review pass: 1) Is it ≤2 sentences? 2) Would a tired mechanic say this? 3) Does it avoid the anti-patterns? If any answer is no, rewrite.

---

## 12. Player Fantasy

The core feelings we're targeting:

1. **"I'm a mad scientist."** — The joy of tinkering, building, and experimenting with different combinations. The garage/workshop is your lab.

2. **"My creation is alive."** — Watching your Brott make decisions autonomously based on YOUR BrottBrain. Pride when it does something clever. Horror when it does something stupid.

3. **"I taught it that!"** — The eureka moment when a Behavior Card tweak turns a losing matchup into a win. The satisfaction of outsmarting the enemy through teaching, not reflexes. Your Brott learned from you.

4. **"Just one more fight."** — The loop of lose → analyze → tweak → try again is addictive. Each loss teaches you something. Each win validates your design.

5. **"Wait, I can do THAT?"** — Discovering unexpected synergies between items and Behavior Cards. The Roach build (ambush + heal + flee) should feel like a discovery, not an obvious path.

6. **"Anyone can play."** — You don't need to know how to code. Drag a card, drop a card, watch your Brott fight. The depth is there for those who want it, but the barrier to entry is zero.

---

## 13. Roguelike Run Loop

*Source-of-truth section as of Arc F (S25.1–S25.10). This section supersedes the league-era flow described in §§2–7. League screens (Scrapyard / Bronze / Silver / Gold, shop, repair) are dormant in code and scheduled for removal in Arc G.*

### 13.1 Overview

BattleBrotts plays as a **15-battle roguelike run** rather than a persistent league career. Each run is self-contained:

- **Chassis pick starts a run.** The player chooses one of the three chassis (Scout / Brawler / Fortress) at run start. That chassis is locked for the duration of the run.
- **Weapons / armor / modules are earned through play.** The player does **not** shop for items. Each won battle offers a **reward pick** that adds an item to the loadout.
- **Death ends the run.** Three retries per run; once spent, an unrecovered loss takes the player to the BROTT DOWN screen and the run is over.
- **Victory = beat all 15 battles.** Battle 15 is the boss (CEO Brott). Defeating the boss takes the player to the RUN COMPLETE screen.

The roguelike loop replaces the league-era "build → teach → fight → analyze → iterate" loop documented in §2. BrottBrain teaching still happens — the BrottBrain editor surface is retained — but progression through tiers is now run-scoped, not account-scoped.

> **Arc N note:** Player chassis is fixed to Brawler (`chassis_type=1`). `run_start_screen.gd`
> shows a single "Start Run" button; chassis-select logic is preserved behind `#CUT:ArcN`
> for Arc O restoration.

### 13.2 RunState

A run is fully described by the `RunState` object (`godot/game/run_state.gd`), which is the **sole source of truth** for run-scoped data. Active fields:

| Field | Type | Purpose |
|---|---|---|
| `equipped_chassis` | `int` (ChassisType) | Locked at run start by chassis pick. |
| `equipped_weapons` | `Array[int]` | Weapons in the loadout. **Pre-seeded with Plasma Cutter** (`WeaponType.PLASMA_CUTTER == 4`) at run start so battle 1 is winnable (S26.1). Reward picks append to this list. |
| `equipped_armor` | `int` (ArmorType) | `ArmorType.NONE` at run start; set by reward picks. |
| `equipped_modules` | `Array[int]` | Empty at run start; reward picks append. |
| `current_battle_index` | `int` (0–14) | 0-indexed battle pointer. Battle 1 = index 0; boss = index 14. |
| `retry_count` | `int` (starts at 3) | Decrements when the player uses a retry on a lost battle. |
| `battles_won` | `int` | Incremented by `advance_battle_index()`. |
| `run_ended` | `bool` | Set when the run terminates (loss with no retries, or boss victory). |
| `encounter_schedule` | `Array[String]` (15 entries) | Pre-generated archetype IDs for the run, populated lazily on first call to `OpponentLoadouts.archetype_for()`. Stable across retries within a run. |
| `current_encounter` | `Dictionary` | `{archetype_id, tier, arena_seed}` for the active battle; consulted on retry to keep the same fight. |
| `seed` | `int` | RNG seed for deterministic encounter generation (0 = time-based). |

`GameState` (the league-era container) is kept as a dormant property on `GameFlow` for compatibility with `tools/test_harness.gd`. Active code paths in Arc F do **not** read from `GameState`. Arc G removes it.

### 13.3 15-Battle Structure

A run is exactly 15 battles. Battles map to **tiers** by index, and each tier has a **baseline HP** that scales archetype enemies:

| Tier | Battle index range | Battle # | Baseline enemy HP |
|---|---|---|---|
| **T1** | 0–2 | 1–3 | 120 |
| **T2** | 3–6 | 4–7 | 120 |
| **T3** | 7–10 | 8–11 | 160 |
| **T4** | 11–13 | 12–14 | 200 |
| **T5** | 14 | 15 (Boss) | 240 |

*(Source: `OpponentLoadouts.difficulty_for_battle()` and `_baseline_hp_for_tier()`, S25.6.)*

#### T1 Battle Timing Target (Arc J)

T1 battles (indices 0–2) target the following duration window for a player starting with Plasma Cutter + no armor against the typical encounter mix:

| Metric | Target | Rationale |
|---|---|---|
| Median battle duration | ≥20s | Minimum feel of "I got to watch a fight" |
| p90 battle duration | ≤60s | Upper cap: fights shouldn't drag |
| Win-rate per chassis | 30–70% | Balance signal: no chassis should be mandatory or useless at T1 |

**Calibration (Arc J):** T1 baseline HP increased from 80 to 120 (+50%) and `small_swarm` T1 weight reduced from 30 to 15 (standard_duel from 40 to 55) to reach the ≥20s median. Combat sim validation confirms these parameters in sprint-28.1.

**Calibration (Arc M, M.2):** T1 baseline HP increased from 120 to 150 (+25%) and `brawler_rush` T1 weight increased from 10 to 25 (`standard_duel` from 60 to 45) to correct over-soft T1 win rates (Scout 84%, Brawler 88%, Fortress 67% → targets per-chassis 55–70% / 45–65% / 40–55%). Combat sim re-validation confirmed post-merge.

Archetype `hp_pct` values (§13.4) multiply against the tier baseline at generation time, so the same archetype shape (e.g. Small Swarm) gets harder as the run progresses.

### 13.4 Encounter Archetypes

Encounters are drawn from a fixed catalog of archetypes (`ARCHETYPE_TEMPLATES` in `godot/data/opponent_loadouts.gd`). Six are usable in normal battles; the seventh (`boss`) is reserved for battle 15.

| Archetype ID | Display Name | Enemy Composition (per generation) |
|---|---|---|
| `standard_duel` | Standard Duel | 1 enemy: Scout chassis, Plasma Cutter, Plating, hp_pct 1.0 |
| `small_swarm` | Small Swarm | 3 enemies: Scout chassis, Plasma Cutter, no armor, hp_pct 0.6 |
| `large_swarm` | Large Swarm | 5–6 enemies, hp_pct overridden by tier (see below) |
| `miniboss_escorts` | Mini-boss + Escorts | 1 Fortress (Minigun + Shotgun, Ablative Shell, Shield Projector, hp_pct 1.5) + 2 Scout escorts (hp_pct 0.7) |
| `counter_build_elite` | Counter-Build Elite | Variant chosen dynamically by reading the player's loadout (anti-module / anti-range / anti-melee). |
| `glass_cannon_blitz` | Glass-Cannon Blitz | 2 enemies: Scout chassis, Railgun + Minigun, no armor, hp_pct 0.5 |
| `brawler_rush` | Brawler Rush | 1 enemy: Brawler chassis, Shotgun, no armor, hp_pct 0.75 |
| `boss` | CEO Brott | Battle 15 only (see §13.8). |

**Large Swarm tier override** (`LARGE_SWARM_HP_BY_TIER`, S25.6): hp_pct is decoupled from the template and set by tier — 0.2 (T1), 0.4 (T2), 0.7 (T3), 0.9 (T4) — with enemy count rising from 5 (T1–2) to 6 (T3–4).

#### Archetype mix weights (per tier)

Weights are relative (don't need to sum to 100). Picker excludes the immediately previous archetype to avoid back-to-back repeats.

| Archetype | T1 | T2 | T3 | T4 |
|---|---|---|---|---|
| `standard_duel` | 45 | 30 | 20 | 15 |
| `small_swarm` | 15 | 30 | 20 | 10 |
| `large_swarm` | 10 | 20 | 20 | 15 |
| `glass_cannon_blitz` | 5 | 10 | 5 | 10 |
| `brawler_rush` | 25 | — | — | — |
| `counter_build_elite` | — | 10 | 15 | 25 |
| `miniboss_escorts` | — | — | 20 | 25 |

*(Source: `ARCHETYPE_WEIGHTS_BY_TIER`, S25.6.)*

*(Sprint-28.2: `brawler_rush` added to T1 archetype pool for chassis variety — Arc J #295.)*

#### Run guarantees

Every run schedule is post-processed to guarantee at least one occurrence of each of these archetypes:

- `small_swarm` (default seed slot: battle index 4)
- `counter_build_elite` (default seed slot: battle index 8)
- `miniboss_escorts` (default seed slot: battle index 11)

If any required archetype is missing after the weighted draw, the schedule generator overwrites a tier-compatible later slot with the missing archetype to enforce the guarantee. *(Source: `_apply_run_guarantees()`, S25.6.)*

#### Battle 0 override (`first_battle_intro`)

**Battle 0 override (`first_battle_intro`):** Battle 1 (index 0) always draws the
`first_battle_intro` archetype, bypassing the weighted schedule. Cannot be drawn for
battles 2+. `archetype_for()` returns `"first_battle_intro"` unconditionally when
`battle_index == 0`, before schedule lookup.

Enemy spec: Scout chassis (0), Plasma Cutter (4), no armor, no modules.
`target_hp`: 750 (direct override, bypasses `baseline_hp × hp_pct`).
`speed_override`: 50 px/s. `fire_rate_override`: 0.4 shots/s.
Default stance: Aggressive (0). `use_first_battle_ai`: true (enables strafe/retreat, wired in Arc N.2).

#### Arc N.2 — First Battle AI Implementation Notes (`use_first_battle_ai`)

When `use_first_battle_ai` is `true` on a `BrottBrain`, the following canonical implementation
contract applies (wired in Arc N.2; referenced by `_evaluate_first_battle()`):

**`movement_override` string values:**

| Value | Behaviour |
|---|---|
| `"first_battle_advance"` | Close toward enemy at full effective speed (target._pos_snapshot). |
| `"first_battle_strafe"` | Lateral orbit at 30 px/s perpendicular to target, direction from `BrottBrain._strafe_direction`. |
| `"first_battle_retreat"` | Additive diagonal vector: lateral 30 px/s + backward 25 px/s (~39 px/s resultant). NOT re-normalized. |

**TCR bypass contract:**
`_evaluate_first_battle()` sets `movement_override` on every tick and returns before
the standard card-eval/TCR path runs. `combat_sim._move_brott()` dispatches on
`movement_override` before the TCR `else:` branch, so TCR never runs for FBI bots.

**Strafe state location:**
Private strafe direction state (`_strafe_direction`, `_strafe_flip_timer`) lives on
`BrottBrain`, not `BrottState`. This keeps render-layer state (`aim_telegraph_*`, `hovered`)
on `BrottState` and simulation state on `BrottBrain` — consistent with existing architecture.

**Combined retreat vector formula:**
`lateral(30 px/s) + backward(25 px/s)` applied additively, NOT re-normalized.
Resultant speed is ~39 px/s at 90° offset. The additive approach is intentional:
it keeps the strafe component and the retreat component each readable at design time
without requiring a normalization constant that would change both.

**Aim telegraph:**
`BrottState.aim_telegraph_active/progress` are driven by `combat_sim._fire_weapons()`
using the weapon cooldown as a proxy (0.75s window before shot at 10 tick/s → 7.5 tick threshold).
Guard: `b.brain != null and b.brain.use_first_battle_ai` — telegraph only fires for FBI enemies.
Reset occurs at fire time and when cooldown > 7.5 ticks.

### 13.5 Run Flow

```
MAIN_MENU
  → RUN_START      (player picks chassis)
  → ARENA          (battle N; encounter pre-resolved into RunState.current_encounter)
  → RESULT
      │
      ├─ win  → REWARD_PICK → advance_battle_index() → next ARENA
      │           (battle 15 win bypasses reward pick → RUN_COMPLETE)
      │
      └─ lose → RETRY_PROMPT
                  ├─ use retry  → same ARENA (current_encounter preserved, retry_count -= 1)
                  └─ accept loss→ BROTT_DOWN  (run_state retained for stats; end_run() called from "New Run" button)
```

Key invariants (`GameFlow`, S25.1–S25.7):
- A run is "active" iff `run_state != null` AND `current_battle_index < 15` AND `not run_ended` (`has_active_run()`).
- Retries replay **the same encounter** (archetype + arena seed are stored on `RunState.current_encounter`, not regenerated).
- `end_run()` clears `run_state`, sets `run_ended = true`, and routes to `MAIN_MENU`.

### 13.6 Reward Pick

After every won battle (battles 1–14), the player is shown the **REWARD_PICK** screen. The screen offers a small set of items drawn from a tier-appropriate pool; the player picks one, which is added to `RunState` via `add_item(category, type)`. `add_item()` is idempotent — already-equipped items return `false` and are no-ops.

Reward categories (matching `RunState.add_item` switch):
- `"weapon"` → appends to `equipped_weapons`
- `"armor"` → sets `equipped_armor` (single-slot, latest wins)
- `"module"` → appends to `equipped_modules`

The reward pick is the player's only loadout-growth surface during a run — there is no shop, no inventory, and no swap-out. Picks are permanent for the run.

*First-encounter coaching:* on the player's first reward pick across all runs, the FE intro `"first_reward_pick"` fires ("🎁 You won! Pick one reward to add to your build. It stays with you for the whole run.").

### 13.7 Click Overrides (Player Controls)

During a battle, the BrottBrain drives the player's bot autonomously — BattleBrotts is not a real-time action game. However, the player has **two click overrides** (S25.2) that layer on top of the AI:

- **Click-to-move (waypoint)** — Click on the arena floor to set a yellow **waypoint diamond**. The player's bot moves toward the waypoint until it arrives (then the waypoint fades over 0.4s), or until the player issues a new command. Setting a waypoint clears any active reticle.
- **Click-to-target (reticle)** — Click on an enemy to set an orange **reticle ring** on that target. The player's bot prioritizes that enemy until it dies, the reticle is cleared, or the player issues a new command. Setting a reticle clears any active waypoint.

Both overrides are **player-only** — enemy bots are not affected. Latest-wins semantics: only one of {waypoint, reticle} is active at a time. The reticle auto-clears when its target dies.

### 13.8 CEO Brott (Battle 15)

The boss encounter is fixed (`ARCHETYPE_TEMPLATES` `boss` entry) and runs at T5 baseline HP (240 × hp_pct 2.0 = 480 base HP):

- **Chassis:** Fortress
- **Weapons:** Railgun + Minigun *(`weapons: [1, 0]`)*
- **Armor:** Ablative Shell *(`armor: 3`)*
- **Modules:** Shield Projector + Sensor Array + EMP Charge *(`modules: [2, 3, 5]`)*

#### Boss AI (`BrottBrain.boss_ai()`, S25.9)

The boss runs a custom evaluator (`_evaluate_boss()`) instead of the baseline brain. Key rules:

1. **Executioner mode (movement-only).** When the player's HP drops below 30%, the boss locks Aggressive stance, disables kiting, and sets `movement_override = "chase"` to close distance. The boss never flees — Afterburner is explicitly excluded from all HP bands.
2. **EMP targets the player's active modules.** At any HP band, if the player currently has a module active (any non-zero `module_active_timers`), the boss will fire **EMP Charge** when ready. Above 60% HP, EMP is the top module priority; below 60%, Shield Projector takes priority and EMP is secondary.
3. **Shield Projector at low HP.** At HP ≤ 60% (and especially ≤ 40%) the boss prioritizes its own **Shield Projector** to extend the fight. Sensor Array has no explicit gating in the boss rule chain — it's part of the loadout but not actively prioritized.
4. **Default movement.** Above 30% player HP, the boss runs Aggressive stance with no kite, no movement override.

*(The 40% / 60% thresholds correspond to the boss's own HP percentage, not the player's. Source: `_evaluate_boss()` in `godot/brain/brottbrain.gd`.)*

### 13.9 Run-End Screens

- **BROTT DOWN** — shown when the player accepts a loss with `retry_count == 0`. Displays farthest threat seen this run (`_farthest_threat_name`) and offers "New Run" (which calls `end_run()` and returns to `MAIN_MENU`). `RunState` is retained on entry to BROTT DOWN so the screen can read run stats; it is cleared on "New Run".
- **RUN COMPLETE** — shown when the boss is defeated at battle 15. Displays best kill name this run (`_best_kill_name`) and offers "New Run".

### 13.10 Relationship to Deprecated Sections

§§2 (Core Loop), §4.1 (BrottBrain Progressive Disclosure schedule), §6 (League Progression), and §7 (Economy / shop / repair) describe the **league-era game flow** (Scrapyard → Bronze → Silver → Gold). That flow is **superseded by this section**. The corresponding screens (`SHOP`, `LOADOUT`, `BROTTBRAIN_EDITOR` as a separate gated screen, `OPPONENT_SELECT`) remain as **dormant enum values** in `GameFlow.Screen` but no active code path routes to them in Arc F. Arc G removes them.

What survives from §§2–7 into the roguelike era:
- **§3 Brott Customization** — chassis / weapons / armor / modules / slot system are unchanged.
- **§4.2–4.4 BrottBrain Behavior Cards / Stances / Examples** — the BrottBrain editor surface and card library are unchanged; only the league-gated unlock schedule is deprecated.
- **§5 Combat System** — tick system, damage formula, movement & targeting, line of sight are all unchanged. Click overrides (§13.7) are an additive layer on top of §5.3 movement.
- **§6.3 Opponent Archetype Taxonomy (S13.9)** — the archetype concept survives and is the foundation for §13.4. Specific tier weights are now defined in `ARCHETYPE_WEIGHTS_BY_TIER` (S25.6) rather than the league-era opponent select.
- **§8 Arena Design**, **§9 Match Format**, **§10 Art Direction**, **§11 Key Metrics**, **§12 Player Fantasy** — unchanged.

---

*This document is the source of truth for BattleBrotts' design. All implementation should reference this. Changes require Game Designer approval and updated version number.*

---

## Balance Changes v1

*Applied in Sprint 14 ([S14-001]) based on Optic's 1,500 combat simulation report (Sprint 12).*

| Change | Before | After | Rationale |
|---|---|---|---|
| Fortress HP | 250 | 210 | 80.3% WR — too tanky |
| Fortress Speed | 70 | 60 | Reduce dominance, increase kiting windows |
| Scout HP | 80 | 100 | 15.7% WR — died too fast |
| Scout Speed | 200 | 220 | Improve survivability through mobility |
| Minigun Damage | 4 | 3 | 47% shot share — too dominant |
| Minigun Energy Cost | 1 | 2 | Increase energy pressure |
| Railgun Fire Rate | 0.5 | 0.6 | Buff to compete with Minigun |
| Railgun Energy Cost | 20 | 16 | Reduce energy barrier |
| Repair Rate (Win) | 10% | 5% | Economy death spiral fix |
| Repair Rate (Loss) | 25% | 15% | Economy death spiral fix |
| First-Win Bonus | 150 🔩 | 200 🔩 | Reward exploration, offset repair costs |

---

## Balance Changes v2

*Applied in Sprint 15 ([S15-001]) based on Optic's 1,530 combat simulation report (Sprint 14). V1 changes were too conservative — Fortress still at 78.6% WR, Scout at 20.1%.*

| Change | Before | After | Rationale |
|---|---|---|---|
| Fortress Weapon Slots | 3 | 2 | 78.6% WR — 3 weapons + 210 HP is too much firepower. Biggest single lever. |
| Scout Dodge Chance | 0% | 15% | New passive evasion mechanic. Represents speed advantage defensively. |
| Minigun Fire Rate | 10 shots/s | 6 shots/s | Fire rate is what makes Minigun dominant (constant DPS uptime). DPS drops from 30 to 18. |
| Repair Cost (Win) | 5% of equipment | 20 🔩 flat | Eliminates death spiral — flat costs don't scale with equipment value |
| Repair Cost (Loss) | 15% of equipment | 50 🔩 flat | Eliminates death spiral — flat costs don't scale with equipment value |

## Balance Changes v3

*Applied in Sprint 16 ([S16-001]) based on Optic's 2,000 combat simulation report (Sprint 15). V2 brought Fortress from 78.6% → 72.9% WR and Scout stayed at 20.4% — structural weapon slot deficit is the root cause.*

| Stat | Old | New | Rationale |
|------|-----|-----|-----------|
| Scout Weapon Slots | 1 | 2 | 20.4% WR — 1 weapon slot is THE structural problem. Scout can't compete in DPS with a single weapon. |
| Fortress HP | 210 | 180 | 72.9% WR — further nerf to survivability to bring Fortress in line with target 45-55%. |
| Minigun Cost | Free (starter) | 50 🔩 | Price-gate Minigun so it's not the default weapon for every build. Creates meaningful early-game choice. |
| Plasma Cutter Damage | 12 | 14 | Make Plasma Cutter a more viable starter alternative now that Minigun costs bolts. |

## Balance Changes v4 (S13.3 Chassis Balance Pass)

*Applied in Sprint 13.3 based on Gizmo's post-TCR analysis. S13.2 TCR worked in mirrors but cross-chassis matchups were catastrophic (Scout vs Fortress 100-0, Brawler vs Fortress 100-0). Four numeric levers, no architectural changes.*

| Lever | Change | Rationale |
|---|---|---|
| **Commit speed cap** | `min(base × 1.4, 200 px/s)` | Scout's 308 px/s commit dash crossed the entire engagement band in a single 0.8s window. Cap clips only Scout's commit (to 200 px/s), leaving Brawler/Fortress unaffected, preserving chassis identity. Biggest single lever. |
| **Per-chassis TCR** | Scout: 2.5–4.0/0.6/1.5s · Brawler: 2.0–3.5/0.8/1.2s (baseline) · Fortress: 1.5–2.5/1.2/0.9s | Distinct combat rhythm per chassis creates counterplay. Fortress's longer COMMIT (1.2s at 84 px/s = 101 px) finally covers meaningful ground per cycle; short TENSION means more time dealing damage, less time orbiting. |
| **Scout HP** | 100 → 110 (spec) · 150 → 165 (engine) | Scout mirror matches were ending in ~10s. +10% HP pushes mirror TTK toward the 15–20s band without eroding Scout's glass-cannon identity. |
| **Fortress HP** | 180 → 220 (spec) · 270 → 330 (engine) | Mobility gap remains even after commit cap. HP buff partially compensates; Fortress should be a wall. |
| **Brawler HP** | 150 → 150 (spec) · 225 → 225 (engine) | Untouched \u2014 baseline chassis. |
| **Pellet instrumentation** | Split `shots_*` (per-trigger) from `pellets_*` (per-projectile) | Pre-S13.3 engine conflated the two, producing shotgun hit rates >100% (Specc KB finding #3). Canonical balance metric is now per-pellet; per-shot is retained as a "did any pellet land?" narrative stat. |

> **Engine HP note:** GDD §3.1 specifies design HP (110/150/220); the engine
> stores those values \u00d7 1.5 as a pacing multiplier dating from Sprint 4
> (`[S4-005] Pacing v3`). Both numbers above are shown for clarity. Tests and
> reports use the engine values.

**S13.3 results (N=100 per matchup, default loadouts, no armor, no modules):**
See PR description for the 6-matchup table.

### S13.4 — No balance changes (UI-only)

Sprint 13.4 is a **UI-only pivot** to the Shop Card Grid (see §10 Art Direction → Shop Card Grid). No chassis, weapon, armor, or module numbers were touched. The only data change is `ArmorData.archetype` values normalized to `Light` / `Adaptive` / `Heavy` for consistent card-tag display — this is a naming change, not a balance change.

The next balance pass is **S14 Fortress Loadout Pass**, which will address residual cross-chassis gaps at the loadout level (Fortress long-range identity, Scout-vs-Brawler asymmetry, mirror TTM floor). See design handoff in `docs/design/sprint13.4-shop-card-grid.md` §6.

### S13.5 — No balance changes (UI/UX polish only)

Sprint 13.5 is UI/UX polish only. No economy, prices, items, chassis, weapons, armor, or modules changed. See §10 Art Direction → Shop Polish (S13.5) for scope. Fortress loadout pass still owed to S14.

### S13.6 — No combat balance changes

Sprint 13.6 ships BrottBrain Scrapyard Trick Choice (see §11 → BrottBrain Trick Choices). Trick effects are small session-scoped deltas — `±10` bolts, `±5` HP, `+1..3` pellets on the next fight — intentionally small so they shape voice/risk flavor without moving the chassis WR balance. No chassis, weapon, armor, or module stats were touched; `ITEM_GRANT`/`ITEM_LOSE` tokens (e.g. `random_weak`) are stubbed no-ops for this sprint and will be wired after the inventory model accepts string tokens.

### S13.7 — Item token router + trick content expansion

Sprint 13.7 wires real item grants/losses for BrottBrain tricks (unblocking the S13.6 F1 scavenger_kid stub) and expands the trick pool from 3 → 6. No chassis/weapon/armor/module stats changed.

**Item token taxonomy** (`godot/data/item_tokens.gd`):

- **Direct tokens** — one-to-one with a concrete item, e.g. `"minigun"` → `{category: CAT_WEAPON, type: WeaponType.MINIGUN}`. Names are the lowercased enum identifier. Direct token set: all 7 weapons, 3 non-NONE armors, 6 modules.
- **Pool tokens** — resolve by picking a direct token from a named pool, then recursing once. Unknown pools or empty pools return `{}` (silent no-op at the call site). The router never loops.
- **Pool conventions:**
  - `random_weak` — grab-bag of starter-tier items across weapons, armor, and modules. Used for cheap rewards (e.g. `crate_find`, `scavenger_kid`) and ITEM_LOSE (e.g. `toll_goblin`).
  - `random_module` — modules only, used for module-shaped rewards (e.g. `scrap_trader` buying a module).

**Adding new items or pools:** append an entry to `ItemTokens.DIRECT` (matching a real enum value in the corresponding `*_data.gd`) for new items; append a new named entry to `ItemTokens.POOLS` (entries must be valid DIRECT token strings — validated by test 16 in `test_sprint13_7.gd`) for new pools. `GameState._grant_trick_item` / `_lose_trick_item` automatically handle any new category or pool via the router — no GameState change needed for new tokens.

**S13.7 new tricks:** `crate_find` (ITEM_GRANT random_weak), `toll_goblin` (ITEM_LOSE random_weak + BOLTS_DELTA +5), `scrap_trader` (BOLTS_DELTA -15 + ITEM_GRANT random_module). `ITEM_GRANT` is idempotent (no duplicates); `ITEM_LOSE` is a safe no-op when the item isn't owned. Floor toast for item grants is deferred to S13.8.

---

## 14. Testing Infrastructure

*Source-of-truth section as of Arc I (S(I).1+). Documents the auto-driver concept that lets agents and CI exercise full user flows without a renderer.*

BattleBrotts uses a three-pillar testing strategy. **Pillar 1** is a native GDScript **AutoDriver** harness that boots the main scene under `godot --headless --script`, ticks the scene tree, and exercises full user flows (menu → run start → chassis pick → arena → first tick) in ~10 seconds. It runs as a per-PR gate inside the existing `verify.yml` `godot-tests` job and is the fastest signal that a player-facing flow is broken end-to-end. **Pillar 2** (arc-close gate) is a `window.bb_test` JavaScript bridge driven by Playwright against the web export, used for renderer-dependent flows. **Pillar 3** is a combat-sim agent that runs N parallel matches nightly and aggregates balance stats. The AutoDriver exposes a tightly-scoped action API (≤6 verbs: `click_chassis`, `click_reward`, `tick(n)`, `get_arena_state`, `get_run_state`, `force_battle_end`) so agent-authored flows stay readable and the surface stays auditable.

