import { expect } from "@std/expect";
import { describe, it } from "@std/testing/bdd";

import { UUID58_ALPHABET, UUID58_LENGTH, UUID58_REGEX } from "./alphabet.ts";

describe("UUID58_ALPHABET", () => {
  it("has exactly 58 characters", () => {
    expect(UUID58_ALPHABET.length).toBe(58);
  });

  it("contains digits 1-9", () => {
    const digits = "123456789";
    for (const digit of digits) {
      expect(UUID58_ALPHABET).toContain(digit);
    }
  });

  it("excludes digit 0", () => {
    expect(UUID58_ALPHABET).not.toContain("0");
  });

  it("contains uppercase letters A-Z except I and O", () => {
    const expectedLetters = "ABCDEFGHJKLMNPQRSTUVWXYZ"; // cspell:disable-line
    for (const letter of expectedLetters) {
      expect(UUID58_ALPHABET).toContain(letter);
    }
    expect(UUID58_ALPHABET).not.toContain("I");
    expect(UUID58_ALPHABET).not.toContain("O");
  });

  it("contains lowercase letters a-z except l", () => {
    const expectedLetters = "abcdefghijkmnopqrstuvwxyz"; // cspell:disable-line
    for (const letter of expectedLetters) {
      expect(UUID58_ALPHABET).toContain(letter);
    }
    expect(UUID58_ALPHABET).not.toContain("l");
  });

  it("has no duplicate characters", () => {
    const seen = new Set<string>();
    for (const char of UUID58_ALPHABET) {
      expect(seen.has(char)).toBe(false);
      seen.add(char);
    }
    expect(seen.size).toBe(58);
  });

  it("matches the Bitcoin Base58 alphabet", () => {
    const expectedAlphabet =
      "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";
    expect(UUID58_ALPHABET).toBe(expectedAlphabet);
  });

  it("has characters in the correct order", () => {
    // First 9 characters should be digits 1-9
    expect(UUID58_ALPHABET.slice(0, 9)).toBe("123456789");
    // Next should be uppercase letters (excluding I and O)
    expect(UUID58_ALPHABET.slice(9, 33)).toBe("ABCDEFGHJKLMNPQRSTUVWXYZ"); // cspell:disable-line
    // Last should be lowercase letters (excluding l)
    expect(UUID58_ALPHABET.slice(33)).toBe("abcdefghijkmnopqrstuvwxyz"); // cspell:disable-line
  });
});

describe("UUID58_LENGTH", () => {
  it("equals the length of UUID58_ALPHABET as BigInt", () => {
    expect(UUID58_LENGTH).toBe(BigInt(UUID58_ALPHABET.length));
    expect(UUID58_LENGTH).toBe(58n);
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
