#!/usr/bin/env bash
# Apply a branch-protection snapshot from .github/branch-protection/<branch>.json
# to the GitHub API. Runs on demand; never from CI.
#
# Usage:
#   BROTT_PAT=... apply-branch-protection.sh [--dry-run] <branch>
#
# Requires: curl, jq. Reads PAT from $BROTT_PAT (required).
# Repo is inferred from the git origin remote.

set -euo pipefail

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
  shift
fi

BRANCH="${1:-}"
if [[ -z "${BRANCH}" ]]; then
  echo "usage: $0 [--dry-run] <branch>" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG="${REPO_ROOT}/.github/branch-protection/${BRANCH}.json"

if [[ ! -f "${CONFIG}" ]]; then
  echo "error: no config at ${CONFIG}" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq required" >&2
  exit 2
fi

# Validate JSON shape minimally.
if ! jq -e '.required_status_checks.contexts and (.enforce_admins == true or .enforce_admins == false)' \
     "${CONFIG}" >/dev/null; then
  echo "error: ${CONFIG} missing required fields" >&2
  exit 2
fi

# Infer owner/repo from git origin.
ORIGIN="$(git -C "${REPO_ROOT}" config --get remote.origin.url)"
# Strip any embedded credentials (https://x-access-token:...@github.com/owner/repo.git)
CLEAN_ORIGIN="${ORIGIN##*@}"
# Handle git@github.com:owner/repo.git
CLEAN_ORIGIN="${CLEAN_ORIGIN#github.com/}"
CLEAN_ORIGIN="${CLEAN_ORIGIN#github.com:}"
CLEAN_ORIGIN="${CLEAN_ORIGIN#https://github.com/}"
CLEAN_ORIGIN="${CLEAN_ORIGIN%.git}"
OWNER="${CLEAN_ORIGIN%%/*}"
REPO="${CLEAN_ORIGIN##*/}"

if [[ -z "${OWNER}" || -z "${REPO}" || "${OWNER}" == "${REPO}" ]]; then
  echo "error: could not infer owner/repo from origin: ${ORIGIN}" >&2
  exit 2
fi

URL="https://api.github.com/repos/${OWNER}/${REPO}/branches/${BRANCH}/protection"
BODY="$(cat "${CONFIG}")"

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "DRY RUN"
  echo "PUT ${URL}"
  echo "Body:"
  echo "${BODY}" | jq .
  exit 0
fi

if [[ -z "${BROTT_PAT:-}" ]]; then
  echo "error: BROTT_PAT not set" >&2
  exit 2
fi

TMP="$(mktemp)"
trap 'rm -f "${TMP}"' EXIT

HTTP_CODE="$(curl -sS -o "${TMP}" -w '%{http_code}' \
  -X PUT "${URL}" \
  -H "Authorization: Bearer ${BROTT_PAT}" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  -d "${BODY}")"

if [[ "${HTTP_CODE}" -ge 200 && "${HTTP_CODE}" -lt 300 ]]; then
  echo "OK ${HTTP_CODE}"
  jq -c '{enforce_admins: .enforce_admins.enabled, contexts: .required_status_checks.contexts}' "${TMP}"
  exit 0
else
  echo "FAIL ${HTTP_CODE}" >&2
  cat "${TMP}" >&2
  exit 1
fi
