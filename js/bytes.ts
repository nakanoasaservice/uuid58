import { decodeUint128, Uuid58DecodeError } from "./decode.ts";
import { Uuid58EncodeError } from "./encode.ts";
import { encodeUint128 } from "./internal.ts";

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
  const view = new DataView(bytes.buffer, bytes.byteOffset, 16);
  return encodeUint128((view.getBigUint64(0) << 64n) | view.getBigUint64(8));
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
  const num = decodeUint128(uuid58);
  if (typeof num !== "bigint") {
    return num;
  }
  const bytes = new Uint8Array(16);
  const view = new DataView(bytes.buffer);
  view.setBigUint64(0, num >> 64n);
  view.setBigUint64(8, num & 0xffffffffffffffffn);
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
