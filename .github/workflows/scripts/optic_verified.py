#!/usr/bin/env python3
"""
optic_verified.py — [S18.4-001] Optic Verified producer.

Runs from `.github/workflows/optic-verified.yml` on the `workflow_run`
completion event from the `Verify` workflow. Mints an installation token
for the **Optic App** (App ID 3459479, installation 125974902 on
`brott-studio/battlebrotts-v2`) and posts the `Optic Verified` check-run
against the PR's head SHA with a binary PASS/FAIL conclusion derived from
Verify's conclusion.

Rules per the S18.4-001 brief and optic.md:
  - Identity: Optic App token (Authorization: Bearer <installation-token>).
    NOT GITHUB_TOKEN, NOT the shared PAT.
  - Name: exactly "Optic Verified".
  - Status: "completed". Conclusion: "success" iff Verify.conclusion ==
    "success", otherwise "failure". Do not invent new criteria.
  - head_sha: github.event.workflow_run.head_sha (PR branch head).
"""

from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.request
from typing import Any, Optional

API_ROOT = "https://api.github.com"
CHECK_NAME = "Optic Verified"
# Verify → Optic mapping. Anything non-"success" becomes a failure.
# GitHub workflow_run.conclusion values: success, failure, cancelled,
# skipped, timed_out, action_required, neutral, stale, null.
SUCCESS_SET = {"success"}


def mint_installation_token() -> str:
    """Mint an Optic App installation access token for the current repo.

    Uses `OPTIC_INSTALLATION_ID` directly (no lookup) since the brief pins
    the installation to 125974902 on battlebrotts-v2.
    """
    import jwt  # PyJWT, installed by the workflow

    app_id = os.environ["OPTIC_APP_ID"]
    pem = os.environ["OPTIC_APP_PRIVATE_KEY"].encode()
    install_id = os.environ["OPTIC_INSTALLATION_ID"]

    now = int(time.time())
    app_jwt = jwt.encode(
        {"iat": now - 30, "exp": now + 9 * 60, "iss": app_id},
        pem,
        algorithm="RS256",
    )
    if isinstance(app_jwt, bytes):
        app_jwt = app_jwt.decode()

    resp = gh_api(
        "POST",
        f"/app/installations/{install_id}/access_tokens",
        bearer=app_jwt,
        body={},
    )
    token = resp.get("token")
    if not isinstance(token, str) or not token:
        raise RuntimeError(f"installation token response missing 'token': {resp}")
    return token


def gh_api(
    method: str,
    path: str,
    *,
    bearer: Optional[str] = None,
    token: Optional[str] = None,
    body: Optional[dict] = None,
) -> dict:
    url = f"{API_ROOT}{path}"
    headers = {
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "optic-verified/1.0",
    }
    if bearer:
        headers["Authorization"] = f"Bearer {bearer}"
    elif token:
        headers["Authorization"] = f"token {token}"
    data = None
    if body is not None:
        data = json.dumps(body).encode()
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        detail = ""
        try:
            detail = e.read().decode()
        except Exception:
            pass
        raise RuntimeError(f"GitHub API {method} {path} -> {e.code}: {detail}") from e


def build_check_run_body(head_sha: str, verify_conclusion: str,
                          verify_html_url: str = "") -> dict[str, Any]:
    """Construct the POST /repos/.../check-runs JSON body.

    Public for unit tests. Pure function — no I/O, no env reads beyond args.
    """
    is_success = verify_conclusion in SUCCESS_SET
    conclusion = "success" if is_success else "failure"
    if is_success:
        summary = "PASS — Verify workflow succeeded."
    else:
        summary = (
            f"FAIL — Verify workflow concluded '{verify_conclusion}'."
        )
    if verify_html_url:
        summary += f" (Verify run: {verify_html_url})"
    return {
        "name": CHECK_NAME,
        "head_sha": head_sha,
        "status": "completed",
        "conclusion": conclusion,
        "output": {
            "title": "Optic verification",
            "summary": summary,
        },
    }


def main() -> int:
    head_sha = os.environ.get("VERIFY_HEAD_SHA", "").strip()
    conclusion = os.environ.get("VERIFY_CONCLUSION", "").strip()
    html_url = os.environ.get("VERIFY_HTML_URL", "").strip()
    repo = os.environ.get("TARGET_REPO", "").strip()
    if not head_sha:
        print("ERROR: VERIFY_HEAD_SHA not set", file=sys.stderr)
        return 2
    if not conclusion:
        print("ERROR: VERIFY_CONCLUSION not set", file=sys.stderr)
        return 2
    if not repo:
        print("ERROR: TARGET_REPO not set", file=sys.stderr)
        return 2

    body = build_check_run_body(head_sha, conclusion, html_url)
    print(f"[optic-verified] posting check-run: {json.dumps(body)}")

    token = mint_installation_token()
    resp = gh_api(
        "POST",
        f"/repos/{repo}/check-runs",
        bearer=token,
        body=body,
    )
    check_id = resp.get("id")
    check_url = resp.get("html_url", "")
    print(f"[optic-verified] posted check-run id={check_id} url={check_url}")

    step_summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if step_summary:
        with open(step_summary, "a", encoding="utf-8") as f:
            f.write(
                f"## Optic Verified — {body['conclusion'].upper()}\n\n"
                f"- head_sha: `{head_sha}`\n"
                f"- Verify conclusion: `{conclusion}`\n"
                f"- Check-run: {check_url}\n"
            )
    return 0


if __name__ == "__main__":
    sys.exit(main())
