const MAX_UUID58_CODES = Array.from(
  // UUID max value encoded in Base58 (length 22)
  "YcVfxkQb6JRzqk5kF2tNLv", // cspell:disable-line
  (char) => char.charCodeAt(0),
);

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

  // Compare chars against the max-UUID Base58 string using ASCII order
  let isBelowMax = false;
  for (let i = 0; i < 22; i++) {
    const code = value.charCodeAt(i);
    // Check if character is in the Bitcoin Base58 alphabet
    const isValid = (code >= 49 && code <= 57) || // '1'..'9'
      (code >= 65 && code <= 72) || // 'A'..'H'
      (code >= 74 && code <= 78) || // 'J'..'N'
      (code >= 80 && code <= 90) || // 'P'..'Z'
      (code >= 97 && code <= 107) || // 'a'..'k'
      (code >= 109 && code <= 122); // 'm'..'z'
    if (!isValid) {
      return false;
    }
    if (!isBelowMax) {
      const maxCode = MAX_UUID58_CODES[i]!;
      if (code < maxCode) {
        isBelowMax = true;
      } else if (code > maxCode) {
        return false;
      }
    }
  }

  return true;
}

/**
 * Regular expression pattern for validating UUID58 strings.
 *
 * This regex ensures that a string:
 * - Contains exactly 22 characters
 * - Uses only characters from the Base58 alphabet
 *
 * **Note:** This regex does NOT validate that the decoded value fits within
 * 128 bits (UUID size). For complete validation including 128-bit range
 * checking, use {@link isUuid58} instead.
 *
 * @example
 * ```typescript
 * const isValid = UUID58_REGEX.test("XDY9dmBbcMBXqcRvYw8xJ2"); // true
 * const isValid = UUID58_REGEX.test("invalid"); // false
 * const isValid = UUID58_REGEX.test("123"); // false (too short)
 * ```
 */
export const UUID58_REGEX: RegExp = /^[1-9A-HJ-NP-Za-km-z]{22}$/u;
