import { expect } from "jsr:@std/expect";
import { describe, it } from "jsr:@std/testing/bdd";

import { uuid58Encode, Uuid58EncodeError, uuid58EncodeSafe } from "./encode.ts";
import { uuid58Decode, Uuid58DecodeError, uuid58DecodeSafe } from "./decode.ts";
import { uuid58 } from "./uuid58.ts";

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
});

describe("uuid58", () => {
  it("round-trips", () => {
    const short = uuid58();
    expect(uuid58Encode(uuid58Decode(short))).toBe(short);
  });
});
