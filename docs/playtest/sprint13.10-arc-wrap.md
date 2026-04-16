# Sprint 13.10 Arc-Wrap Playtest — Eric

**Date:** 2026-04-16
**Playtester:** Eric
**Build:** post-PR #71 (Sprint 13.9 merge, `5affe67`)
**Scope:** Scrapyard league, 3 opponents

This captures Eric's playtest observations at the close of the Sprint 13.x arc. **Findings feed Sprint 14 planning, NOT Sprint 13.10.** Sprint 13.10 stays the quiet arc-wrap (Boltz nits + `test_sprint2` cleanup only).

---

## Creative North Star (explicit)

Eric named **Eve from WALL-E** as the UX polish target: *"professional, clean, and polished. Kind of like Eve from Wall-E."* Sibling to the audio vision (`docs/kb/audio-vision.md`), also WALL-E. Captured in `docs/kb/ux-vision.md`.

## 🔴 Critical blockers (S14 must-fix)

- **No league progression UI.** Beat all 3 Scrapyard opponents. No visible path to advance to Bronze. Only REMATCH buttons surfaced. Hard dead-end in the loop — Eric said he wouldn't have known Bronze existed if not told.
- **Bots stuck on walls.** Bots stop moving mid-fight, always near walls, sometimes one-sided. Repeatable. Likely nav/collision. Observed: "last 5 shots of scout fight, both stopped and just shot."

## 🟠 Top 3 pain points

1. **Random events feel bad-chaotic** — annoying, interrupt building flow, not meaningful. Eric wants build + fight, not interruption. Options: reduce frequency, make skippable, or redesign to feel rewarding not disruptive.
2. **UI issues pervasive** (see specific list)
3. **Overall lack of polish** — expected for dev, but S14 target is Eve-tier

## 🟡 Specific UX issues

- Shop scroll too fast even at min setting
- Shop click jumps scroll to top — destroys flow
- Loadout no tooltips by default; hover-only, not discovered until late
- Loadout items cover shop button when full
- Crate/trade popups too frequent — break flow
- Crate-decision screen jarring as literal first player-facing screen with no context
- BrottBrain UI clunky: "drag" doesn't work (had to click-click), delete button unintuitive, boxes overlap
- Energy bar (blue) unexplained — Eric asked "what is this for?"

## 🔵 Feel issues

- **Scout is jerky — speed is probably fine.** Eric (clarified): *"speed might be okay if movement isn't jerky. i can imagine a fast bot rolling around."* Don't reduce speed cap — **fix smoothing**: turn rate, direction-change lerping, accel/decel curves. Target: Scout can stay fast as long as it moves like a rolling fast thing, not a teleporting fast thing. Prior quote for context (pre-clarification): "watching mice run around rather than weighty brotts."
- **Scrapyard fight 3 feels long when losing.** "I knew I was going to lose for a long time." Consider concede button and/or shorter fights at low HP.

## 🟢 BrottBrain cards

- **Wanted but missing:** aggressive behaviors. Explicit asks: "Charge," "Chase after." Vibe: commit to enemy, close distance.
- **Present but unwanted:** "Clock time" and similar abstract/timing cards felt out of place.
- **Verdict:** Library leans tactical/reactive. Needs aggressive/committal options.

## ✨ Positives — preserve

- Shop itself "super cool" (letter icons are placeholder, art planned)
- **Fight variance from same loadout is fun** — "totally different even though I didn't change any equipment!" Core positive. Protect this.
- First scout fight "incredibly exciting"
- Beating fight 3 felt earned
- BrottBrain crafting "almost fun" — rewarding when brott obeyed built logic
- Seeing brott execute his logic = satisfying

## Sprint 14 theme recommendations (Ett to plan)

Likely 2-3 sprints of material — don't cram:

- **Close the loop** — league progression UI (critical unblock)
- **Fix the ugly bugs** — wall-stuck nav, shop scroll, jump-to-top click
- **UX polish pass toward Eve-tier** — tooltips, overlap fixes, popup frequency, BrottBrain drag
- **Feel pass** — Scout movement smoothing + weight
- **Card library refactor** — add aggressive cards (Charge, Chase), audit for unwanted ones
- **Random events rethink** — reduce friction or redesign
