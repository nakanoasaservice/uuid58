/**
 * Conversion between a UUID string (specification, Section 5.1) and an
 * unsigned 128-bit integer held as four 32-bit words (most significant first).
 *
 * @module
 */
import { previewInput, Uuid58EncodeError } from "./errors.ts";

// ---------------------------------------------------------------------------
// Parsing: UUID string -> words
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Formatting: words -> UUID string
// ---------------------------------------------------------------------------

// Character codes of the lowercase hex digits.
const HEX_CODES = new Uint8Array(16);
for (let i = 0; i < 16; i++) {
  HEX_CODES[i] = "0123456789abcdef".charCodeAt(i);
}

/** Output buffer for {@link formatUuidString}; hyphens are pre-filled. */
const chars = new Uint8Array(36);
chars[8] = chars[13] = chars[18] = chars[23] = 45; // "-"

/** Writes `value` (16 bits) as 4 hex digits into `chars` at `pos`. */
function writeHex16(value: number, pos: number): void {
  for (let i = 3; i >= 0; i--) {
    chars[pos + i] = HEX_CODES[value & 0xf]!;
    value >>>= 4;
  }
}

/**
 * @internal
 * Formats an unsigned 128-bit integer, given as four 32-bit words (most
 * significant first), as a lowercase hyphenated UUID string.
 */
export function formatUuidString(words: ArrayLike<number>): string {
  const w0 = words[0]!;
  const w1 = words[1]!;
  const w2 = words[2]!;
  const w3 = words[3]!;
  writeHex16(w0 >>> 16, 0);
  writeHex16(w0 & 0xffff, 4);
  writeHex16(w1 >>> 16, 9);
  writeHex16(w1 & 0xffff, 14);
  writeHex16(w2 >>> 16, 19);
  writeHex16(w2 & 0xffff, 24);
  writeHex16(w3 >>> 16, 28);
  writeHex16(w3 & 0xffff, 32);
  const c = chars;
  // prettier-ignore
  return String.fromCharCode(
    c[0]!, c[1]!, c[2]!, c[3]!, c[4]!, c[5]!, c[6]!, c[7]!, c[8]!, c[9]!, c[10]!, c[11]!,
    c[12]!, c[13]!, c[14]!, c[15]!, c[16]!, c[17]!, c[18]!, c[19]!, c[20]!, c[21]!, c[22]!,
    c[23]!, c[24]!, c[25]!, c[26]!, c[27]!, c[28]!, c[29]!, c[30]!, c[31]!, c[32]!, c[33]!,
    c[34]!, c[35]!,
  );
}
