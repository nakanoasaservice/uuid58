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

/**
 * Error thrown when an invalid UUID string or byte array is provided for
 * encoding. Its {@link Uuid58EncodeError.kind | kind} tells why.
 */
export class Uuid58EncodeError extends Error {
  static {
    this.prototype.name = "Uuid58EncodeError";
  }

  /**
   * Why the input was rejected: `"invalid_length"` or `"invalid_character"`.
   */
  readonly kind: Exclude<Uuid58ErrorKind, "overflow">;

  constructor(message: string, kind: Exclude<Uuid58ErrorKind, "overflow">) {
    super(message);
    this.kind = kind;
  }
}

/**
 * Error thrown when an invalid uuid58 string is provided for decoding.
 * Its {@link Uuid58DecodeError.kind | kind} tells why.
 */
export class Uuid58DecodeError extends Error {
  static {
    this.prototype.name = "Uuid58DecodeError";
  }

  /**
   * Why the input was rejected: `"invalid_length"`, `"invalid_character"`,
   * or `"overflow"`.
   */
  readonly kind: Uuid58ErrorKind;

  constructor(message: string, kind: Uuid58ErrorKind) {
    super(message);
    this.kind = kind;
  }
}

const MAX_PREVIEW_LENGTH = 40;

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
