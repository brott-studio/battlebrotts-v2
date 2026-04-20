# Per-Agent GitHub Apps (issue-per-agent pattern)

> **First instance:** Specc (App ID `3444613`, installation `125608421`) — landed in S16.2.
> **Status:** Production pattern. Template for Boltz, Nutts, and any future agent that needs a distinct GitHub identity.

## Rationale

### The PAT 422 problem (S15 background)

Prior to S16.2, every pipeline agent — Patch, Nutts, Boltz, Specc — authenticated to GitHub using a single shared Personal Access Token (the classic `brott-studio-token` PAT). This worked for most operations but broke auditability and hit one hard failure:

- **Same-actor review blocked at platform level.** When Nutts authored a PR under the PAT and Specc then tried to approve that PR under *the same PAT*, GitHub returned **422 Unprocessable Entity** ("Can not approve your own pull request"). Because the PAT is one identity, GitHub correctly saw both as the same actor and refused.
- **Audit trail was useless.** Every commit, PR open, review, and merge showed as `brotatotes` (PAT owner). "Who did what" was unreconstructable from the GitHub UI — Specc's docs commits and Nutts's code commits were indistinguishable.

Documented originally in `docs/kb/shared-token-self-review-422.md` (S15).

### Why per-agent GitHub Apps solve it

Each pipeline agent gets its own GitHub App, installed on the brott-studio org. Each App is a distinct GitHub actor (`<agent-name>[bot]`), so:

- Cross-actor approvals work: Nutts-authored PRs can be approved by Specc because they're different identities.
- The audit trail is real: PR reviews list `brott-studio-specc[bot]`; code commits list `brott-studio-nutts[bot]`; etc.
- Token scope is per-agent: compromising one App doesn't blast-radius the rest of the pipeline.
- Rotation is per-agent: rotate Specc's key without touching Nutts or Boltz.

## ⚠️ Important finding — GitHub blocks self-approval universally

**This is the S16.2-003 learning; future agents should not chase this as a bug.**

GitHub's PR-review API blocks **same-actor approval for any identity**: PAT, GitHub App, or human user. If the same actor that authored a commit / opened a PR tries to approve that PR, the review API returns **422** at the platform level.

Specifically:

- Author-a-commit-as-Specc-App + approve-as-Specc-App → **422** (contrived case; was the original S16.2-003 acceptance wording; **spec-wrong**).
- Open-PR-as-Specc-App + approve-as-Specc-App → **422**.
- Author-as-anyone + approve-as-same-identity → **422**.

This is **not** a token fallback bug, **not** a helper misconfiguration, and **not** an App-permissions issue. It is intentional platform behavior.

**What per-agent Apps actually solve:** the cross-actor case — `Nutts-authors → Specc-approves-with-App` — which is the real pipeline requirement. S16.2-003 (redo) validated this end-to-end: approve returned **HTTP 200** with reviewer `brott-studio-specc[bot]` on a Patch-authored PR.

If you see a 422 during a Specc approve:
1. Confirm the PR author is a *different* actor than Specc.
2. If same actor — expected; refactor the flow so a different agent authors.
3. If different actor — investigate; that would be a real regression.

## Setup steps (HCD-facing playbook)

These steps are what HCD performs once per new agent to provision its App. The agent itself never sees the `.pem`.

### 1. Create the App

1. GitHub → Settings → Developer settings → GitHub Apps → **New GitHub App**.
2. **Name:** `brott-studio-<agent>` (e.g., `brott-studio-specc`, `brott-studio-nutts`).
3. **Homepage URL:** `https://github.com/brott-studio`.
4. **Webhook:** disabled (uncheck "Active").
5. **Permissions (repository):**
   - Contents: Read & write
   - Pull requests: Read & write
   - Metadata: Read-only (mandatory)
   - (Add more only if the agent needs them — Issues, Checks, etc. Follow least-privilege.)
6. **Where can this App be installed?** Only on this account.
7. Create App. Record **App ID** (numeric, shown on App settings page).

### 2. Generate & install private key

1. On the App settings page → **Private keys** → Generate a private key. Download the `.pem`.
2. Move the `.pem` to HCD's machine at `~/.config/gh/brott-studio-<agent>-app.pem`, mode `0600`.
3. **Install the App** on the brott-studio org → select target repos (`battlebrotts-v2`, and any others the agent needs). Record the **Installation ID** (visible in the install URL: `.../installations/<id>`).

### 3. Deploy the token helper

Per-agent token helpers live at `~/bin/<agent>-gh-token` and follow the same contract as `~/bin/specc-gh-token`:

- Read `.pem` from `$<AGENT>_APP_PEM_PATH` (default `~/.config/gh/brott-studio-<agent>-app.pem`).
- Mint RS256 JWT (9-min TTL).
- Exchange for an installation token via `/app/installations/<id>/access_tokens`.
- Cache token in `/tmp/<agent>-gh-token.cache` (mode 0600, 50-min TTL).
- Print installation token to stdout. Exit 0 on success, 2/3/4 on config/API/internal error.

**Template:** copy `~/bin/specc-gh-token` and s/specc/<agent>/g; update `DEFAULT_PEM_PATH` and env-var names.

### 4. Wire into the agent profile

Each agent profile (in the OpenClaw agent config) gets:

```bash
# Before any git / gh / curl call that should run as the agent:
export <AGENT>_APP_ID=<app_id>
export <AGENT>_INSTALLATION_ID=<installation_id>
TOKEN=$(~/bin/<agent>-gh-token)
# Use $TOKEN for git push (as x-access-token:$TOKEN) and API calls
# (Authorization: token $TOKEN).
```

**Fallback rule:** if `TOKEN` is empty or the helper exits non-zero, the agent **must stop and report** — do not silently fall back to the shared PAT. Silent PAT fallback defeats the entire audit-trail purpose.

**Git config:** for commits authored by the App, set:

```bash
git config user.name "brott-studio-<agent>[bot]"
git config user.email "<app_user_id>+brott-studio-<agent>[bot]@users.noreply.github.com"
```

(The `<app_user_id>` is the numeric user ID shown by `GET /users/brott-studio-<agent>[bot]`.)

## Token helper reference (`~/bin/specc-gh-token`)

- **Required env:** `SPECC_APP_ID`, `SPECC_INSTALLATION_ID`.
- **Optional env:** `SPECC_APP_PEM_PATH` (default `~/.config/gh/brott-studio-specc-app.pem`).
- **Cache:** `/tmp/specc-gh-token.cache`, mode 0600, 50-min TTL. Cache key includes App ID + installation ID + `.pem` mtime, so key rotation / App swap invalidates automatically.
- **JWT:** 9-min TTL (GitHub maximum is 10 min; 1-min skew margin).
- **Installation token:** 60-min TTL upstream from GitHub; cached 50 min.
- **Exit codes:**
  - `0` — success (token printed to stdout).
  - `2` — config/file error (missing env, unreadable `.pem`, unwritable cache).
  - `3` — GitHub API error (non-200 from `/access_tokens`).
  - `4` — unexpected internal error.
- **Failure modes:**
  - `.pem` mode not `0600` → refused.
  - `SPECC_APP_ID` or `SPECC_INSTALLATION_ID` missing → exit 2.
  - Clock skew > 1 min → JWT may be rejected; check system time (`timedatectl`).
  - Rate limit on `/access_tokens` → exit 3; back off ~60 s.

## Rotation procedure

**When to rotate:**
- Suspected key compromise.
- Scheduled rotation (every 90 days recommended).
- Agent decommissioning (delete App entirely, don't just rotate).

**Steps:**
1. GitHub App settings → Private keys → Generate a new private key.
2. Download new `.pem`, `chmod 0600`, replace `~/.config/gh/brott-studio-<agent>-app.pem`.
3. Clear cache: `rm -f /tmp/<agent>-gh-token.cache` (the mtime-keyed cache would do this automatically, but explicit is safer).
4. Test: `<AGENT>_APP_ID=... <AGENT>_INSTALLATION_ID=... ~/bin/<agent>-gh-token` — should print a 40-char token.
5. On GitHub: delete the old private key.

No agent-profile changes needed; env vars and helper path stay the same.

## Caveat — auto-merge can shadow the App merge step

Observed in S16.2-003 redo: after Specc-App approved and CI went green, the repo's `auto-merge` workflow (running as `github-actions[bot]`) merged the PR before Specc's explicit merge call could run. The Specc App approval is still what unblocked the merge — but the `merged_by` audit row showed `github-actions[bot]`, not `brott-studio-specc[bot]`.

**Implications:**
- For pipelines where "merge actor = agent" matters in the audit trail, disable auto-merge on that PR or skip the approve step until merge-time.
- For normal use, this is benign: Specc's approval review is the semantically meaningful audit row; auto-merge is mechanical.

## Cross-references

- `docs/kb/shared-token-self-review-422.md` — original PAT 422 finding from S15.
- `studio-framework/SECRETS.md` — Specc App secret inventory (updated in S16.2-002).
- `~/bin/specc-gh-token` — reference helper implementation.
- S16.2-002 PR — profile wiring first instance.
- S16.2-003 redo PR #149 — cross-actor validation end-to-end test.
