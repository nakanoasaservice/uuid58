import { test } from "vite-plus/test";

import * as fixtures from "./fixtures.ts";
import { compareWithBaseline } from "./harness.ts";

// Copy imports into module-local constants: imported bindings are getters
// under Vite's module runner, which would add overhead inside timed loops.
const { MASK, UUID58S, UUID_BYTES, UUIDS } = fixtures;

test("uuid58Encode", async ({ bench }) => {
  await compareWithBaseline(bench, ({ uuid58Encode }) => {
    let i = 0;
    return () => {
      uuid58Encode(UUIDS[i++ & MASK]!);
    };
  });
});

test("uuid58Decode", async ({ bench }) => {
  await compareWithBaseline(bench, ({ uuid58Decode }) => {
    let i = 0;
    return () => {
      uuid58Decode(UUID58S[i++ & MASK]!);
    };
  });
});

test("uuid58EncodeBytes", async ({ bench }) => {
  await compareWithBaseline(bench, ({ uuid58EncodeBytes }) => {
    let i = 0;
    return () => {
      uuid58EncodeBytes(UUID_BYTES[i++ & MASK]!);
    };
  });
});

test("uuid58DecodeBytes", async ({ bench }) => {
  await compareWithBaseline(bench, ({ uuid58DecodeBytes }) => {
    let i = 0;
    return () => {
      uuid58DecodeBytes(UUID58S[i++ & MASK]!);
    };
  });
});

test("uuid58 (generate)", async ({ bench }) => {
  await compareWithBaseline(bench, ({ uuid58 }) => () => {
    uuid58();
  });
});

test("isUuid58", async ({ bench }) => {
  await compareWithBaseline(bench, ({ isUuid58 }) => {
    let i = 0;
    return () => {
      isUuid58(UUID58S[i++ & MASK]!);
    };
  });
});

// Error paths matter for validation-heavy callers (e.g. parsing request IDs).
test("uuid58DecodeSafe (invalid input)", async ({ bench }) => {
  await compareWithBaseline(bench, ({ uuid58DecodeSafe }) => () => {
    uuid58DecodeSafe("not-a-valid-uuid58-str");
  });
});
