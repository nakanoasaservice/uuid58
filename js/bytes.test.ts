import { describe, expect, it } from "vite-plus/test";

import {
  Uuid58DecodeError,
  uuid58DecodeBytes,
  Uuid58EncodeError,
  uuid58Encode,
  uuid58EncodeBytes,
  uuid58EncodeBytesSafe,
  uuid58EncodeSafe,
} from "./index.ts";

describe("uuid58EncodeBytes / uuid58DecodeBytes", () => {
  const uuid = "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf";
  const bytes = Uint8Array.from(
    uuid
      .replace(/-/g, "")
      .match(/../g)!
      .map((h) => Number.parseInt(h, 16)),
  );

  it("round-trips", () => {
    expect(uuid58EncodeBytes(bytes)).toBe("XDY9dmBbcMBXqcRvYw8xJ2");
    expect(uuid58DecodeBytes("XDY9dmBbcMBXqcRvYw8xJ2")).toEqual(bytes);
  });

  it("respects the offset of a subarray", () => {
    const buffer = new Uint8Array(20);
    buffer.set(bytes, 3);
    expect(uuid58EncodeBytes(buffer.subarray(3, 19))).toBe(uuid58Encode(uuid));
  });

  it("rejects byte arrays that are not 16 bytes long", () => {
    for (const length of [0, 15, 17]) {
      const result = uuid58EncodeBytesSafe(new Uint8Array(length));
      expect(result).toBeInstanceOf(Uuid58EncodeError);
      expect((result as Uuid58EncodeError).kind).toBe("invalid_length");
    }
    expect(() => uuid58EncodeBytes(new Uint8Array(15))).toThrow(
      Uuid58EncodeError,
    );
  });

  it("returns a new byte array on every call", () => {
    const first = uuid58DecodeBytes("XDY9dmBbcMBXqcRvYw8xJ2");
    const second = uuid58DecodeBytes("1111111111111111111111");
    expect(second).not.toBe(first);
    expect(first).toEqual(bytes);
    expect(second).toEqual(new Uint8Array(16));
  });

  it("round-trips bytes with the high bit set in every position", () => {
    const allOnes = new Uint8Array(16).fill(0xff);
    expect(uuid58DecodeBytes(uuid58EncodeBytes(allOnes))).toEqual(allOnes);
    for (let i = 0; i < 16; i++) {
      const single = new Uint8Array(16);
      single[i] = 0x80;
      expect(uuid58DecodeBytes(uuid58EncodeBytes(single))).toEqual(single);
    }
  });

  it("throws Uuid58DecodeError for invalid input", () => {
    expect(() => uuid58DecodeBytes("invalid")).toThrow(Uuid58DecodeError);
  });
});

describe("error kinds", () => {
  it("reports the kind on encode errors", () => {
    expect((uuid58EncodeSafe("abc") as Uuid58EncodeError).kind).toBe(
      "invalid_length",
    );
    // Hyphens anywhere but 8-4-4-4-12 are rejected (1.x accepted them).
    expect(
      (
        uuid58EncodeSafe(
          "f4b247f-d1f87-45d4-aa06-1c6fc0a8dfaf",
        ) as Uuid58EncodeError
      ).kind,
    ).toBe("invalid_character");
    expect(
      (
        uuid58EncodeSafe(
          "f4b247fd-1f8745d4aa061c6fc0a8dfaf",
        ) as Uuid58EncodeError
      ).kind,
    ).toBe("invalid_length");
  });

  it("reports the kind on thrown decode errors", () => {
    const kindOf = (input: string) => {
      try {
        uuid58DecodeBytes(input);
      } catch (error) {
        return (error as Uuid58DecodeError).kind;
      }
      return undefined;
    };
    expect(kindOf("short")).toBe("invalid_length");
    expect(kindOf("0000000000000000000000")).toBe("invalid_character");
    expect(kindOf("zzzzzzzzzzzzzzzzzzzzzz")).toBe("overflow");
  });
});
