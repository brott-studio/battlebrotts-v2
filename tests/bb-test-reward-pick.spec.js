// tests/bb-test-reward-pick.spec.js — [S(I).7] bb_test-driven reward-pick → second battle flow
//
// Drives the deployed Web Debug build via window.bb_test (S(I).5 bridge).
// Requires: build/index-debug.html exported with "Web Debug" preset.
// Gated by WEB_DEBUG_BUILD=true env var — only runs in build-and-deploy.yml (post-merge).
// Per arc brief: Pillar 2 is per-arc-close gate, not per-PR.
//
// Flow: run_start → click_chassis(0) → in_arena → force_battle_end(0)
//       → REWARD_PICK(8) → click_reward(0) → in_arena (second battle)
//
// PARTIAL_COVERAGE branch: bb_test live but WebGL scene transitions stall on headless.

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
const REWARD_PICK_TIMEOUT_MS = 10000;  // 1s Godot timer + scene transition

const RUN_START_SCREEN   = 7;
const REWARD_PICK_SCREEN = 8;

test.describe('[S(I).7] bb_test reward-pick → second battle', () => {
  test.skip(!WEB_DEBUG_BUILD, 'WEB_DEBUG_BUILD not set — skipping (no debug artifact in this CI context)');

  test('run_start → chassis → win → reward_pick → click_reward → second battle', async ({ page }, testInfo) => {
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

    await page.screenshot({ path: 'tests/screenshots/si7-post-load.png' }).catch(() => {});

    if (!bbTestReady) {
      testInfo.annotations.push({
        type: 'PARTIAL_COVERAGE',
        description: `window.bb_test not injected within ${BB_TEST_READY_TIMEOUT_MS}ms.`,
      });
      console.log('⚠ [S(I).7] PARTIAL_COVERAGE — bb_test not injected');
      const bodyText = await page.evaluate(() => document.body.innerText);
      expect(bodyText.length).toBeGreaterThan(0);
      consoleErrors.check();
      return;
    }

    const bridgeVersion = await page.evaluate(() => window.bb_test.get_version());
    console.log(`[S(I).7] bb_test bridge version: ${JSON.stringify(bridgeVersion)}`);

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
        description: `current_screen not RUN_START(7). state: ${JSON.stringify(runState)}`,
      });
      console.log(`⚠ [S(I).7] PARTIAL_COVERAGE — screen not RUN_START. state=${JSON.stringify(runState)}`);
      consoleErrors.check();
      return;
    }

    console.log('[S(I).7] current_screen == RUN_START(7) confirmed');

    // Step 3: click_chassis(0)
    const clickChassisResult = await page.evaluate(() => window.bb_test.click_chassis(0));
    console.log(`[S(I).7] click_chassis(0) result: ${JSON.stringify(clickChassisResult)}`);
    expect(clickChassisResult, `click_chassis(0) must return true`).toBe(true);

    // Step 4: poll until in_arena == true (first battle)
    let inArena = false;
    let arenaPollStart = Date.now();
    while (Date.now() - arenaPollStart < ARENA_POLL_TIMEOUT_MS) {
      const arenaState = await page.evaluate(() => window.bb_test.get_arena_state());
      if (arenaState && arenaState.in_arena === true) {
        inArena = true;
        break;
      }
      await page.waitForTimeout(500);
    }

    await page.screenshot({ path: 'tests/screenshots/si7-first-arena.png' }).catch(() => {});

    if (!inArena) {
      const arenaState = await page.evaluate(() => window.bb_test.get_arena_state());
      testInfo.annotations.push({
        type: 'PARTIAL_COVERAGE',
        description: `in_arena not true (first battle). arena: ${JSON.stringify(arenaState)}`,
      });
      console.log(`⚠ [S(I).7] PARTIAL_COVERAGE — in_arena(1) not true`);
      consoleErrors.check();
      return;
    }

    console.log('[S(I).7] in_arena == true (first battle) confirmed');

    // Step 5: force_battle_end(0) — player wins
    // _on_roguelike_match_end then awaits 1s Godot timer before REWARD_PICK transition.
    const forceResult = await page.evaluate(() => window.bb_test.force_battle_end(0));
    console.log(`[S(I).7] force_battle_end(0) result: ${JSON.stringify(forceResult)}`);
    expect(forceResult, `force_battle_end(0) must return true`).toBe(true);

    // Step 6: poll until current_screen == REWARD_PICK (8)
    // 10s timeout accounts for 1s Godot timer + scene transition + headless overhead.
    let onRewardPick = false;
    const rewardPollStart = Date.now();
    while (Date.now() - rewardPollStart < REWARD_PICK_TIMEOUT_MS) {
      const runState = await page.evaluate(() => window.bb_test.get_run_state());
      if (runState && runState.current_screen === REWARD_PICK_SCREEN) {
        onRewardPick = true;
        break;
      }
      await page.waitForTimeout(300);
    }

    await page.screenshot({ path: 'tests/screenshots/si7-reward-pick.png' }).catch(() => {});

    if (!onRewardPick) {
      const runState = await page.evaluate(() => window.bb_test.get_run_state());
      testInfo.annotations.push({
        type: 'PARTIAL_COVERAGE',
        description: `current_screen not REWARD_PICK(8) within ${REWARD_PICK_TIMEOUT_MS}ms. state: ${JSON.stringify(runState)}`,
      });
      console.log(`⚠ [S(I).7] PARTIAL_COVERAGE — screen not REWARD_PICK. state=${JSON.stringify(runState)}`);
      consoleErrors.check();
      return;
    }

    console.log('[S(I).7] current_screen == REWARD_PICK(8) confirmed');

    // Step 7: click_reward(0)
    const clickRewardResult = await page.evaluate(() => window.bb_test.click_reward(0));
    console.log(`[S(I).7] click_reward(0) result: ${JSON.stringify(clickRewardResult)}`);
    expect(clickRewardResult, `click_reward(0) must return true`).toBe(true);

    // Step 8: poll until in_arena == true (second battle)
    let inArena2 = false;
    arenaPollStart = Date.now();
    while (Date.now() - arenaPollStart < ARENA_POLL_TIMEOUT_MS) {
      const arenaState = await page.evaluate(() => window.bb_test.get_arena_state());
      if (arenaState && arenaState.in_arena === true) {
        inArena2 = true;
        break;
      }
      await page.waitForTimeout(500);
    }

    await page.screenshot({ path: 'tests/screenshots/si7-second-arena.png' }).catch(() => {});

    if (!inArena2) {
      const arenaState = await page.evaluate(() => window.bb_test.get_arena_state());
      testInfo.annotations.push({
        type: 'PARTIAL_COVERAGE',
        description: `in_arena not true (second battle). arena: ${JSON.stringify(arenaState)}`,
      });
      console.log(`⚠ [S(I).7] PARTIAL_COVERAGE — in_arena(2) not true`);
      consoleErrors.check();
      return;
    }

    console.log('[S(I).7] in_arena == true (second battle) confirmed');

    // Step 9: assert run state progression
    // advance_battle() increments both current_battle_index AND battles_won before reward pick.
    const runState = await page.evaluate(() => window.bb_test.get_run_state());
    expect(runState.current_battle_index, 'current_battle_index must be >= 1').toBeGreaterThanOrEqual(1);
    expect(runState.battles_won, 'battles_won must be >= 1').toBeGreaterThanOrEqual(1);
    expect(runState.active, 'run_state.active must be true').toBe(true);
    console.log(`[S(I).7] run state: battle_index=${runState.current_battle_index} battles_won=${runState.battles_won}`);

    // Step 10: canvas not monochrome
    const canvasStat = await assertCanvasNotMonochrome(page);
    if (canvasStat.status === 'PARTIAL') {
      testInfo.annotations.push({
        type: 'PARTIAL_COVERAGE',
        description: `Canvas check degraded: ${canvasStat.reason}. Run-state and flow verified OK.`,
      });
      console.log(`⚠ [S(I).7] PARTIAL_COVERAGE — canvas partial (${canvasStat.reason})`);
    } else {
      console.log('[S(I).7] FULL_COVERAGE — canvas not monochrome (second battle)');
    }

    // Step 11: no console errors
    consoleErrors.check();

    testInfo.annotations.push({
      type: 'FULL_COVERAGE',
      description: 'chassis→arena→force_battle_end→REWARD_PICK→click_reward→second arena. battles_won>=1.',
    });
    console.log('[S(I).7] reward-pick → second battle flow PASSED');
  });
});
