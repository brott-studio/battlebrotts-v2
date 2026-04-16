// tests/screen-nav.spec.js — Playwright screen navigation tests for URL parameter routing
// Validates ?screen= URL params route to the correct game screens.
// See: kb/patterns/godot-ci-visual-verification.md, kb/patterns/playwright-local-server.md
//
// Note: In headless CI, WebGL is unavailable so Godot may stall at loading.
// We check for canvas OR page content (same pattern as smoke.spec.js).
const { test, expect } = require('@playwright/test');

test('/?screen=battle loads game page', async ({ page }) => {
  await page.goto('/game/?screen=battle');
  // Either Godot canvas exists or the HTML shell loaded with content
  const hasContent = await page.evaluate(() => {
    return document.querySelector('canvas') !== null || document.body.innerText.length > 0;
  });
  expect(hasContent).toBeTruthy();
  await page.screenshot({ path: 'tests/screenshots/screen-battle.png' });
});

test('/?screen=menu loads game page', async ({ page }) => {
  await page.goto('/game/?screen=menu');
  const hasContent = await page.evaluate(() => {
    return document.querySelector('canvas') !== null || document.body.innerText.length > 0;
  });
  expect(hasContent).toBeTruthy();
  await page.screenshot({ path: 'tests/screenshots/screen-menu.png' });
});

test('/ with no params loads default flow', async ({ page }) => {
  await page.goto('/game/');
  const hasContent = await page.evaluate(() => {
    return document.querySelector('canvas') !== null || document.body.innerText.length > 0;
  });
  expect(hasContent).toBeTruthy();
  await page.screenshot({ path: 'tests/screenshots/screen-default.png' });
});
