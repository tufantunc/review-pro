import { defineConfig } from "vitest/config";

// lcov is what sonar-project.properties points SonarQube at
// (sonar.javascript.lcov.reportPaths=cli/coverage/lcov.info); text and html
// stay for local runs.
export default defineConfig({
  test: {
    coverage: {
      reporter: ["text", "html", "lcov"],
    },
  },
});
