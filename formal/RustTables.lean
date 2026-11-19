import Uuid58.Funs  -- generated from Rust by Charon and Aeneas
import Chunk

open Aeneas Aeneas.Std Aeneas.Std.WP Result
namespace RustUuid58

def toByte (b : Std.U8) : Uuid58.Byte := b.bv.toFin
def ofByte (b : Uuid58.Byte) : Std.U8 := ⟨⟨b⟩⟩
def ofDigit (d : Uuid58.Digit) : Std.U8 := ofByte (Uuid58.symbol d)
def natByte (n : Nat) : Std.U8 := ⟨BitVec.ofNat 8 n⟩

theorem alphabet_eq : ALPHABET_BYTES.val = Uuid58.alphabet.map ofByte := by
  unfold ALPHABET_BYTES
  rfl

private def fill : Nat → Nat → List Std.U8 → List Std.U8
  | 0, _, t => t
  | n+1, i, t => fill n (i+1) (t.set Uuid58.alphabet[i]!.val (natByte i))

private theorem fill_correct (n : Nat) (t : Array Std.U8 256#usize) (i : Std.Usize)
    (h : i.val + n = 58) :
    make_digit_table_loop ALPHABET_BYTES t i ⦃ r => r.val = fill n i.val t.val ⦄ := by
  induction n generalizing i t with
  | zero =>
    rw [make_digit_table_loop]
    have hi : ¬ i < 58#usize := by scalar_tac
    simp [hi, fill]
  | succ n ih =>
    rw [make_digit_table_loop]
    have hi : i < 58#usize := by scalar_tac
    simp only [ite_eq_left hi]
    step as ⟨b, hb⟩
    step with UScalar.cast_inBounds_spec as ⟨idx, hidx⟩
    step with UScalar.cast_inBounds_spec as ⟨d, hd⟩
    step as ⟨t', ht⟩
    step as ⟨j, hj⟩
    apply spec_mono (ih t' j (by scalar_tac))
    intro r hr
    subst b t'
    have hbound : i.val < Uuid58.alphabet.length := by
      have : Uuid58.alphabet.length = 58 := by decide
      omega
    have he : d = natByte i.val := by
      apply UScalar.val_eq_imp
      change d.val = i.val % 256
      omega
    simp only [fill, hr, he, Array.set_val_eq, hidx, hj]
    simp [alphabet_eq, hbound, ofByte]
    rfl

def digitTable := fill 58 0 (List.replicate 256 (natByte 255))

@[step] theorem table_correct : DIGITS ⦃ t => t.val = digitTable ⦄ := by
  unfold DIGITS make_digit_table
  apply spec_mono (fill_correct 58 (Array.repeat 256#usize INVALID) 0#usize (by scalar_tac))
  intro t h
  rw [h, Array.repeat_val]
  unfold digitTable
  congr 2
  unfold INVALID
  rfl

set_option maxRecDepth 8192 in
theorem lookup_correct : ∀ b : Uuid58.Byte, digitTable[b.val]! =
    match Uuid58.digit? b with
    | none => natByte 255
    | some d => natByte d.val := by decide

@[step] theorem widen64 (x : Std.U64) :
    lift (core.convert.num.FromU128U64.from x) ⦃ y => y.val = x.val ⦄ := by simp [lift]

@[step] theorem widen8 (x : Std.U8) :
    lift (core.convert.num.FromU64U8.from x) ⦃ y => y.val = x.val ⦄ := by simp [lift]

@[step] theorem byteIndex (x : Std.U8) :
    lift (core.convert.num.FromUsizeU8.from x) ⦃ y => y.val = x.val ⦄ := by simp [lift]

end RustUuid58
