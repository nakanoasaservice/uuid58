# uuid58 for Rust

[![crates.io](https://img.shields.io/crates/v/uuid58.svg)](https://crates.io/crates/uuid58)
[![docs.rs](https://img.shields.io/docsrs/uuid58)](https://docs.rs/uuid58)
[![CI](https://github.com/nakanoasaservice/uuid58/actions/workflows/ci-rust.yml/badge.svg)](https://github.com/nakanoasaservice/uuid58/actions/workflows/ci-rust.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/nakanoasaservice/uuid58/blob/main/LICENSE)

Shorten UUIDs to 22-character Base58 strings, and back, in Rust. Works with
the `uuid` crate, and runs in `no_std` without an allocator.

```text
f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf  ⇄  XDY9dmBbcMBXqcRvYw8xJ2
```

- **Fixed 22 characters**, using the Bitcoin Base58 alphabet: URL-safe, with
  no `0`, `O`, `I`, or `l`.
- **Sortable**: sorting uuid58 strings by byte gives the same order as
  sorting the UUIDs, so UUIDv7 IDs stay time-ordered.
- **Stable spec, well tested**: implements uuid58 spec 1.0.0 and passes its
  200+ shared test vectors, so the output matches every other language.
- **`#![no_std]`**, no allocator required, no required dependencies.
- **Strict parsing**: rejects malformed UUIDs, non-ASCII input, and values
  above 128 bits, with a typed error.

[Try it in your browser](https://nakanoasaservice.github.io/uuid58/) ·
[Specification](https://github.com/nakanoasaservice/uuid58/blob/main/spec/SPEC.md) ·
[Other languages](https://github.com/nakanoasaservice/uuid58#install)

## Installation

```bash
cargo add uuid58
```

With [`uuid`](https://crates.io/crates/uuid) crate integration:

```bash
cargo add uuid58 --features uuid
```

## Usage

```rust
// UUID string <-> uuid58
let id = uuid58::encode_uuid_str("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf")?;
assert_eq!(id, "XDY9dmBbcMBXqcRvYw8xJ2");
let uuid = uuid58::decode_to_uuid_string("XDY9dmBbcMBXqcRvYw8xJ2")?;
assert_eq!(uuid, "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf");

// u128 / [u8; 16] <-> uuid58
assert_eq!(uuid58::encode(1), "1111111111111111111112");
assert_eq!(uuid58::decode("1111111111111111111112")?, 1);
assert_eq!(uuid58::decode_to_bytes("1111111111111111111112")?[15], 1);

// Validation
assert!(uuid58::is_valid("XDY9dmBbcMBXqcRvYw8xJ2"));
assert!(!uuid58::is_valid("YcVfxkQb6JRzqk5kF2tNLw")); // greater than 2^128 - 1
```

### Without an allocator

```rust
let mut buf = [0u8; uuid58::ENCODED_LEN];
let id: &str = uuid58::encode_to_buf(0xf4b247fd_1f87_45d4_aa06_1c6fc0a8dfaf, &mut buf);
assert_eq!(id, "XDY9dmBbcMBXqcRvYw8xJ2");

let mut buf = [0u8; uuid58::UUID_STR_LEN];
let uuid: &str = uuid58::decode_to_uuid_buf("XDY9dmBbcMBXqcRvYw8xJ2", &mut buf)?;
assert_eq!(uuid, "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf");
```

### With the `uuid` crate

```rust
let uuid = uuid::Uuid::parse_str("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf").unwrap();
assert_eq!(uuid58::encode_uuid(&uuid), "XDY9dmBbcMBXqcRvYw8xJ2");
assert_eq!(uuid58::decode_uuid("XDY9dmBbcMBXqcRvYw8xJ2")?, uuid);
```

### Errors

Every fallible function returns `Result<_, uuid58::Error>`:

| Variant            | When                                                                      |
| ------------------ | ------------------------------------------------------------------------- |
| `InvalidLength`    | uuid58 input not 22 bytes, UUID string not 32 or 36 bytes, slice not 16   |
| `InvalidCharacter` | Right length, but a byte is not allowed in its position (incl. non-ASCII) |
| `Overflow`         | A well-formed uuid58 string whose value is greater than `2^128 - 1`       |

Functions that take text accept any `impl AsRef<[u8]>` (`&str`, `String`,
`&[u8]`, ...) and work on bytes. Nothing is trimmed or normalized. UUID strings
must be either hyphenated (`f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf`) or 32 plain
hex digits, in any letter case; braces, `urn:uuid:`, and misplaced hyphens are
rejected.

## API

| Function                | Input                | Output             | Feature |
| ----------------------- | -------------------- | ------------------ | ------- |
| `encode_to_buf`         | `u128`               | `&str` in `[u8; 22]` |       |
| `encode_bytes_to_buf`   | `&[u8; 16]`          | `&str` in `[u8; 22]` |       |
| `encode`                | `u128`               | `String`           | `alloc` |
| `encode_bytes`          | `&[u8; 16]`          | `String`           | `alloc` |
| `encode_slice`          | `&[u8]` (16 bytes)   | `Result<String>`   | `alloc` |
| `encode_uuid_str`       | UUID string          | `Result<String>`   | `alloc` |
| `encode_uuid`           | `&uuid::Uuid`        | `String`           | `uuid` + `alloc` |
| `decode`                | uuid58               | `Result<u128>`     |         |
| `decode_to_bytes`       | uuid58               | `Result<[u8; 16]>` |         |
| `decode_to_uuid_buf`    | uuid58               | `Result<&str>` in `[u8; 36]` |  |
| `decode_to_uuid_string` | uuid58               | `Result<String>`   | `alloc` |
| `decode_uuid`           | uuid58               | `Result<uuid::Uuid>` | `uuid` |
| `is_valid`              | uuid58               | `bool`             |         |
| `parse_uuid_str`        | UUID string          | `Result<u128>`     |         |

Bytes are always big-endian (RFC 9562 order). Generating UUIDs is out of scope;
use the `uuid` crate (for example `Uuid::new_v4()` or `Uuid::now_v7()`) and
encode the result.

## Features

| Feature | Default | Description                                                  |
| ------- | ------- | ------------------------------------------------------------ |
| `std`   | yes     | Enables `alloc` (and `uuid/std` when `uuid` is enabled)      |
| `alloc` | via std | Functions that return `String`                               |
| `uuid`  | no      | `encode_uuid` / `decode_uuid` for `uuid::Uuid` (uuid 1.x)    |

For `no_std` without an allocator:

```toml
[dependencies]
uuid58 = { version = "0.1", default-features = false }
```

## Minimum supported Rust version

Rust 1.85. Changes to the MSRV will be noted in the release notes. With the
`uuid` feature, Cargo's MSRV-aware resolver picks a `uuid` release that
supports your toolchain.

## Compatibility

This crate implements [uuid58 spec 1.0.0](https://github.com/nakanoasaservice/uuid58/blob/main/spec/SPEC.md) and
passes the shared [test vectors](https://github.com/nakanoasaservice/uuid58/blob/main/spec/vectors.json), so it
produces exactly the same strings as the other implementations.

## License

MIT, see [LICENSE](https://github.com/nakanoasaservice/uuid58/blob/main/LICENSE).
