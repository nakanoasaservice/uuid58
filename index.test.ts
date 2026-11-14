import { describe, expect, it } from "vite-plus/test";

import { uuid58Encode, Uuid58EncodeError, uuid58EncodeSafe } from "./encode.ts";
import { uuid58Decode, Uuid58DecodeError, uuid58DecodeSafe } from "./decode.ts";
import { uuid58 } from "./generate.ts";

const samples = [
  "00000000-0000-0000-0000-000000000000", // All zeros
  "ffffffff-ffff-ffff-ffff-ffffffffffff", // All ff
  "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf", // Random
  "123e4567-e89b-12d3-a456-426614174000", // RFC 4122 example
  "00112233-4455-6677-8899-aabbccddeeff", // Contains leading 00 bytes
];

describe("uuid58Encode / uuid58Decode round-trip", () => {
  it("encodes then decodes back to the identical UUID (case-insensitive)", () => {
    for (const uuid of samples) {
      const short = uuid58Encode(uuid);
      const restored = uuid58Decode(short);
      expect(restored).toBe(uuid.toLowerCase());
    }
  });

  it("returns a Base58 string of ~22 chars for non-degenerate UUIDs", () => {
    const uuid = "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf";
    const short = uuid58Encode(uuid);
    expect(short.length).toBe(22);
  });

  it("throws on malformed UUID input", () => {
    expect(() => uuid58Encode("not-a-uuid")).toThrow(Uuid58EncodeError);
    expect(() => uuid58Encode("12345678-1234")).toThrow(Uuid58EncodeError);
  });

  it("throws on malformed Base58 input", () => {
    expect(() => uuid58Decode("O0lI")).toThrow(Uuid58DecodeError); // Contains forbidden characters
    expect(() => uuid58Decode("$$$")).toThrow(Uuid58DecodeError);
  });

  it("throws on Base58 strings that are too short", () => {
    expect(() => uuid58Decode("UoWww8DGaVGLtea7zU7p")).toThrow(
      Uuid58DecodeError,
    );
  });

  it("throws on Base58 strings that are too long", () => {
    expect(() => uuid58Decode("1111UoWww8DGaVGLtea7zU7p")).toThrow(
      Uuid58DecodeError,
    );
  });
});

describe("uuid58EncodeSafe / uuid58DecodeSafe", () => {
  it("encodes and decodes correctly (safe)", () => {
    for (const uuid of samples) {
      const encoded = uuid58EncodeSafe(uuid);
      expect(encoded).not.toBeInstanceOf(Uuid58EncodeError);
      if (encoded instanceof Uuid58EncodeError) throw encoded;
      const decoded = uuid58DecodeSafe(encoded);
      expect(decoded).not.toBeInstanceOf(Uuid58DecodeError);
      if (decoded instanceof Uuid58DecodeError) throw decoded;
      expect(decoded).toBe(uuid.toLowerCase());
    }
  });

  it("returns Uuid58EncodeError on malformed UUID input (safe)", () => {
    expect(uuid58EncodeSafe("not-a-uuid")).toBeInstanceOf(Uuid58EncodeError);
    expect(uuid58EncodeSafe("12345678-1234")).toBeInstanceOf(Uuid58EncodeError);
  });

  it("returns Uuid58DecodeError on malformed Base58 input (safe)", () => {
    expect(uuid58DecodeSafe("O0lI")).toBeInstanceOf(Uuid58DecodeError);
    expect(uuid58DecodeSafe("$$$")).toBeInstanceOf(Uuid58DecodeError);
  });

  it("rejects UUIDs padded with whitespace instead of hex digits", () => {
    const hex31 = "f4b247fd1f8745d4aa061c6fc0a8dfa";
    for (const ws of [" ", "\n", "\t", " "]) {
      expect(uuid58EncodeSafe(hex31 + ws)).toBeInstanceOf(Uuid58EncodeError);
      expect(uuid58EncodeSafe(ws + hex31)).toBeInstanceOf(Uuid58EncodeError);
    }
  });

  it("truncates and escapes untrusted input in error messages", () => {
    const huge = "x".repeat(1_000_000);
    const encodeError = uuid58EncodeSafe(huge);
    const decodeError = uuid58DecodeSafe(huge);
    for (const error of [encodeError, decodeError]) {
      expect(error).toBeInstanceOf(Error);
      expect((error as Error).message.length).toBeLessThan(300);
      expect((error as Error).message).toContain("1000000 characters");
    }

    const forged = uuid58DecodeSafe("1111111111111111111\nab");
    expect(forged).toBeInstanceOf(Uuid58DecodeError);
    expect((forged as Error).message).not.toContain("\n");
  });
});

describe("uuid58", () => {
  it("round-trips", () => {
    const short = uuid58();
    expect(uuid58Encode(uuid58Decode(short))).toBe(short);
  });

  it("generates valid UUID v4 with variant 1", () => {
    const short = uuid58();
    const decoded = uuid58Decode(short);

    // Check UUID format (8-4-4-4-12 pattern)
    expect(decoded).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/,
    );

    // Check version 4 (13th character should be '4')
    expect(decoded[14]).toBe("4");

    // Check variant 1 (17th character should be '8', '9', 'a', or 'b')
    expect(["8", "9", "a", "b"]).toContain(decoded[19]);
  });
});

describe("uuid58Encode is case-insensitive and ignores hyphens", () => {
  const uuidVariants = [
    "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf",
    "F4B247FD-1F87-45D4-AA06-1C6FC0A8DFAF",
    "f4b247fd1f8745d4aa061c6fc0a8dfaf",
    "F4B247FD1F8745D4AA061C6FC0A8DFAF",
  ];
  it("returns the same Base58 string for all case/hyphen variants", () => {
    const encodedSet = new Set(uuidVariants.map(uuid58Encode));
    expect(encodedSet.size).toBe(1);
  });
  it("safe version also returns the same Base58 string for all case/hyphen variants", () => {
    const encodedSet = new Set(
      uuidVariants.map((uuid) => {
        const result = uuid58EncodeSafe(uuid);
        if (result instanceof Uuid58EncodeError) throw result;
        return result;
      }),
    );
    expect(encodedSet.size).toBe(1);
  });
});

describe("chunked Base58 conversion matches the digit-by-digit reference", () => {
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

  // Values around every power of 58 (chunk boundaries at 58^9 and 58^18),
  // around 2^64, and at the 128-bit limits.
  const values = new Set<bigint>([0n, 1n, MAX, MAX - 1n, 1n << 64n]);
  for (let k = 1n; k <= 21n; k++) {
    for (const v of [58n ** k - 1n, 58n ** k, 58n ** k + 1n]) values.add(v);
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

  it("rejects values just above 128 bits", () => {
    expect(uuid58DecodeSafe(referenceEncode(MAX + 1n))).toBeInstanceOf(
      Uuid58DecodeError,
    );
    expect(uuid58DecodeSafe("z".repeat(22))).toBeInstanceOf(Uuid58DecodeError);
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
