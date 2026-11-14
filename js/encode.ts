import type { Uuid58ErrorKind } from "./errors.ts";
import { encodeWords, previewInput } from "./internal.ts";

// Lookup table from ASCII char code to hex digit value (-1 = not a hex digit).
const HEX_VALUE = new Int8Array(128).fill(-1);
for (let i = 0; i < 16; i++) {
  HEX_VALUE["0123456789abcdef".charCodeAt(i)] = i;
  HEX_VALUE["0123456789ABCDEF".charCodeAt(i)] = i;
}

/** Reused output of {@link parseUuidString}; overwritten on every call. */
const words = new Uint32Array(4);

/**
 * Appends the hex digits of `uuid` in `[start, end)` to `acc`, or returns a
 * negative number if any of them is not a hex digit. A negative `acc` stays
 * negative (at most `16^n - 1` is added to `acc * 16^n`), so chained calls
 * carry the failure through.
 */
function parseHex(
  uuid: string,
  start: number,
  end: number,
  acc: number,
): number {
  for (let i = start; i < end; i++) {
    const code = uuid.charCodeAt(i);
    const digit = code < 128 ? HEX_VALUE[code]! : -1;
    if (digit < 0) {
      return -1;
    }
    acc = acc * 16 + digit;
  }
  return acc;
}

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
 * (Section 5.1) into an unsigned 128-bit integer, as four 32-bit words (most
 * significant first). The returned array is reused across calls.
 *
 * Every character is checked explicitly, so surrounding whitespace, a
 * trailing newline, or non-ASCII digits are rejected.
 */
export function parseUuidString(uuid: string): Uint32Array | Uuid58EncodeError {
  let w0: number;
  let w1: number;
  let w2: number;
  let w3: number;
  let hyphensValid = true;
  if (uuid.length === 32) {
    w0 = parseHex(uuid, 0, 8, 0);
    w1 = parseHex(uuid, 8, 16, 0);
    w2 = parseHex(uuid, 16, 24, 0);
    w3 = parseHex(uuid, 24, 32, 0);
  } else if (uuid.length === 36) {
    w0 = parseHex(uuid, 0, 8, 0);
    w1 = parseHex(uuid, 14, 18, parseHex(uuid, 9, 13, 0));
    w2 = parseHex(uuid, 24, 28, parseHex(uuid, 19, 23, 0));
    w3 = parseHex(uuid, 28, 36, 0);
    hyphensValid =
      uuid.charCodeAt(8) === 45 &&
      uuid.charCodeAt(13) === 45 &&
      uuid.charCodeAt(18) === 45 &&
      uuid.charCodeAt(23) === 45;
  } else {
    return new Uuid58EncodeError(
      `Invalid UUID length: expected 32 or 36 characters, got ${uuid.length} in ${previewInput(uuid)}`,
      "invalid_length",
    );
  }

  if (!hyphensValid || w0 < 0 || w1 < 0 || w2 < 0 || w3 < 0) {
    return new Uuid58EncodeError(
      uuid.length === 32
        ? `Invalid UUID: ${previewInput(uuid)} must be 32 hexadecimal digits`
        : `Invalid UUID: ${previewInput(uuid)} must be in the form xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`,
      "invalid_character",
    );
  }
  words[0] = w0;
  words[1] = w1;
  words[2] = w2;
  words[3] = w3;
  return words;
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
