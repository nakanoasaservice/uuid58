import { ALPHABET_LENGTH, BASE58_ALPHABET } from "./alphabet.ts";

/**
 * Error thrown when an invalid UUID string is provided for encoding.
 * This includes strings that don't match the standard UUID format (32 hexadecimal characters with optional hyphens).
 */
export class Uuid58EncodeError extends Error {
  static {
    this.prototype.name = "Uuid58EncodeError";
  }
}

/**
 * Converts a standard UUID string to a Base58-encoded format, but instead of
 * throwing an error for invalid input, it returns an `Uuid58EncodeError` instance.
 *
 * @param uuid - The UUID string to encode (with or without hyphens)
 * @returns A Base58-encoded string, or an `Uuid58EncodeError` if the input is
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
 * const error = uuid58EncodeSafe("invalid"); // returns Uuid58EncodeError
 * ```
 */
export function uuid58EncodeSafe(uuid: string): string | Uuid58EncodeError {
  const hex = uuid.replaceAll("-", "");
  if (hex.length !== 32) {
    return new Uuid58EncodeError(
      `Invalid UUID length: expected 32 characters (excluding hyphens), got ${hex.length} characters in "${uuid}"`,
    );
  }

  let num;
  try {
    num = BigInt("0x" + hex);
  } catch {
    return new Uuid58EncodeError(
      `Invalid UUID format: "${uuid}" contains non-hexadecimal characters`,
    );
  }

  let encoded = "";
  do {
    encoded = BASE58_ALPHABET[Number(num % ALPHABET_LENGTH)] + encoded;
    num /= ALPHABET_LENGTH;
  } while (num > 0n);

  return encoded;
}

/**
 * Converts a standard UUID string to a shortened Base58-encoded format.
 *
 * @param uuid - The UUID string to encode. Can be provided with or without hyphens
 *              (format: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" or "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx").
 *              The input is case-insensitive, so both uppercase and lowercase hexadecimal characters are accepted.
 * @returns A Base58-encoded string representation of the UUID
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
