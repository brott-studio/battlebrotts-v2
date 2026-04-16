# Sprint 12 — Design Spec: Charm & Polish Pass

**Author:** Gizmo (Game Designer)
**Date:** 2026-04-16
**Creative Direction:** "Wall-E style robots — mechanical, weighty, slightly clumsy."

---

## 1. Robot Movement Physics

**Player Fantasy:** "My bot is a real machine with weight and momentum — not a cursor sliding on ice."

### Spec

Each chassis gets acceleration, deceleration, and turn-speed values. Movement is no longer instant — bots ramp up and ramp down.

| Chassis | Max Speed (px/s) | Accel (px/s²) | Decel (px/s²) | Turn Speed (°/s) | Turn Accel (°/s²) |
|---------|------------------|---------------|---------------|-------------------|--------------------|
| **Scout** | 220 | 660 | 880 | 360 | 720 |
| **Brawler** | 120 | 240 | 360 | 240 | 480 |
| **Fortress** | 60 | 90 | 150 | 150 | 300 |

**Derived feel:**
- **Scout:** 0→max in ~0.33s. Zippy but still has perceptible ramp. Stops in ~0.25s.
- **Brawler:** 0→max in ~0.50s. Noticeable momentum. Stops in ~0.33s.
- **Fortress:** 0→max in ~0.67s. Heavy, deliberate. Stops in ~0.40s. You FEEL the weight.

**Turn speed** is how fast the bot can change its facing direction. Bots must turn toward their movement target — they don't snap. This is purely visual; movement direction changes are governed by acceleration (the bot can begin moving in a new direction immediately, but the sprite rotates at turn speed). This creates the "chunky mechanical" feel without impacting gameplay fairness.

**Afterburner interaction:** During Afterburner boost, acceleration is also multiplied by 1.8× (not just max speed). Deceleration remains unchanged — the bot overshoots when the boost ends. This creates a satisfying "rocket brake" moment.

**Combat movement interaction:** Orbit speed (70% of base) and juke bursts (120% of base) are still subject to acceleration curves. Jukes feel punchier on lighter bots and more lumbering on heavy ones.

### Acceptance Criteria
- [ ] Each chassis accelerates at its specified rate (measure px/s² in sim)
- [ ] Each chassis decelerates at its specified rate when stopping or reversing
- [ ] Bot sprites rotate at turn speed (not instant snap)
- [ ] Fortress takes visibly longer to reach full speed than Scout
- [ ] Afterburner multiplies acceleration by 1.8× during boost
- [ ] Combat orbit/juke still functions correctly with acceleration curves
- [ ] Run 1,000 sims: no stuck bots, no oscillation bugs from accel/decel fighting

---

## 2. Visual Loadout (Bot Preview)

**Player Fantasy:** "I'm in the garage building my robot. I see every piece go on."

### Spec

The bot preview in the loadout screen is a larger version of the in-game bot sprite (96×96 px, 4× scale) that dynamically reflects equipped items.

**Visual layers (bottom to top):**
1. **Chassis base** — the core body shape (differs per chassis type)
2. **Armor overlay** — wraps around the chassis. Each armor type has a distinct silhouette:
   - Plating: thick angular plates on front and sides
   - Reactive Mesh: glowing wire-frame mesh pattern
   - Ablative Shell: bulky rounded shell encasing the whole bot
3. **Weapon mounts** — weapons appear at fixed mount points:
   - Slot 1: right side of chassis
   - Slot 2: left side of chassis
   - Each weapon has a recognizable silhouette (Minigun = barrel cluster, Railgun = long barrel, Shotgun = wide barrel, etc.)
4. **Module indicators** — small icons/lights on the chassis body:
   - Each equipped module adds a small glowing element (color-coded)
   - Overclock: orange light, Repair Nanites: green light, Shield Projector: blue light, Sensor Array: yellow light, Afterburner: red light, EMP Charge: purple light

**Animation:** When an item is equipped, it slides/snaps onto the bot with a brief mechanical animation (0.3s tween + 2-frame "clunk" shake). When removed, it detaches and fades (0.2s).

**In-game:** The in-game 24×24 sprite also reflects equipped weapons (simplified — just the weapon silhouette on the side of the bot). Armor changes the bot's outline/color slightly. Modules are NOT visible in-game (too small).

### Acceptance Criteria
- [ ] Bot preview updates in real-time when any item is equipped/unequipped
- [ ] All 7 weapons have distinct silhouettes visible on the preview
- [ ] All 3 armor types change the bot's appearance visibly
- [ ] All 6 modules show as colored indicator lights on the preview
- [ ] Equip animation plays (0.3s snap + shake)
- [ ] Unequip animation plays (0.2s detach + fade)
- [ ] In-game sprites show weapon silhouettes and armor outline changes
- [ ] Preview works correctly for all 3 chassis types

---

## 3. Clear Equipped State (Loadout UI)

**Player Fantasy:** "I can see at a glance what's on my bot and what's in my inventory."

### Spec

**Equipped items:**
- Card background: **bright blue** (#4A90D9) with a subtle glow border
- A small **checkmark badge** (✓) in the top-right corner of the card
- Card is **slightly elevated** (2px drop shadow) to pop off the list
- Item name rendered in **bold white**

**Unequipped (inventory) items:**
- Card background: **dark grey** (#3A3A3A), no border glow
- No badge
- Flat (no shadow)
- Item name in **regular grey** text

**Slot indicators on the bot preview:**
- Empty weapon/module slots show as **dashed outline rectangles** with a "+" icon
- Filled slots show the item (per section 2)

**Weight budget bar:**
- Positioned below the bot preview
- Shows current weight / max weight
- Color: green (0-70%), yellow (70-90%), red (90-100%)
- Overweight: bar turns red and flashes, equip button disabled

### Acceptance Criteria
- [ ] Equipped cards are visually distinct from unequipped at a glance (color + badge + shadow)
- [ ] Empty slots are clearly indicated with dashed outlines and "+" icon
- [ ] Weight budget bar updates in real-time when items are equipped/unequipped
- [ ] Weight bar changes color at 70% and 90% thresholds
- [ ] Overweight state prevents equipping and shows visual feedback
- [ ] Screen-reader accessible: equipped state is reflected in item label text

---

## 4. Plasma Cutter Range Buff

**Player Fantasy:** "Close-range brawler weapon that rewards aggressive positioning."

### Spec

| Stat | Before | After | Rationale |
|------|--------|-------|-----------|
| Range | 1.5 tiles | 2.5 tiles | At 1.5, bots almost never close enough to fire. 2.5 puts it in the "melee range band" (0-2 tiles) with some breathing room. |
| Damage | 14 | 14 | No change — DPS is already good IF it fires. |
| Fire Rate | 3 shots/s | 3 shots/s | No change. |
| Energy/Shot | 4 | 4 | No change. |
| Weight | 8 kg | 8 kg | No change. |

**Design intent:** Plasma Cutter is the close-range DPS king. At 2.5 tiles and 42 DPS (14 × 3), it out-damages everything at melee range. The trade-off is the player MUST design a BrottBrain that closes distance. It rewards Aggressive stance and Afterburner combos.

**Interaction with combat movement:** With 2.5 tile range, an Aggressive Brott's ideal engagement distance is 2.5 × 0.65 = 1.625 tiles. This keeps the bot very close while orbiting — visually exciting, high-risk gameplay.

### Acceptance Criteria
- [ ] Plasma Cutter fires at targets up to 2.5 tiles away
- [ ] Plasma Cutter does NOT fire beyond 2.5 tiles
- [ ] Run 1,000 sims with Plasma Cutter builds: fire rate > 0 in at least 80% of matches (was ~10% at 1.5 range)
- [ ] "Roach" example build (Scout + Plasma Cutter + Ambush) is still viable
- [ ] Plasma Cutter DPS in practice lands between Shotgun and Minigun for close-range matchups

---

## 5. Overtime Threshold: 60s → 45s

**Player Fantasy:** "Matches have urgency. The clock is always ticking."

### Spec

| Parameter | Before | After |
|-----------|--------|-------|
| Overtime trigger | 60s | 45s |
| Sudden Death trigger | 75s | 60s |
| Match timeout | 120s | 100s |
| Arena shrink rate | 0.5 tiles/s | 0.5 tiles/s (unchanged) |

**Reasoning:** CD feedback says overtime feels too late. At 45s, even an evenly-matched fight will feel the pressure before the 1-minute mark. Sudden Death at 60s means the climax hits right at the "target match length" center (45s for 1v1). Timeout shortened proportionally.

**2v2/3v3 adjustment:** Overtime at 60s, Sudden Death at 75s, Timeout at 120s (unchanged for team modes — more bots need more time).

| Mode | Overtime | Sudden Death | Timeout |
|------|----------|--------------|---------|
| 1v1 | 45s | 60s | 100s |
| 2v2 | 60s | 75s | 120s |
| 3v3 | 60s | 75s | 120s |

**Target match length updated:**
- 1v1: 25–50s (was 30–60s)
- 2v2/3v3: 45–90s (unchanged)

### Acceptance Criteria
- [ ] 1v1 overtime triggers at exactly 45s
- [ ] 1v1 Sudden Death triggers at exactly 60s
- [ ] 1v1 timeout at 100s
- [ ] 2v2/3v3 overtime at 60s, Sudden Death at 75s, timeout at 120s
- [ ] "OVERTIME!" banner appears at correct threshold per mode
- [ ] "SUDDEN DEATH!" banner replaces at correct threshold per mode
- [ ] Run 2,000 1v1 sims: median match length is 35–50s
- [ ] Run 2,000 1v1 sims: timeout rate < 3%
- [ ] Arena shrink math still prevents escape (shrink starts at 45s, arena fully collapsed by ~85s for 20-tile arenas)

---

## 6. Overall Charm — Bot Personality & Feel

**Player Fantasy:** "These aren't sprites. These are little guys with personality."

### 6a. Movement Personality

Each chassis has a distinct **idle animation** and **movement quirk:**

| Chassis | Idle Animation | Movement Quirk |
|---------|---------------|-----------------|
| **Scout** | Slight hover-bob (1px up/down, 0.8s cycle) | Occasionally does a quick 360° spin when changing direction (10% chance on direction change) |
| **Brawler** | Subtle side-to-side rock (1px, 1.2s cycle) | Small dust puff particles when starting movement from standstill |
| **Fortress** | Slow mechanical breathing (0.5px up/down, 2.0s cycle) | Screen micro-shake (0.5px, 0.1s) when Fortress starts or stops moving. Visible gear-grinding particle on deceleration. |

### 6b. Equip Feedback

Beyond the animation in Section 2:
- **Sound cue:** Mechanical "clunk" on equip, "whirr-click" on unequip (design note for audio — can be placeholder SFX initially)
- **Bot reaction:** Bot preview does a small "nod" (2px down, 2px up, 0.2s) when an item is equipped, as if acknowledging the new part
- **Weight feedback:** When equipping a heavy item (>12 kg), the bot preview sinks slightly (1px) and bounces back — it FELT that weight

### 6c. Victory / Defeat Reactions

| Event | Winner Reaction | Loser Reaction |
|-------|----------------|----------------|
| **Match End** | Bot does a small spin + jump (4px up, 0.3s) — like a happy hop | Bot slumps down (2px, stays down for 0.5s), then sparks fly from chassis |
| **Perfect Win (100% HP)** | Double spin + slightly bigger jump (6px) | Same as normal loss |
| **Close Win (<20% HP)** | Single wobbly spin (bot visibly shaking) — barely made it | Same as normal loss |

### 6d. Combat Flavor

- **Low HP warning:** Below 25% HP, bot starts trailing smoke particles
- **Critical hit reaction:** On receiving a crit, bot recoils 2px away from attacker (visual only, not gameplay movement)
- **Module activation flash:** When a module activates, a brief colored ring expands from the bot (matching module color from Section 2)
- **Overtime tension:** When overtime triggers, all bots' eyes/lights glow brighter (slight emissive increase)

### Acceptance Criteria
- [ ] All 3 chassis have distinct idle animations at correct rates
- [ ] Movement quirks trigger at specified rates
- [ ] Equip "nod" plays on item equip
- [ ] Heavy item equip causes weight "sink" animation
- [ ] Victory animation plays for winner (with perfect/close variants)
- [ ] Defeat animation plays for loser
- [ ] Smoke particles appear below 25% HP
- [ ] Crit recoil visual plays on crit hits
- [ ] Module activation ring plays in correct color
- [ ] Overtime glow increase is visible
- [ ] None of these animations affect gameplay logic (purely visual)

---

## GDD Update Section

The following changes should be applied to `docs/gdd.md`:

### Section 3.2 — Weapons Table
Update Plasma Cutter range: 1.5 → **2.5**

### Section 5.3 — Movement & Targeting (NEW subsection 5.3.2)
Add **5.3.2 Movement Physics** with the acceleration/deceleration/turn speed table and rules.

### Section 9 — Match Format
Update overtime/timing values for 1v1 (45s/60s/100s) and clarify 2v2/3v3 keep existing values. Update target match lengths.

### Section 10 — Art Direction (NEW subsection: Bot Personality)
Add idle animations, movement quirks, victory/defeat reactions, combat flavor effects, and visual loadout spec.

### Section 10 — Art Direction (UPDATE: UI Layout)
Add visual loadout preview spec and equipped/unequipped card styling.

---

*This spec is the complete design input for Sprint 12. All numbers are final pending playtest results. Ett: plan accordingly.*
