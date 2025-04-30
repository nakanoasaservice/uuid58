# uuid58

[![JSR](https://jsr.io/badges/@nakanoaas/uuid58)](https://jsr.io/@nakanoaas/uuid58)
[![npm](https://badge.fury.io/js/@nakanoaas%2Fuuid58.svg)](https://badge.fury.io/js/@nakanoaas%2Fuuid58)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A tiny, zero-dependency library for generating and converting UUIDs to
Base58-encoded strings (using Bitcoin-style alphabet). Perfect for creating
shorter, URL-safe identifiers while maintaining the uniqueness of UUIDs.

## Features

- 🚀 Generate short, URL-safe identifiers (~22 characters)
- 🔄 Bidirectional conversion between UUID and Base58
- 🪶 Zero dependencies
- 💪 Type-safe with TypeScript
- 🔒 Uses native `crypto.randomUUID()` for secure UUID generation
- 📦 Supports both ESM and CommonJS

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

// Generate a new Base58-encoded UUID
const id = uuid58();
// => "XDY9dmBbcMBXqcRvYw8xJ2"

// Convert existing UUID to Base58
const encoded = uuid58Encode("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf");
// => "XDY9dmBbcMBXqcRvYw8xJ2"

// Convert Base58 back to UUID
const decoded = uuid58Decode("XDY9dmBbcMBXqcRvYw8xJ2");
// => "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf"
```

## API Reference

### `uuid58()`

Generates a new Base58-encoded UUID.

```typescript
function uuid58(): string;
```

### `uuid58Encode(uuid: string)`

Converts a standard UUID string to a Base58-encoded format.

```typescript
function uuid58Encode(uuid: string): string;
```

- **Parameters:**
  - `uuid`: The UUID string to encode (with or without hyphens)
- **Returns:** A Base58-encoded string
- **Throws:** `InvalidUuidError` if the input is not a valid UUID

### `uuid58Decode(encoded: string)`

Converts a Base58-encoded string back to a standard UUID format.

```typescript
function uuid58Decode(encoded: string): string;
```

- **Parameters:**
  - `encoded`: The Base58-encoded string to decode
- **Returns:** A standard UUID string (lowercase, with hyphens)
- **Throws:** `InvalidBase58Error` if the input contains invalid Base58
  characters

## Why uuid58?

Standard UUIDs are 36 characters long (including hyphens), which can be
cumbersome in URLs or when space is limited. Base58 encoding reduces this to
around 22 characters while maintaining uniqueness and using only URL-safe
characters. The Base58 alphabet used in this library is the same as Bitcoin's,
which excludes similar-looking characters (0, O, I, l) to prevent visual
ambiguity and confusion.

## License

MIT License - see the [LICENSE](LICENSE) file for details
