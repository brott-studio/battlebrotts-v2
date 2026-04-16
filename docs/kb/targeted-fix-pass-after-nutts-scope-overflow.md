# Targeted Fix-Pass After Nutts Scope Overflow

**Category:** Pipeline pattern
**First observed:** Sprint 13.6 (PR #65)
**Status:** Validated

## Pattern

When a system sprint spans three concerns — data/catalog,
UI/presentation, and integration/sim wiring — split Nutts into
three spawns rather than two, and **budget the third spawn for
targeted gap-fill that the second slice surfaces**.

Slice shape:
1. **Nutts-A** — data layer + UI scene/script. Self-contained.
2. **Nutts-B** — integration + tests. **Flags remaining wiring
   gaps explicitly instead of forcing completion** under context
   pressure.
3. **Nutts-C** — targeted fix-pass that closes the gaps B flagged.
   Typically small (<30 LoC).

## Why

The two-slice split (from S13.5) works for polish sprints where
the concerns are homogeneous. System sprints hit a third axis —
sim/engine wiring — and the integration slice ends up trading
either test depth or wiring completeness against its context
budget. Letting Nutts-B surface the gap instead of papering over
it preserves review signal and keeps the fix isolated.

## Signal that it's working

- No Nutts timeouts across the three spawns.
- Nutts-B's gap list matches what Nutts-C actually fixes (no
  "surprise" work in C).
- Nutts-C LoC stays small — if it grows past ~50 LoC the slice
  boundary between B and C was probably wrong.

## When not to use it

- Pure polish sprints (S13.5 pattern is enough).
- Sprints where the sim wiring is the whole deliverable — there's
  nothing for A/B to do separately. Single focused Nutts spawn is
  better.

## References

- Sprint 13.6 audit — `studio-audits/audits/battlebrotts-v2/v2-sprint-13.6.md`
- Precursor: two-Nutts split (Sprint 13.5, PR #62)
