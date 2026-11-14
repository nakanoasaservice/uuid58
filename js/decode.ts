import { UUID58_ALPHABET } from "./alphabet.ts";
import type { Uuid58ErrorKind } from "./errors.ts";
import { BASE58_CUBE, previewInput, WORD } from "./internal.ts";

// Lookup table from ASCII char code to alphabet index (-1 = not in alphabet).
const BASE58_INDEX = new Int8Array(128).fill(-1);
for (let i = 0; i < UUID58_ALPHABET.length; i++) {
  BASE58_INDEX[UUID58_ALPHABET.charCodeAt(i)] = i;
}

/** Reused output of {@link decodeWords}; overwritten on every call. */
const words = new Uint32Array(4);

// Character codes of the lowercase hex digits.
const HEX_CODES = new Uint8Array(16);
for (let i = 0; i < 16; i++) {
  HEX_CODES[i] = "0123456789abcdef".charCodeAt(i);
}

/** Output buffer for {@link uuid58DecodeSafe}; hyphens are pre-filled. */
const chars = new Uint8Array(36);
chars[8] = chars[13] = chars[18] = chars[23] = 45; // "-"

/** Writes `value` as 8 hex digits at `pos`, or 4 + 4 around a hyphen. */
function writeHex32(value: number, pos: number, split: boolean): void {
  const gap = split ? 1 : 0;
  for (let i = 7; i >= 0; i--) {
    chars[pos + i + (i >= 4 ? gap : 0)] = HEX_CODES[value & 0xf]!;
    value >>>= 4;
  }
}

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
 * Decodes a uuid58 string to an unsigned 128-bit integer, as four 32-bit
 * words (most significant first), checking length, then characters, then
 * range (specification, Section 4). The returned array is reused across
 * calls.
 *
 * Avoids BigInt: the first 4 digits, then 6 groups of 3 digits, are each
 * multiplied into the words in Number arithmetic (every intermediate stays
 * below 2^50). A carry out of the top word means the value exceeds 128 bits.
 */
export function decodeWords(uuid58: string): Uint32Array | Uuid58DecodeError {
  if (uuid58.length !== 22) {
    return new Uuid58DecodeError(
      `Expected Base58 string of length 22, but received string of length ${uuid58.length}: ${previewInput(uuid58)}`,
      "invalid_length",
    );
  }

  let w0 = 0;
  let w1 = 0;
  let w2 = 0;
  let w3 = 0;
  for (let start = 0; start < 22;) {
    const end = start === 0 ? 4 : start + 3;
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
    let cur = w3 * BASE58_CUBE + chunk;
    w3 = cur >>> 0;
    cur = w2 * BASE58_CUBE + (cur - w3) / WORD;
    w2 = cur >>> 0;
    cur = w1 * BASE58_CUBE + (cur - w2) / WORD;
    w1 = cur >>> 0;
    // w0 keeps any carry out of the top word. 58^19 < 2^128, so a carry can
    // only appear in the last group, after every character has been checked.
    w0 = w0 * BASE58_CUBE + (cur - w1) / WORD;
    start = end;
  }

  if (w0 >= WORD) {
    return new Uuid58DecodeError(
      `Decoded value exceeds 128 bits of UUID: ${previewInput(uuid58)}`,
      "overflow",
    );
  }
  words[0] = w0;
  words[1] = w1;
  words[2] = w2;
  words[3] = w3;
  return words;
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
  if (decoded instanceof Uuid58DecodeError) {
    return decoded;
  }

  writeHex32(decoded[0]!, 0, false);
  writeHex32(decoded[1]!, 9, true);
  writeHex32(decoded[2]!, 19, true);
  writeHex32(decoded[3]!, 28, false);
  const c = chars;
  // prettier-ignore
  return String.fromCharCode(
    c[0]!, c[1]!, c[2]!, c[3]!, c[4]!, c[5]!, c[6]!, c[7]!, c[8]!, c[9]!, c[10]!, c[11]!,
    c[12]!, c[13]!, c[14]!, c[15]!, c[16]!, c[17]!, c[18]!, c[19]!, c[20]!, c[21]!, c[22]!,
    c[23]!, c[24]!, c[25]!, c[26]!, c[27]!, c[28]!, c[29]!, c[30]!, c[31]!, c[32]!, c[33]!,
    c[34]!, c[35]!,
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
