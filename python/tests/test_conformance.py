"""Runs every applicable case in spec/vectors.json (SPEC.md Section 8)."""

from __future__ import annotations

import json
import uuid
from pathlib import Path
from typing import Any

import pytest

import uuid58

VECTORS_PATH = Path(__file__).resolve().parents[2] / "spec" / "vectors.json"
VECTORS: dict[str, Any] = json.loads(VECTORS_PATH.read_text(encoding="utf-8"))

ROUNDTRIP = VECTORS["roundtrip"]
ENCODE_VALID = VECTORS["encode"]["valid"]
ENCODE_INVALID = VECTORS["encode"]["invalid"]
INVALID_BYTES = VECTORS["encode"]["invalid_bytes"]
INVALID_INTEGERS = VECTORS["encode"]["invalid_integers"]
DECODE_INVALID = VECTORS["decode"]["invalid"]

KIND_TO_ERROR: dict[str, type[uuid58.Uuid58Error]] = {
    "invalid_length": uuid58.InvalidLengthError,
    "invalid_character": uuid58.InvalidCharacterError,
    "overflow": uuid58.ValueOverflowError,
}


def ids(cases: list[dict[str, Any]]) -> list[str]:
    return [case["description"] for case in cases]


def expect_kind(exc: uuid58.Uuid58Error, errors: list[str]) -> None:
    assert isinstance(exc, ValueError)
    assert exc.kind in errors
    # The subclass and the kind attribute must agree.
    assert type(exc) is KIND_TO_ERROR[exc.kind.value]


def test_vectors_metadata() -> None:
    assert VECTORS["spec_version"] == "1.0.0-draft"
    assert VECTORS["alphabet"] == uuid58.ALPHABET
    assert max(ROUNDTRIP, key=lambda c: c["uuid58"])["uuid58"] == uuid58.MAX_UUID58


@pytest.mark.parametrize("case", ROUNDTRIP, ids=ids(ROUNDTRIP))
def test_roundtrip(case: dict[str, str]) -> None:
    text, encoded = case["uuid"], case["uuid58"]
    hex32 = text.replace("-", "")
    raw = bytes.fromhex(hex32)
    as_int = int(hex32, 16)

    # UUID strings (Section 5).
    assert uuid58.encode(text) == encoded
    assert uuid58.decode(encoded) == text

    # 16 bytes and integers (Section 8.1: hyphens removed, read big-endian).
    assert uuid58.encode(raw) == encoded
    assert uuid58.encode(bytearray(raw)) == encoded
    assert uuid58.encode(as_int) == encoded
    assert uuid58.decode_bytes(encoded) == raw
    assert uuid58.decode_int(encoded) == as_int

    # Native uuid.UUID, compared against the vector's text and bytes, not
    # only round-tripped through itself (Section 8.1).
    native = uuid58.decode_uuid(encoded)
    assert str(native) == text
    assert native.bytes == raw
    assert uuid58.encode(uuid.UUID(text)) == encoded
    assert uuid58.encode(uuid.UUID(bytes=raw)) == encoded

    # Validation (Section 6).
    assert uuid58.is_uuid58(encoded)


@pytest.mark.parametrize("case", ENCODE_VALID, ids=ids(ENCODE_VALID))
def test_encode_valid(case: dict[str, str]) -> None:
    assert uuid58.encode(case["input"]) == case["output"]


@pytest.mark.parametrize("case", ENCODE_INVALID, ids=ids(ENCODE_INVALID))
def test_encode_invalid(case: dict[str, Any]) -> None:
    # Cases marked "lenient" are accepted by JavaScript 1.x only; this
    # implementation is strict and MUST reject them (Section 9.1).
    with pytest.raises(uuid58.Uuid58Error) as info:
        uuid58.encode(case["input"])
    expect_kind(info.value, case["errors"])


@pytest.mark.parametrize("case", INVALID_BYTES, ids=ids(INVALID_BYTES))
def test_encode_invalid_bytes(case: dict[str, Any]) -> None:
    raw = bytes.fromhex(case["bytes"])
    for value in (raw, bytearray(raw)):
        with pytest.raises(uuid58.Uuid58Error) as info:
            uuid58.encode(value)
        expect_kind(info.value, case["errors"])


@pytest.mark.parametrize("case", INVALID_INTEGERS, ids=ids(INVALID_INTEGERS))
def test_encode_invalid_integers(case: dict[str, Any]) -> None:
    with pytest.raises(uuid58.Uuid58Error) as info:
        uuid58.encode(int(case["integer"]))
    expect_kind(info.value, case["errors"])


DECODERS = [uuid58.decode, uuid58.decode_bytes, uuid58.decode_int, uuid58.decode_uuid]


@pytest.mark.parametrize("case", DECODE_INVALID, ids=ids(DECODE_INVALID))
@pytest.mark.parametrize("decoder", DECODERS, ids=lambda f: f.__name__)
def test_decode_invalid(case: dict[str, Any], decoder: Any) -> None:
    with pytest.raises(uuid58.Uuid58Error) as info:
        decoder(case["input"])
    expect_kind(info.value, case["errors"])


@pytest.mark.parametrize("case", DECODE_INVALID, ids=ids(DECODE_INVALID))
def test_validation_rejects_decode_invalid(case: dict[str, Any]) -> None:
    assert not uuid58.is_uuid58(case["input"])
