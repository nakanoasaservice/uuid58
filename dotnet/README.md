# uuid58 for .NET

[![CI](https://github.com/nakanoasaservice/uuid58/actions/workflows/ci-dotnet.yml/badge.svg)](https://github.com/nakanoasaservice/uuid58/actions/workflows/ci-dotnet.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/nakanoasaservice/uuid58/blob/main/LICENSE)

Shorten UUIDs to 22-character Base58 strings, and back, in C# and .NET.
Works with `Guid` in the standard RFC 9562 byte order, on .NET Standard 2.0
and later.

```text
f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf  ⇄  XDY9dmBbcMBXqcRvYw8xJ2
```

- **Fixed 22 characters**, using the Bitcoin Base58 alphabet: URL-safe, with
  no look-alike characters (`0`, `O`, `I`, `l`).
- **Sortable**: comparing uuid58 strings with `string.CompareOrdinal` gives
  the same order as comparing the UUIDs as unsigned 128-bit integers, so
  UUIDv7 IDs stay time-ordered.
- **Stable spec, well tested**: implements uuid58 spec 1.1.0 and passes its
  200+ shared test vectors, so the output matches every other language.
- **Correct `Guid` byte order**: converts `Guid` in RFC 9562 byte order, not
  the mixed-endian order of `Guid.ToByteArray()`, so `Guid` values agree with
  every other language.
- **No dependencies.** Targets .NET Standard 2.0, so it runs on .NET 5 and
  later, .NET Core 2.0 and later, .NET Framework 4.6.1 and later, Unity, and
  Xamarin.
- **Strict parsing**: rejects malformed UUIDs, non-ASCII input, and values
  above 128 bits, with an exception that tells you which kind of error it was.

[Try it in your browser](https://nakanoasaservice.github.io/uuid58/) ·
[Specification](https://github.com/nakanoasaservice/uuid58/blob/main/spec/SPEC.md) ·
[Other languages](https://github.com/nakanoasaservice/uuid58#install)

> **Status:** the library is 0.x, so its API may still change. The encoding
> itself follows spec 1.1.0, and the format does not change within spec 1.x.

## Installation

```bash
dotnet add package Uuid58
```

The package is not on NuGet yet; the command works once the first version is
published.

## Usage

```csharp
using NakanoAsAService.Uuid58;

// Encode
Uuid58.Encode(Guid.Parse("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf")); // "XDY9dmBbcMBXqcRvYw8xJ2"
Uuid58.EncodeUuidString("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf");  // "XDY9dmBbcMBXqcRvYw8xJ2"
Uuid58.EncodeUuidString("F4B247FD1F8745D4AA061C6FC0A8DFAF");      // "XDY9dmBbcMBXqcRvYw8xJ2"
Uuid58.Encode(bytes);       // byte[16], big-endian
Uuid58.Encode(high, low);   // two ulongs: the high and low 64 bits
Uuid58.Encode(bigInteger);  // System.Numerics.BigInteger in 0..2^128 - 1

// Decode
Uuid58.DecodeToGuid("XDY9dmBbcMBXqcRvYw8xJ2");  // Guid f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf
Uuid58.Decode("XDY9dmBbcMBXqcRvYw8xJ2");        // "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf"
Uuid58.DecodeToBytes("XDY9dmBbcMBXqcRvYw8xJ2"); // byte[16], big-endian

// Validate, or decode without exceptions
Uuid58.IsValid("XDY9dmBbcMBXqcRvYw8xJ2"); // true
if (Uuid58.TryDecodeToGuid(input, out Guid id)) { /* ... */ }

// Generate a random (version 4) UUID, encoded
string newId = Uuid58.Generate();

// Errors
try
{
    Uuid58.Decode(input);
}
catch (Uuid58Exception e)
{
    switch (e.Kind)
    {
        case Uuid58ErrorKind.InvalidLength:    /* not 22 characters */ break;
        case Uuid58ErrorKind.InvalidCharacter: /* not in the alphabet */ break;
        case Uuid58ErrorKind.Overflow:         /* greater than 2^128 - 1 */ break;
    }
}
```

## API

All members are static methods of `NakanoAsAService.Uuid58.Uuid58`. Passing
`null` throws `ArgumentNullException`, except to `IsValid` and
`TryDecodeToGuid`, which return `false`.

| Method                              | Returns  | Throws `Uuid58Exception` with              |
| ----------------------------------- | -------- | ------------------------------------------ |
| `Encode(Guid guid)`                 | `string` | never                                      |
| `Encode(ulong high, ulong low)`     | `string` | never                                      |
| `Encode(byte[] bytes)`              | `string` | `InvalidLength` (not 16 bytes)             |
| `Encode(BigInteger value)`          | `string` | `Overflow` (negative or above `2^128 - 1`) |
| `EncodeUuidString(string uuid)`     | `string` | `InvalidLength`, `InvalidCharacter`        |
| `Decode(string uuid58)`             | `string` | `InvalidLength`, `InvalidCharacter`, `Overflow` |
| `DecodeToGuid(string uuid58)`       | `Guid`   | same as `Decode`                           |
| `DecodeToBytes(string uuid58)`      | `byte[]` | same as `Decode`                           |
| `TryDecodeToGuid(string, out Guid)` | `bool`   | never                                      |
| `IsValid(string uuid58)`            | `bool`   | never                                      |
| `Generate()`                        | `string` | never                                      |

Constants: `Alphabet`, `Length` (22), and `Max` (`YcVfxkQb6JRzqk5kF2tNLv`,
the largest valid uuid58 string).

`Uuid58Exception` derives from `FormatException`. `Kind` is a
`Uuid58ErrorKind`, one of the error kinds of the specification (Section 7);
`SpecName` gives its name in the specification, such as `"invalid_length"`.
Error messages are not part of the API.

### Byte order and `Guid`

`Guid.ToByteArray()` and `new Guid(byte[])` store the first three fields
little-endian, so `Guid.Parse("00112233-4455-6677-8899-aabbccddeeff").ToByteArray()`
starts with `33 22 11 00`. This library always uses the RFC 9562 order
(`00 11 22 33 ...`), which is what the UUID's text form shows and what every
other uuid58 implementation uses. `Encode(Guid)` and `DecodeToGuid` handle the
conversion; byte arrays passed to or returned from this library are always in
RFC 9562 order.

### Accepted UUID strings

`EncodeUuidString` accepts exactly two forms, in upper, lower, or mixed case:

- hyphenated, 36 characters: `f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf`
- plain, 32 hexadecimal digits: `f4b247fd1f8745d4aa061c6fc0a8dfaf`

Everything else is rejected, including braces, parentheses, `urn:uuid:`,
whitespace, and hyphens in other positions. This is stricter than
`Guid.Parse`, which also accepts `{...}`, `(...)`, and the `X` format. To
accept those, parse with `Guid.Parse` and pass the result to `Encode(Guid)`.

`Decode` always produces the lowercase hyphenated form, the same as
`Guid.ToString()`.

### Sorting

Comparing uuid58 strings with `string.CompareOrdinal` (or
`StringComparer.Ordinal`) gives the same order as comparing the 128-bit values
as unsigned integers. Culture-sensitive comparison, the default for
`string.Compare` and `List<string>.Sort()`, does not. In a database, use a
binary collation (for example `Latin1_General_BIN2` in SQL Server). Note that
SQL Server sorts `uniqueidentifier` columns in its own byte order, which
differs from this one.

## Compatibility

This package implements
[uuid58 specification](https://github.com/nakanoasaservice/uuid58/blob/main/spec/SPEC.md)
1.0.0 and passes every case in
[`spec/vectors.json`](https://github.com/nakanoasaservice/uuid58/blob/main/spec/vectors.json),
so its output is identical to the
[other implementations](https://github.com/nakanoasaservice/uuid58#install)
(JavaScript, Go, Python, Rust, PostgreSQL, and more).

## Development

Requires the .NET SDK 8 or later.

```bash
dotnet build
dotnet test                       # includes ../spec/vectors.json
dotnet format --verify-no-changes
dotnet pack src/Uuid58 -c Release
```

The tests read `../spec/vectors.json`, so run them from a checkout of the
whole repository. Pass `-p:TestTargetFramework=net10.0` to run them on
another runtime (the default is `net8.0`).

### Releasing

1. Bump `<Version>` in `dotnet/src/Uuid58/Uuid58.csproj` and merge it into main.
2. `git tag dotnet/v0.1.0 <commit on main> && git push origin dotnet/v0.1.0`

[`publish-dotnet.yml`](https://github.com/nakanoasaservice/uuid58/blob/main/.github/workflows/publish-dotnet.yml)
then runs the tests, publishes the package to NuGet, and creates a GitHub
Release.

## License

[MIT](https://github.com/nakanoasaservice/uuid58/blob/main/dotnet/LICENSE)
