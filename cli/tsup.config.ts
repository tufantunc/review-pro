import { defineConfig } from "tsup";

export default defineConfig({
  entry: ["src/cli.ts"],
  format: ["esm"],
  target: "node18",
  platform: "node",
  splitting: false,
  sourcemap: false,
  clean: true,
  banner: { js: "#!/usr/bin/env node" },
});
