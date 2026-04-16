# Sprint 13.6 — BrottBrain Scrapyard Trick Choice

**Author:** Gizmo
**Pillar:** 3 of The Bott's "first 5 minutes" direction
**Status:** Spec — ready for Ett review / Nutts split-spawn

---

## §0 Scope ("DO NOT EXCEED")

**Files touched (≤5):**
- NEW `godot/data/trick_choices.gd` — trick data definitions
- NEW `godot/ui/trick_choice_modal.tscn` + `godot/ui/trick_choice_modal.gd` — modal UI
- EDIT `godot/ui/shop_screen.gd` — hook to spawn modal on Scrapyard entry
- EDIT `godot/game_state.gd` — add `_tricks_seen: Array[String]` + effect apply helpers
- NEW `godot/tests/test_sprint13_6.gd` — coverage

**LoC cap:** ≤200 total across all five files.

**NOT in 13.6:**
- Voice / TTS (deferred to S13.7)
- Dynamic / procedural text
- Multi-step branching choices
- Fortress tricks (Scrapyard only)
- Animations beyond simple fade-in/fade-out

---

## §1 Design brief

BrottBrain inserts an opinion-loaded micro-decision on each Scrapyard entry before the shop grid appears. The pattern is: cynical-but-caring older-sibling voice frames a small junkyard encounter → two buttons, one riskier and one safer → immediate, small effect → shop proceeds. Low-stakes, flavorful, and repeatable — the point is to make Scrapyard feel *inhabited* by BrottBrain's personality, not to add a new economic layer. Effects are small deltas; the shop itself remains the primary decision surface.

---

## §2 Data model — `trick_choices.gd`

```gdscript
extends Node

enum EffectType {
    BOLTS_DELTA,            # effect_value: int (+/-)
    ITEM_GRANT,             # effect_value: String (item id) or "random_weak"
    ITEM_LOSE,              # effect_value: String (item id)
    NEXT_FIGHT_PELLET_MOD,  # effect_value: int (+/-) pellets next fight only
    HP_DELTA,               # effect_value: int (+/-)
}

# Each trick: {id, brottbrain_text, prompt, choice_a, choice_b}
# choice_a/b:  {label, effect_type, effect_value, flavor_line}

const TRICKS := [
    {
        "id": "rusty_launcher",
        "brottbrain_text": "Looks shady.",
        "prompt": "A rusty pellet launcher half-buried in the scrap. Might work. Might blow up in your face.",
        "choice_a": {
            "label": "Take it",
            "effect_type": EffectType.NEXT_FIGHT_PELLET_MOD,
            "effect_value": 1,
            "flavor_line": "Stuffed it in the pack. You'll find out next fight.",
        },
        "choice_b": {
            "label": "Burn it for scrap",
            "effect_type": EffectType.BOLTS_DELTA,
            "effect_value": 10,
            "flavor_line": "Smart. +10 bolts.",
        },
    },
    {
        "id": "scavenger_kid",
        "brottbrain_text": "I don't trust that kid.",
        "prompt": "A scrawny scavenger waves a mystery bundle at you. \"Five bolts. No peeking.\"",
        "choice_a": {
            "label": "Buy mystery (−5 bolts)",
            "effect_type": EffectType.ITEM_GRANT,
            "effect_value": "random_weak",
            "flavor_line": "Ugh, of course it's that.",  # pair with −5 in apply
        },
        "choice_b": {
            "label": "Walk away",
            "effect_type": EffectType.BOLTS_DELTA,
            "effect_value": 0,
            "flavor_line": "Good call. That kid's a menace.",
        },
    },
    {
        "id": "risk_for_reward",
        "brottbrain_text": "Tempting, but…",
        "prompt": "A spring-loaded crate rig. Three extra pellets if it doesn't snap your paw off.",
        "choice_a": {
            "label": "Grab the pellets",
            "effect_type": EffectType.NEXT_FIGHT_PELLET_MOD,
            "effect_value": 3,
            "flavor_line": "Got 'em. Lost some fur. −5 HP.",  # pair with HP_DELTA −5 in apply
        },
        "choice_b": {
            "label": "No risk",
            "effect_type": EffectType.BOLTS_DELTA,
            "effect_value": 0,
            "flavor_line": "Wise. Boring, but wise.",
        },
    },
]
```

**Note for implementer (Nutts-A):** `scavenger_kid` choice A and `risk_for_reward` choice A each have a *paired* secondary effect (bolts −5, HP −5). Two options:
1. Extend the schema with optional `effect_type_b` / `effect_value_b` on a choice.
2. Hard-code the pairing in the apply function for these two ids.

**Recommend option 1** (clean, extensible, minimal LoC). Add optional `effect_type_2` / `effect_value_2` keys; apply helper iterates both if present.

---

## §3 UI spec — `trick_choice_modal.tscn`

Modal overlay on top of shop screen, reuses shop card visual language (rounded dark panel, cyan accent borders).

**Layout (vertical):**
- **Top band (~100px):** BrottBrain portrait placeholder (80×80 square, cyan tint `#00BFD8`, rounded 8px) on the left; dialogue line (`brottbrain_text`, italic, 18pt) to the right.
- **Middle (~120px):** `prompt` text, regular 16pt, 2–3 lines max, center-aligned, generous padding.
- **Bottom (~80px):** Two buttons side-by-side, equal width, 16px gap. `choice_a` left, `choice_b` right. Standard shop button style.

**Interaction:**
- Fade-in: 0.2s (alpha 0→1, no scale).
- On button click: that button flashes bright cyan for 100ms → effect applies → outcome toast appears (bolts Δ / item Δ / HP Δ, same style as shop purchase toast) → modal fade-out 0.15s → emit `resolved(trick_id, choice_key)` signal.
- Modal is **modal**: blocks input to shop behind it (full-screen semi-transparent overlay `rgba(0,0,0,0.6)`).
- No close/skip button — player must pick one.

**Script surface (`trick_choice_modal.gd`):**
```gdscript
extends CanvasLayer

signal resolved(trick_id: String, choice_key: String)  # "choice_a" | "choice_b"

func show_trick(trick: Dictionary) -> void: ...
# Internal: _on_choice_a_pressed, _on_choice_b_pressed → _apply_and_dismiss
```

Effect application lives in `GameState` (see §4), not the modal — modal only emits the resolved signal with the chosen key; caller applies.

---

## §4 Integration

**`shop_screen.gd`** on Scrapyard entry (`_ready` or whichever method builds the grid today):

```gdscript
func _ready() -> void:
    # ... existing setup ...
    await _run_brottbrain_trick()
    _build_shop_grid()  # existing

func _run_brottbrain_trick() -> void:
    var trick = _pick_trick()
    if trick == null:
        return
    var modal = preload("res://ui/trick_choice_modal.tscn").instantiate()
    add_child(modal)
    modal.show_trick(trick)
    var result = await modal.resolved
    var trick_id: String = result[0]
    var choice_key: String = result[1]
    GameState.apply_trick_choice(trick, choice_key)
    GameState._tricks_seen.append(trick_id)
    modal.queue_free()

func _pick_trick() -> Variant:
    var all = TrickChoices.TRICKS
    var unseen = all.filter(func(t): return not GameState._tricks_seen.has(t["id"]))
    var pool = unseen if unseen.size() > 0 else all
    if pool.is_empty():
        return null
    return pool[randi() % pool.size()]
```

**`game_state.gd`** additions:
```gdscript
var _tricks_seen: Array[String] = []

func apply_trick_choice(trick: Dictionary, choice_key: String) -> void:
    var choice = trick[choice_key]
    _apply_single_effect(choice["effect_type"], choice["effect_value"])
    if choice.has("effect_type_2"):
        _apply_single_effect(choice["effect_type_2"], choice["effect_value_2"])

func _apply_single_effect(effect_type: int, effect_value) -> void:
    match effect_type:
        TrickChoices.EffectType.BOLTS_DELTA: add_bolts(effect_value)
        TrickChoices.EffectType.ITEM_GRANT: grant_item(effect_value)  # handle "random_weak"
        TrickChoices.EffectType.ITEM_LOSE: lose_item(effect_value)
        TrickChoices.EffectType.NEXT_FIGHT_PELLET_MOD: _next_fight_pellet_mod += effect_value
        TrickChoices.EffectType.HP_DELTA: change_hp(effect_value)
```

**Lifecycle rules:**
- One trick per Scrapyard visit.
- `_tricks_seen` persists for the **run only** — cleared on new-run / game-over.
- Modal **must** resolve before shop grid is built (hard `await`) — no race.

---

## §5 Acceptance criteria (10)

1. `trick_choices.gd` defines ≥3 tricks, each with all required fields (`id`, `brottbrain_text`, `prompt`, `choice_a`, `choice_b` with `label`/`effect_type`/`effect_value`/`flavor_line`).
2. Modal appears on every Scrapyard entry (before shop grid becomes interactive).
3. Modal displays BrottBrain dialogue, prompt text, and two labeled choice buttons.
4. Clicking choice A applies its effect correctly (bolts / item / pellet mod / HP all verified via test).
5. Clicking choice B applies its effect correctly.
6. After resolution, modal dismisses (fade-out) and shop grid appears and is interactive.
7. Trick id is appended to `GameState._tricks_seen` exactly once per resolution.
8. Same run: subsequent Scrapyard visits pick an unseen trick if any remain (verified via test with seeded run).
9. Exhausted pool (all tricks seen): falls back to picking from full pool; no crash; no duplicate-append issue.
10. All existing tests still pass: runner 72 + s13.4 42 + s13.5 32 = **146** pre-existing + new s13.6 tests.

---

## §6 GDD updates

**New §11 subsection: "BrottBrain Trick Choices"**
- System overview: one modal per Scrapyard entry, two-option micro-decision, small immediate effects.
- Voice guidelines: BrottBrain is the cynical-but-caring older sibling. Dialogue is short, opinionated, dry. Never neutral ("A choice presents itself" → NO). Always leaning ("Looks shady" / "I don't trust that kid" → YES).
- Authoring rules for new tricks: ≤25 words in `prompt`, ≤6 words in `brottbrain_text`, labels ≤4 words, effects must be small deltas (bolts ≤15, HP ≤10, pellets ≤3).

**§12 update:** "S13.6 — no balance change to combat itself; trick effects are small deltas tuned to feel flavorful rather than decisive. No re-balancing of fights or shop prices."

---

## §7 Ett handoff flags

1. **No save/load system** — confirming session-local `_tricks_seen` is acceptable. Consistent with rest of game state today. Revisit when persistence lands.
2. **Random unseen-first picking** — simple array diff + `randi() %`. No RNG seed concerns; matches existing shop picking style. If deterministic-seed runs become a thing, this will need the same seed injection.
3. **Modal blocks shop build** — using hard `await modal.resolved` before `_build_shop_grid()`. Verify no race with any auto-actions that fire on Scrapyard entry (check `game_flow.go_to_shop()` for signal emissions that assume grid exists). If any exist, defer them until after trick resolves.
4. **Recommend split-spawn:**
   - **Nutts-A:** `trick_choices.gd` data + `trick_choice_modal.tscn`/`.gd` UI (self-contained, no GameState edits). ~90 LoC.
   - **Nutts-B:** `shop_screen.gd` integration + `game_state.gd` additions + `test_sprint13_6.gd` + GDD updates. ~110 LoC.
   - Nutts-B depends on Nutts-A's public surface (`TrickChoices.TRICKS`, modal's `show_trick()` + `resolved` signal). Nutts-A ships first; Nutts-B consumes.
5. **Schema decision needed:** paired secondary effects on a single choice (scavenger_kid A, risk_for_reward A). Recommend optional `effect_type_2`/`effect_value_2` keys (clean, ≤5 LoC overhead). Flag for Ett to bless before Nutts-A starts.

---

## §8 Deliberate tradeoffs

- **Portrait placeholder only** — cyan-tinted square. Real art deferred to a later art-pass sprint.
- **No voice / TTS** — text-only in 13.6; voice lands in S13.7.
- **3 tricks only** — enough to prove the pattern and hit the unseen-first test case. Content scaling (10+ tricks, per-biome pools) deferred.
- **No long-term consequence tracking** — effects resolve immediately at the moment of choice. No "BrottBrain remembers you burned the launcher" callbacks. Deferred.
- **No skip button** — intentional. Forces engagement with BrottBrain's voice. Revisit if playtesters find it annoying.
- **One trick per visit, not per shop-tab refresh** — simpler, avoids trick spam if shop is re-entered via bug/back-nav. Tied to Scrapyard *entry*, not `_ready`.

---
