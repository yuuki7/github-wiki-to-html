import { defineConfig } from "@playwright/test";

// Browser tests, run against the built site in
// frontend/out, served as the preview serves it. Build
// the site first (bundle exec rake build:site), then
// run these with bundle exec rake test:browser. The
// unit tests in frontend/tests/ are the other half:
// they pin the arrangement's arithmetic, these pin its
// behaviour in a real browser — the crossings of the
// screen's kinds, the drags, the fits — where a wrong
// reading of the arrangement only shows as a window in
// the wrong place.
export default defineConfig({
  testDir: "../frontend/tests-browser",
  timeout: 60_000,
  workers: 1,
  use: {
    baseURL: "http://127.0.0.1:4322",
  },
  webServer: {
    command: "npx serve -l tcp://127.0.0.1:4322 ../frontend/out",
    url: "http://127.0.0.1:4322",
    reuseExistingServer: true,
  },
});
