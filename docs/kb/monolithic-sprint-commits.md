# Process: Monolithic Sprint Commits

**Source:** Sprint 2 audit  
**Category:** Process

## The Problem

Sprint 2 landed as a single commit: 2,364 lines across 7 subsystems (BrottBrain, 6 UI screens, economy, progression, game flow, opponent data, overclock fixes). One PR, one review, one approval.

## Why It Matters

- **Review quality degrades with size.** Studies consistently show review effectiveness drops sharply above ~400 lines. Boltz approved 2,364 lines with zero issues found — either the code was flawless (unlikely at any scale) or the review wasn't granular enough.
- **Bisection is impossible.** If a bug surfaces, `git bisect` points to one massive commit. No way to isolate which subsystem introduced it.
- **Rollback is all-or-nothing.** Can't revert economy without also reverting BrottBrain.

## Recommendation

For future sprints with multiple subsystems, split into focused PRs:
1. `[S3-001] feat: subsystem-A` — reviewed and merged
2. `[S3-002] feat: subsystem-B` — reviewed and merged
3. etc.

Each PR should be reviewable in isolation (<500 lines ideal, <1000 acceptable).

## Tradeoff

More PRs = more pipeline overhead (each needs review + verification). For a 2-agent pipeline (Nutts builds, Boltz reviews), this means more review cycles. Acceptable if it improves review quality.

## Acceptance Criteria

If the team decides monolithic commits are acceptable for this project's scale, document that decision explicitly and accept the review-quality tradeoff.
