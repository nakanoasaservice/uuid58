<?php

declare(strict_types=1);

namespace NakanoAsAService\Uuid58;

/**
 * Encode UUIDs as 22-character Base58 strings, and back.
 *
 * Implements the uuid58 specification (spec/SPEC.md) with 16-bit limb
 * arithmetic, so it needs no extension (no GMP or BCMath) and works on
 * 32-bit and 64-bit builds alike.
 *
 * PHP strings are byte strings, so a UUID string and 16 raw bytes have the
 * same type. They therefore have separate methods: `encode()` / `decode()`
 * work with UUID text, `encodeBytes()` / `decodeBytes()` with raw bytes.
 */
final class Uuid58
{
    /** The Bitcoin Base58 alphabet, in ascending ASCII order (SPEC.md Section 2). */
    public const ALPHABET = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

    /** The largest valid uuid58 string: the encoding of 2^128 - 1. */
    public const MAX_UUID58 = 'YcVfxkQb6JRzqk5kF2tNLv';

    /** Length of every uuid58 string. */
    public const LENGTH = 22;

    private const HEX_DIGITS = '0123456789abcdefABCDEF';

    /** @var array<int, int> Digit value by byte, built on first decode. */
    private static array $digitValues = [];

    private function __construct()
    {
    }

    /**
     * Encode a UUID string: hyphenated (36 characters) or 32 hex digits, in
     * any letter case (SPEC.md Section 5.1). Every other form is rejected.
     *
     * @throws Uuid58Exception invalid_length or invalid_character
     */
    public static function encode(string $uuid): string
    {
        return self::encodeBytes(self::parseUuid($uuid));
    }

    /**
     * Encode 16 raw bytes (big-endian, RFC 9562 order), for example
     * `$uuid->getBytes()` from ramsey/uuid or a BINARY(16) column.
     *
     * @throws Uuid58Exception invalid_length if the input is not 16 bytes
     */
    public static function encodeBytes(string $bytes): string
    {
        if (\strlen($bytes) !== 16) {
            throw new Uuid58Exception(
                ErrorKind::InvalidLength,
                \sprintf('Expected 16 bytes, got %d', \strlen($bytes)),
            );
        }

        // Eight 16-bit limbs, most significant first. Each remainder is below
        // 58, so remainder * 65536 + limb stays below 2^22: no overflow even
        // on 32-bit PHP.
        $limbs = [];
        for ($j = 0; $j < 16; $j += 2) {
            $limbs[] = (\ord($bytes[$j]) << 8) | \ord($bytes[$j + 1]);
        }
        $out = '';
        for ($i = 0; $i < self::LENGTH; $i++) {
            $remainder = 0;
            for ($j = 0; $j < 8; $j++) {
                $acc = ($remainder << 16) | $limbs[$j];
                $limbs[$j] = intdiv($acc, 58);
                $remainder = $acc % 58;
            }
            $out .= self::ALPHABET[$remainder];
        }

        return strrev($out);
    }

    /**
     * Decode to the lowercase hyphenated UUID string (SPEC.md Section 5.2).
     *
     * @throws Uuid58Exception invalid_length, invalid_character or overflow
     */
    public static function decode(string $uuid58): string
    {
        $hex = bin2hex(self::decodeBytes($uuid58));

        return substr($hex, 0, 8) . '-' . substr($hex, 8, 4) . '-' . substr($hex, 12, 4)
            . '-' . substr($hex, 16, 4) . '-' . substr($hex, 20);
    }

    /**
     * Decode to 16 raw bytes (big-endian, RFC 9562 order), for example for
     * `Uuid::fromBytes()` in ramsey/uuid or a BINARY(16) column.
     *
     * @throws Uuid58Exception invalid_length, invalid_character or overflow
     */
    public static function decodeBytes(string $uuid58): string
    {
        // SPEC.md Section 4: length, then characters, then range. Length is
        // measured in bytes; any byte >= 0x80 fails the character check.
        if (\strlen($uuid58) !== self::LENGTH) {
            throw new Uuid58Exception(
                ErrorKind::InvalidLength,
                \sprintf('Expected %d characters, got %d bytes', self::LENGTH, \strlen($uuid58)),
            );
        }
        $valid = strspn($uuid58, self::ALPHABET);
        if ($valid !== self::LENGTH) {
            throw new Uuid58Exception(
                ErrorKind::InvalidCharacter,
                \sprintf('Invalid character at position %d', $valid),
            );
        }
        // Same length and alphabet in ASCII order: byte comparison is
        // numeric comparison (SPEC.md Section 3.2).
        if (strcmp($uuid58, self::MAX_UUID58) > 0) {
            throw new Uuid58Exception(ErrorKind::Overflow, 'Value exceeds 128 bits');
        }

        if (self::$digitValues === []) {
            for ($i = 0; $i < 58; $i++) {
                self::$digitValues[\ord(self::ALPHABET[$i])] = $i;
            }
        }
        $values = self::$digitValues;
        $limbs = [0, 0, 0, 0, 0, 0, 0, 0];
        for ($i = 0; $i < self::LENGTH; $i++) {
            $carry = $values[\ord($uuid58[$i])];
            for ($j = 7; $j >= 0; $j--) {
                $acc = $limbs[$j] * 58 + $carry;
                $limbs[$j] = $acc & 0xFFFF;
                $carry = $acc >> 16;
            }
        }

        return pack('n8', ...$limbs);
    }

    /**
     * True exactly when `decode($value)` would succeed (SPEC.md Section 6).
     * Never throws; non-string values return false.
     */
    public static function isUuid58(mixed $value): bool
    {
        return \is_string($value)
            && \strlen($value) === self::LENGTH
            && strspn($value, self::ALPHABET) === self::LENGTH
            && strcmp($value, self::MAX_UUID58) <= 0;
    }

    /**
     * Generate a random UUIDv4 (RFC 9562) with `random_bytes()` and return
     * its uuid58 encoding.
     */
    public static function generate(): string
    {
        $bytes = random_bytes(16);
        $bytes[6] = \chr((\ord($bytes[6]) & 0x0F) | 0x40); // version 4
        $bytes[8] = \chr((\ord($bytes[8]) & 0x3F) | 0x80); // variant 10

        return self::encodeBytes($bytes);
    }

    /** @throws Uuid58Exception */
    private static function parseUuid(string $uuid): string
    {
        $length = \strlen($uuid);
        if ($length === 36) {
            if ($uuid[8] !== '-' || $uuid[13] !== '-' || $uuid[18] !== '-' || $uuid[23] !== '-') {
                throw new Uuid58Exception(
                    ErrorKind::InvalidCharacter,
                    'Expected hyphens at positions 8, 13, 18 and 23',
                );
            }
            $hex = substr($uuid, 0, 8) . substr($uuid, 9, 4) . substr($uuid, 14, 4)
                . substr($uuid, 19, 4) . substr($uuid, 24);
        } elseif ($length === 32) {
            $hex = $uuid;
        } else {
            throw new Uuid58Exception(
                ErrorKind::InvalidLength,
                \sprintf('Expected a UUID of 36 or 32 characters, got %d bytes', $length),
            );
        }
        // Check every byte explicitly, so the error carries its kind.
        if (strspn($hex, self::HEX_DIGITS) !== 32) {
            throw new Uuid58Exception(ErrorKind::InvalidCharacter, 'Invalid hexadecimal digit');
        }

        return (string) hex2bin($hex);
    }
}
