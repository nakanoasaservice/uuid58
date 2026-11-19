# Formal verification

Lean checks the numeric codec against sections 2–4, the Rust UUID text parser and
formatter and the JavaScript UUID string APIs against section 5, and the
Rust and JavaScript validators against section 6 of specification 1.1.0.
The numeric specification treats a UUID as an unsigned integer below `2^128`
and reads Base58 text as bytes, one of the length units allowed by section 4.1.
Its decoder evaluates the positional polynomial using natural numbers.
The JavaScript model measures strings in UTF-16 code units. [Specification](../spec/SPEC.md)

| What is checked | Lean source |
| --- | --- |
| Every UUID has 22 alphabet bytes. Both round trips hold, encoding is injective, and unsigned bytewise order agrees with numeric order. | [Spec](Spec.lean), [proofs](Proofs.lean) |
| The 2 + 10 + 10 digit split and its inverse preserve the value. | [Chunk arithmetic](Chunk.lean) |
| The Rust encoder emits those exact bytes for every `u128`. The lookup table classifies every possible byte. | [Encoder](RustEncode.lean), [tables](RustTables.lean) |
| For every byte slice, Rust decoding returns the specified value or the specified first error. `is_valid` agrees with successful decoding. | [Decoder](RustDecode.lean) |
| For every byte slice, Rust `parse_uuid_str` accepts exactly the two specified UUID spellings, returns their big-endian `u128` value and checks byte length before characters. | [Byte-oriented UUID text specification](UuidTextScan.lean), [Rust parser](RustUuidText.lean) |
| For every `u128` and every initial 36-byte buffer, Rust `format_uuid` writes the lowercase hyphenated UUID and returns those same bytes as a string. Passing it to `parse_uuid_str` recovers the original value. | [Big-endian byte and nibble layout](RustUuidLayout.lean), [formatter and round trip](RustUuidFormat.lean) |
| For every input byte slice and every initial 36-byte buffer, Rust `decode_to_uuid_buf` writes and returns the canonical UUID on success. On failure it returns the first decoding error and preserves all 36 bytes. | [Public decoder and output buffer](RustUuidFormat.lean) |
| For every four unsigned 32-bit words, the JavaScript encoder produces the specified 22 ASCII characters, including leading zero digits. | [Number rounding](JsNumber.lean), [encoder](JsEncode.lean) |
| For every UTF-16 code-unit sequence, the JavaScript decoder returns the four specified big-endian words or the specified error kind. Encoding and decoding returns the original four words. | [Decoder and round trip](JsDecode.lean) |
| For every UTF-16 code-unit sequence, JavaScript's `isUuid58` returns true exactly when `decodeWords` succeeds. | [Validator](JsValidate.lean) |
| The JavaScript byte APIs encode and decode 16 bytes in big-endian order. Both round trips hold. The safe APIs return the specified error kind and the ordinary APIs throw it. | [Byte specification](Bytes.lean), [JavaScript byte API](JsBytes.lean) |
| The JavaScript string APIs accept plain or hyphenated UUIDs with any mix of ASCII hex letter cases. A UUID round trip produces lowercase hyphenated text, and a Base58 round trip preserves the input exactly. The safe and throwing APIs report the specified first error kind. | [UUID text specification](UuidText.lean), [parser](JsTextParse.lean), [formatter and public APIs](JsText.lean) |
| After a successful Web Crypto fill, JavaScript's `uuid58()` sets the UUIDv4 version and variant and preserves the other 122 bits. Its 22-character result passes `isUuid58` and `uuid58Decode` returns that UUID in canonical form. | [UUIDv4 generator](JsGenerate.lean) |

The script runs Charon on the crate's actual source and translates the reachable
functions with Aeneas. The Rust theorems establish successful termination in
Aeneas's model, including the bounds on array accesses, casts and arithmetic.
The proofs for public functions that accept `AsRef<[u8]>` assume that the caller's
`AsRef` implementation returns its input slice successfully. [Audit.lean](Audit.lean)
also composes the extracted encoder and decoder and checks the transitive axioms
of the main theorems against Lean's `propext`, `Classical.choice` and `Quot.sound`.

The Rust guarantee covers the numeric core, UUID text parser, UUID text formatter
and public `decode_to_uuid_buf` function shared by the crate's feature configurations.
Extraction uses the crate without optional features on the host target. Its trust
boundary includes the correspondence between the written and formal specifications,
Lean's kernel and libraries, rustc, Charon, Aeneas and its Rust library models.
The extraction models Rust functions before machine-code generation. Runtime
conformance tests also exercise the public buffer and allocation wrappers.

The Rust parser proof follows the two extracted loops over an enumerated byte slice.
It widens each byte to one code unit in the shared UUID text specification, preserving
byte length even for ill-formed UTF-8. For each hex digit, the proof relates the Rust
shift and bitwise OR to multiplication by 16 and addition. Reading all 32 digits
produces the value of the four big-endian words in the specification.
[Parser source](../rust/src/lib.rs) · [UUID text specification](UuidText.lean)

The Rust formatter proof follows both nibbles of each big-endian byte through the
lowercase hex table. It verifies every buffer write, including the four hyphens,
and relates the final bytes to the same canonical spelling used for JavaScript.
The pinned Aeneas library represents a Rust string slice by its bytes. The model
of `core::str::from_utf8` uses Lean's UTF-8 validator and preserves the error tag.
The formatter sees only the tag on error. Lean proves every output byte is ASCII,
so the conversion succeeds and returns the complete contents of the final buffer.
The round trip passes this byte view to the extracted public parser.
[UTF-8 model](Uuid58/FunsExternal.lean) · [Formatter proof](RustUuidFormat.lean)

The [JavaScript extractor](extract_js.py) reads the alphabet and the arithmetic
expressions from the TypeScript sources on each run. It checks the loop and
buffer operations for both directions, the decoder's validation order and
the error constructor's assignment to `kind`. Unsupported statements in
these blocks fail extraction. Lean checks that the encoder's six divisions
by `58³` produce the integer quotient and remainder and that the leading four
digits and six three-digit groups give the specified encoding.

The decoder proof follows the carries through the four registers. A prefix
before the final group is smaller than `58¹⁹`, so the high word can exceed
`2³² - 1` only in the last group. Each division used to extract a carry is
exact in binary64. The decoder reports overflow precisely when the numeric
value is at least `2¹²⁸`.
The decoder measures length in UTF-16 code units. To apply the byte-oriented
specification, the proof preserves every ASCII unit and maps each other unit
to one invalid byte. This keeps the length and first invalid position,
including for unpaired surrogates.

The extractor also reads the validator's anchored Unicode regex, its character
ranges and repetition count, the upper-bound literal and the comparison.
Lean checks how the regex consumes UTF-16 surrogate pairs and proves that each
accepted character occupies one ASCII code unit. On those inputs the JS string
comparison agrees with numeric order, including equality at `2¹²⁸ − 1`.
The proof assumes the exported regex retains its declared pattern and flags
and uses the standard ECMAScript regex and string operations. [Validator source](../js/src/check.ts)

For the public byte APIs, the extractor reads the byte indices, shifts and bitwise
ORs. It checks the typed-array allocations, the four loop iterations and the
error branches. Lean compares the resulting 32-bit patterns with an independent
base-256 specification. The input is the sequence of bytes in a standard
`Uint8Array` view, held fixed during the call, so a subarray starts at its own
offset. The decoder theorem describes the returned bytes. The source check and
runtime tests also cover allocation of a fresh result on each successful call.
[Byte API source](../js/src/bytes.ts)

The UUID text extractor reads the input tables, hex accumulator, parser ranges and
separator checks. Lean proves that all eight digits of each word are exact in
binary64. If the first part of a split word fails, its negative accumulator stays
negative through the second part. The formatter proof checks every buffer store
and every argument to `String.fromCharCode` against the 32 lowercase hex digits
and four separators of the canonical form. The public API proofs compose those
results with the numeric codec on every UTF-16 code-unit sequence.
[Text extractor](extract_js_text.py) · [UUID text source](../js/src/uuid-hex.ts) · [Public wrappers](../js/src/string.ts)

JavaScript offers the optional generator mentioned in section 1.2. Its proof
starts with the four unsigned words supplied by a successful `crypto.getRandomValues`
call. The extractor checks the fill and encoder call and translates each intervening
array read, mask and store in source order. A signed bitwise result keeps its 32-bit
pattern when stored in the unsigned array. Lean compares the result with the RFC
9562 layout, which copies 48 bits, inserts `0100`, copies 12 bits, inserts `10`,
and copies the final 62 bits. The guarantee holds for every input, including
repeated draws. The randomness of the draws comes from the host's Web Crypto implementation.
[Generator source](../js/src/generate.ts) · [UUIDv4 layout](https://www.rfc-editor.org/rfc/rfc9562#section-5.4)

The rounding proof compares exact rational results with the representable
binary64 values on either side of an integer boundary. It applies to every
nearest rounding, including ECMAScript's ties-to-even rule. The JavaScript
theorems assume the extractor's translation and standard Number, typed-array
and string operations. The encoder takes four unsigned input words. The
decoder result describes the contents of the reused array when it returns.
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
vectors (round trips, alternative UUID spellings, invalid UUID strings and invalid Base58 inputs).
The [CI workflow](../.github/workflows/ci-spec.yml) fetches the required mathlib
modules from mathlib's official build cache for the pinned dependency versions.
Lake builds any missing modules from source. The workflow also includes the
Linux setup and archive checksums.
