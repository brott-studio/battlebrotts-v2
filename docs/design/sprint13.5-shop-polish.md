# Sprint 13.5 — Shop Polish (tight scope)

**Status:** Design handoff — Gizmo → Ett → Nutts
**Sprint:** 13.5 (UI polish follow-up to S13.4)
**Scope:** 4 small, bundled deliverables on top of the S13.4 shop card grid. No new screens, no balance, no new items.

---

## 0. Scope discipline (read this first, Nutts)

**Nutts timed out on initial spawn in S13.3 *and* S13.4.** S13.5 is deliberately scoped smaller than S13.4 to break that pattern. The file to understand is exactly one: `godot/ui/shop_screen.gd`. One test file is new: `test_sprint13_5.gd`. One existing test file grows by ~1 assertion: `test_sprint13_4.gd` (only if Optic wants the F1 regression there instead; default is the new file).

### DO NOT EXCEED (hard cap)

- **Files touched:** `godot/ui/shop_screen.gd`, `godot/tests/test_sprint13_5.gd` (new), `docs/gdd.md`, one SFX resource folder (`godot/assets/audio/shop/` — placeholder `.ogg` or `.wav` files, OR just string constants pointing at future paths — see §4).
- **LoC budget:** ≤ ~120 lines added/changed in `shop_screen.gd`. If you're past that, stop and flag Ett.
- **New nodes:** ≤ 2 (one AudioStreamPlayer; one Tween-driven scale anim lives on the existing buy Button). No new scenes.
- **Ceiling per spawn (Specc recommendation):** 1 medium file edit + ≤ 3 small edits + 1 test file. If finalize (PR body + GDD cross-links) is still open after that, a second explicit finalize spawn is fine.

### NOT in S13.5 (deferred to S13.6+)

- Hover shimmer on cards (no cursor in the QA loop, hard to test).
- Owned-item "check stamp" animation.
- Expansion transition easing / tweened panel open/close.
- Pixel-level screenshot diffs (blocked on F4 — no Godot web build in CI).
- Real commissioned SFX / art.

If any of those "just feel like they'd fit here" — they don't. Push them to S13.6.

---

## 1. Why this sprint

S13.4 shipped the card grid structurally (A−, 42/42 structural assertions). Playtesters can now scan the shop, but the **interaction layer is still silent**: no audio feedback on buy, no motion on successful purchase, no visual nudge toward items they haven't seen yet. Specc's audit also surfaced one latent defect (F1) we're cleaning up with a one-line fix.

The design goal for S13.5 is **"the shop feels alive"** without touching any of the pillars we left untouched in S13.4 (combat sim, chassis data, economy).

---

## 2. Goals & non-goals

### Goals
1. Fix F1 precedence bug so free items render + function correctly (forward-compatible).
2. Give the buy action a short, legible motion cue (~120 ms) so purchases feel confirmed.
3. Cover three moments in the buy loop with audio tokens: buy success, buy failure (can't afford), card tap-to-expand.
4. Nudge the player's eye to newly-available items on **first open of a shop phase**.

### Non-goals (S13.5)
- Any change to card layout, sizing, column rules, archetype tags, section order.
- Any change to `GameState.buy_*` or the `continue_pressed`, `item_purchased` signal contracts.
- Real SFX assets (placeholders/tokens only — see §4).
- Combat, balance, economy, chassis, Fortress loadout. S14 still owns Fortress.

---

## 3. Deliverables (3 concrete items + 1 hotfix)

### D0 — F1 hotfix (one line)

**File:** `godot/ui/shop_screen.gd` ~line 427.

**Replace:**
```gdscript
buy.text = "BUY — %d 🔩" % price if price > 0 else "TAKE (Free)"
```

**With (explicit parenthesization, author-intent-correct):**
```gdscript
buy.text = ("TAKE (Free)" if price <= 0 else "BUY — %d 🔩" % price)
```

**Why:** Specc F1 — current grouping is `("BUY — %d 🔩" % price) if price > 0 else "TAKE (Free)"`, which *happens* to be the correct user-facing behavior today but matches neither Boltz's read nor forward-compatibility with free items. Explicit form eliminates ambiguity and the latent foot-gun.

**Acceptance:** Unit test constructs a mock item with `price = 0`, calls `_render_card`/expansion path, asserts:
- `BuyButton.text == "TAKE (Free)"`
- No `%d` formatting crash.
- `BuyButton.disabled == false` (free items are takeable, not owned).
- Pressing it still routes through `_on_buy` with correct category/type (the handler is authoritative on deduction — bolts should not go negative on a price=0 item).

---

### D1 — Purchase animation (~120 ms scale pulse)

**Trigger:** `_on_buy` returns `success == true` (i.e. before `_build_ui()` rebuilds). Animate the just-pressed `BuyButton` (or the card root; prefer whichever is still in the tree after the branch — see note below).

**Animation:**
- Scale 1.0 → 1.12 → 1.0 over **120 ms** total (60 ms up, 60 ms down).
- `Tween.TRANS_QUAD`, `Tween.EASE_OUT` up; `Tween.EASE_IN` down.
- Pivot = center of the card (`pivot_offset = size / 2`).

**Implementation notes for Nutts:**
- `_on_buy` currently calls `_build_ui()` immediately after a successful purchase, which nukes the button. **Re-order:** play the tween first, `await tween.finished`, *then* rebuild. Budget is one `await`; do not refactor `_build_ui`.
- If the tween-then-rebuild re-order feels fragile, alternative: emit the animation on the **card node** (not the button), play it, then rebuild. Either works; pick whichever is fewer lines.
- Single active tween per purchase. Do not stack.

**Why this motion, not particles:** A 120 ms scale pulse is one `create_tween()` call and ~6 lines of GDScript. A particle burst is a `GPUParticles2D` node, a one-shot emission config, and a texture. Scale pulse stays inside the LoC budget.

**Acceptance:**
- Test: after a successful buy, the animation state is observable for at least one frame before rebuild (e.g. `scale.x > 1.0` during the tween, or a `_last_purchase_anim_playing` flag is set true briefly).
- Test: failed buy (unaffordable — which is already disabled, but cover the edge) does **not** schedule the tween.
- Screenshot-testable: pre-buy card scale = 1.0; mid-buy (tween running) > 1.0. Optic gets a tween-state probe.

---

### D2 — Audio tokens (3 SFX)

**Moments:**
| Token | When | Placeholder path |
|---|---|---|
| `SFX_BUY_SUCCESS` | `_on_buy` success | `res://assets/audio/shop/buy_success.ogg` |
| `SFX_BUY_FAIL` | `_on_buy` failure *or* tap on a disabled/unaffordable buy button | `res://assets/audio/shop/buy_fail.ogg` |
| `SFX_CARD_TAP` | card tap-to-expand (and tap-to-collapse — same SFX, players don't need two) | `res://assets/audio/shop/card_tap.ogg` |

**Implementation:**
- Define the three path strings as `const` at top of `shop_screen.gd`.
- One `AudioStreamPlayer` child node (name: `ShopAudio`). `_play_sfx(token: String)` helper that `load()`s the stream, assigns, and plays. Graceful no-op if the file is missing (`if ResourceLoader.exists(path)`), so Nutts can ship **without** committing real audio files if that's easier.
- Prefer: commit 3 tiny placeholder `.ogg` stubs (even 50ms silence or free-licensed generic UI clicks) so the code path is exercised. If finding/generating 3 audio stubs is a >10-minute detour, ship string constants only and leave a `TODO(audio)` comment pointing at this doc. **Either is acceptable.**
- Document all three tokens in `docs/gdd.md` §10 (see §6 below) so the audio designer knows what to replace.

**Why tokens, not real SFX:** No audio designer in the loop yet; real commissioned SFX is S14+. We want the wiring done so swapping files later is 1-line per token.

**Acceptance:**
- Test: `SFX_BUY_SUCCESS`, `SFX_BUY_FAIL`, `SFX_CARD_TAP` constants exist and are non-empty strings pointing under `res://assets/audio/shop/`.
- Test: `_play_sfx` exists and does not crash when called with a non-existent path (safe-load pattern).
- Test: successful buy triggers `_play_sfx(SFX_BUY_SUCCESS)` (spy / flag on the audio player, or a `_last_sfx_played` string for test observability).
- Test: card tap triggers `_play_sfx(SFX_CARD_TAP)`.

---

### D3 — "New item" pulse (first-open-this-phase)

**Goal:** When the shop screen opens for the **first time in a given shop phase**, every item that wasn't visible in the previous shop phase gets a subtle highlight for ~2 seconds, then settles into normal state.

**Visual:**
- Soft outer glow (cream `#F4E4BC` @ 40% alpha) on the card border, pulsing sine at **1 Hz** for **2.0 s total** (2 full pulses).
- After 2 s, remove the highlight (set alpha to 0, or free the highlight node).
- If user taps the card during the pulse, cancel the pulse on that card (tap already draws attention).

**State model:**
- `GameState` (or the shop screen, if `GameState` edits are out of budget) tracks a `_seen_shop_items: Dictionary` of `{"weapon:3": true, ...}` keyed by `"{category}:{type}"`.
- On `_build_ui()` during a shop-open, diff current catalog vs `_seen_shop_items`. Any item not in the set gets `is_new = true` on its card render. Then add everything currently visible to the set.
- Across shop phases: the set persists on `GameState`; it does *not* reset between shop phases. "New" = literally never seen before by this run.
- Reset: on run-end / new-run (if that hook doesn't exist as a clean callable, **flag Ett** — do not invent a new GameState lifecycle for this; fall back to "just shop_screen-local memory that resets on `_ready`" and note the gap).

**Implementation notes for Nutts:**
- Prefer putting `_seen_shop_items` on `shop_screen` itself (scope-local) if `GameState` doesn't already have an obvious place for it. "First-time this session" is good enough for S13.5 — cross-run persistence is overkill and likely pushes you over budget.
- Highlight can be a `ColorRect` or `Panel` child of the card with a modulated alpha, tweened on a loop (`Tween.set_loops(2)`).

**Acceptance:**
- Test: first `_build_ui()` call marks every card as new; on second call with no catalog change, no cards are marked new.
- Test: tapping a pulsing card stops its pulse (tween is killed / node removed).
- Test: `_seen_shop_items` set grows monotonically within a session.

---

## 4. SFX token specification (for future audio designer)

These tokens are the contract. When real SFX lands, replace the `.ogg` files at these paths; no code changes needed.

| Token | Duration | Character | Reference |
|---|---|---|---|
| `SFX_BUY_SUCCESS` | 150–300 ms | Bright, confident, ascending — "chachink" / coin-drop / register-close feel. Not cutesy. | Hades shop confirm, Into the Breach unit-deploy |
| `SFX_BUY_FAIL` | 100–200 ms | Low, short, muted thud — "nope". Not alarming. | Hearthstone can't-afford, Slay the Spire invalid-click |
| `SFX_CARD_TAP` | 60–120 ms | Soft paper/card flip — mechanical but light. Same SFX for expand and collapse. | StS card hover, Monster Train card click |

Volume: all three at -6 dBFS peak. Should be audible over a quiet gameplay bed but not dominate.

---

## 5. Acceptance criteria (summary, 6 items)

For S13.5 to ship, all of the following must pass:

1. **Regression:** 72/72 pre-S13.4 tests + 42/42 S13.4 tests still pass (no deletions, no skips).
2. **F1 fixed:** test with `price = 0` mock item → `BuyButton.text == "TAKE (Free)"`, no crash, buy handler callable.
3. **Purchase animation exists:** after successful buy, animation state is observable (tween running, or flag set) for ≥1 frame before `_build_ui()` rebuild.
4. **SFX tokens present:** 3 `const` path strings in `shop_screen.gd`, safe-load `_play_sfx` helper, wired to the three moments in D2.
5. **New-item pulse works:** first shop open marks every card new; cards not in the "seen" set on a given open pulse for ~2 s; tapping a pulsing card cancels its pulse.
6. **Scope discipline:** `shop_screen.gd` diff ≤ ~120 LoC, ≤ 2 new nodes per card-rebuild, only the files listed in §0 touched.

---

## 6. GDD updates (small)

### §10 (UX) — append

> **Shop Polish (S13.5).** Purchase interactions get a 120 ms scale pulse confirmation. Three audio tokens wired (`SFX_BUY_SUCCESS`, `SFX_BUY_FAIL`, `SFX_CARD_TAP`) with placeholder files; real SFX commissioned in S14+. Newly-available items get a 2-second cream-colored pulse on first-ever appearance in a session, driven by a `_seen_shop_items` set (scope: `shop_screen.gd` local for S13.5; elevate to `GameState` if cross-run persistence becomes needed).

### §12 (Balance v4 note) — append

> **S13.5 is UI/UX polish only.** No economy, prices, items, chassis, weapons, armor, or modules changed. Fortress loadout pass still owed to S14.

---

## 7. Open questions / Ett flags

- **Cross-run persistence of "seen" items:** if `GameState` has no clean new-run hook, ship session-local and document the gap. Don't invent a lifecycle for this.
- **SFX file commit vs string-only:** Nutts' call based on what's faster. Safe-load pattern means code works either way.
- **Ett scoping:** per Specc F2, split Nutts into (a) hotfix + SFX wiring + animation, (b) new-item pulse + tests + GDD + PR finalize. Two small spawns beat one timing-out spawn. If that split is onerous, at minimum keep finalize (PR body + GDD cross-links) as its own explicit spawn.

---

*Gizmo, S13.5 design handoff — tight scope, deliberate ceiling.*
