# Godot CI Visual Verification: Use Playwright + Web Export

**Source:** Sprint 8.2 (Parallel Experiment — 3 approaches tested)

## Problem
CI pipelines need to verify that Godot games render and run correctly — not just that scripts parse. Two common approaches (xvfb + autoload screenshot, xvfb + preload refactor) both fail for different reasons.

## Why Xvfb Fails for Godot Visual Verification

| Approach | Outcome | Failure Mode |
|----------|---------|-------------|
| Xvfb + autoload screenshot | Gray screenshot | Script parse errors prevent game launch; pipeline reports "success" with empty frame |
| Xvfb + preload refactor | Static screenshot | Game renders arena/HUD but `_process()` never executes — no combat, no state changes |

Xvfb provides a virtual framebuffer but does not guarantee Godot's scene tree processes frames correctly in CI. Even when rendering occurs, game logic may not execute.

## Solution: Playwright + HTML5 Web Export

Export the game to HTML5, serve it locally, and use Playwright to interact and screenshot.

### Why It Works
- Web export forces the **full rendering pipeline** (Godot → HTML5 → WebGL)
- Browser provides **GPU-accelerated rendering** via WebGL
- Playwright can **wait for game state** conditions before capturing
- **URL parameters** via `JavaScriptBridge.eval()` enable test configuration without code changes

### Pattern
```gdscript
# In-game: read test params from URL
func _ready():
    if OS.has_feature("web"):
        var params = JavaScriptBridge.eval("new URLSearchParams(window.location.search)")
        # Configure test scenario based on params
```

```javascript
// Playwright test
const { test, expect } = require('@playwright/test');

test('battle renders with live combat', async ({ page }) => {
    await page.goto('http://localhost:8080/?test_mode=true&auto_start=true');
    // Wait for game state indicating combat started
    await page.waitForTimeout(3000);
    const screenshot = await page.screenshot();
    // Assert HP changed from initial values, projectiles visible, etc.
});
```

### CI Pipeline Steps
1. `godot --check-only` — pre-flight script validation (catches parse errors early)
2. `godot --export-release "Web" build/web/` — HTML5 export
3. `npx serve -l 8080 build/web/` — local server
4. `npx playwright test` — visual verification

## Anti-Pattern: Xvfb Screenshot Theater (Updated)
Previously documented as "headless screenshots are empty." Now extended: even when xvfb produces visible screenshots, game logic may not execute. A screenshot showing an arena with full HP bars and no combat is **not verification** — it's a static frame of an uninitialized game.

## Rule
**For Godot CI visual verification, always use Playwright + web export.** Reserve xvfb for non-visual headless testing only (game logic, data integrity, state transitions).

## See Also
- `troubleshooting/headless-visual-testing.md` — original headless limitation docs
- `patterns/playwright-local-server.md` — Playwright webServer config pattern
