package io.github.nakanoasaservice.uuid58;

import io.github.nakanoasaservice.uuid58.Uuid58Exception.Kind;
import java.math.BigInteger;
import java.util.UUID;

/**
 * Encodes UUIDs as fixed 22-character Base58 strings (uuid58), and decodes them back.
 *
 * <pre>{@code
 * Uuid58.encode("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf"); // "XDY9dmBbcMBXqcRvYw8xJ2"
 * Uuid58.decode("XDY9dmBbcMBXqcRvYw8xJ2");               // "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf"
 * }</pre>
 *
 * <p>This class implements the <a
 * href="https://github.com/nakanoasaservice/uuid58/blob/main/spec/SPEC.md">uuid58
 * specification</a>. Invalid input fails with {@link Uuid58Exception}, an unchecked exception
 * whose {@link Uuid58Exception#getKind() kind} is one of the specification's error kinds. Passing
 * {@code null} to any method except {@link #isValid(String)} throws {@link NullPointerException}.
 *
 * <p>All methods are thread-safe.
 */
public final class Uuid58 {
  /**
   * The Bitcoin Base58 alphabet. The character at index {@code i} is the digit with value {@code
   * i}.
   */
  public static final String ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";

  /** The length of every uuid58 string. */
  public static final int LENGTH = 22;

  /** The largest valid uuid58 string, the encoding of {@code ffffffff-ffff-ffff-ffff-ffffffffffff}. */
  public static final String MAX = "YcVfxkQb6JRzqk5kF2tNLv";

  private static final char[] DIGITS = ALPHABET.toCharArray();

  /** ASCII code to digit value; -1 for characters outside the alphabet. */
  private static final byte[] DIGIT_VALUES = new byte[128];

  private static final char[] HEX = "0123456789abcdef".toCharArray();

  /** 58^5 < 2^30, so (remainder << 32 | limb) and (limb * 58^5 + carry) fit in a long. */
  private static final long CHUNK = 58L * 58 * 58 * 58 * 58;

  private static final int CHUNK_DIGITS = 5;

  private static final long MASK32 = 0xffffffffL;

  private static final BigInteger MAX_VALUE = BigInteger.ONE.shiftLeft(128).subtract(BigInteger.ONE);

  static {
    java.util.Arrays.fill(DIGIT_VALUES, (byte) -1);
    for (int i = 0; i < DIGITS.length; i++) {
      DIGIT_VALUES[DIGITS[i]] = (byte) i;
    }
  }

  private Uuid58() {}

  // ---------------------------------------------------------------------------------------------
  // Encoding

  /**
   * Encodes a 128-bit value given as two halves.
   *
   * <p>The value is {@code msb} followed by {@code lsb}, each read as an unsigned 64-bit integer,
   * matching {@link UUID#getMostSignificantBits()} and {@link UUID#getLeastSignificantBits()}.
   * Never fails.
   *
   * @param msb the most significant 64 bits
   * @param lsb the least significant 64 bits
   * @return the 22-character uuid58 string
   */
  public static String encode(long msb, long lsb) {
    // Four 32-bit limbs, most significant first, each held in a long.
    long l0 = msb >>> 32;
    long l1 = msb & MASK32;
    long l2 = lsb >>> 32;
    long l3 = lsb & MASK32;

    char[] out = new char[LENGTH];
    int pos = LENGTH;
    // Four rounds of division by 58^5 produce the 20 least significant digits.
    for (int round = 0; round < 4; round++) {
      long r = l0 % CHUNK;
      l0 /= CHUNK;
      long t = (r << 32) | l1;
      l1 = t / CHUNK;
      r = t % CHUNK;
      t = (r << 32) | l2;
      l2 = t / CHUNK;
      r = t % CHUNK;
      t = (r << 32) | l3;
      l3 = t / CHUNK;
      r = t % CHUNK;
      for (int i = 0; i < CHUNK_DIGITS; i++) {
        out[--pos] = DIGITS[(int) (r % 58)];
        r /= 58;
      }
    }
    // What remains is below 2^128 / 58^20 < 58^2, so it fits in the lowest limb.
    out[--pos] = DIGITS[(int) (l3 % 58)];
    out[--pos] = DIGITS[(int) (l3 / 58)];
    return new String(out);
  }

  /**
   * Encodes a {@link UUID}. Never fails.
   *
   * @param uuid the UUID
   * @return the 22-character uuid58 string
   */
  public static String encode(UUID uuid) {
    return encode(uuid.getMostSignificantBits(), uuid.getLeastSignificantBits());
  }

  /**
   * Encodes 16 bytes read as an unsigned big-endian integer (RFC 9562 byte order for a UUID).
   *
   * @param bytes exactly 16 bytes; the array is not modified
   * @return the 22-character uuid58 string
   * @throws Uuid58Exception with {@link Kind#INVALID_LENGTH} if {@code bytes} is not 16 bytes long
   */
  public static String encode(byte[] bytes) {
    if (bytes.length != 16) {
      throw new Uuid58Exception(
          Kind.INVALID_LENGTH, "Expected 16 bytes, got " + bytes.length + " bytes");
    }
    return encode(readLong(bytes, 0), readLong(bytes, 8));
  }

  /**
   * Encodes an unsigned integer in the range {@code 0..2^128 - 1}.
   *
   * @param value the integer
   * @return the 22-character uuid58 string
   * @throws Uuid58Exception with {@link Kind#OVERFLOW} if {@code value} is negative or greater than
   *     {@code 2^128 - 1}
   */
  public static String encode(BigInteger value) {
    if (value.signum() < 0 || value.compareTo(MAX_VALUE) > 0) {
      throw new Uuid58Exception(Kind.OVERFLOW, "Integer is outside 0..2^128 - 1: " + value);
    }
    return encode(value.shiftRight(64).longValue(), value.longValue());
  }

  /**
   * Encodes a UUID string.
   *
   * <p>Accepts exactly two forms, in any mix of upper and lower case:
   *
   * <ul>
   *   <li>hyphenated, 36 characters: {@code f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf}
   *   <li>plain, 32 hexadecimal digits: {@code f4b247fd1f8745d4aa061c6fc0a8dfaf}
   * </ul>
   *
   * <p>Everything else is rejected, including braces, the {@code urn:uuid:} prefix, surrounding
   * whitespace, and hyphens in other positions. (Unlike {@link UUID#fromString(String)}, which
   * accepts shortened groups.)
   *
   * @param uuid the UUID string
   * @return the 22-character uuid58 string
   * @throws Uuid58Exception with {@link Kind#INVALID_LENGTH} if the string is neither 32 nor 36
   *     characters long, or {@link Kind#INVALID_CHARACTER} if it does not match the form for its
   *     length
   */
  public static String encode(String uuid) {
    int length = uuid.length();
    boolean hyphenated;
    if (length == 36) {
      hyphenated = true;
    } else if (length == 32) {
      hyphenated = false;
    } else {
      throw new Uuid58Exception(
          Kind.INVALID_LENGTH,
          "Expected a UUID string of 32 or 36 characters, got " + length + " characters");
    }

    long msb = 0;
    long lsb = 0;
    int nibbles = 0;
    for (int i = 0; i < length; i++) {
      char c = uuid.charAt(i);
      if (hyphenated && (i == 8 || i == 13 || i == 18 || i == 23)) {
        if (c != '-') {
          throw invalidCharacter("expected '-'", i);
        }
        continue;
      }
      int v = hexValue(c);
      if (v < 0) {
        throw invalidCharacter("expected a hexadecimal digit", i);
      }
      if (nibbles < 16) {
        msb = (msb << 4) | v;
      } else {
        lsb = (lsb << 4) | v;
      }
      nibbles++;
    }
    return encode(msb, lsb);
  }

  /**
   * Generates a random (version 4) UUID with {@link UUID#randomUUID()} and returns its uuid58
   * encoding.
   *
   * @return a new 22-character uuid58 string
   */
  public static String generate() {
    return encode(UUID.randomUUID());
  }

  // ---------------------------------------------------------------------------------------------
  // Decoding

  /**
   * Decodes a uuid58 string to a UUID string in lowercase hyphenated form, such as {@code
   * f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf}.
   *
   * @param uuid58 the uuid58 string
   * @return the UUID string
   * @throws Uuid58Exception if {@code uuid58} is not a valid uuid58 string (see {@link
   *     #decodeToBytes(String)})
   */
  public static String decode(String uuid58) {
    long[] v = parse(uuid58);
    char[] out = new char[36];
    int pos = 0;
    for (int n = 0; n < 32; n++) {
      if (n == 8 || n == 12 || n == 16 || n == 20) {
        out[pos++] = '-';
      }
      long half = n < 16 ? v[0] : v[1];
      out[pos++] = HEX[(int) (half >>> (60 - 4 * (n % 16))) & 0xf];
    }
    return new String(out);
  }

  /**
   * Decodes a uuid58 string to a {@link UUID}.
   *
   * @param uuid58 the uuid58 string
   * @return the UUID
   * @throws Uuid58Exception if {@code uuid58} is not a valid uuid58 string (see {@link
   *     #decodeToBytes(String)})
   */
  public static UUID decodeToUuid(String uuid58) {
    long[] v = parse(uuid58);
    return new UUID(v[0], v[1]);
  }

  /**
   * Decodes a uuid58 string to 16 bytes in big-endian order (RFC 9562 byte order for a UUID).
   *
   * @param uuid58 the uuid58 string
   * @return a new 16-byte array
   * @throws Uuid58Exception with {@link Kind#INVALID_LENGTH} if {@code uuid58} is not 22
   *     characters long, {@link Kind#INVALID_CHARACTER} if it contains a character outside {@link
   *     #ALPHABET}, or {@link Kind#OVERFLOW} if its value is greater than {@code 2^128 - 1} (the
   *     string is greater than {@link #MAX})
   */
  public static byte[] decodeToBytes(String uuid58) {
    long[] v = parse(uuid58);
    byte[] out = new byte[16];
    for (int i = 0; i < 8; i++) {
      out[i] = (byte) (v[0] >>> (56 - 8 * i));
      out[8 + i] = (byte) (v[1] >>> (56 - 8 * i));
    }
    return out;
  }

  /**
   * Returns whether {@code uuid58} is a valid uuid58 string, that is, whether {@link
   * #decode(String)} would succeed.
   *
   * @param uuid58 the string to check; may be {@code null}
   * @return {@code true} if decoding would succeed; {@code false} otherwise, including for {@code
   *     null}
   */
  public static boolean isValid(String uuid58) {
    if (uuid58 == null || uuid58.length() != LENGTH) {
      return false;
    }
    for (int i = 0; i < LENGTH; i++) {
      if (digitValue(uuid58.charAt(i)) < 0) {
        return false;
      }
    }
    return uuid58.compareTo(MAX) <= 0;
  }

  // ---------------------------------------------------------------------------------------------
  // Internals

  /** Decodes to {msb, lsb}, performing the checks of SPEC.md Section 4 in order. */
  private static long[] parse(String s) {
    int length = s.length();
    if (length != LENGTH) {
      throw new Uuid58Exception(
          Kind.INVALID_LENGTH,
          "Expected a uuid58 string of " + LENGTH + " characters, got " + length + " characters");
    }
    for (int i = 0; i < LENGTH; i++) {
      if (digitValue(s.charAt(i)) < 0) {
        throw invalidCharacter("expected a Base58 character", i);
      }
    }
    // All inputs here are 22 ASCII characters, so String.compareTo is the ASCII order of
    // SPEC.md Section 3.2, and the value exceeds 2^128 - 1 exactly when the string exceeds MAX.
    if (s.compareTo(MAX) > 0) {
      throw new Uuid58Exception(
          Kind.OVERFLOW, "uuid58 string is greater than " + MAX + " (the value exceeds 2^128 - 1)");
    }

    // Accumulate two leading digits, then four chunks of five, into 32-bit limbs.
    long l0 = 0;
    long l1 = 0;
    long l2 = 0;
    long l3 = digitValue(s.charAt(0)) * 58L + digitValue(s.charAt(1));
    for (int start = 2; start < LENGTH; start += CHUNK_DIGITS) {
      long chunk = 0;
      for (int i = start; i < start + CHUNK_DIGITS; i++) {
        chunk = chunk * 58 + digitValue(s.charAt(i));
      }
      long t = l3 * CHUNK + chunk;
      l3 = t & MASK32;
      t = l2 * CHUNK + (t >>> 32);
      l2 = t & MASK32;
      t = l1 * CHUNK + (t >>> 32);
      l1 = t & MASK32;
      t = l0 * CHUNK + (t >>> 32);
      l0 = t & MASK32;
      // The range check above guarantees nothing is carried out of l0.
    }
    return new long[] {(l0 << 32) | l1, (l2 << 32) | l3};
  }

  /**
   * Returns the digit value of {@code c}, or -1. Non-ASCII characters, including unpaired
   * surrogates, are never digits (SPEC.md Section 4.1).
   */
  private static int digitValue(char c) {
    return c < 128 ? DIGIT_VALUES[c] : -1;
  }

  /** ASCII-only hexadecimal digit value, or -1. Deliberately not {@link Character#digit}. */
  private static int hexValue(char c) {
    if (c >= '0' && c <= '9') {
      return c - '0';
    }
    if (c >= 'a' && c <= 'f') {
      return c - 'a' + 10;
    }
    if (c >= 'A' && c <= 'F') {
      return c - 'A' + 10;
    }
    return -1;
  }

  private static long readLong(byte[] b, int offset) {
    long v = 0;
    for (int i = offset; i < offset + 8; i++) {
      v = (v << 8) | (b[i] & 0xff);
    }
    return v;
  }

  private static Uuid58Exception invalidCharacter(String expected, int index) {
    return new Uuid58Exception(
        Kind.INVALID_CHARACTER, "Invalid character at index " + index + ": " + expected);
  }
}
