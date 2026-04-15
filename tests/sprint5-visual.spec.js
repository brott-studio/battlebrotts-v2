const { test, expect } = require('@playwright/test');

test('game page renders with Godot canvas', async ({ page }) => {
  await page.goto('https://brott-studio.github.io/battlebrotts-v2/game/', { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForTimeout(8000);
  await page.screenshot({ path: 'docs/verification/sprint5/game-initial.png', fullPage: true });
  
  const canvas = page.locator('canvas');
  const count = await canvas.count();
  console.log(`Canvas elements: ${count}`);
  expect(count).toBeGreaterThan(0);
});

test('game page after interaction', async ({ page }) => {
  await page.goto('https://brott-studio.github.io/battlebrotts-v2/game/', { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForTimeout(10000);
  
  // Click center to potentially start/interact
  await page.mouse.click(640, 360);
  await page.waitForTimeout(3000);
  await page.screenshot({ path: 'docs/verification/sprint5/game-after-click.png', fullPage: true });
  
  // Click lower area (might be a button)
  await page.mouse.click(640, 500);
  await page.waitForTimeout(3000);
  await page.screenshot({ path: 'docs/verification/sprint5/game-screen2.png', fullPage: true });
  
  // Click another spot
  await page.mouse.click(640, 300);
  await page.waitForTimeout(2000);
  await page.screenshot({ path: 'docs/verification/sprint5/game-screen3.png', fullPage: true });
});

test('mobile viewport', async ({ browser }) => {
  const context = await browser.newContext({ viewport: { width: 375, height: 667 } });
  const page = await context.newPage();
  await page.goto('https://brott-studio.github.io/battlebrotts-v2/game/', { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForTimeout(10000);
  await page.screenshot({ path: 'docs/verification/sprint5/game-mobile.png', fullPage: true });
  await context.close();
});
