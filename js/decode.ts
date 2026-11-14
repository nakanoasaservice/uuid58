import { UUID58_ALPHABET } from "./alphabet.ts";
import type { Uuid58ErrorKind } from "./errors.ts";
import { BASE58_CHUNK, previewInput } from "./internal.ts";

// Lookup table from ASCII char code to alphabet index (-1 = not in alphabet).
const BASE58_INDEX = new Int8Array(128).fill(-1);
for (let i = 0; i < UUID58_ALPHABET.length; i++) {
  BASE58_INDEX[UUID58_ALPHABET.charCodeAt(i)] = i;
}

const MAX_UINT128 = (1n << 128n) - 1n;

/**
 * Error thrown when an invalid uuid58 string is provided for decoding.
 * Its {@link Uuid58DecodeError.kind | kind} tells why.
 */
export class Uuid58DecodeError extends Error {
  static {
    this.prototype.name = "Uuid58DecodeError";
  }

  /**
   * Why the input was rejected: `"invalid_length"`, `"invalid_character"`,
   * or `"overflow"`.
   */
  readonly kind: Uuid58ErrorKind;

  constructor(message: string, kind: Uuid58ErrorKind) {
    super(message);
    this.kind = kind;
  }
}

/**
 * @internal
 * Decodes a uuid58 string to an unsigned 128-bit integer, checking length,
 * then characters, then range (specification, Section 4).
 */
export function decodeUint128(uuid58: string): bigint | Uuid58DecodeError {
  if (uuid58.length !== 22) {
    return new Uuid58DecodeError(
      `Expected Base58 string of length 22, but received string of length ${uuid58.length}: ${previewInput(uuid58)}`,
      "invalid_length",
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
          "invalid_character",
        );
      }
      chunk = chunk * 58 + index;
    }
    num = num * BASE58_CHUNK + BigInt(chunk);
    start = end;
  }

  if (num > MAX_UINT128) {
    return new Uuid58DecodeError(
      `Decoded value exceeds 128 bits of UUID: ${previewInput(uuid58)}`,
      "overflow",
    );
  }
  return num;
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
 * const error = uuid58DecodeSafe("invalid"); // returns Uuid58DecodeError (kind: "invalid_length")
 * ```
 */
export function uuid58DecodeSafe(uuid58: string): string | Uuid58DecodeError {
  const num = decodeUint128(uuid58);
  if (typeof num !== "bigint") {
    return num;
  }

  const hex = num.toString(16).padStart(32, "0");
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
