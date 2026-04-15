# Sprint 4 Design Spec — Pacing, Item Clarity, BrottBrain UX, Visual Feedback

**Ticket:** S4-001
**Author:** Gizmo (Game Designer)
**Date:** 2026-04-15
**Status:** Draft

---

## 1. PACING — Target 20–40 Second Matches

### Problem

Fights end in ~3 seconds. Two-weapon builds (e.g., Brawler with Minigun + Shotgun at close range) output ~36–40 effective DPS against Plating, deleting a 100 HP Scout in under 3 seconds. Even Fortress (180 HP) melts in ~5s. There's no time for BrottBrain decisions to matter — most cards never fire.

### Changes

**A. Triple all chassis HP:**

| Chassis | Old HP | New HP |
|---------|--------|--------|
| Scout | 100 | 300 |
| Brawler | 150 | 450 |
| Fortress | 180 | 540 |

**B. Halve simulation tick rate: 20 ticks/sec → 10 ticks/sec**

This makes everything run at half real-time speed relative to before. Fire rate timers, movement, cooldowns — all tick half as often. Effectively doubles the wall-clock time for everything.

**C. Weapon damage stays the same.** No changes to any weapon stats.

### Math: Time-to-Kill Estimates

Reference matchup: **Brawler (Minigun + Shotgun, Plating) vs. Scout (Plating)**

**Before (100 HP Scout, 20 ticks/sec):**
- Minigun: 3 dmg × 0.8 (Plating) × 6 shots/s = 14.4 DPS
- Shotgun: 6 dmg × ~3 pellets hitting × 0.8 × 1.5 shots/s = 21.6 DPS
- Combined: ~36 DPS → 100 HP / 36 = **~2.8 seconds**

**After (300 HP Scout, 10 ticks/sec):**
- At 10 ticks/sec, fire rates effectively halve in wall-clock terms:
  - Minigun: 6 shots/s at 20 ticks → 3 shots/s at 10 ticks = 7.2 DPS
  - Shotgun: 1.5 shots/s at 20 ticks → 0.75 shots/s at 10 ticks = 10.8 DPS
- Combined: ~18 DPS → 300 HP / 18 = **~16.7 seconds**

That's a 6× increase. For Fortress (540 HP): 540 / 18 = **~30 seconds**. For Brawler vs Brawler: 450 / 18 = **~25 seconds**.

**Wait — 16.7s for Scout kills is under target.** But Scout has 15% dodge, and fights involve movement/range/LoS breaks. Real matches add ~40–60% overhead from non-firing time (repositioning, out-of-range, cover). Adjusted estimates:

| Matchup | Raw TTK | Estimated Real TTK |
|---------|---------|-------------------|
| Brawler → Scout | 16.7s | 23–27s |
| Brawler → Brawler | 25.0s | 35–40s |
| Brawler → Fortress | 30.0s | 42–48s |
| Scout → Fortress | 45.0s+ | Likely timeout unless focused fire |

This lands us squarely in the 20–40 second range for most 1v1s. Heavy-vs-heavy fights may push toward the 120s timeout, which is fine — it pressures pure-tank builds.

### Derived Changes

- **Energy regen** stays at 5/sec (0.5/tick at 10 ticks/sec instead of 0.25/tick at 20)
- **Repair Nanites**: 3 HP/sec stays the same (0.3 HP/tick at 10 ticks/sec)
- **Pathfinding recalc**: every 5 ticks (still 2×/sec)
- **Movement speeds** remain the same in px/sec — just fewer ticks to calculate them
- **Match timeout** stays at 120 seconds
- **"Biggest Threat" targeting window**: 20 ticks (still 2 seconds)

### Acceptance Criteria
- [ ] Average 1v1 match length across all chassis matchups is 20–40 seconds at 1× speed
- [ ] No matchup consistently ends in under 15 seconds
- [ ] Timeout rate stays under 5%
- [ ] At least 3 BrottBrain card triggers fire per match on average

---

## 2. ITEM CLARITY — Archetypes Over Spreadsheets

Raw stats remain in the GDD. In-game, items show their **archetype** and **description** first. A "Details" toggle reveals the stat table.

### Weapons

| Weapon | Archetype | Description |
|--------|-----------|-------------|
| **Minigun** | 🔫 Rapid Fire | Sprays a stream of bullets — low damage, constant pressure. Death by a thousand cuts. |
| **Railgun** | 🎯 Sniper | One devastating shot from across the arena. Miss and you're waiting. |
| **Shotgun** | 💥 Shotgun | Get close, pull the trigger, watch pellets fly. Devastating point-blank, useless at range. |
| **Missile Pod** | 🚀 Explosive | Slow-moving rockets that splash on impact. Great against groups, easy to dodge solo. |
| **Plasma Cutter** | ⚡ Melee Blaster | In-your-face rapid fire beam. Brutal when you can stick to a target. |
| **Arc Emitter** | ⛓️ Chain Lightning | Zaps a target and arcs to their buddy. The anti-group specialist. |
| **Flak Cannon** | 🎆 Mid-Range Burst | A punchy blast at medium distance. Jack-of-all-trades, master of none. |

### Armor

| Armor | Archetype | Description |
|-------|-----------|-------------|
| **Plating** | 🛡️ Reliable | Flat damage reduction. No surprises, no downsides. The safe pick. |
| **Reactive Mesh** | 🪞 Thorns | Light protection, but attackers take damage too. Punishes rapid-fire weapons. |
| **Ablative Shell** | 🧱 Glass Fortress | Incredible protection — until it isn't. Crumbles when you're on your last legs. |

### Modules

| Module | Archetype | Description |
|--------|-----------|-------------|
| **Overclock** | ⚡ Adrenaline | Burst of fire rate, then a hangover. Time it right or pay the price. |
| **Repair Nanites** | 💚 Passive Heal | Slow, steady regeneration. Wins long fights by outlasting everyone. |
| **Shield Projector** | 🔵 Panic Button | Pop it when things go south. One-time damage sponge on a long cooldown. |
| **Sensor Array** | 👁️ Wallhack | See farther, see through cover. Knowledge is power. |
| **Afterburner** | 🏃 Nitro Boost | 2 seconds of blazing speed. Escape, reposition, or close the gap. |
| **EMP Charge** | 🔇 Shutdown | Turn off their toys for 3 seconds. Devastating against module-heavy builds. |

### UI Implementation
- Item cards in the loadout screen show: **[Icon] Name — Archetype** and the 1-sentence description
- Below the description: a collapsed "📊 Stats" toggle that reveals the raw stat table
- New players never need to see numbers; veterans can expand when theory-crafting

### Acceptance Criteria
- [ ] Every item displays archetype + description by default
- [ ] Raw stats are behind a "Details" toggle, collapsed by default
- [ ] Tooltip on hover shows the 1-sentence description

---

## 3. BROTTBRAIN UX — Card-Based Visual Editor

### Layout

```
┌─────────────────────────────────────────────────┐
│  🧠 BrottBrain Editor                    [?]    │
│                                                  │
│  Default Stance: [🔥 Go Get 'Em! ▼]             │
│                                                  │
│  ┌─── Priority List (drag to reorder) ────────┐ │
│  │                                             │ │
│  │  1. [💔] "When I'm Hurt"  →  [🔧] "Use    │ │
│  │      below 40% HP            Shield"        │ │
│  │                                        [✕]  │ │
│  │  2. [📏] "When They're   →  [🔄] "Switch  │ │
│  │      Close" within 3          Hit & Run"    │ │
│  │                                        [✕]  │ │
│  │  3. [💔] "When They're   →  [🔥] "Go Get  │ │
│  │      Hurt" below 30%         'Em!"          │ │
│  │                                        [✕]  │ │
│  │                                             │ │
│  │  4. ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐   │ │
│  │     │  + Drag a card here               │   │ │
│  │     └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘   │ │
│  │           ... (up to 8 slots)               │ │
│  └─────────────────────────────────────────────┘ │
│                                                  │
│  ┌── Available Cards ──────────────────────────┐ │
│  │ [💔 Hurt] [💪 Healthy] [🔋 Low] [⚡ Full]  │ │
│  │ [📏 Close] [📏 Far] [🧱 Cover] [✅ Ready]  │ │
│  │ [⏱️ Clock]                                   │ │
│  │ ─────────────────────────────────────────── │ │
│  │ [🔄 Stance] [🔧 Gadget] [🎯 Target]       │ │
│  │ [🔫 Weapons] [🧱 Cover] [📍 Center]       │ │
│  └─────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘
```

### Card Format

Each card in the priority list is a horizontal row:

```
┌──────────────────────────────────────────────┐
│  [💔]  "When I'm Hurt"  →  [🔧]  "Use       │
│         below 40% HP          Shield"    [✕] │
│         ▲ drag handle                        │
└──────────────────────────────────────────────┘
```

- **Left side**: Trigger — big emoji icon + plain English label + parameter (editable via dropdown/slider)
- **Arrow (→)**: Visual connector
- **Right side**: Action — big emoji icon + plain English label + parameter
- **[✕]**: Delete button
- **Drag handle**: Left edge, reorder by dragging up/down

### Interaction Flow

1. **Drag** a Trigger card from the card tray into an empty slot
2. The slot expands, showing the Trigger on the left and prompting for an Action on the right
3. **Drag** an Action card to complete the pair
4. **Tap** the parameter area to adjust thresholds (slider for HP/energy %, dropdown for modules/stances)
5. **Drag** cards vertically to reorder priority
6. **[✕]** to remove a card

### Smart Defaults

Every chassis comes with a pre-built BrottBrain visible in the editor:

- **Scout**: 💨 Hit & Run stance, 3 cards (flee when hurt, afterburner when close, go aggressive when enemy is weak)
- **Brawler**: 🔥 Go Get 'Em! stance, 2 cards (shield when hurt, all-fire when close)
- **Fortress**: 🛡️ Play it Safe stance, 2 cards (shield when hurt, go aggressive when enemy is weak)

A banner at the top reads: *"These are your Brott's instincts. Change them, reorder them, or add more!"*

### First-Visit Tutorial

On first opening the BrottBrain editor, a 3-step tooltip sequence:

1. **Points at the priority list**: *"Your Brott checks these rules from top to bottom every moment. First match wins!"*
2. **Points at a card**: *"Each rule is simple: WHEN something happens → DO something about it."*
3. **Points at the card tray**: *"Drag cards from here to teach your Brott new tricks. You can have up to 8!"*

Tooltip has a "Got it" button. Never shows again after dismissal.

### Acceptance Criteria
- [ ] 8 card slots, drag-to-reorder
- [ ] Each card shows emoji + plain English label for both trigger and action
- [ ] Parameters editable inline (slider/dropdown)
- [ ] Smart defaults pre-loaded per chassis
- [ ] Tutorial tooltip on first visit, dismissable, never repeats
- [ ] Cards draggable from tray to slot

---

## 4. VISUAL FEEDBACK — More Juice

### Screen Shake

| Event | Intensity (px) | Duration (frames @ 60fps) | Decay |
|-------|----------------|---------------------------|-------|
| Normal hit (Minigun, Plasma Cutter) | 1–2 px | 3 frames (50ms) | Linear |
| Heavy hit (Shotgun, Flak Cannon) | 3–4 px | 5 frames (83ms) | Linear |
| Big hit (Railgun, Missile Pod) | 6–8 px | 8 frames (133ms) | Ease-out |
| Death explosion | 10–12 px | 12 frames (200ms) | Ease-out |

Shake is random directional offset per frame, clamped to intensity. Concurrent shakes take the max, don't stack additively.

### Hit Flash

- **White overlay** on the damaged Brott sprite
- Duration: **2 frames (33ms)**
- Opacity: 80% white blend
- Triggers on every damage instance (including individual shotgun pellets — but clamp to max 1 flash per 3 frames to avoid strobe)

### Impact Sparks

| Event | Particle Count | Lifetime (ms) | Color | Size |
|-------|---------------|----------------|-------|------|
| Bullet impact | 3–5 | 150–250 | White/yellow | 1–2 px |
| Shotgun pellet | 2–3 per pellet | 100–200 | Orange | 1–2 px |
| Railgun hit | 8–12 | 300–400 | Cyan/white | 2–3 px |
| Missile explosion | 15–20 | 400–600 | Orange/red | 2–4 px |
| Plasma hit | 4–6 | 200–300 | Purple/magenta | 1–3 px |
| Arc chain | 3–4 per chain link | 150–250 | Electric blue | 1–2 px |

Particles emit radially from impact point with random velocity (40–80 px/s), fade to transparent over lifetime, affected by gravity (light downward pull for grounding).

### Damage Numbers

- **Font size**: 8px (down from current — keep them small and punchy)
- **Float direction**: Upward, 30 px over 600ms
- **Fade**: Start fading at 400ms, fully transparent at 600ms
- **Normal damage**: White text, thin dark outline
- **Critical damage**: Yellow text, bold, 10px font, slight scale-up pop (1.0→1.2→1.0 over 100ms)
- **Stacking**: Offset horizontally by ±4px random to avoid overlap
- **Shotgun**: Show total damage per volley, not per pellet (sum pellet hits into one number, delayed 100ms to collect)

### Death Explosion

- **Freeze frame**: 100ms pause on the killing blow (hit-stop)
- **Flash**: Screen goes 30% white for 2 frames
- **Explosion sprite**: 3-frame animation, 48×48 px (2× Brott size), centered on dead Brott
- **Particle burst**: 20–30 particles, mixed orange/grey/white, 300–600ms lifetime, high velocity (100–150 px/s), radial
- **Debris**: 4–6 larger chunks (4×4 px), tumble with rotation, fall with gravity, 800ms lifetime
- **Screen shake**: 10–12 px, 200ms (see table above)
- **Camera**: Brief 1.1× zoom toward explosion point over 200ms, then ease back to 1.0× over 300ms
- **Slow-mo**: 0.3s at 50% time scale (as noted in GDD section 10)

### Acceptance Criteria
- [ ] Screen shake fires on every damage event with intensity matching the table
- [ ] Hit flash visible but not strobing (3-frame minimum gap)
- [ ] Sparks spawn at impact point with correct particle counts
- [ ] Damage numbers are small (8px), fade in 600ms, crits are yellow
- [ ] Shotgun damage numbers consolidate into single volley total
- [ ] Death sequence includes hit-stop, flash, explosion, debris, zoom, and slow-mo
- [ ] All VFX work at both 1× and 2× playback speed

---

## Summary of All Changes

| Area | Change | Impact |
|------|--------|--------|
| Chassis HP | 3× all HP values | Longer fights |
| Tick Rate | 20 → 10 ticks/sec | Halves effective fire/move rates, more readable |
| Item Display | Archetype + description first, stats behind toggle | Approachable for new players |
| BrottBrain UI | Card-based drag-and-drop editor with emoji + plain English | Intuitive behavior programming |
| Smart Defaults | Pre-built BrottBrain per chassis | New players can fight immediately |
| Visual Feedback | Screen shake, sparks, damage numbers, death explosions | Combat feels impactful and readable |

---

*This spec is ready for implementation. Nutts should reference this for exact values. Optic should verify TTK targets after implementation.*
