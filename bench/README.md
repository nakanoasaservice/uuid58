# Benchmarks

Benchmarks compare the **current** build against a saved **baseline** build,
run interleaved in one process so both see the same CPU and GC conditions.

| File               | Role                                                                          |
| ------------------ | ----------------------------------------------------------------------------- |
| `uuid58.bench.ts`  | One `test()` per public operation. Add new cases here.                        |
| `harness.ts`       | Loads `dist/` (current) and `.baseline/` (baseline); `compareWithBaseline()`. |
| `fixtures.ts`      | Deterministic inputs (seeded PRNG), identical across runs and machines.       |
| `save-baseline.sh` | Builds any git ref in a temporary worktree and saves it to `.baseline/`.      |
| `.baseline/`       | Saved baseline bundle (git-ignored, machine-local).                           |

## Improvement loop

```bash
pnpm bench:baseline      # 1. snapshot the last commit (HEAD) as the baseline
# 2. edit the source
pnpm bench               # 3. build and compare current against the baseline
# 4. keep or revert; once committed, go back to 1 for the next idea
```

To measure a whole branch, use `main` as the baseline:

```bash
pnpm bench:baseline main
```

Read the `hz` (ops/sec) column. Treat differences inside the `rme` (relative
margin of error), or below a few percent, as noise. Re-run before trusting a
small win. Without a saved baseline, `pnpm bench` shows the current build
only.

## Why benchmark the bundle?

Under Vitest, sources run through Vite's module runner, which turns every
imported binding into a getter. In code this small, the getters dominate the
measurement. The built `dist/index.js` has no internal imports, and it is what
users actually run.

For the same reason, bench files copy imported values into module-local
constants. Inside `make`, pull functions out of `impl` before returning the
timed closure. Vitest prints a "module export getters" warning if a benchmark
breaks this rule.

## Adding a benchmark

```ts
test("uuid58Encode (uppercase input)", async ({ bench }) => {
  await compareWithBaseline(bench, ({ uuid58Encode }) => {
    const input = UUIDS[0]!.toUpperCase();
    return () => {
      uuid58Encode(input);
    };
  });
});
```

Benchmarks can only call the public API, which exists in both builds. To try
an idea before it is wired into the library, change the source and compare
against `HEAD`. Git keeps the history of experiments that were rejected.
