# KB — Nutts Task-Timeout Pattern

**Discovered:** S13.4 (2026-04-16), pattern across S13.3 + S13.4
**Severity:** Process / pipeline
**Impact:** Pipeline stalls mid-sprint, requires subagent re-spawn; ~30 min cost per occurrence.

## Observation

Nutts has now timed out on the **first implementation spawn** for two
consecutive sprints, requiring a re-spawn to complete the work:

- **S13.3 — Chassis balance pass.** Edit-tool unicode mismatch loop on
  GDD / design-doc tables (em-dashes, `×`). See KB
  `edit-tool-unicode-mismatch-loop.md`.
- **S13.4 — Shop Card Grid MVP.** Scope-size timeout. The sprint
  combined a 315-line file rewrite (`shop_screen.gd`), a design-doc
  commit, a data rename pass across `ArmorData` + dependent tests,
  and GDD §10 / §12 updates. Nutts hit its turn/time budget before
  finalizing the PR.

Two different root causes (unicode-matching infinite-loop vs plain
volume), but the same operational symptom: **Nutts doesn't cleanly
checkpoint partial progress**, so the re-spawn reconstructs mid-flight
state from git + PR body and picks up the remaining edits.

## Why it matters

The re-spawn pattern *works*, but:

1. It costs ~30 min of wall-clock per occurrence (detect timeout,
   spawn, reconstruct state, finish).
2. It produces noise in the pipeline story — audits have to narrate
   "Nutts re-spawned" as a process footnote and the PR body has to be
   reconciled by a finalize step.
3. Two in a row is a pattern, not a fluke. If this recurs on S13.5
   polish work it becomes the baseline expectation, and the pipeline
   loses its "one clean spawn per role" shape.

## Triggers seen

- GDD / design-doc tables with multi-byte glyphs in adjacent columns
  (S13.3).
- Single-sprint commits that combine (a) a medium-to-large file
  rewrite with (b) a cross-cutting rename / data pass plus (c)
  multiple doc updates (S13.4).

Expected future triggers:

- Shop-polish sprints that layer animation / SFX / transition logic
  on top of the existing 315-line `shop_screen.gd`.
- Any sprint that bundles "engine change + data rename + GDD update"
  into one Nutts spawn.

## Mitigations

**Ett-facing (task breakdown):**

1. **Smaller Nutts task chunks.** Rough ceiling per single spawn:
   *one medium file rewrite* **or** *~3 small edits*, not both. If a
   sprint genuinely needs both, split into two explicit Nutts slices.
2. **Explicit finalize-step spawn.** The final "PR body + GDD cross-
   links + test updates" pass should be its own spawn with its own
   turn budget, not bolted onto the tail of an implementation spawn.
3. **Pre-split at design time.** On UI-rewrite / multi-file pivot
   sprints, Ett should preemptively scope two slices:
   - Slice A: design doc commit + data rename + test scaffold.
   - Slice B: primary file rewrite + visual ACs.
   Each as a separate Nutts spawn, reviewed independently.

**Tooling-facing:**

- The edit-tool retry logic (S13.3 trigger) is a separate workstream
  tracked in `edit-tool-unicode-mismatch-loop.md`. Fixing it there
  removes one of the two failure modes but not scope-size timeouts.
- Consider a Nutts-internal checkpoint: emit a "partial progress" git
  commit every N edits so re-spawns can `git log` to see exactly
  where the previous spawn stopped, rather than diffing against PR
  body prose.

## Status

- **S13.3:** closed via unicode-loop KB + re-spawn workflow.
- **S13.4:** this entry; mitigations go live for S13.5 scoping.
- **Revisit:** if S13.5 or later also hits a Nutts timeout, escalate
  to a dedicated tooling sprint on Nutts checkpointing.

## See also

- `edit-tool-unicode-mismatch-loop.md` — S13.3 unicode trigger.
- `monolithic-sprint-commits.md` — related anti-pattern on PR size.
- `latent-bugs-inactive-paths.md` — unrelated, but referenced in the
  S13.4 audit's F1 finding.
