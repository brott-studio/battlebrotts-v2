const { test, expect } = require('@playwright/test');

test('dashboard loads with content', async ({ page }) => {
  await page.goto('https://blor-inc.github.io/battlebrotts-v2/', { waitUntil: 'networkidle', timeout: 30000 });
  const body = await page.locator('body');
  await expect(body).toBeVisible();
  const text = await body.innerText();
  expect(text.length).toBeGreaterThan(0);
  await page.screenshot({ path: 'docs/verification/sprint0/dashboard.png', fullPage: true });
});

test('game page loads with Godot canvas', async ({ page }) => {
  await page.goto('https://blor-inc.github.io/battlebrotts-v2/game/', { waitUntil: 'networkidle', timeout: 30000 });
  // Godot shell may hide body until engine loads; just screenshot and check canvas exists in DOM
  await page.screenshot({ path: 'docs/verification/sprint0/game.png', fullPage: true });
  // Check for canvas element in DOM (Godot renders to canvas)
  const canvas = page.locator('canvas');
  const canvasCount = await canvas.count();
  console.log(`Canvas elements found: ${canvasCount}`);
  // Also check if the Godot engine script is present
  const godotScript = await page.evaluate(() => {
    return document.querySelector('script[src*="godot"]') !== null || 
           document.querySelector('canvas#canvas') !== null ||
           document.querySelector('canvas') !== null;
  });
  console.log(`Godot-related elements found: ${godotScript}`);
  expect(canvasCount > 0 || godotScript).toBeTruthy();
});
