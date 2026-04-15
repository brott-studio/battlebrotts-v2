// tests/sprint0-verify.spec.js — Verification smoke tests
// Originally for Sprint 0, now updated to work with the evolving game.
// Uses local server (via playwright.config.js webServer) instead of production URLs.
const { test, expect } = require('@playwright/test');

test('dashboard loads with content', async ({ page }) => {
  await page.goto('/', { waitUntil: 'networkidle', timeout: 30000 });
  const body = page.locator('body');
  await expect(body).toBeVisible();
  const text = await body.innerText();
  expect(text.length).toBeGreaterThan(0);
  // Dashboard should mention BattleBrotts somewhere
  expect(text).toContain('BattleBrotts');
  await page.screenshot({ path: 'tests/screenshots/sprint0-dashboard.png', fullPage: true });
});

test('game page loads with canvas or placeholder', async ({ page }) => {
  await page.goto('/game/', { waitUntil: 'domcontentloaded', timeout: 30000 });
  await page.screenshot({ path: 'tests/screenshots/sprint0-game.png', fullPage: true });
  // In CI without a Godot export, we get a placeholder page.
  // With an export, we get a canvas. Either is valid.
  const hasCanvasOrContent = await page.evaluate(() => {
    return document.querySelector('canvas') !== null || document.body.innerText.length > 0;
  });
  expect(hasCanvasOrContent).toBeTruthy();
});
