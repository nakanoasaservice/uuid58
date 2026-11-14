import { UUID58_ALPHABET } from "./alphabet.ts";

const MAX_PREVIEW_LENGTH = 40;

/**
 * @internal
 * 2^32. Multiplying by it shifts a value left by one 32-bit word.
 */
export const WORD = 4294967296;

/**
 * @internal
 * 58^3. A remainder below it, shifted left by one 32-bit word, stays below
 * 2^50, so long division by it is exact in Number (double) arithmetic.
 */
export const BASE58_CUBE = 195112;

/** Character codes of the alphabet, indexed by digit value. */
const ALPHABET_CODES = new Uint8Array(58);
for (let i = 0; i < 58; i++) {
  ALPHABET_CODES[i] = UUID58_ALPHABET.charCodeAt(i);
}

/** Output buffer, filled from the last digit to the first. */
const digits = new Uint8Array(22);

/**
 * @internal
 * Encodes an unsigned 128-bit integer, given as four 32-bit words (most
 * significant first), as a 22-character Base58 string.
 *
 * Avoids BigInt: each round long-divides the four words by 58^3 in Number
 * arithmetic and emits three digits from the remainder. After 6 rounds (18
 * digits) the value is below 2^128 / 58^18 < 58^4, so it sits in the last
 * word and gives the first 4 digits directly.
 */
export function encodeWords(words: ArrayLike<number>): string {
  let w0 = words[0]!;
  let w1 = words[1]!;
  let w2 = words[2]!;
  let w3 = words[3]!;
  let pos = 21;
  for (let round = 0; round < 6; round++) {
    let quotient = Math.floor(w0 / BASE58_CUBE);
    let rem = w0 - quotient * BASE58_CUBE;
    w0 = quotient;
    let cur = rem * WORD + w1;
    quotient = Math.floor(cur / BASE58_CUBE);
    rem = cur - quotient * BASE58_CUBE;
    w1 = quotient;
    cur = rem * WORD + w2;
    quotient = Math.floor(cur / BASE58_CUBE);
    rem = cur - quotient * BASE58_CUBE;
    w2 = quotient;
    cur = rem * WORD + w3;
    quotient = Math.floor(cur / BASE58_CUBE);
    rem = cur - quotient * BASE58_CUBE;
    w3 = quotient;
    for (let n = 0; n < 3; n++) {
      const q = (rem / 58) >>> 0;
      digits[pos--] = ALPHABET_CODES[rem - q * 58]!;
      rem = q;
    }
  }
  for (let n = 0; n < 4; n++) {
    const q = (w3 / 58) >>> 0;
    digits[pos--] = ALPHABET_CODES[w3 - q * 58]!;
    w3 = q;
  }
  const d = digits;
  // prettier-ignore
  return String.fromCharCode(
    d[0]!, d[1]!, d[2]!, d[3]!, d[4]!, d[5]!, d[6]!, d[7]!, d[8]!, d[9]!, d[10]!, d[11]!,
    d[12]!, d[13]!, d[14]!, d[15]!, d[16]!, d[17]!, d[18]!, d[19]!, d[20]!, d[21]!,
  );
}

/**
 * @internal
 * Formats untrusted input for inclusion in an error message.
 *
 * The input is truncated so huge strings do not bloat error messages or logs,
 * and JSON-escaped so control characters (e.g. newlines) cannot forge log
 * lines.
 */
export function previewInput(input: string): string {
  return input.length > MAX_PREVIEW_LENGTH
    ? `${JSON.stringify(input.slice(0, MAX_PREVIEW_LENGTH))}... (${input.length} characters)`
    : JSON.stringify(input);
}
