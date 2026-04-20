# Warnings-as-errors policy consistency (S16.3-002)

**Status:** Confirmed aligned as of S16.3 (arc-close of S16).
**Owner:** Nutts (build agent), per sprint-16.3 §S16.3-002.

## What was checked

Read-only comparison of the GDScript warnings-as-errors policy between:

- **Local Godot 4.4.1 headless** — reads `godot/project.godot` directly.
- **CI Godot 4.4.1 headless** — runs `godot --headless --path godot/ --script res://tests/test_runner.gd` in `.github/workflows/verify.yml`, which loads the same `godot/project.godot`.

## Settings observed

`godot/project.godot` contains **no** `debug/gdscript/warnings/*` entries and no `warnings_as_errors` override. The file is 23 lines, covering only `[application]`, `[display]`, and `[rendering]` sections. GDScript warning behavior therefore falls through to the Godot 4.4.1 engine defaults in both environments.

## Verdict

**Aligned by construction.** Local and CI load the same `project.godot`, and that file asserts no warnings policy — both resolve to identical engine-default behavior. No divergence is possible without editing `project.godot`, which is out of scope for S16.3.

Spot-check of the most recent green Verify run on a code-path PR (S16.2-005, run `24675088337`, job `Godot Unit Tests`) confirms:

- `PASS: arena_renderer.gd can be loaded` — the S16.1-006 fix has not re-surfaced.
- No GDScript compile-time warnings promoted to errors in the test output.
- Only runtime-shutdown artifacts (ObjectDB / RID leak messages on `--quit`) and test-asserted `SCRIPT ERROR` lines, both of which are orthogonal to `warnings_as_errors`.

## Scope note

This doc is a paper-trail artifact per Ett's tightening of the S16.3 arc-close requirements. No behavior change; no edits to `project.godot` or any `.gd` file.
