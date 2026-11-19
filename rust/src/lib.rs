//! Shorten UUIDs to 22-character Base58 strings, and back: URL-safe, with no
//! look-alike characters, and in the same sort order as the UUIDs.
//!
//! uuid58 writes a 128-bit UUID as an unsigned integer in base 58 using the
//! Bitcoin Base58 alphabet, always padded to exactly 22 characters. This crate
//! implements the [uuid58 specification][spec].
//!
//! ```text
//! f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf  <->  XDY9dmBbcMBXqcRvYw8xJ2
//! ```
//!
//! # Examples
//!
//! ```
//! # #[cfg(feature = "alloc")] {
//! // UUID string <-> uuid58
//! let id = uuid58::encode_uuid_str("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf")?;
//! assert_eq!(id, "XDY9dmBbcMBXqcRvYw8xJ2");
//! assert_eq!(
//!     uuid58::decode_to_uuid_string("XDY9dmBbcMBXqcRvYw8xJ2")?,
//!     "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf",
//! );
//!
//! // u128 <-> uuid58
//! assert_eq!(uuid58::encode(1), "1111111111111111111112");
//! assert_eq!(uuid58::decode("1111111111111111111112")?, 1);
//!
//! // Validation
//! assert!(uuid58::is_valid("XDY9dmBbcMBXqcRvYw8xJ2"));
//! assert!(!uuid58::is_valid("YcVfxkQb6JRzqk5kF2tNLw")); // > 2^128 - 1
//! # }
//! # Ok::<(), uuid58::Error>(())
//! ```
//!
//! Without an allocator, encode into a stack buffer:
//!
//! ```
//! let mut buf = [0u8; uuid58::ENCODED_LEN];
//! let id = uuid58::encode_to_buf(0xf4b247fd_1f87_45d4_aa06_1c6fc0a8dfaf, &mut buf);
//! assert_eq!(id, "XDY9dmBbcMBXqcRvYw8xJ2");
//! ```
//!
//! # Input handling
//!
//! Every function that takes text accepts anything that implements
//! `AsRef<[u8]>` (`&str`, `String`, `&[u8]`, `Vec<u8>`, ...) and works on its
//! bytes. Length is measured in bytes, and any byte that is not ASCII (`0x80`
//! and above, including every byte of ill-formed UTF-8) is rejected. Nothing
//! is trimmed or normalized.
//!
//! UUID strings are parsed strictly: only the 36-character hyphenated form and
//! the 32-character plain hexadecimal form are accepted, in any letter case.
//!
//! # Features
//!
//! - `std` (default): enables `alloc`, and `uuid/std` when `uuid` is enabled.
//! - `alloc`: functions that return `String`.
//! - `uuid`: conversions to and from `uuid::Uuid` (`encode_uuid`, `decode_uuid`).
//!
//! With `default-features = false` the crate is `#![no_std]` and needs no
//! allocator.
//!
//! [spec]: https://github.com/nakanoasaservice/uuid58/blob/main/spec/SPEC.md

#![no_std]
#![cfg_attr(docsrs, feature(doc_cfg))]

#[cfg(feature = "alloc")]
extern crate alloc;
#[cfg(feature = "std")]
extern crate std;

#[cfg(feature = "alloc")]
use alloc::string::String;
use core::fmt;

/// The uuid58 alphabet (the Bitcoin Base58 alphabet). The character at index
/// `i` is the digit with value `i`.
pub const ALPHABET: &str = match core::str::from_utf8(ALPHABET_BYTES) {
    Ok(s) => s,
    Err(_) => panic!("alphabet must be valid UTF-8"),
};

/// The length of every uuid58 string, in bytes (all characters are ASCII).
pub const ENCODED_LEN: usize = 22;

/// The length of a hyphenated UUID string, as produced by
/// [`decode_to_uuid_buf`].
pub const UUID_STR_LEN: usize = 36;

/// The encoding of `2^128 - 1`, the largest valid uuid58 string.
pub const MAX_UUID58: &str = "YcVfxkQb6JRzqk5kF2tNLv";

/// The encoding of `0` (the nil UUID).
pub const NIL_UUID58: &str = "1111111111111111111111";

const ALPHABET_BYTES: &[u8; 58] = b"123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";

const INVALID: u8 = 0xff;

/// Byte -> digit value, or `INVALID`. Bytes `0x80..=0xff` are all `INVALID`.
const DIGITS: [u8; 256] = make_digit_table(ALPHABET_BYTES);

const fn make_digit_table(alphabet: &[u8; 58]) -> [u8; 256] {
    let mut table = [INVALID; 256];
    let mut i = 0;
    while i < 58 {
        table[alphabet[i] as usize] = i as u8;
        i += 1;
    }
    table
}

/// `58^10`, the largest power of 58 used to split the work into `u64` chunks.
const CHUNK: u64 = 430_804_206_899_405_824;

/// The error kinds defined by Section 7 of the specification.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Error {
    /// The input has the wrong length.
    ///
    /// Returned by decoding (not 22 bytes), UUID string parsing (neither 32
    /// nor 36 bytes), and encoding from a byte slice (not 16 bytes).
    InvalidLength,
    /// The input has the right length but contains a byte that is not
    /// allowed in its position, including any non-ASCII byte.
    InvalidCharacter,
    /// The input is a well-formed uuid58 string, but its value is greater
    /// than `2^128 - 1`.
    Overflow,
}

impl fmt::Display for Error {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(match self {
            Error::InvalidLength => "invalid length",
            Error::InvalidCharacter => "invalid character",
            Error::Overflow => "value exceeds 128 bits",
        })
    }
}

impl core::error::Error for Error {}

// ---------------------------------------------------------------------------
// Encoding
// ---------------------------------------------------------------------------

#[inline]
fn digit_symbol(digit: usize) -> u8 {
    ALPHABET_BYTES[digit]
}

/// Writes the low `end - start` base-58 digits of `v` into `out[start..end]`.
fn write_digits(mut v: u64, out: &mut [u8; ENCODED_LEN], start: usize, end: usize) {
    let mut i = end;
    while i > start {
        i -= 1;
        out[i] = digit_symbol((v % 58) as usize);
        v /= 58;
    }
}

fn encode_array(value: u128) -> [u8; ENCODED_LEN] {
    // value = hi * 58^20 + mid * 58^10 + lo, with hi < 58^2.
    let chunk = u128::from(CHUNK);
    let lo = (value % chunk) as u64;
    let rest = value / chunk;
    let mid = (rest % chunk) as u64;
    let hi = (rest / chunk) as u64;
    let mut out = [0u8; ENCODED_LEN];
    write_digits(hi, &mut out, 0, 2);
    write_digits(mid, &mut out, 2, 12);
    write_digits(lo, &mut out, 12, 22);
    out
}

fn ascii_str(bytes: &[u8]) -> &str {
    match core::str::from_utf8(bytes) {
        Ok(s) => s,
        Err(_) => unreachable!("output is always ASCII"),
    }
}

/// Encodes a 128-bit value into `buf` and returns it as a `&str`.
///
/// This never fails and never allocates.
///
/// ```
/// let mut buf = [0u8; uuid58::ENCODED_LEN];
/// assert_eq!(uuid58::encode_to_buf(u128::MAX, &mut buf), uuid58::MAX_UUID58);
/// ```
pub fn encode_to_buf(value: u128, buf: &mut [u8; ENCODED_LEN]) -> &str {
    *buf = encode_array(value);
    ascii_str(buf)
}

/// Encodes 16 big-endian bytes into `buf` and returns it as a `&str`.
///
/// ```
/// let mut buf = [0u8; uuid58::ENCODED_LEN];
/// let mut bytes = [0u8; 16];
/// bytes[15] = 1;
/// assert_eq!(uuid58::encode_bytes_to_buf(&bytes, &mut buf), "1111111111111111111112");
/// ```
pub fn encode_bytes_to_buf<'a>(bytes: &[u8; 16], buf: &'a mut [u8; ENCODED_LEN]) -> &'a str {
    encode_to_buf(u128::from_be_bytes(*bytes), buf)
}

/// Encodes a 128-bit value.
///
/// ```
/// assert_eq!(uuid58::encode(0xf4b247fd_1f87_45d4_aa06_1c6fc0a8dfaf), "XDY9dmBbcMBXqcRvYw8xJ2");
/// ```
#[cfg(feature = "alloc")]
#[cfg_attr(docsrs, doc(cfg(feature = "alloc")))]
pub fn encode(value: u128) -> String {
    String::from(ascii_str(&encode_array(value)))
}

/// Encodes 16 bytes, read as a big-endian integer.
///
/// ```
/// assert_eq!(uuid58::encode_bytes(&[0xff; 16]), uuid58::MAX_UUID58);
/// ```
#[cfg(feature = "alloc")]
#[cfg_attr(docsrs, doc(cfg(feature = "alloc")))]
pub fn encode_bytes(bytes: &[u8; 16]) -> String {
    encode(u128::from_be_bytes(*bytes))
}

/// Encodes a byte slice that must be exactly 16 bytes long (big-endian).
///
/// # Errors
///
/// [`Error::InvalidLength`] if `bytes.len() != 16`. The input is never
/// truncated or padded.
///
/// ```
/// assert_eq!(uuid58::encode_slice(&[0u8; 16]).as_deref(), Ok(uuid58::NIL_UUID58));
/// assert_eq!(uuid58::encode_slice(&[0u8; 15]), Err(uuid58::Error::InvalidLength));
/// ```
#[cfg(feature = "alloc")]
#[cfg_attr(docsrs, doc(cfg(feature = "alloc")))]
pub fn encode_slice(bytes: &[u8]) -> Result<String, Error> {
    let bytes: &[u8; 16] = bytes.try_into().map_err(|_| Error::InvalidLength)?;
    Ok(encode_bytes(bytes))
}

/// Parses a UUID string and encodes it.
///
/// Accepts exactly the hyphenated form
/// (`f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf`) and the plain form
/// (`f4b247fd1f8745d4aa061c6fc0a8dfaf`), in any letter case. See
/// [`parse_uuid_str`] for the errors.
///
/// ```
/// assert_eq!(
///     uuid58::encode_uuid_str("F4B247FD1F8745D4AA061C6FC0A8DFAF").as_deref(),
///     Ok("XDY9dmBbcMBXqcRvYw8xJ2"),
/// );
/// assert!(uuid58::encode_uuid_str("{f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf}").is_err());
/// ```
#[cfg(feature = "alloc")]
#[cfg_attr(docsrs, doc(cfg(feature = "alloc")))]
pub fn encode_uuid_str(input: impl AsRef<[u8]>) -> Result<String, Error> {
    parse_uuid_str(input).map(encode)
}

/// Encodes a [`uuid::Uuid`], using its RFC 9562 (big-endian) byte order.
///
/// ```
/// let id = uuid::Uuid::from_u128(0xf4b247fd_1f87_45d4_aa06_1c6fc0a8dfaf);
/// assert_eq!(uuid58::encode_uuid(&id), "XDY9dmBbcMBXqcRvYw8xJ2");
/// ```
#[cfg(all(feature = "uuid", feature = "alloc"))]
#[cfg_attr(docsrs, doc(cfg(all(feature = "uuid", feature = "alloc"))))]
pub fn encode_uuid(uuid: &uuid::Uuid) -> String {
    encode(uuid.as_u128())
}

// ---------------------------------------------------------------------------
// Decoding
// ---------------------------------------------------------------------------

/// Decodes a uuid58 string to a 128-bit value.
///
/// # Errors
///
/// Checks run in the order of Section 4 of the specification and the first
/// failure is reported:
///
/// 1. [`Error::InvalidLength`] if the input is not exactly 22 bytes.
/// 2. [`Error::InvalidCharacter`] if any byte is not in [`ALPHABET`]
///    (case-sensitive; non-ASCII bytes are never in the alphabet).
/// 3. [`Error::Overflow`] if the value is greater than `2^128 - 1`.
///
/// ```
/// assert_eq!(uuid58::decode(uuid58::MAX_UUID58), Ok(u128::MAX));
/// assert_eq!(uuid58::decode("XDY9dmBbcMBXqcRvYw8xJ"), Err(uuid58::Error::InvalidLength));
/// assert_eq!(uuid58::decode("XDY9dmBbcMBXqcRvYw8xJ0"), Err(uuid58::Error::InvalidCharacter));
/// assert_eq!(uuid58::decode("zzzzzzzzzzzzzzzzzzzzzz"), Err(uuid58::Error::Overflow));
/// ```
pub fn decode(input: impl AsRef<[u8]>) -> Result<u128, Error> {
    decode_value(input.as_ref())
}

/// Reads one chunk of at most ten digits, so the accumulator fits in a u64.
fn read_digits(input: &[u8], mut start: usize, end: usize) -> Result<u64, Error> {
    let mut acc = 0;
    while start < end {
        let d = DIGITS[usize::from(input[start])];
        if d == INVALID {
            return Err(Error::InvalidCharacter);
        }
        acc = acc * 58 + u64::from(d);
        start += 1;
    }
    Ok(acc)
}

fn decode_value(input: &[u8]) -> Result<u128, Error> {
    if input.len() != ENCODED_LEN {
        return Err(Error::InvalidLength);
    }
    // Read every digit before the range check, as required by section 4.
    let hi = read_digits(input, 0, 2)?;
    let mid = read_digits(input, 2, 12)?;
    let lo = read_digits(input, 12, 22)?;
    join_chunks(hi, mid, lo)
}

fn join_chunks(hi: u64, mid: u64, lo: u64) -> Result<u128, Error> {
    let prefix = u128::from(hi) * u128::from(CHUNK) + u128::from(mid);
    let Some(shifted) = prefix.checked_mul(u128::from(CHUNK)) else {
        return Err(Error::Overflow);
    };
    let Some(value) = shifted.checked_add(u128::from(lo)) else {
        return Err(Error::Overflow);
    };
    Ok(value)
}

/// Decodes a uuid58 string to 16 big-endian bytes.
///
/// See [`decode`] for the errors.
///
/// ```
/// assert_eq!(uuid58::decode_to_bytes(uuid58::NIL_UUID58), Ok([0u8; 16]));
/// ```
pub fn decode_to_bytes(input: impl AsRef<[u8]>) -> Result<[u8; 16], Error> {
    decode(input).map(u128::to_be_bytes)
}

/// Decodes a uuid58 string into `buf` as a lowercase hyphenated UUID string.
///
/// See [`decode`] for the errors. `buf` is left unchanged on error.
///
/// ```
/// let mut buf = [0u8; uuid58::UUID_STR_LEN];
/// assert_eq!(
///     uuid58::decode_to_uuid_buf("XDY9dmBbcMBXqcRvYw8xJ2", &mut buf),
///     Ok("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf"),
/// );
/// ```
pub fn decode_to_uuid_buf(
    input: impl AsRef<[u8]>,
    buf: &mut [u8; UUID_STR_LEN],
) -> Result<&str, Error> {
    let value = decode(input)?;
    Ok(format_uuid(value, buf))
}

/// Decodes a uuid58 string to a lowercase hyphenated UUID string.
///
/// See [`decode`] for the errors.
///
/// ```
/// assert_eq!(
///     uuid58::decode_to_uuid_string("XDY9dmBbcMBXqcRvYw8xJ2").as_deref(),
///     Ok("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf"),
/// );
/// ```
#[cfg(feature = "alloc")]
#[cfg_attr(docsrs, doc(cfg(feature = "alloc")))]
pub fn decode_to_uuid_string(input: impl AsRef<[u8]>) -> Result<String, Error> {
    let mut buf = [0u8; UUID_STR_LEN];
    decode_to_uuid_buf(input, &mut buf).map(String::from)
}

/// Decodes a uuid58 string to a [`uuid::Uuid`], using RFC 9562 (big-endian)
/// byte order.
///
/// See [`decode`] for the errors.
///
/// ```
/// let id = uuid58::decode_uuid("XDY9dmBbcMBXqcRvYw8xJ2")?;
/// assert_eq!(id, uuid::uuid!("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf"));
/// # Ok::<(), uuid58::Error>(())
/// ```
#[cfg(feature = "uuid")]
#[cfg_attr(docsrs, doc(cfg(feature = "uuid")))]
pub fn decode_uuid(input: impl AsRef<[u8]>) -> Result<uuid::Uuid, Error> {
    decode(input).map(uuid::Uuid::from_u128)
}

/// Returns `true` exactly when [`decode`] would succeed.
///
/// ```
/// assert!(uuid58::is_valid(uuid58::MAX_UUID58));
/// assert!(!uuid58::is_valid("YcVfxkQb6JRzqk5kF2tNLw"));
/// assert!(!uuid58::is_valid("XDY9dmBbcMBXqcRvYw8xJ2\n"));
/// ```
pub fn is_valid(input: impl AsRef<[u8]>) -> bool {
    decode(input).is_ok()
}

// ---------------------------------------------------------------------------
// UUID strings
// ---------------------------------------------------------------------------

const HYPHENS: [usize; 4] = [8, 13, 18, 23];

fn hex_value(b: u8) -> Option<u8> {
    match b {
        b'0'..=b'9' => Some(b - b'0'),
        b'a'..=b'f' => Some(b - b'a' + 10),
        b'A'..=b'F' => Some(b - b'A' + 10),
        _ => None,
    }
}

/// Parses a UUID string strictly, per Section 5.1 of the specification.
///
/// Accepts exactly:
///
/// - the hyphenated form: 36 bytes, `-` at positions 8, 13, 18 and 23,
///   hexadecimal digits everywhere else;
/// - the plain form: 32 hexadecimal digits.
///
/// Hexadecimal digits may be upper or lower case. Braces, `urn:uuid:`,
/// whitespace and misplaced hyphens are rejected.
///
/// # Errors
///
/// 1. [`Error::InvalidLength`] if the input is neither 32 nor 36 bytes.
/// 2. [`Error::InvalidCharacter`] if it does not match the form for its
///    length.
///
/// ```
/// assert_eq!(uuid58::parse_uuid_str("00000000-0000-0000-0000-00000000000A"), Ok(10));
/// assert_eq!(
///     uuid58::parse_uuid_str("0000000-00000-0000-0000-00000000000a"),
///     Err(uuid58::Error::InvalidCharacter),
/// );
/// ```
pub fn parse_uuid_str(input: impl AsRef<[u8]>) -> Result<u128, Error> {
    let input = input.as_ref();
    let hyphenated = match input.len() {
        32 => false,
        36 => true,
        _ => return Err(Error::InvalidLength),
    };
    let mut value = 0u128;
    for (i, &b) in input.iter().enumerate() {
        if hyphenated && HYPHENS.contains(&i) {
            if b != b'-' {
                return Err(Error::InvalidCharacter);
            }
        } else {
            let d = hex_value(b).ok_or(Error::InvalidCharacter)?;
            value = (value << 4) | u128::from(d);
        }
    }
    Ok(value)
}

/// Writes `value` into `buf` as a lowercase hyphenated UUID string.
fn format_uuid(value: u128, buf: &mut [u8; UUID_STR_LEN]) -> &str {
    const HEX: [u8; 16] = *b"0123456789abcdef";
    let bytes = value.to_be_bytes();
    let mut pos = 0;
    for (i, &b) in bytes.iter().enumerate() {
        if matches!(i, 4 | 6 | 8 | 10) {
            buf[pos] = b'-';
            pos += 1;
        }
        buf[pos] = HEX[usize::from(b >> 4)];
        buf[pos + 1] = HEX[usize::from(b & 0xf)];
        pos += 2;
    }
    ascii_str(buf)
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Straightforward reference encoder: 22 divisions by 58.
    fn reference_encode(mut v: u128) -> [u8; ENCODED_LEN] {
        let mut out = [0u8; ENCODED_LEN];
        for b in out.iter_mut().rev() {
            *b = ALPHABET_BYTES[(v % 58) as usize];
            v /= 58;
        }
        out
    }

    /// splitmix64, so the tests need no dependencies and are reproducible.
    struct Rng(u64);
    impl Rng {
        fn next_u64(&mut self) -> u64 {
            self.0 = self.0.wrapping_add(0x9e37_79b9_7f4a_7c15);
            let mut z = self.0;
            z = (z ^ (z >> 30)).wrapping_mul(0xbf58_476d_1ce4_e5b9);
            z = (z ^ (z >> 27)).wrapping_mul(0x94d0_49bb_1331_11eb);
            z ^ (z >> 31)
        }
        fn next_u128(&mut self) -> u128 {
            // Vary the magnitude so that short values are covered too.
            let v = (u128::from(self.next_u64()) << 64) | u128::from(self.next_u64());
            v >> (self.next_u64() % 128)
        }
    }

    #[test]
    fn alphabet_is_ascending() {
        assert!(ALPHABET_BYTES.windows(2).all(|w| w[0] < w[1]));
    }

    #[test]
    fn constants() {
        let mut buf = [0u8; ENCODED_LEN];
        assert_eq!(encode_to_buf(u128::MAX, &mut buf), MAX_UUID58);
        assert_eq!(encode_to_buf(0, &mut buf), NIL_UUID58);
    }

    #[test]
    fn random_roundtrip_and_order() {
        let mut rng = Rng(0x5eed);
        let mut prev = 0u128;
        let mut prev_enc = encode_array(0);
        for _ in 0..100_000 {
            let v = rng.next_u128();
            let enc = encode_array(v);
            assert_eq!(enc, reference_encode(v));
            assert_eq!(decode(enc), Ok(v));
            assert_eq!(v.cmp(&prev), enc.cmp(&prev_enc));
            let mut buf = [0u8; UUID_STR_LEN];
            let s = format_uuid(v, &mut buf);
            assert_eq!(parse_uuid_str(s), Ok(v));
            prev = v;
            prev_enc = enc;
        }
    }

    #[test]
    fn random_bytes_never_panic_and_agree() {
        let mut rng = Rng(0xf00d);
        for _ in 0..100_000 {
            let len = (rng.next_u64() % 40) as usize;
            let mut input = [0u8; 40];
            for b in &mut input[..len] {
                // Mostly alphabet characters, sometimes any byte.
                let r = rng.next_u64();
                *b = if r % 8 == 0 {
                    (r >> 8) as u8
                } else {
                    ALPHABET_BYTES[((r >> 8) % 58) as usize]
                };
            }
            let input = &input[..len];
            let result = decode(input);
            assert_eq!(is_valid(input), result.is_ok());
            match result {
                Ok(v) => assert_eq!(&encode_array(v)[..], input),
                Err(Error::InvalidLength) => assert_ne!(len, ENCODED_LEN),
                Err(Error::InvalidCharacter) => {
                    assert!(input.iter().any(|&b| DIGITS[usize::from(b)] == INVALID))
                }
                Err(Error::Overflow) => assert!(input > MAX_UUID58.as_bytes()),
            }
            let _ = parse_uuid_str(input);
        }
    }
}
