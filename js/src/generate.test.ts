import { describe, expect, it } from "vite-plus/test";

import { uuid58 } from "./generate.ts";
import { uuid58Decode, uuid58Encode } from "./string.ts";

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

  it("sets the version and variant on every call", () => {
    const v4 =
      /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
    for (let i = 0; i < 1000; i++) {
      expect(uuid58Decode(uuid58())).toMatch(v4);
    }
  });
});
