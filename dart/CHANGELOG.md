## 0.1.1

- Publish through GitHub Actions with trusted publishing on pub.dev.
- No public API or runtime behavior changes.

## 0.1.0

- Initial release, implementing uuid58 specification 1.1.0.
- `uuid58Encode`, `uuid58EncodeBytes`, `uuid58Decode`, `uuid58DecodeBytes`,
  `isUuid58`, and the `uuid58()` UUIDv4 generator.
- `Uuid58Exception` (a `FormatException`) with a `Uuid58ErrorKind` matching
  the spec's error kinds.
- Works on the Dart VM, Flutter, and the web (dart2js and dart2wasm) without
  64-bit integers.
