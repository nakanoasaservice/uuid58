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
 * @internal
 * Fast lookup map from alphabet characters to their indices
 */
export const BASE58_MAP: Record<string, bigint> = {};
for (let i = 0; i < UUID58_ALPHABET.length; i++) {
  BASE58_MAP[UUID58_ALPHABET[i]!] = BigInt(i);
}
