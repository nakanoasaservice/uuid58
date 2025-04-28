import { ALPHABET_LENGTH, BASE58_ALPHABET } from "./alphabet.ts";

/**
 * Error thrown when an invalid UUID string is provided for encoding.
 * This includes strings that don't match the standard UUID format (32 hexadecimal characters with optional hyphens).
 */
export class InvalidUuidError extends Error {
  static {
    this.prototype.name = "InvalidUuidError";
  }

  constructor(uuid: string) {
    super(`Invalid UUID format: ${uuid}`);
  }
}

/**
 * Converts a standard UUID string to a shortened Base58-encoded format.
 *
 * @param uuid - The UUID string to encode. Can be provided with or without hyphens
 *              (format: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" or "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx").
 *              The input is case-insensitive, so both uppercase and lowercase hexadecimal characters are accepted.
 * @returns A Base58-encoded string representation of the UUID
 * @throws {InvalidUuidError} If the input string is not a valid UUID format
 *
 * @example
 * ```typescript
 * // With hyphens
 * const base58 = encodeUuid58("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf"); // returns "XDY9dmBbcMBXqcRvYw8xJ2"
 * // Without hyphens
 * const base58 = encodeUuid58("f4b247fd1f8745d4aa061c6fc0a8dfaf"); // returns "XDY9dmBbcMBXqcRvYw8xJ2"
 * // Uppercase UUID is also accepted
 * const base58 = encodeUuid58("F4B247FD-1F87-45D4-AA06-1C6FC0A8DFAF"); // returns "XDY9dmBbcMBXqcRvYw8xJ2"
 * ```
 */
export function encodeUuid58(uuid: string): string {
  const hex = uuid.replace(/-/g, "").toLowerCase();
  if (!/^[0-9a-f]{32}$/.test(hex)) {
    throw new InvalidUuidError(uuid);
  }

  let num = BigInt("0x" + hex);
  let encoded = "";
  do {
    const rem = Number(num % ALPHABET_LENGTH);
    encoded = BASE58_ALPHABET[rem] + encoded;
    num /= ALPHABET_LENGTH;
  } while (num > 0n);

  return encoded;
}
