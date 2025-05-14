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
- 🔒 Uses native `crypto.randomUUID()` for secure UUID generation
- 📦 Supports both ESM and CommonJS
- 🛡️ Provides safe APIs that return error objects instead of throwing exceptions

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
  - `uuid`: The UUID string to encode (with or without hyphens)
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
  - `uuid`: The UUID string to encode (with or without hyphens)
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

## Why uuid58?

Standard UUIDs are 36 characters long (including hyphens), which can be
cumbersome in URLs or when space is limited. Base58 encoding reduces this to a
fixed 22 characters while maintaining uniqueness and using only URL-safe
characters. The Base58 alphabet used in this library is the same as Bitcoin's,
which excludes similar-looking characters (0, O, I, l) to prevent visual
ambiguity and confusion.

## License

MIT License - see the [LICENSE](LICENSE) file for details
