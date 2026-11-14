import { encodeWords } from "./internal.ts";

// Reused across calls to avoid allocating a typed array per ID. It is
// overwritten with fresh random values on every call.
const random = new Uint32Array(4);

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
  // Words are most significant first; the version is in word 1 and the
  // variant in word 2.
  random[1] = (random[1]! & 0xffff0fff) | 0x4000;
  random[2] = (random[2]! & 0x3fffffff) | 0x80000000;

  return encodeWords(random);
}
