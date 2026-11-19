import JsText
import JsValidate

/-! The public JavaScript generator after a successful Web Crypto fill of four unsigned words. -/
namespace Uuid58.Js

/-- RFC 9562 numbers bits from the most significant end. Copy the 48, 12 and 62
payload bits around the four version bits (0100) and the two variant bits (10).
Lean's slice offsets count from the least significant end. -/
def uuidV4 (raw : BitVec 128) : BitVec 128 :=
  raw.extractLsb' 80 48 ++ 4#4 ++ raw.extractLsb' 64 12 ++ 2#2 ++ raw.extractLsb' 0 62

private theorem reassemble_fields (v : BitVec 128) :
    v.extractLsb' 80 48 ++ v.extractLsb' 76 4 ++ v.extractLsb' 64 12 ++
    v.extractLsb' 62 2 ++ v.extractLsb' 0 62 = v := by
  rw [BitVec.extractLsb'_append_extractLsb'_eq_extractLsb' (by decide : 80 = 76 + 4),
    BitVec.extractLsb'_append_extractLsb'_eq_extractLsb' (by decide : 76 = 64 + 12),
    BitVec.extractLsb'_append_extractLsb'_eq_extractLsb' (by decide : 64 = 62 + 2),
    BitVec.extractLsb'_append_extractLsb'_eq_extractLsb' (by decide : 62 = 0 + 62)]
  exact BitVec.extractLsb'_eq_self

/-- The extracted, sequential Uint32Array writes produce exactly the specified 128 bits. -/
theorem stampRandom_correct (a b c d : BitVec 32) :
    let (x, y, z, t) := Extracted.stampRandom a b c d
    x ++ y ++ z ++ t = uuidV4 (a ++ b ++ c ++ d) := by
  have keep (w : Nat) (x : BitVec w) : x &&& BitVec.ofNat w (2^w - 1) = x := by
    rw [← BitVec.toNat_allOnes, BitVec.ofNat_toNat, BitVec.setWidth_eq, BitVec.and_allOnes]
  dsimp only [Extracted.stampRandom]
  calc
    _ = _ := (reassemble_fields _).symm
    _ = uuidV4 _ := by
      simp [uuidV4, @BitVec.extractLsb'_append_eq_ite 96 32, @BitVec.extractLsb'_append_eq_ite 64 32,
        @BitVec.extractLsb'_append_eq_ite 32 32, BitVec.extractLsb'_and, BitVec.extractLsb'_or,
        keep 16, keep 12, keep 30]

/-- The inputs are the contents of random[0..3] immediately after getRandomValues returns. -/
def uuid58 (r : Rounding) (a b c d : BitVec 32) : Option (List CodeUnit) :=
  let (x, y, z, t) := Extracted.stampRandom a b c d
  (encodeWords r ⟨x.toNat, y.toNat, z.toNat, t.toNat⟩).map (List.map toCodeUnit)

theorem uuid58_correct (r : Rounding) (a b c d : BitVec 32) :
    uuid58 r a b c d = some ((encode (uuidV4 (a ++ b ++ c ++ d)).toFin).map toCodeUnit) := by
  have bits := stampRandom_correct a b c d
  unfold uuid58
  generalize Extracted.stampRandom a b c d = words at bits ⊢
  obtain ⟨x, y, z, t⟩ := words
  let w : Words := ⟨x.toNat, y.toNat, z.toNat, t.toNat⟩
  have valid : w.valid := ⟨x.isLt, y.isLt, z.isLt, t.isLt⟩
  have packed : w.value = (x ++ y ++ z ++ t).toNat := by
    simp only [BitVec.toNat_append_eq_mul_add]
    rfl
  have value : w.uuid valid = (uuidV4 (a ++ b ++ c ++ d)).toFin :=
    Fin.ext (packed.trans (congrArg BitVec.toNat bits))
  change (encodeWords r w).map (List.map toCodeUnit) = _
  rw [encode_correct r w valid, value]; rfl

theorem uuid58_roundtrip (r : Rounding) (a b c d : BitVec 32) :
    let v := (uuidV4 (a ++ b ++ c ++ d)).toFin
    ∃ s, uuid58 r a b c d = some s ∧ s.length = 22 ∧ isUuid58 s = true ∧
      decodeString r s = some (.returned (Text.canonical (Words.ofNat v.val))) := by
  let v := (uuidV4 (a ++ b ++ c ++ d)).toFin
  refine ⟨(encode v).map toCodeUnit, uuid58_correct r a b c d, ?_, ?_, ?_⟩
  · simp [encode_length]
  · rw [isUuid58_correct, specBytes_of_encoded_text, decode_encode]; rfl
  · rw [decodeString_correct, decodeStringSpec, specBytes_of_encoded_text, decode_encode]; rfl

end Uuid58.Js
