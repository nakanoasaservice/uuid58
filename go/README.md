# uuid58 for Go

[![Go Reference](https://pkg.go.dev/badge/github.com/nakanoasaservice/uuid58/go.svg)](https://pkg.go.dev/github.com/nakanoasaservice/uuid58/go)

Go implementation of [uuid58](../spec/SPEC.md): a 22-character Base58 text
encoding for 128-bit UUIDs.

```text
f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf  <->  XDY9dmBbcMBXqcRvYw8xJ2
```

- Always exactly 22 characters, using the Bitcoin Base58 alphabet (no `0`,
  `O`, `I`, `l`).
- Sorts in the same order as the UUIDs it encodes (byte-wise comparison).
- Standard library only. Requires Go 1.26 or later.
- Passes every applicable case in the shared
  [test vectors](../spec/vectors.json).

## Install

```bash
go get github.com/nakanoasaservice/uuid58/go
```

The package name is `uuid58`:

```go
import uuid58 "github.com/nakanoasaservice/uuid58/go"
```

## Usage

```go
s, err := uuid58.Encode("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf")
// s == "XDY9dmBbcMBXqcRvYw8xJ2"

u, err := uuid58.Decode("XDY9dmBbcMBXqcRvYw8xJ2")
// u == "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf"

uuid58.IsValid("XDY9dmBbcMBXqcRvYw8xJ2") // true

id := uuid58.New() // uuid58 of a random version 4 UUID
```

### With `[16]byte` and `github.com/google/uuid`

`EncodeBytes` and `DecodeBytes` work with 16 bytes in RFC 9562 (network)
byte order. Any type whose underlying type is `[16]byte`, such as
`github.com/google/uuid`'s `UUID`, can be passed and assigned directly; this
package does not depend on it.

```go
id := uuid.New()
s := uuid58.EncodeBytes(id) // never fails

b, err := uuid58.DecodeBytes(s)
back := uuid.UUID(b)
```

### Errors

Every error is one of three sentinel values (the error kinds of the
specification), to be tested with `errors.Is`:

| Error                 | Returned when                                                                    |
| --------------------- | -------------------------------------------------------------------------------- |
| `ErrInvalidLength`    | The input has the wrong length.                                                  |
| `ErrInvalidCharacter` | The input has the right length but a character not allowed in its position.      |
| `ErrOverflow`         | (decoding only) The input is well formed but its value exceeds 2^128 − 1.        |

```go
if _, err := uuid58.Decode(s); errors.Is(err, uuid58.ErrInvalidCharacter) {
	// ...
}
```

Input containing any byte `0x80` or above (non-ASCII or ill-formed UTF-8)
is always rejected, with `ErrInvalidLength` or `ErrInvalidCharacter`. Length
is measured in bytes.

### Accepted UUID strings

`Encode` (and `ParseUUID`) accept exactly two forms, in upper, lower, or
mixed case:

```text
f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf   hyphenated, 36 characters
f4b247fd1f8745d4aa061c6fc0a8dfaf       plain, 32 characters
```

Everything else is rejected, including misplaced hyphens, braces, the
`urn:uuid:` prefix, and surrounding whitespace. (The JavaScript package 1.x
is more lenient about hyphens; this package follows the specification.)
`Decode` always returns the lowercase hyphenated form.

## API

| Function                                      | Description                                                         |
| --------------------------------------------- | ------------------------------------------------------------------- |
| `Encode(uuid string) (string, error)`         | UUID string → uuid58                                                |
| `Decode(s string) (string, error)`            | uuid58 → lowercase hyphenated UUID string                           |
| `IsValid(s string) bool`                      | Whether `Decode` would succeed                                      |
| `EncodeBytes(b [16]byte) string`              | 16 big-endian bytes → uuid58                                        |
| `DecodeBytes(s string) ([16]byte, error)`     | uuid58 → 16 big-endian bytes                                        |
| `ParseUUID(s string) ([16]byte, error)`       | UUID string → 16 bytes, accepting the same forms as `Encode`        |
| `FormatUUID(b [16]byte) string`               | 16 bytes → lowercase hyphenated UUID string                         |
| `New() string`                                | uuid58 of a new random version 4 UUID (`crypto/rand`)               |
| `Alphabet`, `Max`, `Len`                      | The alphabet, the largest uuid58 string, and its length (22)        |

See [pkg.go.dev](https://pkg.go.dev/github.com/nakanoasaservice/uuid58/go)
for full documentation.

## Development

Go is managed with [mise](https://mise.jdx.dev/) (`mise.toml`):

```bash
mise install
go vet ./...
gofmt -l .
go test ./...
go test -fuzz=FuzzDecode -fuzztime=30s
```

The conformance tests read `../spec/vectors.json`.

## Releases

This module lives in the `go/` subdirectory of the repository, so by Go's
convention its versions are tags of the form `go/vX.Y.Z` (for example
`go/v0.1.0`). Pushing such a tag is the whole release; the Go module proxy
picks it up on first request. There is no publish workflow.

Versions stay below 1.0.0 until the specification reaches 1.0.0.

## License

MIT, see [LICENSE](LICENSE).
