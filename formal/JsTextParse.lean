import UuidText
import JsTextExtracted

/-! Refinement of parseHex and parseUuidString, including chained negative accumulators. -/
namespace Uuid58.Js

private def hexTable : List Int8 :=
  let lo := bytes TextExtracted.lowerInput
  let hi := bytes TextExtracted.upperInput
  (List.range 16).foldl (fun table i =>
    (table.set lo[i]!.val (Int8.ofNat i)).set hi[i]!.val (Int8.ofNat i)) (List.replicate 128 (-1))

private def hexLookup (u : CodeUnit) : Option Nat :=
  if u.val < 128 then
    let d := hexTable[u.val]!.toInt
    if d < 0 then none else some d.toNat
  else none

set_option maxRecDepth 4096 in
private theorem lookup_ascii : ∀ i : Fin 128,
    let u : CodeUnit := ⟨i.val, by have := i.isLt; omega⟩
    hexLookup u = (Text.digit? u).map Fin.val := by decide

private theorem lookup_correct (u : CodeUnit) : hexLookup u = (Text.digit? u).map Fin.val := by
  by_cases h : u.val < 128
  · exact lookup_ascii ⟨u.val,h⟩
  · have dec : ¬ (48 ≤ u.val ∧ u.val < 58) := by omega
    have upper : ¬ (65 ≤ u.val ∧ u.val < 71) := by omega
    have lower : ¬ (97 ≤ u.val ∧ u.val < 103) := by omega
    simp [hexLookup, h, Text.digit?, dec, upper, lower]

/-- Binary64 is symmetric in sign. Check the magnitude of each multiplication and addition. -/
private def signedInteger (r : Rounding) : Int → Option Int
  | .ofNat n => (integer r n).map Int.ofNat
  | .negSucc n => (integer r (n+1)).map fun m => -(m : Int)

private theorem signed_exact (r : Rounding) (z : Int) (lo : -(2^53) < z) (hi : z < 2^53) :
    signedInteger r z = some z := by
  cases z with
  | ofNat n =>
    change (n : Int) < 2^53 at hi
    rw [signedInteger, integer_of_lt r n (by omega)]; rfl
  | negSucc n =>
    rw [signedInteger, integer_of_lt r (n+1) (by omega)]; rfl

private def readHex (r : Rounding) : List CodeUnit → Int → Option Int
  | [], acc => some acc
  | u :: us, acc =>
    match hexLookup u with
    | none => some (-1)
    | some d => do
      let prod ← signedInteger r (acc * (TextExtracted.hexRadix : Int))
      let next ← signedInteger r (prod + d)
      readHex r us next

private def view (z : Int) : Option Nat := if z < 0 then none else some z.toNat
private def bounded (m : Nat) (z : Int) := -(m : Int) ≤ z ∧ z < (m : Int)

private theorem none_fold (s : List CodeUnit) : s.foldl Text.step none = none := by
  induction s with
  | nil => rfl
  | cons u us ih => exact ih

private theorem view_push (z : Int) (u : CodeUnit) (d : Text.Nibble) (hd : Text.digit? u = some d) :
    view (z*16 + d.val) = Text.step (view z) u := by
  have digitBound := d.isLt
  by_cases neg : z < 0
  · have stays : z*16 + d.val < 0 := by omega
    simp [view, neg, stays, Text.step]
  · have stays : ¬ z*16 + d.val < 0 := by omega
    simp [view, neg, stays, Text.step, hd]
    omega

private theorem read_correct (r : Rounding) (s : List CodeUnit) (m : Nat) (z : Int)
    (pos : 0 < m) (hz : bounded m z) (cap : m * 16^s.length ≤ 2^32) :
    ∃ t, readHex r s z = some t ∧ bounded (m * 16^s.length) t ∧
      view t = s.foldl Text.step (view z) := by
  induction s generalizing m z with
  | nil => exact ⟨z, rfl, by simpa using hz, rfl⟩
  | cons u us ih =>
    have factor : m * 16^(u::us).length = (m*16) * 16^us.length := by
      simp only [List.length_cons, Nat.pow_succ', Nat.mul_assoc]
    rw [factor] at cap ⊢
    have positive := Nat.pow_pos (by decide : 0 < 16) (n := us.length)
    cases hd : Text.digit? u with
    | none =>
      have invalid : Text.step (view z) u = none := by cases view z <;> simp [Text.step, hd]
      have nonzero : 0 < m * 16 * 16^us.length := Nat.mul_pos (by omega) positive
      exact ⟨-1, by simp [readHex, lookup_correct, hd], by unfold bounded; omega,
        by rw [List.foldl_cons, invalid, none_fold]; rfl⟩
    | some d =>
      let next : Int := z*16 + d.val
      have limit := Nat.le_trans (Nat.le_mul_of_pos_right (m*16) positive) cap
      have digitBound := d.isLt
      unfold bounded at hz
      have nextBound : bounded (m*16) next := by
        simp only [bounded, next, Int.natCast_mul, Int.cast_ofNat_Int]; omega
      have product := signed_exact r (z*16) (by omega) (by omega)
      have total := signed_exact r next (by dsimp [next]; omega) (by dsimp [next]; omega)
      obtain ⟨t, run, bound, val⟩ := ih (m*16) next (by omega) nextBound cap
      refine ⟨t, ?_, bound, ?_⟩
      · simpa [readHex, lookup_correct, hd, TextExtracted.hexRadix, product, total, next] using run
      · rw [List.foldl_cons, ← view_push z u d hd]; exact val

private def readRuns (r : Rounding) (groups : List (List CodeUnit)) (acc : Int) :=
  groups.foldlM (fun z cs => readHex r cs z) acc

private theorem runs_correct (r : Rounding) (groups : List (List CodeUnit)) (m : Nat) (z : Int)
    (pos : 0 < m) (hz : bounded m z) (cap : m * 16^groups.flatten.length ≤ 2^32) :
    ∃ t, readRuns r groups z = some t ∧ view t = groups.flatten.foldl Text.step (view z) := by
  induction groups generalizing m z with
  | nil => exact ⟨z, rfl, rfl⟩
  | cons xs rest ih =>
    simp only [List.flatten_cons, List.length_append, Nat.pow_add, ← Nat.mul_assoc] at cap
    have headCap := Nat.le_trans (Nat.le_mul_of_pos_right _ (Nat.pow_pos (by decide : 0 < 16))) cap
    obtain ⟨v, run, bound, val⟩ := read_correct r xs m z pos hz headCap
    obtain ⟨t, final, result⟩ := ih _ v (Nat.mul_pos pos (Nat.pow_pos (by decide))) bound cap
    refine ⟨t, ?_, ?_⟩
    · simpa [readRuns, List.foldlM_cons, run] using final
    · simp only [List.flatten_cons, List.foldl_append, ← val, result]

private def ranges (dashed : Bool) (k : Nat) :=
  ((if dashed then TextExtracted.dashedReads else TextExtracted.plainReads)[k]!).map
    fun (a,b) => List.range' a (b-a)

private theorem ranges_layout : ∀ (dashed : Bool) (k : Fin 4),
    (ranges dashed k.val).flatten = Text.indices dashed k.val := by decide

private def sourceWord (r : Rounding) (s : List CodeUnit) (dashed : Bool) (k : Nat) :=
  readRuns r ((ranges dashed k).map (List.map fun i => s[i]!)) 0

private theorem sourceWord_correct (r : Rounding) (s : List CodeUnit) (dashed : Bool) (k : Nat) (hk : k < 4) :
    ∃ z, sourceWord r s dashed k = some z ∧ view z = (Text.block s dashed k).foldl Text.step (some 0) := by
  let gs := (ranges dashed k).map (List.map fun i => s[i]!)
  have layout : gs.flatten = Text.block s dashed k := by
    dsimp only [gs, Text.block]
    rw [← List.map_flatten, ranges_layout dashed ⟨k,hk⟩]
  have len : gs.flatten.length = 8 := by rw [layout]; simp [Text.block, Text.indices]
  obtain ⟨z, run, val⟩ := runs_correct r gs 1 0 (by decide) (by unfold bounded; decide) (by rw [len])
  rw [layout] at val
  exact ⟨z, run, val⟩

private def finish (a b c d : Int) : Except Error Words :=
  if a < 0 ∨ b < 0 ∨ c < 0 ∨ d < 0 then .error .invalidCharacter
  else .ok ⟨a.toNat % 2^32, b.toNat % 2^32, c.toNat % 2^32, d.toNat % 2^32⟩

private theorem finish_correct (a b c d : Int) :
    finish a b c d = (Text.checked (view a) (view b) (view c) (view d)).map Subtype.val := by
  cases a <;> cases b <;> cases c <;> cases d <;>
    simp [finish, view, Text.checked, Except.map, Int.not_lt_of_ge (Int.natCast_nonneg _)]

private def sourceMarks (s : List CodeUnit) := TextExtracted.separators.all fun (i,c) => s[i]!.val == c

def parseUuidString (r : Rounding) (s : List CodeUnit) : Option (Except Error Words) :=
  match Text.form TextExtracted.plainLength TextExtracted.dashedLength s.length with
  | none => some (.error .invalidLength)
  | some dashed => do
    let a ← sourceWord r s dashed 0
    let b ← sourceWord r s dashed 1
    let c ← sourceWord r s dashed 2
    let d ← sourceWord r s dashed 3
    if dashed && !sourceMarks s then return .error .invalidCharacter
    return finish a b c d

theorem parseUuidString_correct (r : Rounding) (s : List CodeUnit) :
    parseUuidString r s = some ((Text.parse s).map Subtype.val) := by
  have marks : sourceMarks s = Text.hasMarks s := rfl
  simp only [parseUuidString, Text.parse, TextExtracted.plainLength, TextExtracted.dashedLength]
  cases form : Text.form 32 36 s.length with
  | none => rfl
  | some h =>
    obtain ⟨a, ha, va⟩ := sourceWord_correct r s h 0 (by decide)
    obtain ⟨b, hb, vb⟩ := sourceWord_correct r s h 1 (by decide)
    obtain ⟨c, hc, vc⟩ := sourceWord_correct r s h 2 (by decide)
    obtain ⟨d, hd, vd⟩ := sourceWord_correct r s h 3 (by decide)
    simp only [ha, hb, hc, hd, marks]
    cases h && !Text.hasMarks s <;> simp [finish_correct, va, vb, vc, vd, Except.map]

end Uuid58.Js
