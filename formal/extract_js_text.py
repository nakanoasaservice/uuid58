"""Translate the UUID text parser's ranges and the formatter's byte writes from TypeScript."""

from pathlib import Path
import re
import sys

from extract_js import expect_js, match, read_source, split_function


def number(literal):
    value = int(literal, 16 if literal.startswith("0x") else 10)
    if value >= 2**53:
        raise ValueError(f"unsupported Number literal: {literal}")
    return value


def ranges(expr):
    """Nested parseHex calls evaluate the inner accumulator before the outer call."""
    if expr.strip() == "0":
        return []
    start, end, acc = match(r"parseHex\(uuid, ([0-9]+), ([0-9]+), (.+)\)", expr)
    return ranges(acc) + [(number(start), number(end))]


def lean_pairs(pairs):
    return "[" + ", ".join(f"({a}, {b})" for a, b in pairs) + "]"


def word_reads(statements, width):
    reads = match(r"\s*".join(rf"w{i} = ([^;]+);" for i in range(4)), statements)
    words = [ranges(expr) for expr in reads]
    if any(not 0 <= a <= b <= width for word in words for a, b in word):
        raise ValueError("unsupported out-of-bounds UUID read")
    return "[" + ", ".join(lean_pairs(word) for word in words) + "]"


def parser(table, scan, body):
    lower, upper = match(
        r'import \{ Uuid58EncodeError \} from "\./errors\.ts";\s*'
        r"const HEX_VALUE = new Int8Array\(128\)\.fill\(-1\);\s*"
        r"for \(let i = 0; i < 16; i\+\+\) \{\s*" +
        r'HEX_VALUE\["([A-Za-z0-9]{16})"\.charCodeAt\(i\)\] = i;\s*' * 2 +
        r"\}\s*const words = new Uint32Array\(4\);", table)
    radix, = match(
        r"for \(let i = start; i < end; i\+\+\) \{\s*const code = uuid\.charCodeAt\(i\);\s*"
        r"const digit = code < 128 \? HEX_VALUE\[code\]! : -1;\s*"
        r"if \(digit < 0\) \{\s*return -1;\s*\}\s*acc = acc \* ([0-9]+) \+ digit;\s*\}\s*return acc;", scan)
    plain_len, plain, dash_len, dashed, checks, tail = match(
        r"\s*".join(rf"let w{i}: number;" for i in range(4)) +
        r"\s*let hyphensValid = true;\s*if \(uuid\.length === ([0-9]+)\) \{([^{}]*)\}"
        r"\s*else if \(uuid\.length === ([0-9]+)\) \{([^{}]*)hyphensValid =\s*([^;]+);\s*\} else \{(.*)", body)
    expect_js(tail, """
        return new Uuid58EncodeError(`Invalid UUID length: expected 32 or 36 characters, got ${uuid.length}`, "invalid_length",); }
        if (!hyphensValid || w0 < 0 || w1 < 0 || w2 < 0 || w3 < 0) {
          return new Uuid58EncodeError(uuid.length === 32 ? "Invalid UUID: must be 32 hexadecimal digits"
            : "Invalid UUID: must be in the form xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx", "invalid_character",); }
        words[0] = w0; words[1] = w1; words[2] = w2; words[3] = w3; return words;""")
    marks = []
    for term in checks.split("&&"):
        index, code = match(r"uuid\.charCodeAt\(([0-9]+)\) === ([0-9]+)", term)
        marks.append((number(index), number(code)))
    yield f'def lowerInput := "{lower}"\ndef upperInput := "{upper}"'
    yield f"def hexRadix : Nat := {number(radix)}"
    for name, width, layout in (("plain", plain_len, plain), ("dashed", dash_len, dashed)):
        yield f"def {name}Length : Nat := {number(width)}"
        yield f"def {name}Reads : List (List (Nat × Nat)) := {word_reads(layout, number(width))}"
    yield f"def separators : List (Nat × Nat) := {lean_pairs(marks)}"


def formatter(table, writer, body):
    alphabet, init, dash = match(
        r"const HEX_CODES = new Uint8Array\(16\);\s*for \(let i = 0; i < 16; i\+\+\) \{\s*"
        r'HEX_CODES\[i\] = "([A-Za-z0-9]{16})"\.charCodeAt\(i\);\s*\}\s*'
        r"const chars = new Uint8Array\(36\);\s*((?:chars\[[0-9]+\] = )+)([0-9]+);", table)
    literal = r"(0x[0-9a-fA-F]+|[0-9]+)"
    mask, shift = match(
        r"for \(let i = 3; i >= 0; i--\) \{\s*chars\[pos \+ i\] = HEX_CODES\[value & " +
        literal + r"\]!;\s*value >>>= " + literal + r";\s*\}", writer)
    writes, output = match(r"\s*".join(rf"const w{i} = words\[{i}\]!;" for i in range(4)) +
        r"\s*((?:writeHex16\([^;]+;\s*)+)const c = chars;\s*return String\.fromCharCode\(([^()]*)\);", body)
    # Unroll the fixed four stores per call. Each slot records the source word,
    # its shift or mask, and how often writeHex16 has shifted that value.
    slots = {number(i): f".inl {number(dash) % 256}" for i in re.findall(r"chars\[([0-9]+)\]", init)}
    for call in writes.strip().removesuffix(";").split(";"):
        w, op, operand, pos = match(r"writeHex16\(w([0-3]) (>>>|&) " + literal + r", ([0-9]+)\)", call)
        for step in range(4):
            i = number(pos) + 3 - step
            if i in slots:
                raise ValueError("overlapping UUID text output writes")
            slots[i] = f".inr ({w}, {'true' if op == '>>>' else 'false'}, {number(operand)}, {step})"
    if slots.keys() != set(range(36)):
        raise ValueError("UUID text output buffer is not fully initialized")
    result = []
    for arg in output.strip().removesuffix(",").split(","):
        i, = match(r"c\[([0-9]+)\]!", arg)
        result.append(slots[number(i)])
    yield f'def outputAlphabet := "{alphabet}"'
    yield f"def nibbleMask : Nat := {number(mask)}\ndef nibbleShift : Nat := {number(shift)}"
    yield "abbrev Slot := Sum Nat (Nat × Bool × Nat × Nat)"
    yield "def outputSlots : List Slot := [\n  " + ",\n  ".join(result) + "]"


def extract(directory):
    # The package entry point directly re-exports these four functions under their own names.
    public = set()
    for statement in read_source(directory / "index.ts").strip().removesuffix(";").split(";"):
        items, module = match(r'export\s*\{([^{}]*)\}\s*from\s*"([^"]+)"', statement)
        if module == "./string.ts":
            public.update(name.strip() for name in items.split(","))
    if not {"uuid58Encode", "uuid58EncodeSafe", "uuid58Decode", "uuid58DecodeSafe"} <= public:
        raise ValueError("missing public UUID text export")
    expect_js(read_source(directory / "string.ts"), """
        import { decodeWords, encodeWords } from "./base58.ts";
        import { Uuid58DecodeError, Uuid58EncodeError } from "./errors.ts";
        import { formatUuidString, parseUuidString } from "./uuid-hex.ts";
        export function uuid58EncodeSafe(uuid: string): string | Uuid58EncodeError {
          const parsed = parseUuidString(uuid); return parsed instanceof Uuid58EncodeError ? parsed : encodeWords(parsed); }
        export function uuid58Encode(uuid: string): string {
          const result = uuid58EncodeSafe(uuid); if (result instanceof Uuid58EncodeError) { throw result; } return result; }
        export function uuid58DecodeSafe(uuid58: string): string | Uuid58DecodeError {
          const decoded = decodeWords(uuid58); return decoded instanceof Uuid58DecodeError ? decoded : formatUuidString(decoded); }
        export function uuid58Decode(uuid58: string): string {
          const result = uuid58DecodeSafe(uuid58); if (result instanceof Uuid58DecodeError) { throw result; } return result; }
    """)
    table, scan, rest = split_function(read_source(directory / "uuid-hex.ts"),
        r"function parseHex\(\s*uuid: string,\s*start: number,\s*end: number,\s*acc: number,\s*\): number")
    gap, parse, rest = split_function(rest, r"export function parseUuidString\(uuid: string\): Uint32Array \| Uuid58EncodeError")
    output, writer, rest = split_function(rest, r"function writeHex16\(value: number, pos: number\): void")
    gap2, display, end = split_function(rest, r"export function formatUuidString\(words: ArrayLike<number>\): string")
    if any(s.strip() for s in (gap, gap2, end)):
        raise ValueError("unexpected statement outside the UUID text functions")
    yield "import Std\nnamespace Uuid58.Js.TextExtracted\n"
    yield from parser(table, scan, parse)
    yield from formatter(output, writer, display)
    yield "\nend Uuid58.Js.TextExtracted"


if __name__ == "__main__":
    print("\n".join(extract(Path(sys.argv[1]))))
