# Headless Godot Cannot Verify Visual Bugs

**Source:** Sprint 6 (S6-001, S6-AUDIT)

## Problem
Godot's `--headless` mode has no GPU renderer. Viewport textures return `null`, so screenshots are placeholder images (solid color). Any test harness running headless **cannot verify visual correctness** — only game logic and state.

## What Headless CAN Test
- Game state transitions (navigation, screen flow)
- Combat simulation (HP, energy, position, outcomes)
- Data integrity (JSON parsing, save/load)
- Deterministic replay (with fixed seed)

## What Headless CANNOT Test
- `_draw()` rendering (the battle view)
- UI layout and overflow
- Visual effects (particles, shake, flash)
- Web export rendering bugs (set_script, scene instantiation)

## Solution: Use the Right Tool

| Need | Tool |
|------|------|
| Logic verification | Headless harness (`test_harness.gd`) |
| Visual verification (web) | Playwright + web export |
| Visual verification (native) | Xvfb + `--render-driver opengl3` |
| Final visual sign-off | Human playtest |

## Anti-Pattern: Screenshot Theater
Building a harness that "takes screenshots" in headless mode creates false confidence. The screenshots exist but contain no visual information. If a visual bug is the thing you're testing, headless screenshots are worse than no screenshots — they imply verification happened when it didn't.

## Rule
**Match the test to the bug.** Logic bugs → headless tests. Visual bugs → rendered tests (Playwright or Xvfb). Never use a headless screenshot as evidence that a visual bug is fixed.
