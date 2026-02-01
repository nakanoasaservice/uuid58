// UUID max value encoded in Base58 (length 22)
const MAX_UUID58 = "YcVfxkQb6JRzqk5kF2tNLv"; // cspell:disable-line

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

/**
 * Checks if a given string is a valid UUID58-encodable string.
 * This function efficiently validates without performing full decoding.
 *
 * A valid UUID58 string must:
 * - Be exactly 22 characters long
 * - Contain only characters from the Base58 alphabet
 * - Decode to a value that fits within 128 bits (UUID size)
 *
 * @param uuid58 - The string to check
 * @returns `true` if the string is a valid UUID58 string, `false` otherwise
 *
 * @example
 * ```typescript
 * isUuid58("XDY9dmBbcMBXqcRvYw8xJ2"); // true
 * isUuid58("invalid"); // false
 * isUuid58("O0lI"); // false (contains invalid characters)
 * ```
 */
export function isUuid58(uuid58: string): boolean {
  return UUID58_REGEX.test(uuid58) && uuid58 <= MAX_UUID58;
}
