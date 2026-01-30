import { UUID58_ALPHABET, UUID58_LENGTH } from "./alphabet.ts";

/**
 * Generates a new Base58-encoded UUID (always 22 characters).
 *
 * This function combines the standard UUID generation (using crypto.getRandomValues())
 * with Base58 encoding to create a shorter, URL-safe identifier.
 *
 * @returns A 22-character Base58-encoded string representing a newly generated UUID
 *
 * @example
 * ```typescript
 * const id = uuid58(); // returns a 22-character string like "XDY9dmBbcMBXqcRvYw8xJ2"
 * ```
 */
export function uuid58(): string {
  const bytes = crypto.getRandomValues(new BigUint64Array(2));

  bytes[0] = (bytes[0]! & 0xffffffffffff0fffn) | 0x0000000000004000n;
  bytes[1] = (bytes[1]! & 0x3fffffffffffffffn) | 0x8000000000000000n;

  let num = bytes[0] << 64n | bytes[1];
  let encoded = "";

  do {
    encoded = UUID58_ALPHABET[Number(num % UUID58_LENGTH)] + encoded;
    num /= UUID58_LENGTH;
  } while (num > 0n);

  return encoded.padStart(22, UUID58_ALPHABET[0]);
}
