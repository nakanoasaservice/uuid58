<?php

declare(strict_types=1);

namespace NakanoAsAService\Uuid58\Tests;

use InvalidArgumentException;
use NakanoAsAService\Uuid58\ErrorKind;
use NakanoAsAService\Uuid58\Uuid58;
use NakanoAsAService\Uuid58\Uuid58Exception;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

/**
 * Tests beyond spec/vectors.json: byte inputs JSON cannot express
 * (SPEC.md Section 4.1), PHP-specific pitfalls, the API surface, and
 * properties checked on random values.
 */
final class Uuid58Test extends TestCase
{
    private const SAMPLE_UUID = 'f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf';
    private const SAMPLE_HEX = 'f4b247fd1f8745d4aa061c6fc0a8dfaf';
    private const SAMPLE_UUID58 = 'XDY9dmBbcMBXqcRvYw8xJ2';

    /** @param callable(string): mixed $fn */
    private static function kindOf(callable $fn, string $input): ErrorKind
    {
        try {
            $fn($input);
        } catch (Uuid58Exception $e) {
            return $e->kind;
        }
        self::fail('expected Uuid58Exception for ' . bin2hex($input));
    }

    // --- Section 4.1: bytes that are not ASCII -----------------------------

    /** @return iterable<string, array{string}> */
    public static function nonAsciiUuid58(): iterable
    {
        $s = self::SAMPLE_UUID58;
        yield '22 x 0xFF' => [str_repeat("\xFF", 22)];
        yield 'trailing 0x80' => [substr($s, 0, 21) . "\x80"];
        yield 'lone 0xC1' => [substr($s, 0, 10) . "\xC1" . substr($s, 11)];
        yield 'U+0141 (low byte 0x41)' => ["\u{0141}" . substr($s, 2)];
        yield 'KELVIN SIGN' => ["\u{212A}" . substr($s, 1)];
        yield 'FULLWIDTH DIGIT ONE' => ["\u{FF11}" . substr($s, 1)];
        yield 'encoded surrogate' => ["\xED\xA0\x80" . substr($s, 3)];
        yield 'NUL byte' => [substr($s, 0, 21) . "\0"];
    }

    #[DataProvider('nonAsciiUuid58')]
    public function testDecodeRejectsNonAscii(string $s): void
    {
        self::assertContains(
            self::kindOf(Uuid58::decode(...), $s),
            [ErrorKind::InvalidLength, ErrorKind::InvalidCharacter],
        );
        self::assertFalse(Uuid58::isUuid58($s));
    }

    /** @return iterable<string, array{string}> */
    public static function nonAsciiUuid(): iterable
    {
        yield '36 x 0xFF' => [str_repeat("\xFF", 36)];
        yield '32 x 0xFF' => [str_repeat("\xFF", 32)];
        yield '0xFF in place of a hex digit' => ["\xFF" . substr(self::SAMPLE_UUID, 1)];
        yield 'trailing 0x80, plain' => [substr(self::SAMPLE_HEX, 0, 31) . "\x80"];
        yield 'FULLWIDTH A' => ["\u{FF21}" . substr(self::SAMPLE_UUID, 1)];
        yield 'U+2010 HYPHEN' => [substr(self::SAMPLE_UUID, 0, 8) . "\u{2010}" . substr(self::SAMPLE_UUID, 9)];
        yield 'NUL byte' => [substr(self::SAMPLE_HEX, 0, 31) . "\0"];
    }

    #[DataProvider('nonAsciiUuid')]
    public function testEncodeRejectsNonAscii(string $s): void
    {
        self::assertContains(
            self::kindOf(Uuid58::encode(...), $s),
            [ErrorKind::InvalidLength, ErrorKind::InvalidCharacter],
        );
    }

    // --- Section 5.1 note: lenient parsers must not leak -------------------

    /** @return iterable<string, array{string}> */
    public static function lenientForms(): iterable
    {
        yield 'braces' => ['{' . self::SAMPLE_UUID . '}'];
        yield 'urn' => ['urn:uuid:' . self::SAMPLE_UUID];
        yield 'braces, plain' => ['{' . self::SAMPLE_HEX . '}'];
        yield 'misplaced hyphens' => ['f4b247fd1f87-45d4-aa06-1c6fc0a8dfaf-'];
        yield 'leading +' => ['+' . substr(self::SAMPLE_HEX, 1)];
        yield 'leading -' => ['-' . substr(self::SAMPLE_HEX, 1)];
        yield '0x prefix' => ['0x' . substr(self::SAMPLE_HEX, 2)];
        yield 'leading space' => [' ' . substr(self::SAMPLE_HEX, 1)];
        yield 'trailing newline, plain' => [substr(self::SAMPLE_HEX, 0, 31) . "\n"];
        yield 'trailing newline, hyphenated' => [substr(self::SAMPLE_UUID, 0, 35) . "\n"];
        yield 'appended newline' => [self::SAMPLE_UUID . "\n"];
        yield 'raw 16 bytes' => [(string) hex2bin(self::SAMPLE_HEX)];
    }

    #[DataProvider('lenientForms')]
    public function testEncodeRejectsLenientForms(string $s): void
    {
        $this->expectException(Uuid58Exception::class);
        Uuid58::encode($s);
    }

    public function testDecodeDoesNotTrim(): void
    {
        self::assertSame(ErrorKind::InvalidLength, self::kindOf(Uuid58::decode(...), ' ' . self::SAMPLE_UUID58));
        self::assertSame(ErrorKind::InvalidLength, self::kindOf(Uuid58::decode(...), self::SAMPLE_UUID58 . "\n"));
        self::assertSame(
            ErrorKind::InvalidCharacter,
            self::kindOf(Uuid58::decode(...), substr(self::SAMPLE_UUID58, 0, 21) . "\n"),
        );
    }

    public function testEncodeBytesAreRawNotText(): void
    {
        self::assertSame(ErrorKind::InvalidLength, self::kindOf(Uuid58::encodeBytes(...), self::SAMPLE_UUID));
        self::assertSame(ErrorKind::InvalidLength, self::kindOf(Uuid58::encodeBytes(...), self::SAMPLE_HEX));
        self::assertSame(self::SAMPLE_UUID58, Uuid58::encodeBytes((string) hex2bin(self::SAMPLE_HEX)));
    }

    public function testCaseSensitiveDecode(): void
    {
        self::assertNotSame(Uuid58::decode('1111111111111111111112'), Uuid58::decode('111111111111111111111z'));
        self::assertSame(ErrorKind::Overflow, self::kindOf(Uuid58::decode(...), 'zzzzzzzzzzzzzzzzzzzzzz'));
        self::assertSame(
            ErrorKind::InvalidCharacter,
            self::kindOf(Uuid58::decode(...), 'Zzzzzzzzzzzzzzzzzzzzz0'),
        );
    }

    // --- API surface --------------------------------------------------------

    public function testIsUuid58NonStrings(): void
    {
        foreach ([null, 1, 1.5, true, [], new \stdClass()] as $value) {
            self::assertFalse(Uuid58::isUuid58($value));
        }
        self::assertTrue(Uuid58::isUuid58(Uuid58::MAX_UUID58));
    }

    public function testExceptionCarriesKind(): void
    {
        $e = new Uuid58Exception(ErrorKind::Overflow, 'x');
        self::assertInstanceOf(InvalidArgumentException::class, $e);
        self::assertSame(ErrorKind::Overflow, $e->kind);
        self::assertSame('overflow', ErrorKind::Overflow->value);
        self::assertSame('invalid_length', ErrorKind::InvalidLength->value);
        self::assertSame('invalid_character', ErrorKind::InvalidCharacter->value);
        self::assertSame(ErrorKind::InvalidCharacter, ErrorKind::from('invalid_character'));
    }

    public function testGenerate(): void
    {
        $seen = [];
        for ($i = 0; $i < 1000; $i++) {
            $s = Uuid58::generate();
            self::assertSame(22, \strlen($s));
            self::assertTrue(Uuid58::isUuid58($s));
            $uuid = Uuid58::decode($s);
            self::assertSame('4', $uuid[14], 'version');
            self::assertContains($uuid[19], ['8', '9', 'a', 'b'], 'variant');
            $seen[$s] = true;
        }
        self::assertCount(1000, $seen);
    }

    // --- Properties on random values ---------------------------------------

    public function testRandomRoundtripAndOrder(): void
    {
        $prevBytes = '';
        $prevEncoded = '';
        for ($i = 0; $i < 2000; $i++) {
            // Mix fully random values with mostly-zero and mostly-0xFF ones.
            $bytes = random_bytes(16);
            if ($i % 3 === 1) {
                $bytes = str_repeat("\0", random_int(0, 15)) . $bytes;
            } elseif ($i % 3 === 2) {
                $bytes = str_repeat("\xFF", random_int(0, 15)) . $bytes;
            }
            $bytes = substr($bytes, 0, 16);

            $encoded = Uuid58::encodeBytes($bytes);
            self::assertSame(22, \strlen($encoded));
            self::assertSame($bytes, Uuid58::decodeBytes($encoded));
            self::assertSame($encoded, Uuid58::encode(Uuid58::decode($encoded)));
            self::assertSame($encoded, Uuid58::encode(strtoupper(bin2hex($bytes))));

            // Section 3.2: byte order of encodings equals numeric order.
            if ($i > 0) {
                self::assertSame(
                    strcmp($prevBytes, $bytes) <=> 0,
                    strcmp($prevEncoded, $encoded) <=> 0,
                );
            }
            $prevBytes = $bytes;
            $prevEncoded = $encoded;
        }
    }
}
