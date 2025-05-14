import { ALPHABET_LENGTH, BASE58_ALPHABET } from "./alphabet.ts";

/**
 * Generates a new Base58-encoded UUID (always 22 characters).
 *
 * This function combines the standard UUID generation (using crypto.randomUUID())
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
  let num = BigInt("0x" + crypto.randomUUID().replaceAll("-", ""));
  let encoded = "";

  do {
    encoded = BASE58_ALPHABET[Number(num % ALPHABET_LENGTH)] + encoded;
    num /= ALPHABET_LENGTH;
  } while (num > 0n);

  return encoded.padStart(22, BASE58_ALPHABET[0]);
}
