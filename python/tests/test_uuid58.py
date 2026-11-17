"""Tests beyond spec/vectors.json: inputs JSON cannot express (SPEC.md 4.1),
Python-specific pitfalls, the API surface, and properties."""

from __future__ import annotations

import enum
import uuid
from typing import Any

import pytest
from hypothesis import given
from hypothesis import strategies as st

import uuid58

SAMPLE_UUID = "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf"
SAMPLE_UUID58 = "XDY9dmBbcMBXqcRvYw8xJ2"
MAX_UINT128 = (1 << 128) - 1

uint128 = st.integers(min_value=0, max_value=MAX_UINT128)


def kind_of(fn: Any, arg: Any) -> str:
    with pytest.raises(uuid58.Uuid58Error) as info:
        fn(arg)
    return info.value.kind.value


# --- Section 4.1: input that is not valid Unicode or not ASCII --------------


@pytest.mark.parametrize(
    "s",
    [
        "\ud800" * 22,  # lone high surrogates
        "\udfff" + SAMPLE_UUID58[1:],  # lone low surrogate
        SAMPLE_UUID58[:21] + "\udc80",  # surrogateescape'd 0x80 byte
        SAMPLE_UUID58[:10] + "\udcc1" + SAMPLE_UUID58[11:],  # escaped 0xC1 byte
        SAMPLE_UUID58[:21] + "\x80",
        SAMPLE_UUID58[:21] + "\xff",
        "Ł" + SAMPLE_UUID58[1:],  # U+0141: low byte is 0x41 ('A')
        "K" + SAMPLE_UUID58[1:],  # KELVIN SIGN, NFKC-equal to 'K'
        "１" + SAMPLE_UUID58[1:],  # FULLWIDTH DIGIT ONE
        "١" + SAMPLE_UUID58[1:],  # ARABIC-INDIC DIGIT ONE
        "\U0001d7d9" + SAMPLE_UUID58[1:],  # MATHEMATICAL DOUBLE-STRUCK ONE
    ],
)
def test_decode_rejects_non_ascii(s: str) -> None:
    assert kind_of(uuid58.decode, s) in ("invalid_length", "invalid_character")
    assert not uuid58.is_uuid58(s)


@pytest.mark.parametrize(
    "s",
    [
        "\ud800" * 32,
        "\ud800" * 36,
        SAMPLE_UUID[:35] + "\udcff",
        SAMPLE_UUID.replace("-", "")[:31] + "\udc80",
        "０" * 32,  # FULLWIDTH DIGIT ZERO
        "٠" * 32,  # ARABIC-INDIC DIGIT ZERO: int() would accept it
        "Ａ" + SAMPLE_UUID[1:],  # FULLWIDTH LATIN CAPITAL A
        SAMPLE_UUID[:8] + "‐" + SAMPLE_UUID[9:],  # HYPHEN, not '-'
        SAMPLE_UUID[:8] + "−" + SAMPLE_UUID[9:],  # MINUS SIGN
    ],
)
def test_encode_rejects_non_ascii(s: str) -> None:
    assert kind_of(uuid58.encode, s) in ("invalid_length", "invalid_character")


# --- Section 5.1 note: stdlib parser leniency must not leak ----------------


@pytest.mark.parametrize(
    "s",
    [
        "{" + SAMPLE_UUID + "}",
        "urn:uuid:" + SAMPLE_UUID,
        "{" + SAMPLE_UUID.replace("-", "") + "}",  # 34 chars
        "f4b247fd1f87-45d4-aa06-1c6fc0a8dfaf-",  # misplaced hyphens, 36
        "+" + SAMPLE_UUID.replace("-", "")[1:],  # int(s, 16) accepts '+'
        "-" + SAMPLE_UUID.replace("-", "")[1:],
        "f4b247fd_1f8745d4aa061c6fc0a8dfa",  # int(s, 16) accepts '_'
        "0x" + SAMPLE_UUID.replace("-", "")[2:],  # int(s, 16) accepts '0x'
        " " + SAMPLE_UUID.replace("-", "")[1:],  # int() strips whitespace
        SAMPLE_UUID.replace("-", "")[:31] + "\n",
        SAMPLE_UUID[:35] + "\n",
    ],
)
def test_encode_rejects_stdlib_lenient_forms(s: str) -> None:
    with pytest.raises(uuid58.Uuid58Error):
        uuid58.encode(s)


def test_decode_does_not_trim() -> None:
    assert kind_of(uuid58.decode, " " + SAMPLE_UUID58) == "invalid_length"
    assert kind_of(uuid58.decode, SAMPLE_UUID58[:21] + "\n") == "invalid_character"


# --- Types ------------------------------------------------------------------


@pytest.mark.parametrize("value", [True, False, 1.0, None, [], memoryview(b"x" * 16)])
def test_encode_rejects_other_types(value: Any) -> None:
    with pytest.raises(TypeError):
        uuid58.encode(value)


def test_encode_bytes_are_raw_not_text() -> None:
    # bytes are 16 raw bytes, never ASCII text of a UUID.
    assert kind_of(uuid58.encode, SAMPLE_UUID.encode()) == "invalid_length"
    assert kind_of(uuid58.encode, SAMPLE_UUID.replace("-", "").encode()) == (
        "invalid_length"
    )


def test_encode_int_subclass() -> None:
    class Big(enum.IntEnum):
        MAX = MAX_UINT128

    assert uuid58.encode(Big.MAX) == uuid58.MAX_UUID58


@pytest.mark.parametrize("decoder", [uuid58.decode, uuid58.decode_int])
@pytest.mark.parametrize("value", [SAMPLE_UUID58.encode(), None, 1])
def test_decode_rejects_non_str(decoder: Any, value: Any) -> None:
    with pytest.raises(TypeError):
        decoder(value)


@pytest.mark.parametrize("value", [SAMPLE_UUID58.encode(), None, 1, object()])
def test_is_uuid58_non_str_is_false(value: Any) -> None:
    assert uuid58.is_uuid58(value) is False


# --- Errors -----------------------------------------------------------------


def test_error_hierarchy() -> None:
    for cls, kind in [
        (uuid58.InvalidLengthError, "invalid_length"),
        (uuid58.InvalidCharacterError, "invalid_character"),
        (uuid58.ValueOverflowError, "overflow"),
    ]:
        assert issubclass(cls, uuid58.Uuid58Error)
        assert issubclass(cls, ValueError)
        assert cls.kind == kind
        assert cls.kind is uuid58.ErrorKind(kind)
        assert str(cls.kind) == kind
    assert not issubclass(uuid58.ValueOverflowError, OverflowError)


def test_error_message_excludes_input() -> None:
    """SPEC.md Section 7: error messages leave the untrusted input out."""
    with pytest.raises(uuid58.InvalidLengthError) as length_info:
        uuid58.decode("a" * 10_000 + "\n")
    assert "aa" not in str(length_info.value)
    with pytest.raises(uuid58.InvalidCharacterError) as info:
        uuid58.decode("1111111111111111111\nab")
    assert str(info.value) == "Invalid uuid58 character at position 19"
    with pytest.raises(uuid58.InvalidCharacterError) as info:
        uuid58.encode("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfa\n")
    assert str(info.value) == (
        "Invalid UUID: expected a hexadecimal digit at position 35"
    )


# --- Generation and properties ----------------------------------------------


def test_uuid58_generator() -> None:
    generated = uuid58.uuid58()
    assert uuid58.is_uuid58(generated)
    native = uuid58.decode_uuid(generated)
    assert native.version == 4
    assert native.variant == uuid.RFC_4122


@given(uint128)
def test_property_roundtrip(n: int) -> None:
    encoded = uuid58.encode(n)
    assert len(encoded) == 22
    assert uuid58.is_uuid58(encoded)
    assert uuid58.decode_int(encoded) == n
    native = uuid.UUID(int=n)
    assert uuid58.decode(encoded) == str(native)
    assert uuid58.decode_uuid(encoded) == native
    assert uuid58.decode_bytes(encoded) == native.bytes
    assert uuid58.encode(str(native)) == encoded
    assert uuid58.encode(str(native).upper()) == encoded
    assert uuid58.encode(native.hex) == encoded
    assert uuid58.encode(native.bytes) == encoded
    assert uuid58.encode(native) == encoded


@given(uint128, uint128)
def test_property_order_preserving(a: int, b: int) -> None:
    ea, eb = uuid58.encode(a), uuid58.encode(b)
    assert (ea < eb) == (a < b)
    assert (ea == eb) == (a == b)


@given(
    st.one_of(st.text(), st.text(alphabet=uuid58.ALPHABET, min_size=22, max_size=22))
)
def test_property_is_uuid58_matches_decode(s: str) -> None:
    try:
        uuid58.decode(s)
    except uuid58.Uuid58Error:
        decodes = False
    else:
        decodes = True
    assert uuid58.is_uuid58(s) is decodes


@given(st.text(alphabet=uuid58.ALPHABET, min_size=22, max_size=22))
def test_property_decode_range_check(s: str) -> None:
    if s <= uuid58.MAX_UUID58:
        assert uuid58.encode(uuid58.decode_int(s)) == s
    else:
        assert kind_of(uuid58.decode, s) == "overflow"


@given(st.text(max_size=40))
def test_property_encode_only_accepts_strict_forms(s: str) -> None:
    hexdigits = set("0123456789abcdefABCDEF")
    plain = len(s) == 32 and all(c in hexdigits for c in s)
    hyphenated = (
        len(s) == 36
        and all(s[i] == "-" for i in (8, 13, 18, 23))
        and all(c in hexdigits for i, c in enumerate(s) if i not in (8, 13, 18, 23))
    )
    try:
        uuid58.encode(s)
    except uuid58.Uuid58Error:
        assert not plain
        assert not hyphenated
    else:
        assert plain or hyphenated
