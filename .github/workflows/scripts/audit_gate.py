#!/usr/bin/env python3
"""
audit_gate.py — [S18.2-003] Audit Gate logic.

Enforces the sub-sprint close-out invariant by failing a planning PR when
the immediately-preceding sub-sprint's Specc audit is absent from
`brott-studio/studio-audits` on `main`.

Six anchored logic points (from sprint-18.2 plan):
  1. Parse (N, M) from added/modified `sprints/sprint-<N>.<M>.md`. If the
     path doesn't match the <N>.<M> shape → exit with neutral conclusion and
     an explanatory summary.
  2. Mint installation token via Boltz App (BOLTZ_APP_ID +
     BOLTZ_APP_PRIVATE_KEY) scoped to `studio-audits`.
  3. First-sprint-of-arc rule: if M == 1, require `arcs/arc-<N>.md` in the
     PR tree → PASS + skip audit lookup. Missing → FAIL.
  4. Prior-audit lookup (M >= 2): GET
     /repos/brott-studio/studio-audits/contents/audits/battlebrotts-v2/
     v2-sprint-<N>.<M-1>.md on ref=main. Immediately-preceding only.
     200 → PASS; 404 → FAIL.
  5. Fail-closed on API outage: 3 retries (10s → 30s → 60s). Final failure →
     FAIL with summary prefixed "API unreachable:".
  6. `current_closed_sprint` discovery = file-based lexicographic tuple-sort
     (N, M) on audits/battlebrotts-v2/v2-sprint-<N>.<M>.md — no manifest.

This script runs inside a GitHub Actions job named `audit-gate` whose
check-run title is `Audit Gate`. Exit 0 → PASS; exit 1 → FAIL; exit 0 with
GITHUB_STEP_SUMMARY containing a "neutral" marker → inconclusive pass-through
(still exits 0 so check is neutral, per logic point 1).

Workflow-level concerns (check-run title, trigger, secrets) live in
audit-gate.yml. This file is pure logic + GitHub REST client.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Optional

AUDITS_REPO = "brott-studio/studio-audits"
PROJECT = "battlebrotts-v2"
AUDIT_PATH_TEMPLATE = f"audits/{PROJECT}/v2-sprint-{{n}}.{{m}}.md"
ARC_PATH_TEMPLATE = "arcs/arc-{n}.md"

SPRINT_FILE_RE = re.compile(r"^sprints/sprint-(\d+)\.(\d+)\.md$")
SPRINT_ANY_RE = re.compile(r"^sprints/sprint-.*\.md$")
RETRY_DELAYS = (10, 30, 60)  # seconds


# ---------------------------------------------------------------------------
# Result plumbing
# ---------------------------------------------------------------------------

def write_summary(text: str) -> None:
    """Append to GITHUB_STEP_SUMMARY if present; always echo to stdout."""
    print(text)
    summary_file = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_file:
        with open(summary_file, "a", encoding="utf-8") as f:
            f.write(text + "\n")


def finish(conclusion: str, summary: str) -> None:
    """Emit a result and exit. conclusion ∈ {pass, fail, neutral}."""
    banner = {
        "pass": "## ✅ Audit Gate: PASS",
        "fail": "## ❌ Audit Gate: FAIL",
        "neutral": "## ⚪ Audit Gate: NEUTRAL (pass-through)",
    }[conclusion]
    write_summary(f"{banner}\n\n{summary}")
    if conclusion == "fail":
        sys.exit(1)
    sys.exit(0)


# ---------------------------------------------------------------------------
# Git helpers — discover which sprint file triggered the run
# ---------------------------------------------------------------------------

def run(cmd: list[str]) -> str:
    res = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if res.returncode != 0:
        raise RuntimeError(f"cmd failed ({res.returncode}): {' '.join(cmd)}\n{res.stderr}")
    return res.stdout


def changed_sprint_files() -> list[str]:
    """Files under sprints/sprint-*.md that changed between base and head."""
    base = os.environ.get("PR_BASE_SHA")
    head = os.environ.get("PR_HEAD_SHA")
    if not base or not head:
        raise RuntimeError("PR_BASE_SHA / PR_HEAD_SHA env vars not set")
    diff = run(["git", "diff", "--name-only", f"{base}...{head}"])
    files = [ln.strip() for ln in diff.splitlines() if ln.strip()]
    return [f for f in files if SPRINT_ANY_RE.match(f)]


def arc_file_in_tree(n: int) -> bool:
    """True iff arcs/arc-<N>.md exists in the PR head tree."""
    return Path(ARC_PATH_TEMPLATE.format(n=n)).is_file()


# ---------------------------------------------------------------------------
# Boltz App token mint — inline, because the workflow runs in a clean runner
# ---------------------------------------------------------------------------

def mint_installation_token() -> str:
    import jwt  # PyJWT, installed by the workflow

    app_id = os.environ["BOLTZ_APP_ID"]
    pem = os.environ["BOLTZ_APP_PRIVATE_KEY"].encode()

    now = int(time.time())
    app_jwt = jwt.encode(
        {"iat": now - 30, "exp": now + 9 * 60, "iss": app_id},
        pem,
        algorithm="RS256",
    )
    if isinstance(app_jwt, bytes):
        app_jwt = app_jwt.decode()

    # Resolve the installation for AUDITS_REPO (scoped to studio-audits).
    install = gh_api(
        "GET",
        f"/repos/{AUDITS_REPO}/installation",
        bearer=app_jwt,
        retries_on_outage=True,
    )
    install_id = install["id"]

    token_resp = gh_api(
        "POST",
        f"/app/installations/{install_id}/access_tokens",
        bearer=app_jwt,
        body={},
        retries_on_outage=True,
    )
    token = token_resp["token"]
    if not isinstance(token, str) or not token:
        raise RuntimeError(f"installation token response missing 'token': {token_resp}")
    return token


# ---------------------------------------------------------------------------
# GitHub REST client with retry/back-off (logic point 5)
# ---------------------------------------------------------------------------

class GHNotFound(Exception):
    """HTTP 404 from GitHub — treat as a deterministic 'absent' signal."""


class GHUnreachable(Exception):
    """Exhausted retries without a decisive response — fail-closed signal."""


def gh_api(
    method: str,
    path: str,
    *,
    bearer: Optional[str] = None,
    token: Optional[str] = None,
    body: Optional[dict] = None,
    retries_on_outage: bool = True,
    params: Optional[dict] = None,
) -> dict:
    """Call https://api.github.com{path} with retry on 5xx / network errors.

    - 2xx → parsed JSON (empty dict for empty body).
    - 404 → raise GHNotFound (caller decides pass/fail).
    - other 4xx → raise RuntimeError (config bug; do not retry).
    - 5xx / URLError → retry per RETRY_DELAYS; on exhaustion raise GHUnreachable.
    """
    url = f"https://api.github.com{path}"
    if params:
        # minimal query builder — callers currently only use ?ref=...
        url = f"{url}?{urllib.parse.urlencode(params)}"

    headers = {
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "battlebrotts-audit-gate/1.0",
    }
    if bearer:
        headers["Authorization"] = f"Bearer {bearer}"
    elif token:
        headers["Authorization"] = f"token {token}"

    data = None
    if body is not None:
        data = json.dumps(body).encode()
        headers["Content-Type"] = "application/json"

    attempts = [0] + list(RETRY_DELAYS) if retries_on_outage else [0]
    last_err: Optional[str] = None

    for i, delay in enumerate(attempts):
        if delay:
            print(f"[audit-gate] retry {i}/{len(attempts)-1} after {delay}s: {method} {path}")
            time.sleep(delay)
        try:
            req = urllib.request.Request(url, data=data, method=method, headers=headers)
            with urllib.request.urlopen(req, timeout=20) as resp:
                raw = resp.read().decode("utf-8", errors="replace")
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as e:
            try:
                errbody = e.read().decode("utf-8", errors="replace")[:500]
            except Exception:
                errbody = ""
            if e.code == 404:
                raise GHNotFound(f"{method} {path} → 404 {errbody}")
            if 400 <= e.code < 500:
                # Non-retryable client error (401/403/422): surface immediately.
                raise RuntimeError(
                    f"GitHub API {method} {path} → HTTP {e.code} (non-retryable): {errbody}"
                )
            last_err = f"HTTP {e.code}: {errbody}"
        except urllib.error.URLError as e:
            last_err = f"URLError: {e}"
        except (json.JSONDecodeError, TimeoutError) as e:
            last_err = f"{type(e).__name__}: {e}"

    raise GHUnreachable(f"exhausted retries ({len(attempts)} attempts): {last_err}")


# ---------------------------------------------------------------------------
# Audit lookup (logic points 4 + 6)
# ---------------------------------------------------------------------------

def check_prior_audit_exists(token: str, n: int, m: int) -> bool:
    """Immediately-preceding rule: v2-sprint-<N>.<M-1>.md must exist on main."""
    prior_m = m - 1
    # The rule is "immediately preceding" — same arc, previous sub-sprint.
    # If M == 1 we shouldn't be in this branch; guard anyway.
    if prior_m < 1:
        return True
    path = AUDIT_PATH_TEMPLATE.format(n=n, m=prior_m)
    try:
        gh_api(
            "GET",
            f"/repos/{AUDITS_REPO}/contents/{path}",
            token=token,
            params={"ref": "main"},
        )
        return True
    except GHNotFound:
        return False


# ---------------------------------------------------------------------------
# Main flow
# ---------------------------------------------------------------------------

def main() -> None:
    try:
        changed = changed_sprint_files()
    except RuntimeError as e:
        finish("fail", f"Could not compute PR diff: `{e}`.")
        return

    if not changed:
        finish(
            "neutral",
            "No `sprints/sprint-*.md` files changed in this PR. Nothing to gate.",
        )

    # Prefer a well-formed N.M file; if only malformed ones exist, emit neutral.
    well_formed = [f for f in changed if SPRINT_FILE_RE.match(f)]
    if not well_formed:
        finish(
            "neutral",
            "Changed sprint files present but none match `sprints/sprint-<N>.<M>.md`:\n"
            + "\n".join(f"- `{f}`" for f in changed)
            + "\n\nAudit Gate only gates sub-sprint planning PRs. Passing through.",
        )

    # If multiple well-formed sprint files changed in one PR, gate on the
    # lexicographically-largest (most recent) tuple — the one this PR is "about".
    tuples = sorted(
        (int(m.group(1)), int(m.group(2)), f)
        for f in well_formed
        for m in [SPRINT_FILE_RE.match(f)]
        if m
    )
    n, m, fname = tuples[-1]
    print(f"[audit-gate] gating on: {fname} → (N={n}, M={m})")

    # Logic point 3 — first-sprint-of-arc rule.
    if m == 1:
        if arc_file_in_tree(n):
            finish(
                "pass",
                f"First sprint of arc S{n} ({fname}) — `arcs/arc-{n}.md` present "
                "in PR tree. Prior-audit lookup SKIPPED per first-sprint rule.",
            )
        else:
            finish(
                "fail",
                f"**first sprint of an arc must introduce arcs/arc-{n}.md** — "
                f"`{fname}` has M=1 but `arcs/arc-{n}.md` is not in the PR tree.",
            )
        return

    # Logic point 2 — mint token. Logic point 5 — retries baked into gh_api.
    try:
        token = mint_installation_token()
    except GHUnreachable as e:
        finish("fail", f"API unreachable: could not mint Boltz installation token: `{e}`")
        return
    except Exception as e:
        finish("fail", f"Audit Gate configuration error while minting token: `{e}`")
        return

    # Logic point 4 — prior-audit lookup.
    prior_path = AUDIT_PATH_TEMPLATE.format(n=n, m=m - 1)
    try:
        exists = check_prior_audit_exists(token, n, m)
    except GHUnreachable as e:
        finish(
            "fail",
            f"API unreachable: could not reach "
            f"`{AUDITS_REPO}/contents/{prior_path}` after retries: `{e}`",
        )
        return
    except RuntimeError as e:
        finish("fail", f"Audit Gate config error during audit lookup: `{e}`")
        return

    if exists:
        finish(
            "pass",
            f"Prior-audit present: `{AUDITS_REPO}/{prior_path}` found on `main`.\n\n"
            f"Gating PR file: `{fname}` (N={n}, M={m}).",
        )
    else:
        finish(
            "fail",
            f"**audit missing: {prior_path} not on studio-audits/main**\n\n"
            f"Gating PR file: `{fname}` (N={n}, M={m}).\n"
            "The immediately-preceding sub-sprint's Specc audit must be merged to "
            f"`{AUDITS_REPO}/main` before this planning PR can close the "
            "sub-sprint close-out invariant.",
        )


if __name__ == "__main__":
    main()
