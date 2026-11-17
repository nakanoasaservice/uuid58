import { describe, expect, it } from "vite-plus/test";

import { Uuid58DecodeError, Uuid58EncodeError } from "./errors.ts";
import {
  uuid58Decode,
  uuid58DecodeSafe,
  uuid58Encode,
  uuid58EncodeSafe,
} from "./string.ts";

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

  it("keeps the input out of error messages (spec Section 7)", () => {
    const huge = "x".repeat(1_000_000);
    for (const error of [uuid58EncodeSafe(huge), uuid58DecodeSafe(huge)]) {
      expect(error).toBeInstanceOf(Error);
      expect((error as Error).message).not.toContain("xx");
      expect((error as Error).message).toContain("1000000");
    }

    const forged = uuid58DecodeSafe("1111111111111111111\nab");
    expect(forged).toBeInstanceOf(Uuid58DecodeError);
    expect((forged as Error).message).toBe(
      "Invalid Base58 character at index 19",
    );

    const encodeError = uuid58EncodeSafe(
      "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfa\n",
    );
    expect((encodeError as Error).message).not.toContain("f4b247fd");
  });
});

describe("uuid58Encode is case-insensitive and accepts both forms", () => {
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
