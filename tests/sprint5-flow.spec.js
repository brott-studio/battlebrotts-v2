const { test, expect } = require('@playwright/test');

test('navigate full game flow and capture battle', async ({ page }) => {
  const dir = 'docs/verification/sprint5';
  
  await page.goto('https://brott-studio.github.io/battlebrotts-v2/game/', { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForTimeout(8000);
  
  // Main menu - click NEW GAME
  await page.screenshot({ path: `${dir}/01-main-menu.png` });
  await page.mouse.click(640, 358); // NEW GAME button area
  await page.waitForTimeout(3000);
  await page.screenshot({ path: `${dir}/02-after-new-game.png` });
  
  // We're in shop. Click "Continue" button (bottom right area)
  await page.mouse.click(1070, 633); // Continue button
  await page.waitForTimeout(3000);
  await page.screenshot({ path: `${dir}/03-after-shop-continue.png` });
  
  // Try clicking continue/next on whatever screen we're on
  await page.mouse.click(1070, 633);
  await page.waitForTimeout(3000);
  await page.screenshot({ path: `${dir}/04-next-screen.png` });
  
  // Keep clicking through
  await page.mouse.click(640, 400);
  await page.waitForTimeout(3000);
  await page.screenshot({ path: `${dir}/05-screen5.png` });
  
  await page.mouse.click(640, 500);
  await page.waitForTimeout(3000);
  await page.screenshot({ path: `${dir}/06-screen6.png` });
  
  // Try clicking more
  await page.mouse.click(1070, 633);
  await page.waitForTimeout(3000);
  await page.screenshot({ path: `${dir}/07-screen7.png` });
  
  await page.mouse.click(640, 360);
  await page.waitForTimeout(5000);
  await page.screenshot({ path: `${dir}/08-screen8.png` });
  
  // Wait longer in case battle is playing
  await page.waitForTimeout(10000);
  await page.screenshot({ path: `${dir}/09-after-long-wait.png` });
});
