/**
 * Shared harness for the benchmarks in this directory.
 *
 * Benchmarks run against built bundles, not the TypeScript sources: Vite's
 * module runner turns every cross-module reference in the sources into a
 * getter, which would dominate measurements this small. The bundle has no
 * internal imports, so it measures what users actually run.
 *
 * - current:  dist/index.js, rebuilt by `pnpm bench`
 * - baseline: bench/.baseline/index.js, saved by `pnpm bench:baseline [ref]`
 */
import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
import type { TestContext } from "vite-plus/test";

import type * as Uuid58 from "../index.ts";

export type Impl = typeof Uuid58;
type Bench = TestContext["bench"];

const CURRENT_PATH = resolve("dist/index.js");
const BASELINE_PATH = resolve("bench/.baseline/index.js");

async function load(path: string): Promise<Impl> {
  return (await import(pathToFileURL(path).href)) as Impl;
}

if (!existsSync(CURRENT_PATH)) {
  throw new Error(
    "dist/index.js not found. Run `pnpm bench`, which builds it.",
  );
}

export const current: Impl = await load(CURRENT_PATH);
export const baseline: Impl | undefined = existsSync(BASELINE_PATH)
  ? await load(BASELINE_PATH)
  : undefined;

if (baseline) {
  const refFile = resolve("bench/.baseline/REF");
  const ref = existsSync(refFile) ? readFileSync(refFile, "utf8").trim() : "?";
  console.info(`Baseline: ${ref}`);
} else {
  console.warn(
    "No baseline at bench/.baseline/index.js; showing current only. " +
      "Run `pnpm bench:baseline [git-ref]` to compare against a saved build.",
  );
}

/**
 * Benchmarks one operation on `current` and, when present, `baseline`.
 *
 * `make` receives an implementation and returns the function to time. Pull
 * what you need out of `impl` inside `make` (not inside the returned function)
 * so the timed loop only calls local references.
 *
 * With a baseline, both run interleaved via `bench.compare()`, which reduces
 * bias from CPU throttling and GC, and Vitest prints a comparison table.
 */
export async function compareWithBaseline(
  bench: Bench,
  make: (impl: Impl) => () => void,
): Promise<void> {
  const currentBench = bench("current", make(current));
  if (baseline) {
    await bench.compare(currentBench, bench("baseline", make(baseline)));
  } else {
    await currentBench.run();
  }
}
