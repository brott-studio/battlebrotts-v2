# Design Spec: Combat Stalemate Fix

**Author:** Gizmo (Game Designer)
**Date:** 2026-04-16
**Sprint:** TBD (for Nutts)
**Status:** DESIGN READY

---

## Problem Statement

CD playtested Scrapyard and observed: both bots rush center, collide within ~1 second, get stuck overlapping/adjacent, then stand still shooting and mostly missing for the remaining 60+ seconds. Only 1 hit landed in a full minute. This violates the core player fantasy ("holding your breath watching if the next shots will hit") and makes the game look broken on first impression.

**Root cause chain:**
1. Scrapyard bots both use Aggressive stance ("close to within shortest weapon range")
2. Both have Plasma Cutter (1.5 tile range) → target distance = 1.5 tiles → effectively 0 after collision
3. Collision system says "slide along the surface" but provides no separation force → bots get stuck touching
4. At 0 distance, bots may be inside each other's hitbox or at angles where hit detection fails
5. No behavior exists to separate, reposition, or circle — just "move toward enemy" forever

---

## Options Analysis

### Option 1: Minimum Engagement Distance

**Description:** Aggressive stance targets `weapon_range × 0.7` instead of `0`. Bot approaches to optimal distance, then holds position. If closer than `weapon_range × 0.4`, bot backs away.

**Pros:**
- Simple to implement (modify stance movement target)
- Immediately fixes the rush-and-stick problem
- Creates natural standoff distance that looks like a firefight

**Cons:**
- Two bots with the same weapon settle at the same distance and stand still → still boring (just further apart)
- Doesn't create dynamic movement during combat
- Backing-away logic can look weird (robots moonwalking)

**Player experience:** Better than current, but still mostly static. 5/10.

---

### Option 2: Separation Force (Physics Repulsion)

**Description:** When two bots' hitboxes overlap or are within 0.5 tiles of each other, apply a repulsion vector that pushes them apart at 50% of their move speed.

**Pros:**
- Prevents the stuck-together state entirely
- Simple physics, easy to implement
- Works regardless of stance or weapon

**Cons:**
- Only fixes the overlap symptom, not the "rush to center and stand still" behavior
- Bots still converge to the same spot — they just vibrate near each other
- Feels like a band-aid, not a real behavior improvement

**Player experience:** Fixes the worst case but doesn't make fights interesting. 4/10.

---

### Option 3: Weapon Minimum Range

**Description:** Weapons have a minimum effective range (e.g., Plasma Cutter: 0.5 tiles, Shotgun: 1 tile). Inside minimum range, weapon cannot fire or deals 50% damage.

**Pros:**
- Creates mechanical reason to maintain distance
- Adds a new balance lever per weapon
- Could create interesting close-range vs. long-range dynamics

**Cons:**
- Doesn't help if bots have no behavior to respond to "can't fire" — they'll just stand there NOT shooting, which is worse
- Adds complexity to weapon table
- Unintuitive for players ("why isn't my gun working?")

**Player experience:** Worse without matching AI improvements. 3/10.

---

### Option 4: Smarter Aggressive Stance (Optimal Range Targeting)

**Description:** Redefine Aggressive to seek `weapon_range × 0.6` (the "sweet spot") instead of minimum range. Add micro-repositioning: when at target distance ±0.5 tiles, bot strafes laterally instead of standing still.

**Pros:**
- Directly fixes the "rush to zero" behavior
- Strafing at optimal range looks like actual combat
- Works within existing system, no new mechanics

**Cons:**
- Only affects Aggressive stance — other stances could have similar issues
- Strafing pattern is predictable if always the same direction
- Doesn't address what happens when bots DO end up touching

**Player experience:** Good — bots fight at range and move laterally. 7/10.

---

### Option 5: Combat Choreography System

**Description:** Add a movement sub-system that runs alongside stances. When a bot is within its engagement range and has line of sight, it enters "combat movement" mode:
- **Orbit:** Bot circles the target at current distance (direction randomized per engagement, flips on wall collision)
- **Juke:** Every 1.5–3s (randomized), bot briefly moves toward or away from target by 1–2 tiles, then returns to orbit
- **Separation:** If within 1 tile of any bot, immediately move perpendicular to the line between them until at 1.5+ tiles

**Pros:**
- Fights look dynamic and exciting — bots actually MOVE during combat
- Randomized timing creates tension ("will this shot land?")
- Works for ALL stances (each stance modifies the orbit distance and juke frequency)
- Separation prevents the stuck-together state
- Scales well to 2v2 and 3v3

**Cons:**
- Most complex to implement
- Needs tuning to not look erratic
- Juking could accidentally dodge INTO danger

**Player experience:** Excellent — this is the "two robots actually fighting" fantasy. 9/10.

---

### Option 6: Engagement Distance Per Stance (Hybrid)

**Description:** Each stance defines an `engagement_range_factor` applied to the bot's shortest weapon range. When in engagement range, bot uses combat movement (orbit + juke). Add a hard separation threshold.

| Stance | Engagement Factor | Orbit Speed | Juke Frequency | Juke Distance |
|--------|------------------|-------------|----------------|---------------|
| Aggressive | 0.7× weapon range | 80% move speed | Every 2s | 1.5 tiles |
| Defensive | 1.0× weapon range | 60% move speed | Every 3s | 1 tile |
| Kiting | 0.8× weapon range | 100% move speed | Every 1.5s | 2 tiles |
| Ambush | N/A (stationary) | 0 | N/A | N/A |

**Pros:** Combines best of Options 4 and 5. Each stance feels distinct in combat.
**Cons:** Same complexity concerns as Option 5.

**Player experience:** 9/10.

---

## Recommendation: Option 5 + 2 (Combat Choreography + Separation Force)

### The Full Design

#### A. Separation Force (Safety Net)

When two bots' centers are within **1.0 tile** (32 px) of each other:
- Apply repulsion vector away from the other bot
- Repulsion speed: **60% of bot's base move speed**
- This is a physics-level guarantee — no bot should ever be stuck overlapping another

**Numbers:**
- Separation threshold: 1.0 tile (32 px center-to-center)
- Repulsion speed: `base_speed × 0.6`
- Scout repulsion: 132 px/s, Brawler: 72 px/s, Fortress: 36 px/s

#### B. Combat Movement System

When a bot has a target in LoS and is within weapon range, it enters **Combat Movement** mode. This replaces the current "move toward target and stop" behavior.

**B1. Engagement Distance**

Each stance now defines an **ideal engagement distance** (not "close to zero"):

| Stance | Ideal Distance | Tolerance Band |
|--------|---------------|----------------|
| Aggressive | `shortest_weapon_range × 0.65` | ±0.5 tiles |
| Defensive | `longest_weapon_range × 0.85` | ±1.0 tiles |
| Kiting | `longest_weapon_range × 0.70` | ±1.0 tiles |
| Ambush | N/A (hold position) | N/A |

For Scrapyard bots (Scout + Plasma Cutter, range 1.5 tiles, Aggressive):
- Ideal distance = 1.5 × 0.65 = **~1.0 tile**
- Tolerance = 0.5–1.5 tiles

For a Brawler + Shotgun (range 3, Aggressive):
- Ideal distance = 3 × 0.65 = **~2.0 tiles**

**Approach behavior:** If further than ideal + tolerance, move toward target. If closer than ideal − tolerance, back away. If within tolerance band → orbit.

**B2. Orbit**

When within the tolerance band:
- Bot moves **perpendicular** to the vector between itself and target
- Direction: randomized (CW or CCW) at start of each engagement, flips when hitting a wall or arena boundary
- Orbit speed: **70% of base move speed**
- This creates the "circling" look of two fighters sizing each other up

**Numbers:**
- Scout orbit: 154 px/s
- Brawler orbit: 84 px/s
- Fortress orbit: 42 px/s

**B3. Juking**

While in combat movement, bots periodically **juke** — a brief burst toward or away from the target:
- Juke interval: randomized between **1.5–3.0 seconds** (uniform distribution)
- Juke type: 60% chance lateral (perpendicular, flip orbit direction), 30% close (toward target by 1 tile), 10% retreat (away by 1 tile)
- Juke duration: **0.4 seconds** (8 ticks)
- Juke speed: **120% of base move speed**
- After juke ends, resume orbit

This creates the unpredictability that makes watching fights exciting. "Is this juke going to move them into that railgun shot?"

**B4. Re-engagement**

If target breaks LoS (moves behind cover):
- Bot exits combat movement
- Resumes stance-based pathfinding to reacquire target
- Re-enters combat movement when LoS reestablished and within range

#### C. Scrapyard-Specific Impact

With these changes, a Scrapyard match (two Scouts, Plasma Cutters, Aggressive) plays out like:

1. **0–2s:** Both bots rush toward each other (unchanged)
2. **~2s:** They reach engagement distance (~1 tile apart). Combat movement activates.
3. **2–60s:** Bots orbit each other, juking unpredictably. Plasma Cutters fire 3×/sec at 1-tile range. Some shots connect during stable orbit, some miss during jukes. Damage accumulates steadily.
4. **Expected TTK:** With 14 damage/hit, 0° spread at 1 tile, ~70% hit rate during orbiting, ~40% during jukes → avg ~8 damage/sec after armor → Scout (100 HP, Plating 20% reduction) dies in ~16 seconds.

This is right in the Scrapyard TTK target of 15–30s. ✓

#### D. What This Changes in Code

1. **New: `separation_force`** — Applied in Movement phase (tick step 4). If any bot center within 1.0 tile, apply repulsion vector.
2. **Modified: Stance movement logic** — Replace "move to target" with engagement distance + tolerance band system.
3. **New: `CombatMovement` state** — Orbit + juke sub-behaviors. Activated when in engagement range with LoS.
4. **Modified: Aggressive stance definition** — "Close to within shortest weapon range" → "Close to 65% of shortest weapon range, then orbit."

#### E. GDD Text Update (Section 4.3)

Replace the Aggressive stance row:

| Stance | Friendly Name | Movement Behavior | Engagement Behavior |
|---|---|---|---|
| **Aggressive** | 🔥 "Go Get 'Em!" | Move toward nearest enemy. Enter combat movement at 65% of shortest weapon range (orbit + juke). | Fire all weapons as soon as in range. Prioritize DPS uptime. |

Add new subsection after 5.3:

> ### 5.3.1 Combat Movement
> When a Brott has LoS to its target and is within weapon range, it enters combat movement. The Brott orbits its target at its stance's ideal engagement distance, periodically juking laterally, forward, or backward. This creates dynamic, watchable fights where positioning matters.
>
> **Separation force:** If two Brotts' centers are within 1.0 tile, a repulsion force pushes them apart at 60% of their base speed. This prevents Brotts from getting stuck overlapping.

---

## Acceptance Criteria (for Optic)

1. **No overlap stalemate:** In 1,000 Scrapyard simulations (Scout vs Scout, Aggressive, Plasma Cutter), 0% of matches should have bots stuck within 0.5 tiles for more than 2 consecutive seconds.
2. **Movement during combat:** Average distance traveled per bot after first engagement should be >5 tiles per match (currently ~0).
3. **Hit rate:** Plasma Cutter at 1-tile orbit distance should land 60–80% of shots (not 0%, not 100%).
4. **TTK in Scrapyard:** 15–30 seconds for Scout vs Scout.
5. **Match pacing:** At least 1 position change (juke or orbit direction flip) every 3 seconds during combat.
6. **No moonwalking:** Bots should never back up in a straight line for more than 1 tile. Backing away should transition into orbit.
7. **Existing stances preserved:** Kiting circle-strafe behavior should still work (it's already an orbit — just ensure it integrates with the new system rather than conflicting). Defensive and Ambush stances should not orbit.
8. **Regression:** All existing balance metrics (chassis WR, weapon usage, economy flow) should remain within ±5% of current values.

---

## Priority

**HIGH.** This is the first thing a new player sees. If Scrapyard looks broken, they close the game. This should ship before any new content.

---

*Gizmo out. Make 'em dance, Nutts.* 🤖💃
