/**
 * Compares uuid58 with other common ways to shorten a UUID in JavaScript.
 * Run with `pnpm bench:compare`. The README's Performance table comes from
 * this file.
 *
 * - short-uuid: the popular npm package, with its default Flickr Base58
 *   alphabet (padded to 22 characters, like uuid58).
 * - bs58 + hex: the do-it-yourself approach, Base58-encoding the 16 bytes.
 *   It does not pad to a fixed length or validate input strictly, so it does
 *   less work than uuid58.
 *
 * All three run interleaved via `bench.compare()`, so they see the same CPU
 * and GC conditions.
 */
import bs58 from "bs58";
import shortUuid from "short-uuid";
import { test } from "vite-plus/test";

import * as fixtures from "./fixtures.ts";
import { current } from "./harness.ts";

// Copy imports into module-local constants: imported bindings are getters
// under Vite's module runner, which would add overhead inside timed loops.
const { MASK, UUIDS, UUID58S } = fixtures;
const { uuid58Encode, uuid58Decode } = current;
const translator = shortUuid.createTranslator(shortUuid.constants.flickrBase58);
const SHORT_UUIDS = UUIDS.map((uuid) => translator.fromUUID(uuid));
const BS58S = UUIDS.map((uuid) =>
  bs58.encode(Buffer.from(uuid.replace(/-/g, ""), "hex")),
);

test("encode (UUID string to short string)", async ({ bench }) => {
  let i = 0;
  await bench.compare(
    bench("uuid58", () => {
      uuid58Encode(UUIDS[i++ & MASK]!);
    }),
    bench("short-uuid", () => {
      translator.fromUUID(UUIDS[i++ & MASK]!);
    }),
    bench("bs58 + hex", () => {
      bs58.encode(Buffer.from(UUIDS[i++ & MASK]!.replace(/-/g, ""), "hex"));
    }),
  );
});

test("decode (short string to UUID string)", async ({ bench }) => {
  let i = 0;
  await bench.compare(
    bench("uuid58", () => {
      uuid58Decode(UUID58S[i++ & MASK]!);
    }),
    bench("short-uuid", () => {
      translator.toUUID(SHORT_UUIDS[i++ & MASK]!);
    }),
    bench("bs58 + hex", () => {
      Buffer.from(bs58.decode(BS58S[i++ & MASK]!)).toString("hex");
    }),
  );
});
