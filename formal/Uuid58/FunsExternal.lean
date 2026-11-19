module
public import Uuid58.Types

@[expose] public section
open Aeneas Aeneas.Std Result

namespace core.str.converts

def pushByte (acc : ByteArray) (b : Std.U8) := acc.push (UInt8.ofNat b.val)

/-- Rust's checked conversion returns a view of the original bytes for valid UTF-8. -/
@[rust_fun "core::str::converts::from_utf8"]
def from_utf8 (s : Slice Std.U8) : Result (core.result.Result Str core.str.error.Utf8Error) :=
  if (s.val.foldl pushByte ByteArray.empty).validateUTF8 then ok (.Ok s) else ok (.Err ())

theorem from_utf8_ascii (s : Slice Std.U8) (ascii : ∀ b ∈ s.val, b.val < 128) :
    from_utf8 s = ok (.Ok s) := by
  have single : ∀ i : Fin 128, (Char.ofNat i.val).utf8Size = 1 ∧
      (Char.ofNat i.val).toUInt8 = UInt8.ofNat i.val := by decide
  have valid (bs : List Std.U8) (h : ∀ b ∈ bs, b.val < 128) (acc : ByteArray) (ha : acc.IsValidUTF8) :
      (bs.foldl pushByte acc).IsValidUTF8 := by
    induction bs generalizing acc with
    | nil => exact ha
    | cons b bs ih =>
      obtain ⟨size, repr⟩ := single ⟨b.val, h b (by simp)⟩
      apply ih (fun x hx => h _ (List.mem_cons_of_mem _ hx))
      have push := ha.push size
      rw [repr] at push
      exact push
  have okBytes := ByteArray.validateUTF8_eq_true_iff.mpr (valid s.val ascii ByteArray.empty (by decide))
  simp [from_utf8, okBytes]

end core.str.converts
