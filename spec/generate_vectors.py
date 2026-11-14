#!/usr/bin/env python3
"""Generate spec/vectors.json from an independent reference implementation.

This script deliberately does not use any uuid58 implementation in this
repository. It implements the rules of SPEC.md directly with Python's
arbitrary-precision integers, so bugs in an implementation cannot leak into
the test vectors.

Usage:
    python3 spec/generate_vectors.py          # rewrite spec/vectors.json
    python3 spec/generate_vectors.py --check  # fail if the file is stale

Requires Python 3.8+ and the standard library only.
"""

import hashlib
import json
import re
import sys
from pathlib import Path

SPEC_VERSION = "1.0.0-draft"
ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
UUID58_LENGTH = 22
MAX_VALUE = (1 << 128) - 1

VECTORS_PATH = Path(__file__).resolve().parent / "vectors.json"

HEX_DIGITS = set("0123456789abcdefABCDEF")
HYPHEN_POSITIONS = (8, 13, 18, 23)


# ---------------------------------------------------------------------------
# Reference implementation (SPEC.md, sections "Encoding" and "Decoding")
# ---------------------------------------------------------------------------


def encode_value(value):
    """Encode a 128-bit unsigned integer as a 22-character Base58 string."""
    assert 0 <= value <= MAX_VALUE
    digits = []
    for _ in range(UUID58_LENGTH):
        value, rem = divmod(value, 58)
        digits.append(ALPHABET[rem])
    assert value == 0
    return "".join(reversed(digits))


def format_uuid(value):
    """Format a 128-bit unsigned integer as a canonical UUID string."""
    h = format(value, "032x")
    return f"{h[0:8]}-{h[8:12]}-{h[12:16]}-{h[16:20]}-{h[20:32]}"


# SPEC.md Section 4.1: input containing a non-ASCII character is always
# invalid, and an implementation may report either kind for it.
NON_ASCII_KINDS = frozenset({"invalid_length", "invalid_character"})


def parse_uuid(text):
    """Parse a UUID string. Returns the value, or a set of error kinds."""
    if not text.isascii():
        return set(NON_ASCII_KINDS)
    if len(text) == 32:
        ok = all(c in HEX_DIGITS for c in text)
    elif len(text) == 36:
        ok = all(
            (c == "-") if i in HYPHEN_POSITIONS else (c in HEX_DIGITS)
            for i, c in enumerate(text)
        )
    else:
        return {"invalid_length"}
    if not ok:
        return {"invalid_character"}
    return int(text.replace("-", ""), 16)


def decode_uuid58(text):
    """Decode a uuid58 string. Returns the value, or a set of error kinds."""
    if not text.isascii():
        return set(NON_ASCII_KINDS)
    if len(text) != UUID58_LENGTH:
        return {"invalid_length"}

    value = 0
    for c in text:
        index = ALPHABET.find(c)
        if index < 0:
            return {"invalid_character"}
        value = value * 58 + index
    if value > MAX_VALUE:
        return {"overflow"}
    return value


def is_lenient(text):
    """True if uuid58 JavaScript 1.x accepts this strictly invalid input.

    JavaScript 1.x removes every hyphen, wherever it is, and then requires
    32 hexadecimal digits. SPEC.md lists this as a known deviation.
    """
    return re.fullmatch(r"[0-9a-fA-F]{32}", text.replace("-", "")) is not None


# ---------------------------------------------------------------------------
# Test inputs
# ---------------------------------------------------------------------------


def sample_values():
    """(value, description) pairs for the round-trip vectors."""
    values = [
        (0, "nil UUID (all zero bits)"),
        (1, "smallest non-zero value"),
        (57, "largest single-digit value"),
        (58, "smallest two-digit value"),
        (58**9 - 1, "58^9 - 1 (largest 9-digit value)"),
        (58**9, "58^9 (smallest 10-digit value)"),
        (58**18 - 1, "58^18 - 1"),
        (58**18, "58^18"),
        (58**21 - 1, "58^21 - 1 (largest 21-digit value)"),
        (58**21, "58^21 (smallest value that needs all 22 digits)"),
        ((1 << 53) - 1, "2^53 - 1"),
        (1 << 53, "2^53"),
        ((1 << 64) - 1, "2^64 - 1"),
        (1 << 64, "2^64"),
        ((1 << 32) - 1, "2^32 - 1"),
        (1 << 32, "2^32"),
        ((1 << 63) - 1, "2^63 - 1 (largest signed 64-bit value)"),
        (1 << 63, "2^63 (sign bit of a signed 64-bit low half)"),
        ((1 << 64) + (1 << 63), "2^64 + 2^63"),
        (1 << 96, "2^96"),
        ((1 << 127) - 1, "2^127 - 1"),
        (1 << 127, "2^127 (only the top bit set)"),
        ((1 << 127) | (1 << 63), "2^127 + 2^63 (sign bit set in both halves)"),
        (MAX_VALUE - (1 << 64) + 1, "2^128 - 2^64 (high half all ones, low half zero)"),
        (MAX_VALUE - 1, "max UUID - 1"),
        (MAX_VALUE, "max UUID (all one bits)"),
        (0xF4B247FD1F8745D4AA061C6FC0A8DFAF, "README example (UUIDv4)"),
        (0x123E4567E89B12D3A456426614174000, "common documentation example"),
        (0x00112233445566778899AABBCCDDEEFF, "leading zero byte"),
    ]
    # Values near the top of the range, given by their encoding.
    for text, description in [
        ("Y111111111111111111111", "smallest value with first digit Y"),
        ("YcVfxkQb6JRzqk5kF2tNL1", "max UUID with the last digit zeroed"),
        # Below max in ASCII order, but not under case-insensitive or
        # dictionary-style comparison (SPEC.md Section 3.2).
        ("YcVfxkQb6JRzqk5kF2tNLZ", "below max only in ASCII order (Z < v)"),
        ("YcVfxkQB6JRzqk5kF2tNLv", "below max only in ASCII order (B < b)"),
    ]:
        value = decode_uuid58(text)
        assert isinstance(value, int), text
        values.append((value, description))
    # Deterministic pseudo-random values, stable across Python versions.
    for i in range(16):
        digest = hashlib.sha256(f"uuid58-vector-{i}".encode()).digest()
        values.append((int.from_bytes(digest[:16], "big"), f"pseudo-random #{i}"))
    return values


EXAMPLE = "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf"
EXAMPLE_HEX = EXAMPLE.replace("-", "")

EXTRA_VALID_ENCODE_INPUTS = [
    (EXAMPLE_HEX, "32 hex digits without hyphens"),
    (EXAMPLE.upper(), "uppercase, hyphenated"),
    (EXAMPLE_HEX.upper(), "uppercase, without hyphens"),
    ("F4b247Fd-1F87-45d4-Aa06-1c6FC0a8DfAf", "mixed case"),
    ("ABCDEF01-2345-6789-ABCD-EF0123456789", "every uppercase hex letter"),
    ("abcdef0123456789abcdef0123456789", "every lowercase hex letter, without hyphens"),
]

INVALID_ENCODE_INPUTS = [
    ("", "empty string"),
    ("f4b247fd", "too short"),
    (EXAMPLE_HEX[:31], "31 hex digits"),
    (EXAMPLE_HEX + "0", "33 hex digits"),
    (EXAMPLE[:35], "35 characters, hyphenated"),
    (EXAMPLE + "0", "37 characters, hyphenated"),
    (EXAMPLE_HEX + "0000", "36 hex digits without hyphens"),
    ("g" + EXAMPLE_HEX[1:], "non-hex letter, 32 characters"),
    ("g" + EXAMPLE[1:], "non-hex letter, hyphenated"),
    ("0x" + EXAMPLE_HEX[2:], "0x prefix"),
    (" " + EXAMPLE_HEX[1:], "leading space, 32 characters"),
    (EXAMPLE_HEX[:31] + "\n", "trailing newline, 32 characters"),
    (" " + EXAMPLE, "leading space, hyphenated"),
    (EXAMPLE + "\n", "trailing newline, hyphenated"),
    ("{" + EXAMPLE + "}", "braces"),
    ("urn:uuid:" + EXAMPLE, "URN prefix"),
    (EXAMPLE.replace("-", "_"), "underscores instead of hyphens"),
    (EXAMPLE_HEX[:8] + "-" + EXAMPLE_HEX[8:], "one hyphen only (33 characters)"),
    ("f4b247f-d1f87-45d4-aa06-1c6fc0a8dfaf", "hyphen in the wrong position"),
    ("f4b247fd1f87-45d4-aa06-1c6fc0a8dfaf", "first hyphen missing"),
    ("f4b247fd-1f874-5d4-aa06-1c6fc0a8dfaf", "second hyphen in the wrong position"),
    ("f4b247fd-1f87-45d4a-a06-1c6fc0a8dfaf", "third hyphen in the wrong position"),
    ("f4b247fd-1f87-45d4-aa061-c6fc0a8dfaf", "fourth hyphen in the wrong position"),
    # A hex digit or another character where exactly one hyphen belongs.
    ("f4b247fd01f87-45d4-aa06-1c6fc0a8dfaf", "digit at index 8 instead of a hyphen"),
    ("f4b247fd-1f87045d4-aa06-1c6fc0a8dfaf", "digit at index 13 instead of a hyphen"),
    ("f4b247fd-1f87-45d40aa06-1c6fc0a8dfaf", "digit at index 18 instead of a hyphen"),
    ("f4b247fd-1f87-45d4-aa0601c6fc0a8dfaf", "digit at index 23 instead of a hyphen"),
    ("f4b247fd-1f87-45d4-aa06_1c6fc0a8dfaf", "underscore at index 23 instead of a hyphen"),
    (EXAMPLE + "-", "trailing hyphen"),
    ("-" * 4 + EXAMPLE_HEX, "hyphens before the digits"),
    ("f4b2-47fd-1f87-45d4-aa06-1c6f-c0a8-dfaf", "hyphen every four digits"),
    ("e" + EXAMPLE_HEX[1:31] + "é", "non-ASCII letter (U+00E9)"),
    (EXAMPLE_HEX[:31] + "０", "fullwidth digit zero (U+FF10)"),
    (EXAMPLE_HEX[:31] + "\U0001f600", "astral-plane character (U+1F600)"),
    # Lenient standard-library parsers (signs, digit separators, anchors).
    ("+" + EXAMPLE_HEX[1:], "leading plus sign, 32 characters"),
    ("-" + EXAMPLE_HEX[1:], "leading minus sign, 32 characters"),
    ("-" + EXAMPLE[1:], "leading minus sign, hyphenated"),
    (EXAMPLE[:9] + "+" + EXAMPLE[10:], "plus sign inside a group, hyphenated"),
    ("+" + EXAMPLE[1:], "leading plus sign, hyphenated"),
    (EXAMPLE_HEX[:16] + "+" + EXAMPLE_HEX[17:], "plus sign at index 16, 32 characters"),
    (EXAMPLE_HEX[:8] + "_" + EXAMPLE_HEX[9:], "underscore between digits, 32 characters"),
    (EXAMPLE_HEX + "\n", "32 hex digits and a trailing newline"),
    ("1-2-3-4-5", "short groups"),
    # ASCII line break that some languages count as one character.
    (EXAMPLE_HEX[:30] + "\r\n", "CRLF at the end, 32 code units"),
    # Characters whose low 8 bits are a hex digit.
    (EXAMPLE_HEX[:31] + "\u0141", "U+0141 (low byte is A)"),
    (EXAMPLE_HEX[:31] + "\u0161", "U+0161 (low byte is a)"),
    (EXAMPLE_HEX[:31] + "\u0130", "U+0130 (low byte is 0)"),
    # Non-ASCII input that is exactly 32 or 36 long in UTF-8 bytes or UTF-16
    # code units, so it reaches the character check in those implementations.
    (EXAMPLE_HEX[:30] + "\u00b1", "30 hex digits and U+00B1 (32 UTF-8 bytes)"),
    (EXAMPLE[:34] + "\u00b1", "34 characters and U+00B1 (36 UTF-8 bytes)"),
    (EXAMPLE_HEX[:30] + "\U0001f600", "30 hex digits and U+1F600 (32 UTF-16 code units)"),
    # Control characters that become digits when OR-ed with 0x20.
    (EXAMPLE_HEX[:12] + "\x10" + EXAMPLE_HEX[13:], "U+0010 (0x10 | 0x20 is 0)"),
    (EXAMPLE_HEX[:20] + "\x19" + EXAMPLE_HEX[21:], "U+0019 (0x19 | 0x20 is 9)"),
    # NUL after a valid UUID (C-string truncation).
    (EXAMPLE_HEX + "\x00", "32 hex digits and NUL"),
    (EXAMPLE + "\x00", "hyphenated UUID and NUL"),
    # ASCII neighbours of the hex digit ranges, at interior positions.
    (EXAMPLE_HEX[:5] + "/" + EXAMPLE_HEX[6:], "contains / (before 0)"),
    (EXAMPLE_HEX[:10] + ":" + EXAMPLE_HEX[11:], "contains : (after 9)"),
    (EXAMPLE_HEX[:15] + "@" + EXAMPLE_HEX[16:], "contains @ (before A)"),
    (EXAMPLE_HEX[:20] + "G" + EXAMPLE_HEX[21:], "contains G (after F)"),
    (EXAMPLE_HEX[:25] + "`" + EXAMPLE_HEX[26:], "contains ` (before a)"),
    (EXAMPLE[:14] + "g" + EXAMPLE[15:], "contains g (after f), hyphenated"),
]

MAX_UUID58 = encode_value(MAX_VALUE)
VALID_UUID58 = encode_value(0xF4B247FD1F8745D4AA061C6FC0A8DFAF)

INVALID_DECODE_INPUTS = [
    ("", "empty string"),
    (VALID_UUID58[:21], "21 characters"),
    (VALID_UUID58 + "1", "23 characters"),
    ("1" * 23, "23 characters of the zero digit"),
    ("0" + VALID_UUID58[1:], "contains 0 (zero)"),
    ("O" + VALID_UUID58[1:], "contains O (capital o)"),
    ("I" + VALID_UUID58[1:], "contains I (capital i)"),
    ("l" + VALID_UUID58[1:], "contains l (lowercase L)"),
    (VALID_UUID58[:21] + "+", "contains +"),
    (VALID_UUID58[:21] + "/", "contains /"),
    (VALID_UUID58[:21] + "-", "contains -"),
    (VALID_UUID58[:21] + "_", "contains _"),
    (" " + VALID_UUID58[1:], "leading space, 22 characters"),
    (VALID_UUID58[:21] + "\n", "trailing newline, 22 characters"),
    (" " + VALID_UUID58, "leading space, 23 characters"),
    (VALID_UUID58 + "\n", "trailing newline, 23 characters"),
    (VALID_UUID58[:21] + "\x00", "NUL character"),
    (VALID_UUID58[:21] + "é", "non-ASCII letter (U+00E9)"),
    (VALID_UUID58[:21] + "Ａ", "fullwidth A (U+FF21)"),
    (VALID_UUID58[:21] + "\U0001f600", "astral-plane character (U+1F600)"),
    (MAX_UUID58[:-1] + "w", "max UUID + 1"),
    ("Z" + "1" * 21, "first digit Z (exceeds 128 bits)"),
    ("z" * 22, "largest 22-character value"),
    ("0" + "z" * 21, "invalid first character, overflowing digits"),
    # The character check comes before the range check (SPEC.md Section 4),
    # even when the invalid character is last.
    ("Z" + "z" * 20 + "0", "overflowing digits, invalid last character"),
    (MAX_UUID58[:-1] + "0", "max UUID prefix, invalid last character"),
    ("z" * 11 + "!" + "z" * 10, "overflowing digits, invalid middle character"),
    # The length check comes first.
    ("z" * 23, "23 characters that would overflow"),
    # Overflow detected at different positions.
    ("Yd" + "1" * 20, "overflow decided by the second digit"),
    ("YcVfxkQb6JS" + "1" * 11, "overflow decided by the eleventh digit"),
    # Above max in ASCII order, but not under case-insensitive or
    # dictionary-style comparison (SPEC.md Section 3.2).
    ("Yca" + "1" * 19, "above max only in ASCII order (a > V)"),
    ("Ycv" + "1" * 19, "above max only in ASCII order (v > V)"),
    # ASCII line break that some languages count as one character.
    (VALID_UUID58[:20] + "\r\n", "CRLF at the end, 22 code units"),
    # Characters whose low 8 bits are an alphabet character.
    (VALID_UUID58[:10] + "\u0141" + VALID_UUID58[11:], "U+0141 (low byte is A)"),
    (VALID_UUID58[:10] + "\u0171" + VALID_UUID58[11:], "U+0171 (low byte is q)"),
    (VALID_UUID58[:20] + "\u00e9", "20 characters and U+00E9 (22 UTF-8 bytes)"),
    (VALID_UUID58[:20] + "\u00f1", "20 characters and U+00F1 (22 UTF-8 bytes)"),
    (VALID_UUID58[:20] + "\U0001f600", "20 characters and U+1F600 (22 UTF-16 code units)"),
    # Canonically equivalent to an alphabet character (Swift compares
    # Characters this way, and NFKC normalization maps it too).
    ("\u212a" + "Kj6FuLStPJZaGMVmm9i2Y", "U+212A KELVIN SIGN in place of K"),
    # NUL after a valid uuid58 string (C-string truncation).
    (VALID_UUID58 + "\x00", "22 characters and NUL"),
    # ASCII neighbours of the alphabet ranges, at chunk boundaries.
    (VALID_UUID58[:3] + ":" + VALID_UUID58[4:], "contains : (after 9) at index 3"),
    (VALID_UUID58[:4] + "@" + VALID_UUID58[5:], "contains @ (before A) at index 4"),
    (VALID_UUID58[:12] + "[" + VALID_UUID58[13:], "contains [ (after Z) at index 12"),
    (VALID_UUID58[:13] + "`" + VALID_UUID58[14:], "contains ` (before a) at index 13"),
    (VALID_UUID58[:17] + "{" + VALID_UUID58[18:], "contains { (after z) at index 17"),
    (VALID_UUID58[:8] + "O" + VALID_UUID58[9:], "contains O at index 8"),
    (VALID_UUID58[:9] + "l" + VALID_UUID58[10:], "contains l at index 9"),
    (VALID_UUID58[:16] + "I" + VALID_UUID58[17:], "contains I at index 16"),
]

# SPEC.md Section 3.3: invalid inputs for APIs that encode from bytes or from
# an arbitrary-precision integer.
INVALID_BYTES = [
    ("", "no bytes"),
    ("00" * 15, "15 bytes"),
    ("00" * 17, "17 bytes"),
    ("ff" * 32, "32 bytes"),
]

INVALID_INTEGERS = [
    (-1, "-1"),
    (-(1 << 127), "-2^127"),
    (1 << 128, "2^128"),
    ((1 << 128) + 1, "2^128 + 1"),
    (1 << 129, "2^129"),
]


# ---------------------------------------------------------------------------
# Assembly
# ---------------------------------------------------------------------------


def build():
    roundtrip = []
    for value, description in sample_values():
        roundtrip.append(
            {
                "description": description,
                "uuid": format_uuid(value),
                "uuid58": encode_value(value),
            }
        )

    encode_valid = []
    for text, description in EXTRA_VALID_ENCODE_INPUTS:
        value = parse_uuid(text)
        assert isinstance(value, int), text
        encode_valid.append(
            {"description": description, "input": text, "output": encode_value(value)}
        )

    encode_invalid = []
    for text, description in INVALID_ENCODE_INPUTS:
        kinds = parse_uuid(text)
        assert isinstance(kinds, set), text
        case = {"description": description, "input": text, "errors": sorted(kinds)}
        if is_lenient(text):
            case["lenient"] = True
            case["lenient_output"] = encode_value(int(text.replace("-", ""), 16))
        encode_invalid.append(case)

    decode_invalid = []
    for text, description in INVALID_DECODE_INPUTS:
        kinds = decode_uuid58(text)
        assert isinstance(kinds, set), text
        decode_invalid.append(
            {"description": description, "input": text, "errors": sorted(kinds)}
        )

    invalid_bytes = [
        {"description": d, "bytes": h, "errors": ["invalid_length"]}
        for h, d in INVALID_BYTES
    ]
    invalid_integers = [
        {"description": d, "integer": str(n), "errors": ["overflow"]}
        for n, d in INVALID_INTEGERS
    ]

    # Self-checks on the reference implementation.
    for case in roundtrip:
        assert decode_uuid58(case["uuid58"]) == int(case["uuid"].replace("-", ""), 16)
        assert parse_uuid(case["uuid"]) == decode_uuid58(case["uuid58"])
    assert MAX_UUID58 == "YcVfxkQb6JRzqk5kF2tNLv"
    assert decode_uuid58(MAX_UUID58[:-1] + "w") == {"overflow"}

    return {
        "spec_version": SPEC_VERSION,
        "alphabet": ALPHABET,
        "roundtrip": roundtrip,
        "encode": {
            "valid": encode_valid,
            "invalid": encode_invalid,
            "invalid_bytes": invalid_bytes,
            "invalid_integers": invalid_integers,
        },
        "decode": {"invalid": decode_invalid},
    }


def render():
    return json.dumps(build(), indent=2, ensure_ascii=True) + "\n"


def main(argv):
    content = render()
    if "--check" in argv:
        current = VECTORS_PATH.read_text(encoding="utf-8") if VECTORS_PATH.exists() else ""
        if current != content:
            print(f"{VECTORS_PATH} is out of date; run spec/generate_vectors.py", file=sys.stderr)
            return 1
        print(f"{VECTORS_PATH} is up to date")
        return 0
    VECTORS_PATH.write_text(content, encoding="utf-8")
    print(f"wrote {VECTORS_PATH}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
