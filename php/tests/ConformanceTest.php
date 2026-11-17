<?php

declare(strict_types=1);

namespace NakanoAsAService\Uuid58\Tests;

use NakanoAsAService\Uuid58\RamseyUuid58;
use NakanoAsAService\Uuid58\Uuid58;
use NakanoAsAService\Uuid58\Uuid58Exception;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;
use Ramsey\Uuid\Uuid;

/**
 * Runs every applicable case in spec/vectors.json (SPEC.md Section 8).
 *
 * Skipped: encode.invalid_integers, because this implementation has no
 * integer API (PHP integers are at most 64 bits).
 */
final class ConformanceTest extends TestCase
{
    /** @var array<string, mixed>|null */
    private static ?array $vectors = null;

    /** @return array<string, mixed> */
    private static function vectors(): array
    {
        if (self::$vectors === null) {
            $json = file_get_contents(__DIR__ . '/../../spec/vectors.json');
            self::assertIsString($json, 'cannot read ../spec/vectors.json');
            /** @var array<string, mixed> $decoded */
            $decoded = json_decode($json, true, flags: JSON_THROW_ON_ERROR);
            self::$vectors = $decoded;
        }

        return self::$vectors;
    }

    /**
     * @param list<string> $path
     * @return iterable<string, array{array<string, mixed>}>
     */
    private static function cases(array $path): iterable
    {
        $node = self::vectors();
        foreach ($path as $key) {
            /** @var array<string, mixed> $node */
            $node = $node[$key];
        }
        /** @var list<array<string, mixed>> $node */
        foreach ($node as $case) {
            \assert(\is_string($case['description']));
            yield $case['description'] => [$case];
        }
    }

    /** @return iterable<string, array{array<string, mixed>}> */
    public static function roundtripCases(): iterable
    {
        return self::cases(['roundtrip']);
    }

    /** @return iterable<string, array{array<string, mixed>}> */
    public static function encodeValidCases(): iterable
    {
        return self::cases(['encode', 'valid']);
    }

    /** @return iterable<string, array{array<string, mixed>}> */
    public static function encodeInvalidCases(): iterable
    {
        return self::cases(['encode', 'invalid']);
    }

    /** @return iterable<string, array{array<string, mixed>}> */
    public static function invalidBytesCases(): iterable
    {
        return self::cases(['encode', 'invalid_bytes']);
    }

    /** @return iterable<string, array{array<string, mixed>}> */
    public static function decodeInvalidCases(): iterable
    {
        return self::cases(['decode', 'invalid']);
    }

    /**
     * @param callable(string): mixed $fn
     * @param array<string, mixed> $case
     */
    private static function assertFailsWith(callable $fn, string $input, array $case): void
    {
        try {
            $fn($input);
        } catch (Uuid58Exception $e) {
            self::assertIsArray($case['errors']);
            self::assertContains($e->kind->value, $case['errors']);

            return;
        }
        self::fail('expected Uuid58Exception for ' . json_encode($input));
    }

    public function testMetadata(): void
    {
        $vectors = self::vectors();
        self::assertSame('1.1.0', $vectors['spec_version']);
        self::assertSame(Uuid58::ALPHABET, $vectors['alphabet']);

        $max = '';
        foreach (self::roundtripCases() as [$case]) {
            \assert(\is_string($case['uuid58']));
            $max = max($max, $case['uuid58']);
        }
        self::assertSame(Uuid58::MAX_UUID58, $max);
    }

    /** @param array<string, mixed> $case */
    #[DataProvider('roundtripCases')]
    public function testRoundtrip(array $case): void
    {
        $text = $case['uuid'];
        $encoded = $case['uuid58'];
        \assert(\is_string($text) && \is_string($encoded));
        $hex = str_replace('-', '', $text);
        $raw = (string) hex2bin($hex);

        // UUID strings (Section 5), in both accepted forms.
        self::assertSame($encoded, Uuid58::encode($text));
        self::assertSame($encoded, Uuid58::encode($hex));
        self::assertSame($text, Uuid58::decode($encoded));

        // 16 bytes (Section 8.1: hyphens removed, read big-endian).
        self::assertSame($encoded, Uuid58::encodeBytes($raw));
        self::assertSame($raw, Uuid58::decodeBytes($encoded));

        // ramsey/uuid, compared against the vector's text, not only
        // round-tripped through itself (Section 8.1).
        self::assertSame($text, RamseyUuid58::decode($encoded)->toString());
        self::assertSame($raw, RamseyUuid58::decode($encoded)->getBytes());
        self::assertSame($encoded, RamseyUuid58::encode(Uuid::fromString($text)));

        // Validation (Section 6).
        self::assertTrue(Uuid58::isUuid58($encoded));
    }

    /** @param array<string, mixed> $case */
    #[DataProvider('encodeValidCases')]
    public function testEncodeValid(array $case): void
    {
        \assert(\is_string($case['input']));
        self::assertSame($case['output'], Uuid58::encode($case['input']));
    }

    /** @param array<string, mixed> $case */
    #[DataProvider('encodeInvalidCases')]
    public function testEncodeInvalid(array $case): void
    {
        // Cases marked "lenient" are accepted by JavaScript 1.x only; this
        // implementation is strict and MUST reject them (Section 9.1).
        \assert(\is_string($case['input']));
        self::assertFailsWith(Uuid58::encode(...), $case['input'], $case);
    }

    /** @param array<string, mixed> $case */
    #[DataProvider('invalidBytesCases')]
    public function testEncodeInvalidBytes(array $case): void
    {
        \assert(\is_string($case['bytes']));
        self::assertFailsWith(Uuid58::encodeBytes(...), (string) hex2bin($case['bytes']), $case);
    }

    /** @param array<string, mixed> $case */
    #[DataProvider('decodeInvalidCases')]
    public function testDecodeInvalid(array $case): void
    {
        \assert(\is_string($case['input']));
        self::assertFailsWith(Uuid58::decode(...), $case['input'], $case);
        self::assertFailsWith(Uuid58::decodeBytes(...), $case['input'], $case);
        self::assertFailsWith(RamseyUuid58::decode(...), $case['input'], $case);
        self::assertFalse(Uuid58::isUuid58($case['input']));
    }
}
