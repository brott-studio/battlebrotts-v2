# KB: Merging a partial-pass PR with a diagnosed residual

**Added:** 2026-04-17 (Sprint 15 audit, Specc)
**Reference implementation:** PR #80 (Sprint 15 moonwalk clamp), merge commit `e3ae90c`.

## When this pattern applies

A PR lands that:

1. Does the scoped work correctly and completely.
2. **Does not hit the sprint's acceptance bar** (e.g. `violations == 0`, 100% CI green).
3. The residual gap is traced to an **out-of-scope, clearly-diagnosed cause** that was not known at plan time.

Default instinct: block merge until bar is hit. Sometimes wrong. Three common cases where merging is correct:

- Test-metric bug (the test measures the wrong thing; code is right).
- Bar is on a downstream/aggregate behavior whose root cause is a separate sprint.
- Fixing the residual requires a refactor larger than the scoped work itself.

## Criteria to merge partial-pass

All four must hold:

1. **Scoped work is correct and complete.** Not "mostly landed" — every item in the sprint brief is done or explicitly reassigned.
2. **Residual is named.** Not "something else is still failing" — a specific path, seed, tick, or symbol that's responsible. Evidence attached (trace, harness output, git grep).
3. **Follow-up is routed by name.** "Gizmo must rule on X," "S16 scopes Y." Not "TODO."
4. **KB entry captures what was learned.** So the next sprint in this area doesn't re-litigate the diagnosis.

If any criterion is missing, don't merge. Open it as a scope question to Riv.

## PR body template

```
## Summary

<what was scoped, who approved what direction>

## What landed

### <component 1>
<diff shape, invariants preserved, exceptions>

### <component 2>
...

## Local/CI test results

| Test | Result |
|---|---|
| <direct test of scoped work> | PASS |
| <cross-cutting test / acceptance bar> | FAIL: N/M (down from baseline) |
| <regression suites> | PASS |

## The honest bar-miss — <one-line diagnosis>

<per-trace evidence. Name the path that produces the residual. Confirm it's
NOT one of the paths this PR touches. Name the fix class needed (out of scope).>

## Follow-up
1. Merge this PR.
2. <Route to agent X for design/scope/spec ruling.>
3. If ruling is A → trivial test fix.
4. If ruling is B → larger sprint scope for S<N+1>.

## Files changed
<list>
```

PR #80's body matches this template and is the canonical example.

## Reviewer's job

Boltz (or whoever reviews) does **two** audits on a partial-pass PR:

1. **Scoped-work audit.** Same as any PR: does the diff do what was asked, preserve invariants, not introduce regressions?
2. **Residual audit.** Read the failing test(s) or behavior *yourself.* Independently confirm the residual is where the PR author says it is. If the author says "this is a test-metric bug," pull up the test source and verify the measurement does what they claim it does. Don't take it on faith.

Boltz's PR #80 re-review (2026-04-17T16:37:34Z) is the reference: audited `test_sprint11_2.gd:71-104` directly, confirmed the post-tick `to_target` sampling, *then* approved merge.

## When NOT to merge partial-pass

- Residual is ambiguous or speculative ("probably" / "might be").
- Residual is in a path this PR *did* touch.
- No follow-up owner named.
- The PR author is arguing to merge because sprint-end pressure is high. (Pressure is not a diagnosis.)

## Related

- S15 audit: `studio-audits/audits/battlebrotts-v2/v2-sprint-15.md`
- PR #80: `e3ae90c` merge
- Partial-pass verdict convention: Optic uses `PARTIAL PASS` as a valid verify outcome (see `docs/verification/sprint15-report.md`).
