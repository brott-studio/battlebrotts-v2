// playwright.config.js
const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './tests',
  testMatch: ['smoke.spec.js', 'sprint0-verify.spec.js', 'screen-nav.spec.js', 'battle-view.spec.js', 's13.4-shop-visual.spec.js', 'gameplay-smoke.spec.js', 'chassis-pick-real-flow.spec.js', 'bb-test-chassis-pick.spec.js', 'bb-test-reward-pick.spec.js', 'bb-test-run-e2e.spec.js'],
  timeout: 30000,
  use: {
    baseURL: 'http://localhost:8080',
    screenshot: 'only-on-failure',
  },
  webServer: {
    command: 'mkdir -p _site/game && ([ -f index.html ] && cp index.html _site/ || printf "<!DOCTYPE html><html lang=en><head><meta charset=UTF-8><title>BattleBrotts v2</title></head><body><p>BattleBrotts v2 - CI stub</p><script>\/\* ci-stub *\/</script></body></html>" > _site/index.html) && cp data.json _site/ && (cp -r build/* _site/game/ 2>/dev/null || printf "<!DOCTYPE html><html lang=en><head><meta charset=UTF-8><title>BattleBrotts v2</title></head><body id=status><p>BattleBrotts v2 - game CI stub</p><script>\/\* ci-stub *\/</script></body></html>" > _site/game/index.html) && npx serve -l 8080 -s _site',
    port: 8080,
    reuseExistingServer: true,
    timeout: 10000,
  },
  reporter: [['list'], ['json', { outputFile: 'tests/results.json' }]],
});
