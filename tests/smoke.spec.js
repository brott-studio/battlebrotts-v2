// tests/smoke.spec.js — Playwright smoke test
// Loads the dashboard and verifies it renders
const { test, expect } = require('@playwright/test');

test('dashboard loads', async ({ page }) => {
  // Serve from repo root; CI will start a local server
  await page.goto('http://localhost:8080/');
  await expect(page).toHaveTitle(/BattleBrotts/);
  await page.screenshot({ path: 'tests/screenshots/dashboard.png' });
});

test('game page loads', async ({ page }) => {
  await page.goto('http://localhost:8080/game/');
  // Godot takes a while to init; just verify the HTML loaded
  const body = await page.locator('body');
  await expect(body).toBeVisible();
  await page.screenshot({ path: 'tests/screenshots/game.png' });
});
