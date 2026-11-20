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

def natWord (n : Nat) : Std.U32 := ⟨BitVec.ofNat 32 n⟩

/-- Marks a byte outside the alphabet in the digit table. -/
def invalid : Nat := 2^31

private def fill : Nat → Nat → List Std.U32 → List Std.U32
  | 0, _, t => t
  | n+1, i, t => fill n (i+1) (t.set Uuid58.alphabet[i]!.val (natWord i))

private theorem fill_correct (n : Nat) (t : Array Std.U32 256#usize) (i : Std.Usize)
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
    have he : d = natWord i.val := by
      apply UScalar.val_eq_imp
      change d.val = i.val % 2^32
      omega
    simp only [fill, hr, he, Array.set_val_eq, hidx, hj]
    simp [alphabet_eq, hbound, ofByte]
    rfl

def digitTable := fill 58 0 (List.replicate 256 (natWord invalid))

theorem invalid_marker : INVALID = ok (natWord invalid) := by unfold INVALID; rfl

@[step] theorem table_correct : DIGITS ⦃ t => t.val = digitTable ⦄ := by
  unfold DIGITS make_digit_table
  rw [invalid_marker, bind_ok]
  apply spec_mono (fill_correct 58 (Array.repeat 256#usize (natWord invalid)) 0#usize (by scalar_tac))
  intro t h
  rw [h, Array.repeat_val]
  rfl

set_option maxRecDepth 8192 in
theorem lookup_correct : ∀ b : Uuid58.Byte, digitTable[b.val]! =
    match Uuid58.digit? b with
    | none => natWord invalid
    | some d => natWord d.val := by decide

private def fillSymbols : Nat → Nat → List Std.U8 → List Std.U8
  | 0, _, t => t
  | n+1, i, t => fillSymbols n (i+1) (t.set i (ofByte Uuid58.alphabet[i]!))

private theorem fillSymbols_correct (n : Nat) (t : Array Std.U8 64#usize) (i : Std.Usize)
    (h : i.val + n = 58) :
    make_symbol_table_loop ALPHABET_BYTES t i ⦃ r => r.val = fillSymbols n i.val t.val ⦄ := by
  induction n generalizing i t with
  | zero =>
    rw [make_symbol_table_loop]
    have hi : ¬ i < 58#usize := by scalar_tac
    simp [hi, fillSymbols]
  | succ n ih =>
    rw [make_symbol_table_loop]
    have hi : i < 58#usize := by scalar_tac
    simp only [ite_eq_left hi]
    step as ⟨b, hb⟩
    step as ⟨t', ht⟩
    step as ⟨j, hj⟩
    apply spec_mono (ih t' j (by scalar_tac))
    intro r hr
    subst b t'
    have hbound : i.val < Uuid58.alphabet.length := by
      have : Uuid58.alphabet.length = 58 := by decide
      omega
    simp only [fillSymbols, hr, Array.set_val_eq, hj]
    simp [alphabet_eq, hbound]

/-- The alphabet, padded to 64 entries with its first character. -/
def symbolTable := fillSymbols 58 0 (List.replicate 64 (ofByte Uuid58.alphabet[0]!))

@[step] theorem symbols_correct : SYMBOLS ⦃ t => t.val = symbolTable ⦄ := by
  unfold SYMBOLS make_symbol_table
  step as ⟨first, hfirst⟩
  apply spec_mono (fillSymbols_correct 58 (Array.repeat 64#usize first) 0#usize (by scalar_tac))
  intro t h
  rw [h, Array.repeat_val]
  subst first
  simp [symbolTable, alphabet_eq]
  rfl

theorem symbol_lookup : ∀ d : Uuid58.Digit, symbolTable[d.val]! = ofDigit d := by decide

@[step] theorem chunk_odd_correct : CHUNK_ODD ⦃ c => c.val = 29^10 ⦄ := by
  unfold CHUNK_ODD CHUNK
  rw [show (430804206899405824#u64 >>> 10#i32) = ok 420707233300201#u64 by rfl]
  simp

@[step] theorem half_lead_reciprocal_correct : HALF_LEAD_RECIPROCAL ⦃ r => r.val = 2^58 / 58^4 + 1 ⦄ := by
  unfold HALF_LEAD_RECIPROCAL FRACTION_BITS HALF_LEAD
  rw [show (1#u64 <<< 58#u32) = ok 288230376151711744#u64 by rfl]
  simp only [bind_ok]
  step as ⟨q, hq⟩
  step as ⟨r, hr⟩
  simp [hr, hq]

@[step] theorem widen64 (x : Std.U64) :
    lift (core.convert.num.FromU128U64.from x) ⦃ y => y.val = x.val ⦄ := by simp [lift]

@[step] theorem widen32 (x : Std.U32) :
    lift (core.convert.num.FromU64U32.from x) ⦃ y => y.val = x.val ⦄ := by simp [lift]

@[step] theorem widen16 (x : Std.U16) :
    lift (core.convert.num.FromU64U16.from x) ⦃ y => y.val = x.val ⦄ := by simp [lift]

@[step] theorem byteIndex (x : Std.U8) :
    lift (core.convert.num.FromUsizeU8.from x) ⦃ y => y.val = x.val ⦄ := by simp [lift]

end RustUuid58
