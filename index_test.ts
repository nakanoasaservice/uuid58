import { describe, it } from "jsr:@std/testing/bdd";
import { expect } from "jsr:@std/expect";

import { encodeUuid58 } from "./encode.ts";
import { decodeUuid58 } from "./decode.ts";
import { uuid58 } from "./uuid58.ts";

describe("encodeUuid58 / decodeUuid58 round-trip", () => {
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
      const short = encodeUuid58(uuid);
      const restored = decodeUuid58(short);
      expect(restored).toBe(uuid.toLowerCase());
    }
  });

  it("returns a Base58 string of ~22 chars for non-degenerate UUIDs", () => {
    const uuid = "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf";
    const short = encodeUuid58(uuid);
    expect(short.length).toBe(22);
  });

  it("throws on malformed UUID input", () => {
    expect(() => encodeUuid58("not-a-uuid")).toThrow();
    expect(() => encodeUuid58("12345678-1234")).toThrow();
  });

  it("throws on malformed Base58 input", () => {
    expect(() => decodeUuid58("O0lI")).toThrow(); // Contains forbidden characters
    expect(() => decodeUuid58("$$$")).toThrow();
  });
});

describe("uuid58", () => {
  it("round-trips", () => {
    const short = uuid58();
    expect(encodeUuid58(decodeUuid58(short))).toBe(short);
  });
});
