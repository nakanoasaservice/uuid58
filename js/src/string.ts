import { decodeWords, encodeWords } from "./base58.ts";
import { Uuid58DecodeError, Uuid58EncodeError } from "./errors.ts";
import { formatUuidString, parseUuidString } from "./uuid-hex.ts";

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
  const parsed = parseUuidString(uuid);
  return parsed instanceof Uuid58EncodeError ? parsed : encodeWords(parsed);
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
  const decoded = decodeWords(uuid58);
  return decoded instanceof Uuid58DecodeError
    ? decoded
    : formatUuidString(decoded);
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
