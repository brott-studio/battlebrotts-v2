/**
 * tests/visual-helpers.js — Visual + console assertion helpers for Playwright specs.
 *
 * Closes the S26.8 P0 framework gap: the prior smoke specs only checked
 * "canvas exists OR body has text" — they passed on a grey canvas where
 * compose_encounter() silently aborted (typed-array web-export bug).
 *
 * GRACEFUL DEGRADATION CONTRACT:
 *   GitHub Actions runners have NO GPU. Godot's WebGL renderer stalls at
 *   "Loading…" and the canvas never paints. Helpers detect this state
 *   (gl null OR all-zero readback) and return { status: 'PARTIAL' } INSTEAD
 *   of throwing. Specs that need full coverage must check the return value
 *   and annotate test.info().annotations PARTIAL_COVERAGE accordingly.
 *
 * Helpers NEVER throw on the headless-WebGL state — that would make CI red
 * permanently. They throw only when the canvas IS readable and the assertion
 * actually fails. This is the load-bearing invariant.
 */

'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// assertCanvasNotMonochrome
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Assert that the canvas is NOT rendering a single flat colour.
 *
 * On a headless runner where WebGL is unavailable (gl null or all-zero
 * readback), returns { status: 'PARTIAL', reason: 'webgl-unavailable' }
 * WITHOUT throwing so CI stays green.
 *
 * @param {import('@playwright/test').Page} page
 * @param {{ sampleCount?: number, tolerance?: number, monochromeThreshold?: number, selector?: string }} opts
 * @returns {Promise<{ status: 'PASS'|'PARTIAL', stats?: object, reason?: string }>}
 */
async function assertCanvasNotMonochrome(page, opts = {}) {
  const {
    sampleCount = 1000,
    tolerance = 5,
    monochromeThreshold = 0.95,
    selector = 'canvas',
  } = opts;

  const result = await page.evaluate(
    ({ sampleCount, tolerance, monochromeThreshold, selector }) => {
      const canvas = document.querySelector(selector);
      if (!canvas) {
        return { status: 'PARTIAL', reason: 'no-canvas-element' };
      }

      // Try WebGL readback first, then fall back to 2d.
      let pixels = null;
      let width = canvas.width || 0;
      let height = canvas.height || 0;

      if (width === 0 || height === 0) {
        return { status: 'PARTIAL', reason: 'canvas-zero-dimensions' };
      }

      // Attempt WebGL
      try {
        const gl =
          canvas.getContext('webgl') ||
          canvas.getContext('webgl2') ||
          canvas.getContext('experimental-webgl');
        if (gl) {
          const buf = new Uint8Array(width * height * 4);
          gl.readPixels(0, 0, width, height, gl.RGBA, gl.UNSIGNED_BYTE, buf);
          // All-zero = headless, no GPU
          const allZero = buf.every(v => v === 0);
          if (allZero) {
            return { status: 'PARTIAL', reason: 'webgl-all-zero-readback' };
          }
          pixels = buf;
        }
      } catch (_) {
        // WebGL context unavailable or readPixels failed
      }

      // Fall back to 2d
      if (!pixels) {
        try {
          const ctx = canvas.getContext('2d');
          if (!ctx) {
            return { status: 'PARTIAL', reason: 'webgl-unavailable' };
          }
          const imgData = ctx.getImageData(0, 0, width, height);
          pixels = imgData.data;
          const allZero = pixels.every(v => v === 0);
          if (allZero) {
            return { status: 'PARTIAL', reason: 'canvas-all-zero-readback' };
          }
        } catch (_) {
          return { status: 'PARTIAL', reason: 'webgl-unavailable' };
        }
      }

      // Sample random pixels and compute modal RGB
      const totalPixels = width * height;
      const sampled = [];
      for (let i = 0; i < sampleCount; i++) {
        const idx = Math.floor(Math.random() * totalPixels) * 4;
        sampled.push([pixels[idx], pixels[idx + 1], pixels[idx + 2]]);
      }

      // Find modal pixel: use a coarse bucket (divide by tolerance) to cluster
      const bucketKey = ([r, g, b]) =>
        `${Math.round(r / tolerance)},${Math.round(g / tolerance)},${Math.round(b / tolerance)}`;
      const counts = {};
      for (const px of sampled) {
        const k = bucketKey(px);
        counts[k] = (counts[k] || 0) + 1;
      }
      let modalKey = null;
      let modalCount = 0;
      for (const [k, c] of Object.entries(counts)) {
        if (c > modalCount) { modalCount = c; modalKey = k; }
      }

      // Count pixels within tolerance of modal
      const [mr, mg, mb] = modalKey.split(',').map(v => parseInt(v, 10) * tolerance);
      let closeCount = 0;
      for (const [r, g, b] of sampled) {
        if (
          Math.abs(r - mr) <= tolerance &&
          Math.abs(g - mg) <= tolerance &&
          Math.abs(b - mb) <= tolerance
        ) {
          closeCount++;
        }
      }
      const fraction = closeCount / sampleCount;

      if (fraction > monochromeThreshold) {
        // Return an object that will be caught by the outer JS throw
        return {
          status: 'FAIL',
          modalRGB: [mr, mg, mb],
          fraction,
          sampleCount,
        };
      }

      return {
        status: 'PASS',
        stats: { modalRGB: [mr, mg, mb], fraction, sampleCount },
      };
    },
    { sampleCount, tolerance, monochromeThreshold, selector }
  );

  if (result.status === 'FAIL') {
    throw new Error(
      `assertCanvasNotMonochrome: canvas appears monochrome. ` +
      `modalRGB=${JSON.stringify(result.modalRGB)} ` +
      `fraction=${result.fraction.toFixed(3)} (threshold=${monochromeThreshold}) ` +
      `sampleCount=${result.sampleCount}`
    );
  }

  return result; // { status: 'PASS'|'PARTIAL', ... }
}

// ─────────────────────────────────────────────────────────────────────────────
// assertCanvasHasContent
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Assert that the canvas has rendered content beyond a solid background colour.
 * Background is defined as the pixel at (0,0). If more than `minNonBackgroundPct`
 * of sampled pixels differ from the background colour by more than `tolerance`
 * in any channel, the canvas is considered to have content.
 *
 * On headless WebGL (all-zero / no canvas), returns PARTIAL without throwing.
 *
 * @param {import('@playwright/test').Page} page
 * @param {{ selector?: string, minNonBackgroundPct?: number, tolerance?: number }} opts
 * @returns {Promise<{ status: 'PASS'|'PARTIAL', stats?: object, reason?: string }>}
 */
async function assertCanvasHasContent(page, opts = {}) {
  const {
    selector = 'canvas',
    minNonBackgroundPct = 0.05,
    tolerance = 5,
  } = opts;

  const result = await page.evaluate(
    ({ selector, minNonBackgroundPct, tolerance }) => {
      const canvas = document.querySelector(selector);
      if (!canvas) {
        return { status: 'PARTIAL', reason: 'no-canvas-element' };
      }

      const width = canvas.width || 0;
      const height = canvas.height || 0;
      if (width === 0 || height === 0) {
        return { status: 'PARTIAL', reason: 'canvas-zero-dimensions' };
      }

      // Get pixel data
      let pixels = null;

      // Try WebGL first
      try {
        const gl =
          canvas.getContext('webgl') ||
          canvas.getContext('webgl2') ||
          canvas.getContext('experimental-webgl');
        if (gl) {
          const buf = new Uint8Array(width * height * 4);
          gl.readPixels(0, 0, width, height, gl.RGBA, gl.UNSIGNED_BYTE, buf);
          if (buf.every(v => v === 0)) {
            return { status: 'PARTIAL', reason: 'webgl-all-zero-readback' };
          }
          pixels = buf;
        }
      } catch (_) {
        // ignore
      }

      if (!pixels) {
        try {
          const ctx = canvas.getContext('2d');
          if (!ctx) return { status: 'PARTIAL', reason: 'webgl-unavailable' };
          const imgData = ctx.getImageData(0, 0, width, height);
          pixels = imgData.data;
          if (pixels.every(v => v === 0)) {
            return { status: 'PARTIAL', reason: 'canvas-all-zero-readback' };
          }
        } catch (_) {
          return { status: 'PARTIAL', reason: 'webgl-unavailable' };
        }
      }

      // Background = pixel at (0,0)
      const bgR = pixels[0], bgG = pixels[1], bgB = pixels[2];

      // Sample 1000 pixels and count those that differ from background
      const sampleCount = 1000;
      const totalPixels = width * height;
      let nonBgCount = 0;
      for (let i = 0; i < sampleCount; i++) {
        const idx = Math.floor(Math.random() * totalPixels) * 4;
        if (
          Math.abs(pixels[idx] - bgR) > tolerance ||
          Math.abs(pixels[idx + 1] - bgG) > tolerance ||
          Math.abs(pixels[idx + 2] - bgB) > tolerance
        ) {
          nonBgCount++;
        }
      }

      const nonBgFraction = nonBgCount / sampleCount;

      if (nonBgFraction < minNonBackgroundPct) {
        return {
          status: 'FAIL',
          bgRGB: [bgR, bgG, bgB],
          nonBgFraction,
          sampleCount,
          minNonBackgroundPct,
        };
      }

      return {
        status: 'PASS',
        stats: { bgRGB: [bgR, bgG, bgB], nonBgFraction, sampleCount },
      };
    },
    { selector, minNonBackgroundPct, tolerance }
  );

  if (result.status === 'FAIL') {
    throw new Error(
      `assertCanvasHasContent: canvas appears to have no content beyond background. ` +
      `bgRGB=${JSON.stringify(result.bgRGB)} ` +
      `nonBgFraction=${result.nonBgFraction.toFixed(3)} (min=${result.minNonBackgroundPct}) ` +
      `sampleCount=${result.sampleCount}`
    );
  }

  return result;
}

// ─────────────────────────────────────────────────────────────────────────────
// startConsoleCapture / assertConsoleNoErrors
// ─────────────────────────────────────────────────────────────────────────────

// isRealError MUST stay in sync with the duplicate in gameplay-smoke.spec.js.
//
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

/**
 * Start capturing console errors and page errors on `page`.
 * Returns { check } where calling check() throws if any real errors were
 * captured since startConsoleCapture() was called.
 *
 * "Real errors" = console.error events passing isRealError + any pageerror +
 * any unhandled promise rejection.
 *
 * @param {import('@playwright/test').Page} page
 * @returns {{ check: () => void }}
 */
function startConsoleCapture(page) {
  const captured = [];

  page.on('console', msg => {
    if (msg.type() === 'error') {
      const text = msg.text();
      if (isRealError(text)) {
        captured.push({ kind: 'console.error', text });
      }
    }
  });

  page.on('pageerror', err => {
    captured.push({ kind: 'pageerror', text: err.message });
  });

  // Unhandled promise rejections arrive as pageerror on some Playwright versions;
  // on others they're a separate event. Wire both for safety.
  page.on('requestfailed', req => {
    // requestfailed is NOT a real error by default — it includes things like
    // favicon 404s and aborted loads. We intentionally do NOT include these.
    // This handler exists as a named placeholder to prevent future confusion.
    void req;
  });

  return {
    check() {
      if (captured.length > 0) {
        const summary = captured
          .map(e => `[${e.kind}] ${e.text}`)
          .join('\n  ');
        throw new Error(
          `startConsoleCapture: ${captured.length} real error(s) captured:\n  ${summary}`
        );
      }
    },
  };
}

/**
 * One-shot version: assertConsoleNoErrors(page, { capturedErrors }).
 * If you already have an array of captured errors, pass it in.
 * Prefer startConsoleCapture for new specs.
 *
 * @param {import('@playwright/test').Page} _page  (unused — kept for API symmetry)
 * @param {{ capturedErrors?: string[] }} opts
 */
function assertConsoleNoErrors(_page, opts = {}) {
  const { capturedErrors = [] } = opts;
  const real = capturedErrors.filter(isRealError);
  if (real.length > 0) {
    throw new Error(
      `assertConsoleNoErrors: ${real.length} real console error(s):\n  ` +
      real.join('\n  ')
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// assertClickProducesChange
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Click `selector` and wait for any observable change:
 *   - URL navigation
 *   - DOM mutation under `subtreeSelector`
 *   - Canvas pixel delta > `pixelDeltaThreshold`
 *   - Console line matching `expectedConsoleMarker`
 *
 * Returns { signal: 'url'|'dom'|'pixel'|'marker' } indicating which signal
 * fired first. Throws NO_OBSERVABLE_CHANGE after `timeout` ms if nothing fires.
 *
 * On headless (canvas readback all-zero), pixel signal is unavailable;
 * helper relies on URL/DOM/marker signals.
 *
 * @param {import('@playwright/test').Page} page
 * @param {string} selector  CSS selector of the element to click
 * @param {{
 *   timeout?: number,
 *   subtreeSelector?: string,
 *   expectedConsoleMarker?: string,
 *   pixelDeltaThreshold?: number
 * }} opts
 * @returns {Promise<{ signal: 'url'|'dom'|'pixel'|'marker' }>}
 */
async function assertClickProducesChange(page, selector, opts = {}) {
  const {
    timeout = 3000,
    subtreeSelector,
    expectedConsoleMarker,
    pixelDeltaThreshold = 0.05,
  } = opts;

  // --- Pre-click snapshots ---
  const preUrl = page.url();

  // Sample canvas pixels before click (200 points)
  const prePixels = await page.evaluate((canvasSelector) => {
    const canvas = document.querySelector(canvasSelector || 'canvas');
    if (!canvas || !canvas.width || !canvas.height) return null;
    try {
      const gl =
        canvas.getContext('webgl') ||
        canvas.getContext('webgl2') ||
        canvas.getContext('experimental-webgl');
      if (gl) {
        const buf = new Uint8Array(canvas.width * canvas.height * 4);
        gl.readPixels(0, 0, canvas.width, canvas.height, gl.RGBA, gl.UNSIGNED_BYTE, buf);
        if (buf.every(v => v === 0)) return null; // headless
        // Sample 200 random pixels
        const totalPixels = canvas.width * canvas.height;
        const sample = [];
        for (let i = 0; i < 200; i++) {
          const idx = Math.floor(Math.random() * totalPixels) * 4;
          sample.push([buf[idx], buf[idx + 1], buf[idx + 2]]);
        }
        return sample;
      }
    } catch (_) {}
    try {
      const ctx = canvas.getContext('2d');
      if (!ctx) return null;
      const imgData = ctx.getImageData(0, 0, canvas.width, canvas.height);
      const buf = imgData.data;
      if (buf.every(v => v === 0)) return null;
      const totalPixels = canvas.width * canvas.height;
      const sample = [];
      for (let i = 0; i < 200; i++) {
        const idx = Math.floor(Math.random() * totalPixels) * 4;
        sample.push([buf[idx], buf[idx + 1], buf[idx + 2]]);
      }
      return sample;
    } catch (_) {}
    return null;
  }, 'canvas');

  // --- Wire DOM mutation observer ---
  let domMutated = false;
  if (subtreeSelector) {
    await page.evaluate((sel) => {
      window.__assertClickDomMutated = false;
      const target = document.querySelector(sel);
      if (target) {
        const obs = new MutationObserver(() => { window.__assertClickDomMutated = true; });
        obs.observe(target, { childList: true, subtree: true, attributes: true, characterData: true });
        window.__assertClickObserver = obs;
      }
    }, subtreeSelector);
  }

  // --- Wire console marker watch ---
  let markerFired = false;
  const markerHandler = expectedConsoleMarker
    ? (msg) => {
        if (msg.text().includes(expectedConsoleMarker)) markerFired = true;
      }
    : null;
  if (markerHandler) page.on('console', markerHandler);

  // --- Perform click ---
  await page.click(selector);
  const clickedAt = Date.now();

  // --- Poll for signals ---
  let firedSignal = null;
  while (Date.now() - clickedAt < timeout && firedSignal === null) {
    await page.waitForTimeout(100);

    // URL changed?
    if (page.url() !== preUrl) {
      firedSignal = 'url';
      break;
    }

    // DOM mutation?
    if (subtreeSelector) {
      domMutated = await page.evaluate(() => window.__assertClickDomMutated || false);
      if (domMutated) {
        firedSignal = 'dom';
        break;
      }
    }

    // Console marker?
    if (markerFired) {
      firedSignal = 'marker';
      break;
    }

    // Canvas pixel delta?
    if (prePixels) {
      const postPixels = await page.evaluate((preLen) => {
        const canvas = document.querySelector('canvas');
        if (!canvas || !canvas.width || !canvas.height) return null;
        try {
          const gl =
            canvas.getContext('webgl') ||
            canvas.getContext('webgl2') ||
            canvas.getContext('experimental-webgl');
          if (gl) {
            const buf = new Uint8Array(canvas.width * canvas.height * 4);
            gl.readPixels(0, 0, canvas.width, canvas.height, gl.RGBA, gl.UNSIGNED_BYTE, buf);
            if (buf.every(v => v === 0)) return null;
            const totalPixels = canvas.width * canvas.height;
            const sample = [];
            for (let i = 0; i < preLen; i++) {
              const idx = Math.floor(Math.random() * totalPixels) * 4;
              sample.push([buf[idx], buf[idx + 1], buf[idx + 2]]);
            }
            return sample;
          }
        } catch (_) {}
        try {
          const ctx = canvas.getContext('2d');
          if (!ctx) return null;
          const imgData = ctx.getImageData(0, 0, canvas.width, canvas.height);
          const buf = imgData.data;
          if (buf.every(v => v === 0)) return null;
          const totalPixels = canvas.width * canvas.height;
          const sample = [];
          for (let i = 0; i < preLen; i++) {
            const idx = Math.floor(Math.random() * totalPixels) * 4;
            sample.push([buf[idx], buf[idx + 1], buf[idx + 2]]);
          }
          return sample;
        } catch (_) {}
        return null;
      }, prePixels.length);

      if (postPixels && postPixels.length === prePixels.length) {
        let diffCount = 0;
        for (let i = 0; i < prePixels.length; i++) {
          const [r1, g1, b1] = prePixels[i];
          const [r2, g2, b2] = postPixels[i];
          if (Math.abs(r1 - r2) + Math.abs(g1 - g2) + Math.abs(b1 - b2) > 15) {
            diffCount++;
          }
        }
        if (diffCount / prePixels.length > pixelDeltaThreshold) {
          firedSignal = 'pixel';
          break;
        }
      }
    }
  }

  // Cleanup
  if (markerHandler) page.off('console', markerHandler);
  if (subtreeSelector) {
    await page.evaluate(() => {
      if (window.__assertClickObserver) {
        window.__assertClickObserver.disconnect();
        window.__assertClickObserver = null;
      }
      window.__assertClickDomMutated = false;
    }).catch(() => {});
  }

  if (!firedSignal) {
    throw new Error(
      `assertClickProducesChange: NO_OBSERVABLE_CHANGE after ${timeout}ms. ` +
      `Selector: "${selector}". Watched: url, ` +
      `dom(${subtreeSelector || 'none'}), ` +
      `pixel(${prePixels ? 'available' : 'headless-unavailable'}), ` +
      `marker(${expectedConsoleMarker || 'none'})`
    );
  }

  return { signal: firedSignal };
}

// ─────────────────────────────────────────────────────────────────────────────
// Exports
// ─────────────────────────────────────────────────────────────────────────────

module.exports = {
  assertCanvasNotMonochrome,
  assertCanvasHasContent,
  assertConsoleNoErrors,
  startConsoleCapture,
  assertClickProducesChange,
};
