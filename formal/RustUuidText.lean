import RustDecode
import UuidTextScan

open Aeneas Aeneas.Std Aeneas.Std.WP Result
namespace RustUuid58
open Uuid58.Js

def unit (b : Std.U8) := toCodeUnit (toByte b)
private def word128 (n : Nat) : Std.U128 := ⟨BitVec.ofNat 128 n⟩
def natShort (n : Nat) : Std.U16 := ⟨BitVec.ofNat 16 n⟩

private theorem word128_self (x : Std.U128) : word128 x.val = x := by
  apply UScalar.val_eq_imp
  exact Nat.mod_eq_of_lt (by scalar_tac)

private theorem eq_ok_of_spec {α} {m : Result α} {x : α} (h : m ⦃ y => y = x ⦄) : m = ok x := by
  cases m <;> simp_all

open core.iter.adapters.enumerate core.iter.traits.iterator

namespace TextIter

abbrev Iter := core.iter.adapters.enumerate.Enumerate (core.slice.iter.Iter Std.U8)

def index (i : Nat) (hi : i ≤ 36) : Std.Usize := Usize.ofNatCore i (by scalar_tac)
def iterAt (s : Slice Std.U8) (i : Nat) (hi : i ≤ 36) : Iter := ⟨⟨s, i⟩, index i hi⟩

theorem next_end (s : Slice Std.U8) (hi : s.val.length ≤ 36) :
    IteratorEnumerate.next (IteratorSliceIter Std.U8) (iterAt s s.val.length hi) = ok (none, iterAt s s.val.length hi) := by
  simp [iterAt, core.iter.adapters.enumerate.IteratorEnumerate.next,
    core.slice.iter.IteratorSliceIter.next]

theorem next_byte (s : Slice Std.U8) (i : Nat) (h : i < s.val.length) (hi : i+1 ≤ 36) :
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

end TextIter


/-- The table entry of a byte: the value of that hexadecimal digit, or the marker for any
other byte. -/
def hexValue (u : CodeUnit) : Nat :=
  match Text.digit? u with
  | none => 256
  | some d => d.val

def lowerHex : List Nat := [48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 97, 98, 99, 100, 101, 102]
private def upperHex : List Nat := [48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 65, 66, 67, 68, 69, 70]

theorem lower_eq : LOWER_HEX.val = lowerHex.map natByte := by
  unfold LOWER_HEX
  rfl

private theorem upper_eq : UPPER_HEX.val = upperHex.map natByte := by
  unfold UPPER_HEX
  rfl

private def fillHex : Nat → Nat → List Std.U16 → List Std.U16
  | 0, _, t => t
  | n+1, i, t => fillHex n (i+1)
      ((t.set (natByte lowerHex[i]!).val (natShort i)).set (natByte upperHex[i]!).val (natShort i))

private theorem fillHex_correct (n : Nat) (t : Array Std.U16 256#usize) (i : Std.Usize)
    (h : i.val + n = 16) :
    make_hex_values_loop LOWER_HEX UPPER_HEX t i ⦃ r => r.val = fillHex n i.val t.val ⦄ := by
  induction n generalizing i t with
  | zero =>
    rw [make_hex_values_loop]
    have hi : ¬ i < 16#usize := by scalar_tac
    simp [hi, fillHex]
  | succ n ih =>
    rw [make_hex_values_loop]
    have hi : i < 16#usize := by scalar_tac
    simp only [ite_eq_left hi]
    step as ⟨b, hb⟩
    step with UScalar.cast_inBounds_spec as ⟨idx, hidx⟩
    step with UScalar.cast_inBounds_spec as ⟨d, hd⟩
    step as ⟨t', ht⟩
    step as ⟨b', hb'⟩
    step with UScalar.cast_inBounds_spec as ⟨idx', hidx'⟩
    step with UScalar.cast_inBounds_spec as ⟨d', hd'⟩
    step as ⟨t'', ht'⟩
    step as ⟨j, hj⟩
    apply spec_mono (ih t'' j (by scalar_tac))
    intro r hr
    subst b t' b' t''
    have inLower : i.val < lowerHex.length := by
      have : lowerHex.length = 16 := by decide
      omega
    have inUpper : i.val < upperHex.length := by
      have : upperHex.length = 16 := by decide
      omega
    have he : d = natShort i.val := by
      apply UScalar.val_eq_imp
      change d.val = i.val % 2^16
      omega
    have he' : d' = natShort i.val := by
      apply UScalar.val_eq_imp
      change d'.val = i.val % 2^16
      omega
    simp only [fillHex, hr, he, he', Array.set_val_eq, hidx, hidx', hj]
    simp [lower_eq, upper_eq, inLower, inUpper]

def hexTable := fillHex 16 0 (List.replicate 256 (natShort 256))

@[step] theorem hex_values_correct : HEX_VALUES ⦃ t => t.val = hexTable ⦄ := by
  unfold HEX_VALUES make_hex_values NOT_HEX
  apply spec_mono (fillHex_correct 16 (Array.repeat 256#usize 256#u16) 0#usize (by scalar_tac))
  intro t h
  rw [h, Array.repeat_val]
  rfl

set_option maxRecDepth 8192 in
theorem hex_lookup : ∀ b : Uuid58.Byte, hexTable[b.val]! = natShort (hexValue (toCodeUnit b)) := by
  decide

/-- Two digits make a byte. A byte that is not a digit lifts the sum to the marker or above. -/
def pairValue (p : CodeUnit × CodeUnit) : Nat := hexValue p.1 * 16 + hexValue p.2

private theorem step_pair (acc : Option Nat) (u v : CodeUnit) :
    Text.step (Text.step acc u) v =
      if pairValue (u, v) < 256 then acc.map (fun n => n * 256 + pairValue (u, v)) else none := by
  unfold pairValue hexValue
  cases acc <;> cases hu : Text.digit? u <;> cases hv : Text.digit? v <;>
    simp [Text.step, hu, hv] <;> omega

/-- Reading digits one at a time is reading them two at a time. -/
theorem fold_pairs (ps : List (CodeUnit × CodeUnit)) (acc : Option Nat) :
    (ps.flatMap fun p => [p.1, p.2]).foldl Text.step acc =
      if ps.all (fun p => pairValue p < 256) then
        acc.map (fun n => ps.foldl (fun a p => a * 256 + pairValue p) n)
      else none := by
  induction ps generalizing acc with
  | nil => simp
  | cons p ps ih =>
    simp only [List.flatMap_cons, List.cons_append, List.nil_append, List.foldl_cons, step_pair, ih,
      List.all_cons, Bool.and_eq_true, decide_eq_true_eq]
    by_cases hp : pairValue p < 256 <;> by_cases hs : (ps.all fun p => decide (pairValue p < 256)) = true <;>
      cases acc <;> simp [hp, hs]

private theorem hexValue_le (u : CodeUnit) : hexValue u ≤ 256 := by
  unfold hexValue
  split <;> omega

private theorem hexTable_val (b : Std.U8) : (hexTable[b.val]!).val = hexValue (unit b) := by
  have entry := hex_lookup (toByte b)
  change hexTable[b.val]! = natShort (hexValue (unit b)) at entry
  rw [entry]
  change hexValue (unit b) % 2^16 = _
  exact Nat.mod_eq_of_lt (Nat.lt_of_le_of_lt (hexValue_le _) (by decide))

theorem unit_get (s : List Std.U8) (i : Nat) : (s.map unit)[i]! = unit s[i]! := by
  simp only [List.getElem!_eq_getElem?_getD, List.getElem?_map]
  cases s[i]? <;> rfl

def pairAt (x : Nat → CodeUnit) (p : Nat) : CodeUnit × CodeUnit := (x p, x (p+1))

@[step] private theorem hex_byte_correct (input : Slice Std.U8) (pos : Std.Usize)
    (h : pos.val + 1 < input.val.length) :
    hex_byte input pos ⦃ r => r.val = pairValue (pairAt (fun i => unit input.val[i]!) pos.val) ⦄ := by
  unfold hex_byte
  step as ⟨table, htable⟩
  step as ⟨b0, hb0⟩
  step as ⟨i0, hi0⟩
  step as ⟨v0, hv0⟩
  step as ⟨w0, hw0⟩
  have e0 : w0.val = hexValue (unit input.val[pos.val]!) := by
    rw [hw0, hv0, ← getElem!_pos table.val i0.val (by scalar_tac), htable, hi0, hexTable_val,
      getElem!_pos input.val pos.val (by omega), hb0]
  have small0 := hexValue_le (unit input.val[pos.val]!)
  step as ⟨scaled, hscaled⟩
  step as ⟨next, hnext⟩
  step as ⟨b1, hb1⟩
  step as ⟨i1, hi1⟩
  step as ⟨v1, hv1⟩
  step as ⟨w1, hw1⟩
  have e1 : w1.val = hexValue (unit input.val[pos.val + 1]!) := by
    rw [hw1, hv1, ← getElem!_pos table.val i1.val (by scalar_tac), htable, hi1, hexTable_val,
      getElem!_pos input.val (pos.val + 1) (by omega), hb1]
    simp only [hnext]
  have small1 := hexValue_le (unit input.val[pos.val + 1]!)
  step as ⟨r, hr⟩
  simp only [pairValue, pairAt]
  omega

private def fromNat : Except Uuid58.Error Nat → Decoded
  | .ok n => .Ok (word128 n)
  | .error e => rustResult (.error e)

private def finish (value : Option Nat) := fromNat (Text.scanResult value)

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


/-- The 16 bytes of a UUID as pairs of digits, in groups of 4, 2, 2, 2 and 6 bytes. -/
def groupPairs (x : Nat → CodeUnit) (a b c d e : Nat) : List (CodeUnit × CodeUnit) :=
  [pairAt x a, pairAt x (a+2), pairAt x (a+4), pairAt x (a+6), pairAt x b, pairAt x (b+2),
    pairAt x c, pairAt x (c+2), pairAt x d, pairAt x (d+2), pairAt x e, pairAt x (e+2),
    pairAt x (e+4), pairAt x (e+6), pairAt x (e+8), pairAt x (e+10)]

/-- What two-at-a-time reading returns: the bytes in base 256, unless one is not a byte. -/
def pairsResult (ps : List (CodeUnit × CodeUnit)) : Option Nat :=
  if ps.all (fun p => pairValue p < 256) then some (ps.foldl (fun a p => a * 256 + pairValue p) 0)
  else none

set_option maxHeartbeats 1000000 in
/-- One comparison of the OR of the 16 bytes decides whether all 32 characters are digits. -/
private theorem parse_groups_correct (input : Slice Std.U8) (a b c d e : Std.Usize)
    (ha : a.val + 8 ≤ input.val.length) (hb : b.val + 4 ≤ input.val.length)
    (hc : c.val + 4 ≤ input.val.length) (hd : d.val + 4 ≤ input.val.length)
    (he : e.val + 12 ≤ input.val.length) :
    parse_groups input a b c d e ⦃ r => r = finish (pairsResult
      (groupPairs (fun i => unit input.val[i]!) a.val b.val c.val d.val e.val)) ⦄ := by
  unfold parse_groups NOT_HEX
  have size128 : U128.size = 2^128 := by scalar_tac
  step as ⟨b0, h0⟩
  step as ⟨q1, hq1⟩
  step as ⟨b1, h1⟩
  step as ⟨q2, hq2⟩
  step as ⟨b2, h2⟩
  step as ⟨q3, hq3⟩
  step as ⟨b3, h3⟩
  step as ⟨b4, h4⟩
  step as ⟨q5, hq5⟩
  step as ⟨b5, h5⟩
  step as ⟨b6, h6⟩
  step as ⟨q7, hq7⟩
  step as ⟨b7, h7⟩
  step as ⟨b8, h8⟩
  step as ⟨q9, hq9⟩
  step as ⟨b9, h9⟩
  step as ⟨b10, h10⟩
  step as ⟨q11, hq11⟩
  step as ⟨b11, h11⟩
  step as ⟨q12, hq12⟩
  step as ⟨b12, h12⟩
  step as ⟨q13, hq13⟩
  step as ⟨b13, h13⟩
  step as ⟨q14, hq14⟩
  step as ⟨b14, h14⟩
  step as ⟨q15, hq15⟩
  step as ⟨b15, h15⟩
  rw [hq1] at h1
  rw [hq2] at h2
  rw [hq3] at h3
  rw [hq5] at h5
  rw [hq7] at h7
  rw [hq9] at h9
  rw [hq11] at h11
  rw [hq12] at h12
  rw [hq13] at h13
  rw [hq14] at h14
  rw [hq15] at h15
  simp only [pairsResult, groupPairs, List.all_cons, List.all_nil, List.foldl_cons, List.foldl_nil,
    ← h0, ← h1, ← h2, ← h3, ← h4, ← h5, ← h6, ← h7, ← h8, ← h9, ← h10, ← h11, ← h12, ← h13, ← h14,
    ← h15]
  clear h0 h1 h2 h3 h4 h5 h6 h7 h8 h9 h10 h11 h12 h13 h14 h15
  step as ⟨o1, ho1⟩
  step as ⟨o2, ho2⟩
  step as ⟨o3, ho3⟩
  step as ⟨o4, ho4⟩
  step as ⟨o5, ho5⟩
  step as ⟨o6, ho6⟩
  step as ⟨o7, ho7⟩
  step as ⟨o8, ho8⟩
  step as ⟨o9, ho9⟩
  step as ⟨o10, ho10⟩
  step as ⟨o11, ho11⟩
  step as ⟨o12, ho12⟩
  step as ⟨o13, ho13⟩
  step as ⟨o14, ho14⟩
  step as ⟨seen, hseen⟩
  step as ⟨limit, hlimit⟩
  have limitVal : limit.val = 2^8 := hlimit
  have bounded : seen.val < 2^8 ↔ (((((((((((((((b0.val < 2^8 ∧ b1.val < 2^8) ∧ b2.val < 2^8) ∧
      b3.val < 2^8) ∧ b4.val < 2^8) ∧ b5.val < 2^8) ∧ b6.val < 2^8) ∧ b7.val < 2^8) ∧
      b8.val < 2^8) ∧ b9.val < 2^8) ∧ b10.val < 2^8) ∧ b11.val < 2^8) ∧ b12.val < 2^8) ∧
      b13.val < 2^8) ∧ b14.val < 2^8) ∧ b15.val < 2^8) := by
    rw [hseen, UScalar.val_or, ho14, UScalar.val_or, ho13, UScalar.val_or, ho12, UScalar.val_or,
      ho11, UScalar.val_or, ho10, UScalar.val_or, ho9, UScalar.val_or, ho8, UScalar.val_or, ho7,
      UScalar.val_or, ho6, UScalar.val_or, ho5, UScalar.val_or, ho4, UScalar.val_or, ho3,
      UScalar.val_or, ho2, UScalar.val_or, ho1, UScalar.val_or]
    simp only [or_lt_two_pow_iff]
  clear ho1 ho2 ho3 ho4 ho5 ho6 ho7 ho8 ho9 ho10 ho11 ho12 ho13 ho14 hseen
  by_cases valid : seen.val < 2^8
  · have below : ¬ seen ≥ limit := by scalar_tac
    rw [ite_eq_right below]
    obtain ⟨⟨⟨⟨⟨⟨⟨⟨⟨⟨⟨⟨⟨⟨⟨v0, v1⟩, v2⟩, v3⟩, v4⟩, v5⟩, v6⟩, v7⟩, v8⟩, v9⟩, v10⟩, v11⟩, v12⟩, v13⟩,
      v14⟩, v15⟩ := bounded.mp valid
    have all : (decide (b0.val < 256) && (decide (b1.val < 256) && (decide (b2.val < 256) &&
        (decide (b3.val < 256) && (decide (b4.val < 256) && (decide (b5.val < 256) &&
        (decide (b6.val < 256) && (decide (b7.val < 256) && (decide (b8.val < 256) &&
        (decide (b9.val < 256) && (decide (b10.val < 256) && (decide (b11.val < 256) &&
        (decide (b12.val < 256) && (decide (b13.val < 256) && (decide (b14.val < 256) &&
        (decide (b15.val < 256) && true)))))))))))))))) = true := by
      simp only [Bool.and_eq_true, decide_eq_true_eq, and_true]
      omega
    rw [ite_eq_left all]
    step as ⟨m0, hm0⟩
    step as ⟨a1, ha1⟩
    step as ⟨m1, hm1⟩
    step as ⟨a2, ha2⟩
    step as ⟨m2, hm2⟩
    step as ⟨a3, ha3⟩
    step as ⟨m3, hm3⟩
    step as ⟨a4, ha4⟩
    step as ⟨m4, hm4⟩
    step as ⟨a5, ha5⟩
    step as ⟨m5, hm5⟩
    step as ⟨a6, ha6⟩
    step as ⟨m6, hm6⟩
    step as ⟨high, hhigh⟩
    step as ⟨n0, hn0⟩
    step as ⟨c1, hc1⟩
    step as ⟨n1, hn1⟩
    step as ⟨c2, hc2⟩
    step as ⟨n2, hn2⟩
    step as ⟨c3, hc3⟩
    step as ⟨n3, hn3⟩
    step as ⟨c4, hc4⟩
    step as ⟨n4, hn4⟩
    step as ⟨c5, hc5⟩
    step as ⟨n5, hn5⟩
    step as ⟨c6, hc6⟩
    step as ⟨n6, hn6⟩
    step as ⟨low, hlow⟩
    step as ⟨wide, hwide⟩
    step as ⟨shifted, hshifted⟩
    step as ⟨wideLow, hwideLow⟩
    step as ⟨joined, hjoined⟩
    have highSmall : high.val < 2^64 := by scalar_tac
    have lowSmall : low.val < 2^64 := by scalar_tac
    have value : joined.val = high.val * 2^64 + low.val := by
      rw [hjoined, UScalar.val_or, hshifted, hwide, hwideLow, Nat.shiftLeft_eq, size128,
        Nat.mod_eq_of_lt (by omega), Nat.mul_comm]
      exact (Nat.two_pow_add_eq_or_of_lt lowSmall high.val).symm
    rw [← word128_self joined, value]
    simp only [finish, fromNat, Text.scanResult]
    refine congrArg (fun n : Nat => (core.result.Result.Ok (word128 n) : Decoded)) ?_
    omega
  · have above : seen ≥ limit := by scalar_tac
    have some : ¬ ((decide (b0.val < 256) && (decide (b1.val < 256) && (decide (b2.val < 256) &&
        (decide (b3.val < 256) && (decide (b4.val < 256) && (decide (b5.val < 256) &&
        (decide (b6.val < 256) && (decide (b7.val < 256) && (decide (b8.val < 256) &&
        (decide (b9.val < 256) && (decide (b10.val < 256) && (decide (b11.val < 256) &&
        (decide (b12.val < 256) && (decide (b13.val < 256) && (decide (b14.val < 256) &&
        (decide (b15.val < 256) && true)))))))))))))))) = true) := by
      simp only [Bool.and_eq_true, decide_eq_true_eq, and_true]
      intro h
      exact valid (bounded.mpr (by omega))
    rw [ite_eq_left above, ite_eq_right some]
    simp [finish, fromNat, Text.scanResult, rustResult]

private theorem pairsResult_eq (ps : List (CodeUnit × CodeUnit)) :
    pairsResult ps = (ps.flatMap fun p => [p.1, p.2]).foldl Text.step (some 0) := by
  rw [fold_pairs]
  rfl

/-- The plain form has no separators: its 32 digits are the 16 pairs in order. -/
private theorem plain_scan (s : List Std.U8) :
    Text.scan (s.map unit) false (List.range' 0 32) (some 0) =
      pairsResult (groupPairs (fun i => unit s[i]!) 0 8 12 16 20) := by
  have separators : (List.range' 0 32).filter (Text.isMark false) = [] := by decide
  have digits : (List.range' 0 32).filter (fun i => !Text.isMark false i) =
      [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25,
        26, 27, 28, 29, 30, 31] := by decide
  rw [pairsResult_eq, Text.scan, separators, digits]
  simp only [List.all_nil, ite_true, unit_get, List.map_cons, List.map_nil]
  rfl

/-- The hyphenated form has four separators, and the same 16 pairs between them. -/
private theorem dashed_scan (s : List Std.U8) :
    Text.scan (s.map unit) true (List.range' 0 36) (some 0) =
      if (unit s[8]!).val = 45 ∧ (unit s[13]!).val = 45 ∧ (unit s[18]!).val = 45 ∧
          (unit s[23]!).val = 45 then
        pairsResult (groupPairs (fun i => unit s[i]!) 0 9 14 19 24)
      else none := by
  have separators : (List.range' 0 36).filter (Text.isMark true) = [8, 13, 18, 23] := by decide
  have digits : (List.range' 0 36).filter (fun i => !Text.isMark true i) =
      [0, 1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 14, 15, 16, 17, 19, 20, 21, 22, 24, 25, 26, 27, 28, 29,
        30, 31, 32, 33, 34, 35] := by decide
  rw [pairsResult_eq, Text.scan, separators, digits]
  simp only [List.all_cons, List.all_nil, Bool.and_true, Bool.and_eq_true, beq_iff_eq, unit_get,
    List.map_cons, List.map_nil]
  rfl

/-- For every byte slice the parser returns the specified UUID or the specified first error. -/
theorem parse_uuid_bytes_correct (s : Slice Std.U8) :
    parse_uuid_bytes s ⦃ r => r = rustResult (Uuid58.parseUuidBytes (s.val.map toByte)) ⦄ := by
  have units : (s.val.map toByte).map toCodeUnit = s.val.map unit := by rw [List.map_map]; rfl
  unfold parse_uuid_bytes
  simp only [Slice.len_val, Slice.length]
  split
  · rename_i len
    have groups := parse_groups_correct s 0#usize 8#usize 12#usize 16#usize 20#usize
      (by scalar_tac) (by scalar_tac) (by scalar_tac) (by scalar_tac) (by scalar_tac)
    simp only [UScalar.ofNatCore_val_eq] at groups
    apply spec_mono groups
    intro r hr
    have spec := finish_spec (s.val.map unit) false (by simpa using len)
    simp only [List.length_map, len] at spec
    rw [hr, Uuid58.parseUuidBytes, units, ← spec, plain_scan]
  · rename_i len
    have spec := finish_spec (s.val.map unit) true (by simpa using len)
    simp only [List.length_map, len] at spec
    rw [Uuid58.parseUuidBytes, units, ← spec, dashed_scan]
    have hyphen (i : Nat) (h : i < s.val.length) :
        (s.val[i] != 45#u8) = true ↔ ¬ (unit s.val[i]!).val = 45 := by
      rw [getElem!_pos s.val i h, bne_iff_ne, ne_eq, UScalar.eq_equiv]
      rfl
    step as ⟨c8, h8⟩
    rw [h8]
    by_cases m8 : (unit s.val[8]!).val = 45
    swap
    · rw [ite_eq_left ((hyphen 8 (by omega)).mpr m8), ite_eq_right fun h => m8 h.1]
      simp [finish, fromNat, Text.scanResult, rustResult]
    rw [ite_eq_right fun h => (hyphen 8 (by omega)).mp h m8]
    step as ⟨c13, h13⟩
    rw [h13]
    by_cases m13 : (unit s.val[13]!).val = 45
    swap
    · rw [ite_eq_left ((hyphen 13 (by omega)).mpr m13), ite_eq_right fun h => m13 h.2.1]
      simp [finish, fromNat, Text.scanResult, rustResult]
    rw [ite_eq_right fun h => (hyphen 13 (by omega)).mp h m13]
    step as ⟨c18, h18⟩
    rw [h18]
    by_cases m18 : (unit s.val[18]!).val = 45
    swap
    · rw [ite_eq_left ((hyphen 18 (by omega)).mpr m18), ite_eq_right fun h => m18 h.2.2.1]
      simp [finish, fromNat, Text.scanResult, rustResult]
    rw [ite_eq_right fun h => (hyphen 18 (by omega)).mp h m18]
    step as ⟨c23, h23⟩
    rw [h23]
    by_cases m23 : (unit s.val[23]!).val = 45
    swap
    · rw [ite_eq_left ((hyphen 23 (by omega)).mpr m23), ite_eq_right fun h => m23 h.2.2.2]
      simp [finish, fromNat, Text.scanResult, rustResult]
    rw [ite_eq_right fun h => (hyphen 23 (by omega)).mp h m23]
    have groups := parse_groups_correct s 0#usize 9#usize 14#usize 19#usize 24#usize
      (by scalar_tac) (by scalar_tac) (by scalar_tac) (by scalar_tac) (by scalar_tac)
    simp only [UScalar.ofNatCore_val_eq] at groups
    apply spec_mono groups
    intro r hr
    rw [hr, ite_eq_left ⟨m8, m13, m18, m23⟩]
  · rename_i notPlain notDashed
    have wrong : Text.form 32 36 ((s.val.map toByte).map toCodeUnit).length = none := by
      simp only [Text.form, List.length_map, ite_eq_right notPlain, ite_eq_right notDashed]
    simp only [spec_ok, Uuid58.parseUuidBytes, Text.parse, wrong]
    rfl

/-- The public parser returns the exact specified UUID or first error on every byte slice,
including non-ASCII bytes, once the caller's AsRef implementation supplies the slice. -/
theorem parse_uuid_str_correct {α : Type} (asRef : core.convert.AsRef α (Slice Std.U8))
    (x : α) (s : Slice Std.U8) (view : asRef.as_ref x ⦃ t => t = s ⦄) :
    parse_uuid_str asRef x ⦃ r => r = rustResult (Uuid58.parseUuidBytes (s.val.map toByte)) ⦄ := by
  unfold parse_uuid_str
  apply spec_bind view
  rintro _ rfl
  exact parse_uuid_bytes_correct _

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
