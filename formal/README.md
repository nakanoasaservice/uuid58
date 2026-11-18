# Formal verification

Lean checks the numeric codec against sections 2–4 of [specification 1.1.0](../spec/SPEC.md).
The model treats a UUID as an unsigned integer below `2^128` and reads text as bytes,
one of the length units allowed by section 4.1. Its decoder evaluates the positional
polynomial using natural numbers.

| What is checked | Lean source |
| --- | --- |
| Every UUID has 22 alphabet bytes. Both round trips hold, encoding is injective, and unsigned bytewise order agrees with numeric order. | [Spec](Spec.lean), [proofs](Proofs.lean) |
| The 2 + 10 + 10 digit split and its inverse preserve the value. | [Chunk arithmetic](Chunk.lean) |
| The Rust encoder emits those exact bytes for every `u128`. The lookup table classifies every possible byte. | [Encoder](RustEncode.lean), [tables](RustTables.lean) |
| For every byte slice, Rust decoding returns the specified value or the specified first error. `is_valid` agrees with successful decoding. | [Decoder](RustDecode.lean) |
| For every four unsigned 32-bit words, the JavaScript encoder produces the specified 22 ASCII characters, including leading zero digits. | [Number rounding](JsNumber.lean), [encoder](JsEncode.lean) |

The script runs Charon on the crate's actual source and translates the reachable
functions with Aeneas. The Rust theorems establish successful termination in
Aeneas's model, including the bounds on array accesses, casts and arithmetic.
The public decoder and validator theorems assume that the caller's `AsRef`
implementation returns its input slice successfully. [Audit.lean](Audit.lean)
also composes the extracted encoder and decoder and checks the transitive axioms
of the main theorems against Lean's `propext`, `Classical.choice` and `Quot.sound`.

The Rust guarantee covers the numeric core shared by the crate's feature configurations.
Extraction uses the crate without optional features on the host target. Its trust
boundary includes the correspondence between the written and formal specifications,
Lean's kernel and libraries, rustc, Charon, Aeneas and its Rust library models.
The UUID text parser, formatting and allocation wrappers and generated machine code
are outside the Rust proof.

The [JavaScript extractor](extract_js.py) reads the alphabet and the arithmetic
expressions from the TypeScript sources on each run. It recognizes the four-word
loop, the right-to-left digit writes and the final buffer reads. An unsupported
statement in these blocks fails extraction. Lean checks that all six divisions
by `58³` produce the integer quotient and remainder and that the leading four
digits and six three-digit groups give the specified encoding.

The rounding proof compares exact rational results with the representable
binary64 values on either side of an integer boundary. It applies to every
nearest rounding, including ECMAScript's ties-to-even rule. The JavaScript
theorem assumes four unsigned input words, the extractor's translation, and
standard Number, typed-array and string operations. The JS decoder and the
public UUID text and byte wrappers are covered by the conformance tests.
[ECMAScript Number type](https://tc39.es/ecma262/#sec-ecmascript-language-types-number-type)

## Run the check

Use Bash, Python 3.11 or later, rustup, and the Lean version in
[lean-toolchain](lean-toolchain). With elan installed, running the script selects
that Lean toolchain. Download the Linux x86-64 archive from the
[pinned Aeneas release](https://github.com/AeneasVerif/aeneas/releases/tag/nightly-2026.11.18-1dc8ad3)
and extract it to a writable directory, then run this from the repository root.

```sh
AENEAS_DIR=/path/to/extracted/aeneas formal/check.sh
```

The first run installs the release's Rust nightly if needed and builds the pinned
Lean dependencies in the Aeneas directory. Every run regenerates the Rust and
JavaScript models in a fresh temporary directory, checks the proofs and runs the applicable shared
vectors (round trips, additional valid pairs and invalid decoder inputs).
The [CI workflow](../.github/workflows/ci-spec.yml) fetches the required mathlib
modules from mathlib's official build cache for the pinned dependency versions.
Lake builds any missing modules from source. The workflow also includes the
Linux setup and archive checksums.
