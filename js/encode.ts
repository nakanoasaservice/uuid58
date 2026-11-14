import type { Uuid58ErrorKind } from "./errors.ts";
import { encodeUint128, previewInput } from "./internal.ts";

// Every character is checked explicitly: BigInt() would silently trim
// surrounding whitespace. Without the `m` flag, `$` matches only at the very
// end of the string, so a trailing newline is rejected.
const HEX32_REGEX = /^[0-9a-f]{32}$/i;
const HYPHENATED_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * Error thrown when an invalid UUID string or byte array is provided for
 * encoding. Its {@link Uuid58EncodeError.kind | kind} tells why.
 */
export class Uuid58EncodeError extends Error {
  static {
    this.prototype.name = "Uuid58EncodeError";
  }

  /**
   * Why the input was rejected: `"invalid_length"` or `"invalid_character"`.
   */
  readonly kind: Exclude<Uuid58ErrorKind, "overflow">;

  constructor(message: string, kind: Exclude<Uuid58ErrorKind, "overflow">) {
    super(message);
    this.kind = kind;
  }
}

/**
 * @internal
 * Parses a UUID string in one of the two forms of the specification
 * (Section 5.1) into an unsigned 128-bit integer.
 */
export function parseUuidString(uuid: string): bigint | Uuid58EncodeError {
  let hex: string;
  if (uuid.length === 32) {
    if (!HEX32_REGEX.test(uuid)) {
      return new Uuid58EncodeError(
        `Invalid UUID: ${previewInput(uuid)} must be 32 hexadecimal digits`,
        "invalid_character",
      );
    }
    hex = uuid;
  } else if (uuid.length === 36) {
    if (!HYPHENATED_REGEX.test(uuid)) {
      return new Uuid58EncodeError(
        `Invalid UUID: ${previewInput(uuid)} must be in the form xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`,
        "invalid_character",
      );
    }
    hex =
      uuid.slice(0, 8) +
      uuid.slice(9, 13) +
      uuid.slice(14, 18) +
      uuid.slice(19, 23) +
      uuid.slice(24);
  } else {
    return new Uuid58EncodeError(
      `Invalid UUID length: expected 32 or 36 characters, got ${uuid.length} in ${previewInput(uuid)}`,
      "invalid_length",
    );
  }
  return BigInt("0x" + hex);
}

/**
 * Converts a standard UUID string to a 22-character Base58-encoded format, but instead of
 * throwing an error for invalid input, it returns an `Uuid58EncodeError` instance.
 *
 * Only two forms are accepted, in any letter case: the hyphenated form
 * (`xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`) and 32 hexadecimal digits. Braces,
 * `urn:uuid:`, whitespace, and hyphens in other positions are rejected.
 *
 * @param uuid - The UUID string to encode (hyphenated, or 32 hexadecimal digits)
 * @returns A 22-character Base58-encoded string, or an `Uuid58EncodeError` if the input is
 *   not a valid UUID
 * @note This function does not throw; it returns the error object instead.
 *
 * @example
 * ```typescript
 * // With hyphens
 * const base58 = uuid58EncodeSafe("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf"); // returns "XDY9dmBbcMBXqcRvYw8xJ2"
 * // Without hyphens
 * const base58 = uuid58EncodeSafe("f4b247fd1f8745d4aa061c6fc0a8dfaf"); // returns "XDY9dmBbcMBXqcRvYw8xJ2"
 * // Uppercase UUID is also accepted
 * const base58 = uuid58EncodeSafe("F4B247FD-1F87-45D4-AA06-1C6FC0A8DFAF"); // returns "XDY9dmBbcMBXqcRvYw8xJ2"
 * // Invalid UUID format
 * const error = uuid58EncodeSafe("invalid"); // returns Uuid58EncodeError (kind: "invalid_length")
 * ```
 */
export function uuid58EncodeSafe(uuid: string): string | Uuid58EncodeError {
  const num = parseUuidString(uuid);
  return typeof num === "bigint" ? encodeUint128(num) : num;
}

/**
 * Converts a standard UUID string to a 22-character Base58-encoded format.
 *
 * @param uuid - The UUID string to encode, either hyphenated
 *              ("xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx") or as 32 hexadecimal digits
 *              ("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"). Hexadecimal digits may be in any case.
 *              Other forms, including hyphens in other positions, are rejected.
 * @returns A 22-character Base58-encoded string representation of the UUID
 * @throws {Uuid58EncodeError} If the input string is not a valid UUID format
 *
 * @example
 * ```typescript
 * // With hyphens
 * const base58 = uuid58Encode("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf"); // returns "XDY9dmBbcMBXqcRvYw8xJ2"
 * // Without hyphens
 * const base58 = uuid58Encode("f4b247fd1f8745d4aa061c6fc0a8dfaf"); // returns "XDY9dmBbcMBXqcRvYw8xJ2"
 * // Uppercase UUID is also accepted
 * const base58 = uuid58Encode("F4B247FD-1F87-45D4-AA06-1C6FC0A8DFAF"); // returns "XDY9dmBbcMBXqcRvYw8xJ2"
 * ```
 */
export function uuid58Encode(uuid: string): string {
  const result = uuid58EncodeSafe(uuid);
  if (result instanceof Uuid58EncodeError) {
    throw result;
  }
  return result;
}
