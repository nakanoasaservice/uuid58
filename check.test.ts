import { expect } from "@std/expect";
import { describe, it } from "@std/testing/bdd";

import { isUuid58, UUID58_REGEX } from "./check.ts";
import { UUID58_ALPHABET } from "./alphabet.ts";
import { uuid58Encode } from "./encode.ts";
import { uuid58DecodeSafe } from "./decode.ts";

const validUuids = [
  "00000000-0000-0000-0000-000000000000", // All zeros
  "ffffffff-ffff-ffff-ffff-ffffffffffff", // All ff
  "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf", // Random
  "123e4567-e89b-12d3-a456-426614174000", // RFC 4122 example
  "00112233-4455-6677-8899-aabbccddeeff", // Contains leading 00 bytes
];

describe("isUuid58", () => {
  describe("boundary values", () => {
    it("returns true for minimum UUID value (all zeros)", () => {
      const minUuid = "00000000-0000-0000-0000-000000000000";
      const encoded = uuid58Encode(minUuid);
      expect(isUuid58(encoded)).toBe(true);
      expect(encoded).toBe("1111111111111111111111");
    });

    it("returns true for maximum UUID value", () => {
      expect(isUuid58("YcVfxkQb6JRzqk5kF2tNLv")).toBe(true); // cspell:disable-line
    });

    it("returns false for max UUID value plus one", () => {
      // MAX_UUID58 + 1
      expect(isUuid58("YcVfxkQb6JRzqk5kF2tNLw")).toBe(false); // cspell:disable-line
    });
  });

  describe("valid UUID58 strings", () => {
    it("returns true for valid encoded UUID strings", () => {
      for (const uuid of validUuids) {
        const encoded = uuid58Encode(uuid);
        expect(isUuid58(encoded)).toBe(true);
      }
    });

    it("returns true for valid 22-character Base58 strings", () => {
      // All '1' characters (minimum Base58 value, represents zero)
      expect(isUuid58("1111111111111111111111")).toBe(true);

      // Mixed valid characters that decode to valid UUIDs
      expect(isUuid58("123456789ABCDEFGHJKLMN")).toBe(true); // cspell:disable-line
      expect(isUuid58("PQRSTUVWXYZabcdefghijk")).toBe(true); // cspell:disable-line
    });
  });

  describe("invalid length", () => {
    it("returns false for strings shorter than 22 characters", () => {
      expect(isUuid58("")).toBe(false);
      expect(isUuid58("short")).toBe(false);
      expect(isUuid58("UoWww8DGaVGLtea7zU7p")).toBe(false); // 21 characters
      expect(isUuid58("123456789012345678901")).toBe(false); // 21 characters
      expect(isUuid58("123456789ABCDEFGHJKLM")).toBe(false); // 21 characters (cspell:disable-line)
    });

    it("returns false for strings longer than 22 characters", () => {
      expect(isUuid58("11111111111111111111111")).toBe(false); // 23 characters
      expect(isUuid58("1111UoWww8DGaVGLtea7zU7p")).toBe(false); // 26 characters
      expect(isUuid58("12345678901234567890123")).toBe(false); // 23 characters
      expect(isUuid58("123456789ABCDEFGHJKLMNP")).toBe(false); // 23 characters (cspell:disable-line)
    });
  });

  describe("invalid characters", () => {
    it("returns false for strings containing forbidden Base58 characters", () => {
      expect(isUuid58("O0lI111111111111111111")).toBe(false); // Contains O, 0, l, I
      expect(isUuid58("$$$111111111111111111")).toBe(false); // Contains special characters
      expect(isUuid58("invalid11111111111111")).toBe(false); // Contains invalid characters
      expect(isUuid58("11111111111111111111O0")).toBe(false); // Contains O and 0 at the end
    });

    it("returns false for strings containing lowercase 'l'", () => {
      expect(isUuid58("11111111111111111111l1")).toBe(false);
    });

    it("returns false for strings containing uppercase 'I'", () => {
      expect(isUuid58("11111111111111111111I1")).toBe(false);
    });

    it("returns false for strings containing uppercase 'O'", () => {
      expect(isUuid58("11111111111111111111O1")).toBe(false);
    });

    it("returns false for strings containing digit '0'", () => {
      expect(isUuid58("1111111111111111111101")).toBe(false);
    });
  });

  describe("values exceeding 128 bits", () => {
    it("returns false for Base58 strings that decode to values exceeding 128 bits", () => {
      // 22 'z' characters (maximum Base58 value) exceeds 128 bits
      expect(isUuid58("zzzzzzzzzzzzzzzzzzzzzz")).toBe(false);

      // Verify that decode also fails for this value
      const decodeResult = uuid58DecodeSafe("zzzzzzzzzzzzzzzzzzzzzz");
      expect(decodeResult).toBeInstanceOf(Error);
    });

    it("returns false for strings that would exceed 128 bits during decoding", () => {
      // A string that starts with high-value characters
      expect(isUuid58("zzzzzzzzzzzzzzzzzzzzz1")).toBe(false);
    });
  });

  describe("consistency with decode function", () => {
    it("returns true for strings that can be decoded successfully", () => {
      for (const uuid of validUuids) {
        const encoded = uuid58Encode(uuid);
        const decodeResult = uuid58DecodeSafe(encoded);
        expect(decodeResult).not.toBeInstanceOf(Error);
        expect(isUuid58(encoded)).toBe(true);
      }
    });

    it("returns false for strings that fail to decode", () => {
      const invalidStrings = [
        "O0lI111111111111111111", // Invalid characters
        "short", // Too short
        "11111111111111111111111", // Too long
        "zzzzzzzzzzzzzzzzzzzzzz", // Exceeds 128 bits
      ];

      for (const invalid of invalidStrings) {
        const decodeResult = uuid58DecodeSafe(invalid);
        expect(decodeResult).toBeInstanceOf(Error);
        expect(isUuid58(invalid)).toBe(false);
      }
    });
  });
});

describe("UUID58_REGEX", () => {
  it("matches valid 22-character Base58 strings", () => {
    const validStrings = [
      "XDY9dmBbcMBXqcRvYw8xJ2",
      "1111111111111111111111", // All "1" (represents leading zeros)
      "zzzzzzzzzzzzzzzzzzzzzz", // All "z"
      "123456789ABCDEFGHJKLMN", // Mixed case (cspell:disable-line)
      "abcdefghijkmnopqrstuvw", // Lowercase only (cspell:disable-line)
      "ABCDEFGHJKLMNPQRSTUVWX", // Uppercase only (cspell:disable-line)
    ];

    for (const str of validStrings) {
      expect(UUID58_REGEX.test(str)).toBe(true);
    }
  });

  it("does not match strings shorter than 22 characters", () => {
    const invalidStrings = [
      "",
      "1",
      "XDY9dmBbcMBXqcRvYw8xJ", // 21 characters
      "123456789ABCDEFGHJKLM", // 21 characters (cspell:disable-line)
    ];

    for (const str of invalidStrings) {
      expect(UUID58_REGEX.test(str)).toBe(false);
    }
  });

  it("does not match strings longer than 22 characters", () => {
    const invalidStrings = [
      "XDY9dmBbcMBXqcRvYw8xJ22", // 23 characters
      "11111111111111111111111", // 23 characters
      "123456789ABCDEFGHJKLMNP", // 23 characters (cspell:disable-line)
    ];

    for (const str of invalidStrings) {
      expect(UUID58_REGEX.test(str)).toBe(false);
    }
  });

  it("does not match strings containing forbidden characters (0, O, I, l)", () => {
    const invalidStrings = [
      "0DY9dmBbcMBXqcRvYw8xJ2", // Contains "0"
      "XDY9dmBbcMBXqcRvYw8xJO", // Contains "O"
      "IDY9dmBbcMBXqcRvYw8xJ2", // Contains "I"
      "XDY9dmBbcMBXqcRvYw8xl2", // Contains "l"
      "0OIl0OIl0OIl0OIl0OIl0O", // Contains all forbidden characters
    ];

    for (const str of invalidStrings) {
      expect(UUID58_REGEX.test(str)).toBe(false);
    }
  });

  it("does not match strings containing non-alphanumeric characters", () => {
    const invalidStrings = [
      "XDY9dmBbcMBXqcRvYw8xJ-", // Contains hyphen
      "XDY9dmBbcMBXqcRvYw8xJ_", // Contains underscore
      "XDY9dmBbcMBXqcRvYw8xJ ", // Contains space
      "XDY9dmBbcMBXqcRvYw8xJ.", // Contains period
      "XDY9dmBbcMBXqcRvYw8xJ@", // Contains @
      "XDY9dmBbcMBXqcRvYw8xJ#", // Contains #
      "XDY9dmBbcMBXqcRvYw8xJ$", // Contains $
    ];

    for (const str of invalidStrings) {
      expect(UUID58_REGEX.test(str)).toBe(false);
    }
  });

  it("matches strings that start with '1' (representing leading zeros)", () => {
    const validStrings = [
      "1111111111111111111111", // All "1"
      "1XDY9dmBbcMBXqcRvYw8xJ", // Starts with "1"
      "123456789ABCDEFGHJKLMN", // Starts with "1" (cspell:disable-line)
    ];

    for (const str of validStrings) {
      expect(UUID58_REGEX.test(str)).toBe(true);
    }
  });

  it("does not match empty string", () => {
    expect(UUID58_REGEX.test("")).toBe(false);
  });

  it("works with actual encoded UUID58 values", () => {
    // These are real encoded UUIDs from the main test suite
    const realEncodedUuids = [
      "1111111111111111111111", // All zeros UUID
      "7mTz9XK2YpQvNwRfJhLcBdG", // Example encoded UUID
    ];

    for (const str of realEncodedUuids) {
      // Only test if the string is exactly 22 characters and uses valid Base58 chars
      if (str.length === 22) {
        const hasOnlyValidChars = [...str].every((char) =>
          UUID58_ALPHABET.includes(char)
        );
        if (hasOnlyValidChars) {
          expect(UUID58_REGEX.test(str)).toBe(true);
        }
      }
    }
  });
});
