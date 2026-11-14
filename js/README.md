# uuid58

[![JSR](https://jsr.io/badges/@nakanoaas/uuid58)](https://jsr.io/@nakanoaas/uuid58)
[![npm](https://badge.fury.io/js/@nakanoaas%2Fuuid58.svg)](https://badge.fury.io/js/@nakanoaas%2Fuuid58)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A tiny, zero-dependency library for generating and converting UUIDs to
Base58-encoded strings (using Bitcoin-style alphabet). Perfect for creating
shorter, URL-safe identifiers while maintaining the uniqueness of UUIDs.

## Features

- 🚀 Generate short, URL-safe identifiers (**fixed 22 characters**)
- 🔄 Bidirectional conversion between UUID and Base58
- 🪶 Zero dependencies
- 💪 Type-safe with TypeScript
- 🔒 Uses native `crypto.getRandomValues()` for secure UUID generation
- 📦 Supports both ESM and CommonJS
- 🛡️ Provides safe APIs that return error objects instead of throwing exceptions

## Try it out!

[uuid58 website](https://nakanoasaservice.github.io/uuid58/) - Try
generating, encoding, and decoding UUID58 in real-time!

## Installation

### Deno

```bash
deno add @nakanoaas/uuid58
```

### Node.js

Using npm:

```bash
npm install @nakanoaas/uuid58
```

Using yarn:

```bash
yarn add @nakanoaas/uuid58
```

Using pnpm:

```bash
pnpm add @nakanoaas/uuid58
```

## Usage

```typescript
import { uuid58, uuid58Decode, uuid58Encode } from "@nakanoaas/uuid58";

// Generate a new Base58-encoded UUID (always 22 characters)
const id = uuid58();
// => "XDY9dmBbcMBXqcRvYw8xJ2" (22 characters)

// Convert existing UUID to Base58 (always 22 characters)
const encoded = uuid58Encode("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf");
// => "XDY9dmBbcMBXqcRvYw8xJ2" (22 characters)

// Convert Base58 back to UUID
const decoded = uuid58Decode("XDY9dmBbcMBXqcRvYw8xJ2");
// => "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf"

import {
  Uuid58DecodeError,
  uuid58DecodeSafe,
  Uuid58EncodeError,
  uuid58EncodeSafe,
} from "@nakanoaas/uuid58";

// Safe encoding: returns error object instead of throwing
const encodedSafe = uuid58EncodeSafe("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf");
if (encodedSafe instanceof Uuid58EncodeError) {
  // handle error
  console.error(encodedSafe.message);
  return;
}
// use encoded string (22 characters)
console.log(encodedSafe);

// Safe decoding: returns error object instead of throwing
const decodedSafe = uuid58DecodeSafe("XDY9dmBbcMBXqcRvYw8xJ2");
if (decodedSafe instanceof Uuid58DecodeError) {
  // handle error
  console.error(decodedSafe.message);
  return;
}
// use decoded UUID
console.log(decodedSafe);

import { isUuid58, UUID58_REGEX } from "@nakanoaas/uuid58";

// Validate UUID58 string without decoding
const isValid = isUuid58("XDY9dmBbcMBXqcRvYw8xJ2"); // true
const isValid2 = isUuid58("invalid"); // false

// Or use regex pattern for validation
const isValid3 = UUID58_REGEX.test("XDY9dmBbcMBXqcRvYw8xJ2"); // true
```

## API Reference

### `uuid58()`

Generates a new Base58-encoded UUID (always 22 characters).

```typescript
function uuid58(): string; // always returns a 22-character string
```

### `uuid58Encode(uuid: string)`

Converts a standard UUID string to a 22-character Base58-encoded format.

```typescript
function uuid58Encode(uuid: string): string; // always returns a 22-character string
```

- **Parameters:**
  - `uuid`: The UUID string to encode: hyphenated
    (`xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`) or 32 hexadecimal digits, in any
    letter case. Other forms (braces, `urn:uuid:`, whitespace, hyphens in other
    positions) are rejected.
- **Returns:** A 22-character Base58-encoded string
- **Throws:** `Uuid58EncodeError` if the input is not a valid UUID

### `uuid58EncodeSafe(uuid: string)`

Converts a standard UUID string to a 22-character Base58-encoded format, but
instead of throwing an error for invalid input, it returns an
`Uuid58EncodeError` instance.

```typescript
function uuid58EncodeSafe(uuid: string): string | Uuid58EncodeError; // string is always 22 characters
```

- **Parameters:**
  - `uuid`: The UUID string to encode (same forms as `uuid58Encode`)
- **Returns:** A 22-character Base58-encoded string, or an `Uuid58EncodeError`
  if the input is not a valid UUID
- **Note:** This function does not throw; it returns the error object instead.

### `uuid58Decode(encoded: string)`

Converts a 22-character Base58-encoded string back to a standard UUID format.

```typescript
function uuid58Decode(uuid58: string): string;
```

- **Parameters:**
  - `uuid58`: The 22-character Base58-encoded string to decode
- **Returns:** A standard UUID string (lowercase, with hyphens)
- **Throws:** `Uuid58DecodeError` if the input is not a valid 22-character
  Base58 string

### `uuid58DecodeSafe(encoded: string)`

Converts a 22-character Base58-encoded string back to a standard UUID format,
but instead of throwing an error for invalid input, it returns an
`Uuid58DecodeError` instance.

```typescript
function uuid58DecodeSafe(uuid58: string): string | Uuid58DecodeError;
```

- **Parameters:**
  - `uuid58`: The 22-character Base58-encoded string to decode
- **Returns:** A standard UUID string (lowercase, with hyphens), or an
  `Uuid58DecodeError` if the input is not a valid 22-character Base58 string
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

Checks if a given string is a valid UUID58-encodable string. This function
efficiently validates without performing full decoding.

```typescript
function isUuid58(uuid58: string): boolean;
```

- **Parameters:**
  - `uuid58`: The string to check
- **Returns:** `true` if the string is a valid UUID58 string, `false` otherwise
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

Character set for Base58 encoding (Bitcoin compatible). This alphabet excludes
characters that can be easily confused: `0` (zero) and `O` (capital O), `I`
(capital i) and `l` (lowercase L). The alphabet consists of 58 characters:
digits 1-9 and letters A-Z, a-z (excluding the ambiguous characters mentioned
above).

```typescript
const UUID58_ALPHABET: string; // "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
```

#### `UUID58_REGEX`

Regular expression pattern for validating UUID58 strings. This regex ensures
that a string contains exactly 22 characters and uses only characters from the
Base58 alphabet.

```typescript
const UUID58_REGEX: RegExp; // /^[1-9A-HJ-NP-Za-km-z]{22}$/
```

**Note:** While `UUID58_REGEX` can validate the format, `isUuid58()` provides
more comprehensive validation by also checking that the decoded value fits
within 128 bits. For simple format checks, the regex is sufficient; for complete
validation, use `isUuid58()`.

**Example:**

```typescript
import { UUID58_REGEX } from "@nakanoaas/uuid58";

const isValid = UUID58_REGEX.test("XDY9dmBbcMBXqcRvYw8xJ2"); // true
const isValid = UUID58_REGEX.test("invalid"); // false
const isValid = UUID58_REGEX.test("123"); // false (too short)
```

## Why uuid58?

Standard UUIDs are 36 characters long (including hyphens), which can be
cumbersome in URLs or when space is limited. Base58 encoding reduces this to a
fixed 22 characters while maintaining uniqueness and using only URL-safe
characters. The Base58 alphabet used in this library is the same as Bitcoin's,
which excludes similar-looking characters (0, O, I, l) to prevent visual
ambiguity and confusion.

This package implements the
[uuid58 specification](https://github.com/nakanoasaservice/uuid58/blob/main/spec/SPEC.md).
Since 2.0 it follows the spec fully. 1.x accepted hyphens anywhere in the
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

This package lives in the `js/` directory of the repository and uses
[Vite+](https://viteplus.dev/) (`vp`) and pnpm. Run these commands in `js/`:

```bash
pnpm install
pnpm check   # format, lint and type check
pnpm test    # run tests, including the spec's conformance vectors
pnpm bench   # build and benchmark (see bench/README.md)
pnpm build   # build the npm package into dist/
```

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

MIT License - see the [LICENSE](LICENSE) file for details
