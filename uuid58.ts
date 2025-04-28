import { encodeUuid58 } from "./encode.ts";

/**
 * Generates a new Base58-encoded UUID.
 *
 * This function combines the standard UUID generation (using crypto.randomUUID())
 * with Base58 encoding to create a shorter, URL-safe identifier.
 *
 * @returns A Base58-encoded string representing a newly generated UUID
 *
 * @example
 * ```typescript
 * const id = uuid58(); // returns something like "XDY9dmBbcMBXqcRvYw8xJ2"
 * ```
 */
export function uuid58(): string {
  return encodeUuid58(crypto.randomUUID());
}
