## Unreleased

- Implements uuid58 specification 1.1.0: `Uuid58Exception.toString()` no
  longer includes the rejected input, only its kind, message, and offset.
  The input is still available as `source`.

## 0.1.0

- Initial release, implementing uuid58 specification 1.0.0.
- `uuid58Encode`, `uuid58EncodeBytes`, `uuid58Decode`, `uuid58DecodeBytes`,
  `isUuid58`, and the `uuid58()` UUIDv4 generator.
- `Uuid58Exception` (a `FormatException`) with a `Uuid58ErrorKind` matching
  the spec's error kinds.
- Works on the Dart VM, Flutter, and the web (dart2js and dart2wasm) without
  64-bit integers.
