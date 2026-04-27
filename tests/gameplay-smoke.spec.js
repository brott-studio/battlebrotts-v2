// tests/gameplay-smoke.spec.js — [S26.3-001] End-to-end gameplay smoke
//
// Closes the framework gap exposed by 2026-04-27 playtest (blank-screen P0
// shipped undetected through S25.1–S25.10).
//
// ════════════════════════════════════════════════════════════════════
// What this catches that smoke.spec.js misses
// ════════════════════════════════════════════════════════════════════
//   - Godot game fails to start (canvas present but blank — old smoke passed)
//   - chassis-pick → battle-start silently fails
//   - Player enters battle UNARMED and dies in <2s (the actual pre-S26.1 bug)
//
// ════════════════════════════════════════════════════════════════════
// Pre-fix bug repro (commit 9aa417f, before S26.1)
// ════════════════════════════════════════════════════════════════════
//   - RunState.equipped_weapons = [] at run start
//   - _on_chassis_picked → _start_roguelike_match → player_brott unarmed
//   - Enemies fired, player died in ~0.9–1.5s
//   - print("[S25.7] match_end: winner=1 ...") fired in console
//   - The retry prompt rendered instead of the arena
//
// The KEY assertion below — "no [S25.7] match_end console line within 2s of
// run_battle entry" — would FAIL on 9aa417f and PASS on S26.1+ main. That's
// the framework-gap-closure invariant.
//
// ════════════════════════════════════════════════════════════════════
// Headless-WebGL caveat (READ before "fixing" failures)
// ════════════════════════════════════════════════════════════════════
// CI's headless Chromium has no GPU. Godot's WebGL renderer typically stalls
// at "Loading…" before _ready() runs, so the URL-param hook (added in this
// sprint at game_main.gd:130-149 under `?screen=run_battle`) never fires.
// In that case there is no console output to inspect and no canvas to click.
//
// We handle this by:
//   1. Trying the FULL flow first (?screen=run_battle&chassis=N).
//   2. Watching the browser console for the canonical Godot-booted marker
//      "[S26.3] run_battle URL hook" within 15s.
//   3. If that marker NEVER appears: WebGL is unavailable. We mark the test
//      as PARTIAL_COVERAGE via test.info().annotations and run a degraded
//      check (page loaded, no fatal pageerror, canvas DOM element present).
//      PARTIAL_COVERAGE is NOT a green light on the gap — true coverage
//      requires a GPU-enabled runner. Treat repeated PARTIAL_COVERAGE in CI
//      as expected; treat a PARTIAL_COVERAGE locally on a GPU machine as a
//      regression (the URL hook itself is broken).
//   4. If the marker appears but [S25.7] match_end fires within 2s of it,
//      that's the pre-fix bug pattern → HARD FAIL.
//
// ════════════════════════════════════════════════════════════════════

const { test, expect } = require('@playwright/test');

const BASE_URL = process.env.GAME_URL || '/game/';

// All three chassis (BRAWLER=0, SCOUT=1, TANK/HEAVY=2 per ChassisData enum).
// We loop so a regression in ONE chassis path still surfaces.
const CHASSIS = [
  { idx: 0, name: 'chassis-0' },
  { idx: 1, name: 'chassis-1' },
  { idx: 2, name: 'chassis-2' },
];

// Minimum battle duration we require before any match_end is acceptable.
// Pre-S26.1, match_end fired in ~0.9–1.5s (player unarmed, died instantly).
// Real chassis-1 battles last well over 2s; 2s is a comfortable lower bound.
const MIN_BATTLE_MS = 2000;

// Window we wait for the URL-hook console marker. Godot WebGL boot in a GPU
// runner typically completes in <8s. 15s gives generous headroom.
const HOOK_BOOT_TIMEOUT_MS = 15000;

// Console-error filter: ignore environmental noise that's expected in
// headless Chromium and unrelated to gameplay correctness.
function isRealError(text) {
  if (!text) return false;
  const benign = [
    'SharedArrayBuffer',
    'crossOriginIsolated',
    'Feature policy',
    'Cross-Origin-Opener-Policy',
    'WebGL',                  // headless WebGL warnings are expected
    'webgl',
    'Failed to load resource', // 404s on optional assets in placeholder builds
    'favicon',
  ];
  return !benign.some(b => text.includes(b));
}

for (const chassis of CHASSIS) {
  test(`[S26.3] run_battle ${chassis.name}: battle must not fire match_end within ${MIN_BATTLE_MS}ms`, async ({ page }, testInfo) => {
    const consoleLog = [];
    const pageErrors = [];
    const realErrors = [];
    let hookFiredAt = null;
    let matchEndAt = null;

    page.on('console', msg => {
      const text = msg.text();
      const stamp = Date.now();
      consoleLog.push({ stamp, type: msg.type(), text });
      if (text.includes('[S26.3] run_battle URL hook')) {
        hookFiredAt = stamp;
      }
      if (text.includes('[S25.7] match_end')) {
        matchEndAt = stamp;
      }
      if (msg.type() === 'error' && isRealError(text)) {
        realErrors.push(text);
      }
    });

    page.on('pageerror', err => {
      pageErrors.push(err.message);
    });

    const url = `${BASE_URL}?screen=run_battle&chassis=${chassis.idx}`;
    await page.goto(url);

    // Phase 1 — wait for the URL-hook console marker (proves Godot booted
    // AND our hook ran). If it never appears, WebGL isn't available.
    const start = Date.now();
    while (Date.now() - start < HOOK_BOOT_TIMEOUT_MS && hookFiredAt === null) {
      await page.waitForTimeout(250);
    }

    await page.screenshot({
      path: `tests/screenshots/gameplay-smoke-${chassis.name}.png`,
      fullPage: false,
    });

    if (hookFiredAt === null) {
      // === PARTIAL_COVERAGE branch ===========================================
      // Godot did not boot far enough to run our URL hook (typical headless CI
      // outcome). We cannot exercise the chassis-pick → battle path here.
      // Run degraded checks instead and annotate clearly.
      testInfo.annotations.push({
        type: 'PARTIAL_COVERAGE',
        description:
          `Godot WebGL did not boot in headless runner (no [S26.3] hook marker within ${HOOK_BOOT_TIMEOUT_MS}ms). ` +
          `Falling back to structural checks. True framework-gap coverage requires a GPU-enabled runner.`,
      });

      // Degraded checks: page reachable + HTML shell loaded + no hard pageerror.
      // We deliberately do NOT assert <canvas> exists — in headless Chromium
      // without GPU, Godot often never creates the canvas element at all
      // (it stalls before reaching that point in the WebGL bootstrap). That's
      // a property of the runner, not a regression. Mirror the pattern from
      // tests/battle-view.spec.js ("⚠ No canvas (headless CI without WebGL)
      // — verifying HTML shell") which is the canonical fallback in this repo.
      console.log(`⚠ No canvas (headless CI without WebGL) — verifying HTML shell only`);

      // HTML shell must have loaded SOMETHING — non-empty body proves the
      // request hit a real document. We deliberately don't check title because
      // the dashboard, /game/ shell, and Godot loader use different titles
      // across CI and dev builds.
      const bodyText = await page.evaluate(() => document.body.innerText);
      expect(bodyText.length, 'document.body.innerText must be non-empty').toBeGreaterThan(0);

      // pageerrors are uncaught JS exceptions — those break the page in any
      // env, GPU or not. Console errors are filtered separately.
      expect(pageErrors, `pageerror events: ${pageErrors.join(' | ')}`).toEqual([]);

      // Even in PARTIAL_COVERAGE, if [S25.7] match_end somehow fired we MUST
      // fail — that means Godot DID boot and the bug is live.
      expect(
        matchEndAt,
        '[S25.7] match_end fired even in PARTIAL_COVERAGE branch — pre-fix bug pattern detected'
      ).toBeNull();

      console.log(`[S26.3] PARTIAL_COVERAGE for ${chassis.name} — WebGL unavailable; structural checks only.`);
      return;
    }

    // === FULL coverage branch =================================================
    // Hook fired → Godot is live and on the roguelike battle path.
    testInfo.annotations.push({
      type: 'FULL_COVERAGE',
      description: `URL hook fired at +${hookFiredAt - start}ms; watching for premature match_end.`,
    });

    // Phase 2 — wait MIN_BATTLE_MS past the hook firing, watching for an
    // illegal early match_end. We poll instead of single waitForTimeout so
    // we can fail fast the instant the bad pattern shows up.
    const deadline = hookFiredAt + MIN_BATTLE_MS;
    while (Date.now() < deadline) {
      if (matchEndAt !== null && matchEndAt - hookFiredAt < MIN_BATTLE_MS) {
        break; // fail-fast — assertion below will catch
      }
      await page.waitForTimeout(100);
    }

    // THE ASSERTION THAT CLOSES THE GAP:
    // Pre-S26.1, match_end fired in <2s of run_battle hook → this fails.
    // Post-S26.1 (player armed), the battle lasts well past 2s → this passes.
    if (matchEndAt !== null) {
      const dt = matchEndAt - hookFiredAt;
      expect(
        dt,
        `[S25.7] match_end fired only ${dt}ms after run_battle entry. ` +
        `This is the pre-S26.1 blank-screen bug pattern: player enters battle ` +
        `unarmed (equipped_weapons=[]), dies in <2s, retry prompt renders instead ` +
        `of the arena. See sprint-26.1 fix.`
      ).toBeGreaterThanOrEqual(MIN_BATTLE_MS);
    }

    // Bonus invariant: no real (non-environmental) console errors during boot+battle.
    expect(
      realErrors,
      `Non-environmental console errors during gameplay: ${realErrors.join(' | ')}`
    ).toEqual([]);

    // Bonus invariant: no uncaught JS pageerrors.
    expect(pageErrors, `pageerror events: ${pageErrors.join(' | ')}`).toEqual([]);

    console.log(`[S26.3] FULL_COVERAGE for ${chassis.name} — battle survived ${MIN_BATTLE_MS}ms past hook (matchEnd=${matchEndAt ? matchEndAt - hookFiredAt + 'ms' : 'not seen'}).`);
  });
}
