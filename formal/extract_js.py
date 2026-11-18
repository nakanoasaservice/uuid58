"""Translate the numeric encoder in base58.ts into Lean's checked Number operations."""

import ast
from pathlib import Path
import re
import sys


def match(pattern, text):
    result = re.fullmatch(pattern, text.strip(), re.DOTALL)
    if not result:
        raise ValueError(f"unsupported encoder source: {text!r}")
    return result.groups()


def expression(source, names):
    """The accepted arithmetic operators have the same precedence in JS and Python."""
    if not source.isascii():
        raise ValueError(f"unsupported Number expression: {source!r}")
    ops = {ast.Add: "add", ast.Sub: "sub", ast.Mult: "mul"}

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
    return re.sub(r"/\*.*?\*/|//[^\n]*", " ", path.read_text(), flags=re.DOTALL)


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
    yield "\nend Uuid58.Js.Extracted"


if __name__ == "__main__":
    print("\n".join(extract(Path(sys.argv[1]))))
