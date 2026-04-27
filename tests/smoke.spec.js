// tests/smoke.spec.js — Playwright smoke tests for BattleBrotts v2
// Validates that dashboard and game pages deploy and render correctly.
// Keep these tests generic — don't test game internals that change each sprint.
const { test, expect } = require('@playwright/test');
const { assertCanvasNotMonochrome, startConsoleCapture } = require('./visual-helpers.js');

test('dashboard loads with content', async ({ page }) => {
  const errors = startConsoleCapture(page);
  await page.goto('/');
  await expect(page).toHaveTitle(/BattleBrotts/);
  // Dashboard should have visible text content
  const body = page.locator('body');
  await expect(body).toBeVisible();
  await expect(body).not.toBeEmpty();
  await page.screenshot({ path: 'tests/screenshots/dashboard.png' });
  await assertCanvasNotMonochrome(page);
  errors.check();
});

test('game page loads', async ({ page }) => {
  const errors = startConsoleCapture(page);
  await page.goto('/game/');
  const body = page.locator('body');
  await expect(body).toBeVisible();
  await page.screenshot({ path: 'tests/screenshots/game.png' });
  await assertCanvasNotMonochrome(page);
  errors.check();
});

test('game page has canvas or placeholder', async ({ page }) => {
  const errors = startConsoleCapture(page);
  await page.goto('/game/');
  // Either a real Godot canvas exists (exported build) or the placeholder HTML loaded
  const hasContent = await page.evaluate(() => {
    return document.querySelector('canvas') !== null || document.body.innerText.length > 0;
  });
  expect(hasContent).toBeTruthy();
  await page.screenshot({ path: 'tests/screenshots/game-canvas-check.png' });
  await assertCanvasNotMonochrome(page);
  errors.check();
});
