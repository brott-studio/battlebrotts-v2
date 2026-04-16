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
| **Scout** | 100 | 220 | 30 kg | 2 | 3 | 15% dodge chance |
| **Brawler** | 150 | 120 | 55 kg | 2 | 2 | — |
| **Fortress** | 180 | 60 | 80 kg | 2 | 1 | — |

Base chassis weight is excluded from the weight budget — only equipped items count against capacity.

### 3.2 Weapons

| Weapon | Damage | Range (tiles) | Fire Rate (shots/s) | Spread (°) | Energy/Shot | Weight (kg) |
|---|---|---|---|---|---|---|
| **Minigun** | 3 | 5 | 6 | 15 | 2 | 10 |
| **Railgun** | 45 | 12 | 0.6 | 0 | 16 | 15 |
| **Shotgun** | 6×5 pellets | 3 | 1.5 | 30 | 8 | 12 |
| **Missile Pod** | 30 (splash r=1 tile) | 8 | 0.8 | 5 | 12 | 18 |
| **Plasma Cutter** | 14 | 1.5 | 3 | 0 | 4 | 8 |
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

**TCR State Machine:** Each bot cycles through three phases:

1. **TENSION** (2.0–3.5s randomized):
   - Orbits at 55% base speed
   - Weapons fire normally
   - Small lateral drifts ±0.3 tiles perpendicular every 1.0s
   - When timer expires → COMMIT

2. **COMMIT** (0.8s):
   - Dashes toward target at 140% base speed
   - Closes to `ideal_engagement_distance - 1.5 tiles` (minimum 0.5 tiles from target)
   - Straight line — no orbit
   - Weapons fire at normal rate (spread weapons land more at close range)
   - When timer expires → RECOVERY

3. **RECOVERY** (1.2s):
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

---

## 7. Economy

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
