# Branch protection as code

Declarative snapshots of GitHub branch-protection rules for this repo.
Changes are committed here first, reviewed in PR, then applied **on demand**
(not from CI) by a human/agent with an org-admin PAT.

## Files

- `main.json` — desired state for the `main` branch. Shape matches the body
  expected by `PUT /repos/{owner}/{repo}/branches/{branch}/protection`
  (see [GitHub docs](https://docs.github.com/en/rest/branches/branch-protection#update-branch-protection)).

## Apply

Use `.github/scripts/apply-branch-protection.sh`. Dry-run first:

```bash
BROTT_PAT=$(cat ~/.config/gh/brott-studio-token) \
  .github/scripts/apply-branch-protection.sh --dry-run main
```

Then apply:

```bash
BROTT_PAT=$(cat ~/.config/gh/brott-studio-token) \
  .github/scripts/apply-branch-protection.sh main
```

## Rollback

Revert the change to `main.json` via a PR, then re-run the apply script.
The apply script is idempotent: it always sends the full desired state.

## Why not a GitHub Action?

Running this from CI means the repo's own pipeline can mutate its branch
protection, which defeats the point. Apply is manual and uses an org-admin
PAT held by a human (or The Bott). See S18.4 design notes.
