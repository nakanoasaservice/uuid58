/**
 * The kind of an encoding or decoding error, as defined by the uuid58
 * specification (Section 7).
 *
 * - `"invalid_length"`: the input has the wrong length (a UUID string that is
 *   neither 32 nor 36 characters, a uuid58 string that is not 22 characters,
 *   or a byte array that is not 16 bytes long).
 * - `"invalid_character"`: the input has the right length but contains a
 *   character not allowed in its position.
 * - `"overflow"`: (decoding only) the uuid58 string is well formed, but its
 *   value is greater than 2^128 - 1.
 *
 * Inputs containing non-ASCII characters may report either
 * `"invalid_length"` or `"invalid_character"`.
 */
export type Uuid58ErrorKind =
  | "invalid_length"
  | "invalid_character"
  | "overflow";
