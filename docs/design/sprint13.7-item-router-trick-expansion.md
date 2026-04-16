# Sprint 13.7 — Inventory/Item Router + Trick Content Expansion

**Author:** Gizmo
**Status:** Design — ready to implement
**Predecessor:** S13.6 (trick choice framework, ITEM_GRANT stubbed)
**Successor candidates:** S13.8 rarity system, item icons, cross-category trades

---

## 1. Goal

Un-stub `ITEM_GRANT` / `ITEM_LOSE` so tricks can actually touch the inventory, and add enough Scrapyard content to exercise the new plumbing. No new systems beyond the router and a handful of tricks.

---

## 2. DO NOT EXCEED (scope lock)

**Hard budget: ≤250 LoC net across all production files** (tests excluded).
Rough split:
- `item_tokens.gd` ~120 LoC
- `GameState` helper wiring ~40 LoC
- `trick_choices.gd` additions ~60 LoC (3–5 new tricks + scavenger_kid fix)
- Toast string polish ~10 LoC
- Misc/glue ~20 LoC

**Explicitly out of scope — do not add, even if tempting:**
- Rarity tiers / weighted pools (flat random only in 13.7)
- Item icons, sprites, tooltips
- Cross-category swaps (grant weapon → lose armor)
- Audio / SFX hooks
- UI inventory panel changes
- Save/load migration (schema is unchanged; arrays already persist)
- New RNG system — reuse `GameState.rng` if present, else Godot default
- Consumable category (`random_consumable` pool) unless consumables already exist in the codebase; if not, **skip it silently**, do not add the category

If a requirement here reads like it opens any of the above, stop and flag to Ett.

---

## 3. Architecture

### 3.1 Token schema

All tricks reference items via **string tokens**. The router resolves tokens to a structured dict:

```gdscript
# Resolved item descriptor
{
    "category": int,   # enum: CAT_WEAPON | CAT_ARMOR | CAT_MODULE | CAT_CHASSIS
    "type": int,       # enum value within that category (e.g. ArmorData.Type.CERAMIC)
    "token": String,   # original token, for toast display / debugging
}
```

This mirrors the existing `chassis_data` / `weapon_data` pattern (category + type int).

### 3.2 Token kinds

Two kinds, distinguished inside the router (callers don't care):

1. **Direct tokens** — 1:1 mapping to a specific item.
   - e.g. `"ceramic_plating"` → `{CAT_ARMOR, ArmorData.Type.CERAMIC}`
2. **Pool tokens** — prefixed conceptually with `random_*`; resolve by picking from a pool list.
   - e.g. `"random_weak"` → random pick from the "weak/early" pool.

Pool definitions live in a constant dict in `item_tokens.gd`:

```gdscript
const POOLS = {
    "random_weak": [
        "scrap_blade", "rusted_plating", "spare_bolts_module", ...
    ],
    "random_module": [
        "spare_bolts_module", "kick_servo", "shock_dampener", ...
    ],
    # "random_consumable": [...]  # only if consumables exist; else omit
}
```

Pool entries are themselves **direct tokens**, so pool resolution = pick one entry → recurse/resolve as direct. One level of indirection, no nesting.

### 3.3 Router API

```gdscript
# godot/data/item_tokens.gd  (class_name ItemTokens, static)

const CAT_WEAPON  := 0
const CAT_ARMOR   := 1
const CAT_MODULE  := 2
const CAT_CHASSIS := 3

static func resolve_token(token: String, rng = null) -> Dictionary:
    # Returns {} on unknown token or empty pool (caller treats as no-op).
    ...

static func display_name(resolved: Dictionary) -> String:
    # Human-readable name for toasts (e.g. "Ceramic Plating").
    ...
```

- `rng` is optional. If `GameState.rng` exists, the caller passes it. Otherwise the router uses `randi_range` directly.
- Unknown tokens or empty pools return `{}` — callers must null-check. **Never loop-retry on empty pools.**

### 3.4 GameState wiring

Two helpers, called from the existing `apply_trick_choice` effect dispatcher:

```gdscript
func _grant_item(token: String) -> Dictionary:
    var resolved = ItemTokens.resolve_token(token, rng if "rng" in self else null)
    if resolved.is_empty():
        return {}
    match resolved.category:
        ItemTokens.CAT_WEAPON:  weapons.append(resolved.type)
        ItemTokens.CAT_ARMOR:   armors.append(resolved.type)   # use real field names
        ItemTokens.CAT_MODULE:  modules.append(resolved.type)
        ItemTokens.CAT_CHASSIS: chassis.append(resolved.type)
    return resolved

func _lose_item(token: String) -> Dictionary:
    # Direct tokens only in 13.7; pool LOSE deferred.
    var resolved = ItemTokens.resolve_token(token)
    if resolved.is_empty():
        return {}
    var arr = _array_for_category(resolved.category)
    var idx = arr.find(resolved.type)
    if idx != -1:
        arr.remove_at(idx)
    return resolved  # still returned so toast shows what was targeted
```

`_lose_item` on a missing item is a **silent no-op** (returns the resolved dict so the trick can still fire its toast/flavor, but inventory is unchanged). This matches "toll goblin demands a part you don't have → you shrug" flavor.

### 3.5 Toast messages

Grant toast now uses `ItemTokens.display_name(resolved)`:

> `"Found: Ceramic Plating"` instead of `"got item"`.

Lose toast:

> `"Lost: Scrap Blade"` (or, if nothing to lose: `"Nothing to give up."`).

---

## 4. New Scrapyard tricks

Added to `trick_choices.gd`. Five starters; implementer may cut to 3 if LoC is tight, but **must keep at least one of each class** (pure grant, pure lose, mixed).

| id                  | flavor                                                                 | choices                                                                                           |
|---------------------|------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------|
| `crate_find`        | "A sealed crate wedged under a dead bus. Prybar says hi."              | A: `ITEM_GRANT "random_weak"` (flavor: crack it open). B: walk past (no-op).                      |
| `toll_goblin`       | "A goblin on the bridge rattles a tin cup: 'part, please.'"            | A: `ITEM_LOSE "random_weak"` → `MORALE_DELTA +1` (goblin salutes). B: `BOLTS_DELTA -10` bribe.    |
| `scrap_trader`      | "Traveling junker with a grin too wide."                               | A: `BOLTS_DELTA -15` + `ITEM_GRANT "random_module"` (trade). B: haggle fail → small morale hit.   |
| `rusted_cache`      | "Pre-collapse stash behind a rotted fence."                            | A: `ITEM_GRANT "random_module"` + `BOLTS_DELTA +5`. B: booby-trapped — `HP_DELTA -10`.            |
| `beggar_bott`       | "A sparking wreck of a bott holds out one claw."                       | A: `ITEM_LOSE "random_weak"` → `MORALE_DELTA +2`. B: ignore (no-op).                              |

Plus: **`scavenger_kid.choice_a`** — existing. No new content; just the router now lands the grant. Toast string changes to include the resolved item name.

Totals after 13.7: 3 existing + 5 new + scavenger_kid polished = **≥6 tricks**, hits AC #5.

---

## 5. Tests — `test_sprint13_7.gd`

Target ≥15 tests. Suggested breakdown:

**Router (6):**
1. `resolve_token("ceramic_plating")` → correct `{category=CAT_ARMOR, type=CERAMIC}`.
2. `resolve_token("scrap_blade")` → weapon category, correct enum.
3. `resolve_token("random_weak", seeded_rng)` → non-empty, category in {weapon, armor, module}.
4. `resolve_token("random_module", seeded_rng)` → category == CAT_MODULE.
5. `resolve_token("bogus_token")` → `{}`.
6. `display_name` returns non-empty string for every direct token in `POOLS["random_weak"]`.

**GameState grant/lose (5):**
7. `_grant_item("ceramic_plating")` appends to armors array.
8. `_grant_item("random_weak")` appends to exactly one category array (length grows by 1 total).
9. `_lose_item("ceramic_plating")` after grant → array length back to original.
10. `_lose_item("ceramic_plating")` with empty inventory → no-op, no error.
11. `_grant_item("bogus")` → no array changes, returns `{}`.

**Trick integration (4):**
12. `crate_find.choice_a` → inventory grows by 1.
13. `toll_goblin.choice_a` with non-empty inventory → inventory shrinks by 1, morale +1.
14. `scrap_trader.choice_a` → bolts -15 AND module array +1.
15. `scavenger_kid.choice_a` → inventory grows by 1 (regression for S13.6 stub fix).

**Guards (1+):**
16. Empty pool (temporarily monkey-patch POOLS or use a defined-empty test pool) → `resolve_token` returns `{}`, no infinite loop.

All 207+ existing tests must continue to pass (AC #7).

---

## 6. Split-spawn plan (Ett)

Recommend 2 Nutts in parallel:

**Nutts-A — Router + Data**
- Create `godot/data/item_tokens.gd`
- Define category constants, direct token table, 2 pool definitions (`random_weak`, `random_module`)
- `resolve_token`, `display_name`
- Tests 1–6 + test 16

**Nutts-B — Integration**
- `GameState._grant_item` / `_lose_item` wiring
- `_array_for_category` helper
- Toast message updates
- 5 new tricks in `trick_choices.gd`
- scavenger_kid toast polish
- Tests 7–15
- GDD §11 update

**Sync point:** B depends on A's `ItemTokens` API surface. If A stubs the constants + empty function bodies first and commits, B can land immediately after. Otherwise B waits for A.

---

## 7. GDD §11 BrottBrain — addendum text

> **Item tokens.** Tricks reference inventory items by string tokens, not direct enum values, to keep content-authoring decoupled from schema churn. A token is either a **direct token** (1:1 to a specific item, e.g. `"ceramic_plating"`) or a **pool token** (prefixed `random_*`, resolves to a flat random pick from a named pool). Pools are defined in `item_tokens.gd` alongside the direct mapping table. Tokens resolve to `{category, type}` dicts matching the existing `chassis_data` / `weapon_data` schema; unknown tokens and empty pools resolve to `{}` and are treated as no-ops by the caller.
>
> **Pool conventions.** `random_weak` is the early-game catch-all (cheap chassis-agnostic parts). `random_module` restricts to modules only — used for trader-style tricks where the narrative specifies "a gizmo." Rarity tiers and cross-category trades are intentionally deferred; in 13.7 pools are flat-uniform and single-category. When a trick's flavor demands a specific item, use a direct token — do not invent ad-hoc pools.

---

## 8. Acceptance criteria (restated, checkable)

1. ✅ `godot/data/item_tokens.gd` exists, exports `resolve_token`.
2. ✅ ≥2 pool definitions present.
3. ✅ `_grant_item` handles direct + pool tokens.
4. ✅ `_lose_item` handles direct tokens; no-op when not owned.
5. ✅ ≥3 new tricks added; total tricks ≥6.
6. ✅ `scavenger_kid.choice_a` grants a real item end-to-end.
7. ✅ All prior tests pass (207+).
8. ✅ `test_sprint13_7.gd` has ≥15 tests covering router + integration.
9. ✅ Grant toast shows resolved display name.
10. ✅ Empty-pool guard — returns `{}`, no loop.

---

## 9. Flags for Ett

- **RNG:** pass `GameState.rng` into the router if the field exists. If not, router falls back to Godot default. **Do not** introduce a new RNG instance.
- **Token schema:** `{category: int, type: int, token: String}`. Matches existing data files.
- **Consumables:** verify whether a consumable category exists. If not, **drop `random_consumable` entirely** — don't scaffold an empty category.
- **LoC watch:** 250 LoC is tight once you add 5 tricks. If pressed, cut `rusted_cache` and `beggar_bott` first; keep `crate_find`, `toll_goblin`, `scrap_trader` (covers grant / lose / mixed).
- **Split-spawn recommended:** Nutts-A (router) → Nutts-B (integration + tests + GDD). Serialize if A's API isn't stubbed first.
- **Array field names:** spec uses `weapons / armors / modules / chassis` — implementer must match the actual GameState field names; don't rename.
