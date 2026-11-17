// Package uuid58 shortens UUIDs to 22-character Base58 strings, and back.
// The strings are URL-safe, have no look-alike characters, and sort in the
// same order as the UUIDs they encode. It implements the stable uuid58
// specification and passes its shared test vectors, so the output matches the
// libraries for other languages.
//
// A UUID is read as an unsigned 128-bit big-endian integer and written in
// base 58 with the Bitcoin alphabet, left-padded with '1' (the zero digit) to
// exactly 22 characters:
//
//	f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf  <->  XDY9dmBbcMBXqcRvYw8xJ2
//
// Because the alphabet is in ascending ASCII order and every encoding has the
// same length, comparing two uuid58 strings byte by byte gives the same order
// as comparing the UUIDs as integers.
//
// This package implements the uuid58 specification:
// https://github.com/nakanoasaservice/uuid58/blob/main/spec/SPEC.md
//
// The [16]byte functions use RFC 9562 (network) byte order, so they accept and
// return values of any type whose underlying type is [16]byte, such as
// github.com/google/uuid's UUID, without a conversion.
package uuid58

import (
	"crypto/rand"
	"errors"
	"math/bits"
)

// Alphabet is the Bitcoin Base58 alphabet. The character at index i is the
// digit with value i.
const Alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

// Max is the largest valid uuid58 string, the encoding of
// ffffffff-ffff-ffff-ffff-ffffffffffff.
const Max = "YcVfxkQb6JRzqk5kF2tNLv"

// Len is the length of every uuid58 string.
const Len = 22

// Error kinds (SPEC.md Section 7). Every error returned by this package is
// one of these values; test for them with errors.Is.
var (
	// ErrInvalidLength reports input of the wrong length.
	ErrInvalidLength = errors.New("uuid58: invalid length")
	// ErrInvalidCharacter reports input of the right length that contains a
	// character not allowed in its position, or any non-ASCII byte.
	ErrInvalidCharacter = errors.New("uuid58: invalid character")
	// ErrOverflow reports a well-formed uuid58 string whose value exceeds
	// 2^128 - 1.
	ErrOverflow = errors.New("uuid58: value overflows 128 bits")
)

const invalid = 0xff

// digits maps a byte to its Base58 digit value, or invalid. Bytes >= 0x80 are
// invalid, so non-ASCII input is never mapped to an ASCII digit.
var digits = func() (t [256]byte) {
	for i := range t {
		t[i] = invalid
	}
	for i := 0; i < len(Alphabet); i++ {
		t[Alphabet[i]] = byte(i)
	}
	return t
}()

// hexVals maps a byte to its hexadecimal value, or invalid.
var hexVals = func() (t [256]byte) {
	for i := range t {
		t[i] = invalid
	}
	for i := byte(0); i < 10; i++ {
		t['0'+i] = i
	}
	for i := byte(0); i < 6; i++ {
		t['a'+i] = 10 + i
		t['A'+i] = 10 + i
	}
	return t
}()

// EncodeBytes encodes 16 bytes, read as a big-endian unsigned integer, as a
// 22-character uuid58 string. It never fails.
func EncodeBytes(b [16]byte) string {
	hi := uint64(b[0])<<56 | uint64(b[1])<<48 | uint64(b[2])<<40 | uint64(b[3])<<32 |
		uint64(b[4])<<24 | uint64(b[5])<<16 | uint64(b[6])<<8 | uint64(b[7])
	lo := uint64(b[8])<<56 | uint64(b[9])<<48 | uint64(b[10])<<40 | uint64(b[11])<<32 |
		uint64(b[12])<<24 | uint64(b[13])<<16 | uint64(b[14])<<8 | uint64(b[15])

	var out [Len]byte
	for i := Len - 1; i >= 0; i-- {
		var r uint64
		hi, r = hi/58, hi%58
		lo, r = bits.Div64(r, lo, 58)
		out[i] = Alphabet[r]
	}
	return string(out[:])
}

// DecodeBytes decodes a uuid58 string to 16 bytes in big-endian order.
//
// It fails with ErrInvalidLength if s is not 22 bytes long, with
// ErrInvalidCharacter if s contains a byte outside the alphabet (including
// any non-ASCII byte), and with ErrOverflow if the value exceeds 2^128 - 1,
// checked in that order.
func DecodeBytes(s string) ([16]byte, error) {
	var b [16]byte
	if len(s) != Len {
		return b, ErrInvalidLength
	}
	for i := 0; i < Len; i++ {
		if digits[s[i]] == invalid {
			return b, ErrInvalidCharacter
		}
	}

	var hi, lo uint64
	for i := 0; i < Len; i++ {
		// (hi, lo) = (hi, lo) * 58 + digit
		carry, l := bits.Mul64(lo, 58)
		over, h := bits.Mul64(hi, 58)
		var c uint64
		lo, c = bits.Add64(l, uint64(digits[s[i]]), 0)
		hi, c = bits.Add64(h, carry, c)
		if over != 0 || c != 0 {
			return [16]byte{}, ErrOverflow
		}
	}

	for i := 0; i < 8; i++ {
		b[i] = byte(hi >> (56 - 8*i))
		b[8+i] = byte(lo >> (56 - 8*i))
	}
	return b, nil
}

// IsValid reports whether s is a valid uuid58 string, that is, whether
// Decode would succeed.
func IsValid(s string) bool {
	if len(s) != Len {
		return false
	}
	for i := 0; i < Len; i++ {
		if digits[s[i]] == invalid {
			return false
		}
	}
	return s <= Max
}

// Encode encodes a UUID string as uuid58.
//
// It accepts exactly two forms, in upper, lower, or mixed case:
//
//	f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf  (hyphenated, 36 characters)
//	f4b247fd1f8745d4aa061c6fc0a8dfaf      (plain, 32 characters)
//
// Everything else fails: ErrInvalidLength if the length is neither 32 nor 36
// bytes, otherwise ErrInvalidCharacter. Braces, the "urn:uuid:" prefix,
// surrounding whitespace, and misplaced hyphens are rejected.
func Encode(uuid string) (string, error) {
	b, err := ParseUUID(uuid)
	if err != nil {
		return "", err
	}
	return EncodeBytes(b), nil
}

// Decode decodes a uuid58 string to a lowercase hyphenated UUID string such
// as "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf". Errors are as for DecodeBytes.
func Decode(s string) (string, error) {
	b, err := DecodeBytes(s)
	if err != nil {
		return "", err
	}
	return FormatUUID(b), nil
}

// ParseUUID parses a UUID string in the forms accepted by Encode into 16
// bytes in big-endian order.
func ParseUUID(s string) ([16]byte, error) {
	var b [16]byte
	switch len(s) {
	case 32:
		for i := 0; i < 16; i++ {
			h, l := hexVals[s[2*i]], hexVals[s[2*i+1]]
			if h == invalid || l == invalid {
				return [16]byte{}, ErrInvalidCharacter
			}
			b[i] = h<<4 | l
		}
	case 36:
		if s[8] != '-' || s[13] != '-' || s[18] != '-' || s[23] != '-' {
			return b, ErrInvalidCharacter
		}
		j := 0
		for i := 0; i < 16; i++ {
			if j == 8 || j == 13 || j == 18 || j == 23 {
				j++
			}
			h, l := hexVals[s[j]], hexVals[s[j+1]]
			if h == invalid || l == invalid {
				return [16]byte{}, ErrInvalidCharacter
			}
			b[i] = h<<4 | l
			j += 2
		}
	default:
		return b, ErrInvalidLength
	}
	return b, nil
}

// FormatUUID formats 16 bytes as a lowercase hyphenated UUID string.
func FormatUUID(b [16]byte) string {
	const hexDigits = "0123456789abcdef"
	var out [36]byte
	j := 0
	for i, v := range b {
		if i == 4 || i == 6 || i == 8 || i == 10 {
			out[j] = '-'
			j++
		}
		out[j] = hexDigits[v>>4]
		out[j+1] = hexDigits[v&0x0f]
		j += 2
	}
	return string(out[:])
}

// New returns the uuid58 encoding of a new random (version 4) UUID, using
// crypto/rand.
func New() string {
	var b [16]byte
	_, _ = rand.Read(b[:])  // never returns an error since Go 1.24
	b[6] = b[6]&0x0f | 0x40 // version 4
	b[8] = b[8]&0x3f | 0x80 // variant 10
	return EncodeBytes(b)
}
