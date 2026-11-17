# uuid58 for Go

[![Go Reference](https://pkg.go.dev/badge/github.com/nakanoasaservice/uuid58/go.svg)](https://pkg.go.dev/github.com/nakanoasaservice/uuid58/go)
[![CI](https://github.com/nakanoasaservice/uuid58/actions/workflows/ci-go.yml/badge.svg)](https://github.com/nakanoasaservice/uuid58/actions/workflows/ci-go.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/nakanoasaservice/uuid58/blob/main/LICENSE)

Shorten UUIDs to 22-character Base58 strings, and back, in Go. Works with
`[16]byte` and `github.com/google/uuid`, and ships with a command-line tool.

```text
f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf  ⇄  XDY9dmBbcMBXqcRvYw8xJ2
```

- **Fixed 22 characters**, using the Bitcoin Base58 alphabet: URL-safe, with
  no `0`, `O`, `I`, or `l`.
- **Sortable**: strings sort in the same order as the UUIDs they encode
  (byte-wise comparison), so UUIDv7 IDs stay time-ordered.
- **Stable spec, well tested**: implements uuid58 spec 1.1.0 and passes its
  200+ shared test vectors, so the output matches every other language.
- **Standard library only.** Requires Go 1.26 or later.

[Try it in your browser](https://nakanoasaservice.github.io/uuid58/) ·
[Specification](https://github.com/nakanoasaservice/uuid58/blob/main/spec/SPEC.md) ·
[Other languages](https://github.com/nakanoasaservice/uuid58#install)

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

## Command-line tool

`cmd/uuid58` is a small CLI built on this package: a single static binary
with no dependencies beyond the standard library.

```bash
go install github.com/nakanoasaservice/uuid58/go/cmd/uuid58@latest
```

```console
$ uuid58 encode f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf
XDY9dmBbcMBXqcRvYw8xJ2
$ uuid58 decode XDY9dmBbcMBXqcRvYw8xJ2
f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf
$ uuid58 validate XDY9dmBbcMBXqcRvYw8xJ0
uuid58 validate: "XDY9dmBbcMBXqcRvYw8xJ0": invalid_character
$ uuid58 gen -n 2 -uuid
H3c9vqTCe6HUJLf5J4B85a	81ef5ed7-e2d8-4fba-8eef-28d5b73aaa65
D4DRZqo3FLg8r4Dzz8vrfQ	61a08d30-4a07-4352-9519-0287e58ac62f
$ psql -Atc 'select id from users' | uuid58 encode
```

| Command                  | Description                                                                           |
| ------------------------ | ------------------------------------------------------------------------------------- |
| `encode [uuid ...]`      | UUID → uuid58 (same accepted forms as `Encode`)                                       |
| `decode [uuid58 ...]`    | uuid58 → lowercase hyphenated UUID                                                    |
| `validate [uuid58 ...]`  | No output; exit status 0 only if every input is valid (alias `check`)                 |
| `gen [-n count] [-uuid]` | New random version 4 UUIDs as uuid58; `-uuid` adds the UUID after a tab (alias `new`) |
| `--version`, `--help`    | Print the version or usage                                                            |

- With no arguments, `encode`, `decode`, and `validate` read one value per
  line from standard input. Only the line terminator (`\n` or `\r\n`) is
  removed; other whitespace is part of the value and makes it invalid, as in
  the specification.
- Every input is processed. Each invalid one is reported on standard error
  with its error kind (`invalid_length`, `invalid_character`, `overflow`).
- Exit status: 0 on success, 1 if any input was invalid, 2 on a usage error.

### Homebrew, Nix, and prebuilt binaries

```bash
brew install nakanoasaservice/tap/uuid58
```

```bash
nix run github:nakanoasaservice/uuid58 -- encode f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf
nix profile install github:nakanoasaservice/uuid58
```

Prebuilt binaries for macOS, Linux, and Windows (amd64 and arm64) are
attached to each `go/vX.Y.Z` [GitHub Release](https://github.com/nakanoasaservice/uuid58/releases).

The Homebrew formula installs those binaries and is updated by the release
workflow. The Nix flake (`flake.nix` at the repository root) builds from
source at whatever commit you point it at, so its `--version` is the commit
rather than a release number.

## Compatibility

This package implements
[uuid58 spec 1.1.0](https://github.com/nakanoasaservice/uuid58/blob/main/spec/SPEC.md) and passes every applicable
case in the shared [test vectors](https://github.com/nakanoasaservice/uuid58/blob/main/spec/vectors.json). A string
it produces decodes to the same UUID in every other implementation, and the
other way around.

## Development

Go is managed with [mise](https://mise.jdx.dev/) (`mise.toml`):

```bash
mise install
go vet ./...
gofmt -l .
go test ./...
go test -fuzz=FuzzDecode -fuzztime=30s
```

The conformance tests read [`spec/vectors.json`](https://github.com/nakanoasaservice/uuid58/blob/main/spec/vectors.json)
at the repository root.

## Releases

This module lives in the `go/` subdirectory of the repository, so by Go's
convention its versions are tags of the form `go/vX.Y.Z` (for example
`go/v0.1.0`). Pushing such a tag is the whole release; the Go module proxy
picks it up on first request. The same tag also releases the CLI:
[`publish-go.yml`](https://github.com/nakanoasaservice/uuid58/blob/main/.github/workflows/publish-go.yml) builds the binaries,
attaches them to a GitHub Release, and updates `Formula/uuid58.rb` in
[nakanoasaservice/homebrew-tap](https://github.com/nakanoasaservice/homebrew-tap).
That last step needs a `HOMEBREW_TAP_TOKEN` secret: a fine-grained token with
Contents read and write access to the tap repository only.

Versions stay below 1.0.0 until the specification reaches 1.0.0.

## License

MIT, see [LICENSE](https://github.com/nakanoasaservice/uuid58/blob/main/LICENSE).
