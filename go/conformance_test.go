package uuid58

import (
	"encoding/hex"
	"encoding/json"
	"errors"
	"os"
	"strings"
	"testing"
)

// vectors mirrors spec/vectors.json (SPEC.md Section 8.1).
type vectors struct {
	SpecVersion string `json:"spec_version"`
	Alphabet    string `json:"alphabet"`
	Roundtrip   []struct {
		Description string `json:"description"`
		UUID        string `json:"uuid"`
		UUID58      string `json:"uuid58"`
	} `json:"roundtrip"`
	Encode struct {
		Valid []struct {
			Description string `json:"description"`
			Input       string `json:"input"`
			Output      string `json:"output"`
		} `json:"valid"`
		Invalid []struct {
			Description string   `json:"description"`
			Input       string   `json:"input"`
			Errors      []string `json:"errors"`
			Lenient     bool     `json:"lenient"`
		} `json:"invalid"`
		InvalidBytes []struct {
			Description string   `json:"description"`
			Bytes       string   `json:"bytes"`
			Errors      []string `json:"errors"`
		} `json:"invalid_bytes"`
	} `json:"encode"`
	Decode struct {
		Invalid []struct {
			Description string   `json:"description"`
			Input       string   `json:"input"`
			Errors      []string `json:"errors"`
		} `json:"invalid"`
	} `json:"decode"`
}

func loadVectors(t *testing.T) *vectors {
	t.Helper()
	data, err := os.ReadFile("../spec/vectors.json")
	if err != nil {
		t.Fatal(err)
	}
	var v vectors
	if err := json.Unmarshal(data, &v); err != nil {
		t.Fatal(err)
	}
	return &v
}

var kinds = map[string]error{
	"invalid_length":    ErrInvalidLength,
	"invalid_character": ErrInvalidCharacter,
	"overflow":          ErrOverflow,
}

// checkKind fails unless err is one of the error kinds named in want.
func checkKind(t *testing.T, err error, want []string) {
	t.Helper()
	if err == nil {
		t.Fatalf("got no error, want one of %v", want)
	}
	for _, k := range want {
		sentinel, ok := kinds[k]
		if !ok {
			t.Fatalf("unknown error kind %q in vectors", k)
		}
		if errors.Is(err, sentinel) {
			return
		}
	}
	t.Fatalf("got error %v, want one of %v", err, want)
}

func TestVectorsAlphabet(t *testing.T) {
	v := loadVectors(t)
	if v.Alphabet != Alphabet {
		t.Fatalf("alphabet = %q, want %q", Alphabet, v.Alphabet)
	}
}

func TestVectorsRoundtrip(t *testing.T) {
	v := loadVectors(t)
	if len(v.Roundtrip) == 0 {
		t.Fatal("no roundtrip vectors")
	}
	for _, c := range v.Roundtrip {
		t.Run(c.Description, func(t *testing.T) {
			got, err := Encode(c.UUID)
			if err != nil || got != c.UUID58 {
				t.Errorf("Encode(%q) = %q, %v; want %q", c.UUID, got, err, c.UUID58)
			}
			back, err := Decode(c.UUID58)
			if err != nil || back != c.UUID {
				t.Errorf("Decode(%q) = %q, %v; want %q", c.UUID58, back, err, c.UUID)
			}
			if !IsValid(c.UUID58) {
				t.Errorf("IsValid(%q) = false", c.UUID58)
			}

			// Byte API: compare against bytes derived from the UUID text,
			// not against our own parser (SPEC.md Section 8.1).
			raw, err := hex.DecodeString(strings.ReplaceAll(c.UUID, "-", ""))
			if err != nil || len(raw) != 16 {
				t.Fatalf("bad uuid in vectors: %q", c.UUID)
			}
			b := [16]byte(raw)
			if got := EncodeBytes(b); got != c.UUID58 {
				t.Errorf("EncodeBytes(%x) = %q, want %q", b, got, c.UUID58)
			}
			gotB, err := DecodeBytes(c.UUID58)
			if err != nil || gotB != b {
				t.Errorf("DecodeBytes(%q) = %x, %v; want %x", c.UUID58, gotB, err, b)
			}
		})
	}
}

func TestVectorsEncodeValid(t *testing.T) {
	v := loadVectors(t)
	for _, c := range v.Encode.Valid {
		t.Run(c.Description, func(t *testing.T) {
			got, err := Encode(c.Input)
			if err != nil || got != c.Output {
				t.Errorf("Encode(%q) = %q, %v; want %q", c.Input, got, err, c.Output)
			}
		})
	}
}

func TestVectorsEncodeInvalid(t *testing.T) {
	v := loadVectors(t)
	for _, c := range v.Encode.Invalid {
		// Lenient inputs (accepted by JavaScript 1.x) must be rejected too.
		t.Run(c.Description, func(t *testing.T) {
			got, err := Encode(c.Input)
			if got != "" {
				t.Errorf("Encode(%q) returned %q with error", c.Input, got)
			}
			checkKind(t, err, c.Errors)
		})
	}
}

// TestVectorsEncodeInvalidBytes applies encode.invalid_bytes: EncodeBytes
// takes a [16]byte and cannot receive these, so the check is that the vectors
// are exactly the lengths a [16]byte cannot hold.
func TestVectorsEncodeInvalidBytes(t *testing.T) {
	v := loadVectors(t)
	for _, c := range v.Encode.InvalidBytes {
		raw, err := hex.DecodeString(c.Bytes)
		if err != nil {
			t.Fatal(err)
		}
		if len(raw) == 16 {
			t.Errorf("%s: 16-byte input in invalid_bytes", c.Description)
		}
	}
}

func TestVectorsDecodeInvalid(t *testing.T) {
	v := loadVectors(t)
	for _, c := range v.Decode.Invalid {
		t.Run(c.Description, func(t *testing.T) {
			got, err := Decode(c.Input)
			if got != "" {
				t.Errorf("Decode(%q) returned %q with error", c.Input, got)
			}
			checkKind(t, err, c.Errors)

			b, err := DecodeBytes(c.Input)
			if b != [16]byte{} {
				t.Errorf("DecodeBytes(%q) returned %x with error", c.Input, b)
			}
			checkKind(t, err, c.Errors)

			if IsValid(c.Input) {
				t.Errorf("IsValid(%q) = true", c.Input)
			}
		})
	}
}

// TestIllFormedInput covers SPEC.md Section 4.1 inputs that JSON cannot
// express: Go strings can hold arbitrary bytes, so any byte >= 0x80 and any
// ill-formed UTF-8 must be rejected with invalid_length or invalid_character.
func TestIllFormedInput(t *testing.T) {
	either := []string{"invalid_length", "invalid_character"}
	valid58 := "XDY9dmBbcMBXqcRvYw8xJ2"
	validUUID := "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf"
	validPlain := "f4b247fd1f8745d4aa061c6fc0a8dfaf"

	var decodeInputs, encodeInputs []string
	for _, bad := range []byte{0x80, 0xc1, 0xc3, 0xe0, 0xed, 0xf0, 0xf5, 0xfe, 0xff} {
		for _, pos := range []int{0, 10, 21} {
			s := []byte(valid58)
			s[pos] = bad
			decodeInputs = append(decodeInputs, string(s))
		}
		for _, pos := range []int{0, 8, 20, 35} {
			s := []byte(validUUID)
			s[pos] = bad
			encodeInputs = append(encodeInputs, string(s))
		}
		for _, pos := range []int{0, 31} {
			s := []byte(validPlain)
			s[pos] = bad
			encodeInputs = append(encodeInputs, string(s))
		}
	}
	decodeInputs = append(decodeInputs,
		strings.Repeat("\xff", 22),
		"XDY9dmBbcMBXqcRvYw8x\xc1\x81",         // overlong encoding of 'A'
		"XDY9dmBbcMBXqcRvYw8x\xed\xa0",         // truncated surrogate (CESU-style)
		"XDY9dmBbcMBXqcRvYw8xJ\xc5",            // truncated 2-byte sequence
		"XDY9dmBbcMBXqcRvYw8\xed\xa0\x80",      // UTF-8-encoded lone surrogate U+D800
		"XDY9dmBbcMBXqcRvYw8xJ"+"\xc2\xa0",     // NBSP
		"XDY9dmBbcMBXqcRvYw8xJ"+"\xc5\x81"[:1], // lone lead byte of U+0141 'Ł'
	)
	encodeInputs = append(encodeInputs,
		strings.Repeat("\xff", 32),
		strings.Repeat("\xff", 36),
		"f4b247fd-1f87-45d4-aa06-1c6fc0a8df\xc1\xa6", // overlong 'f'
	)

	for _, in := range decodeInputs {
		if _, err := Decode(in); err == nil {
			t.Errorf("Decode(%q) succeeded", in)
		} else {
			checkKind(t, err, either)
		}
		if _, err := DecodeBytes(in); err == nil {
			t.Errorf("DecodeBytes(%q) succeeded", in)
		} else {
			checkKind(t, err, either)
		}
		if IsValid(in) {
			t.Errorf("IsValid(%q) = true", in)
		}
	}
	for _, in := range encodeInputs {
		if _, err := Encode(in); err == nil {
			t.Errorf("Encode(%q) succeeded", in)
		} else {
			checkKind(t, err, either)
		}
	}
}
