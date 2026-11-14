# uuid58 for Java and Kotlin

uuid58 encodes a UUID as a fixed 22-character Base58 string, using the Bitcoin
alphabet. The result is shorter than the usual 36-character form, safe to use
in URLs, and free of look-alike characters (`0`, `O`, `I`, `l`). Encoded
strings sort in the same order as the UUIDs they encode.

```text
f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf  ⇄  XDY9dmBbcMBXqcRvYw8xJ2
```

This is the Java implementation of the
[uuid58 specification](../spec/SPEC.md). It passes every case in
[`spec/vectors.json`](../spec/vectors.json).

- No runtime dependencies.
- Java 8 or later (also works on Android). Kotlin uses the Java API directly.
- JPMS module name: `io.github.nakanoasaservice.uuid58`.

> **Status:** 0.x. The API may change until the specification reaches 1.0.0.

## Installation

Gradle (Kotlin DSL):

```kotlin
dependencies {
    implementation("io.github.nakanoasaservice:uuid58:0.1.0")
}
```

Gradle (Groovy DSL):

```groovy
dependencies {
    implementation 'io.github.nakanoasaservice:uuid58:0.1.0'
}
```

Maven:

```xml
<dependency>
  <groupId>io.github.nakanoasaservice</groupId>
  <artifactId>uuid58</artifactId>
  <version>0.1.0</version>
</dependency>
```

## Usage

### Java

```java
import io.github.nakanoasaservice.uuid58.Uuid58;
import io.github.nakanoasaservice.uuid58.Uuid58Exception;
import java.util.UUID;

// Encode
Uuid58.encode("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf"); // "XDY9dmBbcMBXqcRvYw8xJ2"
Uuid58.encode("F4B247FD1F8745D4AA061C6FC0A8DFAF");     // "XDY9dmBbcMBXqcRvYw8xJ2"
Uuid58.encode(UUID.fromString("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf"));
Uuid58.encode(bytes);    // 16 bytes, big-endian
Uuid58.encode(msb, lsb); // two longs, as in UUID.getMostSignificantBits()

// Decode
Uuid58.decode("XDY9dmBbcMBXqcRvYw8xJ2");        // "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf"
Uuid58.decodeToUuid("XDY9dmBbcMBXqcRvYw8xJ2");  // java.util.UUID
Uuid58.decodeToBytes("XDY9dmBbcMBXqcRvYw8xJ2"); // byte[16]

// Validate without decoding
Uuid58.isValid("XDY9dmBbcMBXqcRvYw8xJ2"); // true
Uuid58.isValid("invalid");                // false

// Generate a random (version 4) UUID, encoded
String id = Uuid58.generate();

// Errors
try {
  Uuid58.decode(input);
} catch (Uuid58Exception e) {
  switch (e.getKind()) {
    case INVALID_LENGTH:    /* not 22 characters */ break;
    case INVALID_CHARACTER: /* not in the alphabet */ break;
    case OVERFLOW:          /* greater than 2^128 - 1 */ break;
  }
}
```

### Kotlin

```kotlin
import io.github.nakanoasaservice.uuid58.Uuid58
import io.github.nakanoasaservice.uuid58.Uuid58Exception

val id = Uuid58.encode("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf") // "XDY9dmBbcMBXqcRvYw8xJ2"
val uuid: java.util.UUID = Uuid58.decodeToUuid(id)

fun parseOrNull(s: String?): java.util.UUID? =
    if (Uuid58.isValid(s)) Uuid58.decodeToUuid(s) else null

try {
    Uuid58.decode("nope")
} catch (e: Uuid58Exception) {
    when (e.kind) {
        Uuid58Exception.Kind.INVALID_LENGTH -> TODO()
        Uuid58Exception.Kind.INVALID_CHARACTER -> TODO()
        Uuid58Exception.Kind.OVERFLOW -> TODO()
    }
}
```

## API

All members are static methods of the final class `Uuid58`. Passing `null`
throws `NullPointerException`, except to `isValid`, which returns `false`.

| Method                          | Returns  | Throws `Uuid58Exception` with                |
| ------------------------------- | -------- | -------------------------------------------- |
| `encode(String uuid)`           | `String` | `INVALID_LENGTH`, `INVALID_CHARACTER`        |
| `encode(UUID uuid)`             | `String` | never                                        |
| `encode(long msb, long lsb)`    | `String` | never                                        |
| `encode(byte[] bytes)`          | `String` | `INVALID_LENGTH` (not 16 bytes)              |
| `encode(BigInteger value)`      | `String` | `OVERFLOW` (negative or above `2^128 - 1`)   |
| `decode(String uuid58)`         | `String` | `INVALID_LENGTH`, `INVALID_CHARACTER`, `OVERFLOW` |
| `decodeToUuid(String uuid58)`   | `UUID`   | same as `decode`                             |
| `decodeToBytes(String uuid58)`  | `byte[]` | same as `decode`                             |
| `isValid(String uuid58)`        | `boolean`| never                                        |
| `generate()`                    | `String` | never                                        |

Constants: `ALPHABET`, `LENGTH` (22), and `MAX`
(`YcVfxkQb6JRzqk5kF2tNLv`, the largest valid uuid58 string).

`Uuid58Exception` extends `IllegalArgumentException`. `getKind()` returns a
`Uuid58Exception.Kind`, one of the error kinds of the specification
(Section 7); `Kind.specName()` gives its name in the specification, such as
`"invalid_length"`. Error messages are not part of the API.

### Accepted UUID strings

`encode(String)` accepts exactly two forms, in upper, lower, or mixed case:

- hyphenated, 36 characters: `f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf`
- plain, 32 hexadecimal digits: `f4b247fd1f8745d4aa061c6fc0a8dfaf`

Everything else is rejected, including braces, `urn:uuid:`, whitespace, and
hyphens in other positions. This is stricter than `UUID.fromString`, which
accepts inputs such as `1-2-3-4-5`. (It is also stricter than the JavaScript
package 1.x, which ignores misplaced hyphens; see SPEC.md Section 9.1.)

`decode` and `decodeToUuid` always produce the lowercase hyphenated form.

### Sorting

Comparing uuid58 strings with `String.compareTo` gives the same order as
comparing the 128-bit values as unsigned integers. Note that
`java.util.UUID.compareTo` compares the halves as signed longs, so it orders
some UUIDs differently. In a database, use a binary (`C`) collation.

## Development

Requires a JDK (8 or later) to build; [mise](https://mise.jdx.dev) installs
the one used in development (`mise install`). The Maven wrapper downloads
Maven itself.

```bash
./mvnw verify   # compile for Java 8, run the tests (including spec/vectors.json), build jars
./mvnw install  # also install into ~/.m2 for local use
```

The tests read `../spec/vectors.json`, so run them from a checkout of the
whole repository.

### Releasing

1. Bump `<version>` in `java/pom.xml` and merge it into main.
2. `git tag java/v0.1.0 <commit on main> && git push origin java/v0.1.0`

[`publish-java.yml`](../.github/workflows/publish-java.yml) then runs the
tests, signs the artifacts, publishes them to Maven Central, and creates a
GitHub Release.

## License

[MIT](LICENSE)
