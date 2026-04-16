# KB: Design Agent Verifies Key Noun Bindings Against Codebase Before Brief Commits

**Source:** Sprint 13.9 audit (two data points: S13.6 + S13.9)
**Category:** Pipeline / Process

## Pattern

Before the design agent (Gizmo) commits a brief to the pipeline,
they run a verification pass over every **load-bearing noun** in
the spec and grep the codebase for:

1. Name collisions (the spec's noun is already used for
   something else).
2. Name shadows (the spec's noun is similar enough to an
   existing symbol to confuse readers).
3. Prior conflicting uses (an earlier sprint used the noun with
   different semantics).

If any check triggers, flag the rename **before the brief
commits**, not after implementation has started. Rename in-
flight; commit the corrected brief.

## Why It Works

1. **Terminology collisions compound.** Ship a brief with a
   colliding noun and the collision appears in code, tests,
   GDD, audit language, and every future reference. Fixing it
   post-merge is a rename sprint of its own.
2. **The design agent is the right layer.** Design is the first
   step where nouns concretize. Catching collisions any later
   (at planning, implementation, or review) means at least one
   deliverable was authored against the wrong name.
3. **Grep is cheap; rename is expensive.** The pre-commit check
   is a handful of `rg` passes. The post-merge rename is a
   multi-file edit with test churn and doc updates.
4. **Reinforces the pipeline's verification-pushdown philosophy.**
   Each gate catches failures at the layer where they're
   cheapest to fix.

## Evidence

**Two mission-critical catches in three sprints.**

**S13.6 — Chassis archetype mapping.** Spec used an archetype
noun that already named a chassis in the codebase. Gizmo flagged
the collision during design verification; deliverable was
renamed before the brief committed.

**S13.9 — "Fortress" opponent loadout.** Spec called the AI
opponent concept "Fortress." Codebase already had "Fortress" as
a chassis name. Shipping as-written would have produced
colliding references across opponent data, archetype taxonomy,
picker code, GDD §6.3, and tests. Gizmo caught it pre-brief;
the deliverable was renamed to "Opponent Loadouts" in-flight;
sprint shipped clean.

Two data points of the same shape from the same agent at the
same pipeline stage. That's a pattern.

## The Check (concrete)

Before committing the brief, the design agent:

1. Lists every load-bearing noun in the spec (archetypes,
   systems, deliverable names, new class/struct names).
2. For each noun, runs `rg -i '\b<noun>\b' -l` across the
   codebase (and GDD, and prior audits if accessible).
3. Reviews matches for collision / shadow / prior-conflicting-
   use.
4. If any match looks like a collision, flags it in the brief
   response with a proposed rename, **and does not commit the
   brief until resolved.**
5. If no matches, notes the noun as verified in the brief.

## Trilogy: Pre-Implementation Verification Patterns

This KB completes a trilogy of verification-pushdown patterns
across the pipeline:

- **Design-time (this KB):** design agent verifies noun bindings
  against codebase before brief commits.
- **Plan-time (KB PR #68):** TPM verifies spec field names
  against codebase before brief-out.
- **Merge-time (KB PR #70):** reviewer runs actual CI on merged
  branch before approving.

Each pushes verification to the layer where the failure mode
actually surfaces. Read together, they form the pipeline's
verification posture: **every gate catches its own failure
class, and no gate trusts the next one to catch what it
should have caught itself.**

## Pairs With

- **KB PR #68** — TPM verifies spec field names against codebase
  before brief-out. Plan-time counterpart.
- **KB PR #70** — Reviewer runs actual CI on merged branch
  before approving. Merge-time counterpart.

## Anti-Pattern

"The spec says Fortress, ship Fortress." Trusting spec
terminology without verifying it against the codebase. This is
the failure mode the pattern exists to prevent — and the mode
Gizmo's pre-design pass has caught twice now.
