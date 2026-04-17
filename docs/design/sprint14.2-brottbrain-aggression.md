# Sprint 14.2 — BrottBrain UX + Aggressive Cards

**Arc:** Sprint 14 "Make it a Real Game"
**Arc position:** 2 of 5 (+ 1 reserved)
**Theme:** Does it *feel* like a brott yet? — make the brain editor usable and let players actually build aggression.

---

## §0 Arc context

Sprint 14.1 closed the macro loop (finish a run, concede a fight, stop freezing on walls). 14.2 moves inward: the player can now *reach* BrottBrain, but when they get there the editor is clunky and the card library can't express "go get them." The felt question this sprint answers is **"when I open BrottBrain, can I build the brott I'm picturing in my head?"** Today: no — if the brott in your head is aggressive, chase-y, or target-selective, the cards for it don't exist, and the ones that do are buried behind an editor that visually lies about drag-to-reorder. After 14.2 the answer should be "yes, at least for the aggressive archetype."

---

## §1 Scope + DO NOT EXCEED

### In scope
1. **Slice A — BrottBrain UI polish:** reorder actually works, delete is obvious, tray stops colliding with card list.
2. **Slice B — Aggression cards:** 2–3 new cards (triggers + actions) that let the player compose charge / chase / focus-weakest behavior.
3. **Slice C — Card library audit + housekeeping:** trim or reword cards that don't map to game reality; fold the two S14.1 carry-forward test items in.

### DO NOT EXCEED ⚠️
- ❌ Rewrite of the card model (`BehaviorCard` shape stays; we extend enums, not schema)
- ❌ Full drag-and-drop implementation with ghost cards, snapping, animations — reorder-by-buttons is fine, **we just need to stop *claiming* drag in the file header and make buttons unambiguous**
- ❌ Counter-play picker (still parked)
- ❌ New stances (four stances is enough; cards modulate stance, not replace it)
- ❌ Card library rewrite — audit is *trim + reword*, not rebuild
- ❌ Visual redesign of BrottBrain screen (layout fix only, no theme pass)

---

## §2 Slice A — BrottBrain UI polish

**File:** `godot/ui/brottbrain_screen.gd` (single file; there is no `.tscn`, the screen is built in code)
**Brain model:** `godot/brain/brottbrain.gd` — untouched by Slice A.

### Verified bug shapes (Gizmo-confirmed from code read)

**Bug A1 — "Drag doesn't drag."**
- The file's doc comment says `# Sprint 4: Card-based visual editor with drag-to-reorder` but the actual implementation is `▲ Up` / `▼ Down` buttons operating on `selected_card_index` (see `_move_card_up` / `_move_card_down`, lines ~363–380).
- Selection happens via an almost-invisible overlay `select_btn` (`modulate = Color(1,1,1,0.01)`) on top of each card row. There's no visual selected-state feedback on the card itself — you tap, nothing changes, you try to drag, nothing happens.
- **Expected behavior after fix:** tapping a card visibly highlights it (border color change or modulate), the Up/Down buttons become enabled/disabled based on selection, and the doc comment stops lying.

**Bug A2 — "Delete feels unintuitive."**
- Each card has a `✕` button at `(625, y+10)`, 35×28 px (line ~284). It works. But there's no confirmation, no hover affordance beyond the default Godot button, and on small cards the `✕` sits visually adjacent to the invisible select overlay — clicks near the right edge are ambiguous.
- **Expected behavior:** `✕` button stays, but gets a clearer affordance (tinted red, wider hit area, or a trash icon). Clicking `✕` should not also trigger select.

**Bug A3 — "Overlapping condition boxes."**
- The WHEN tray wraps at `tx > 700` with `tx += 115` for 110px-wide buttons (lines ~157–170). With 10 trigger types that's 2 rows. The tray's start Y (`tray_y = maxi(y + 15, 380)`) floats based on how many cards are placed — once you hit ~4–5 cards, `y` climbs past 380 and the tray's top row collides with the live card list's last row(s), producing visible overlap.
- **Expected behavior:** tray and card list never overlap. Either the tray is fixed-position with a scrollable card list above, or the card list caps at a height that reserves space for the 2-row tray.

### Acceptance criteria

- **AC1 (Selection visible, hard bar):** when a card is selected (`selected_card_index >= 0`), its row has a distinct visual state (e.g. border color ≠ default). Test: render with `selected_card_index = 2`, grep the resulting scene tree for a modulate/border override on index-2 children.
- **AC2 (Reorder buttons honest, hard bar):** with 0 cards or no selection, `▲ Up` and `▼ Down` are disabled. With selection at top, `▲ Up` disabled; at bottom, `▼ Down` disabled. Delete the misleading `drag-to-reorder` phrase from the file header.
- **AC3 (Delete distinct, hard bar):** `✕` button visually distinct from the row background (tinted or icon). Clicking `✕` removes the card without also changing `selected_card_index` to that now-freed slot.
- **AC4 (No overlap, hard bar):** with the maximum 8 cards added, the WHEN/THEN tray does not visually overlap the card list. Test: add 8 cards, inspect child Y positions — no tray child's rect intersects a card panel's rect.
- **AC5 (Tutorial copy update, soft bar):** the tutorial's step 3 ("Click a WHEN card, then a THEN card") still reads true after the Slice A changes. If selection model changes meaningfully, update the copy.

---

## §3 Slice B — Aggression cards

### Design signal

The *aggressive* stance already exists: `STANCE_NAMES[0]` = `"🔥 Go Get 'Em!"`, mapped in `Brawler`'s default brain. Stance 0 controls movement logic at the combat sim level — **the player already has access to an aggressive brott via the default stance.** What's missing is *conditional* aggression: "chase when they run," "focus the weakest," "commit to a target once I start hurting it." Those compose poorly in the current enum because the relevant triggers/actions aren't there.

### Proposed new cards

All items below are **proposed-new** unless otherwise noted. Existing enum values they live next to are cited for placement.

#### New triggers (Trigger enum, add after `WHEN_CLOCK_SAYS`)

1. **`WHEN_THEYRE_RUNNING`** *(proposed-new)*
   - Param: `int` — speed threshold in tiles/sec (default `4`)
   - Semantics: fires when enemy's velocity magnitude ÷ 32 ≥ threshold **and** enemy's velocity is away from `brott` (dot product of enemy_velocity and (enemy.position - brott.position) > 0).
   - Display: `🏃 When They're Running`, param type `"tiles_per_sec"` (new param formatter, or reuse `"tiles"` label with "/sec" suffix).
   - Existence check: `brott_state.gd` exposes `velocity` (verify at slice-spec time). If not, this becomes a two-tick position delta and we write a helper in `brottbrain.gd`.

2. **`WHEN_I_JUST_HIT_THEM`** *(proposed-new)*
   - Param: `int` — seconds of grace (default `2`).
   - Semantics: fires if `brott` has landed a hit on `enemy` within the last `param` seconds. Requires `last_hit_time_sec` field on `BrottState` (new).
   - Display: `🎯 When I Just Hit Them`, param type `"seconds"`.
   - Rationale: lets players write "once I'm on them, stay on them" — the core of commitment.

#### New actions (Action enum, add after `HOLD_CENTER`)

3. **`CHASE_TARGET`** *(proposed-new)*
   - Param: `none`
   - Semantics: sets `movement_override = "chase"` — combat_sim interprets as "move toward enemy at stance-max speed, ignoring normal stance-level kiting logic for this tick." Distinct from stance 0 in that it *overrides* whatever stance the brott is currently in (e.g. lets a `Play it Safe` brott lunge for a kill).
   - Display: `🏃 Chase Them`, param type `"none"`.
   - Sim-side work: `combat_sim.gd` handles `movement_override == "chase"` symmetrically to existing `"cover"` / `"center"`.

4. **`FOCUS_WEAKEST`** *(proposed-new, composite)*
   - Param: `none`
   - Semantics: sugar. Sets `target_priority = "weakest"` **and** clears any pending target lock for this tick. Today a player can write `WHEN ... → PICK_TARGET(weakest)`, but the param is a string dropdown that new players don't discover. `FOCUS_WEAKEST` is a one-click preset card for the most common aggressive targeting choice.
   - Display: `🎯 Focus the Weakest`, param type `"none"`.
   - Alternative: skip if audit reveals `PICK_TARGET` is already discoverable enough. **Gizmo lean: keep it — discoverability is the whole point of the slice.**

#### Not shipping (considered, cut)

- **`PURSUE_UNTIL_DAMAGE`** — suggested in task, but it's `FOCUS_WEAKEST` + `WHEN_I_JUST_HIT_THEM` composed. Let the player compose it themselves; don't pre-bake.
- **`CHARGE`** as distinct action — functionally identical to `CHASE_TARGET` for the first 1–2 seconds, and the word "charge" implies an animation/dash we don't have. Fold into chase.

### Composition examples (docstring candidates for slice brief)

- **Pit bull:** `WHEN They're Hurt (30%) → Focus the Weakest` + `WHEN I Just Hit Them (2s) → Chase Them`. Once you draw blood, you don't let go.
- **Lunge finisher (Fortress):** default stance `Play it Safe` + `WHEN They're Hurt (20%) → Chase Them`. Turtle until the kill opportunity, then commit.
- **Rundown (Brawler vs Scout):** `WHEN They're Running (5 tiles/sec) → Chase Them` + `WHEN They're Close (2) → WEAPONS(all_fire)`.

### Acceptance criteria

- **AC6 (Triggers fire correctly, hard bar):** unit tests in a new `test_sprint14_2.gd` covering `WHEN_THEYRE_RUNNING` (100 seeds, stationary enemy = never fires, fleeing enemy = always fires past threshold) and `WHEN_I_JUST_HIT_THEM` (fires within grace window, not after).
- **AC7 (Actions move the brott, hard bar):** `CHASE_TARGET` override causes `brott` to close distance on `enemy` over 30 sim ticks — assert final distance < initial distance by a margin determined at slice-spec time (suggest 2 tiles).
- **AC8 (Pit-bull composition wins, soft bar):** Brawler with the "pit bull" composition beats unmodified Brawler ≥ 55/100 seeds. If 50/100, reword; if <45/100, investigate before shipping.
- **AC9 (Editor surfaces new cards, hard bar):** `TRIGGER_DISPLAY` and `ACTION_DISPLAY` arrays include all shipped new cards with their param metadata.

---

## §4 Slice C — Card library audit + housekeeping

### Audit table

Column key: ✅ keep as-is · ✏️ reword · ✂️ trim · 🆕 add (covered by Slice B).

**Triggers (current 10):**

| # | Current label | Verdict | Note |
|---|---|---|---|
| 0 | When I'm Hurt | ✅ | Core. |
| 1 | When I'm Healthy | ✅ | Core. |
| 2 | When I'm Low on Juice | ✏️ | Reword → `When I'm Low on Energy`. "Juice" is cute, but new players tested in 13.x didn't parse it. Confirm during slice spec. |
| 3 | When I'm Charged Up | ✅ | Parses fine. |
| 4 | When They're Hurt | ✅ | Core. |
| 5 | When They're Close | ✅ | Core. |
| 6 | When They're Far | ✅ | Core. |
| 7 | When They're In Cover | ✅ | Ties to pillar geometry — this one is genuinely grounded. |
| 8 | When Gadget Is Ready | ✅ | Core. |
| 9 | When the Clock Says | ✂️ | **Trim.** This is the "irrelevant card" Eric flagged. Match time does not feel like a resource the player tracks; in playtest nobody builds a brain around "at 30 seconds, switch stance." Clock-conditional behavior is a sim-level curiosity, not a design tool. Remove from `TRIGGER_DISPLAY`, keep in enum for save-compat (load existing cards referencing it fine, just don't surface in the tray). |

**Actions (current 6):**

| # | Current label | Verdict | Note |
|---|---|---|---|
| 0 | Switch Stance | ✅ | Core. |
| 1 | Use Gadget | ✅ | Core. |
| 2 | Pick a Target | ✏️ | Keep, but the dropdown values `nearest` / `weakest` / `biggest_threat` need display-friendly labels. Slice B adds `Focus the Weakest` as a sugar shortcut; `Pick a Target` stays for `nearest` and `biggest_threat`. |
| 3 | Weapons | ✅ | Core. Verify `hold_fire` actually does something distinct from `conserve` in `combat_sim.gd` at slice-spec time — if not, trim `hold_fire` from `WEAPON_MODES`. |
| 4 | Get to Cover | ⚠️ | Header comment in `brottbrain.gd` says "not fully implemented" (line ~25). **Decision needed:** either finish it this slice (feel risk — cover is the pillars, pathing may be weird) or hide it from the tray with the same save-compat approach as `WHEN_CLOCK_SAYS`. **Gizmo lean: hide.** Finishing cover is a Sprint 14.3+ question, not a 14.2 concern. |
| 5 | Hold the Center | ✅ | Works, grounded (arena center is a real concept). |

### Housekeeping (from S14.1 carry-forward)

Per `docs/plans/sprint14.2-carryforward.md`:

1. **Tighten `test_sprint11.gd` AC6 threshold `≤10` → `≤9`.** One-line diff. Plan calls this a non-blocking nit; folding into 14.2 closes the ticket.
2. **Tighten `test_sprint11_2.gd` duplicate moonwalk assertion threshold to match `≤9`.** The written plan recommends option (a) tighten (not delete). Gizmo's prior-session note leaned delete-as-redundant; on re-read of the plan, **defer to plan: tighten.** If at slice-spec time Nutts confirms the assertion is byte-for-byte redundant with S11 AC6 (same entity, same sim path, same call site), escalate the delete decision to Eric — otherwise keep both at `≤9`.

Carry-forward item 3 (post-movement stuck evaluation restructure) is explicitly "don't schedule yet" per plan — **out of scope**.

### Acceptance criteria

- **AC10 (Clock trigger hidden, hard bar):** `WHEN_CLOCK_SAYS` does not appear in the WHEN tray after `_build_ui()`. A save file with an existing `WHEN_CLOCK_SAYS` card still loads and evaluates without crash.
- **AC11 (Cover action hidden, hard bar):** same treatment as AC10 for `GET_TO_COVER` unless Slice B expands to ship a working cover pathfinder (Gizmo: no).
- **AC12 (Reword pass, soft bar):** "Low on Juice" → "Low on Energy". Spot-check tutorial and tooltip copy for other "juice" references.
- **AC13 (Carry-forward tests pass, hard bar):** `test_sprint11.gd` AC6 asserts `≤ 9`; `test_sprint11_2.gd` moonwalk assertion also asserts `≤ 9`. Both pass on current main's sim behavior (observed 8/100 per plan).

---

## §5 Hard bars vs soft bars — summary

| Slice | Hard bars (regression-testable) | Soft bars (feel / playtest) |
|---|---|---|
| A · UI polish | AC1 selection visible, AC2 reorder buttons honest, AC3 delete distinct, AC4 no overlap at 8 cards | AC5 tutorial copy still reads true |
| B · Aggression cards | AC6 new triggers fire on unit tests, AC7 CHASE_TARGET closes distance in sim, AC9 editor surfaces new cards | AC8 pit-bull composition wins ≥55/100 (feel-threshold; reword if marginal) |
| C · Audit + housekeeping | AC10 clock hidden, AC11 cover hidden, AC13 test thresholds `≤9` | AC12 "juice" → "energy" reword |

Regression watch: the Slice B sim additions (new triggers touching `brott_state` fields, new `movement_override = "chase"` path) are the most likely source of a moonwalk delta. Nutts should re-run `test_sprint11.gd` / `test_sprint11_2.gd` against the new combat_sim before the PR closes.

---

## §6 Open questions for Eric

**None genuinely blocking.** The creative calls Gizmo has already made:

- `FOCUS_WEAKEST` ships as sugar action (discoverability wins). Can be pulled if Boltz argues it's redundant.
- `CHARGE` is folded into `CHASE_TARGET` (no dash animation to justify the separate noun).
- `PURSUE_UNTIL_DAMAGE` is user-composable from `WHEN_I_JUST_HIT_THEM` + `CHASE_TARGET`, so not pre-baked.
- `GET_TO_COVER` is hidden, not implemented — deferred to post-arc.
- `WHEN_CLOCK_SAYS` is hidden, not deleted — save-compat preserved.
- Carry-forward moonwalk assertion is **tightened**, not deleted, per written plan.

**Single flag for Eric if he wants to weigh in:** is "Low on Juice" worth losing? It's a voice note (slightly playful, slightly on-brand for BattleBrotts). Gizmo trims it; Eric may want to keep it. Either way is fine, not worth a round-trip if he's busy — Nutts can pick during Slice C.

---

_Drafted by Gizmo 2026-04-17. Format follows sprint14.1-loop-closure.md._
