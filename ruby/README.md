# uuid58 (Ruby)

Encode UUIDs as 22-character Base58 strings, and back.

```text
f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf  <->  XDY9dmBbcMBXqcRvYw8xJ2
```

- Always exactly 22 characters, using the Bitcoin Base58 alphabet (no `0`,
  `O`, `I`, `l`).
- Order-preserving: sorting uuid58 strings bytewise sorts the UUIDs
  numerically (useful with UUIDv7).
- Strict: implements the [uuid58 specification](https://github.com/nakanoasaservice/uuid58/blob/main/spec/SPEC.md)
  and passes its [test vectors](https://github.com/nakanoasaservice/uuid58/blob/main/spec/vectors.json).
- No dependencies, Ruby 3.2+.

## Install

```bash
bundle add uuid58
```

or `gem install uuid58`.

## Usage

```ruby
require "uuid58"

s = "XDY9dmBbcMBXqcRvYw8xJ2"

# All of these return s:
Uuid58.encode("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf")
Uuid58.encode("F4B247FD1F8745D4AA061C6FC0A8DFAF") # plain hex, any case
Uuid58.encode(["f4b247fd1f8745d4aa061c6fc0a8dfaf"].pack("H32")) # 16 binary bytes
Uuid58.encode(0xF4B247FD1F8745D4AA061C6FC0A8DFAF)

Uuid58.decode(s)       # => "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf"
Uuid58.decode_bytes(s) # => "\xF4\xB2G\xFD\x1F\x87E\xD4..." (Encoding::BINARY)
Uuid58.decode_int(s)   # => 325257319917903217740243107280071483311

Uuid58.valid?("XDY9dmBbcMBXqcRvYw8xJ2") # => true
Uuid58.valid?("zzzzzzzzzzzzzzzzzzzzzz") # => false: exceeds 128 bits

Uuid58.generate # a random UUIDv4, encoded, e.g. "Tj5D5H2Bc1LcPjwNNhH4xS"
```

### Rails

With UUID primary keys, encode for URLs and decode when looking records up:

```ruby
class Post < ApplicationRecord
  def to_param = Uuid58.encode(id)

  def self.find_by_param!(param) = find(Uuid58.decode(param))
end
```

`Uuid58.decode` raises `Uuid58::Error` (an `ArgumentError`) for a malformed
parameter; rescue it, or check `Uuid58.valid?` first, to return 404 instead
of 500.

### Strings, encodings and bytes

`encode` decides how to read a `String` from its encoding:

- **`Encoding::BINARY`** (`ASCII-8BIT`) strings are raw bytes and must be
  exactly 16 bytes long. These come from `Array#pack`,
  `SecureRandom.random_bytes`, or `bytea`/`binary(16)` columns.
- **Any other encoding** is UUID text (see [Accepted UUID strings](#accepted-uuid-strings)).

Some sources return text as `BINARY`, such as `Net::HTTP` bodies or
`File.binread`. Call `Uuid58.encode(str.dup.force_encoding(Encoding::UTF_8))`
for those, or use `Uuid58.encode_bytes` / `Uuid58.encode_int` to choose
explicitly.

Every check works on bytes, so any byte `0x80` or above is rejected, whatever
the string's encoding (SPEC.md Section 4.1). Strings in an encoding that is
not ASCII-compatible (UTF-16, UTF-32) are transcoded to UTF-8 first.

### Errors

All invalid-input errors subclass `Uuid58::Error`, which subclasses
`ArgumentError`. Each has a `kind` symbol naming the spec error kind
(SPEC.md Section 7):

| Exception                       | `kind`               | Raised when                                                          |
| ------------------------------- | -------------------- | -------------------------------------------------------------------- |
| `Uuid58::InvalidLengthError`    | `:invalid_length`    | a string of the wrong length, or bytes whose length is not 16        |
| `Uuid58::InvalidCharacterError` | `:invalid_character` | a character not allowed in its position                              |
| `Uuid58::OverflowError`         | `:overflow`          | a value outside `0..2**128 - 1` (decoded string or encoded Integer)  |

Input that contains a non-ASCII character raises `InvalidLengthError` or
`InvalidCharacterError`, depending on the byte length.

```ruby
begin
  Uuid58.decode(user_input)
rescue Uuid58::InvalidCharacterError
  # ...
rescue Uuid58::Error => e
  e.kind # => :invalid_length or :overflow
end
```

Passing an unsupported type (for example `nil`, a `Float` or a `Symbol`)
raises `TypeError`. Error messages are not part of the specification and may
change.

## API

| Method                                  | Description                                                                |
| --------------------------------------- | -------------------------------------------------------------------------- |
| `Uuid58.encode(value) -> String`        | Encode a UUID string, a 16-byte `BINARY` string, or an `Integer`.          |
| `Uuid58.encode_bytes(bytes) -> String`  | Encode exactly 16 bytes, whatever the string's encoding.                   |
| `Uuid58.encode_int(int) -> String`      | Encode an `Integer` in `0..2**128 - 1`.                                    |
| `Uuid58.decode(str) -> String`          | Decode to the lowercase hyphenated UUID string.                            |
| `Uuid58.decode_bytes(str) -> String`    | Decode to 16 big-endian bytes (`Encoding::BINARY`).                        |
| `Uuid58.decode_int(str) -> Integer`     | Decode to an `Integer` in `0..2**128 - 1`.                                 |
| `Uuid58.valid?(str)`, `Uuid58.uuid58?`  | `true` exactly when `decode(str)` would succeed. Never raises.             |
| `Uuid58.generate -> String`             | Generate a random UUIDv4 (`SecureRandom`) and return its encoding.         |
| `ALPHABET`, `MAX_UUID58`, `MAX_INT`     | The Base58 alphabet, the largest valid uuid58 string, and `2**128 - 1`.    |

### Accepted UUID strings

`encode` accepts exactly two textual forms, in any letter case (SPEC.md
Section 5.1):

- hyphenated, 36 characters: `f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf`
- plain, 32 hex digits: `f4b247fd1f8745d4aa061c6fc0a8dfaf`

Everything else is rejected: braces, the `urn:uuid:` prefix, misplaced
hyphens, and surrounding whitespace or newlines.

## Development

Uses Ruby from [mise](https://mise.jdx.dev/) (pinned via `mise.toml`).

```bash
bundle install
bundle exec rake test   # tests, including spec/vectors.json conformance
bundle exec rake build  # build pkg/uuid58-x.y.z.gem
```

The conformance tests read `../spec/vectors.json`, so run them from a
checkout of the repository.

## License

MIT
