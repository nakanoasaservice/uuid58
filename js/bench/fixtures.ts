/**
 * Deterministic benchmark inputs, so current and baseline (and runs on
 * different days) always see exactly the same data.
 *
 * Benchmarks cycle through these arrays instead of reusing one constant, so
 * the engine cannot specialize on a single input.
 */

export const SIZE = 1024; // power of two: index with `i++ & MASK`
export const MASK: number = SIZE - 1;

// mulberry32: tiny seeded PRNG, good enough for benchmark inputs.
function mulberry32(seed: number): () => number {
  return () => {
    seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), seed | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return (t ^ (t >>> 14)) >>> 0;
  };
}

function makeUuids(seed: number): string[] {
  const next = mulberry32(seed);
  // `>>> 0` keeps bitwise results unsigned; without it they can go negative.
  const hex = (n: number) => (n >>> 0).toString(16).padStart(8, "0");
  const uuids = Array.from({ length: SIZE }, () => {
    const a = hex(next());
    const b = hex((next() & 0xffff0fff) | 0x4000); // version 4
    const c = hex((next() & 0x3fffffff) | 0x80000000); // variant 10
    const d = hex(next());
    return `${a}-${b.slice(0, 4)}-${b.slice(4)}-${c.slice(0, 4)}-${c.slice(4)}${d}`;
  });
  const v4 =
    /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
  const bad = uuids.find((uuid) => !v4.test(uuid));
  if (bad !== undefined) throw new Error(`Bad fixture UUID: ${bad}`);
  return uuids;
}

/** Random v4 UUIDs in canonical lowercase, hyphenated form. */
export const UUIDS: readonly string[] = makeUuids(0x5eed);

/** Valid 22-character UUID58 strings: UUIDS encoded with the reference algorithm. */
export const UUID58S: readonly string[] = UUIDS.map((uuid) => {
  const alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";
  let num = BigInt(`0x${uuid.replace(/-/g, "")}`);
  let out = "";
  for (let i = 0; i < 22; i++) {
    out = alphabet[Number(num % 58n)] + out;
    num /= 58n;
  }
  return out;
});
