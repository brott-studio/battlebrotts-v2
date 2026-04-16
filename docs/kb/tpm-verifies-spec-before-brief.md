# KB: TPM Verifies Spec Field Names Against Codebase Before Brief-Out

**Source:** Sprint 13.7 audit
**Category:** Pipeline / Process

## Pattern

Before the TPM (Ett) hands a feature spec to the implementer
(Nutts), the TPM greps the target enums, class names, field names,
and effect kinds referenced in the spec against the **actual
source of truth** (GDD + code), not just against the feature
brief.

A thirty-second verification pass that catches spec errors **before
any code is written**.

## Why It Works

1. **Fails early.** Catches spec errors at the cheapest possible
   layer — before the implementer spawn, before exploration, before
   rework.
2. **Prevents Nutts failure cascades.** A spec referencing a
   non-existent field or enum value manifests downstream as either
   an exploration timeout (Nutts hunting for something that isn't
   there) or a Boltz-level rework. Both cost 15–60 minutes. The
   pre-brief grep costs 30 seconds.
3. **Keeps GDD and code aligned.** If the spec references
   something the code doesn't have, either the spec is wrong or
   the code is behind — either way, the TPM surfaces the gap at
   the right time to resolve it cleanly.
4. **Reduces scope inflation.** Forces the TPM to trim specs to
   what the codebase can actually express today, deferring
   infrastructure gaps to explicit sprints rather than
   accidentally bundling them into content work.

## Sprint 13.7 Evidence

Ett's pre-code audit on the trick content expansion spec caught
three material errors:

1. **Wrong field names** on trick effect payloads.
2. **Missing `CERAMIC` item class** — referenced in the spec,
   absent from the code's item class enum.
3. **Non-existent `MORALE_DELTA` effect kind** — spec assumed it
   existed; the code has no such dispatch.

Ett rewrote the trick set from 5 down to 3, aligned with what the
codebase could actually express. The downstream Nutts spawns (A
router + B wiring/tricks/tests) ran clean with no timeouts, no
rework, and Boltz's merge-round issues were narrow (CI workflow
gap + a narrative flavor inversion) rather than structural
rework.

Every one of those three catches would have been a Nutts failure
mode downstream.

## The Check (concrete)

Before brief-out, the TPM runs:

```bash
# Enum / class references in spec
grep -rn "enum ItemClass" godot/
grep -rn "enum EffectKind" godot/

# Field names the spec assumes
grep -rn "MORALE_DELTA\|CERAMIC" godot/
```

…and confirms every symbol the spec names actually exists in the
target codebase. If it doesn't, the TPM either:

- **Trims the spec** to what the code supports, or
- **Flags the gap** as prerequisite infrastructure work before the
  implementer is spawned.

## When to Apply

Every spec that references:

- Enum values (item classes, effect kinds, state machine states)
- Field names on data classes
- Function or method names on existing systems
- GDD section numbers or content taxonomies

In practice: every sprint spec that touches the data layer or
wires into existing systems — which is most of them.

## Related

- `monolithic-sprint-commits.md` — complementary: small specs with
  verified field names merge cleaner.
- Sprint 13.6 F3 (Gizmo exploration timeout pattern) — similar
  class of fix: kill exploration by providing correct context up
  front.
