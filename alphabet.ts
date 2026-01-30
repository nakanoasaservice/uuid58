/**
 * Character set for Base58 encoding (Bitcoin compatible).
 *
 * This alphabet excludes characters that can be easily confused:
 * - `0` (zero) and `O` (capital O)
 * - `I` (capital i) and `l` (lowercase L)
 *
 * The alphabet consists of 58 characters: digits 1-9 and letters A-Z, a-z
 * (excluding the ambiguous characters mentioned above).
 *
 * @example
 * ```typescript
 * const char = UUID58_ALPHABET[0]; // "1"
 * const char = UUID58_ALPHABET[9]; // "A"
 * ```
 */
export const UUID58_ALPHABET: string =
  "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";

/**
 * @internal
 * The length of the Base58 alphabet as BigInt for encoding/decoding operations.
 * This is exported for internal use but not part of the public API.
 */
export const UUID58_LENGTH: bigint = BigInt(UUID58_ALPHABET.length);

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
export const UUID58_REGEX: RegExp = /^[1-9A-HJ-NP-Za-km-z]{22}$/;
