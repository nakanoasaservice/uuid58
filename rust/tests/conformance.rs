//! Runs the shared test vectors in `spec/vectors.json` against this crate
//! (SPEC.md Section 8), plus the non-Unicode inputs of Section 4.1 that JSON
//! cannot express.

use serde_json::Value;
use uuid58::Error;

fn vectors() -> Value {
    let path = concat!(env!("CARGO_MANIFEST_DIR"), "/../spec/vectors.json");
    let text = std::fs::read_to_string(path).expect("read spec/vectors.json");
    serde_json::from_str(&text).expect("parse spec/vectors.json")
}

fn cases<'a>(v: &'a Value, path: &[&str]) -> &'a [Value] {
    let mut v = v;
    for key in path {
        v = &v[key];
    }
    let cases = v.as_array().expect("array of cases");
    assert!(!cases.is_empty(), "no cases at {path:?}");
    cases
}

fn str_field<'a>(case: &'a Value, key: &str) -> &'a str {
    case[key]
        .as_str()
        .unwrap_or_else(|| panic!("{key} in {case}"))
}

fn kind(e: Error) -> &'static str {
    match e {
        Error::InvalidLength => "invalid_length",
        Error::InvalidCharacter => "invalid_character",
        Error::Overflow => "overflow",
    }
}

fn assert_kind<T: std::fmt::Debug>(result: Result<T, Error>, case: &Value) {
    let expected: Vec<&str> = case["errors"]
        .as_array()
        .expect("errors")
        .iter()
        .map(|e| e.as_str().unwrap())
        .collect();
    match result {
        Ok(v) => panic!("expected {expected:?}, got Ok({v:?}) for {case}"),
        Err(e) => assert!(
            expected.contains(&kind(e)),
            "expected {expected:?}, got {e:?} for {case}"
        ),
    }
}

fn hex_to_bytes(hex: &str) -> Vec<u8> {
    assert!(hex.len() % 2 == 0);
    (0..hex.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&hex[i..i + 2], 16).unwrap())
        .collect()
}

/// `uuid` with the hyphens removed, read as 16 big-endian bytes. Independent
/// of the crate's own UUID parser.
fn uuid_bytes(uuid: &str) -> [u8; 16] {
    hex_to_bytes(&uuid.replace('-', "")).try_into().unwrap()
}

#[test]
fn spec_version() {
    assert_eq!(vectors()["spec_version"], "1.1.0");
}

#[test]
fn alphabet() {
    assert_eq!(vectors()["alphabet"], uuid58::ALPHABET);
}

#[test]
fn roundtrip() {
    let v = vectors();
    for case in cases(&v, &["roundtrip"]) {
        let uuid = str_field(case, "uuid");
        let id = str_field(case, "uuid58");
        let bytes = uuid_bytes(uuid);
        let value = u128::from_be_bytes(bytes);

        let mut buf = [0u8; uuid58::ENCODED_LEN];
        assert_eq!(uuid58::encode_to_buf(value, &mut buf), id, "{case}");
        assert_eq!(uuid58::encode_bytes_to_buf(&bytes, &mut buf), id, "{case}");
        assert_eq!(uuid58::parse_uuid_str(uuid), Ok(value), "{case}");

        assert_eq!(uuid58::decode(id), Ok(value), "{case}");
        assert_eq!(uuid58::decode(id.as_bytes()), Ok(value), "{case}");
        assert_eq!(uuid58::decode_to_bytes(id), Ok(bytes), "{case}");
        let mut ubuf = [0xff; uuid58::UUID_STR_LEN];
        assert_eq!(
            uuid58::decode_to_uuid_buf(id, &mut ubuf),
            Ok(uuid),
            "{case}"
        );
        assert_eq!(ubuf.as_slice(), uuid.as_bytes(), "{case}");
        assert!(uuid58::is_valid(id), "{case}");

        #[cfg(feature = "alloc")]
        {
            assert_eq!(uuid58::encode(value), id, "{case}");
            assert_eq!(uuid58::encode_bytes(&bytes), id, "{case}");
            assert_eq!(uuid58::encode_slice(&bytes).as_deref(), Ok(id), "{case}");
            assert_eq!(uuid58::encode_uuid_str(uuid).as_deref(), Ok(id), "{case}");
            assert_eq!(
                uuid58::decode_to_uuid_string(id).as_deref(),
                Ok(uuid),
                "{case}"
            );
        }
    }
}

#[cfg(feature = "uuid")]
#[test]
fn roundtrip_uuid_feature() {
    let v = vectors();
    for case in cases(&v, &["roundtrip"]) {
        let uuid_str = str_field(case, "uuid");
        let id = str_field(case, "uuid58");
        // Compare against bytes derived from the vector, not only the
        // crate's own values, so a byte-order mistake cannot hide.
        let expected = uuid::Uuid::from_bytes(uuid_bytes(uuid_str));

        let decoded = uuid58::decode_uuid(id).expect("decode_uuid");
        assert_eq!(decoded, expected, "{case}");
        assert_eq!(decoded.as_bytes(), &uuid_bytes(uuid_str), "{case}");
        assert_eq!(
            decoded
                .hyphenated()
                .encode_lower(&mut uuid::Uuid::encode_buffer()),
            uuid_str,
            "{case}"
        );
        #[cfg(feature = "alloc")]
        assert_eq!(uuid58::encode_uuid(&expected), id, "{case}");
    }
}

#[test]
fn encode_valid() {
    let v = vectors();
    for case in cases(&v, &["encode", "valid"]) {
        let input = str_field(case, "input");
        let output = str_field(case, "output");
        let value = uuid58::parse_uuid_str(input).unwrap_or_else(|e| panic!("{e} for {case}"));
        let mut buf = [0u8; uuid58::ENCODED_LEN];
        assert_eq!(uuid58::encode_to_buf(value, &mut buf), output, "{case}");
        #[cfg(feature = "alloc")]
        assert_eq!(
            uuid58::encode_uuid_str(input).as_deref(),
            Ok(output),
            "{case}"
        );
    }
}

#[test]
fn encode_invalid() {
    let v = vectors();
    let mut lenient = 0;
    for case in cases(&v, &["encode", "invalid"]) {
        // Cases marked `lenient` are accepted by JavaScript 1.x only; this
        // implementation is strict and MUST reject them like any other.
        if case["lenient"] == true {
            lenient += 1;
        }
        let input = str_field(case, "input");
        assert_kind(uuid58::parse_uuid_str(input), case);
        assert_kind(uuid58::parse_uuid_str(input.as_bytes()), case);
        #[cfg(feature = "alloc")]
        assert_kind(uuid58::encode_uuid_str(input), case);
    }
    assert!(lenient > 0, "expected some lenient cases");
}

#[cfg(feature = "alloc")]
#[test]
fn encode_invalid_bytes() {
    let v = vectors();
    for case in cases(&v, &["encode", "invalid_bytes"]) {
        let bytes = hex_to_bytes(str_field(case, "bytes"));
        assert_kind(uuid58::encode_slice(&bytes), case);
    }
}

// `encode.invalid_integers` does not apply: the only integer input is
// `u128`, which cannot hold a value outside 0..=2^128-1 (SPEC.md 3.3).

#[test]
fn decode_invalid() {
    let v = vectors();
    for case in cases(&v, &["decode", "invalid"]) {
        let input = str_field(case, "input");
        assert_kind(uuid58::decode(input), case);
        assert_kind(uuid58::decode(input.as_bytes()), case);
        assert_kind(uuid58::decode_to_bytes(input), case);
        let mut buf = [0u8; uuid58::UUID_STR_LEN];
        assert_kind(uuid58::decode_to_uuid_buf(input, &mut buf), case);
        #[cfg(feature = "alloc")]
        assert_kind(uuid58::decode_to_uuid_string(input), case);
        #[cfg(feature = "uuid")]
        assert_kind(uuid58::decode_uuid(input), case);
    }
}

#[test]
fn validation() {
    let v = vectors();
    for case in cases(&v, &["roundtrip"]) {
        assert!(uuid58::is_valid(str_field(case, "uuid58")), "{case}");
    }
    for case in cases(&v, &["decode", "invalid"]) {
        assert!(!uuid58::is_valid(str_field(case, "input")), "{case}");
    }
}

// ---------------------------------------------------------------------------
// SPEC.md 4.1: inputs that are not valid UTF-8 / contain bytes >= 0x80.
// ---------------------------------------------------------------------------

const NON_ASCII: &[Error] = &[Error::InvalidLength, Error::InvalidCharacter];

fn assert_non_ascii_rejected<T: std::fmt::Debug>(result: Result<T, Error>, input: &[u8]) {
    match result {
        Ok(v) => panic!("accepted {input:x?} as {v:?}"),
        Err(e) => assert!(NON_ASCII.contains(&e), "{e:?} for {input:x?}"),
    }
}

/// Every non-ASCII byte value, substituted at every position of a valid
/// 22-byte uuid58 string (so the length check alone cannot reject it).
#[test]
fn decode_rejects_any_non_ascii_byte() {
    let valid = b"XDY9dmBbcMBXqcRvYw8xJ2";
    for pos in 0..valid.len() {
        for byte in 0x80..=0xffu8 {
            let mut input = *valid;
            input[pos] = byte;
            assert_eq!(uuid58::decode(input), Err(Error::InvalidCharacter));
            assert!(!uuid58::is_valid(input));
        }
    }
}

/// Bytes whose low 7 bits are an alphabet character (e.g. 0xC1 -> 'A')
/// must not be mapped to it.
#[test]
fn decode_does_not_strip_high_bit() {
    let mut input = *b"1111111111111111111111";
    input[21] = b'A' | 0x80;
    assert_eq!(uuid58::decode(input), Err(Error::InvalidCharacter));
}

#[test]
fn ill_formed_utf8() {
    let cases: &[&[u8]] = &[
        // 22 bytes containing 0xFF.
        b"XDY9dmBbcMBXqcRvYw8x\xff2",
        // Lone continuation byte.
        b"XDY9dmBbcMBXqcRvYw8x\x802",
        // Overlong lead byte 0xC1 (0xC1 0x81 would be an overlong 'A').
        b"XDY9dmBbcMBXqcRvYw8x\xc1\x81",
        // Truncated 2-byte sequence.
        b"XDY9dmBbcMBXqcRvYw8xJ\xc3",
        // Encoded UTF-16 surrogate (CESU-8 style), ill-formed in UTF-8.
        b"XDY9dmBbcMBXqcRvYw\xed\xa0\x80J",
        // Fullwidth digit one (valid UTF-8, but not ASCII), 22 code points.
        "XDY9dmBbcMBXqcRvYw8xJ\u{ff11}".as_bytes(),
        // Non-ASCII byte making the input 22 bytes long but 21 code points.
        "XDY9dmBbcMBXqcRvYw8x\u{e9}".as_bytes(),
    ];
    for &input in cases {
        assert_non_ascii_rejected(uuid58::decode(input), input);
        assert!(!uuid58::is_valid(input), "{input:x?}");
    }
}

#[test]
fn uuid_str_rejects_non_ascii() {
    let valid = *b"f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf";
    for pos in 0..valid.len() {
        for byte in [0x80u8, 0xb0, 0xc1, 0xe2, 0xff, b'0' | 0x80, b'-' | 0x80] {
            let mut input = valid;
            input[pos] = byte;
            assert_non_ascii_rejected(uuid58::parse_uuid_str(input), &input);
        }
    }
    let plain = b"f4b247fd1f8745d4aa061c6fc0a8dfa\xff";
    assert_non_ascii_rejected(uuid58::parse_uuid_str(plain), plain);
    // U+FF10 FULLWIDTH DIGIT ZERO is not '0'.
    let fullwidth = "f4b247fd1f8745d4aa061c6fc0a8df\u{ff10}";
    assert_non_ascii_rejected(uuid58::parse_uuid_str(fullwidth), fullwidth.as_bytes());
}

#[cfg(feature = "alloc")]
#[test]
fn encode_slice_any_length() {
    for len in 0..64 {
        let bytes = vec![0xffu8; len];
        let result = uuid58::encode_slice(&bytes);
        if len == 16 {
            assert_eq!(result.as_deref(), Ok(uuid58::MAX_UUID58));
        } else {
            assert_eq!(result, Err(Error::InvalidLength), "len {len}");
        }
    }
}

#[cfg(feature = "std")]
#[test]
fn error_traits() {
    fn is_error<E: std::error::Error + Send + Sync + 'static>(_: &E) {}
    is_error(&Error::Overflow);
    assert_eq!(Error::InvalidLength.to_string(), "invalid length");
}
