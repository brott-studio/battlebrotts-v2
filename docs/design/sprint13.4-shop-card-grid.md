# Sprint 13.4 — Shop Card Grid MVP

**Status:** Design handoff — Gizmo → Nutts
**Sprint:** 13.4 (UI-only pivot; balance deferred to S14)
**Scope:** Replace text-list shop with card grid. MVP only. Polish (animations, SFX, real art) → S13.5.

---

## 1. Why this sprint

The current shop (pre-S13.4) is a vertical text list of 19 items (7 weapons, 3 armor, 3 chassis, 6 modules). Playtesters in the S13.2/13.3 TCR sessions consistently reported:

- **"Feels like a spreadsheet, not a shop"** — no visual differentiation between items, prices blur together.
- **"I don't know what I'm looking at"** — archetype labels use emoji + adjective but the scannable information density is low.
- **"Too many clicks to see stats"** — the 📊 expand toggle opens stats for one item at a time and still returns you to the scrolling list.

The combat loop is landing (S13.3 validation: mirror matchups resolve in 10–42s, no instant kills). The next playtest bottleneck is shop engagement — players need to *want* to spend bolts.

**S13.4 is UI-only.** No economy changes, no balance changes, no new items. We're reskinning the shop with a card grid and inline expansion. If this lands we pick up polish (animations, real art swap-in points, SFX) in S13.5 and return to balance (Fortress loadout pass) in S14.

---

## 2. Goals & non-goals

### Goals
1. Card grid layout — 3-col desktop, 2-col mobile.
2. At-a-glance scan: art tile, name, archetype tag, price. No digging required to identify an item's role.
3. Inline expansion for stats + buy action (NOT modal). Players stay in context.
4. Clear state rendering: owned, affordable, unaffordable all readable from the card.
5. Preserve `continue_pressed` signal contract and `GameState.buy_*` call sites.

### Non-goals (S13.4)
- Real commissioned art (placeholder tiles only).
- Card hover animations, press SFX, purchase-confirm animations.
- Compare-two-items mode.
- Filtering / sorting UI.
- Re-rolling the item catalog.
- Any balance / price / economy change.

---

## 3. Visual & interaction spec

### 3.1 Layout

```
┌─────────────────────────────────────────────────────────┐
│ 🔩 SHOP                                      1240 🔩    │  ← header, bolts @ 36pt
├─────────────────────────────────────────────────────────┤
│ — WEAPONS —                                             │
│ ┌─────────┐  ┌─────────┐  ┌─────────┐                   │
│ │  [art]  │  │  [art]  │  │  [art]  │                   │
│ │ 120x120 │  │         │  │         │                   │
│ │         │  │         │  │         │                   │
│ │ Railgun │  │ Minigun │  │ Shotgun │                   │
│ │ Sniper  │  │ RapFire │  │ Burst   │   ← archetype tag │
│ │   300🔩 │  │    50🔩 │  │   150🔩 │                   │
│ └─────────┘  └─────────┘  └─────────┘                   │
│   200x240      200x240      200x240                     │
│                                                         │
│ ┌─────────┐  ┌─────────┐  ┌─────────┐                   │
│ │ ...     │  │ ...     │  │ ...     │                   │
│ └─────────┘  └─────────┘  └─────────┘                   │
│ — ARMOR —                                               │
│ ...                                                     │
└─────────────────────────────────────────────────────────┘
```

- **Section order:** WEAPONS → ARMOR → CHASSIS → MODULES (weapons first; this is what players hunt for post-fight).
- **Card size:** fixed 200 × 240 px.
- **Column count:** viewport width ≥ 1024 px → 3 cols; < 1024 px → 2 cols. 720 px is our mobile reference width.
- **Gutters:** 16 px between cards, 20 px section padding.
- **Bolts counter:** top-right of header, 36pt, format `{N} 🔩`.

### 3.2 Card anatomy

```
┌─────────────────┐
│                 │
│   [ART TILE]    │  ← 120x120, category-colored placeholder with monogram glyph
│                 │
│                 │
├─────────────────┤
│ Railgun         │  ← 16pt bold, left-aligned
│ Sniper • Weapon │  ← 11pt muted (#A0A0A0): {archetype} • {category}
│                 │
│           300 🔩│  ← 18pt, right-aligned, bottom
└─────────────────┘
```

- **Art tile:** top 120 px of the card. Placeholder = category-colored fill + first-letter monogram (48pt, cream `#F4E4BC`, centered). See §5 for palette.
- **Name:** 16pt bold, cream, left-aligned, 10 px below art.
- **Archetype tag:** 11pt, muted grey, format `{archetype} • {category}`. E.g. `Sniper • Weapon`, `Light • Armor`.
- **Price:** 18pt, bottom-right with 10 px inset.
  - Affordable → default color (cream).
  - Unaffordable → red (`#D04040`).
  - Owned → replaced with `✓ Owned` in green (`#6FCF6F`).

### 3.3 Card states

| State | Opacity | Price area | Badge | Tappable? |
|---|---|---|---|---|
| Available (affordable) | 1.0 | `{N} 🔩` cream | none | yes |
| Available (unaffordable) | 1.0 | `{N} 🔩` red | none | yes |
| Owned | 0.5 | `✓ Owned` green | green ✓ top-right of art | yes (stats still viewable) |

The owned-but-tappable behavior is intentional: players should be able to inspect stats of items they already own.

### 3.4 Expand-in-place

Tapping a card expands an **inline stats panel** directly below that row (not a modal, not a sidebar). Only one card is expanded at a time; tapping a second card collapses the first.

```
│ ┌─────────┐  ┌─────────┐  ┌─────────┐                   │
│ │ Railgun │  │ Minigun │  │ Shotgun │ ← tap Railgun     │
│ │  300🔩  │  │   50🔩  │  │  150🔩  │                   │
│ └─────────┘  └─────────┘  └─────────┘                   │
│ ╔═════════════════════════════════════════════════════╗ │
│ ║ RAILGUN                                      ✕      ║ │ ← collapse button
│ ║ Sniper • Weapon                                     ║ │
│ ║                                                     ║ │
│ ║ Damage: 40      Range: 400    Fire rate: 0.5/s      ║ │
│ ║ Projectile spd: 800            Energy cost: 25      ║ │
│ ║                                                     ║ │
│ ║ High damage, long range, slow fire. Line of sight.  ║ │ ← description
│ ║                                                     ║ │
│ ║               [ BUY — 300 🔩 ]                      ║ │ ← buy button in panel
│ ╚═════════════════════════════════════════════════════╝ │
│ ┌─────────┐  ┌─────────┐  ┌─────────┐                   │
│ │ Plasma  │  │ ...     │  │ ...     │                   │  ← next row of weapons
│ └─────────┘  └─────────┘  └─────────┘                   │
```

- Panel spans full grid width, rendered between the row containing the tapped card and the next row.
- Stats are laid out in a 2- or 3-column arrangement that fits in ~120 px panel height.
- Description text (from `data["description"]`) rendered below stats, italic, 11pt muted.
- **Buy button** inside the panel: enabled if affordable + not owned; disabled + labeled `Need {N} more` if unaffordable; hidden (or replaced with `✓ Owned`) if already owned.
- The collapse `✕` button (top-right of panel) also closes it. Tapping the same card a second time = close.

**Implementation note (Ett flag):** If `GridContainer` reflow misbehaves when a full-width child is inserted mid-grid, fall back to **VBox-of-HBox rows**: each section is a VBox whose children alternate between HBox rows of cards and (optionally) a full-width ExpandPanel inserted after the row that owns the expanded card.

### 3.5 Continue button
Unchanged semantics: bottom-right `Continue →` button emits `continue_pressed`. Keep position reasonable relative to the shop — bottom of viewport, right-aligned.

---

## 4. Acceptance criteria (15 items)

For S13.4 to ship, all of the following must be visible in screenshots and verifiable by unit/Playwright tests.

1. **Desktop 3-col grid** — at 1280w, first WEAPONS row contains exactly 3 cards side-by-side.
2. **Mobile 2-col grid** — at 720w, first WEAPONS row contains exactly 2 cards side-by-side.
3. **Card size 200×240** — every rendered card has `custom_minimum_size == (200, 240)`.
4. **Section order** — sections render in order: WEAPONS → ARMOR → CHASSIS → MODULES.
5. **All items rendered** — 7 weapons + 3 armor + 3 chassis + 6 modules = 19 cards.
6. **Bolts counter 36pt** — header bolts label has `font_size = 36`.
7. **Continue signal contract** — pressing `ContinueButton` emits `continue_pressed`, no args.
8. **Unaffordable = red price** — at bolts=100, Railgun's price label has red font color.
9. **Affordable exists** — at bolts=100, at least one non-owned card has non-red price.
10. **Owned = ✓ + 50% opacity** — default loadout (Plasma Cutter, Plating, Scout) renders with `✓ Owned` text and green ✓ badge; card opacity = 0.5.
11. **Archetype tag format** — weapon cards show `{archetype} • Weapon`; armor cards show `Light` / `Adaptive` / `Heavy`.
12. **Expand in place** — tapping a card creates exactly one `ExpandPanel_` node; no panels exist pre-tap.
13. **Only one expanded at a time** — tapping a second card collapses the first; total panel count always ≤ 1.
14. **Buy flow works** — tapping Buy on an affordable card decrements `game_state.bolts` by price and adds type to `owned_*` set; card re-renders as owned.
15. **Buy button disabled when unaffordable** — in expanded panel of Railgun at bolts=10, the BuyButton is `disabled=true` and its text contains `Need`.

---

## 5. Placeholder art palette

Real art is an S13.5+ concern. For S13.4 every card uses a colored tile with a monogram (first letter of item name). Palette is intentional — color coding per category has meaning even after real art lands.

| Category | Fill | Border | Glyph |
|---|---|---|---|
| Weapon | `#8B2E2E` (rust red) | `#D4A84A` gold | 48pt cream (`#F4E4BC`) |
| Armor | `#2E5A8B` (steel blue) | `#8FAECB` light steel | 48pt cream |
| Chassis | `#4A4A4A` (gunmetal) | `#A0A0A0` silver | 48pt cream |
| Module | `#2E6B4A` (industrial green) | `#7BCA9E` mint | 48pt cream |

The placeholders should read as *intentionally chunky* — playtesters should recognize them as not-final art, not mistake them for shipped visuals.

---

## 6. Handoff to S14 (Balance)

Nothing in this sprint touches balance. S14 picks up the Fortress loadout pass flagged in S13.3 validation:

- Scout vs Fortress 100/0 and Brawler vs Fortress 100/0 cross-chassis skews (S13.3 closed instant-kill regressions but not the outcome gap).
- Fortress long-range identity — does it have the weapons/modules to actually punish Scout's kiting?
- Mirror-match TTM floor (Scout mirror ~10s; Brawler mirror ~10s). Long enough to be readable, short enough to feel punchy?

None of these are in scope for S13.4. Flagging here so the S14 author has a running list.

---

## 7. Open questions for Nutts
- If `GridContainer` expand-in-place feels wrong, fall back to VBox-of-HBox — your call, just document the decision in your PR.
- Monogram glyph for multi-word names (e.g. "Reactive Mesh", "Plasma Cutter") — use first letter of the **last word** (M, C). First letter of first word collides too often (P for Plating and Plasma Cutter).

---

*Gizmo, S13.4 design handoff, pre-commit.*
