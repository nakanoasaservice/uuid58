import RustDecode
import UuidTextScan

open Aeneas Aeneas.Std Aeneas.Std.WP Result
namespace RustUuid58
open Uuid58.Js

private def unit (b : Std.U8) := toCodeUnit (toByte b)
private def word128 (n : Nat) : Std.U128 := ⟨BitVec.ofNat 128 n⟩

private theorem eq_ok_of_spec {α} {m : Result α} {x : α} (h : m ⦃ y => y = x ⦄) : m = ok x := by
  cases m <;> simp_all

private theorem hex_eq (b : Std.U8) :
    hex_value b = ok ((Text.digit? (unit b)).map fun d => natByte d.val) := by
  apply eq_ok_of_spec
  have byte_val (k : Nat) : (natByte k).val = k % 256 := rfl
  have hu : (unit b).val = b.val := rfl
  simp [hex_value, UScalar.le_equiv]
  repeat' first | split | (exfalso; omega)
  all_goals
    repeat' step
    simp only [Text.digit?, hu]
    repeat' first | split | (exfalso; omega)
    all_goals simp_all [UScalar.eq_equiv]
    all_goals omega

private theorem push_bits (n : Nat) (d : Text.Nibble) :
    (BitVec.ofNat 128 n <<< (4 : Nat)) ||| (BitVec.ofNat 8 d.val).setWidth 128 =
      BitVec.ofNat 128 (n * 16 + d.val) := by
  rw [BitVec.setWidth_ofNat_of_le_of_lt (by decide) (by have := d.isLt; omega),
    BitVec.shiftLeft_eq_mul_twoPow]
  change BitVec.ofNat 128 n * BitVec.ofNat 128 16 ||| BitVec.ofNat 128 d.val = _
  rw [← BitVec.ofNat_mul, ← BitVec.ofNat_or, Nat.mul_comm n 16,
    ← Nat.two_pow_add_eq_or_of_lt (i := 4) d.isLt n]

private abbrev Iter := core.iter.adapters.enumerate.Enumerate (core.slice.iter.Iter Std.U8)
open core.iter.adapters.enumerate core.iter.traits.iterator

private def index (i : Nat) (hi : i ≤ 36) : Std.Usize := Usize.ofNatCore i (by scalar_tac)
private def iterAt (s : Slice Std.U8) (i : Nat) (hi : i ≤ 36) : Iter := ⟨⟨s, i⟩, index i hi⟩

private theorem next_end (s : Slice Std.U8) (hi : s.val.length ≤ 36) :
    IteratorEnumerate.next (IteratorSliceIter Std.U8) (iterAt s s.val.length hi) = ok (none, iterAt s s.val.length hi) := by
  simp [iterAt, core.iter.adapters.enumerate.IteratorEnumerate.next,
    core.slice.iter.IteratorSliceIter.next]

private theorem next_byte (s : Slice Std.U8) (i : Nat) (h : i < s.val.length) (hi : i+1 ≤ 36) :
    IteratorEnumerate.next (IteratorSliceIter Std.U8) (iterAt s i (by omega)) =
      ok (some (index i (by omega), s.val[i]), iterAt s (i+1) hi) := by
  have add : index i (by omega) + 1#usize = ok (index (i+1) hi) := by
    apply eq_ok_of_spec
    have iv : (index i (by omega)).val = i := Usize.ofNatCore_val_eq _
    step as ⟨v, hv⟩
    apply UScalar.val_eq_imp
    simpa [index, iv] using hv
  simp [iterAt, core.iter.adapters.enumerate.IteratorEnumerate.next,
    core.slice.iter.IteratorSliceIter.next, h, add]

private theorem hyphens (i : Std.Usize) :
    core.slice.Slice.contains core.cmp.PartialEqUsize (Array.to_slice HYPHENS) i =
      ok (Text.marks.contains i.val) := by
  have layout : (Array.to_slice HYPHENS).val = [8#usize, 13#usize, 18#usize, 23#usize] := by
    unfold HYPHENS
    rfl
  simp only [core.slice.Slice.contains, layout, List.anyM,
    core.cmp.impls.PartialEqUsize.eq, liftFun2, bind_tc_ok, pure_tc_eq, UScalar.eq_equiv]
  simp [Text.marks]
  repeat' split <;> simp_all

/-- The digit branch shared by the two MIR loops. -/
private def readDigit (b : Std.U8) (value : Std.U128) (continueWith : Std.U128 → Result Decoded) :
    Result Decoded := do
  let digit ← hex_value b
  let result ← core.option.Option.ok_or digit Error.InvalidCharacter
  let flow ← core.result.Result.Insts.CoreOpsTry.branch result
  match flow with
  | .Continue d =>
    let shifted ← value <<< 4#i32
    let widened ← lift (core.convert.num.FromU128U8.from d)
    let value' ← lift (shifted ||| widened)
    continueWith value'
  | .Break residual =>
    core.result.Result.Insts.CoreOpsTry_traitFromResidualResult.from_residual
      Std.U128 (core.convert.FromSame Error) residual

private theorem readDigit_eq (b : Std.U8) (n : Nat) (k : Std.U128 → Result Decoded) :
    readDigit b (word128 n) k = match Text.digit? (unit b) with
      | none => ok (.Err .InvalidCharacter)
      | some d => k (word128 (n*16 + d.val)) := by
  have shift : word128 n <<< 4#i32 = ok (⟨BitVec.ofNat 128 n <<< (4 : Nat)⟩ : Std.U128) := rfl
  unfold readDigit
  rw [hex_eq]
  cases hd : Text.digit? (unit b) with
  | none => simp [core.option.Option.ok_or, core.result.Result.Insts.CoreOpsTry.branch,
      core.result.Result.Insts.CoreOpsTry_traitFromResidualResult.from_residual]
  | some d =>
    simp [core.option.Option.ok_or, core.result.Result.Insts.CoreOpsTry.branch, shift, lift]
    exact congrArg k (congrArg (fun v : BitVec 128 => (⟨v⟩ : Std.U128)) (push_bits n d))

private def loop (dashed : Bool) := if dashed then parse_uuid_str_loop1 else parse_uuid_str_loop0

private theorem loop_end (s : Slice Std.U8) (hi : s.val.length ≤ 36) (dashed : Bool) (n : Nat) :
    loop dashed (iterAt s s.val.length hi) (word128 n) = ok (.Ok (word128 n)) := by
  cases dashed
  · rw [loop, ite_eq_right (by decide), parse_uuid_str_loop0, next_end]
    simp
  · rw [loop, ite_eq_left rfl, parse_uuid_str_loop1, next_end]
    simp

-- Compare the extracted digit branches before unfolding the effect monad.
attribute [local irreducible] Std.bind in
private theorem loop_byte (s : Slice Std.U8) (i : Nat) (h : i < s.val.length)
    (hi : i+1 ≤ 36) (dashed : Bool) (n : Nat) :
    let b := s.val[i]
    let k := loop dashed (iterAt s (i+1) hi)
    loop dashed (iterAt s i (by omega)) (word128 n) =
      if Text.isMark dashed i then (if (unit b).val = 45 then k (word128 n) else ok (.Err .InvalidCharacter))
      else match Text.digit? (unit b) with
        | none => ok (.Err .InvalidCharacter)
        | some d => k (word128 (n*16 + d.val)) := by
  dsimp only
  cases dashed with
  | false =>
    rw [loop, ite_eq_right (by decide), parse_uuid_str_loop0, next_byte s i h hi]
    simp only [bind_ok]
    exact readDigit_eq s.val[i] n (parse_uuid_str_loop0 (iterAt s (i+1) hi))
  | true =>
    rw [loop, ite_eq_left rfl, parse_uuid_str_loop1, next_byte s i h hi]
    simp only [bind_ok]
    change (Std.bind (lift (Array.to_slice HYPHENS)) _) = _
    rw [show lift (Array.to_slice HYPHENS) = ok (Array.to_slice HYPHENS) by rfl, bind_ok,
      hyphens, bind_ok, show (index i (by omega)).val = i from Usize.ofNatCore_val_eq _]
    simp only [Text.isMark, Bool.true_and]
    cases Text.marks.contains i with
    | false =>
      exact readDigit_eq s.val[i] n (parse_uuid_str_loop1 (iterAt s (i+1) hi))
    | true =>
      have byteEq : s.val[i] = 45#u8 ↔ (unit s.val[i]).val = 45 := UScalar.eq_equiv _ _
      simp only [ite_true, bne_iff_ne, ← byteEq]
      by_cases hb : s.val[i] = 45#u8
      · rw [ite_eq_right (not_not_intro hb), ite_eq_left hb]
      · rw [ite_eq_left hb, ite_eq_right hb]

private def fromNat : Except Uuid58.Error Nat → Decoded
  | .ok n => .Ok (word128 n)
  | .error e => rustResult (.error e)

private def finish (value : Option Nat) := fromNat (Text.scanResult value)

/-- The slice cursor and the enumerate counter both represent i. Each digit appends
a nibble to the accumulator, while each required hyphen preserves its value. -/
private theorem loop_correct (s : Slice Std.U8) (small : s.val.length ≤ 36) (dashed : Bool)
    (remaining i n : Nat) (len : i + remaining = s.val.length) :
    loop dashed (iterAt s i (by omega)) (word128 n) =
      ok (finish (Text.scan (s.val.map unit) dashed (List.range' i remaining) (some n))) := by
  induction remaining generalizing i n with
  | zero =>
    simp only [Nat.add_zero] at len
    subst i
    rw [loop_end]
    rfl
  | succ remaining ih =>
    have h : i < s.val.length := by omega
    have get : (s.val.map unit)[i]! = unit s.val[i] := by
      rw [getElem!_pos _ _ (by simpa using h), List.getElem_map]
    rw [loop_byte s i h (by omega), List.range'_succ, Text.scan_cons, get]
    have rest := ih (i+1) (len := by omega)
    cases Text.isMark dashed i with
    | true =>
      by_cases hyphen : (unit s.val[i]).val = 45
      · simpa only [ite_true, hyphen] using rest n
      · simp [hyphen, finish, Text.scanResult, fromNat, rustResult]
    | false =>
      cases hd : Text.digit? (unit s.val[i]) with
      | none => simp [Text.step, hd, Text.scan_none, finish, Text.scanResult, fromNat, rustResult]
      | some d => simpa [Text.step, hd] using rest (n*16+d.val)

private theorem word_uuid (v : Uuid58.UUID) : word128 v.val = (⟨⟨v⟩⟩ : Std.U128) := by
  apply congrArg (fun b : BitVec 128 => (⟨b⟩ : Std.U128))
  change BitVec.ofNat 128 (⟨v⟩ : BitVec 128).toNat = (⟨v⟩ : BitVec 128)
  simpa only [BitVec.setWidth_eq] using BitVec.ofNat_toNat 128 (⟨v⟩ : BitVec 128)

private theorem pack_words (result : Except Uuid58.Error Text.ValidWords) :
    fromNat (result.map fun w => w.val.value) = rustResult (result.map fun w => w.val.uuid w.property) := by
  cases result with
  | error e => rfl
  | ok w => exact congrArg core.result.Result.Ok (word_uuid (w.val.uuid w.property))

private theorem finish_spec (text : List CodeUnit) (dashed : Bool)
    (len : text.length = if dashed then 36 else 32) :
    finish (Text.scan text dashed (List.range' 0 text.length) (some 0)) =
      rustResult ((Text.parse text).map fun w => w.val.uuid w.property) :=
  (congrArg fromNat (Text.scan_spec text dashed len)).trans (pack_words (Text.parse text))

private theorem full_scan (s : Slice Std.U8) (dashed : Bool)
    (len : s.val.length = if dashed then 36 else 32) :
    loop dashed (iterAt s 0 (by decide)) 0#u128 =
      ok (rustResult (Uuid58.parseUuidBytes (s.val.map toByte))) := by
  have small : s.val.length ≤ 36 := by rw [len]; cases dashed <;> decide
  apply (loop_correct s small dashed s.val.length 0 0 (by omega)).trans
  apply congrArg ok
  have units : (s.val.map toByte).map toCodeUnit = s.val.map unit := by rw [List.map_map]; rfl
  unfold Uuid58.parseUuidBytes
  rw [units]
  simpa only [List.length_map] using finish_spec (s.val.map unit) dashed (by simpa using len)

/-- The public parser returns the exact specified UUID or first error on every byte slice,
including non-ASCII bytes, once the caller's AsRef implementation supplies the slice. -/
theorem parse_uuid_str_correct {α : Type} (asRef : core.convert.AsRef α (Slice Std.U8))
    (x : α) (s : Slice Std.U8) (view : asRef.as_ref x ⦃ t => t = s ⦄) :
    parse_uuid_str asRef x ⦃ r => r = rustResult (Uuid58.parseUuidBytes (s.val.map toByte)) ⦄ := by
  unfold parse_uuid_str
  apply spec_bind view
  intro t ht
  subst t
  simp only [Slice.len_val, Slice.length]
  have run (dashed : Bool) (len : s.val.length = if dashed then 36 else 32) :
      (do let it ← core.slice.Slice.iter s
          let en ← Iterator.enumerate.trait_default (IteratorSliceIter Std.U8) it
          loop dashed en 0#u128) ⦃ r => r = rustResult (Uuid58.parseUuidBytes (s.val.map toByte)) ⦄ := by
    simp only [core.slice.Slice.iter, Iterator.enumerate.trait_default, Iterator.enumerate.default, bind_ok]
    change loop dashed (iterAt s 0 (by decide)) 0#u128 ⦃ _ ⦄
    rw [full_scan s dashed len]
    simp
  split
  · exact run false (by assumption)
  · exact run true (by assumption)
  · rename_i _ notPlain notDashed
    have wrong : Text.form 32 36 ((s.val.map toByte).map toCodeUnit).length = none := by
      simp only [Text.form, List.length_map, ite_eq_right notPlain, ite_eq_right notDashed]
    simp only [spec_ok, Uuid58.parseUuidBytes, Text.parse, wrong]
    rfl

/-- Successful Rust results are exactly the plain and hyphenated spellings of section 5.1. -/
theorem parse_uuid_str_accepts {α : Type} (asRef : core.convert.AsRef α (Slice Std.U8))
    (x : α) (s : Slice Std.U8) (view : asRef.as_ref x ⦃ t => t = s ⦄) :
    (do let r ← parse_uuid_str asRef x; core.result.Result.is_ok r)
      ⦃ valid => valid = Text.wellFormed ((s.val.map toByte).map toCodeUnit) ⦄ := by
  apply spec_bind (parse_uuid_str_correct asRef x s view)
  rintro _ rfl
  rw [← Text.parse_accepts]
  unfold Uuid58.parseUuidBytes
  cases Text.parse ((s.val.map toByte).map toCodeUnit) with
  | ok w => simp [Except.map, rustResult, core.result.Result.is_ok, Except.isOk, Except.toBool]
  | error e => cases e <;> simp [Except.map, rustResult, core.result.Result.is_ok, Except.isOk, Except.toBool]

end RustUuid58
