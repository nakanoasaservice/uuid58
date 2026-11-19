import { describe, expect, it, vi } from "vite-plus/test";

import { uuid58, uuid58Decode, uuid58Encode } from "./index.ts";

describe("uuid58", () => {
  it("round-trips", () => {
    const short = uuid58();
    expect(uuid58Encode(uuid58Decode(short))).toBe(short);
  });

  it("preserves the 122 payload bits from each Web Crypto fill", () => {
    let words = [0x01234567, 0x89abcdef, 0xfedcba98, 0x76543210];
    const fill = vi
      .spyOn(crypto, "getRandomValues")
      .mockImplementation((view) => {
        if (!(view instanceof Uint32Array) || view.length !== 4) {
          throw new Error("Expected a four-word Uint32Array");
        }
        view.set(words);
        return view;
      });
    try {
      expect(uuid58Decode(uuid58())).toBe(
        "01234567-89ab-4def-bedc-ba9876543210",
      );
      // Complement every input bit on the second call to exercise the reused buffer.
      words = words.map((word) => ~word >>> 0);
      expect(uuid58Decode(uuid58())).toBe(
        "fedcba98-7654-4210-8123-456789abcdef",
      );
      expect(fill).toHaveBeenCalledTimes(2);
    } finally {
      fill.mockRestore();
    }
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

  it("sets the version and variant on every call", () => {
    const v4 =
      /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
    for (let i = 0; i < 1000; i++) {
      expect(uuid58Decode(uuid58())).toMatch(v4);
    }
  });
});
