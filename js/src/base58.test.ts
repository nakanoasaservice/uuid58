import { describe, expect, it } from "vite-plus/test";

import { Uuid58DecodeError, Uuid58EncodeError } from "./errors.ts";
import {
  uuid58Decode,
  uuid58DecodeSafe,
  uuid58Encode,
  uuid58EncodeSafe,
} from "./string.ts";

describe("word-based Base58 conversion matches the BigInt reference", () => {
  const ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";
  const MAX = (1n << 128n) - 1n;

  function referenceEncode(num: bigint): string {
    let encoded = "";
    do {
      encoded = ALPHABET[Number(num % 58n)] + encoded;
      num /= 58n;
    } while (num > 0n);
    return encoded.padStart(22, "1");
  }

  const toUuid = (num: bigint) => {
    const hex = num.toString(16).padStart(32, "0");
    return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
  };

  // Values around every power of 58 (digit-group boundaries), around each
  // 32-bit word boundary, and at the 128-bit limits.
  const values = new Set<bigint>([0n, 1n, MAX, MAX - 1n]);
  for (let k = 1n; k <= 21n; k++) {
    for (const v of [58n ** k - 1n, 58n ** k, 58n ** k + 1n]) values.add(v);
  }
  for (let k = 32n; k <= 96n; k += 32n) {
    for (const v of [(1n << k) - 1n, 1n << k, (1n << k) + 1n]) values.add(v);
  }
  // Every combination of all-zero and all-one 32-bit words, and words near
  // the 58^3 divisor (where long-division remainders peak).
  for (let mask = 0; mask < 16; mask++) {
    let allOnes = 0n;
    let nearCube = 0n;
    for (let word = 0; word < 4; word++) {
      const on = (mask >> word) & 1;
      allOnes = (allOnes << 32n) | (on ? 0xffffffffn : 0n);
      nearCube = (nearCube << 32n) | (on ? 195111n : 195112n);
    }
    values.add(allOnes);
    values.add(nearCube);
  }
  for (let i = 0; i < 500; i++) {
    values.add(BigInt("0x" + crypto.randomUUID().replace(/-/g, "")));
  }

  it("encodes and decodes boundary and random values identically", () => {
    for (const value of values) {
      const expected = referenceEncode(value);
      expect(uuid58Encode(toUuid(value))).toBe(expected);
      expect(uuid58Decode(expected)).toBe(toUuid(value));
    }
  });

  it("rejects every value from 2^128 up to 58^22 - 1 as overflow", () => {
    const tooLarge = [MAX + 1n, MAX + 2n, 58n ** 22n - 1n];
    for (let k = 0n; k < 128n; k += 17n) tooLarge.push(MAX + 1n + (1n << k));
    for (const value of tooLarge) {
      const result = uuid58DecodeSafe(referenceEncode(value));
      expect(result).toBeInstanceOf(Uuid58DecodeError);
      expect((result as Uuid58DecodeError).kind).toBe("overflow");
    }
    expect((uuid58DecodeSafe("z".repeat(22)) as Uuid58DecodeError).kind).toBe(
      "overflow",
    );
  });

  it("is unaffected by earlier calls, including failed ones", () => {
    const first = uuid58Encode(toUuid(MAX));
    const decoded = uuid58Decode(first);
    // Fail at each stage, then succeed with different values.
    uuid58DecodeSafe("z".repeat(22)); // overflow after filling every word
    uuid58DecodeSafe("1".repeat(21) + "0"); // invalid character at the end
    uuid58EncodeSafe("f".repeat(31) + "g");
    expect(uuid58Encode(toUuid(0n))).toBe("1".repeat(22));
    expect(uuid58Decode("1".repeat(22))).toBe(toUuid(0n));
    expect(uuid58Encode(toUuid(MAX))).toBe(first);
    expect(uuid58Decode(first)).toBe(decoded);
    expect(first).toBe(referenceEncode(MAX));
    expect(decoded).toBe(toUuid(MAX));
  });

  it("rejects a non-hex character at every UUID position", () => {
    const hyphenated = toUuid(MAX);
    const plain = hyphenated.replace(/-/g, "");
    for (const uuid of [hyphenated, plain]) {
      for (let position = 0; position < uuid.length; position++) {
        const expected = uuid[position] === "-" ? "f" : "-";
        for (const bad of [expected, "g", " ", "\uFF11", "\u212A"]) {
          if (bad === uuid[position]) continue;
          const input =
            uuid.slice(0, position) + bad + uuid.slice(position + 1);
          const result = uuid58EncodeSafe(input);
          expect(result, input).toBeInstanceOf(Uuid58EncodeError);
          expect((result as Uuid58EncodeError).kind).toBe("invalid_character");
        }
      }
    }
  });

  it("rejects invalid characters in every chunk, including non-ASCII", () => {
    const valid = referenceEncode(MAX);
    for (const position of [0, 3, 4, 12, 13, 21]) {
      for (const bad of ["0", "O", "I", "l", "é", "\u{1F600}".slice(0, 1)]) {
        const input =
          valid.slice(0, position) + bad + valid.slice(position + 1);
        expect(uuid58DecodeSafe(input)).toBeInstanceOf(Uuid58DecodeError);
      }
    }
  });
});
