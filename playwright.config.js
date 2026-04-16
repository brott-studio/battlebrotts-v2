// playwright.config.js
const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './tests',
  testMatch: ['smoke.spec.js', 'sprint0-verify.spec.js'],
  timeout: 30000,
  use: {
    baseURL: 'http://localhost:8080',
    screenshot: 'only-on-failure',
  },
  webServer: {
    command: 'npx serve -l 8080 -s _site',
    port: 8080,
    reuseExistingServer: true,
    timeout: 10000,
  },
  reporter: [['list'], ['json', { outputFile: 'tests/results.json' }]],
});
