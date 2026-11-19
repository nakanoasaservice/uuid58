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

/// Marks a byte that is not in the alphabet. Larger than any number made of
/// five digits (`58^5 < 2^30`), see `read_half`.
const INVALID: u32 = 1 << 31;

/// Byte -> digit value, or `INVALID`. Bytes `0x80..=0xff` are all `INVALID`.
const DIGITS: [u32; 256] = make_digit_table(ALPHABET_BYTES);

const fn make_digit_table(alphabet: &[u8; 58]) -> [u32; 256] {
    let mut table = [INVALID; 256];
    let mut i = 0;
    while i < 58 {
        table[alphabet[i] as usize] = i as u32;
        i += 1;
    }
    table
}

/// Digit value -> character. Padded to 64 entries so that a six-bit index
/// needs no bounds check; the padding is never read.
const SYMBOLS: [u8; 64] = make_symbol_table(ALPHABET_BYTES);

const fn make_symbol_table(alphabet: &[u8; 58]) -> [u8; 64] {
    let mut table = [alphabet[0]; 64];
    let mut i = 0;
    while i < 58 {
        table[i] = alphabet[i];
        i += 1;
    }
    table
}

/// `58^10`, the largest power of 58 used to split the work into `u64` chunks.
const CHUNK: u64 = 430_804_206_899_405_824;

/// `58^5`: a chunk is two halves of five digits, each below this.
const HALF: u64 = 656_356_768;

/// `58^4`, the weight of the first of a half's five digits.
const HALF_LEAD: u64 = 11_316_496;

/// `29^10`, which is `CHUNK` without its ten factors of two.
const CHUNK_ODD: u64 = CHUNK >> 10;

/// `ceil(2^167 / 29^10)`, for dividing by `CHUNK` with a multiplication.
const CHUNK_ODD_RECIPROCAL: u128 = {
    // Long division of 2^167 by 29^10, one bit at a time.
    let d = CHUNK_ODD as u128;
    let mut quotient = 0u128;
    let mut remainder = 1u128;
    let mut bit = 0;
    while bit < 167 {
        remainder <<= 1;
        quotient <<= 1;
        if remainder >= d {
            remainder -= d;
            quotient |= 1;
        }
        bit += 1;
    }
    // 29^10 is odd, so the division is never exact: round up.
    quotient + 1
};

/// The number of fraction bits in the fixed-point numbers of `write_half`.
const FRACTION_BITS: u32 = 58;

/// `ceil(2^58 / 58^4)`: a half times this is the half divided by `58^4`, as
/// a fixed-point number.
const HALF_LEAD_RECIPROCAL: u64 = (1 << FRACTION_BITS) / HALF_LEAD + 1;

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

/// The high 128 bits of the 256-bit product `x * y`.
#[inline]
fn mul_high(x: u128, y: u128) -> u128 {
    const LOW: u128 = u64::MAX as u128;
    let (x1, x0) = (x >> 64, x & LOW);
    let (y1, y0) = (y >> 64, y & LOW);
    let cross = ((x0 * y0) >> 64) + ((x0 * y1) & LOW) + ((x1 * y0) & LOW);
    x1 * y1 + ((x0 * y1) >> 64) + ((x1 * y0) >> 64) + (cross >> 64)
}

/// `value / CHUNK`, without a 128-bit division.
#[inline]
fn div_chunk(value: u128) -> u128 {
    // CHUNK = 2^10 * 29^10, so the quotient is n / 29^10 with
    // n = value >> 10 < 2^118. With m = ceil(2^167 / 29^10) and 29^10 < 2^49,
    // floor(n * m / 2^167) = floor(n / 29^10) for every n < 2^118 (Granlund
    // and Montgomery, "Division by Invariant Integers using Multiplication",
    // 1994, Theorem 4.2). 2^167 = 2^128 * 2^39.
    mul_high(value >> 10, CHUNK_ODD_RECIPROCAL) >> 39
}

/// Writes the five base-58 digits of `v`, which is below `58^5`, into
/// `out[at..at + 5]`.
#[inline(always)]
fn write_half(v: u64, out: &mut [u8; ENCODED_LEN], at: usize) {
    // Fixed point with 58 fraction bits. `t / 2^58` is `v / 58^4` plus an
    // error below `v / 2^58`, because the reciprocal is rounded up by less
    // than one. `v < 58^5` and `58^9 < 2^58`, so the error is below `58^-4`:
    // less than one unit of the last of the five digits, and it changes
    // none of them. The integer part of `t` is the first digit, and
    // multiplying the fraction by 58 moves the next one up. Nothing is
    // rounded on the way: `58^5` times the reciprocal and a fraction times
    // 58 are both below `2^64`.
    //
    // The integer part is the top six bits, so the lookup needs no bounds
    // check.
    let mut t = v * HALF_LEAD_RECIPROCAL;
    for symbol in &mut out[at..at + 5] {
        *symbol = SYMBOLS[(t >> FRACTION_BITS) as usize];
        t = (t & ((1 << FRACTION_BITS) - 1)) * 58;
    }
}

/// Writes the ten base-58 digits of `v`, which is below `58^10`, into
/// `out[at..at + 10]`.
#[inline(always)]
fn write_chunk(v: u64, out: &mut [u8; ENCODED_LEN], at: usize) {
    write_half(v / HALF, out, at);
    write_half(v % HALF, out, at + 5);
}

/// Writes the 22 characters of `value` into `out`.
fn encode_into(value: u128, out: &mut [u8; ENCODED_LEN]) {
    // value = hi * 58^20 + mid * 58^10 + lo, with hi < 58^2.
    let rest = div_chunk(value);
    // lo = value - rest * 58^10 is below 2^64, so its low 64 bits are all of
    // it. The same goes for mid.
    let lo = (value as u64).wrapping_sub((rest as u64).wrapping_mul(CHUNK));
    let hi = (rest >> 10) as u64 / CHUNK_ODD;
    let mid = (rest as u64).wrapping_sub(hi.wrapping_mul(CHUNK));
    // `hi / 58` is below 58; the mask only removes the bounds check.
    out[0] = SYMBOLS[(hi / 58) as usize & 63];
    out[1] = SYMBOLS[(hi % 58) as usize];
    write_chunk(mid, out, 2);
    write_chunk(lo, out, 12);
}

#[cfg(any(feature = "alloc", test))]
#[inline]
fn encode_array(value: u128) -> [u8; ENCODED_LEN] {
    let mut out = [0u8; ENCODED_LEN];
    encode_into(value, &mut out);
    out
}

fn ascii_str(bytes: &[u8]) -> &str {
    match core::str::from_utf8(bytes) {
        Ok(s) => s,
        Err(_) => unreachable!("output is always ASCII"),
    }
}

/// Copies ASCII bytes into a new `String`.
#[cfg(feature = "alloc")]
#[inline]
fn ascii_string<const N: usize>(bytes: &[u8; N]) -> String {
    // The copy is checked rather than `bytes`: an allocation is aligned, so
    // the UTF-8 check reads it a word at a time from the start. An array
    // rather than a slice, so that the copy has a fixed size.
    match String::from_utf8(bytes.to_vec()) {
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
    encode_into(value, buf);
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
    ascii_string(&encode_array(value))
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

#[inline(always)]
fn digit(input: &[u8; ENCODED_LEN], at: usize) -> u64 {
    u64::from(DIGITS[usize::from(input[at])])
}

/// Reads the five characters `input[at..at + 5]` as one number: below `58^5`
/// if all five are in the alphabet, and at least `INVALID` if any is not.
#[inline(always)]
fn read_half(input: &[u8; ENCODED_LEN], at: usize) -> u64 {
    // A sum of independent products instead of Horner's rule, so no step
    // waits for the one before. `INVALID` times every weight still fits.
    digit(input, at) * HALF_LEAD
        + digit(input, at + 1) * (58 * 58 * 58)
        + digit(input, at + 2) * (58 * 58)
        + digit(input, at + 3) * 58
        + digit(input, at + 4)
}

fn decode_value(input: &[u8]) -> Result<u128, Error> {
    let Ok(input) = <&[u8; ENCODED_LEN]>::try_from(input) else {
        return Err(Error::InvalidLength);
    };
    let (first, second) = (digit(input, 0), digit(input, 1));
    let halves = [
        read_half(input, 2),
        read_half(input, 7),
        read_half(input, 12),
        read_half(input, 17),
    ];
    // Read every digit before the range check, as required by section 4.
    // Without an invalid character every term is below 2^30, and so is
    // their OR. An invalid one puts its term, and the OR, at `INVALID` or
    // above.
    let seen = first | second | halves[0] | halves[1] | halves[2] | halves[3];
    if seen >= u64::from(INVALID) {
        return Err(Error::InvalidCharacter);
    }
    let hi = first * 58 + second;
    let mid = halves[0] * HALF + halves[1];
    let lo = halves[2] * HALF + halves[3];
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
    let value = decode(input)?;
    let mut buf = [0u8; UUID_STR_LEN];
    write_uuid(value, &mut buf);
    Ok(ascii_string(&buf))
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

/// A `u64` with every byte set to `byte`.
const fn splat(byte: u8) -> u64 {
    u64::from_ne_bytes([byte; 8])
}

/// Parses the eight ASCII hexadecimal digits held in the bytes of `word`,
/// most significant first. `None` if any byte is not a hexadecimal digit.
#[inline]
fn parse_hex_word(word: u64) -> Option<u32> {
    // All eight bytes are handled at once. With bit 7 cleared, a byte plus a
    // constant of at most 0x80 never carries into its neighbour, and
    // `b + (0x80 - k)` has bit 7 set exactly when `b >= k`.
    let low = word & splat(0x7f);
    let at_least = |bytes: u64, k: u8| bytes + splat(0x80 - k);
    let digit = at_least(low, b'0') & !at_least(low, b'9' + 1);
    let lower = low | splat(0x20);
    let letter = at_least(lower, b'a') & !at_least(lower, b'f' + 1);
    // Bit 7 of each byte: is a digit or a letter, and was ASCII to begin with.
    if (digit | letter) & !word & splat(0x80) != splat(0x80) {
        return None;
    }
    // The low four bits are the value of '0'..='9', and nine less than the
    // value of a letter; only letters have bit 6 set.
    let nibbles = (word & splat(0x0f)) + ((word >> 6) & splat(1)) * 9;
    // Squeeze the eight nibbles, one per byte, into the low 32 bits.
    let pairs = (nibbles | (nibbles >> 4)) & 0x00ff_00ff_00ff_00ff;
    let quads = (pairs | (pairs >> 8)) & 0x0000_ffff_0000_ffff;
    Some((quads | (quads >> 16)) as u32)
}

/// Formats `value` as eight lowercase hexadecimal digits.
#[inline]
fn format_hex_word(value: u32) -> [u8; 8] {
    // Spread the eight nibbles out, one per byte.
    let quads = u64::from(value);
    let quads = (quads | (quads << 16)) & 0x0000_ffff_0000_ffff;
    let pairs = (quads | (quads << 8)) & 0x00ff_00ff_00ff_00ff;
    let nibbles = (pairs | (pairs << 4)) & splat(0x0f);
    // 1 in every byte that holds 10..=15: those skip from '9' to 'a'.
    let letters = ((nibbles + splat(6)) >> 4) & splat(1);
    (nibbles + splat(b'0') + letters * u64::from(b'a' - b'9' - 1)).to_be_bytes()
}

/// Reads four bytes of `input` at `at` into the low half of a `u64`,
/// most significant first.
#[inline(always)]
fn read_four<const N: usize>(input: &[u8; N], at: usize) -> u64 {
    u64::from(u32::from_be_bytes([
        input[at],
        input[at + 1],
        input[at + 2],
        input[at + 3],
    ]))
}

/// Reads eight bytes of `input` at `at`, most significant first.
#[inline(always)]
fn read_eight<const N: usize>(input: &[u8; N], at: usize) -> u64 {
    (read_four(input, at) << 32) | read_four(input, at + 4)
}

fn parse_uuid_bytes(input: &[u8]) -> Result<u128, Error> {
    // The 32 hexadecimal digits, as four words of eight.
    let words = if let Ok(plain) = <&[u8; 32]>::try_from(input) {
        [
            read_eight(plain, 0),
            read_eight(plain, 8),
            read_eight(plain, 16),
            read_eight(plain, 24),
        ]
    } else if let Ok(hyphenated) = <&[u8; UUID_STR_LEN]>::try_from(input) {
        if hyphenated[8] != b'-'
            || hyphenated[13] != b'-'
            || hyphenated[18] != b'-'
            || hyphenated[23] != b'-'
        {
            return Err(Error::InvalidCharacter);
        }
        [
            read_eight(hyphenated, 0),
            (read_four(hyphenated, 9) << 32) | read_four(hyphenated, 14),
            (read_four(hyphenated, 19) << 32) | read_four(hyphenated, 24),
            read_eight(hyphenated, 28),
        ]
    } else {
        return Err(Error::InvalidLength);
    };
    let [Some(a), Some(b), Some(c), Some(d)] = words.map(parse_hex_word) else {
        return Err(Error::InvalidCharacter);
    };
    Ok((u128::from(a) << 96) | (u128::from(b) << 64) | (u128::from(c) << 32) | u128::from(d))
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
    parse_uuid_bytes(input.as_ref())
}

/// Writes `value` into `buf` as a lowercase hyphenated UUID string.
fn format_uuid(value: u128, buf: &mut [u8; UUID_STR_LEN]) -> &str {
    write_uuid(value, buf);
    ascii_str(buf)
}

/// Writes the 36 characters of `value` as a lowercase hyphenated UUID string.
fn write_uuid(value: u128, buf: &mut [u8; UUID_STR_LEN]) {
    let a = format_hex_word((value >> 96) as u32);
    let b = format_hex_word((value >> 64) as u32);
    let c = format_hex_word((value >> 32) as u32);
    let d = format_hex_word(value as u32);
    buf[0..8].copy_from_slice(&a);
    buf[8] = b'-';
    buf[9..13].copy_from_slice(&b[0..4]);
    buf[13] = b'-';
    buf[14..18].copy_from_slice(&b[4..8]);
    buf[18] = b'-';
    buf[19..23].copy_from_slice(&c[0..4]);
    buf[23] = b'-';
    buf[24..28].copy_from_slice(&c[4..8]);
    buf[28..36].copy_from_slice(&d);
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

    /// Straightforward reference decoder: one digit at a time.
    fn reference_decode(input: &[u8]) -> Result<u128, Error> {
        if input.len() != ENCODED_LEN {
            return Err(Error::InvalidLength);
        }
        let mut digits = [0u128; ENCODED_LEN];
        for (digit, b) in digits.iter_mut().zip(input) {
            let Some(i) = ALPHABET_BYTES.iter().position(|a| a == b) else {
                return Err(Error::InvalidCharacter);
            };
            *digit = i as u128;
        }
        let mut value = 0u128;
        for digit in digits {
            value = value
                .checked_mul(58)
                .and_then(|v| v.checked_add(digit))
                .ok_or(Error::Overflow)?;
        }
        Ok(value)
    }

    /// Straightforward reference UUID parser: one character at a time.
    fn reference_parse(input: &[u8]) -> Result<u128, Error> {
        let hyphenated = match input.len() {
            32 => false,
            36 => true,
            _ => return Err(Error::InvalidLength),
        };
        let mut value = 0u128;
        for (i, &b) in input.iter().enumerate() {
            if hyphenated && [8, 13, 18, 23].contains(&i) {
                if b != b'-' {
                    return Err(Error::InvalidCharacter);
                }
            } else {
                let d = char::from(b).to_digit(16).ok_or(Error::InvalidCharacter)?;
                value = (value << 4) | u128::from(d);
            }
        }
        Ok(value)
    }

    /// Straightforward reference UUID formatter: one character at a time.
    fn reference_format(v: u128) -> [u8; UUID_STR_LEN] {
        let mut text = [b'-'; UUID_STR_LEN];
        let mut shift = 128;
        for (i, b) in text.iter_mut().enumerate() {
            if ![8, 13, 18, 23].contains(&i) {
                shift -= 4;
                *b = b"0123456789abcdef"[(v >> shift) as usize & 15];
            }
        }
        text
    }

    /// Values on and next to every boundary the encoder splits at.
    fn boundary_values() -> impl Iterator<Item = u128> {
        let chunk = u128::from(CHUNK);
        let half = u128::from(HALF);
        let mut bases = [0u128; 128 + 22 + 4 * 58];
        let mut n = 0;
        for bit in 0..128 {
            bases[n] = 1 << bit;
            n += 1;
        }
        for power in 0..22 {
            bases[n] = 58u128.pow(power);
            n += 1;
        }
        // Multiples of every unit the encoder divides by.
        for unit in [half, chunk, chunk * half, chunk * chunk] {
            for k in 1..=58 {
                bases[n] = unit.saturating_mul(k * k * k);
                n += 1;
            }
        }
        assert_eq!(n, bases.len());
        bases
            .into_iter()
            .chain([0, u128::MAX])
            .flat_map(|v| [v.wrapping_sub(2), v.wrapping_sub(1), v, v.wrapping_add(1)])
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
            assert_eq!(result, reference_decode(input));
            assert_eq!(parse_uuid_str(input), reference_parse(input));
        }
    }

    #[test]
    fn reciprocals() {
        // 29^10 * ceil(2^167 / 29^10) is 2^167 plus less than 29^10. The
        // product needs more than 128 bits, so it is built from two halves.
        let d = u128::from(CHUNK_ODD);
        let low = (CHUNK_ODD_RECIPROCAL & u128::from(u64::MAX)) * d;
        let high = (CHUNK_ODD_RECIPROCAL >> 64) * d + (low >> 64);
        let excess = low & u128::from(u64::MAX);
        assert_eq!(high, 1 << (167 - 64));
        assert!(0 < excess && excess < d);
        assert_eq!(u128::from(CHUNK_ODD) << 10, u128::from(CHUNK));

        assert_eq!(CHUNK, 58u64.pow(10));
        assert_eq!(HALF, 58u64.pow(5));
        assert_eq!(HALF_LEAD, 58u64.pow(4));
        let excess = HALF_LEAD_RECIPROCAL * HALF_LEAD - (1 << FRACTION_BITS);
        assert!(0 < excess && excess <= HALF_LEAD);
    }

    #[test]
    fn boundaries() {
        for v in boundary_values() {
            let enc = encode_array(v);
            assert_eq!(enc, reference_encode(v), "{v}");
            assert_eq!(div_chunk(v), v / u128::from(CHUNK), "{v}");
            assert_eq!(decode(enc), Ok(v), "{v}");
            let mut buf = [0u8; UUID_STR_LEN];
            let text = format_uuid(v, &mut buf);
            assert_eq!(text.as_bytes(), reference_format(v), "{v}");
            assert_eq!(parse_uuid_str(text), Ok(v), "{v}");
        }
    }

    #[test]
    fn halves_cover_every_digit() {
        // Every digit value in every position of a half, and the extremes.
        let mut out = [0u8; ENCODED_LEN];
        for position in 0..5 {
            for digit in 0..58 {
                for rest in [0, HALF - 1] {
                    let weight = 58u64.pow(4 - position);
                    let v = rest - rest / weight % 58 * weight + digit * weight;
                    write_half(v, &mut out, 0);
                    assert_eq!(out[..5], reference_encode(u128::from(v))[17..], "{v}");
                }
            }
        }
    }

    #[test]
    fn every_byte_in_every_position() {
        let mut rng = Rng(0xbeef);
        for _ in 0..40 {
            let v = rng.next_u128();
            let encoded = encode_array(v);
            let mut hyphenated = [0u8; UUID_STR_LEN];
            format_uuid(v, &mut hyphenated);
            let mut plain = [0u8; 32];
            let mut hex = hyphenated.iter().filter(|&&b| b != b'-');
            plain.fill_with(|| *hex.next().unwrap());
            for byte in 0..=255 {
                for at in 0..ENCODED_LEN {
                    let mut input = encoded;
                    input[at] = byte;
                    assert_eq!(decode(input), reference_decode(&input), "{input:?}");
                    assert_eq!(is_valid(input), reference_decode(&input).is_ok());
                }
                for at in 0..UUID_STR_LEN {
                    let mut input = hyphenated;
                    input[at] = byte;
                    assert_eq!(parse_uuid_str(input), reference_parse(&input), "{input:?}");
                }
                for at in 0..32 {
                    let mut input = plain;
                    input[at] = byte;
                    assert_eq!(parse_uuid_str(input), reference_parse(&input), "{input:?}");
                }
            }
        }
    }
}
