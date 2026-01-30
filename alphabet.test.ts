import { expect } from "@std/expect";
import { describe, it } from "@std/testing/bdd";

import { UUID58_ALPHABET, UUID58_LENGTH } from "./alphabet.ts";

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
