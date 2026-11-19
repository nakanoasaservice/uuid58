import RustEncode
import RustUuidText
import JsGenerate
import Lean.Util.CollectAxioms

open Aeneas Aeneas.Std Aeneas.Std.WP

/-- Encode using the extracted Rust function, then decode the resulting byte slice. -/
theorem RustUuid58.roundtrip (v : Std.U128) :
    (do let a ← RustUuid58.encode_array v; RustUuid58.decode_value a.to_slice)
      ⦃ r => r = core.result.Result.Ok v ⦄ := by
  apply spec_bind (RustUuid58.encode_correct v)
  intro a h
  apply spec_mono (RustUuid58.decode_correct a.to_slice)
  intro r hr
  simp only [Array.to_slice, Slice.from_val, h, Uuid58.decode_encode] at hr
  exact hr

-- Check transitive dependencies, including generated code and imported proof libraries.
-- This also rejects sorryAx and axioms introduced by native_decide.
open Lean in
run_cmd do
  let allowed := [``propext, ``Classical.choice, ``Quot.sound]
  for decl in [``Uuid58.encode_length, ``Uuid58.encode_alphabet, ``Uuid58.decode_encode, ``Uuid58.encode_decode,
      ``Uuid58.encode_injective, ``Uuid58.encode_order, ``Uuid58.max_encoding,
      ``RustUuid58.encode_correct, ``RustUuid58.decode_correct, ``RustUuid58.public_decode_correct,
      ``RustUuid58.is_valid_correct, ``RustUuid58.roundtrip,
      ``RustUuid58.parse_uuid_str_correct, ``RustUuid58.parse_uuid_str_accepts,
      ``Uuid58.Js.rounding_exists, ``Uuid58.Js.integer_exact, ``Uuid58.Js.floor_div_exact,
      ``Uuid58.Js.divideWords_correct, ``Uuid58.Js.encode_correct, ``Uuid58.Js.digitAt_correct,
      ``Uuid58.Js.appendChunk_correct, ``Uuid58.Js.decode_correct, ``Uuid58.Js.invalid_index_correct,
      ``Uuid58.Js.roundtrip, ``Uuid58.Js.regex_correct, ``Uuid58.Js.isUuid58_correct,
      ``Uuid58.Js.isUuid58_iff_decodeWords, ``Uuid58.Js.encodeBytesSafe_correct, ``Uuid58.Js.decodeBytesSafe_correct,
      ``Uuid58.Js.encodeBytes_correct, ``Uuid58.Js.decodeBytes_correct,
      ``Uuid58.Js.bytes_decode_encode, ``Uuid58.Js.bytes_encode_decode,
      ``Uuid58.Js.Text.block_fits, ``Uuid58.Js.Text.parse_accepts, ``Uuid58.Js.Text.parse_canonical,
      ``Uuid58.Js.Text.scan_spec, ``Uuid58.Js.parseUuidString_correct, ``Uuid58.Js.formatUuidString_correct,
      ``Uuid58.Js.encodeStringSafe_correct, ``Uuid58.Js.encodeStringSafe_accepts, ``Uuid58.Js.decodeStringSafe_correct,
      ``Uuid58.Js.encodeString_correct, ``Uuid58.Js.decodeString_correct,
      ``Uuid58.Js.text_decode_encode, ``Uuid58.Js.text_encode_decode,
      ``Uuid58.Js.stampRandom_correct, ``Uuid58.Js.uuid58_correct, ``Uuid58.Js.uuid58_roundtrip] do
    for axiomName in ← collectAxioms decl do
      unless allowed.contains axiomName do
        throwError "{decl} depends on unexpected axiom {axiomName}"
