# GDD-Code Parity: Update Docs Inside the Arc That Touches the Mechanic

**Source:** Arc F.5 (S26.5 + retrospective on Arc F) — 2026-04-27
**Audit:** `studio-audits/audits/battlebrotts-v2/v2-sprint-26.1.md`

## The rule

Any arc that touches **RunState**, **GameFlow**, or any other core
mechanic-defining object must update the GDD section that documents that
mechanic **inside the same arc**. Not in the next arc. Not as a "follow-up
GDD pass." Inside this arc.

## Why

Arc F shipped a working roguelike RunState rewrite without writing
GDD §13 (Roguelike Run Loop). The "does the player start with a weapon?"
question therefore had **no canonical answer**. Code defaulted to
`equipped_weapons = []`. This shipped to playtest. The first roguelike
playtest hit a P0 blank-screen bug on the very first chassis-pick → battle
transition.

Arc F.5 had to:
1. Backfill GDD §13 (S26.5) — the canonical answer that should have existed before any code shipped.
2. Patch the symptom (S26.1 starter-weapon seed).
3. Close the framework gap that let it ship undetected (S26.3 user-flow smoke).

**Half of Arc F.5 was retrospective debt repayment for an Arc F discipline
miss.** The cost: one P0 playtest interruption, one full hotfix arc, three
sub-sprints of work, and a forced GDD update under hotfix pressure rather
than during the calm of arc-planning.

## The structural fix

Ett's arc / sprint plans MUST include either:

- A dedicated GDD-update sub-sprint inside the arc that introduces the
  mechanic, *or*
- A GDD diff bundled into the feature sub-sprint's own PR.

Rule of thumb for Ett: when an arc plan touches `godot/game/run_state.gd`,
`godot/game/game_flow.gd`, or any file with names matching `*_state.gd`,
`*_flow.gd`, or `*_data.gd` for a new mechanic, the corresponding GDD
section must appear in the arc's deliverables list. If it isn't there,
the plan is incomplete.

Specc audits should flag: any arc that ships mechanic-defining code
without a GDD diff in the same arc is a structural carry-forward,
regardless of test coverage or implementation quality.

## What "documented in the GDD" means

Concretely, for any new mechanic, the GDD section must answer:

- **Default values.** What does the player start with? What's seeded at
  state creation? (This is the question that wasn't answered for
  `equipped_weapons`.)
- **State invariants.** What conditions must be true for the state to be
  valid? (`equipped_weapons` non-empty when entering battle.)
- **Transitions.** Under what circumstances does the state change? Who
  writes to it?
- **Failure modes.** What happens if an invariant is violated?

If any of these four are missing from the GDD section, the doc is
insufficient and code will fill the gap with whatever the implementer
guessed. Code written against a gap-filled GDD ships gap-filled defaults
to playtest. See Arc F.5.

## Cross-references

- **GDD §13** is the post-Arc F.5 reference example of "what good looks
  like" — overview, RunState contract, structure, archetypes, flow,
  reward, controls, boss, run-end screens, and a deprecation map for
  superseded sections.
- **kb/patterns/default-starter-state.md** — the code-side discipline that
  pairs with this doc-side discipline.
- **kb/troubleshooting/blank-screen-godot-html5.md** — the symptom this
  rule prevents.
