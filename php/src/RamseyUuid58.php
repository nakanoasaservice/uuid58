<?php

declare(strict_types=1);

namespace NakanoAsAService\Uuid58;

use Ramsey\Uuid\Uuid;
use Ramsey\Uuid\UuidInterface;

/**
 * Optional interop with ramsey/uuid (install it separately; this package
 * does not require it). Uses the 16 bytes in RFC 9562 order.
 */
final class RamseyUuid58
{
    private function __construct()
    {
    }

    public static function encode(UuidInterface $uuid): string
    {
        return Uuid58::encodeBytes($uuid->getBytes());
    }

    /** @throws Uuid58Exception invalid_length, invalid_character or overflow */
    public static function decode(string $uuid58): UuidInterface
    {
        return Uuid::fromBytes(Uuid58::decodeBytes($uuid58));
    }
}
