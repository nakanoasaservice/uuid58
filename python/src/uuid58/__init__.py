"""Encode UUIDs as 22-character, order-preserving Base58 strings.

This package implements the uuid58 specification:
https://github.com/nakanoasaservice/uuid58/blob/main/spec/SPEC.md

>>> import uuid58
>>> uuid58.encode("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf")
'XDY9dmBbcMBXqcRvYw8xJ2'
>>> uuid58.decode("XDY9dmBbcMBXqcRvYw8xJ2")
'f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf'
"""

from __future__ import annotations

import enum
import uuid as _uuid
from typing import Final

__all__ = [
    "ALPHABET",
    "MAX_UUID58",
    "ErrorKind",
    "InvalidCharacterError",
    "InvalidLengthError",
    "UUIDLike",
    "Uuid58Error",
    "ValueOverflowError",
    "decode",
    "decode_bytes",
    "decode_int",
    "decode_uuid",
    "encode",
    "is_uuid58",
    "uuid58",
]

__version__ = "0.1.0"

ALPHABET: Final = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
"""The Bitcoin Base58 alphabet, in ascending ASCII order (SPEC.md Section 2)."""

MAX_UUID58: Final = "YcVfxkQb6JRzqk5kF2tNLv"  # cspell:disable-line
"""The largest valid uuid58 string, the encoding of 2**128 - 1."""

UUIDLike = str | _uuid.UUID | bytes | bytearray | int
"""The input types accepted by :func:`encode`."""

_ENCODED_LENGTH: Final = 22
_MAX_UINT128: Final = (1 << 128) - 1
_DIGIT_VALUES: Final = {c: i for i, c in enumerate(ALPHABET)}
_HEX_DIGITS: Final = frozenset("0123456789abcdefABCDEF")
_HYPHEN_POSITIONS: Final = (8, 13, 18, 23)
_MAX_PREVIEW_LENGTH: Final = 40


class ErrorKind(str, enum.Enum):
    """The error kinds defined in SPEC.md Section 7.

    Members compare equal to their spec names, e.g.
    ``ErrorKind.OVERFLOW == "overflow"``.
    """

    INVALID_LENGTH = "invalid_length"
    INVALID_CHARACTER = "invalid_character"
    OVERFLOW = "overflow"

    def __str__(self) -> str:
        return self.value


class Uuid58Error(ValueError):
    """Base class for every error raised by this package for invalid input.

    Catch a subclass, or inspect :attr:`kind`, to tell the error kinds apart.
    Error messages are not part of the specification and may change.
    """

    kind: ErrorKind
    """The spec error kind (SPEC.md Section 7)."""


class InvalidLengthError(Uuid58Error):
    """The input has the wrong length (``invalid_length``)."""

    kind = ErrorKind.INVALID_LENGTH


class InvalidCharacterError(Uuid58Error):
    """The input contains a character not allowed in its position
    (``invalid_character``)."""

    kind = ErrorKind.INVALID_CHARACTER


class ValueOverflowError(Uuid58Error):
    """The value is outside ``0..2**128 - 1`` (``overflow``).

    Named to avoid shadowing the built-in :class:`OverflowError`, which it
    does not subclass.
    """

    kind = ErrorKind.OVERFLOW


def _preview(value: object) -> str:
    """Formats untrusted input for an error message: truncated and repr()'d,
    so huge or multi-line inputs cannot bloat or forge log lines."""
    if isinstance(value, (str, bytes, bytearray)) and len(value) > _MAX_PREVIEW_LENGTH:
        return f"{value[:_MAX_PREVIEW_LENGTH]!r}... (length {len(value)})"
    return repr(value)


# --- encoding ---------------------------------------------------------------


def _encode_uint128(value: int) -> str:
    digits = [""] * _ENCODED_LENGTH
    for i in range(_ENCODED_LENGTH - 1, -1, -1):
        value, digit = divmod(value, 58)
        digits[i] = ALPHABET[digit]
    return "".join(digits)


def _parse_uuid_string(s: str) -> int:
    """Parses the hyphenated or plain UUID form strictly (SPEC.md Section 5.1).

    ``uuid.UUID()`` and ``int(s, 16)`` are deliberately not used for
    validation: both accept inputs the spec requires to be rejected.
    """
    length = len(s)
    if length == 36:
        for pos in _HYPHEN_POSITIONS:
            if s[pos] != "-":
                raise InvalidCharacterError(
                    f"Invalid UUID: expected '-' at position {pos} in {_preview(s)}"
                )
        hex_digits = s[0:8] + s[9:13] + s[14:18] + s[19:23] + s[24:36]
    elif length == 32:
        hex_digits = s
    else:
        raise InvalidLengthError(
            f"Invalid UUID length: expected 32 or 36 characters, got {length} "
            f"in {_preview(s)}"
        )
    # Membership in an explicit ASCII set: no Unicode digits, signs,
    # underscores or whitespace can slip through to int().
    for c in hex_digits:
        if c not in _HEX_DIGITS:
            raise InvalidCharacterError(
                f"Invalid UUID: {c!r} is not a hexadecimal digit in {_preview(s)}"
            )
    return int(hex_digits, 16)


def encode(value: UUIDLike) -> str:
    """Encodes a UUID as a 22-character uuid58 string.

    ``value`` may be:

    - a UUID string, hyphenated (``f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf``)
      or plain (32 hex digits), in any letter case. Nothing else is accepted:
      no braces, ``urn:uuid:`` prefix, whitespace or misplaced hyphens;
    - a :class:`uuid.UUID`;
    - exactly 16 :class:`bytes` (or :class:`bytearray`), big-endian
      (``uuid.UUID.bytes`` order);
    - an :class:`int` in ``0..2**128 - 1``.

    Raises:
        InvalidLengthError: a string of the wrong length, or bytes whose
            length is not 16.
        InvalidCharacterError: a string that is not a valid UUID form.
        ValueOverflowError: an int outside ``0..2**128 - 1``.
        TypeError: any other type (including :class:`bool`).

    >>> encode("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf")
    'XDY9dmBbcMBXqcRvYw8xJ2'
    """
    if isinstance(value, str):
        n = _parse_uuid_string(value)
    elif isinstance(value, _uuid.UUID):
        n = value.int
    elif isinstance(value, (bytes, bytearray)):
        if len(value) != 16:
            raise InvalidLengthError(
                f"Invalid UUID bytes: expected 16 bytes, got {len(value)}"
            )
        n = int.from_bytes(value, "big")
    elif isinstance(value, int) and not isinstance(value, bool):
        if not 0 <= value <= _MAX_UINT128:
            raise ValueOverflowError(
                f"Integer out of range for a 128-bit UUID: {_preview(value)}"
            )
        n = int(value)
    else:
        raise TypeError(
            "encode() expects str, uuid.UUID, bytes, bytearray or int, "
            f"not {type(value).__name__}"
        )
    return _encode_uint128(n)


# --- decoding ---------------------------------------------------------------


def _decode_uint128(s: str) -> int:
    """Decodes per SPEC.md Section 4: length, then characters, then range."""
    if not isinstance(s, str):
        raise TypeError(f"expected str, not {type(s).__name__}")
    if len(s) != _ENCODED_LENGTH:
        raise InvalidLengthError(
            f"Invalid uuid58 length: expected {_ENCODED_LENGTH} characters, "
            f"got {len(s)} in {_preview(s)}"
        )
    value = 0
    for c in s:
        digit = _DIGIT_VALUES.get(c)
        if digit is None:
            raise InvalidCharacterError(
                f"Invalid uuid58 character {c!r} in {_preview(s)}"
            )
        value = value * 58 + digit
    if value > _MAX_UINT128:
        raise ValueOverflowError(f"uuid58 value exceeds 128 bits: {_preview(s)}")
    return value


def decode_int(s: str) -> int:
    """Decodes a uuid58 string to an int in ``0..2**128 - 1``.

    Raises:
        InvalidLengthError: ``s`` is not exactly 22 characters long.
        InvalidCharacterError: ``s`` contains a character outside the alphabet.
        ValueOverflowError: the value exceeds ``2**128 - 1``.
        TypeError: ``s`` is not a str.
    """
    return _decode_uint128(s)


def decode_bytes(s: str) -> bytes:
    """Decodes a uuid58 string to 16 big-endian bytes.

    Raises the same errors as :func:`decode_int`.
    """
    return _decode_uint128(s).to_bytes(16, "big")


def decode_uuid(s: str) -> _uuid.UUID:
    """Decodes a uuid58 string to a :class:`uuid.UUID`.

    Raises the same errors as :func:`decode_int`.
    """
    return _uuid.UUID(int=_decode_uint128(s))


def decode(s: str) -> str:
    """Decodes a uuid58 string to a lowercase, hyphenated UUID string.

    Raises the same errors as :func:`decode_int`.

    >>> decode("XDY9dmBbcMBXqcRvYw8xJ2")
    'f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf'
    """
    h = f"{_decode_uint128(s):032x}"
    return f"{h[0:8]}-{h[8:12]}-{h[12:16]}-{h[16:20]}-{h[20:32]}"


# --- validation and generation ----------------------------------------------


def is_uuid58(s: object) -> bool:
    """Returns True exactly when :func:`decode` would succeed on ``s``.

    Never raises; any non-str input returns False.
    """
    # Same length and alphabet, so ASCII order equals numeric order
    # (SPEC.md Section 3.2) and comparing with MAX_UUID58 checks the range.
    return (
        isinstance(s, str)
        and len(s) == _ENCODED_LENGTH
        and all(c in _DIGIT_VALUES for c in s)
        and s <= MAX_UUID58
    )


def uuid58() -> str:
    """Generates a random (version 4) UUID and returns its uuid58 encoding."""
    return _encode_uint128(_uuid.uuid4().int)
