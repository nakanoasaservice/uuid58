import JsBytes
import JsTextParse

/-! JavaScript public UUID string APIs and the formatter's extracted byte writes. -/
namespace Uuid58.Js

private def shifted (value : Nat) : Nat → Nat
  | 0 => value
  | steps + 1 => shifted (value >>> (TextExtracted.nibbleShift % 32)) steps

/-- Keep the low 32 bits for JS bitwise operations. Each loop iteration stores
the alphabet byte selected by the low bits and shifts the value for the next store. -/
private def outputIndex (word : Nat) (right : Bool) (arg steps : Nat) :=
  let bits := word % 2^32
  let half := if right then bits >>> (arg % 32) else bits &&& (arg % 2^32)
  shifted half steps &&& (TextExtracted.nibbleMask % 2^32)

private def render (w : Words) : TextExtracted.Slot → CodeUnit
  | .inl c => Fin.ofNat (2^16) c
  | .inr (k, right, arg, steps) =>
    let i := outputIndex (Text.word w k) right arg steps
    toCodeUnit ((bytes TextExtracted.outputAlphabet)[i]?.getD 0)

def formatUuidString (w : Words) := TextExtracted.outputSlots.map (render w)

private def digitSlot (i : Nat) : TextExtracted.Slot :=
  let j := i % 8
  .inr (i / 8, decide (j < 4), if j < 4 then 16 else 65535, 3 - j % 4)

private def expectedSlot (p : Nat) : TextExtracted.Slot :=
  match Text.digitIndex p with
  | none => .inl 45
  | some i => digitSlot i

private theorem output_layout : TextExtracted.outputSlots = (List.range 36).map expectedSlot := by decide

private theorem alphabet_lower : ∀ d : Text.Nibble,
    toCodeUnit ((bytes TextExtracted.outputAlphabet)[d.val]?.getD 0) = Text.lower d := by decide

private theorem index_correct (n j : Nat) (hj : j < 8) :
    outputIndex n (decide (j < 4)) (if j < 4 then 16 else 65535) (3 - j % 4) = (Text.nibble n j).val := by
  have mask4 (x : Nat) : x &&& 15 = x % 16 := Nat.and_two_pow_sub_one_eq_mod x 4
  have mask16 (x : Nat) : x &&& 65535 = x % 65536 := Nat.and_two_pow_sub_one_eq_mod x 16
  have cases : j = 0 ∨ j = 1 ∨ j = 2 ∨ j = 3 ∨ j = 4 ∨ j = 5 ∨ j = 6 ∨ j = 7 := by omega
  rcases cases with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;>
    simp [outputIndex, TextExtracted.nibbleMask, shifted, TextExtracted.nibbleShift, mask4, mask16,
      Nat.shiftRight_eq_div_pow, Text.nibble, Fin.val_ofNat] <;> omega

theorem formatUuidString_correct (w : Words) : formatUuidString w = Text.canonical w := by
  rw [formatUuidString, output_layout, List.map_map, Text.canonical]
  apply congrArg (fun f => (List.range 36).map f)
  funext p
  change render w (expectedSlot p) = Text.character w p
  unfold expectedSlot Text.character
  cases Text.digitIndex p with
  | none => rfl
  | some i =>
    simp only [digitSlot, render, index_correct _ _ (Nat.mod_lt i (by decide))]
    apply alphabet_lower

def encodeStringSafe (r : Rounding) (s : List CodeUnit) : Option (Except Error (List CodeUnit)) := do
  match ← parseUuidString r s with
  | .error e => return .error e
  | .ok w => return .ok ((← encodeWords r w).map toCodeUnit)

def decodeStringSafe (r : Rounding) (s : List CodeUnit) : Option (Except Error (List CodeUnit)) :=
  (decodeWords r s).map (Except.map formatUuidString)

def encodeStringSpec (s : List CodeUnit) : Except Error (List CodeUnit) :=
  (Text.parse s).map fun w => (encode (w.val.uuid w.property)).map toCodeUnit

def decodeStringSpec (s : List CodeUnit) : Except Error (List CodeUnit) :=
  (decode (s.map specByte)).map fun v => Text.canonical (Words.ofNat v.val)

theorem encodeStringSafe_correct (r : Rounding) (s : List CodeUnit) :
    encodeStringSafe r s = some (encodeStringSpec s) := by
  rw [encodeStringSafe, parseUuidString_correct, encodeStringSpec]
  cases Text.parse s with
  | error e => rfl
  | ok w => simp [Except.map, encode_correct r w.val w.property]

theorem encodeStringSafe_accepts (r : Rounding) (s : List CodeUnit) :
    (encodeStringSafe r s).map Except.isOk = some (Text.wellFormed s) := by
  rw [encodeStringSafe_correct, ← Text.parse_accepts, encodeStringSpec]
  cases Text.parse s <;> rfl

theorem decodeStringSafe_correct (r : Rounding) (s : List CodeUnit) :
    decodeStringSafe r s = some (decodeStringSpec s) := by
  rw [decodeStringSafe, decode_correct, decodeStringSpec]
  cases decode (s.map specByte) <;> simp [wordsResult, Except.map, formatUuidString_correct]

def encodeString (r : Rounding) (s : List CodeUnit) := (encodeStringSafe r s).map throwOnError
def decodeString (r : Rounding) (s : List CodeUnit) := (decodeStringSafe r s).map throwOnError

theorem encodeString_correct (r : Rounding) (s : List CodeUnit) :
    encodeString r s = some (throwOnError (encodeStringSpec s)) := by
  rw [encodeString, encodeStringSafe_correct]; rfl

theorem decodeString_correct (r : Rounding) (s : List CodeUnit) :
    decodeString r s = some (throwOnError (decodeStringSpec s)) := by
  rw [decodeString, decodeStringSafe_correct]; rfl

/-- Both accepted spellings and every mixture of letter cases decode to the same canonical form. -/
theorem text_decode_encode (r : Rounding) (s : List CodeUnit) (w : Text.ValidWords)
    (ok : Text.parse s = .ok w) :
    ∃ b58, encodeStringSafe r s = some (.ok b58) ∧ decodeStringSafe r b58 = some (.ok (Text.canonical w.val)) := by
  refine ⟨(encode (w.val.uuid w.property)).map toCodeUnit, ?_, ?_⟩
  · rw [encodeStringSafe_correct, encodeStringSpec, ok]; rfl
  · rw [decodeStringSafe_correct, decodeStringSpec, specBytes_of_encoded_text, decode_encode]
    simp [Except.map, Words.ofNat_uuid]

theorem text_encode_decode (r : Rounding) (s uuid : List CodeUnit)
    (ok : decodeStringSafe r s = some (.ok uuid)) : encodeStringSafe r uuid = some (.ok s) := by
  rw [decodeStringSafe_correct, decodeStringSpec] at ok
  cases hv : decode (s.map specByte) with
  | error e => simp [hv, Except.map] at ok
  | ok v =>
    simp [hv, Except.map] at ok
    subst uuid
    rw [encodeStringSafe_correct, encodeStringSpec, Text.parse_canonical ⟨_, Words.valid_of_uuid v⟩]
    simp [Except.map, Words.uuid_ofNat, encoded_text_of_decode hv]

end Uuid58.Js
