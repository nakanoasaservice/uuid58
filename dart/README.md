# uuid58 (Dart)

Encode UUIDs as 22-character Base58 strings, and back. Pure Dart, for
Flutter, server, and web apps.

```text
f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf  <->  XDY9dmBbcMBXqcRvYw8xJ2
```

- Always exactly 22 characters, using the Bitcoin Base58 alphabet (no `0`,
  `O`, `I`, `l`).
- Order-preserving: sorting uuid58 strings by code unit sorts the UUIDs
  numerically (useful with UUIDv7).
- Strict: implements the
  [uuid58 specification](https://github.com/nakanoasaservice/uuid58/blob/main/spec/SPEC.md)
  and passes its
  [test vectors](https://github.com/nakanoasaservice/uuid58/blob/main/spec/vectors.json).
- Works on every Dart platform: the VM, Flutter (iOS, Android, desktop), and
  the web (dart2js and dart2wasm). The arithmetic uses 32-bit words, so it
  never needs 64-bit integers, which JavaScript does not have.
- No dependencies. Requires Dart 3.6 or later.

## Install

```bash
dart pub add uuid58
```

or `flutter pub add uuid58`.

## Usage

```dart
import 'package:uuid58/uuid58.dart';

const s = 'XDY9dmBbcMBXqcRvYw8xJ2';

// All of these return s:
uuid58Encode('f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf');
uuid58Encode('F4B247FD1F8745D4AA061C6FC0A8DFAF'); // plain hex, any case
uuid58EncodeBytes(bytes); // a Uint8List of 16 bytes

uuid58Decode(s); // 'f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf'
uuid58DecodeBytes(s); // Uint8List [244, 178, 71, 253, ...]

isUuid58('XDY9dmBbcMBXqcRvYw8xJ2'); // true
isUuid58('zzzzzzzzzzzzzzzzzzzzzz'); // false: exceeds 128 bits

uuid58(); // a random UUIDv4, encoded, e.g. 'Tj5D5H2Bc1LcPjwNNhH4xS'
```

With [`package:uuid`](https://pub.dev/packages/uuid), go through the bytes:

```dart
final value = UuidValue.fromString('f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf');
final id = uuid58EncodeBytes(value.toBytes()); // 'XDY9dmBbcMBXqcRvYw8xJ2'
final back = UuidValue.fromByteList(uuid58DecodeBytes(id)); // == value
```

### Errors

Invalid input throws a `Uuid58Exception`, which implements
`FormatException`. Its `kind` is a `Uuid58ErrorKind`, and `kind.code` is the
error kind name from the specification (Section 7):

| `kind`             | `kind.code`           | Thrown when                                                    |
| ------------------ | --------------------- | -------------------------------------------------------------- |
| `invalidLength`    | `"invalid_length"`    | a string of the wrong length, or bytes whose length is not 16 |
| `invalidCharacter` | `"invalid_character"` | a character not allowed in its position (incl. any non-ASCII) |
| `overflow`         | `"overflow"`          | a uuid58 string whose value exceeds `2^128 - 1`               |

```dart
try {
  uuid58Decode(userInput);
} on Uuid58Exception catch (e) {
  print(e.kind.code); // invalid_length / invalid_character / overflow
}
```

`offset` holds the index of the first invalid character when decoding fails
with `invalidCharacter`. Error messages are not part of the specification
and may change.

## API

| Name                                        | Description                                                   |
| ------------------------------------------- | ------------------------------------------------------------- |
| `String uuid58Encode(String uuid)`          | Encode a UUID string (hyphenated or 32 hex digits, any case). |
| `String uuid58EncodeBytes(Uint8List bytes)` | Encode 16 big-endian bytes (RFC 9562 order).                  |
| `String uuid58Decode(String s)`             | Decode to the lowercase hyphenated UUID string.               |
| `Uint8List uuid58DecodeBytes(String s)`     | Decode to 16 big-endian bytes.                                |
| `bool isUuid58(String s)`                   | `true` exactly when `uuid58Decode(s)` would succeed.          |
| `String uuid58({Random? random})`           | Generate a UUIDv4 (with `Random.secure()` by default).        |
| `uuid58Alphabet`, `uuid58Max`, `uuid58Nil`  | The alphabet, the largest valid string, and the nil UUID.     |
| `Uuid58Exception`, `Uuid58ErrorKind`        | See [Errors](#errors).                                        |

### Accepted UUID strings

`uuid58Encode` accepts exactly two forms, in any letter case (SPEC.md
Section 5.1):

- hyphenated, 36 characters: `f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf`
- plain, 32 hex digits: `f4b247fd1f8745d4aa061c6fc0a8dfaf`

Everything else is rejected, including braces, the `urn:uuid:` prefix,
misplaced hyphens and surrounding whitespace.

Length is measured in UTF-16 code units, like `String.length`. Any non-ASCII
character, including a lone surrogate, is rejected.

## Development

The Dart SDK is pinned via `mise.toml`.

```bash
dart pub get
dart format --output=none --set-exit-if-changed .
dart analyze
dart test                       # Dart VM
dart test -p node               # dart2js on Node.js
dart test -p chrome             # dart2js in Chrome
dart test -p chrome -c dart2wasm
```

The conformance tests read `../spec/vectors.json`, so run them from a
checkout of the repository. They run on the VM and Node.js; browsers skip
them.

## License

[MIT](LICENSE)
