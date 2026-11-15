<?php

declare(strict_types=1);

namespace NakanoAsAService\Uuid58;

/**
 * The error kinds of the uuid58 specification (SPEC.md Section 7).
 * Each case's value is the kind's name in the specification.
 */
enum ErrorKind: string
{
    /** The input has the wrong length (or contains a non-ASCII byte). */
    case InvalidLength = 'invalid_length';

    /** The input contains a character that is not allowed in its position. */
    case InvalidCharacter = 'invalid_character';

    /** The input is well formed but its value exceeds 128 bits. */
    case Overflow = 'overflow';
}
