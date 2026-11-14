import { encodeUint128 } from "./internal.ts";

// Reused across calls to avoid allocating a typed array per ID. It is
// overwritten with fresh random values on every call.
const random = new BigUint64Array(2);

/**
 * Generates a new Base58-encoded UUID (always 22 characters).
 *
 * This function combines the standard UUID generation (using crypto.getRandomValues())
 * with Base58 encoding to create a shorter, URL-safe identifier.
 *
 * @returns A 22-character Base58-encoded string representing a newly generated UUID
 *
 * @example
 * ```typescript
 * const id = uuid58(); // returns a 22-character string like "XDY9dmBbcMBXqcRvYw8xJ2"
 * ```
 */
export function uuid58(): string {
  crypto.getRandomValues(random);

  // UUID v4: version nibble = 4, variant bits = 10.
  const high = (random[0]! & 0xffffffffffff0fffn) | 0x0000000000004000n;
  const low = (random[1]! & 0x3fffffffffffffffn) | 0x8000000000000000n;

  return encodeUint128((high << 64n) | low);
}
