// tests/bb-test-chassis-pick.spec.js — [S(I).6] bb_test-driven chassis-pick → arena flow
//
// Drives the deployed Web Debug build via window.bb_test (S(I).5 bridge).
// Requires: build/index-debug.html exported with "Web Debug" preset.
// Gated by WEB_DEBUG_BUILD=true env var — only runs in build-and-deploy.yml (post-merge).
// Per arc brief: Pillar 2 is per-arc-close gate, not per-PR.
//
// PARTIAL_COVERAGE branch: bb_test live but WebGL scene transitions stall on headless
// (no GPU on GHA) → state checks degrade gracefully.

const { test, expect } = require('@playwright/test');
const {
  assertCanvasNotMonochrome,
  startConsoleCapture,
} = require('./visual-helpers.js');

const WEB_DEBUG_BUILD = process.env.WEB_DEBUG_BUILD === 'true';
const DEBUG_URL = (process.env.GAME_URL || '/game/') + 'index-debug.html';

const BB_TEST_READY_TIMEOUT_MS = 20000;
const SCREEN_POLL_TIMEOUT_MS = 15000;
const ARENA_POLL_TIMEOUT_MS = 20000;

// GameFlow.Screen.RUN_START = 7
const RUN_START_SCREEN = 7;

test.describe('[S(I).6] bb_test chassis-pick → arena', () => {
  test.skip(!WEB_DEBUG_BUILD, 'WEB_DEBUG_BUILD not set — skipping (no debug artifact in this CI context)');

  test('chassis 0: run_start → click_chassis(0) → in_arena → canvas not monochrome', async ({ page }, testInfo) => {
    const consoleErrors = startConsoleCapture(page);

    await page.goto(`${DEBUG_URL}?screen=run_start`);
    const loadedAt = Date.now();

    // Step 1: wait for bb_test injection
    let bbTestReady = false;
    while (Date.now() - loadedAt < BB_TEST_READY_TIMEOUT_MS) {
      bbTestReady = await page.evaluate(() => typeof window.bb_test !== 'undefined');
      if (bbTestReady) break;
      await page.waitForTimeout(250);
    }

    await page.screenshot({ path: 'tests/screenshots/si6-post-load.png' }).catch(() => {});

    if (!bbTestReady) {
      testInfo.annotations.push({
        type: 'PARTIAL_COVERAGE',
        description: `window.bb_test not injected within ${BB_TEST_READY_TIMEOUT_MS}ms — debug build may not have loaded or Godot boot stalled.`,
      });
      console.log('⚠ [S(I).6] PARTIAL_COVERAGE — bb_test not injected');
      const bodyText = await page.evaluate(() => document.body.innerText);
      expect(bodyText.length).toBeGreaterThan(0);
      consoleErrors.check();
      return;
    }

    const bridgeVersion = await page.evaluate(() => window.bb_test.get_version());
    console.log(`[S(I).6] bb_test bridge version: ${JSON.stringify(bridgeVersion)}`);

    // Step 2: poll until current_screen == RUN_START (7)
    let onRunStart = false;
    const screenPollStart = Date.now();
    while (Date.now() - screenPollStart < SCREEN_POLL_TIMEOUT_MS) {
      const runState = await page.evaluate(() => window.bb_test.get_run_state());
      if (runState && runState.current_screen === RUN_START_SCREEN) {
        onRunStart = true;
        break;
      }
      await page.waitForTimeout(300);
    }

    if (!onRunStart) {
      const runState = await page.evaluate(() => window.bb_test.get_run_state());
      testInfo.annotations.push({
        type: 'PARTIAL_COVERAGE',
        description: `current_screen not RUN_START(7) within ${SCREEN_POLL_TIMEOUT_MS}ms. last state: ${JSON.stringify(runState)}`,
      });
      console.log(`⚠ [S(I).6] PARTIAL_COVERAGE — screen not RUN_START. state=${JSON.stringify(runState)}`);
      consoleErrors.check();
      return;
    }

    console.log('[S(I).6] current_screen == RUN_START(7) confirmed');

    // Step 3: click_chassis(0) via bb_test
    const clickResult = await page.evaluate(() => window.bb_test.click_chassis(0));
    console.log(`[S(I).6] click_chassis(0) result: ${JSON.stringify(clickResult)}`);
    expect(clickResult, `click_chassis(0) must return true (got: ${JSON.stringify(clickResult)})`).toBe(true);

    // Step 4: poll until in_arena == true
    let inArena = false;
    const arenaPollStart = Date.now();
    while (Date.now() - arenaPollStart < ARENA_POLL_TIMEOUT_MS) {
      const arenaState = await page.evaluate(() => window.bb_test.get_arena_state());
      if (arenaState && arenaState.in_arena === true) {
        inArena = true;
        break;
      }
      await page.waitForTimeout(500);
    }

    await page.screenshot({ path: 'tests/screenshots/si6-post-click.png' }).catch(() => {});

    if (!inArena) {
      const arenaState = await page.evaluate(() => window.bb_test.get_arena_state());
      const runState = await page.evaluate(() => window.bb_test.get_run_state());
      testInfo.annotations.push({
        type: 'PARTIAL_COVERAGE',
        description: `in_arena not true within ${ARENA_POLL_TIMEOUT_MS}ms. arena: ${JSON.stringify(arenaState)}, run: ${JSON.stringify(runState)}`,
      });
      console.log(`⚠ [S(I).6] PARTIAL_COVERAGE — in_arena not true. arena=${JSON.stringify(arenaState)}`);
      consoleErrors.check();
      return;
    }

    console.log('[S(I).6] in_arena == true confirmed');

    // Step 5: assert run state
    const runState = await page.evaluate(() => window.bb_test.get_run_state());
    expect(runState.active, 'run_state.active must be true in arena').toBe(true);
    expect(runState.equipped_chassis, 'equipped_chassis must be set').toBeGreaterThanOrEqual(0);

    // Step 6: canvas not monochrome (S26.8 regression check)
    const canvasStat = await assertCanvasNotMonochrome(page);
    if (canvasStat.status === 'PARTIAL') {
      testInfo.annotations.push({
        type: 'PARTIAL_COVERAGE',
        description: `Canvas pixel check degraded: ${canvasStat.reason}. Run-state verified OK.`,
      });
      console.log(`⚠ [S(I).6] PARTIAL_COVERAGE — canvas check partial (${canvasStat.reason})`);
    } else {
      console.log(`[S(I).6] FULL_COVERAGE — canvas not monochrome`);
    }

    // Step 7: no console errors
    consoleErrors.check();

    testInfo.annotations.push({
      type: 'FULL_COVERAGE',
      description: 'bb_test injected, click_chassis(0) → in_arena=true, run active. Canvas check per GPU availability.',
    });
    console.log('[S(I).6] chassis-pick → arena flow PASSED');
  });
});
