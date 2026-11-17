import { readFileSync, writeFileSync } from "node:fs";
import { defineConfig } from "vite-plus";

/**
 * Writes jsr.json from package.json so the version lives in one place.
 * jsr.json is git-ignored and regenerated on every `vp pack`.
 */
function generateJsrJson(): void {
  const pkg = JSON.parse(readFileSync("package.json", "utf8")) as {
    name: string;
    version: string;
    license: string;
  };

  const jsrJson = {
    name: pkg.name,
    version: pkg.version,
    license: pkg.license,
    exports: "./src/index.ts",
    publish: {
      include: ["src/**/*.ts", "LICENSE", "README.md"],
      exclude: ["src/**/*.test.ts"],
    },
  };

  writeFileSync("jsr.json", `${JSON.stringify(jsrJson, null, 2)}\n`);
}

export default defineConfig({
  pack: {
    entry: ["./src/index.ts"],
    outDir: "./dist",
    format: ["esm", "cjs"],
    platform: "neutral",
    target: "es2020",
    dts: true,
    hooks: {
      "build:prepare": generateJsrJson,
    },
  },
  test: {
    include: ["src/**/*.test.ts"],
    benchmark: {
      include: ["bench/**/*.bench.ts"],
    },
  },
  lint: {
    ignorePatterns: ["dist/**", "bench/.baseline/**"],
    options: {
      typeAware: true,
      typeCheck: true,
    },
  },
  fmt: {
    printWidth: 80,
    ignorePatterns: ["dist/**", "bench/.baseline/**", "pnpm-lock.yaml"],
  },
});
