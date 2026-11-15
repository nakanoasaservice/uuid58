<?php

declare(strict_types=1);

namespace NakanoAsAService\Uuid58;

use InvalidArgumentException;

/**
 * Thrown for invalid input. `$kind` tells callers which spec error kind
 * (SPEC.md Section 7) occurred; the message is not part of the specification.
 */
final class Uuid58Exception extends InvalidArgumentException
{
    public function __construct(
        public readonly ErrorKind $kind,
        string $message,
    ) {
        parent::__construct($message);
    }
}
