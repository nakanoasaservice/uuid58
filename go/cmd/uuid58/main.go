// Command uuid58 converts UUIDs to and from uuid58, a 22-character Base58
// encoding.
//
// Usage:
//
//	uuid58 encode [uuid ...]      UUID -> uuid58
//	uuid58 decode [uuid58 ...]    uuid58 -> lowercase hyphenated UUID
//	uuid58 validate [uuid58 ...]  exit 0 if every input is a valid uuid58
//	uuid58 gen [-n count] [-uuid] new random (version 4) UUIDs as uuid58
//
// encode, decode, and validate read one value per line from standard input
// when no arguments are given. Only the line terminator (\n or \r\n) is
// removed; any other whitespace is part of the value, as in the
// specification.
//
// Every input is processed. Each invalid input is reported on standard error
// with its error kind (invalid_length, invalid_character, or overflow), and
// the exit status is then 1. Usage errors exit with status 2.
package main

import (
	"bufio"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"runtime/debug"
	"strings"

	uuid58 "github.com/nakanoasaservice/uuid58/go"
)

// version is set at link time by release builds
// (-ldflags "-X main.version=1.2.3"). Otherwise it comes from the module
// version recorded by go install.
var version = ""

const usage = `uuid58 converts UUIDs to and from uuid58, a 22-character Base58 encoding.

Usage:
  uuid58 encode [uuid ...]        UUID -> uuid58
  uuid58 decode [uuid58 ...]      uuid58 -> lowercase hyphenated UUID
  uuid58 validate [uuid58 ...]    exit 0 if every input is a valid uuid58 (alias: check)
  uuid58 gen [-n count] [-uuid]   new random version 4 UUIDs as uuid58 (alias: new)
  uuid58 version                  print the version (also --version)
  uuid58 help                     print this help (also --help)

encode, decode, and validate read one value per line from standard input
when no arguments are given.

Errors are reported on standard error with their kind (invalid_length,
invalid_character, or overflow). Exit status: 0 on success, 1 if any input
is invalid, 2 on a usage error.
`

const (
	exitOK      = 0
	exitInvalid = 1
	exitUsage   = 2
)

func main() {
	os.Exit(run(os.Args[1:], os.Stdin, os.Stdout, os.Stderr))
}

// run executes the command line args and returns the exit status.
func run(args []string, stdin io.Reader, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		fmt.Fprint(stderr, usage)
		return exitUsage
	}
	cmd, rest := args[0], args[1:]
	switch cmd {
	case "-h", "-help", "--help", "help":
		fmt.Fprint(stdout, usage)
		return exitOK
	case "-version", "--version", "version":
		fmt.Fprintln(stdout, "uuid58", getVersion())
		return exitOK
	case "encode":
		return convert(cmd, rest, stdin, stdout, stderr, uuid58.Encode)
	case "decode":
		return convert(cmd, rest, stdin, stdout, stderr, uuid58.Decode)
	case "validate", "check":
		return convert(cmd, rest, stdin, io.Discard, stderr, uuid58.Decode)
	case "gen", "new":
		return gen(cmd, rest, stdout, stderr)
	default:
		fmt.Fprintf(stderr, "uuid58: unknown command %q\nRun 'uuid58 --help' for usage.\n", cmd)
		return exitUsage
	}
}

func getVersion() string {
	if version != "" {
		return version
	}
	if info, ok := debug.ReadBuildInfo(); ok && info.Main.Version != "" {
		return info.Main.Version
	}
	return "(devel)"
}

// newFlagSet returns a flag set for a subcommand that writes its help to
// stderr and does not exit on its own.
func newFlagSet(name, args string, stderr io.Writer) *flag.FlagSet {
	fs := flag.NewFlagSet("uuid58 "+name, flag.ContinueOnError)
	fs.SetOutput(stderr)
	fs.Usage = func() {
		fmt.Fprintf(stderr, "Usage: uuid58 %s %s\n", name, args)
		fs.PrintDefaults()
	}
	return fs
}

// parseFlags parses a subcommand's flags. It returns -1 to continue, or an
// exit status.
func parseFlags(fs *flag.FlagSet, args []string) int {
	switch err := fs.Parse(args); {
	case err == nil:
		return -1
	case errors.Is(err, flag.ErrHelp):
		return exitOK
	default:
		return exitUsage
	}
}

// convert applies f to every argument, or to every line of stdin if there are
// none, writing each result on its own line.
func convert(name string, args []string, stdin io.Reader, stdout, stderr io.Writer, f func(string) (string, error)) int {
	fs := newFlagSet(name, "[value ...]", stderr)
	if code := parseFlags(fs, args); code >= 0 {
		return code
	}

	out := bufio.NewWriter(stdout)
	defer out.Flush()
	status := exitOK
	do := func(in string) {
		s, err := f(in)
		if err != nil {
			// Flush first so stdout and stderr stay in input order on a
			// terminal.
			out.Flush()
			fmt.Fprintf(stderr, "uuid58 %s: %q: %s\n", name, in, errorKind(err))
			status = exitInvalid
			return
		}
		out.WriteString(s)
		out.WriteByte('\n')
	}

	if fs.NArg() > 0 {
		for _, a := range fs.Args() {
			do(a)
		}
		return status
	}

	r := bufio.NewReader(stdin)
	for {
		line, err := r.ReadString('\n')
		if line != "" {
			line = strings.TrimSuffix(line, "\n")
			line = strings.TrimSuffix(line, "\r")
			do(line)
		}
		if err == io.EOF {
			break
		}
		if err != nil {
			out.Flush()
			fmt.Fprintf(stderr, "uuid58 %s: reading standard input: %v\n", name, err)
			return exitInvalid
		}
	}
	return status
}

// errorKind returns the specification's name for err's error kind.
func errorKind(err error) string {
	switch {
	case errors.Is(err, uuid58.ErrInvalidLength):
		return "invalid_length"
	case errors.Is(err, uuid58.ErrInvalidCharacter):
		return "invalid_character"
	case errors.Is(err, uuid58.ErrOverflow):
		return "overflow"
	default:
		return err.Error()
	}
}

func gen(name string, args []string, stdout, stderr io.Writer) int {
	fs := newFlagSet(name, "[-n count] [-uuid]", stderr)
	n := fs.Int("n", 1, "number of IDs to generate")
	withUUID := fs.Bool("uuid", false, "also print the UUID, separated by a tab")
	if code := parseFlags(fs, args); code >= 0 {
		return code
	}
	if fs.NArg() > 0 {
		fmt.Fprintf(stderr, "uuid58 %s: unexpected argument %q\n", name, fs.Arg(0))
		return exitUsage
	}
	if *n < 0 {
		fmt.Fprintf(stderr, "uuid58 %s: -n must not be negative\n", name)
		return exitUsage
	}

	out := bufio.NewWriter(stdout)
	defer out.Flush()
	for range *n {
		s := uuid58.New()
		out.WriteString(s)
		if *withUUID {
			u, _ := uuid58.Decode(s) // s is always valid
			out.WriteByte('\t')
			out.WriteString(u)
		}
		out.WriteByte('\n')
	}
	return exitOK
}
