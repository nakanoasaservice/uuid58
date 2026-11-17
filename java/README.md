# uuid58 for Java and Kotlin

[![Maven Central](https://img.shields.io/maven-central/v/io.github.nakanoasaservice/uuid58.svg)](https://central.sonatype.com/artifact/io.github.nakanoasaservice/uuid58)
[![CI](https://github.com/nakanoasaservice/uuid58/actions/workflows/ci-java.yml/badge.svg)](https://github.com/nakanoasaservice/uuid58/actions/workflows/ci-java.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/nakanoasaservice/uuid58/blob/main/LICENSE)

Shorten UUIDs to 22-character Base58 strings, and back, in Java and Kotlin.
Works with `java.util.UUID`, strings, bytes, and `BigInteger`.

```text
f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf  ⇄  XDY9dmBbcMBXqcRvYw8xJ2
```

- **Fixed 22 characters**, using the Bitcoin Base58 alphabet: URL-safe, with
  no look-alike characters (`0`, `O`, `I`, `l`).
- **Sortable**: comparing uuid58 strings with `String.compareTo` gives the
  same order as comparing the UUIDs as unsigned 128-bit integers, so UUIDv7
  IDs stay time-ordered.
- **Stable spec, well tested**: implements uuid58 spec 1.1.0 and passes its
  200+ shared test vectors, so the output matches every other language.
- **No runtime dependencies.** Java 8 or later (also works on Android).
  Kotlin uses the Java API directly. JPMS module name:
  `io.github.nakanoasaservice.uuid58`.

[Try it in your browser](https://nakanoasaservice.github.io/uuid58/) ·
[Specification](https://github.com/nakanoasaservice/uuid58/blob/main/spec/SPEC.md) ·
[Other languages](https://github.com/nakanoasaservice/uuid58#install)

> **Status:** the library is 0.x, so its API may still change. The encoding
> itself follows spec 1.1.0, and the format does not change within spec 1.x.

## Installation

Gradle (Kotlin DSL):

```kotlin
dependencies {
    implementation("io.github.nakanoasaservice:uuid58:0.1.1")
}
```

Gradle (Groovy DSL):

```groovy
dependencies {
    implementation 'io.github.nakanoasaservice:uuid58:0.1.1'
}
```

Maven:

```xml
<dependency>
  <groupId>io.github.nakanoasaservice</groupId>
  <artifactId>uuid58</artifactId>
  <version>0.1.1</version>
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
package 1.x, which ignores misplaced hyphens; see
[SPEC.md Section 9.1](https://github.com/nakanoasaservice/uuid58/blob/main/spec/SPEC.md#91-javascript-nakanoaasuuid58-1x).)

`decode` and `decodeToUuid` always produce the lowercase hyphenated form.

### Sorting

Comparing uuid58 strings with `String.compareTo` gives the same order as
comparing the 128-bit values as unsigned integers. Note that
`java.util.UUID.compareTo` compares the halves as signed longs, so it orders
some UUIDs differently. In a database, use a binary (`C`) collation.

## Compatibility

This package implements
[uuid58 specification](https://github.com/nakanoasaservice/uuid58/blob/main/spec/SPEC.md)
1.0.0 and passes every case in
[`spec/vectors.json`](https://github.com/nakanoasaservice/uuid58/blob/main/spec/vectors.json),
so its output is identical to the
[other implementations](https://github.com/nakanoasaservice/uuid58#install)
(JavaScript, Go, Python, Rust, PostgreSQL, and more).

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

[`publish-java.yml`](https://github.com/nakanoasaservice/uuid58/blob/main/.github/workflows/publish-java.yml) then runs the
tests, signs the artifacts, publishes them to Maven Central, and creates a
GitHub Release.

## License

[MIT](https://github.com/nakanoasaservice/uuid58/blob/main/LICENSE)
