# KB Review Gate

**Mandatory step 0 at every sprint kickoff.** Before writing any code, every agent must review all active KB entries below.

## Sprint Kickoff Checklist

1. Read every entry in this file
2. Confirm you understand each pattern/fix — if unclear, re-read the full KB file
3. Proceed with sprint tasks

---

## Patterns (`kb/patterns/`)

| File | Summary |
|------|---------|
| `godot-ci-visual-verification.md` | Use Playwright + web export for CI visual verification; xvfb is unreliable for Godot |
| `playwright-local-server.md` | Use Playwright's built-in `webServer` config to auto-start a local server for tests |
| `juice-separation.md` | Keep visual feedback (juice) separate from simulation logic |
| `openclaw-hub-and-spoke.md` | OpenClaw subagents cannot spawn subagents — use hub-and-spoke pattern |
| `shrinking-arena-pacing.md` | Shrinking arena as a forcing function for combat pacing |
| `tick-rate-pacing-lever.md` | Use tick rate as a lever to control game pacing |

## Troubleshooting (`kb/troubleshooting/`)

| File | Summary |
|------|---------|
| `godot-web-export.md` | Use `gl_compatibility` renderer; never use `set_script()` in web exports; use scene instantiation |
| `gdscript-variant-inference.md` | `max()`/`min()` return Variant — use typed alternatives to avoid inference issues |
| `godot-ci-project-import.md` | Run `godot --headless --import` before CI tests to avoid first-run failures |
| `headless-visual-testing.md` | Headless Godot cannot verify visual bugs — use web export + Playwright instead |
