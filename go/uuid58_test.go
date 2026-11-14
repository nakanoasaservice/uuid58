package uuid58

import (
	"bytes"
	"errors"
	"math/big"
	"strings"
	"testing"
)

// referenceEncode is an independent math/big implementation of SPEC.md
// Section 3.1.
func referenceEncode(b [16]byte) string {
	v := new(big.Int).SetBytes(b[:])
	base := big.NewInt(58)
	out := make([]byte, Len)
	r := new(big.Int)
	for i := Len - 1; i >= 0; i-- {
		v.QuoRem(v, base, r)
		out[i] = Alphabet[r.Int64()]
	}
	return string(out)
}

func TestConstants(t *testing.T) {
	var ones [16]byte
	for i := range ones {
		ones[i] = 0xff
	}
	if got := EncodeBytes(ones); got != Max {
		t.Errorf("EncodeBytes(max) = %q, want Max = %q", got, Max)
	}
	if len(Alphabet) != 58 {
		t.Errorf("len(Alphabet) = %d", len(Alphabet))
	}
	for i := 1; i < len(Alphabet); i++ {
		if Alphabet[i-1] >= Alphabet[i] {
			t.Errorf("Alphabet not in ascending ASCII order at %d", i)
		}
	}
}

func TestErrorsAreDistinct(t *testing.T) {
	errs := []error{ErrInvalidLength, ErrInvalidCharacter, ErrOverflow}
	for i, a := range errs {
		for j, b := range errs {
			if (i == j) != errors.Is(a, b) {
				t.Errorf("errors.Is(%v, %v) = %v", a, b, !(i == j))
			}
		}
	}
}

func TestDecodeCheckOrder(t *testing.T) {
	// Digits that would overflow, but a later character is invalid.
	if _, err := Decode("Zzzzzzzzzzzzzzzzzzzzz0"); !errors.Is(err, ErrInvalidCharacter) {
		t.Errorf("got %v, want ErrInvalidCharacter", err)
	}
	// Wrong length beats invalid characters.
	if _, err := Decode("000"); !errors.Is(err, ErrInvalidLength) {
		t.Errorf("got %v, want ErrInvalidLength", err)
	}
}

func TestDecodeOverflowBoundary(t *testing.T) {
	// Every 22-character string just above Max overflows; Max itself does not.
	if _, err := DecodeBytes(Max); err != nil {
		t.Fatalf("DecodeBytes(Max) = %v", err)
	}
	above := []byte(Max)
	for i := Len - 1; i >= 0; i-- {
		d := strings.IndexByte(Alphabet, above[i])
		if d < 57 {
			above[i] = Alphabet[d+1]
			break
		}
		above[i] = '1'
	}
	if _, err := DecodeBytes(string(above)); !errors.Is(err, ErrOverflow) {
		t.Errorf("DecodeBytes(%q) = %v, want ErrOverflow", above, err)
	}
}

func TestParseFormatUUID(t *testing.T) {
	b, err := ParseUUID("F4B247FD-1f87-45D4-aa06-1C6FC0A8DFAF")
	if err != nil {
		t.Fatal(err)
	}
	if got := FormatUUID(b); got != "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf" {
		t.Errorf("FormatUUID = %q", got)
	}
}

func TestNew(t *testing.T) {
	seen := map[string]bool{}
	for range 1000 {
		s := New()
		if !IsValid(s) {
			t.Fatalf("New() = %q is not valid", s)
		}
		u, err := Decode(s)
		if err != nil {
			t.Fatal(err)
		}
		if u[14] != '4' || !strings.ContainsRune("89ab", rune(u[19])) {
			t.Fatalf("New() decodes to %s, not a v4 UUID", u)
		}
		if seen[s] {
			t.Fatalf("duplicate %q", s)
		}
		seen[s] = true
	}
}

func FuzzBytesRoundTrip(f *testing.F) {
	f.Add(make([]byte, 16))
	f.Add(bytes.Repeat([]byte{0xff}, 16))
	f.Add([]byte{0xf4, 0xb2, 0x47, 0xfd, 0x1f, 0x87, 0x45, 0xd4, 0xaa, 0x06, 0x1c, 0x6f, 0xc0, 0xa8, 0xdf, 0xaf})
	f.Fuzz(func(t *testing.T, data []byte) {
		if len(data) < 16 {
			return
		}
		b := [16]byte(data)
		s := EncodeBytes(b)
		if want := referenceEncode(b); s != want {
			t.Fatalf("EncodeBytes(%x) = %q, reference %q", b, s, want)
		}
		if !IsValid(s) {
			t.Fatalf("IsValid(%q) = false", s)
		}
		got, err := DecodeBytes(s)
		if err != nil || got != b {
			t.Fatalf("DecodeBytes(%q) = %x, %v; want %x", s, got, err, b)
		}
		u, err := Decode(s)
		if err != nil || u != FormatUUID(b) {
			t.Fatalf("Decode(%q) = %q, %v", s, u, err)
		}
		if e, err := Encode(u); err != nil || e != s {
			t.Fatalf("Encode(%q) = %q, %v; want %q", u, e, err, s)
		}

		// Ordering (SPEC.md Section 3.2) against a second value.
		if len(data) >= 32 {
			b2 := [16]byte(data[16:32])
			if c1, c2 := bytes.Compare(b[:], b2[:]), strings.Compare(s, EncodeBytes(b2)); c1 != c2 {
				t.Fatalf("order mismatch: bytes %d, uuid58 %d", c1, c2)
			}
		}
	})
}

func FuzzDecode(f *testing.F) {
	f.Add("XDY9dmBbcMBXqcRvYw8xJ2")
	f.Add(Max)
	f.Add("YcVfxkQb6JRzqk5kF2tNLw")
	f.Add("Zzzzzzzzzzzzzzzzzzzzz0")
	f.Add("XDY9dmBbcMBXqcRvYw8x\xc1\x81")
	f.Fuzz(func(t *testing.T, s string) {
		b, err := DecodeBytes(s)
		if valid := IsValid(s); valid != (err == nil) {
			t.Fatalf("IsValid(%q) = %v but DecodeBytes error = %v", s, valid, err)
		}
		if err != nil {
			if !errors.Is(err, ErrInvalidLength) && !errors.Is(err, ErrInvalidCharacter) && !errors.Is(err, ErrOverflow) {
				t.Fatalf("unexpected error %v", err)
			}
			return
		}
		if got := EncodeBytes(b); got != s {
			t.Fatalf("EncodeBytes(DecodeBytes(%q)) = %q", s, got)
		}
	})
}

func FuzzEncode(f *testing.F) {
	f.Add("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf")
	f.Add("f4b247fd1f8745d4aa061c6fc0a8dfaf")
	f.Add("f4b247f-d1f87-45d4-aa06-1c6fc0a8dfaf")
	f.Fuzz(func(t *testing.T, s string) {
		got, err := Encode(s)
		if err != nil {
			if !errors.Is(err, ErrInvalidLength) && !errors.Is(err, ErrInvalidCharacter) {
				t.Fatalf("unexpected error %v", err)
			}
			return
		}
		// Accepted input must be one of the two forms; decoding gives the
		// canonical form, which matches the input up to case and hyphens.
		u, err := Decode(got)
		if err != nil {
			t.Fatal(err)
		}
		norm := strings.ToLower(s)
		if len(s) == 32 {
			norm = strings.ReplaceAll(u, "-", "")
			if !strings.EqualFold(s, norm) {
				t.Fatalf("Encode(%q) round-trips to %q", s, u)
			}
		} else if norm != u {
			t.Fatalf("Encode(%q) round-trips to %q", s, u)
		}
	})
}
