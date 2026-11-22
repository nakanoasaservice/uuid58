## 0.1.1

- Update installation documentation now that the package is available on Hex.
- Publish through GitHub Actions using Hex workload identity.
- No runtime behavior changes.

## 0.1.0

- Initial release, implementing uuid58 specification 1.1.0.
- `encode/1`, `encode_bytes/1`, `encode_integer/1`, `decode/1`,
  `decode_bytes/1`, `decode_integer/1`, and `valid?/1`, plus bang variants
  that raise `Uuid58.Error`.
- `generate/0` returns a random UUID version 4 as uuid58.
- No runtime dependencies. Requires Elixir 1.16 or later.
