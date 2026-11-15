# uuid58 for PHP

PHP implementation of [uuid58](https://github.com/nakanoasaservice/uuid58/blob/main/spec/SPEC.md):
a 22-character Base58 text encoding for 128-bit UUIDs.

```text
f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf  <->  XDY9dmBbcMBXqcRvYw8xJ2
```

- Always exactly 22 characters, using the Bitcoin Base58 alphabet (no `0`,
  `O`, `I`, `l`).
- Order-preserving: sorting uuid58 strings byte-wise (`strcmp`, binary
  collation) sorts the UUIDs numerically (useful with UUIDv7).
- Strict: implements the [uuid58 specification](https://github.com/nakanoasaservice/uuid58/blob/main/spec/SPEC.md)
  and passes its [test vectors](https://github.com/nakanoasaservice/uuid58/blob/main/spec/vectors.json).
- No dependencies and no extensions: 128-bit arithmetic is done with 16-bit
  limbs, so GMP and BCMath are not needed. PHP 8.1 or later.

## Install

```bash
composer require nakanoasaservice/uuid58
```

## Usage

```php
use NakanoAsAService\Uuid58\Uuid58;

Uuid58::encode('f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf'); // 'XDY9dmBbcMBXqcRvYw8xJ2'
Uuid58::encode('F4B247FD1F8745D4AA061C6FC0A8DFAF');     // same: plain hex, any case

Uuid58::decode('XDY9dmBbcMBXqcRvYw8xJ2'); // 'f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf'

Uuid58::isUuid58('XDY9dmBbcMBXqcRvYw8xJ2'); // true
Uuid58::isUuid58('zzzzzzzzzzzzzzzzzzzzzz'); // false: exceeds 128 bits

Uuid58::generate(); // uuid58 of a random UUIDv4, e.g. 'Tj5D5H2Bc1LcPjwNNhH4xS'
```

### Raw bytes (BINARY(16) columns)

PHP strings are byte strings, so UUID text and 16 raw bytes have the same
type. Raw bytes therefore have their own methods; `encode()` never accepts
raw bytes and `encodeBytes()` never accepts text.

```php
$bytes = Uuid58::decodeBytes('XDY9dmBbcMBXqcRvYw8xJ2'); // 16 bytes, big-endian
Uuid58::encodeBytes($bytes);                             // 'XDY9dmBbcMBXqcRvYw8xJ2'
```

### ramsey/uuid (Laravel, Symfony)

`RamseyUuid58` converts to and from `Ramsey\Uuid\UuidInterface`. ramsey/uuid
is only a suggested dependency; install it yourself (Laravel already does).

```php
use NakanoAsAService\Uuid58\RamseyUuid58;
use Ramsey\Uuid\Uuid;

RamseyUuid58::encode(Uuid::uuid7());                 // e.g. '1C3XR6GsZf6bBz7dTqzVLe'
RamseyUuid58::decode('XDY9dmBbcMBXqcRvYw8xJ2');      // UuidInterface
```

Without the helper, any library that exposes the 16 bytes works the same
way: `Uuid58::encodeBytes($uuid->getBytes())`, and for Symfony UID
`Uuid58::encodeBytes($uuid->toBinary())`.

### Errors

Invalid input throws `Uuid58Exception` (a subclass of
`InvalidArgumentException`). Its `kind` property is an `ErrorKind` enum
whose value is the spec error kind (SPEC.md Section 7):

| `ErrorKind`        | Value                 | Thrown when                                                         |
| ------------------ | --------------------- | ------------------------------------------------------------------- |
| `InvalidLength`    | `'invalid_length'`    | a string of the wrong length, or bytes whose length is not 16       |
| `InvalidCharacter` | `'invalid_character'` | a character not allowed in its position (including any non-ASCII byte) |
| `Overflow`         | `'overflow'`          | a decoded value greater than 2^128 - 1                              |

```php
use NakanoAsAService\Uuid58\ErrorKind;
use NakanoAsAService\Uuid58\Uuid58Exception;

try {
    Uuid58::decode($input);
} catch (Uuid58Exception $e) {
    if ($e->kind === ErrorKind::Overflow) { /* ... */ }
    echo $e->kind->value; // 'invalid_length', 'invalid_character' or 'overflow'
}
```

Error messages are not part of the specification and may change.

## API

All methods are static on `NakanoAsAService\Uuid58\Uuid58`.

| Method                                   | Description                                                            |
| ---------------------------------------- | ---------------------------------------------------------------------- |
| `encode(string $uuid): string`           | Encode a UUID string (hyphenated or 32 hex digits, any case).          |
| `encodeBytes(string $bytes): string`     | Encode 16 raw bytes (big-endian, RFC 9562 order).                      |
| `decode(string $uuid58): string`         | Decode to the lowercase hyphenated UUID string.                        |
| `decodeBytes(string $uuid58): string`    | Decode to 16 raw bytes.                                                |
| `isUuid58(mixed $value): bool`           | `true` exactly when `decode($value)` would succeed. Never throws.      |
| `generate(): string`                     | Generate a random UUIDv4 with `random_bytes()` and return its encoding. |
| `ALPHABET`, `MAX_UUID58`, `LENGTH`       | The Base58 alphabet, the largest valid uuid58 string, and 22.          |

### Accepted UUID strings

`encode` accepts exactly two textual forms, in any letter case (SPEC.md
Section 5.1):

- hyphenated, 36 characters: `f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf`
- plain, 32 hex digits: `f4b247fd1f8745d4aa061c6fc0a8dfaf`

Everything else is rejected, including braces, the `urn:uuid:` prefix,
misplaced hyphens and surrounding whitespace. To encode those, parse them
with `Ramsey\Uuid\Uuid::fromString()` first and use `RamseyUuid58::encode()`.

## Development

```bash
composer install
composer test        # PHPUnit, including spec/vectors.json conformance
composer analyse     # PHPStan, level max
```

The conformance tests read `../spec/vectors.json`, so run them from a
checkout of the repository.

## License

MIT
