package io.github.nakanoasaservice.uuid58;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import io.github.nakanoasaservice.uuid58.Uuid58Exception.Kind;
import java.math.BigInteger;
import java.util.Arrays;
import java.util.Random;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.function.Executable;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

/** Cases that spec/vectors.json cannot express, plus Java-specific API behavior. */
class Uuid58Test {
  private static final String UUID = "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf";
  private static final String UUID58 = "XDY9dmBbcMBXqcRvYw8xJ2";

  private static Kind kindOf(Executable call) {
    return assertThrows(Uuid58Exception.class, call).getKind();
  }

  private static void assertNonAsciiRejected(Executable call) {
    Kind kind = kindOf(call);
    assertTrue(
        kind == Kind.INVALID_LENGTH || kind == Kind.INVALID_CHARACTER, "unexpected kind " + kind);
  }

  private static String replaceAt(String s, int index, String replacement) {
    return s.substring(0, index) + replacement + s.substring(index + 1);
  }

  // SPEC.md Section 4.1: a Java String can hold unpaired surrogates, which JSON cannot.

  @ParameterizedTest
  @ValueSource(chars = {'\uD800', '\uDBFF', '\uDC00', '\uDFFF'})
  void decodeRejectsLoneSurrogate(char surrogate) {
    String s = String.valueOf(surrogate);
    // 22 UTF-16 code units, one of them a lone surrogate.
    for (int i : new int[] {0, 10, 21}) {
      String input = replaceAt(UUID58, i, s);
      assertEquals(22, input.length());
      assertEquals(Kind.INVALID_CHARACTER, kindOf(() -> Uuid58.decode(input)));
      assertFalse(Uuid58.isValid(input));
    }
    // A lone surrogate in an otherwise too short or too long input.
    assertNonAsciiRejected(() -> Uuid58.decode(UUID58.substring(1) + s + s));
    assertNonAsciiRejected(() -> Uuid58.decode(UUID58.substring(1)));
    assertNonAsciiRejected(() -> Uuid58.decode(s));
  }

  @Test
  void decodeRejectsReversedSurrogatePair() {
    String input = UUID58.substring(0, 20) + "\uDE00\uD83D";
    assertEquals(Kind.INVALID_CHARACTER, kindOf(() -> Uuid58.decodeToBytes(input)));
  }

  @ParameterizedTest
  @ValueSource(chars = {'\uD800', '\uDFFF'})
  void encodeRejectsLoneSurrogate(char surrogate) {
    String s = String.valueOf(surrogate);
    assertEquals(Kind.INVALID_CHARACTER, kindOf(() -> Uuid58.encode(replaceAt(UUID, 0, s))));
    assertEquals(Kind.INVALID_CHARACTER, kindOf(() -> Uuid58.encode(replaceAt(UUID, 8, s))));
    String plain = UUID.replace("-", "");
    assertEquals(Kind.INVALID_CHARACTER, kindOf(() -> Uuid58.encode(replaceAt(plain, 31, s))));
  }

  // SPEC.md Section 4.1: no Unicode-aware digit classification.

  @ParameterizedTest
  @ValueSource(
      strings = {
        "０", // FULLWIDTH DIGIT ZERO, Character.digit(c, 16) == 0
        "Ａ", // FULLWIDTH LATIN CAPITAL LETTER A, Character.digit(c, 16) == 10
        "٠", // ARABIC-INDIC DIGIT ZERO, Character.isDigit
        "०", // DEVANAGARI DIGIT ZERO
      })
  void encodeRejectsUnicodeDigits(String digit) {
    assertEquals(Kind.INVALID_CHARACTER, kindOf(() -> Uuid58.encode(replaceAt(UUID, 0, digit))));
  }

  @Test
  void encodeRejectsWhatUuidFromStringAccepts() {
    // UUID.fromString accepts this (shortened groups) and returns 1-2-3-4-5.
    assertEquals(Kind.INVALID_LENGTH, kindOf(() -> Uuid58.encode("1-2-3-4-5")));
    // Hyphens in the wrong position, right length.
    assertEquals(
        Kind.INVALID_CHARACTER, kindOf(() -> Uuid58.encode("f4b247f-d1f87-45d4-aa06-1c6fc0a8dfaf")));
    assertEquals(
        Kind.INVALID_CHARACTER, kindOf(() -> Uuid58.encode("+4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf")));
  }

  // API behavior.

  @Test
  void example() {
    assertEquals(UUID58, Uuid58.encode(UUID));
    assertEquals(UUID58, Uuid58.encode(UUID.toUpperCase()));
    assertEquals(UUID58, Uuid58.encode(UUID.replace("-", "")));
    assertEquals(UUID58, Uuid58.encode(java.util.UUID.fromString(UUID)));
    assertEquals(UUID, Uuid58.decode(UUID58));
    assertEquals(java.util.UUID.fromString(UUID), Uuid58.decodeToUuid(UUID58));
    assertTrue(Uuid58.isValid(UUID58));
  }

  @Test
  void constants() {
    assertEquals(58, Uuid58.ALPHABET.length());
    assertEquals(Uuid58.LENGTH, Uuid58.MAX.length());
    assertEquals(Uuid58.MAX, Uuid58.encode(-1L, -1L));
    assertEquals("1111111111111111111111", Uuid58.encode(0L, 0L));
  }

  @Test
  void kindSpecNames() {
    assertEquals("invalid_length", Kind.INVALID_LENGTH.specName());
    assertEquals("invalid_character", Kind.INVALID_CHARACTER.specName());
    assertEquals("overflow", Kind.OVERFLOW.specName());
  }

  @Test
  void exceptionIsIllegalArgumentException() {
    IllegalArgumentException e =
        assertThrows(IllegalArgumentException.class, () -> Uuid58.decode("nope"));
    assertTrue(e instanceof Uuid58Exception);
  }

  @Test
  void nullHandling() {
    assertFalse(Uuid58.isValid(null));
    assertThrows(NullPointerException.class, () -> Uuid58.encode((String) null));
    assertThrows(NullPointerException.class, () -> Uuid58.encode((UUID) null));
    assertThrows(NullPointerException.class, () -> Uuid58.encode((byte[]) null));
    assertThrows(NullPointerException.class, () -> Uuid58.encode((BigInteger) null));
    assertThrows(NullPointerException.class, () -> Uuid58.decode(null));
  }

  @Test
  void encodeDoesNotModifyInputBytes() {
    byte[] bytes = new byte[16];
    Arrays.fill(bytes, (byte) 0xab);
    byte[] copy = bytes.clone();
    Uuid58.encode(bytes);
    assertArrayEquals(copy, bytes);
  }

  @Test
  void generate() {
    String id = Uuid58.generate();
    assertTrue(Uuid58.isValid(id));
    assertEquals(4, Uuid58.decodeToUuid(id).version());
  }

  /** Random values against a BigInteger reference, plus the ordering property (SPEC.md 3.2). */
  @Test
  void randomValuesMatchReferenceAndOrder() {
    Random random = new Random(58);
    BigInteger base = BigInteger.valueOf(58);
    for (int n = 0; n < 20_000; n++) {
      // Vary the magnitude so that short values (many leading '1's) are covered.
      BigInteger v = new BigInteger(random.nextInt(129), random);
      StringBuilder expected = new StringBuilder();
      BigInteger rest = v;
      for (int i = 0; i < 22; i++) {
        BigInteger[] qr = rest.divideAndRemainder(base);
        expected.append(Uuid58.ALPHABET.charAt(qr[1].intValue()));
        rest = qr[0];
      }
      String encoded = Uuid58.encode(v);
      assertEquals(expected.reverse().toString(), encoded);
      assertEquals(v, new BigInteger(1, Uuid58.decodeToBytes(encoded)));

      BigInteger w = new BigInteger(random.nextInt(129), random);
      assertEquals(
          Integer.signum(v.compareTo(w)), Integer.signum(encoded.compareTo(Uuid58.encode(w))));
    }
  }
}
