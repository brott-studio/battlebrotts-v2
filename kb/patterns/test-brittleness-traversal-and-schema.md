# Prior-Sprint Test Brittleness: Direct-Children Traversal and Exact-Size Asserts

**Source:** S21.2 audit (2026-04-23) — [audit](https://github.com/brott-studio/studio-audits/blob/main/audits/battlebrotts-v2/v2-sprint-21.2.md), tracking issue [#248](https://github.com/brott-studio/battlebrotts-v2/issues/248)
**Related:** `kb/troubleshooting/test-fixture-constant-coupling.md`

## Problem

Tests that over-specify their structural invariants break when the implementation undergoes **legitimate** UI evolution (scroll-wrapper introduction, schema extension, layout refactor). The test failure is real but the underlying production invariant still holds — the test was asserting the wrong thing.

## Two canonical cases from S21.2

### Case 1: `get_children()` direct-children traversal

**Before:** S17.4-002 test helper `_find_tray_header()` walked only `screen.get_children()` — direct children of the screen Control.

```gdscript
func _find_tray_header(screen: BrottBrainScreen) -> Label:
    for child in screen.get_children():
        if child is Label and lbl.text == "── Available Cards ──":
            return lbl
    return null
```

**What broke it:** S21.2 T1 wrapped the tray under a `TrayScroll` ScrollContainer. The header Label was no longer a direct child of `screen`; it lived at `TrayScroll/tray_content/Label`. The helper returned `null` → 3 assertion failures.

**Real invariant:** "tray header exists somewhere findable under the screen." Not "tray header is a direct child of the screen."

**Fix:** primary lookup inside `TrayScroll/tray_content`, fallback to direct children for pre-S21.2 layout.

```gdscript
func _find_tray_header(screen: BrottBrainScreen) -> Label:
    # Primary: post-S21.2 layout
    var tray_content := screen.get_node_or_null("TrayScroll/tray_content")
    if tray_content != null:
        for child in tray_content.get_children():
            if child is Label and child.text == "── Available Cards ──":
                return child
    # Fallback: pre-S21.2 layout
    for child in screen.get_children():
        if child is Label and child.text == "── Available Cards ──":
            return child
    return null
```

### Case 2: `size() == N` on an extensible schema

**Before:** `test_sprint14_2_cards.gd` asserted:

```gdscript
_assert(running_row.size() == 4 and running_row[2] == "tiles_per_sec", ...)
```

**What broke it:** S21.2 T2 (#103) extended `TRIGGER_DISPLAY` / `ACTION_DISPLAY` rows from 3 slots to 4 slots (adding a caption slot at index 4). Rows that were 4 wide became 5 wide — assertion failed.

**Real invariant:** "row carries the param-metadata tuple at index 2." Not "row has exactly N slots."

**Fix:** `==` → `>=`.

```gdscript
_assert(running_row.size() >= 4 and running_row[2] == "tiles_per_sec", ...)
```

## How to recognize brittleness at test-write time

Heuristics to catch these patterns **before** they break:

1. **`get_children()` direct traversal on a screen-root Control.** Ask: "Is the thing I'm looking for *guaranteed* to be a direct child, or could a future scroll/layout wrapper push it deeper?" If there's any chance of wrapping, use `find_child(name, true, false)` (recursive) or an explicit path lookup with fallback.

2. **`size() == N` on any data structure documented as "schema may grow."** Look for the real invariant (presence of a specific index, presence of a specific key, minimum width) and assert that instead. `>=` is forward-compatible; `==` is not.

3. **Hardcoded pixel coordinates in assertions** (e.g. `< 600.0`) without a comment linking the number to a structural invariant. S21.2's `d2cb886` had to bump `600 → 648` for exactly this reason. If the number is not derivable from a documented structural fact (anchor positions, screen dimensions, layout constants), the test is asserting geometry it cannot justify.

4. **Exact node-path strings in tests** (e.g. `"MainContainer/ButtonRow/BackButton"`). Prefer a name-based `find_child` with a comment explaining why the name is the stable contract.

## Grep-level audit queries

To sweep existing tests for the pattern:

```bash
# Direct-children traversal candidates
rg -n "screen\.get_children\(\)" godot/tests/

# Exact-size assertions
rg -n "\.size\(\) == \d" godot/tests/

# Hardcoded pixel thresholds without comments
rg -B1 -n "< \d{3,4}\.\d" godot/tests/ | rg -v "^.*#.*"
```

## When to reach for this KB entry

- Any test-write pass for a UI surface that is still actively evolving (BrottbrainScreen, OpponentSelectScreen, LoadoutScreen).
- Any test fix after a legitimate UI change broke a prior-sprint test — ask whether the test was asserting the wrong invariant, not just updating values.
- During Specc audits: if a sub-sprint's diff touched UI layout and prior tests broke, check whether the broken tests hardcoded structural assumptions the production code never guaranteed.
