import { BASE58_MAP, UUID58_LENGTH } from "./alphabet.ts";

// Maximum value for a 128-bit UUID (2^128 - 1)
const MAX_UUID_VALUE = (1n << 128n) - 1n;

/**
 * Checks if a given string is a valid UUID58-encodable string.
 * This function efficiently validates without performing full decoding.
 *
 * A valid UUID58 string must:
 * - Be exactly 22 characters long
 * - Contain only characters from the Base58 alphabet
 * - Decode to a value that fits within 128 bits (UUID size)
 *
 * @param value - The string to check
 * @returns `true` if the string is a valid UUID58 string, `false` otherwise
 *
 * @example
 * ```typescript
 * isUuid58("XDY9dmBbcMBXqcRvYw8xJ2"); // true
 * isUuid58("invalid"); // false
 * isUuid58("O0lI"); // false (contains invalid characters)
 * ```
 */
export function isUuid58(value: string): boolean {
  // Check length: UUID58 strings must be exactly 22 characters
  if (value.length !== 22) {
    return false;
  }

  // Convert Base58 string to BigInt and check if it's within UUID range
  let num = 0n;
  for (const char of value) {
    const index = BASE58_MAP[char];
    // Check if character is in the Base58 alphabet
    if (index === undefined) {
      return false;
    }
    num = num * UUID58_LENGTH + index;
    // Early exit: if we exceed the maximum UUID value, it's invalid
    if (num > MAX_UUID_VALUE) {
      return false;
    }
  }

  // Verify the decoded value fits within 128 bits
  return num <= MAX_UUID_VALUE;
}

/**
 * Regular expression pattern for validating UUID58 strings.
 *
 * This regex ensures that a string:
 * - Contains exactly 22 characters
 * - Uses only characters from the Base58 alphabet
 * - Does not start with leading zeros (represented as "1" in Base58)
 *
 * @example
 * ```typescript
 * const isValid = UUID58_REGEX.test("XDY9dmBbcMBXqcRvYw8xJ2"); // true
 * const isValid = UUID58_REGEX.test("invalid"); // false
 * const isValid = UUID58_REGEX.test("123"); // false (too short)
 * ```
 */
export const UUID58_REGEX: RegExp = /^[1-9A-HJ-NP-Za-km-z]{22}$/u;
