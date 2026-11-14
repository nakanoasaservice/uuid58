import { UUID58_ALPHABET } from "./alphabet.ts";
import { BASE58_CHUNK, previewInput } from "./internal.ts";

// Lookup table from ASCII char code to alphabet index (-1 = not in alphabet).
const BASE58_INDEX = new Int8Array(128).fill(-1);
for (let i = 0; i < UUID58_ALPHABET.length; i++) {
  BASE58_INDEX[UUID58_ALPHABET.charCodeAt(i)] = i;
}

/**
 * Error thrown when an invalid Base58 string is provided for decoding.
 * This includes strings containing characters not in the Base58 alphabet.
 */
export class Uuid58DecodeError extends Error {
  static {
    this.prototype.name = "Uuid58DecodeError";
  }
}

/**
 * Converts a 22-character Base58-encoded string back to a standard UUID format, but instead of
 * throwing an error for invalid input, it returns an `Uuid58DecodeError`
 * instance.
 *
 * @param uuid58 - The 22-character Base58-encoded UUID string to decode
 * @returns A standard UUID string (lowercase, with hyphens), or an
 *   `Uuid58DecodeError` if the input is not a valid 22-character Base58 string
 * @note This function does not throw; it returns the error object instead.
 *
 * @example
 * ```typescript
 * const uuid = uuid58DecodeSafe("XDY9dmBbcMBXqcRvYw8xJ2"); // returns "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf"
 * const error = uuid58DecodeSafe("invalid"); // returns Uuid58DecodeError
 * ```
 */
export function uuid58DecodeSafe(uuid58: string): string | Uuid58DecodeError {
  if (uuid58.length !== 22) {
    return new Uuid58DecodeError(
      `Expected Base58 string of length 22, but received string of length ${uuid58.length}: ${previewInput(uuid58)}`,
    );
  }

  // Accumulate 4 + 9 + 9 digit chunks as Numbers (each below 58^9 < 2^53),
  // then combine them with a few BigInt operations instead of 22.
  let num = 0n;
  for (let start = 0; start < 22;) {
    const end = start === 0 ? 4 : start + 9;
    let chunk = 0;
    for (let i = start; i < end; i++) {
      const code = uuid58.charCodeAt(i);
      const index = code < 128 ? BASE58_INDEX[code]! : -1;
      if (index < 0) {
        const char = String.fromCodePoint(uuid58.codePointAt(i)!);
        return new Uuid58DecodeError(
          `Invalid Base58 character ${JSON.stringify(char)} found in input: ${previewInput(uuid58)}`,
        );
      }
      chunk = chunk * 58 + index;
    }
    num = num * BASE58_CHUNK + BigInt(chunk);
    start = end;
  }

  const hex = num.toString(16).padStart(32, "0");
  if (hex.length !== 32) {
    return new Uuid58DecodeError(
      `Decoded value exceeds 128 bits of UUID: ${previewInput(uuid58)}`,
    );
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
 * Converts a 22-character Base58-encoded string back to a standard UUID string format.
 *
 * @param uuid58 - The 22-character Base58-encoded string to decode
 * @returns A standard UUID string in the format "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" (always in lowercase)
 * @throws {Uuid58DecodeError} If the input string is not a valid 22-character Base58 string
 *
 * @example
 * ```typescript
 * const uuid = uuid58Decode("XDY9dmBbcMBXqcRvYw8xJ2"); // returns "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf"
 * ```
 */
export function uuid58Decode(uuid58: string): string {
  const result = uuid58DecodeSafe(uuid58);
  if (result instanceof Uuid58DecodeError) {
    throw result;
  }
  return result;
}
