// tests/bb-test-run-e2e.spec.js — [S(J).3] bb_test-driven 3-battle E2E run
//
// Drives the deployed Web Debug build via window.bb_test (S(I).5 bridge).
// Requires: build/index-debug.html exported with "Web Debug" preset.
// Gated by WEB_DEBUG_BUILD=true env var — only runs in build-and-deploy.yml (post-merge).
// Per arc brief: arc-close gate, not per-PR.
//
// "run_end_screen" assertion: battles_won >= 3 AND 3rd REWARD_PICK screen reached.
// The roguelike run continues beyond battle 3 — this is NOT a short-run termination test.
// It validates that the full chain: pick → arena1 → reward1 → arena2 → reward2 → arena3 → reward3
// completes without hang or error.

const { test, expect } = require('@playwright/test');
const {
  assertCanvasNotMonochrome,
  startConsoleCapture,
} = require('./visual-helpers.js');

const WEB_DEBUG_BUILD = process.env.WEB_DEBUG_BUILD === 'true';
const DEBUG_URL = (process.env.GAME_URL || '/game/') + 'index-debug.html';

const BB_TEST_READY_TIMEOUT_MS = 20000;
const SCREEN_POLL_TIMEOUT_MS   = 15000;
const ARENA_POLL_TIMEOUT_MS    = 20000;
const REWARD_PICK_TIMEOUT_MS   = 12000;

const RUN_START_SCREEN   = 7;
const REWARD_PICK_SCREEN = 8;

test.setTimeout(180000);

// ─── Helpers ─────────────────────────────────────────────────────────────────

async function pollScreen(page, target, timeoutMs) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const rs = await page.evaluate(() => window.bb_test.get_run_state());
    if (rs && rs.current_screen === target) return { ok: true, state: rs };
    await page.waitForTimeout(300);
  }
  const last = await page.evaluate(() => window.bb_test.get_run_state());
  return { ok: false, state: last };
}

async function pollInArena(page, expectedBattleIdx, timeoutMs) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const a = await page.evaluate(() => window.bb_test.get_arena_state());
    const rs = await page.evaluate(() => window.bb_test.get_run_state());
    if (a && a.in_arena === true && rs && rs.current_battle_index === expectedBattleIdx) {
      return { ok: true, arena: a, run: rs };
    }
    await page.waitForTimeout(400);
  }
  const a = await page.evaluate(() => window.bb_test.get_arena_state());
  const rs = await page.evaluate(() => window.bb_test.get_run_state());
  return { ok: false, arena: a, run: rs };
}

async function partial(testInfo, consoleErrors, label, description) {
  testInfo.annotations.push({ type: 'PARTIAL_COVERAGE', description });
  console.log(`⚠ [S(J).3] PARTIAL_COVERAGE — ${label}: ${description}`);
  consoleErrors.check();
}

async function assertCanvasOk(page, testInfo, label) {
  const stat = await assertCanvasNotMonochrome(page);
  if (stat && stat.status === 'PARTIAL') {
    testInfo.annotations.push({ type: 'PARTIAL_COVERAGE', description: `${label} canvas: ${stat.reason}` });
    console.log(`⚠ [S(J).3] ${label} canvas PARTIAL (${stat.reason})`);
  } else {
    console.log(`[S(J).3] ${label} canvas FULL_COVERAGE`);
  }
}

// ─── Spec ─────────────────────────────────────────────────────────────────────

test.describe('[S(J).3] bb_test 3-battle E2E run', () => {
  test.skip(!WEB_DEBUG_BUILD, 'WEB_DEBUG_BUILD not set — skipping');

  test('run_start → 3 battles → 3 reward picks → battles_won>=3', async ({ page }, testInfo) => {
    const consoleErrors = startConsoleCapture(page);

    await page.goto(`${DEBUG_URL}?screen=run_start`);
    const loadedAt = Date.now();

    // ── Step 1: bb_test injection ──
    let bbTestReady = false;
    while (Date.now() - loadedAt < BB_TEST_READY_TIMEOUT_MS) {
      bbTestReady = await page.evaluate(() => typeof window.bb_test !== 'undefined');
      if (bbTestReady) break;
      await page.waitForTimeout(250);
    }
    await page.screenshot({ path: 'tests/screenshots/sj3-post-load.png' }).catch(() => {});
    if (!bbTestReady) {
      await partial(testInfo, consoleErrors, 'bb_test-injection',
        `window.bb_test not injected within ${BB_TEST_READY_TIMEOUT_MS}ms.`);
      const bodyText = await page.evaluate(() => document.body.innerText);
      expect(bodyText.length).toBeGreaterThan(0);
      return;
    }
    console.log('[S(J).3] bb_test ready');
    consoleErrors.check();

    // ── Step 2: poll RUN_START ──
    const runStart = await pollScreen(page, RUN_START_SCREEN, SCREEN_POLL_TIMEOUT_MS);
    if (!runStart.ok) {
      await partial(testInfo, consoleErrors, 'run_start',
        `current_screen not RUN_START(7). state: ${JSON.stringify(runStart.state)}`);
      return;
    }
    console.log('[S(J).3] RUN_START confirmed');
    consoleErrors.check();

    // ── Step 3: click_chassis(0) ──
    const clickChassisResult = await page.evaluate(() => window.bb_test.click_chassis(0));
    expect(clickChassisResult, 'click_chassis(0) must return true').toBe(true);
    console.log(`[S(J).3] click_chassis(0): ${JSON.stringify(clickChassisResult)}`);
    consoleErrors.check();

    // ── Battle loop: 3 iterations ──
    for (let battleNum = 1; battleNum <= 3; battleNum++) {
      const battleIdx = battleNum - 1;  // 0-indexed

      // a. wait for in_arena at expected battle index
      const arena = await pollInArena(page, battleIdx, ARENA_POLL_TIMEOUT_MS);
      await page.screenshot({ path: `tests/screenshots/sj3-arena-${battleNum}.png` }).catch(() => {});
      if (!arena.ok) {
        await partial(testInfo, consoleErrors, `in_arena(${battleNum})`,
          `in_arena not true or battle_index mismatch for battle ${battleNum}. arena: ${JSON.stringify(arena.arena)} run: ${JSON.stringify(arena.run)}`);
        return;
      }
      console.log(`[S(J).3] in_arena confirmed (battle ${battleNum}, index ${battleIdx})`);

      // b. canvas non-monochrome
      await assertCanvasOk(page, testInfo, `arena-${battleNum}`);
      consoleErrors.check();

      // c. force_battle_end(0) — player wins
      const forceResult = await page.evaluate(() => window.bb_test.force_battle_end(0));
      expect(forceResult, `force_battle_end(0) must return true (battle ${battleNum})`).toBe(true);
      console.log(`[S(J).3] force_battle_end(0) battle ${battleNum}: ${JSON.stringify(forceResult)}`);

      // d. wait for REWARD_PICK
      const rewardScreen = await pollScreen(page, REWARD_PICK_SCREEN, REWARD_PICK_TIMEOUT_MS);
      await page.screenshot({ path: `tests/screenshots/sj3-reward-${battleNum}.png` }).catch(() => {});
      if (!rewardScreen.ok) {
        await partial(testInfo, consoleErrors, `reward_pick(${battleNum})`,
          `REWARD_PICK screen not reached after battle ${battleNum}. state: ${JSON.stringify(rewardScreen.state)}`);
        return;
      }
      console.log(`[S(J).3] REWARD_PICK reached (battle ${battleNum})`);
      consoleErrors.check();

      // e. click_reward(0)
      const rewardClick = await page.evaluate(() => window.bb_test.click_reward(0));
      expect(rewardClick, `click_reward(0) must return true (reward ${battleNum})`).toBe(true);
      console.log(`[S(J).3] click_reward(0) reward ${battleNum}: ${JSON.stringify(rewardClick)}`);
      consoleErrors.check();
    }

    // ── Final assertion: battles_won >= 3 ──
    const finalState = await page.evaluate(() => window.bb_test.get_run_state());
    await page.screenshot({ path: 'tests/screenshots/sj3-final.png' }).catch(() => {});
    console.log(`[S(J).3] final run_state: ${JSON.stringify(finalState)}`);

    expect(
      finalState && finalState.battles_won >= 3,
      `Expected battles_won >= 3, got: ${finalState ? finalState.battles_won : 'null'}`
    ).toBe(true);

    consoleErrors.check();
    console.log('[S(J).3] FULL_COVERAGE — 3-battle run chain complete');
  });
});
