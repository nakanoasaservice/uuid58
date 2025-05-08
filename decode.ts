import { ALPHABET_LENGTH, BASE58_ALPHABET } from "./alphabet.ts";

// Fast lookup map from alphabet characters to their indices
const BASE58_MAP: Record<string, bigint> = {};
for (let i = 0; i < BASE58_ALPHABET.length; i++) {
  BASE58_MAP[BASE58_ALPHABET[i]!] = BigInt(i);
}

/**
 * Error thrown when an invalid Base58 string is provided for decoding.
 * This includes strings containing characters not in the Base58 alphabet.
 */
export class InvalidBase58Error extends Error {
  static {
    this.prototype.name = "InvalidBase58Error";
  }

  constructor(base58: string) {
    super(`Invalid Base58 string: ${base58}`);
  }
}

/**
 * Converts a Base58-encoded string back to a standard UUID format, but instead of
 * throwing an error for invalid input, it returns an `InvalidBase58Error`
 * instance.
 *
 * @param base58 - The Base58-encoded string to decode
 * @returns A standard UUID string (lowercase, with hyphens), or an
 *   `InvalidBase58Error` if the input contains invalid Base58 characters
 * @note This function does not throw; it returns the error object instead.
 *
 * @example
 * ```typescript
 * const uuid = uuid58DecodeSafe("XDY9dmBbcMBXqcRvYw8xJ2"); // returns "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf"
 * const error = uuid58DecodeSafe("invalid"); // returns InvalidBase58Error
 * ```
 */
export function uuid58DecodeSafe(base58: string): string | InvalidBase58Error {
  let num = 0n;
  for (const char of base58) {
    const index = BASE58_MAP[char];
    if (index === undefined) {
      return new InvalidBase58Error(base58);
    }
    num = num * ALPHABET_LENGTH + index;
  }

  const hex = num.toString(16).padStart(32, "0");
  if (hex.length !== 32) {
    return new InvalidBase58Error(base58);
  }

  return (
    hex.slice(0, 8) +
    "-" +
    hex.slice(8, 12) +
    "-" +
    hex.slice(12, 16) +
    "-" +
    hex.slice(16, 20) +
    "-" +
    hex.slice(20)
  );
}

/**
 * Converts a Base58-encoded string back to a standard UUID string format.
 *
 * @param base58 - The Base58-encoded string to decode
 * @returns A standard UUID string in the format "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" (always in lowercase)
 * @throws {InvalidBase58Error} If the input string contains characters not in the Base58 alphabet
 *
 * @example
 * ```typescript
 * const uuid = uuid58Decode("XDY9dmBbcMBXqcRvYw8xJ2"); // returns "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf"
 * ```
 */
export function uuid58Decode(base58: string): string {
  let num = 0n;
  for (const char of base58) {
    const index = BASE58_MAP[char];
    if (index === undefined) {
      throw new InvalidBase58Error(base58);
    }
    num = num * ALPHABET_LENGTH + index;
  }

  const hex = num.toString(16).padStart(32, "0");
  if (hex.length !== 32) {
    throw new InvalidBase58Error(base58);
  }

  return (
    hex.slice(0, 8) +
    "-" +
    hex.slice(8, 12) +
    "-" +
    hex.slice(12, 16) +
    "-" +
    hex.slice(16, 20) +
    "-" +
    hex.slice(20)
  );
}
