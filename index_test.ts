import { expect } from "jsr:@std/expect";
import { describe, it } from "jsr:@std/testing/bdd";

import { uuid58Decode } from "./decode.ts";
import { uuid58Encode } from "./encode.ts";
import { uuid58 } from "./uuid58.ts";

describe("uuid58Encode / uuid58Decode round-trip", () => {
  // Prepare various UUIDs including random, typical, and zero-padded cases
  const samples = [
    "00000000-0000-0000-0000-000000000000", // All zeros
    "ffffffff-ffff-ffff-ffff-ffffffffffff", // All ff
    "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf", // Random
    "123e4567-e89b-12d3-a456-426614174000", // RFC 4122 example
    "00112233-4455-6677-8899-aabbccddeeff", // Contains leading 00 bytes
  ];

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
    expect(() => uuid58Encode("not-a-uuid")).toThrow();
    expect(() => uuid58Encode("12345678-1234")).toThrow();
  });

  it("throws on malformed Base58 input", () => {
    expect(() => uuid58Decode("O0lI")).toThrow(); // Contains forbidden characters
    expect(() => uuid58Decode("$$$")).toThrow();
  });
});

describe("uuid58", () => {
  it("round-trips", () => {
    const short = uuid58();
    expect(uuid58Encode(uuid58Decode(short))).toBe(short);
  });
});
