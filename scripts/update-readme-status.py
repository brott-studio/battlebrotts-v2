#!/usr/bin/env python3
"""Regenerate the 📊 Status block in README.md from live GitHub data.

Pure stdlib. Idempotent. Graceful on missing auth / API errors.

Run locally:
    python3 scripts/update-readme-status.py

In CI:
    GITHUB_TOKEN=...            # same-repo reads (auto-provided)
    BROTT_STUDIO_PAT=...        # cross-repo read of brott-studio/studio-audits
"""
from __future__ import annotations

import json
import os
import re
import sys
import urllib.parse
import urllib.request
import urllib.error
from datetime import datetime, timezone
from pathlib import Path

REPO = "brott-studio/battlebrotts-v2"
AUDITS_REPO = "brott-studio/studio-audits"
AUDITS_SUBDIR = "audits/battlebrotts-v2"
DEFAULT_BRANCH = "main"
VERIFY_WORKFLOW_FILE = "verify.yml"

START = "<!-- STATUS-START -->"
END = "<!-- STATUS-END -->"

AREA_LABELS = [
    ("area:audio", "🎵 Audio"),
    ("area:art", "🎨 Art"),
    ("area:ux", "✨ UX"),
    ("area:gameplay", "🎮 Gameplay"),
    ("area:tech-debt", "🔧 Tech-Debt"),
    ("area:framework", "🏗️ Framework"),
]
PRIO_LABELS = [
    ("prio:high", "🔴 High"),
    ("prio:mid", "🟡 Mid"),
    ("prio:low", "🔵 Low"),
]

ROOT = Path(__file__).resolve().parent.parent
README = ROOT / "README.md"


def _token_for(repo: str) -> str | None:
    """Pick the best token available for a given repo.

    - Same repo: prefer GITHUB_TOKEN (CI default), else BROTT_STUDIO_PAT.
    - Cross repo: require BROTT_STUDIO_PAT.
    """
    if repo == REPO:
        return os.environ.get("GITHUB_TOKEN") or os.environ.get("BROTT_STUDIO_PAT")
    return os.environ.get("BROTT_STUDIO_PAT")


def gh(path: str, *, repo: str = REPO, params: dict | None = None, accept: str = "application/vnd.github+json"):
    """Minimal GitHub REST v3 GET. Returns parsed JSON or None on soft failure."""
    url = f"https://api.github.com{path}"
    if params:
        url += "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url)
    req.add_header("Accept", accept)
    req.add_header("User-Agent", "bb2-readme-status/1.0")
    tok = _token_for(repo)
    if tok:
        req.add_header("Authorization", f"Bearer {tok}")
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        sys.stderr.write(f"[warn] HTTP {e.code} for {url}\n")
        return None
    except (urllib.error.URLError, TimeoutError, OSError) as e:
        sys.stderr.write(f"[warn] {e} for {url}\n")
        return None


# ---------------------------------------------------------------------------
# Data collection
# ---------------------------------------------------------------------------

def fetch_ci_status() -> str:
    """Return 'success', 'failure', or '' for most recent workflow run on default branch."""
    data = gh(
        f"/repos/{REPO}/actions/runs",
        params={"branch": DEFAULT_BRANCH, "per_page": 1, "event": "push"},
    )
    if not data or not data.get("workflow_runs"):
        return ""
    run = data["workflow_runs"][0]
    return run.get("conclusion") or run.get("status") or ""


def fetch_open_prs() -> list[dict]:
    data = gh(f"/repos/{REPO}/pulls", params={"state": "open", "per_page": 5, "sort": "created", "direction": "desc"})
    return data or []


def _search_issue_count(q: str) -> int:
    data = gh("/search/issues", params={"q": q, "per_page": 1})
    if not data:
        return 0
    return int(data.get("total_count", 0))


def _list_issue_count(labels: list[str]) -> int:
    # Use /repos/{owner}/{repo}/issues with comma-joined labels — handles
    # labels containing ':' (e.g. area:audio) which the search API requires
    # to be quoted. Cap at 100; backlog is not expected to exceed that soon.
    data = gh(f"/repos/{REPO}/issues", params={
        "state": "open",
        "labels": ",".join(labels),
        "per_page": 100,
    })
    if not isinstance(data, list):
        return 0
    # Filter out PRs (the issues endpoint returns PRs too, they have 'pull_request' key).
    return sum(1 for i in data if "pull_request" not in i)


def fetch_backlog_counts() -> dict:
    out: dict = {
        "total": _list_issue_count(["backlog"]),
        "areas": {},
        "prios": {},
    }
    for key, _label in AREA_LABELS:
        out["areas"][key] = _list_issue_count(["backlog", key])
    for key, _label in PRIO_LABELS:
        out["prios"][key] = _list_issue_count(["backlog", key])
    return out


_SPRINT_NAME_RE = re.compile(r"sprint[-_]?(\d+)(?:[._-](\d+))?", re.IGNORECASE)


def _sprint_sort_key(name: str) -> tuple[int, int]:
    m = _SPRINT_NAME_RE.search(name)
    if not m:
        return (-1, -1)
    major = int(m.group(1))
    minor = int(m.group(2)) if m.group(2) else 0
    return (major, minor)


def find_current_sprint() -> tuple[str, str] | None:
    """Return (title, relative_path) of the highest-versioned sprint doc, or None."""
    candidates: list[Path] = []
    for d in (ROOT / "docs" / "design", ROOT / "sprints"):
        if d.is_dir():
            candidates.extend(p for p in d.glob("sprint*.md") if p.is_file())
    if not candidates:
        return None
    candidates.sort(key=lambda p: _sprint_sort_key(p.name), reverse=True)
    best = candidates[0]
    title = ""
    try:
        for line in best.read_text(encoding="utf-8").splitlines():
            s = line.strip()
            if s.startswith("# "):
                title = s[2:].strip()
                break
    except OSError:
        pass
    if not title:
        title = best.stem
    rel = best.relative_to(ROOT).as_posix()
    return title, rel


_GRADE_RE = re.compile(r"\b(?:grade|final grade|overall)\s*[:\-–]\s*([A-F][+\-−–]?)", re.IGNORECASE)
_GRADE_FM_RE = re.compile(r"^grade\s*:\s*([A-F][+\-−–]?)\s*$", re.IGNORECASE | re.MULTILINE)


def _parse_grade(text: str) -> str:
    m = _GRADE_FM_RE.search(text) or _GRADE_RE.search(text)
    if not m:
        return "?"
    g = m.group(1).replace("-", "−")  # prettier unicode minus
    return g


def fetch_recent_audits() -> list[dict] | None:
    """Return list of {sprint,label,grade,url} for up to 3 most recent audits.

    Returns None if auth unavailable or repo unreachable -> caller renders graceful message.
    """
    if not _token_for(AUDITS_REPO):
        return None
    listing = gh(f"/repos/{AUDITS_REPO}/contents/{AUDITS_SUBDIR}", repo=AUDITS_REPO)
    if listing is None:
        return None
    if not isinstance(listing, list):
        return []
    files = [f for f in listing if f.get("type") == "file" and re.match(r"(?:v2-)?sprint.*\.md$", f.get("name", ""), re.I)]
    files.sort(key=lambda f: _sprint_sort_key(f["name"]), reverse=True)
    top = files[:3]
    out = []
    for f in top:
        name = f["name"]
        m = _SPRINT_NAME_RE.search(name)
        if m:
            major = m.group(1)
            minor = m.group(2)
            label = f"S{major}.{minor}" if minor else f"S{major}"
        else:
            label = name
        # Fetch raw content for grade parsing
        grade = "?"
        dl = f.get("download_url")
        if dl:
            try:
                req = urllib.request.Request(dl, headers={"User-Agent": "bb2-readme-status/1.0"})
                tok = _token_for(AUDITS_REPO)
                if tok:
                    req.add_header("Authorization", f"Bearer {tok}")
                with urllib.request.urlopen(req, timeout=20) as resp:
                    body = resp.read().decode("utf-8", errors="replace")
                grade = _parse_grade(body[:4000])
            except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError, OSError):
                pass
        out.append({"label": label, "grade": grade, "url": f.get("html_url", "")})
    return out


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

def render_block() -> str:
    lines: list[str] = [START, "## 📊 Status", ""]

    # Badges (shields.io — always renders, even offline)
    badges = [
        f'<img alt="ci" src="https://img.shields.io/github/actions/workflow/status/{REPO}/{VERIFY_WORKFLOW_FILE}?branch={DEFAULT_BRANCH}&label=CI">',
        f'<img alt="prs" src="https://img.shields.io/github/issues-pr/{REPO}?label=open%20PRs">',
        f'<img alt="backlog" src="https://img.shields.io/github/issues-search/{REPO}?query=label%3Abacklog+is%3Aopen&label=backlog">',
    ]
    lines.append(" ".join(badges))
    lines.append("")

    # Current sprint
    sprint = find_current_sprint()
    if sprint:
        title, rel = sprint
        lines.append(f"**Current sprint:** [{title}](./{rel})")
    else:
        lines.append("**Current sprint:** _(no sprint docs found)_")
    lines.append("")

    # Backlog
    bl = fetch_backlog_counts()
    view_all = f"https://github.com/{REPO}/issues?q=is%3Aissue+label%3Abacklog+is%3Aopen"
    lines.append(f"**Backlog** ({bl['total']} total · [view all]({view_all}))")
    area_bits = [f"{label} {bl['areas'].get(k, 0)}" for k, label in AREA_LABELS]
    prio_bits = [f"{label} {bl['prios'].get(k, 0)}" for k, label in PRIO_LABELS]
    lines.append("- " + " · ".join(area_bits))
    lines.append("- " + " · ".join(prio_bits))
    lines.append("")

    # Open PRs (compact list)
    prs = fetch_open_prs()
    if prs:
        lines.append(f"**Open PRs** ({len(prs)})")
        for pr in prs[:5]:
            num = pr.get("number")
            title = (pr.get("title") or "").strip()
            url = pr.get("html_url") or f"https://github.com/{REPO}/pull/{num}"
            lines.append(f"- [#{num}]({url}) {title}")
        lines.append("")

    # Audits
    audits = fetch_recent_audits()
    lines.append(f"**Recent audits** (from [studio-audits](https://github.com/{AUDITS_REPO}))")
    if audits is None:
        lines.append("- _Audits unavailable (configure `BROTT_STUDIO_PAT` secret)_")
    elif not audits:
        lines.append("- _No audits yet_")
    else:
        for a in audits:
            lines.append(f"- {a['label']} — {a['grade']} · [audit]({a['url']})")
    lines.append("")

    # Docs row
    doc_links = []
    if (ROOT / "docs" / "gdd.md").exists():
        doc_links.append("[GDD](./docs/gdd.md)")
    if (ROOT / "docs" / "kb" / "audio-vision.md").exists():
        doc_links.append("[Audio Vision](./docs/kb/audio-vision.md)")
    if (ROOT / "docs" / "kb" / "ux-vision.md").exists():
        doc_links.append("[UX Vision](./docs/kb/ux-vision.md)")
    if (ROOT / "docs" / "kb" / "pipeline.md").exists():
        doc_links.append("[Pipeline](./docs/kb/pipeline.md)")
    else:
        doc_links.append("[Pipeline](https://github.com/blor-inc/studio-framework/blob/main/PIPELINE.md)")
    if doc_links:
        lines.append("**Docs:** " + " · ".join(doc_links))
        lines.append("")

    # Footer
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    lines.append(f"_Last updated: {now} · [update log](../../actions/workflows/readme-status.yml)_")
    lines.append(END)
    return "\n".join(lines) + "\n"


# ---------------------------------------------------------------------------
# README splice
# ---------------------------------------------------------------------------

_TS_RE = re.compile(r"_Last updated: \d{4}-\d{2}-\d{2} \d{2}:\d{2} UTC")


def _strip_timestamp(block: str) -> str:
    return _TS_RE.sub("_Last updated: <TS>", block)


def splice(readme_text: str, block: str) -> str:
    if START in readme_text and END in readme_text:
        pre, rest = readme_text.split(START, 1)
        _old, post = rest.split(END, 1)
        # Ensure exactly one blank line around the block for readability.
        pre = pre.rstrip() + "\n\n"
        post = post.lstrip("\n")
        if post and not post.startswith("\n"):
            post = "\n" + post
        return pre + block.rstrip() + "\n" + post
    # Insert after h1 + intro paragraph
    lines = readme_text.splitlines(keepends=True)
    insert_at = 0
    seen_h1 = False
    for i, ln in enumerate(lines):
        if not seen_h1 and ln.startswith("# "):
            seen_h1 = True
            insert_at = i + 1
            continue
        if seen_h1:
            # Skip blockquote/intro lines until we hit a section header or double blank.
            if ln.startswith("## "):
                insert_at = i
                break
            insert_at = i + 1
    before = "".join(lines[:insert_at])
    after = "".join(lines[insert_at:])
    if before and not before.endswith("\n"):
        before += "\n"
    if before and not before.endswith("\n\n"):
        before += "\n"
    if after and not after.startswith("\n"):
        after = "\n" + after
    return before + block.rstrip() + "\n" + after


def main() -> int:
    readme_text = README.read_text(encoding="utf-8") if README.exists() else "# BattleBrotts v2\n"
    block = render_block()
    candidate = splice(readme_text, block)

    # Idempotence: if nothing but the timestamp would change, keep the old
    # timestamp so back-to-back runs produce zero diff.
    if _strip_timestamp(candidate) == _strip_timestamp(readme_text) and readme_text:
        # Preserve previous timestamp (or carry over if block just didn't exist yet).
        old_ts = _TS_RE.search(readme_text)
        new_ts = _TS_RE.search(candidate)
        if old_ts and new_ts:
            candidate = candidate[:new_ts.start()] + old_ts.group(0) + candidate[new_ts.end():]

    if candidate == readme_text:
        print("README status block unchanged.")
        return 0
    README.write_text(candidate, encoding="utf-8")
    print(f"README.md updated ({len(candidate)} bytes).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
