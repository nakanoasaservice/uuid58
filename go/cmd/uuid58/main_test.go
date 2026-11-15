package main

import (
	"bytes"
	"encoding/json"
	"os"
	"strings"
	"testing"

	uuid58 "github.com/nakanoasaservice/uuid58/go"
)

const (
	sampleUUID = "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf"
	sample58   = "XDY9dmBbcMBXqcRvYw8xJ2"
)

type result struct {
	code           int
	stdout, stderr string
}

func runCLI(t *testing.T, stdin string, args ...string) result {
	t.Helper()
	var out, errOut bytes.Buffer
	code := run(args, strings.NewReader(stdin), &out, &errOut)
	return result{code, out.String(), errOut.String()}
}

func TestCommands(t *testing.T) {
	tests := []struct {
		name       string
		stdin      string
		args       []string
		code       int
		stdout     string
		stderrHas  string
		stderrNone bool
	}{
		{name: "encode arg", args: []string{"encode", sampleUUID}, stdout: sample58 + "\n", stderrNone: true},
		{name: "encode plain uppercase", args: []string{"encode", "F4B247FD1F8745D4AA061C6FC0A8DFAF"}, stdout: sample58 + "\n", stderrNone: true},
		{name: "decode arg", args: []string{"decode", sample58}, stdout: sampleUUID + "\n", stderrNone: true},
		{
			name:       "encode several args",
			args:       []string{"encode", sampleUUID, "00000000-0000-0000-0000-000000000000"},
			stdout:     sample58 + "\n1111111111111111111111\n",
			stderrNone: true,
		},
		{
			name:       "decode stdin",
			stdin:      sample58 + "\n" + uuid58.Max + "\n",
			args:       []string{"decode"},
			stdout:     sampleUUID + "\nffffffff-ffff-ffff-ffff-ffffffffffff\n",
			stderrNone: true,
		},
		{name: "stdin CRLF and no final newline", stdin: sampleUUID + "\r\n" + sampleUUID, args: []string{"encode"}, stdout: sample58 + "\n" + sample58 + "\n", stderrNone: true},
		{name: "stdin empty", args: []string{"encode"}, stderrNone: true},
		{name: "stdin empty line is invalid", stdin: "\n", args: []string{"encode"}, code: 1, stderrHas: "invalid_length"},
		{name: "stdin keeps other whitespace", stdin: " " + sample58 + "\n", args: []string{"decode"}, code: 1, stderrHas: "invalid_length"},
		{name: "decode invalid character", args: []string{"decode", "XDY9dmBbcMBXqcRvYw8xJ0"}, code: 1, stderrHas: `uuid58 decode: "XDY9dmBbcMBXqcRvYw8xJ0": invalid_character`},
		{name: "decode overflow", args: []string{"decode", "YcVfxkQb6JRzqk5kF2tNLw"}, code: 1, stderrHas: "overflow"},
		{name: "encode invalid length", args: []string{"encode", "abc"}, code: 1, stderrHas: "invalid_length"},
		{
			name:      "bad input does not stop the rest",
			stdin:     "bad\n" + sample58 + "\n",
			args:      []string{"decode"},
			code:      1,
			stdout:    sampleUUID + "\n",
			stderrHas: `"bad": invalid_length`,
		},
		{name: "validate ok", args: []string{"validate", sample58, uuid58.Max}, stderrNone: true},
		{name: "validate bad", args: []string{"validate", sample58, "nope"}, code: 1, stderrHas: `uuid58 validate: "nope": invalid_length`},
		{name: "check alias stdin", stdin: sample58 + "\n", args: []string{"check"}, stderrNone: true},
		{name: "help", args: []string{"--help"}, stdout: usage, stderrNone: true},
		{name: "help command", args: []string{"help"}, stdout: usage, stderrNone: true},
		{name: "subcommand help", args: []string{"gen", "-h"}, stderrHas: "Usage: uuid58 gen"},
		{name: "no args", code: 2, stderrHas: "Usage:"},
		{name: "unknown command", args: []string{"frobnicate"}, code: 2, stderrHas: `unknown command "frobnicate"`},
		{name: "unknown flag", args: []string{"encode", "-x"}, code: 2, stderrHas: "-x"},
		{name: "gen extra arg", args: []string{"gen", "foo"}, code: 2, stderrHas: "unexpected argument"},
		{name: "gen negative", args: []string{"gen", "-n", "-1"}, code: 2, stderrHas: "negative"},
		{name: "gen zero", args: []string{"gen", "-n", "0"}, stderrNone: true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			r := runCLI(t, tt.stdin, tt.args...)
			if r.code != tt.code {
				t.Errorf("exit code = %d, want %d (stderr %q)", r.code, tt.code, r.stderr)
			}
			if r.stdout != tt.stdout {
				t.Errorf("stdout = %q, want %q", r.stdout, tt.stdout)
			}
			if tt.stderrNone && r.stderr != "" {
				t.Errorf("stderr = %q, want empty", r.stderr)
			}
			if !strings.Contains(r.stderr, tt.stderrHas) {
				t.Errorf("stderr = %q, want it to contain %q", r.stderr, tt.stderrHas)
			}
		})
	}
}

func TestVersion(t *testing.T) {
	for _, arg := range []string{"--version", "-version", "version"} {
		r := runCLI(t, "", arg)
		if r.code != 0 || !strings.HasPrefix(r.stdout, "uuid58 ") || r.stderr != "" {
			t.Errorf("%s: got %+v", arg, r)
		}
	}

	old := version
	defer func() { version = old }()
	version = "9.9.9"
	if r := runCLI(t, "", "--version"); r.stdout != "uuid58 9.9.9\n" {
		t.Errorf("stdout = %q", r.stdout)
	}
}

func TestGen(t *testing.T) {
	for _, cmd := range []string{"gen", "new"} {
		r := runCLI(t, "", cmd, "-n", "5")
		lines := strings.Split(strings.TrimSuffix(r.stdout, "\n"), "\n")
		if r.code != 0 || len(lines) != 5 {
			t.Fatalf("%s: got %+v", cmd, r)
		}
		for _, l := range lines {
			if !uuid58.IsValid(l) {
				t.Errorf("%s: invalid output %q", cmd, l)
			}
		}
	}

	r := runCLI(t, "", "gen", "-uuid")
	id, u, ok := strings.Cut(strings.TrimSuffix(r.stdout, "\n"), "\t")
	if r.code != 0 || !ok {
		t.Fatalf("gen -uuid: got %+v", r)
	}
	if got, err := uuid58.Encode(u); err != nil || got != id {
		t.Errorf("gen -uuid: %q does not encode to %q", u, id)
	}
	// Version 4, variant 10.
	if u[14] != '4' || !strings.ContainsRune("89ab", rune(u[19])) {
		t.Errorf("gen -uuid: %q is not a version 4 UUID", u)
	}
}

// vectors is the subset of spec/vectors.json the CLI can exercise.
type vectors struct {
	Roundtrip []struct {
		Description, UUID, UUID58 string
	} `json:"roundtrip"`
	Encode struct {
		Valid []struct {
			Description, Input, Output string
		} `json:"valid"`
		Invalid []struct {
			Description, Input string
			Errors             []string
		} `json:"invalid"`
	} `json:"encode"`
	Decode struct {
		Invalid []struct {
			Description, Input string
			Errors             []string
		} `json:"invalid"`
	} `json:"decode"`
}

// TestVectors runs spec/vectors.json through the command line, so the output
// format and the error-kind names are checked as well as the library.
func TestVectors(t *testing.T) {
	data, err := os.ReadFile("../../../spec/vectors.json")
	if err != nil {
		t.Fatal(err)
	}
	var v vectors
	if err := json.Unmarshal(data, &v); err != nil {
		t.Fatal(err)
	}
	if len(v.Roundtrip) == 0 || len(v.Encode.Invalid) == 0 || len(v.Decode.Invalid) == 0 {
		t.Fatal("vectors not loaded")
	}

	ok := func(t *testing.T, cmd, in, want string) {
		t.Helper()
		r := runCLI(t, "", cmd, "--", in)
		if r.code != 0 || r.stdout != want+"\n" || r.stderr != "" {
			t.Errorf("%s %q = %+v, want %q", cmd, in, r, want)
		}
	}
	fail := func(t *testing.T, cmd, in string, kinds []string) {
		t.Helper()
		r := runCLI(t, "", cmd, "--", in)
		if r.code != 1 || r.stdout != "" {
			t.Errorf("%s %q = %+v, want exit 1 and no output", cmd, in, r)
		}
		for _, k := range kinds {
			if strings.HasSuffix(r.stderr, ": "+k+"\n") {
				return
			}
		}
		t.Errorf("%s %q: stderr = %q, want one of %v", cmd, in, r.stderr, kinds)
	}

	for _, c := range v.Roundtrip {
		t.Run("roundtrip/"+c.Description, func(t *testing.T) {
			ok(t, "encode", c.UUID, c.UUID58)
			ok(t, "decode", c.UUID58, c.UUID)
			if r := runCLI(t, "", "validate", c.UUID58); r.code != 0 || r.stdout != "" || r.stderr != "" {
				t.Errorf("validate %q = %+v", c.UUID58, r)
			}
		})
	}
	// Roundtrip again through standard input, all at once.
	var uuids, ids, wantIDs, wantUUIDs strings.Builder
	for _, c := range v.Roundtrip {
		uuids.WriteString(c.UUID + "\n")
		ids.WriteString(c.UUID58 + "\n")
		wantIDs.WriteString(c.UUID58 + "\n")
		wantUUIDs.WriteString(c.UUID + "\n")
	}
	if r := runCLI(t, uuids.String(), "encode"); r.code != 0 || r.stdout != wantIDs.String() {
		t.Errorf("encode from stdin: %+v", r)
	}
	if r := runCLI(t, ids.String(), "decode"); r.code != 0 || r.stdout != wantUUIDs.String() {
		t.Errorf("decode from stdin: %+v", r)
	}

	for _, c := range v.Encode.Valid {
		t.Run("encode/valid/"+c.Description, func(t *testing.T) {
			ok(t, "encode", c.Input, c.Output)
		})
	}
	for _, c := range v.Encode.Invalid {
		t.Run("encode/invalid/"+c.Description, func(t *testing.T) {
			fail(t, "encode", c.Input, c.Errors)
		})
	}
	for _, c := range v.Decode.Invalid {
		t.Run("decode/invalid/"+c.Description, func(t *testing.T) {
			fail(t, "decode", c.Input, c.Errors)
			r := runCLI(t, "", "validate", "--", c.Input)
			if r.code != 1 {
				t.Errorf("validate %q: exit %d, want 1", c.Input, r.code)
			}
		})
	}
}
