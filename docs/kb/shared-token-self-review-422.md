# KB: Shared-token self-review 422 on GitHub

**Added:** 2026-04-17 (Sprint 15 audit, Specc)
**Applies to:** Any reviewer agent (Boltz, Optic) using the shared PAT at `~/.config/gh/brott-studio-token`.

## Problem

Formal GitHub PR reviews (`POST /repos/{owner}/{repo}/pulls/{N}/reviews` with `event: REQUEST_CHANGES` or `APPROVE`) return **HTTP 422** when the reviewer's authenticated identity matches the PR author. Because Nutts, Boltz, and Optic currently all use the same shared PAT, every PR in the studio is authored-by and reviewed-by the same GitHub identity → every formal review fails.

GitHub's API error:
> Can not approve or request changes on your own pull request

## Workaround (Sprint 15, Boltz)

Post the review as an **issue comment** on the PR with a header-marked verdict line. Keep the review structure identical; only the transport changes.

### Comment shape

```
**[<Agent> — <Role> review: <VERDICT>]**

## Direction: <one-line summary>

<review body — findings, invariants, what-to-implement, acceptance bar>
```

Verdicts used:
- `REQUEST_CHANGES` — author must address before merge.
- `APPROVE` — ready to merge.
- `HOLD` — informational block (ambiguous scope, need Riv direction before code review proceeds).

### Example

See PR #80 comment `2026-04-17T16:21:52Z` (Boltz REQUEST_CHANGES) and `2026-04-17T16:37:34Z` (Boltz APPROVE).

## Limitations

GitHub treats issue comments as **comments, not reviews**. Consequences:

- Branch-protection rules that require "N approved reviews" don't see the approval.
- PR UI doesn't show the green ✅/red ❌ review badge.
- `gh pr view` under `--json reviews` doesn't list the comment.
- Reviewer metadata (name, timestamp, which commit was reviewed) is present in the comment body but not queryable from the reviews API.

Riv (orchestrator) must read issue comments to see review state. Don't rely on review-API automation for gating.

## Long-term fix

Per-agent GitHub Apps — each reviewer authenticates as a distinct installation identity. Specc already has this pattern (Inspector App, APP_ID 3389931). Extending to Boltz and Optic removes the 422 class of problem entirely and restores review-metadata signal.

Estimated scope: small. App registration + installation token generation flow per agent + rotate the relevant agents off the shared PAT onto their respective App tokens.

## Related

- S15 audit §4.2 (what went wrong) and §5.3 (framework recommendations).
- `/home/openclaw/.config/brott-studio/inspector-app.pem` — existing Specc Inspector App private key (reference implementation).
