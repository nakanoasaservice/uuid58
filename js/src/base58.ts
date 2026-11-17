/**
 * The core conversion between an unsigned 128-bit integer, held as four
 * 32-bit words (most significant first), and its 22-character Base58 form.
 *
 * Both directions avoid BigInt and work in Number (double) arithmetic, three
 * Base58 digits (one division or multiplication by 58^3) at a time.
 *
 * @module
 */
import { UUID58_ALPHABET } from "./alphabet.ts";
import { Uuid58DecodeError } from "./errors.ts";

/** 2^32. Multiplying by it shifts a value left by one 32-bit word. */
const WORD = 4294967296;

/**
 * 58^3. A remainder below it, shifted left by one 32-bit word, stays below
 * 2^50, so long division by it is exact in Number (double) arithmetic.
 */
const BASE58_CUBE = 195112;

// ---------------------------------------------------------------------------
// Encoding: words -> Base58
// ---------------------------------------------------------------------------

/** Character codes of the alphabet, indexed by digit value. */
const ALPHABET_CODES = new Uint8Array(58);
for (let i = 0; i < 58; i++) {
  ALPHABET_CODES[i] = UUID58_ALPHABET.charCodeAt(i);
}

/** Output buffer, filled from the last digit to the first. */
const digits = new Uint8Array(22);

/**
 * Writes the low `count` Base58 digits of `value` into `digits`, ending at
 * `pos`, and returns the position before them.
 */
function writeDigits(value: number, count: number, pos: number): number {
  for (let n = 0; n < count; n++) {
    const quotient = (value / 58) >>> 0;
    digits[pos--] = ALPHABET_CODES[value - quotient * 58]!;
    value = quotient;
  }
  return pos;
}

/**
 * @internal
 * Encodes an unsigned 128-bit integer, given as four 32-bit words (most
 * significant first), as a 22-character Base58 string.
 *
 * Each round long-divides the four words by 58^3 and emits three digits from
 * the remainder. After 6 rounds (18 digits) the value is below
 * 2^128 / 58^18 < 58^4, so it sits in the last word and gives the first 4
 * digits directly.
 */
export function encodeWords(words: ArrayLike<number>): string {
  let w0 = words[0]!;
  let w1 = words[1]!;
  let w2 = words[2]!;
  let w3 = words[3]!;
  let pos = 21;
  for (let round = 0; round < 6; round++) {
    // Long division by 58^3, most significant word first.
    let cur = w0;
    w0 = Math.floor(cur / BASE58_CUBE);
    let rem = cur - w0 * BASE58_CUBE;
    cur = rem * WORD + w1;
    w1 = Math.floor(cur / BASE58_CUBE);
    rem = cur - w1 * BASE58_CUBE;
    cur = rem * WORD + w2;
    w2 = Math.floor(cur / BASE58_CUBE);
    rem = cur - w2 * BASE58_CUBE;
    cur = rem * WORD + w3;
    w3 = Math.floor(cur / BASE58_CUBE);
    rem = cur - w3 * BASE58_CUBE;
    pos = writeDigits(rem, 3, pos);
  }
  writeDigits(w3, 4, pos);

  const d = digits;
  // prettier-ignore
  return String.fromCharCode(
    d[0]!, d[1]!, d[2]!, d[3]!, d[4]!, d[5]!, d[6]!, d[7]!, d[8]!, d[9]!, d[10]!, d[11]!,
    d[12]!, d[13]!, d[14]!, d[15]!, d[16]!, d[17]!, d[18]!, d[19]!, d[20]!, d[21]!,
  );
}

// ---------------------------------------------------------------------------
// Decoding: Base58 -> words
// ---------------------------------------------------------------------------

// Lookup table from ASCII char code to alphabet index (-1 = not in alphabet).
const BASE58_INDEX = new Int8Array(128).fill(-1);
for (let i = 0; i < UUID58_ALPHABET.length; i++) {
  BASE58_INDEX[UUID58_ALPHABET.charCodeAt(i)] = i;
}

/** Reused output of {@link decodeWords}; overwritten on every call. */
const words = new Uint32Array(4);

/** Alphabet index of the character at `i`, or -1 if it is not in it. */
function digitAt(uuid58: string, i: number): number {
  const code = uuid58.charCodeAt(i);
  return code < 128 ? BASE58_INDEX[code]! : -1;
}

/**
 * Value of the `count` Base58 digits of `uuid58` from `start`, or -1 if any
 * of them is not in the alphabet.
 */
function readDigits(uuid58: string, start: number, count: number): number {
  let value = 0;
  for (let i = start; i < start + count; i++) {
    const digit = digitAt(uuid58, i);
    if (digit < 0) {
      return -1;
    }
    value = value * 58 + digit;
  }
  return value;
}

/** The error for the first character of `uuid58` not in the alphabet. */
function invalidCharacterError(uuid58: string): Uuid58DecodeError {
  let i = 0;
  while (digitAt(uuid58, i) >= 0) {
    i++;
  }
  return new Uuid58DecodeError(
    `Invalid Base58 character at index ${i}`,
    "invalid_character",
  );
}

/**
 * @internal
 * Decodes a uuid58 string to an unsigned 128-bit integer, as four 32-bit
 * words (most significant first), checking length, then characters, then
 * range (specification, Section 4). The returned array is reused across
 * calls.
 *
 * The first 4 digits, then 6 groups of 3 digits, are multiplied into the
 * words (every intermediate stays below 2^50). A carry out of the top word
 * means the value exceeds 128 bits.
 */
export function decodeWords(uuid58: string): Uint32Array | Uuid58DecodeError {
  if (uuid58.length !== 22) {
    return new Uuid58DecodeError(
      `Expected Base58 string of length 22, but received string of length ${uuid58.length}`,
      "invalid_length",
    );
  }

  // The first 4 digits fit in the low word (58^4 < 2^32).
  let w0 = 0;
  let w1 = 0;
  let w2 = 0;
  let w3 = readDigits(uuid58, 0, 4);
  if (w3 < 0) {
    return invalidCharacterError(uuid58);
  }
  for (let start = 4; start < 22; start += 3) {
    const chunk = readDigits(uuid58, start, 3);
    if (chunk < 0) {
      return invalidCharacterError(uuid58);
    }
    // Multiply the words by 58^3 and add the chunk, carrying upward.
    let cur = w3 * BASE58_CUBE + chunk;
    w3 = cur >>> 0;
    cur = w2 * BASE58_CUBE + (cur - w3) / WORD;
    w2 = cur >>> 0;
    cur = w1 * BASE58_CUBE + (cur - w2) / WORD;
    w1 = cur >>> 0;
    // w0 keeps any carry out of the top word. 58^19 < 2^128, so a carry can
    // only appear in the last group, after every character has been checked.
    w0 = w0 * BASE58_CUBE + (cur - w1) / WORD;
  }

  if (w0 >= WORD) {
    return new Uuid58DecodeError(
      "Decoded value exceeds 128 bits of UUID",
      "overflow",
    );
  }
  words[0] = w0;
  words[1] = w1;
  words[2] = w2;
  words[3] = w3;
  return words;
}
