"""Translate the numeric codec in base58.ts into Lean's checked Number operations."""

import ast
from pathlib import Path
import re
import sys


def match(pattern, text):
    result = re.fullmatch(pattern, text.strip(), re.DOTALL)
    if not result:
        raise ValueError(f"unsupported codec source: {text!r}")
    return result.groups()


def expression(source, names):
    """The accepted arithmetic operators have the same precedence in JS and Python."""
    if not source.isascii():
        raise ValueError(f"unsupported Number expression: {source!r}")
    ops = {ast.Add: "add", ast.Sub: "sub", ast.Mult: "mul", ast.Div: "exactDiv"}

    def render(node):
        if isinstance(node, ast.Name) and node.id in names:
            return names[node.id]
        if isinstance(node, ast.Constant) and type(node.value) is int and 0 <= node.value < 2**53:
            return str(node.value)
        if isinstance(node, ast.BinOp) and type(node.op) in ops:
            return f"(← {ops[type(node.op)]} r {render(node.left)} {render(node.right)})"
        if isinstance(node, ast.Call) and ast.unparse(node.func) == "Math.floor":
            if not node.keywords and len(node.args) == 1:
                arg = node.args[0]
                if isinstance(arg, ast.BinOp) and isinstance(arg.op, ast.Div):
                    return f"(← floorDiv r {render(arg.left)} {render(arg.right)})"
        raise ValueError(f"unsupported Number expression: {source!r}")

    return render(ast.parse(source, mode="eval").body)


def split_function(source, signature):
    pattern = rf"^{signature}\s*\{{(.*?)^\}}"
    function, = re.finditer(pattern, source, re.MULTILINE | re.DOTALL)
    return source[:function.start()], function[1], source[function.end():]


def read_source(path):
    # Preserve quoted strings and template literals. A multiline comment can
    # insert a semicolon after return, so keep its line terminator as well.
    tokens = r'''("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`)|/\*.*?\*/|//[^\r\n\u2028\u2029]*'''

    def strip_comment(token):
        if token[1] is not None:
            return token[1]
        return "\n" if re.search(r"[\r\n\u2028\u2029]", token[0]) else " "

    return re.sub(tokens, strip_comment, path.read_text(), flags=re.DOTALL)


def expect_js(source, expected):
    """Check fixed control flow, keeping string literals and JS token boundaries."""
    token = r'`[^`]*`|"[^"\n]*"|[\w$]+|>>>|!==|>=|\+\+|\+=|\S'
    if (re.findall(token, source) != re.findall(token, expected)
            or re.search(r"\breturn[^\S\r\n\u2028\u2029]*[\r\n\u2028\u2029]", source)):
        raise ValueError(f"unsupported codec source: {source.strip()!r}")


def extract_decoder(source, errors):
    table, lookup, rest = split_function(source, r"function digitAt\(uuid58: string, i: number\): number")
    gap, read_digits, rest = split_function(rest, r"function readDigits\(uuid58: string, start: number, count: number\): number")
    gap2, invalid, rest = split_function(rest, r"function invalidCharacterError\(uuid58: string\): Uuid58DecodeError")
    gap3, decode, end = split_function(rest, r"export function decodeWords\(uuid58: string\): Uint32Array \| Uuid58DecodeError")
    if any(s.strip() for s in (gap, gap2, gap3, end)):
        raise ValueError("unexpected statement outside the decoder functions")

    expect_js(table, """
        const BASE58_INDEX = new Int8Array(128).fill(-1);
        for (let i = 0; i < UUID58_ALPHABET.length; i++) {
          BASE58_INDEX[UUID58_ALPHABET.charCodeAt(i)] = i;
        }
        const words = new Uint32Array(4);
    """)
    expect_js(lookup, """const code = uuid58.charCodeAt(i);
        return code < 128 ? BASE58_INDEX[code]! : -1;""")
    update, = match(r"let value = 0;\s*for \(let i = start; i < start \+ count; i\+\+\) \{\s*"
                    r"const digit = digitAt\(uuid58, i\);\s*if \(digit < 0\) \{\s*return -1;\s*\}\s*"
                    r"value = ([^;]+);\s*\}\s*return value;", read_digits)
    yield "\ndef readDigit (r : Rounding) (value digit : Nat) : Option Nat := do"
    yield f"  return {expression(update, {'value': 'value', 'digit': 'digit'})}"
    expect_js(invalid, """let i = 0; while (digitAt(uuid58, i) >= 0) { i++; }
        return new Uuid58DecodeError(`Invalid Base58 character at index ${i}`, "invalid_character",);""")
    prefix, error_class = errors.split("export class Uuid58DecodeError extends Error")
    expect_js(prefix, """
        export type Uuid58ErrorKind = | "invalid_length" | "invalid_character" | "overflow";
        export class Uuid58EncodeError extends Error {
          static { this.prototype.name = "Uuid58EncodeError"; }
          readonly kind: Exclude<Uuid58ErrorKind, "overflow">;
          constructor(message: string, kind: Exclude<Uuid58ErrorKind, "overflow">) {
            super(message); this.kind = kind;
          }
        }
    """)
    expect_js(error_class, """{ static { this.prototype.name = "Uuid58DecodeError"; }
        readonly kind: Uuid58ErrorKind;
        constructor(message: string, kind: Uuid58ErrorKind) { super(message); this.kind = kind; } }""")

    header, rest = decode.split("let cur =")
    expect_js(header, """
        if (uuid58.length !== 22) {
          return new Uuid58DecodeError(`Expected Base58 string of length 22, but received string of length ${uuid58.length}`, "invalid_length",);
        }
        let w0 = 0; let w1 = 0; let w2 = 0; let w3 = readDigits(uuid58, 0, 4);
        if (w3 < 0) { return invalidCharacterError(uuid58); }
        for (let start = 4; start < 22; start += 3) {
          const chunk = readDigits(uuid58, start, 3);
          if (chunk < 0) { return invalidCharacterError(uuid58); }
    """)
    arithmetic, finish = rest.split("}", 1)
    # Each >>> 0 retains the low word. The high register keeps its carry.
    statements = [s.strip() for s in arithmetic.strip().removesuffix(";").split(";")]
    if len(statements) != 7:
        raise ValueError("expected three unsigned word stores and one high word")
    for word in (3, 2, 1, 0):
        names = {f"w{word}": "word", "BASE58_CUBE": "cube", "WORD": "wordBase"}
        assignment = statements[(3-word)*2]
        if word == 3:
            expr = assignment
            names["chunk"] = "chunk"
            args = "word chunk"
        else:
            lhs = "cur" if word else "w0"
            expr, = match(rf"{lhs}\s*=\s*(.+)", assignment)
            names.update({"cur": "cur", f"w{word+1}": "low"})
            args = "word cur low"
        if word:
            expect_js(statements[(3-word)*2+1], f"w{word} = cur >>> 0")
        yield f"\ndef accumulate{word} (r : Rounding) ({args} : Nat) : Option Nat := do"
        yield f"  return {expression(expr, names)}"
    comparison, = match(r'if \(w0 (>=|>) WORD\) \{\s*return new Uuid58DecodeError\(\s*'
                        r'"Decoded value exceeds 128 bits of UUID",\s*"overflow",\s*\);\s*\}\s*'
                        + r"\s*".join(rf"words\[{i}\] = w{i};" for i in range(4))
                        + r"\s*return words;", finish)
    op = "≥" if comparison == ">=" else ">"
    yield f"\ndef overflow (high : Nat) : Bool := decide (high {op} wordBase)"


def extract(directory):
    alphabet, = match(r'export const UUID58_ALPHABET: string =\s*"([A-Za-z0-9]+)";',
                      read_source(directory / "alphabet.ts"))
    before, encoder, after = split_function(
        read_source(directory / "base58.ts"),
        r"export function encodeWords\(words: ArrayLike<number>\): string")
    preamble, writer, gap = split_function(
        before, r"function writeDigits\(value: number, count: number, pos: number\): number")
    if gap.strip() or re.search(r"\b(ALPHABET_CODES|digits)\b", after):
        raise ValueError("unexpected access to the encoder's scratch buffers")
    word_base, cube = match(
        r'import \{ UUID58_ALPHABET \} from "\./alphabet\.ts";\s*'
        r'import \{ Uuid58DecodeError \} from "\./errors\.ts";\s*'
        r"const WORD = ([0-9]+);\s*const BASE58_CUBE = ([0-9]+);\s*"
        r"const ALPHABET_CODES = new Uint8Array\(58\);\s*for \(let i = 0; i < 58; i\+\+\) \{\s*"
        r"ALPHABET_CODES\[i\] = UUID58_ALPHABET\.charCodeAt\(i\);\s*\}\s*"
        r"const digits = new Uint8Array\(22\);", preamble)
    yield "import JsNumber\nnamespace Uuid58.Js.Extracted\n"
    yield f'def alphabet := "{alphabet}"'
    yield f"def wordBase : Nat := {int(word_base)}"
    yield f"def cube : Nat := {int(cube)}"

    prefix, output = encoder.split("const d = digits;")
    args, = match(r"return String\.fromCharCode\(([^()]*)\);", output)
    if [arg.strip() for arg in args.strip().removesuffix(",").split(",")] != [f"d[{i}]!" for i in range(22)]:
        raise ValueError("expected the 22 output characters in order")

    loads, loop_and_tail = prefix.split("let pos = 21;")
    match(r"\s*".join(rf"let w{i} = words\[{i}\]!;" for i in range(4)), loads)
    rounds, loop, leading = match(
        r"for \(let round = 0;\s*round < ([0-9]+);\s*round\+\+\) \{([^{}]*)\}\s*"
        r"writeDigits\(w3, ([0-9]+), pos\);", loop_and_tail)
    statements = [s.strip() for s in loop.split(";") if s.strip()]
    if len(statements) != 13:
        raise ValueError("expected four word updates and one digit group")
    width, = match(r"pos = writeDigits\(rem, ([0-9]+), pos\)", statements[-1])
    for name, value in [("rounds", rounds), ("width", width), ("leading", leading)]:
        yield f"def {name} : Nat := {int(value)}"

    for i in range(4):
        names = {"WORD": "wordBase", "BASE58_CUBE": "cube", f"w{i}": "word"}
        args = "word" if i == 0 else "carry word"
        if i:
            names["rem"] = "carry"
        yield f"\ndef step{i} (r : Rounding) ({args} : Nat) : Option (Nat × Nat) := do"
        targets = ["cur" if i else "let cur", f"w{i}", "rem" if i else "let rem"]
        for assignment, lhs, var in zip(statements[3*i:3*i+3], targets, ["cur", "q", "rem"], strict=True):
            expr, = match(rf"{lhs}\s*=\s*(.+)", assignment)
            yield f"  let {var} := {expression(expr, names)}"
            names[lhs.removeprefix("let ")] = var
        yield "  return (q, rem)"

    divisor, digit = match(
        r"for \(let n = 0;\s*n < count;\s*n\+\+\) \{\s*"
        r"const quotient = \(value / ([0-9]+)\) >>> 0;\s*"
        r"digits\[pos--\] = ALPHABET_CODES\[([^\]]+)\]!;\s*value = quotient;\s*}\s*return pos;",
        writer)
    yield "\ndef digitStep (r : Rounding) (value : Nat) : Option (Nat × Nat) := do"
    yield f"  let q := (← floorDiv r value {int(divisor)}) % 2^32"
    yield f"  return (q, {expression(digit, {'value': 'value', 'quotient': 'q'})})"
    yield from extract_decoder(after, read_source(directory / "errors.ts"))
    yield "\nend Uuid58.Js.Extracted"


if __name__ == "__main__":
    print("\n".join(extract(Path(sys.argv[1]))))
