package io.github.nakanoasaservice.uuid58;

/**
 * Thrown when an input cannot be encoded to or decoded from uuid58.
 *
 * <p>{@link #getKind()} tells callers why the input was rejected, using the error kinds of the
 * uuid58 specification (Section 7). Error messages are not part of the specification and may
 * change.
 */
public final class Uuid58Exception extends IllegalArgumentException {
  private static final long serialVersionUID = 1L;

  /** The error kinds defined by the uuid58 specification, Section 7. */
  public enum Kind {
    /**
     * The input has the wrong length: a uuid58 string that is not 22 characters, a UUID string
     * that is neither 32 nor 36 characters, or a byte array that is not 16 bytes.
     */
    INVALID_LENGTH("invalid_length"),

    /**
     * The input has the right length but contains a character that is not allowed in its
     * position, including any non-ASCII character.
     */
    INVALID_CHARACTER("invalid_character"),

    /** The input is well formed but its value is outside {@code 0..2^128 - 1}. */
    OVERFLOW("overflow");

    private final String specName;

    Kind(String specName) {
      this.specName = specName;
    }

    /**
     * Returns the name the specification and the test vectors use for this kind, such as
     * {@code "invalid_length"}.
     *
     * @return the snake_case name of this kind
     */
    public String specName() {
      return specName;
    }
  }

  /** Why the input was rejected. */
  private final Kind kind;

  Uuid58Exception(Kind kind, String message) {
    super(message);
    this.kind = kind;
  }

  /**
   * Returns why the input was rejected.
   *
   * @return the error kind, never {@code null}
   */
  public Kind getKind() {
    return kind;
  }
}
