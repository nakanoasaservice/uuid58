# uuid58

[![CI](https://github.com/nakanoasaservice/uuid58/actions/workflows/ci.yml/badge.svg)](https://github.com/nakanoasaservice/uuid58/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**Shorten UUIDs to 22-character Base58 strings, and back.** uuid58 is a
stable, well-tested encoding with one spec and libraries for JavaScript, Go,
Python, Rust, Java, Kotlin, Swift, C#, PHP, Ruby, Dart, Elixir, PostgreSQL, and
MySQL.

```text
f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf  ⇄  XDY9dmBbcMBXqcRvYw8xJ2
```

**[Try the converter in your browser →](https://nakanoasaservice.github.io/uuid58/)**

## Why uuid58

- **Short and fixed-length.** Always 22 characters instead of 36. Validate
  with one length check, and store in a fixed-width column such as `CHAR(22)`.
- **URL-safe, no look-alikes.** Uses the Bitcoin Base58 alphabet: nothing to
  escape in URLs, and no `0`, `O`, `I`, or `l` to misread.
- **Sortable.** Strings sort in the same order as the UUIDs they encode, so
  UUIDv7 IDs stay time-ordered.
- **Still a UUID.** Conversion is lossless both ways. Keep UUID columns in
  your database, and show uuid58 in URLs, APIs, and logs.
- **Same output everywhere.** A string made in Go decodes to the same UUID in
  Python, Rust, PostgreSQL, or MySQL.

## Stable and well tested

- **[Spec 1.1.0](spec/SPEC.md)** defines the alphabet, the padding, every
  accepted input, and every error kind. The format will not change within
  1.x.
- **[Shared test vectors](spec/vectors.json)**: over 200 cases, 120 of them
  invalid inputs. Every implementation runs them in CI.
- **[Formal proofs](formal/)** go beyond tests: the core guarantees hold for
  every UUID, not just the cases we wrote down.

## Install

| Language                                                  | Install                                        | Package                                                                                         |
| --------------------------------------------------------- | ---------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| [JavaScript / TypeScript](js/)                            | `npm i @nakanoaas/uuid58`                      | [npm](https://www.npmjs.com/package/@nakanoaas/uuid58), [JSR](https://jsr.io/@nakanoaas/uuid58) |
| [Go](go/)                                                 | `go get github.com/nakanoasaservice/uuid58/go` | [pkg.go.dev](https://pkg.go.dev/github.com/nakanoasaservice/uuid58/go)                          |
| [Python](python/)                                         | `pip install uuid58`                           | [PyPI](https://pypi.org/project/uuid58/)                                                        |
| [Rust](rust/)                                             | `cargo add uuid58`                             | [crates.io](https://crates.io/crates/uuid58)                                                    |
| [Java / Kotlin](java/)                                    | `io.github.nakanoasaservice:uuid58`            | [Maven Central](https://central.sonatype.com/artifact/io.github.nakanoasaservice/uuid58)        |
| [Swift](https://github.com/nakanoasaservice/uuid58-swift) | Swift Package Manager                          | [uuid58-swift](https://github.com/nakanoasaservice/uuid58-swift)                                |
| [PostgreSQL](postgres/)                                   | One SQL file, no extension                     | [`uuid58.sql`](postgres/uuid58.sql)                                                             |
| [MySQL / MariaDB](mysql/)                                 | One SQL file, no extension                     | [`uuid58.sql`](mysql/uuid58.sql)                                                                |
| [C# / .NET](dotnet/)                                      | `dotnet add package Uuid58`                    | [NuGet](https://www.nuget.org/packages/Uuid58)                                                    |
| [PHP](https://github.com/nakanoasaservice/uuid58-php)                                               | `composer require nakanoaas/uuid58`     | [Packagist](https://packagist.org/packages/nakanoaas/uuid58)                                                                    |
| [Ruby](ruby/)                                             | `bundle add uuid58`                            | [RubyGems](https://rubygems.org/gems/uuid58)                                                                     |
| [Dart / Flutter](dart/)                                   | `dart pub add uuid58`                          | [pub.dev](https://pub.dev/packages/uuid58)                                                                      |
| [Elixir](elixir/)                                         | `{:uuid58, "~> 0.1.1"}`                        | [Hex](https://hex.pm/packages/uuid58)                                                           |
| [CLI](go/cmd/uuid58/)                                     | `brew install nakanoasaservice/tap/uuid58`     | Homebrew, `nix run github:nakanoasaservice/uuid58`, or `go install`                             |

Each language links to its README with usage and API details. Swift and PHP have their own repositories because Swift Package Manager and
Packagist expect their package manifests at the repository root. The JavaScript package follows the spec from 2.0; 1.x
accepts hyphens anywhere in its input, which the spec does not allow.

## How uuid58 compares

| Option             | Length | Still a UUID? | Notes                                                                                    |
| ------------------ | ------ | ------------- | ---------------------------------------------------------------------------------------- |
| **uuid58**         | 22     | Yes           | Bitcoin Base58, fixed length, sortable, one spec across languages.                       |
| Standard UUID      | 36     | Yes           | Long, and the hyphens stop a double-click from selecting the whole ID.                   |
| short-uuid (npm)   | 22     | Yes           | Flickr Base58 by default: a different alphabet order, so its strings differ from uuid58. |
| shortuuid (Python) | 22     | Yes           | A 57-character alphabet; its strings differ from uuid58.                                 |
| slugid             | 22     | Yes           | URL-safe Base64, so IDs can contain `-` and `_`.                                         |
| ULID               | 26     | No            | Its own format (Crockford Base32), 128-bit compatible with UUID but written differently. |
| Nano ID            | 21     | No            | Random IDs, not UUIDs. Nothing to convert back to.                                       |
| Firestore auto-ID  | 20     | No            | Random alphanumeric IDs from the Firestore SDKs. Not sortable, nothing to convert back.  |
| Sqids              | Varies | No            | Encodes integers such as database row IDs, not UUIDs. Length grows with the number.      |

Pick uuid58 when you already use UUIDs (or want to), need them short in URLs
and APIs, and want every service and language to agree on the string.

## FAQ

<details>
<summary>Will the format change?</summary>

No. Spec 1.1.0 fixes the alphabet, the padding, and the accepted inputs. Any
change that would alter an encoded string needs a new major version of the
spec, and every implementation is tested against the same versioned vectors.

</details>

<details>
<summary>Does it work with UUIDv7?</summary>

Yes. uuid58 encodes any 128-bit UUID, and strings sort in the same order as
the UUIDs, so UUIDv7 IDs stay time-ordered when sorted as strings.

</details>

<details>
<summary>Can I use uuid58 for Firestore document IDs?</summary>

Yes. uuid58 strings meet Firestore's document ID rules. Use random (v4)
UUIDs: Firestore advises against sequential IDs, which can cause write
hotspots. If you later move to a relational database, decode each ID into a
UUID column; references between records carry over as they are.

</details>

<details>
<summary>What exactly is formally verified?</summary>

The spec's guarantees: decoding an encoded UUID returns it unchanged, every
encoding is 22 characters, and string order matches UUID order. Lean also
proves that the JavaScript library's public functions and the Rust library's
numeric codec, validator, UUID text parser, and UUID text formatter follow
the spec for every input. Rust's `decode_to_uuid_buf` writes and returns the
canonical UUID on success and preserves the caller's buffer on error. The
proofs are rechecked against the current source on every change. The other
libraries are checked with the shared test vectors. See
[formal/](formal/) for proof scope and trust assumptions.

</details>

<details>
<summary>I found a 22-character ID like <code>XDY9dmBbcMBXqcRvYw8xJ2</code>. Is it uuid58?</summary>

If it uses only Base58 characters (no `0`, `O`, `I`, `l`) and decodes in the
[converter](https://nakanoasaservice.github.io/uuid58/), it is likely a
uuid58-encoded UUID.

</details>

## Website

[`site/`](site/) is the website at
<https://nakanoasaservice.github.io/uuid58/>. It builds against the library
source in `js/`, so it always matches `main`. Run it locally with
`pnpm install && pnpm dev` in `site/`. Pushes to `main` that touch `site/`,
`js/`, or `spec/` deploy it with the Pages workflow.

## Releases

Each implementation is released on its own, with tags prefixed by its
directory, such as `js/v1.2.3`. Swift and PHP releases use version tags in their own repositories,
`uuid58-swift` and `uuid58-php`.

## License

MIT License. See [LICENSE](LICENSE).
