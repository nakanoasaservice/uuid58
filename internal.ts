import { UUID58_ALPHABET } from "./alphabet.ts";

const MAX_PREVIEW_LENGTH = 40;

/**
 * @internal
 * 58^9, the largest power of 58 below 2^53. A 9-digit Base58 chunk therefore
 * fits in a Number, so most digit arithmetic can avoid slow BigInt division.
 */
export const BASE58_CHUNK: bigint = 7427658739644928n;

/** Appends `digits` Base58 digits of `value` (most significant first). */
function appendDigits(out: string, value: number, digits: number): string {
  let chunk = "";
  for (let i = 0; i < digits; i++) {
    const quotient = Math.floor(value / 58);
    chunk = UUID58_ALPHABET[value - quotient * 58]! + chunk;
    value = quotient;
  }
  return out + chunk;
}

/**
 * @internal
 * Encodes an unsigned 128-bit integer as a 22-character Base58 string.
 *
 * The value is split into 4 + 9 + 9 digit chunks with two BigInt divisions,
 * instead of 22 BigInt divisions (one per digit).
 */
export function encodeUint128(num: bigint): string {
  const low = Number(num % BASE58_CHUNK);
  num /= BASE58_CHUNK;
  const mid = Number(num % BASE58_CHUNK);
  // 58^22 > 2^128, so the remaining high part is always below 58^4.
  const high = Number(num / BASE58_CHUNK);
  return appendDigits(appendDigits(appendDigits("", high, 4), mid, 9), low, 9);
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
