# uuid58 for Python

[![PyPI](https://img.shields.io/pypi/v/uuid58.svg)](https://pypi.org/project/uuid58/)
[![CI](https://github.com/nakanoasaservice/uuid58/actions/workflows/ci-python.yml/badge.svg)](https://github.com/nakanoasaservice/uuid58/actions/workflows/ci-python.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/nakanoasaservice/uuid58/blob/main/LICENSE)

Shorten UUIDs to 22-character Base58 strings, and back, in Python. Works with
`uuid.UUID` from the standard library, as well as strings, bytes, and ints.

```text
f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf  ⇄  XDY9dmBbcMBXqcRvYw8xJ2
```

- **Fixed 22 characters**, using the Bitcoin Base58 alphabet: URL-safe, with
  no `0`, `O`, `I`, or `l`.
- **Sortable**: sorting uuid58 strings by code point sorts the UUIDs
  numerically, so UUIDv7 IDs stay time-ordered.
- **Stable spec, well tested**: implements
  [uuid58 spec 1.1.0](https://github.com/nakanoasaservice/uuid58/blob/main/spec/SPEC.md)
  and passes its 200+ shared
  [test vectors](https://github.com/nakanoasaservice/uuid58/blob/main/spec/vectors.json),
  so output matches every other language.
- **No dependencies**, fully typed (`py.typed`), CPython 3.10+.

[Try it in your browser](https://nakanoasaservice.github.io/uuid58/) ·
[Specification](https://github.com/nakanoasaservice/uuid58/blob/main/spec/SPEC.md) ·
[Other languages](https://github.com/nakanoasaservice/uuid58#install)

## Install

```bash
pip install uuid58
```

or `uv add uuid58`.

## Usage

```python
import uuid
import uuid58

s = "XDY9dmBbcMBXqcRvYw8xJ2"

# All of these return s:
uuid58.encode("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf")
uuid58.encode("F4B247FD1F8745D4AA061C6FC0A8DFAF")  # plain hex, any case
uuid58.encode(uuid.UUID("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf"))
uuid58.encode(bytes.fromhex("f4b247fd1f8745d4aa061c6fc0a8dfaf"))
uuid58.encode(0xF4B247FD1F8745D4AA061C6FC0A8DFAF)

uuid58.decode(s)  # 'f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf'
uuid58.decode_uuid(s)  # UUID('f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf')
uuid58.decode_bytes(s)  # b'\xf4\xb2G\xfd\x1f\x87E\xd4...'
uuid58.decode_int(s)  # 325257319917903217740243107280071483311

uuid58.is_uuid58("XDY9dmBbcMBXqcRvYw8xJ2")  # True
uuid58.is_uuid58("zzzzzzzzzzzzzzzzzzzzzz")  # False: exceeds 128 bits

uuid58.uuid58()  # a random UUIDv4, encoded, e.g. 'Tj5D5H2Bc1LcPjwNNhH4xS'
```

### Errors

All invalid-input errors subclass `uuid58.Uuid58Error`, which subclasses
`ValueError`. Each carries the spec error kind
([SPEC.md Section 7](https://github.com/nakanoasaservice/uuid58/blob/main/spec/SPEC.md#7-errors)) in `kind`,
an `ErrorKind` that compares equal to its spec name:

| Exception               | `kind`                | Raised when                                                      |
| ----------------------- | --------------------- | ---------------------------------------------------------------- |
| `InvalidLengthError`    | `"invalid_length"`    | a string of the wrong length, or bytes whose length is not 16    |
| `InvalidCharacterError` | `"invalid_character"` | a character not allowed in its position (incl. any non-ASCII)    |
| `ValueOverflowError`    | `"overflow"`          | a value outside `0..2**128 - 1` (decoded string or encoded `int`) |

```python
try:
    uuid58.decode(user_input)
except uuid58.InvalidCharacterError:
    ...
except uuid58.Uuid58Error as e:
    print(e.kind)  # invalid_length / overflow
```

Passing an unsupported type (for example `bool`, `float` or `None`) raises
`TypeError`. Error messages are not part of the specification and may change.

## API

| Name                                     | Description                                                                       |
| ---------------------------------------- | --------------------------------------------------------------------------------- |
| `encode(value: UUIDLike) -> str`         | Encode a UUID string, `uuid.UUID`, 16 `bytes`/`bytearray`, or `int`.               |
| `decode(s: str) -> str`                  | Decode to the lowercase hyphenated UUID string.                                   |
| `decode_uuid(s: str) -> uuid.UUID`       | Decode to a `uuid.UUID`.                                                          |
| `decode_bytes(s: str) -> bytes`          | Decode to 16 big-endian bytes (`uuid.UUID.bytes` order).                          |
| `decode_int(s: str) -> int`              | Decode to an `int` in `0..2**128 - 1`.                                            |
| `is_uuid58(s: object) -> bool`           | `True` exactly when `decode(s)` would succeed. Never raises.                      |
| `uuid58() -> str`                        | Generate a random UUIDv4 and return its encoding.                                 |
| `ALPHABET`, `MAX_UUID58`                 | The Base58 alphabet and the largest valid uuid58 string.                          |
| `Uuid58Error`, `ErrorKind`, …            | See [Errors](#errors).                                                            |

### Accepted UUID strings

`encode` accepts exactly two textual forms, in any letter case
([SPEC.md Section 5.1](https://github.com/nakanoasaservice/uuid58/blob/main/spec/SPEC.md#51-accepted-forms)):

- hyphenated, 36 characters: `f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf`
- plain, 32 hex digits: `f4b247fd1f8745d4aa061c6fc0a8dfaf`

Everything else is rejected, including forms that `uuid.UUID()` accepts:
braces, the `urn:uuid:` prefix, misplaced hyphens and surrounding
whitespace. To encode those, parse them with `uuid.UUID(...)` first and pass
the resulting object.

`bytes` passed to `encode` are the 16 raw bytes of the UUID, never the ASCII
text of a UUID string.

## Compatibility

This package implements
[uuid58 spec 1.1.0](https://github.com/nakanoasaservice/uuid58/blob/main/spec/SPEC.md)
and passes every case in
[`spec/vectors.json`](https://github.com/nakanoasaservice/uuid58/blob/main/spec/vectors.json)
in CI. A string encoded here decodes to the same UUID with every other
[uuid58 implementation](https://github.com/nakanoasaservice/uuid58#install),
and the reverse.

## Development

Uses [uv](https://docs.astral.sh/uv/) (pinned via `mise.toml`).

```bash
uv run pytest            # tests, including spec/vectors.json conformance
uv run ruff check        # lint
uv run ruff format       # format
uv run mypy              # type check (strict)
```

The conformance tests read `../spec/vectors.json`, so run them from a
checkout of the repository.

## License

MIT. See
[LICENSE](https://github.com/nakanoasaservice/uuid58/blob/main/LICENSE).
