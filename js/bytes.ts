import { decodeWords, Uuid58DecodeError } from "./decode.ts";
import { Uuid58EncodeError } from "./encode.ts";
import { encodeWords } from "./internal.ts";

/** Reused input for {@link encodeWords}; overwritten on every call. */
const words = new Uint32Array(4);

/**
 * Encodes 16 bytes, in big-endian (RFC 9562) order, as a 22-character uuid58
 * string, but instead of throwing an error for invalid input, it returns an
 * `Uuid58EncodeError` instance.
 *
 * @param bytes - The 16 bytes of the UUID
 * @returns A 22-character uuid58 string, or an `Uuid58EncodeError` (kind
 *   `"invalid_length"`) if `bytes` is not exactly 16 bytes long
 * @note This function does not throw; it returns the error object instead.
 *
 * @example
 * ```typescript
 * const bytes = new Uint8Array(16); // nil UUID
 * uuid58EncodeBytesSafe(bytes); // returns "1111111111111111111111"
 * ```
 */
export function uuid58EncodeBytesSafe(
  bytes: Uint8Array,
): string | Uuid58EncodeError {
  if (bytes.length !== 16) {
    return new Uuid58EncodeError(
      `Invalid byte length: expected 16 bytes, got ${bytes.length}`,
      "invalid_length",
    );
  }
  // Big-endian; storing into the Uint32Array makes the results unsigned.
  for (let i = 0; i < 4; i++) {
    const j = i * 4;
    words[i] =
      (bytes[j]! << 24) |
      (bytes[j + 1]! << 16) |
      (bytes[j + 2]! << 8) |
      bytes[j + 3]!;
  }
  return encodeWords(words);
}

/**
 * Encodes 16 bytes, in big-endian (RFC 9562) order, as a 22-character uuid58
 * string.
 *
 * @param bytes - The 16 bytes of the UUID
 * @returns A 22-character uuid58 string
 * @throws {Uuid58EncodeError} If `bytes` is not exactly 16 bytes long
 *
 * @example
 * ```typescript
 * uuid58EncodeBytes(new Uint8Array(16)); // returns "1111111111111111111111"
 * ```
 */
export function uuid58EncodeBytes(bytes: Uint8Array): string {
  const result = uuid58EncodeBytesSafe(bytes);
  if (result instanceof Uuid58EncodeError) {
    throw result;
  }
  return result;
}

/**
 * Decodes a uuid58 string to 16 bytes in big-endian (RFC 9562) order, but
 * instead of throwing an error for invalid input, it returns an
 * `Uuid58DecodeError` instance.
 *
 * @param uuid58 - The 22-character uuid58 string to decode
 * @returns A new 16-byte `Uint8Array`, or an `Uuid58DecodeError`
 * @note This function does not throw; it returns the error object instead.
 *
 * @example
 * ```typescript
 * uuid58DecodeBytesSafe("1111111111111111111111"); // returns Uint8Array(16) of zeros
 * ```
 */
export function uuid58DecodeBytesSafe(
  uuid58: string,
): Uint8Array | Uuid58DecodeError {
  const decoded = decodeWords(uuid58);
  if (decoded instanceof Uuid58DecodeError) {
    return decoded;
  }
  // Big-endian; the Uint8Array stores keep the low 8 bits of each shift.
  const bytes = new Uint8Array(16);
  for (let i = 0; i < 4; i++) {
    const word = decoded[i]!;
    bytes[i * 4] = word >>> 24;
    bytes[i * 4 + 1] = word >>> 16;
    bytes[i * 4 + 2] = word >>> 8;
    bytes[i * 4 + 3] = word;
  }
  return bytes;
}

/**
 * Decodes a uuid58 string to 16 bytes in big-endian (RFC 9562) order.
 *
 * @param uuid58 - The 22-character uuid58 string to decode
 * @returns A new 16-byte `Uint8Array`
 * @throws {Uuid58DecodeError} If the input is not a valid uuid58 string
 *
 * @example
 * ```typescript
 * const bytes = uuid58DecodeBytes("XDY9dmBbcMBXqcRvYw8xJ2");
 * ```
 */
export function uuid58DecodeBytes(uuid58: string): Uint8Array {
  const result = uuid58DecodeBytesSafe(uuid58);
  if (result instanceof Uuid58DecodeError) {
    throw result;
  }
  return result;
}
