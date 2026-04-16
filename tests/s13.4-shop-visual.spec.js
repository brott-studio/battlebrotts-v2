// tests/s13.4-shop-visual.spec.js — Sprint 13.4 shop card grid screenshot tests
// Generates screenshots at 1280w (desktop 3-col) and 720w (mobile 2-col).
//
// Note: this spec runs against the local _site build. The deployed build is a
// Godot canvas, so these tests produce visual-reference screenshots rather than
// asserting DOM properties. Structural verification (AC #1–15) lives in:
//   godot/tests/test_sprint13_4.gd (42 unit tests against real ShopScreen nodes)
//
// Route `?screen=shop` (added in game_main.gd for S13.4) seeds a new run and
// lands on the shop directly. `?bolts=N` overrides bolt count for
// unaffordable/affordable/owned-state screenshots.
const { test, expect } = require('@playwright/test');
const fs = require('fs');
const path = require('path');

const OUT_DIR = 'tests/screenshots/s13.4-shop';
fs.mkdirSync(OUT_DIR, { recursive: true });

const WAIT_LOAD_MS = 8000;

async function gotoShop(page, bolts) {
  const qs = bolts != null ? `?screen=shop&bolts=${bolts}` : '?screen=shop';
  await page.goto(`/game/${qs}`, { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForTimeout(WAIT_LOAD_MS);
}

async function snap(page, name) {
  const out = path.join(OUT_DIR, `${name}.png`);
  await page.screenshot({ path: out, fullPage: true });
  console.log(`  -> ${out}`);
}

async function hasCanvasOrContent(page) {
  return page.evaluate(() => {
    return document.querySelector('canvas') !== null || document.body.innerText.length > 0;
  });
}

// --- Desktop (1280w) ---
test('s13.4 shop - desktop 3-col grid layout', async ({ browser }) => {
  const ctx = await browser.newContext({ viewport: { width: 1280, height: 720 } });
  const page = await ctx.newPage();
  await gotoShop(page, 500);
  expect(await hasCanvasOrContent(page)).toBeTruthy();
  await snap(page, 'desktop-3col-grid');
  await ctx.close();
});

test('s13.4 shop - desktop bolts counter prominent', async ({ browser }) => {
  const ctx = await browser.newContext({ viewport: { width: 1280, height: 720 } });
  const page = await ctx.newPage();
  await gotoShop(page, 1240);
  await snap(page, 'desktop-bolts-counter');
  await ctx.close();
});

test('s13.4 shop - desktop unaffordable state (bolts=100)', async ({ browser }) => {
  const ctx = await browser.newContext({ viewport: { width: 1280, height: 720 } });
  const page = await ctx.newPage();
  await gotoShop(page, 100);
  await snap(page, 'desktop-unaffordable');
  await ctx.close();
});

test('s13.4 shop - desktop owned state (default loadout visible)', async ({ browser }) => {
  const ctx = await browser.newContext({ viewport: { width: 1280, height: 720 } });
  const page = await ctx.newPage();
  await gotoShop(page, 500);
  await snap(page, 'desktop-owned-state');
  await ctx.close();
});

test('s13.4 shop - desktop expanded card (click a card)', async ({ browser }) => {
  const ctx = await browser.newContext({ viewport: { width: 1280, height: 720 } });
  const page = await ctx.newPage();
  await gotoShop(page, 500);
  await page.mouse.click(200, 240);
  await page.waitForTimeout(1000);
  await snap(page, 'desktop-expanded-card');
  await ctx.close();
});

test('s13.4 shop - desktop buy flow before', async ({ browser }) => {
  const ctx = await browser.newContext({ viewport: { width: 1280, height: 720 } });
  const page = await ctx.newPage();
  await gotoShop(page, 500);
  await snap(page, 'desktop-buy-before');
  await ctx.close();
});

test('s13.4 shop - desktop section headers visible', async ({ browser }) => {
  const ctx = await browser.newContext({ viewport: { width: 1280, height: 720 } });
  const page = await ctx.newPage();
  await gotoShop(page, 500);
  await page.mouse.wheel(0, 400);
  await page.waitForTimeout(500);
  await snap(page, 'desktop-section-order');
  await ctx.close();
});

// --- Mobile (720w) ---
test('s13.4 shop - mobile 2-col grid layout', async ({ browser }) => {
  const ctx = await browser.newContext({ viewport: { width: 720, height: 1024 } });
  const page = await ctx.newPage();
  await gotoShop(page, 500);
  expect(await hasCanvasOrContent(page)).toBeTruthy();
  await snap(page, 'mobile-2col-grid');
  await ctx.close();
});

test('s13.4 shop - mobile unaffordable state', async ({ browser }) => {
  const ctx = await browser.newContext({ viewport: { width: 720, height: 1024 } });
  const page = await ctx.newPage();
  await gotoShop(page, 100);
  await snap(page, 'mobile-unaffordable');
  await ctx.close();
});

test('s13.4 shop - mobile expanded card', async ({ browser }) => {
  const ctx = await browser.newContext({ viewport: { width: 720, height: 1024 } });
  const page = await ctx.newPage();
  await gotoShop(page, 500);
  await page.mouse.click(160, 240);
  await page.waitForTimeout(1000);
  await snap(page, 'mobile-expanded-card');
  await ctx.close();
});
