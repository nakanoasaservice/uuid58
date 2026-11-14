package io.github.nakanoasaservice.uuid58;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.Reader;
import java.math.BigInteger;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Stream;
import org.junit.jupiter.api.DynamicTest;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.TestFactory;
import org.junit.jupiter.api.function.Executable;

/** Runs every applicable case of spec/vectors.json (SPEC.md Section 8). */
class ConformanceTest {
  private static final JsonObject VECTORS = load();

  private static JsonObject load() {
    String path = System.getProperty("uuid58.vectors", "../spec/vectors.json");
    Path file = Paths.get(path);
    try (Reader reader =
        new InputStreamReader(Files.newInputStream(file), StandardCharsets.UTF_8)) {
      return JsonParser.parseReader(reader).getAsJsonObject();
    } catch (IOException e) {
      throw new IllegalStateException("Cannot read test vectors at " + file.toAbsolutePath(), e);
    }
  }

  private static Stream<JsonObject> cases(JsonArray array) {
    List<JsonObject> list = new ArrayList<>();
    for (JsonElement e : array) {
      list.add(e.getAsJsonObject());
    }
    return list.stream();
  }

  private static Stream<JsonObject> section(String name) {
    return cases(VECTORS.getAsJsonArray(name));
  }

  private static Stream<JsonObject> section(String parent, String name) {
    return cases(VECTORS.getAsJsonObject(parent).getAsJsonArray(name));
  }

  private static String str(JsonObject o, String key) {
    return o.get(key).getAsString();
  }

  private static DynamicTest test(JsonObject c, Executable body) {
    return DynamicTest.dynamicTest(str(c, "description"), body);
  }

  private static byte[] hexToBytes(String hex) {
    byte[] out = new byte[hex.length() / 2];
    for (int i = 0; i < out.length; i++) {
      out[i] = (byte) Integer.parseInt(hex.substring(2 * i, 2 * i + 2), 16);
    }
    return out;
  }

  /** Asserts that {@code call} fails with one of the kinds listed in the case's "errors". */
  private static void assertFailsWithListedKind(JsonObject c, Executable call) {
    Uuid58Exception e = assertThrows(Uuid58Exception.class, call);
    List<String> allowed = new ArrayList<>();
    for (JsonElement k : c.getAsJsonArray("errors")) {
      allowed.add(k.getAsString());
    }
    assertTrue(
        allowed.contains(e.getKind().specName()),
        () -> "kind " + e.getKind().specName() + " not in " + allowed);
  }

  @Test
  void alphabetMatches() {
    assertEquals(str(VECTORS, "alphabet"), Uuid58.ALPHABET);
  }

  @Test
  void specVersionIsSupported() {
    assertTrue(str(VECTORS, "spec_version").startsWith("1."));
  }

  @TestFactory
  Stream<DynamicTest> roundtripEncodeString() {
    return section("roundtrip")
        .map(c -> test(c, () -> assertEquals(str(c, "uuid58"), Uuid58.encode(str(c, "uuid")))));
  }

  @TestFactory
  Stream<DynamicTest> roundtripDecodeString() {
    return section("roundtrip")
        .map(c -> test(c, () -> assertEquals(str(c, "uuid"), Uuid58.decode(str(c, "uuid58")))));
  }

  @TestFactory
  Stream<DynamicTest> roundtripBytes() {
    return section("roundtrip")
        .map(
            c ->
                test(
                    c,
                    () -> {
                      byte[] bytes = hexToBytes(str(c, "uuid").replace("-", ""));
                      assertEquals(str(c, "uuid58"), Uuid58.encode(bytes));
                      assertArrayEquals(bytes, Uuid58.decodeToBytes(str(c, "uuid58")));
                    }));
  }

  @TestFactory
  Stream<DynamicTest> roundtripBigInteger() {
    return section("roundtrip")
        .map(
            c ->
                test(
                    c,
                    () -> {
                      BigInteger v = new BigInteger(str(c, "uuid").replace("-", ""), 16);
                      assertEquals(str(c, "uuid58"), Uuid58.encode(v));
                    }));
  }

  /**
   * java.util.UUID, compared against the vector's text and bytes rather than only round-tripped
   * (SPEC.md Section 8.1), so a byte-order mistake cannot hide.
   */
  @TestFactory
  Stream<DynamicTest> roundtripJavaUtilUuid() {
    return section("roundtrip")
        .map(
            c ->
                test(
                    c,
                    () -> {
                      String hex = str(c, "uuid").replace("-", "");
                      long msb = Long.parseUnsignedLong(hex.substring(0, 16), 16);
                      long lsb = Long.parseUnsignedLong(hex.substring(16), 16);

                      UUID decoded = Uuid58.decodeToUuid(str(c, "uuid58"));
                      assertEquals(str(c, "uuid"), decoded.toString());
                      assertEquals(msb, decoded.getMostSignificantBits());
                      assertEquals(lsb, decoded.getLeastSignificantBits());

                      assertEquals(str(c, "uuid58"), Uuid58.encode(new UUID(msb, lsb)));
                      assertEquals(str(c, "uuid58"), Uuid58.encode(msb, lsb));
                    }));
  }

  @TestFactory
  Stream<DynamicTest> roundtripIsValid() {
    return section("roundtrip").map(c -> test(c, () -> assertTrue(Uuid58.isValid(str(c, "uuid58")))));
  }

  @TestFactory
  Stream<DynamicTest> encodeValid() {
    return section("encode", "valid")
        .map(c -> test(c, () -> assertEquals(str(c, "output"), Uuid58.encode(str(c, "input")))));
  }

  /** Includes the "lenient" cases, which JavaScript 1.x accepts but this implementation must not. */
  @TestFactory
  Stream<DynamicTest> encodeInvalid() {
    return section("encode", "invalid")
        .map(c -> test(c, () -> assertFailsWithListedKind(c, () -> Uuid58.encode(str(c, "input")))));
  }

  @TestFactory
  Stream<DynamicTest> encodeInvalidBytes() {
    return section("encode", "invalid_bytes")
        .map(
            c ->
                test(
                    c,
                    () -> assertFailsWithListedKind(c, () -> Uuid58.encode(hexToBytes(str(c, "bytes"))))));
  }

  @TestFactory
  Stream<DynamicTest> encodeInvalidIntegers() {
    return section("encode", "invalid_integers")
        .map(
            c ->
                test(
                    c,
                    () ->
                        assertFailsWithListedKind(
                            c, () -> Uuid58.encode(new BigInteger(str(c, "integer"))))));
  }

  @TestFactory
  Stream<DynamicTest> decodeInvalid() {
    List<Function<String, Object>> decoders = new ArrayList<>();
    decoders.add(Uuid58::decode);
    decoders.add(Uuid58::decodeToUuid);
    decoders.add(Uuid58::decodeToBytes);
    return section("decode", "invalid")
        .map(
            c ->
                test(
                    c,
                    () -> {
                      for (Function<String, Object> decoder : decoders) {
                        assertFailsWithListedKind(c, () -> decoder.apply(str(c, "input")));
                      }
                    }));
  }

  @TestFactory
  Stream<DynamicTest> decodeInvalidIsNotValid() {
    return section("decode", "invalid")
        .map(c -> test(c, () -> assertFalse(Uuid58.isValid(str(c, "input")))));
  }
}
