// tests/smoke.spec.js — Playwright smoke tests for BattleBrotts v2
// Validates that dashboard and game pages deploy and render correctly.
// Keep these tests generic — don't test game internals that change each sprint.
const { test, expect } = require('@playwright/test');

test('dashboard loads with content', async ({ page }) => {
  await page.goto('/');
  await expect(page).toHaveTitle(/BattleBrotts/);
  // Dashboard should have visible text content
  const body = page.locator('body');
  await expect(body).toBeVisible();
  await expect(body).not.toBeEmpty();
  await page.screenshot({ path: 'tests/screenshots/dashboard.png' });
});

test('game page loads', async ({ page }) => {
  await page.goto('/game/');
  const body = page.locator('body');
  await expect(body).toBeVisible();
  await page.screenshot({ path: 'tests/screenshots/game.png' });
});

test('game page has canvas or placeholder', async ({ page }) => {
  await page.goto('/game/');
  // Either a real Godot canvas exists (exported build) or the placeholder HTML loaded
  const hasContent = await page.evaluate(() => {
    return document.querySelector('canvas') !== null || document.body.innerText.length > 0;
  });
  expect(hasContent).toBeTruthy();
});
