# UX Vision — Eve from WALL-E

**Established:** Sprint 13.10 arc-wrap playtest, 2026-04-16
**Source:** Eric's direct quote: *"professional, clean, and polished. Kind of like Eve from Wall-E."*

Sibling to `audio-vision.md` (also WALL-E). This codifies the UX polish target for Sprint 14 onward.

## Pillars

- **Professional** — restrained, confident, no toy-like overstatement. No cartoon bounces, no emoji UI, no wacky typography.
- **Clean** — strong negative space, minimal ornament, typography-led hierarchy. One voice per screen.
- **Polished** — motion is smooth, feedback is immediate, transitions don't jar. Nothing feels unfinished.
- **Smooth curves** — Eve's silhouette is round, soft, matte. UI corners should lean the same way.
- **Intentional color** — restrained palette, color as accent not as decoration. Let motion and whitespace do the work.

## Anti-patterns (do NOT ship)

- Cluttered HUDs with 8+ simultaneous badges/numbers
- Hover-only affordances (already flagged in playtest — tooltips must be visible by default)
- Popup spam (random events, crate/trade prompts) that interrupt flow
- Hard corners + neon + busy gradients (this is the inverse of Eve)
- Overlapping UI elements that mask critical buttons (also flagged in playtest)

## Writing guidance

- Copy should match BrottBrain voice (concise, present tense, dry humor per GDD §11) — but UI chrome itself should feel calm, not try to be funny.
- Labels short. Tooltips one sentence. Explanations live in dedicated info screens, not shoved into controls.

## Checklist for S14 polish pass

- [ ] Tooltips visible by default, not hover-only
- [ ] No UI overlap when inventory/loadout is full
- [ ] Scroll behaviors respect user position (no jump-to-top on click)
- [ ] Random-event popups: skippable, rarer, or redesigned to feel rewarding
- [ ] Energy bar (and every HUD element) has in-game explanation on first encounter
- [ ] League progression path visibly surfaced after a league's last win
- [ ] Motion curves eased, not linear/snappy
- [ ] Corners/shapes lean rounded over angular where the mechanic permits
