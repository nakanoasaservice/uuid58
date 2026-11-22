# uuid58 for JavaScript and TypeScript

[![npm](https://img.shields.io/npm/v/@nakanoaas/uuid58.svg)](https://www.npmjs.com/package/@nakanoaas/uuid58)
[![JSR](https://jsr.io/badges/@nakanoaas/uuid58)](https://jsr.io/@nakanoaas/uuid58)
[![CI](https://github.com/nakanoasaservice/uuid58/actions/workflows/ci-js.yml/badge.svg)](https://github.com/nakanoasaservice/uuid58/actions/workflows/ci-js.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/nakanoasaservice/uuid58/blob/main/LICENSE)

Shorten UUIDs to 22-character Base58 strings, and back, in JavaScript and
TypeScript. Works in Node.js, Deno, and browsers, with no dependencies.

```text
f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf  ⇄  XDY9dmBbcMBXqcRvYw8xJ2
```

- **Fixed 22 characters**, using the Bitcoin Base58 alphabet: URL-safe, with
  no `0`, `O`, `I`, or `l` to misread.
- **Sortable**: sorting uuid58 strings with the default string comparison
  sorts the UUIDs they encode, so UUIDv7 IDs stay time-ordered.
- **Stable spec, well tested**: implements uuid58 spec 1.1.0 and passes its
  200+ shared test vectors, so the output matches every other language.
- **Fast**: encodes in about 0.5 µs and decodes in about 0.3 µs on Node.js,
  roughly 10× faster than short-uuid and 3× faster than bs58, with full
  validation. No BigInt; 32-bit integer arithmetic only.
  [Benchmarks](#performance).
- **Tiny and zero-dependency**: ESM and CommonJS, with TypeScript types.
- **Safe APIs** that return an error object instead of throwing, and
  `crypto.getRandomValues()` for generating new IDs.

[Try it in your browser](https://nakanoasaservice.github.io/uuid58/) ·
[Specification](https://github.com/nakanoasaservice/uuid58/blob/main/spec/SPEC.md) ·
[Other languages](https://github.com/nakanoasaservice/uuid58#install)

## Install

### Node.js

```bash
npm install @nakanoaas/uuid58
```

Or with another package manager:

```bash
pnpm add @nakanoaas/uuid58
yarn add @nakanoaas/uuid58
```

### Deno

```bash
deno add @nakanoaas/uuid58
```

## Usage

```typescript
import { uuid58, uuid58Decode, uuid58Encode } from "@nakanoaas/uuid58";

uuid58Encode("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf"); // "XDY9dmBbcMBXqcRvYw8xJ2"
uuid58Decode("XDY9dmBbcMBXqcRvYw8xJ2"); // "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf"
uuid58(); // a new random UUID, encoded (22 characters)
```

### Without exceptions

The `Safe` variants return an error object instead of throwing:

```typescript
import {
  Uuid58DecodeError,
  uuid58DecodeSafe,
  Uuid58EncodeError,
  uuid58EncodeSafe,
} from "@nakanoaas/uuid58";

const encoded = uuid58EncodeSafe("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf");
if (encoded instanceof Uuid58EncodeError) {
  console.error(encoded.kind, encoded.message);
} else {
  console.log(encoded); // 22 characters
}

const decoded = uuid58DecodeSafe("XDY9dmBbcMBXqcRvYw8xJ2");
if (decoded instanceof Uuid58DecodeError) {
  console.error(decoded.kind, decoded.message);
} else {
  console.log(decoded); // "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf"
}
```

### Validation

```typescript
import { isUuid58, UUID58_REGEX } from "@nakanoaas/uuid58";

isUuid58("XDY9dmBbcMBXqcRvYw8xJ2"); // true
isUuid58("invalid"); // false

// Format only (length and alphabet); see the note under UUID58_REGEX.
UUID58_REGEX.test("XDY9dmBbcMBXqcRvYw8xJ2"); // true
```

## API Reference

### `uuid58()`

Generates a random UUIDv4 with `crypto.getRandomValues()` and returns its
22-character uuid58 encoding. Decoding recovers the same UUIDv4.

```typescript
function uuid58(): string; // always returns a 22-character string
```

### `uuid58Encode(uuid: string)`

Converts a standard UUID string to a 22-character uuid58 string.

```typescript
function uuid58Encode(uuid: string): string; // always returns a 22-character string
```

- **Parameters:**
  - `uuid`: The UUID string to encode: hyphenated
    (`xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`) or 32 hexadecimal digits, in any
    letter case. Other forms (braces, `urn:uuid:`, whitespace, hyphens in other
    positions) are rejected.
- **Returns:** A 22-character uuid58 string
- **Throws:** `Uuid58EncodeError` if the input is not a valid UUID

### `uuid58EncodeSafe(uuid: string)`

Like `uuid58Encode`, but returns an `Uuid58EncodeError` instance instead of
throwing for invalid input.

```typescript
function uuid58EncodeSafe(uuid: string): string | Uuid58EncodeError; // string is always 22 characters
```

- **Parameters:**
  - `uuid`: The UUID string to encode (same forms as `uuid58Encode`)
- **Returns:** A 22-character uuid58 string, or an `Uuid58EncodeError` if the
  input is not a valid UUID
- **Note:** This function does not throw; it returns the error object instead.

### `uuid58Decode(uuid58: string)`

Converts a 22-character uuid58 string back to a standard UUID string.

```typescript
function uuid58Decode(uuid58: string): string;
```

- **Parameters:**
  - `uuid58`: The 22-character uuid58 string to decode
- **Returns:** A standard UUID string (lowercase, with hyphens)
- **Throws:** `Uuid58DecodeError` if the input is not a valid uuid58 string

### `uuid58DecodeSafe(uuid58: string)`

Like `uuid58Decode`, but returns an `Uuid58DecodeError` instance instead of
throwing for invalid input.

```typescript
function uuid58DecodeSafe(uuid58: string): string | Uuid58DecodeError;
```

- **Parameters:**
  - `uuid58`: The 22-character uuid58 string to decode
- **Returns:** A standard UUID string (lowercase, with hyphens), or an
  `Uuid58DecodeError` if the input is not a valid uuid58 string
- **Note:** This function does not throw; it returns the error object instead.

### `uuid58EncodeBytes(bytes: Uint8Array)` / `uuid58EncodeBytesSafe`

Encodes 16 bytes, in big-endian (RFC 9562) order, as a 22-character string.

```typescript
function uuid58EncodeBytes(bytes: Uint8Array): string;
function uuid58EncodeBytesSafe(bytes: Uint8Array): string | Uuid58EncodeError;
```

- **Throws / returns:** `Uuid58EncodeError` with kind `"invalid_length"` if
  `bytes` is not exactly 16 bytes long

### `uuid58DecodeBytes(uuid58: string)` / `uuid58DecodeBytesSafe`

Decodes a 22-character string to a new 16-byte `Uint8Array` in big-endian
(RFC 9562) order.

```typescript
function uuid58DecodeBytes(uuid58: string): Uint8Array;
function uuid58DecodeBytesSafe(uuid58: string): Uint8Array | Uuid58DecodeError;
```

- **Throws / returns:** `Uuid58DecodeError`, as for `uuid58Decode`

### Error Classes

Both error classes have a `kind` property with the error kind defined by the
[specification](https://github.com/nakanoasaservice/uuid58/blob/main/spec/SPEC.md)
(type `Uuid58ErrorKind`). Use it instead of parsing the message, which may
change.

| `kind`                | Meaning                                                                        |
| --------------------- | ------------------------------------------------------------------------------ |
| `"invalid_length"`    | Wrong length: not 32 or 36 characters (UUID), not 22 (uuid58), or not 16 bytes |
| `"invalid_character"` | Right length, but a character not allowed in its position                      |
| `"overflow"`          | (decoding only) Well formed, but the value is greater than 2^128 − 1           |

```typescript
const result = uuid58DecodeSafe(input);
if (result instanceof Uuid58DecodeError && result.kind === "overflow") {
  // ...
}
```

#### `Uuid58EncodeError`

Error thrown when an invalid UUID string or byte array is provided for
encoding. `kind` is `"invalid_length"` or `"invalid_character"`.

```typescript
class Uuid58EncodeError extends Error {
  readonly kind: "invalid_length" | "invalid_character";
}
```

#### `Uuid58DecodeError`

Error thrown when an invalid string is provided for decoding. `kind` is
`"invalid_length"`, `"invalid_character"`, or `"overflow"`.

```typescript
class Uuid58DecodeError extends Error {
  readonly kind: Uuid58ErrorKind;
}
```

### `isUuid58(uuid58: string)`

Checks whether a string is a valid uuid58 string, without fully decoding it.

```typescript
function isUuid58(uuid58: string): boolean;
```

- **Parameters:**
  - `uuid58`: The string to check
- **Returns:** `true` if the string is a valid uuid58 string, `false` otherwise
- **Note:** This function validates:
  - Length (must be exactly 22 characters)
  - Base58 alphabet characters only
  - That the decoded value fits within 128 bits (UUID size)

**Example:**

```typescript
import { isUuid58 } from "@nakanoaas/uuid58";

isUuid58("XDY9dmBbcMBXqcRvYw8xJ2"); // true
isUuid58("invalid"); // false
isUuid58("O0lI"); // false (contains invalid characters)
isUuid58("short"); // false (too short)
```

### Alphabet and Utilities

#### `UUID58_ALPHABET`

The Base58 character set (Bitcoin compatible). It leaves out characters that
are easily confused: `0` (zero) and `O` (capital O), `I` (capital i) and `l`
(lowercase L). The alphabet consists of 58 characters: digits 1-9 and letters
A-Z, a-z (excluding the ambiguous characters above).

```typescript
const UUID58_ALPHABET: string; // "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
```

#### `UUID58_REGEX`

Regular expression for the uuid58 format: exactly 22 characters from the
Base58 alphabet.

```typescript
const UUID58_REGEX: RegExp; // /^[1-9A-HJ-NP-Za-km-z]{22}$/u
```

**Note:** `UUID58_REGEX` checks the format only. `isUuid58()` also checks that
the decoded value fits within 128 bits. For simple format checks, the regex is
sufficient; for complete validation, use `isUuid58()`.

**Example:**

```typescript
import { UUID58_REGEX } from "@nakanoaas/uuid58";

UUID58_REGEX.test("XDY9dmBbcMBXqcRvYw8xJ2"); // true
UUID58_REGEX.test("invalid"); // false
UUID58_REGEX.test("123"); // false (too short)
```

## Performance

Encoding and decoding a UUID string, compared with short-uuid and with
Base58-encoding the bytes yourself using bs58:

| Operation | uuid58      | short-uuid   | bs58 + hex   |
| --------- | ----------- | ------------ | ------------ |
| Encode    | ~2.3M ops/s | ~0.18M ops/s | ~0.59M ops/s |
| Decode    | ~3.3M ops/s | ~0.15M ops/s | ~0.89M ops/s |

Measured on Node.js 22, Intel Xeon 2.1 GHz; numbers vary by machine.
short-uuid 6.0.3 uses its default Flickr Base58 alphabet. bs58 6.0.0 is used
with hex conversion and does no padding or strict validation, so it does less
work than uuid58. Reproduce with `pnpm bench:compare` in `js/` (see
[`bench/compare.bench.ts`](https://github.com/nakanoasaservice/uuid58/blob/main/js/bench/compare.bench.ts)).

## Why uuid58?

Standard UUIDs are 36 characters long, which is cumbersome in URLs, APIs, and
logs. uuid58 writes the same UUID in a fixed 22 characters that are URL-safe
and easy to read, and you can always convert back. See
[how uuid58 compares](https://github.com/nakanoasaservice/uuid58#how-uuid58-compares)
with short-uuid, ULID, Nano ID, and other options.

## Compatibility

This package implements
[uuid58 specification](https://github.com/nakanoasaservice/uuid58/blob/main/spec/SPEC.md)
1.0.0 and passes its shared
[test vectors](https://github.com/nakanoasaservice/uuid58/blob/main/spec/vectors.json),
so it produces the same strings as the Go, Python, Rust, PostgreSQL, and other
implementations.

It follows the spec fully since 2.0. 1.x accepted hyphens anywhere in the
input of `uuid58Encode` (see Section 9.1 of the spec).

## Migrating from 1.x

2.0 has two breaking changes:

- **Stricter UUID input.** `uuid58Encode` and `uuid58EncodeSafe` accept only
  the hyphenated form (`xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`) and 32
  hexadecimal digits. 1.x removed every hyphen first, so inputs such as
  `f4b247f-d1f87-45d4-aa06-1c6fc0a8dfaf` or `f4b247fd-1f8745d4aa061c6fc0a8dfaf`
  were accepted; they are now rejected. Normalize such input yourself before
  encoding if you need it, for example with `uuid.replace(/-/g, "")`.
- **Error constructors** take a second argument, the error kind
  (`new Uuid58EncodeError(message, kind)`). This matters only if you
  construct these errors yourself.

New in 2.0: the `kind` property on errors, and `uuid58EncodeBytes` /
`uuid58DecodeBytes` for `Uint8Array`.

## Development

This package lives in the
[`js/`](https://github.com/nakanoasaservice/uuid58/tree/main/js) directory of
the repository and uses [Vite+](https://viteplus.dev/) (`vp`) and pnpm. Run
these commands in `js/`:

```bash
pnpm install
pnpm check           # format, lint and type check
pnpm test            # run tests, including the spec's conformance vectors
pnpm bench           # build and benchmark against a saved baseline
pnpm bench:compare   # build and benchmark against short-uuid and bs58
pnpm build           # build the npm package into dist/
```

See
[`bench/README.md`](https://github.com/nakanoasaservice/uuid58/blob/main/js/bench/README.md)
for the benchmark workflow.

The version lives only in `package.json`. `jsr.json` is generated from it
by `vp pack` and is not committed.

### Releasing

1. Bump `version` in `js/package.json` and merge the change into `main`.
2. Tag that commit with a `js/` prefix and push the tag:

   ```bash
   git tag js/v1.2.3 && git push origin js/v1.2.3
   ```

The `Publish` workflow then checks that the tag matches `js/package.json` and
is on `main`, runs the tests, publishes to JSR and npm, and creates the
GitHub Release.

## License

MIT License. See
[LICENSE](https://github.com/nakanoasaservice/uuid58/blob/main/LICENSE).

### Runtime versions

`package.json` is the source of truth for development Node.js (`devEngines.runtime`)
and pnpm (`packageManager`). The major versions in `mise.toml` only bootstrap the
environment. Install the [global Vite+ CLI](https://viteplus.dev/guide/global-cli)
with environment management enabled, then use `vp install --frozen-lockfile`
and `vp run <script>` to run with the declared versions. `pnpm` commands also use
them when the Vite+ shims are active. The project-local CLI alone does not switch
Node.js versions.

CI reads the same manifest automatically; compatibility-test matrices explicitly
override Node.js. pnpm runtime management is disabled so it does not override
Vite+'s selection. Keep any consumer-facing `engines.node` support range separate
from the development pin.
