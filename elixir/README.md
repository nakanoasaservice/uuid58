# uuid58 for Elixir

[![CI](https://github.com/nakanoasaservice/uuid58/actions/workflows/ci-elixir.yml/badge.svg)](https://github.com/nakanoasaservice/uuid58/actions/workflows/ci-elixir.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/nakanoasaservice/uuid58/blob/main/LICENSE)

Shorten UUIDs to 22-character Base58 strings, and back, in Elixir. Give
Phoenix and Ecto records with UUID primary keys short, URL-safe IDs.

```text
f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf  ⇄  XDY9dmBbcMBXqcRvYw8xJ2
```

- **Fixed 22 characters**, using the Bitcoin Base58 alphabet: URL-safe, with
  no `0`, `O`, `I`, or `l`.
- **Sortable**: sorting uuid58 strings byte by byte sorts the UUIDs
  numerically, so UUIDv7 IDs stay time-ordered. `Enum.sort/1` does this.
- **Stable spec, well tested**: implements
  [uuid58 spec 1.1.0](https://github.com/nakanoasaservice/uuid58/blob/main/spec/SPEC.md)
  and passes its 200+ shared
  [test vectors](https://github.com/nakanoasaservice/uuid58/blob/main/spec/vectors.json),
  so output matches every other language.
- **No runtime dependencies.** Requires Elixir 1.16 or later.

[Try it in your browser](https://nakanoasaservice.github.io/uuid58/) ·
[Specification](https://github.com/nakanoasaservice/uuid58/blob/main/spec/SPEC.md) ·
[Other languages](https://github.com/nakanoasaservice/uuid58#install)

## Install

Add `uuid58` to `mix.exs`:

```elixir
def deps do
  [
    {:uuid58, "~> 0.1.1"}
  ]
end
```

Available on [Hex](https://hex.pm/packages/uuid58), with API documentation
on [HexDocs](https://uuid58.hexdocs.pm/).

## Usage

```elixir
s = "XDY9dmBbcMBXqcRvYw8xJ2"

# All of these return {:ok, s}:
Uuid58.encode("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf")
Uuid58.encode("F4B247FD1F8745D4AA061C6FC0A8DFAF") # plain hex, any case
Uuid58.encode(0xF4B247FD1F8745D4AA061C6FC0A8DFAF)

raw = Base.decode16!("f4b247fd1f8745d4aa061c6fc0a8dfaf", case: :lower)
Uuid58.encode_bytes(raw) # {:ok, s}

Uuid58.decode(s) # {:ok, "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf"}
Uuid58.decode_bytes(s) # {:ok, <<244, 178, 71, 253, ...>>}
Uuid58.decode_integer(s) # {:ok, 325257319917903217740243107280071483311}

Uuid58.valid?("XDY9dmBbcMBXqcRvYw8xJ2") # true
Uuid58.valid?("zzzzzzzzzzzzzzzzzzzzzz") # false: exceeds 128 bits

Uuid58.encode!("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf") # s, or raises
Uuid58.generate() # a random UUIDv4, encoded, e.g. "Tj5D5H2Bc1LcPjwNNhH4xS"
```

Keep the UUID in the database and show uuid58 in URLs, APIs, and logs.
`Ecto.Schema` with `:binary_id` loads `id` as the hyphenated string, so
`Uuid58.encode!/1` takes it directly. The 16 bytes from `Ecto.UUID.dump/1`
go through `encode_bytes/1`. A 16-byte binary passed to `encode/1` is read as
UUID text and rejected.

### Phoenix

```elixir
defimpl Phoenix.Param, for: MyApp.Post do
  def to_param(%{id: id}), do: Uuid58.encode!(id)
end
```

Verified routes call `Phoenix.Param` on an interpolated struct, so pass the
struct. A bare `post.id` is a string and is used as written, so encode it
yourself:

```elixir
~p"/posts/#{post}"
~p"/posts/#{Uuid58.encode!(post.id)}"
```

When looking a record up, decode first. `decode/1` returns
`{:error, kind}` for a malformed parameter, which is straightforward to turn
into a 404:

```elixir
def show(conn, %{"id" => param}) do
  with {:ok, uuid} <- Uuid58.decode(param),
       %MyApp.Post{} = post <- MyApp.Repo.get(MyApp.Post, uuid) do
    render(conn, :show, post: post)
  else
    _ -> Plug.Conn.send_resp(conn, :not_found, "Not found")
  end
end
```

### Errors

The plain functions return `{:error, kind}`. The bang functions raise
`Uuid58.Error`, and `kind` is the spec error kind
([SPEC.md section 7](https://github.com/nakanoasaservice/uuid58/blob/main/spec/SPEC.md#7-errors)):

| `kind`               | When                                                                |
| -------------------- | ------------------------------------------------------------------- |
| `:invalid_length`    | a string of the wrong length, or bytes whose length is not 16      |
| `:invalid_character` | a character not allowed in its position                             |
| `:overflow`          | a value outside `0..2**128 - 1` (decoded string or encoded integer) |

Input that contains a non-ASCII byte fails with `:invalid_length` or
`:invalid_character`, depending on the byte length. Length is measured in
bytes, not graphemes (`String.length/1` is not used).

```elixir
case Uuid58.decode(user_input) do
  {:ok, uuid} -> uuid
  {:error, :invalid_character} -> :bad_character
  {:error, kind} -> kind
end
```

Passing an unsupported type (for example `nil`, a float, or an atom) raises
`FunctionClauseError`. `valid?/1` returns `false` instead of raising.
Error messages are not part of the specification and may change. They leave
the input out, and may include its length or the position of the first
invalid byte.

## API

| Function                                      | Description                                                              |
| --------------------------------------------- | ------------------------------------------------------------------------ |
| `encode/1`, `encode!/1`                       | Encode a UUID string or an integer in `0..2**128 - 1`.                   |
| `encode_bytes/1`, `encode_bytes!/1`           | Encode exactly 16 big-endian bytes.                                      |
| `encode_integer/1`, `encode_integer!/1`       | Encode an integer in `0..2**128 - 1`.                                    |
| `decode/1`, `decode!/1`                       | Decode to the lowercase hyphenated UUID string.                          |
| `decode_bytes/1`, `decode_bytes!/1`           | Decode to 16 big-endian bytes.                                           |
| `decode_integer/1`, `decode_integer!/1`       | Decode to an integer in `0..2**128 - 1`.                                 |
| `valid?/1`                                    | `true` exactly when `decode/1` would succeed. Never raises.              |
| `generate/0`                                  | Generate a random UUIDv4 and return its encoding.                        |
| `alphabet/0`, `max_uuid58/0`, `max_integer/0` | The Base58 alphabet, the largest valid string, and `2**128 - 1`.         |
| `Uuid58.Error`                                | Exception raised by the bang functions. See [Errors](#errors).           |

### Accepted UUID strings

`encode/1` accepts exactly two textual forms, in any letter case
([SPEC.md section 5.1](https://github.com/nakanoasaservice/uuid58/blob/main/spec/SPEC.md#51-accepted-forms)):

- hyphenated, 36 characters: `f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf`
- plain, 32 hex digits: `f4b247fd1f8745d4aa061c6fc0a8dfaf`

Everything else is rejected: braces, the `urn:uuid:` prefix, misplaced
hyphens, and surrounding whitespace or newlines.

## Compatibility

This package implements
[uuid58 spec 1.1.0](https://github.com/nakanoasaservice/uuid58/blob/main/spec/SPEC.md)
and passes every case in
[`spec/vectors.json`](https://github.com/nakanoasaservice/uuid58/blob/main/spec/vectors.json)
in CI. A string encoded here decodes to the same UUID with every other
[uuid58 implementation](https://github.com/nakanoasaservice/uuid58#install),
and the reverse.

The Hex package [`shortuuid`](https://hex.pm/packages/shortuuid) uses a
57-character alphabet, so its strings differ.
`550e8400-e29b-41d4-a716-446655440000` is `H9cNmGXLEc8NWcZzSThA9S` there and
`BWBeN28Vb7cMEx7Ym8AUzs` here. Do not mix the two strings.

## Development

Uses Elixir and Erlang from [mise](https://mise.jdx.dev/) (pinned via
`mise.toml`).

```bash
mix deps.get
mix format --check-formatted
mix test          # includes spec/vectors.json
mix docs --warnings-as-errors
mix hex.build     # build uuid58-x.y.z.tar
```

The conformance tests read `../spec/vectors.json`, so run them from a
checkout of the repository.

## License

MIT. See
[LICENSE](https://github.com/nakanoasaservice/uuid58/blob/main/LICENSE).
