"""Unit test: main.json snapshot matches the S18.4-002 desired state.

This asserts every field so that any drift surfaces as a diff in PR review.
"""

import json
import pathlib

CONFIG = pathlib.Path(__file__).parent / "main.json"

EXPECTED = {
    "required_status_checks": {
        "strict": True,
        "contexts": [
            "Godot Unit Tests",
            "Playwright Smoke Tests",
            "Optic Verified",
            "Audit Gate",
        ],
    },
    "enforce_admins": True,
    "required_pull_request_reviews": {
        "dismiss_stale_reviews": False,
        "require_code_owner_reviews": False,
        "require_last_push_approval": False,
        "required_approving_review_count": 1,
        "bypass_pull_request_allowances": {
            "users": [],
            "teams": [],
            "apps": ["brott-studio-specc"],
        },
    },
    "restrictions": None,
    "required_linear_history": False,
    "allow_force_pushes": False,
    "allow_deletions": False,
    "required_conversation_resolution": False,
}


def test_main_config_matches_expected():
    with CONFIG.open() as fh:
        actual = json.load(fh)
    assert actual == EXPECTED, f"main.json drifted from expected S18.4-002 state"


def test_enforce_admins_true():
    with CONFIG.open() as fh:
        actual = json.load(fh)
    assert actual["enforce_admins"] is True, "enforce_admins must be True (S18.4-002)"


if __name__ == "__main__":
    test_main_config_matches_expected()
    test_enforce_admins_true()
    print("OK")
