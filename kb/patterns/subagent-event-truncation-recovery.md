# Subagent Event-Truncation Pattern on Opus 4.7 Build-Agent Role

**Source:** S21.2 audit (2026-04-23) — [audit](https://github.com/brott-studio/studio-audits/blob/main/audits/battlebrotts-v2/v2-sprint-21.2.md), tracking issue [#246](https://github.com/brott-studio/battlebrotts-v2/issues/246)
**Related:** SOUL.md "Long-running arc verification" (2026-04-22)

## Problem

Subagent completion events truncate on `github-copilot/claude-opus-4.7` when spawned in build-agent / verifier roles under the studio pipeline (Riv → Nutts / Optic). When this happens:

- The completion event arrives with final line cut mid-thought.
- Token-accounting reports `0 tokens in / 0 tokens out`.
- The **actual work on the remote** (git branch, PR, commits) often landed cleanly — the truncation is event-emission-only, not work-truncation.
- The parent orchestrator has no in-payload signal distinguishing "work failed" from "work succeeded but event truncated."

## Evidence

From a single sub-sprint (S21.2):

| Spawn | Model | Completion event | Actual work state |
|---|---|---|---|
| Nutts-initial (T1+T2+T3+test-enroll) | `github-copilot/claude-opus-4.7` | Truncated. 0/0 tokens. | 4 commits + PR landed (881 additions). |
| Nutts-fix (regression fixes) | `github-copilot/claude-sonnet-4.6` | **Clean.** Full payload. | 2 commits pushed. |
| Optic-verify | `github-copilot/claude-opus-4.7` | Truncated. Mid-sentence cut. | CI green on merge commit; Playwright baseline screenshots not captured. |

Sonnet 4.6 is the contrast data point. Same harness, same session shape, same tooling; different model; no truncation.

## How to recognize it

- Completion event final line ends mid-word or mid-sentence.
- Event payload says `status: completed successfully` but token counts are both 0.
- Promised artifact path (PR URL, audit file, commit SHA) not present in the payload.

If any of these, treat the event as **ambiguous**, not as a clean close.

## Remediation (tactical — in use)

### 1. Pivot to artifact-based verification when a completion event truncates

Do not trust a truncated event's implicit success signal. Before re-spawning, check remote state for the artifact the spawn was supposed to produce:

- Nutts spawn → check for branch + commits + PR on project repo.
- Optic spawn → check for `Optic Verified` check-run on merge commit and screenshots at expected paths.
- Specc spawn → check for audit file on `studio-audits/main` at the canonical path.

If the artifact is present and matches spec, proceed; the work landed, the event emission just failed. If the artifact is missing, re-spawn.

This is the canonical pattern from SOUL.md "Long-running arc verification" — artifact-based verification is the ground truth, not event propagation.

### 2. Sonnet 4.6 as build-agent fallback when Opus 4.7 truncates

If an Opus 4.7 spawn truncates on a given task shape, the re-spawn should run on Sonnet 4.6 as a **diagnostic experiment** (not a confident fix). Either outcome is informative:

- Sonnet runs clean → variable isolated to Opus 4.7 on that spawn shape; file as evidence for the framework investigation.
- Sonnet also truncates → route/harness/payload-size is suspect, not the model.

Framing matters: do not present model-swap as a confident cure when the root cause is unknown. It is a diagnostic instrument.

## Remediation (structural — proposed)

The tactical pattern above is the right fallback but it is bandage. Structural investigation owed, per HCD request, after Arc B close:

1. Capture 2–3 more truncation events with full gateway logs.
2. Compare Opus 4.7 vs Sonnet 4.6 spawn-payload sizes, tool-call counts, completion-event byte lengths.
3. Determine whether the truncation is: (a) the model's own payload limit, (b) gateway event-buffer limit, (c) route-specific config, or (d) token-accounting sync failure.
4. If (a): add pre-flight payload-size check to Riv's spawn logic. If (b)/(c)/(d): fix in the harness.

## When to reach for this KB entry

- A subagent completion event arrives that looks malformed (truncated text, 0/0 tokens, missing artifact ref).
- Before re-spawning, check the remote for the expected artifact.
- If the artifact landed: proceed with artifact-based verification, log the truncation event, do not re-spawn.
- If re-spawning is required, prefer Sonnet 4.6 as the retry model and frame it diagnostically.
