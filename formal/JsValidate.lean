import JsDecode

/-! The JavaScript validator agrees with successful decoding as required by section 6. -/
namespace Uuid58.Js

/-- ECMAScript's Unicode regex mode reads a surrogate pair as one code point
and treats an unpaired surrogate as its own code point. -/
private def codePoints : List CodeUnit → List Nat
  | [] => []
  | [u] => [u.val]
  | u :: v :: us =>
    if 0xd800 ≤ u.val ∧ u.val < 0xdc00 ∧ 0xdc00 ≤ v.val ∧ v.val < 0xe000 then
      (0x10000 + (u.val - 0xd800) * 0x400 + (v.val - 0xdc00)) :: codePoints us
    else u.val :: codePoints (v :: us)

/-- The source regex has both input anchors, one repeated class and the u flag. -/
def regexTest (s : List CodeUnit) : Bool :=
  let chars := codePoints s
  chars.all Extracted.regexChar && chars.length == Extracted.regexWidth

/-- ECMAScript compares the original strings lexicographically by unsigned UTF-16 units. -/
def isUuid58 (s : List CodeUnit) : Bool :=
  regexTest s && Extracted.withinLimit (s.map Fin.val)

private theorem nonAscii {c : Nat} (h : 128 ≤ c) : Extracted.regexChar c = false := by
  simp only [Extracted.regexChar, decide_eq_false_iff_not]; omega

private abbrev unitChar (u : CodeUnit) := Extracted.regexChar u.val

/-- If the class accepts every character, every code point occupies one unit. -/
private theorem class_codePoints (s : List CodeUnit) :
    (codePoints s).all Extracted.regexChar = s.all unitChar ∧
      (s.all unitChar = true → codePoints s = s.map Fin.val) := by
  induction s using codePoints.induct with
  | case1 => simp [codePoints]
  | case2 u => simp [codePoints, unitChar]
  | case3 u v us pair _ =>
    have high : Extracted.regexChar u.val = false := nonAscii (by omega)
    have astral : Extracted.regexChar (0x10000 + (u.val - 0xd800) * 0x400 + (v.val - 0xdc00)) = false :=
      nonAscii (by omega)
    simp [codePoints, pair, unitChar, high, astral]
  | case4 u v us separate ih =>
    rw [codePoints, ite_eq_right separate, List.all_cons, ih.1, List.all_cons]
    refine ⟨rfl, fun h => ?_⟩
    exact congrArg (u.val :: ·) (ih.2 (Bool.and_eq_true_iff.mp h).2)

set_option maxRecDepth 4096 in
private theorem ascii_class : ∀ i : Fin 128,
    Extracted.regexChar i.val = (digit? ⟨i.val, by have := i.isLt; omega⟩).isSome := by decide

private theorem unit_class (u : CodeUnit) : unitChar u = (digit? (specByte u)).isSome := by
  by_cases h : u.val < 128
  · simpa only [unitChar, specByte, dite_eq_left h] using ascii_class ⟨u.val, h⟩
  · rw [unitChar, nonAscii (by omega), specByte, dite_eq_right h]; decide

private theorem class_parse (s : List CodeUnit) :
    s.all unitChar = (parse (s.map specByte)).isSome := by
  induction s with
  | nil => rfl
  | cons u us ih =>
    cases hd : digit? (specByte u) <;> cases hp : parse (us.map specByte) <;>
      simp [parse, unit_class, ih, hd, hp]

/-- The exported regex checks the alphabet and width over every ECMAScript string. -/
theorem regex_correct (s : List CodeUnit) :
    regexTest s = ((parse (s.map specByte)).isSome && s.length == 22) := by
  obtain ⟨allChars, ascii⟩ := class_codePoints s
  dsimp only [regexTest]
  rw [allChars, ← class_parse]
  cases h : s.all unitChar with
  | false => rfl
  | true => rw [ascii h, List.length_map]; rfl

private abbrev maximum : UUID := ⟨2^128 - 1, by decide⟩

private theorem within_limit {s : List CodeUnit} {ds : List Digit}
    (hp : parse (s.map specByte) = some ds) (len : s.length = 22) :
    Extracted.withinLimit (s.map Fin.val) = decide (value ds < 2^128) := by
  have accepted : s.all unitChar = true := by rw [class_parse, hp]; rfl
  have units : s.map Fin.val = (ds.map symbol).map Fin.val := by
    rw [map_parse hp, List.map_map]
    apply List.map_congr_left
    intro u hu
    have good := List.all_eq_true.mp accepted u hu
    have ascii : u.val < 128 := by
      apply Nat.lt_of_not_le
      intro high
      simp [unitChar, nonAscii high] at good
    simp [specByte, ascii]
  have bound : Extracted.maxUuid58.toList.map Char.toNat = (encode maximum).map Fin.val := by
    rw [max_encoding]; decide
  have lengthDigits : ds.length = 22 := by simpa [len] using congrArg List.length (map_parse hp)
  have ordered : encode maximum < ds.map symbol ↔ maximum.val < value ds := by
    simpa only [encode, value_digits 22 maximum.val (by decide)] using
      value_order (digits 22 maximum.val) ds (by simp [lengthDigits])
  unfold Extracted.withinLimit
  rw [units, bound]
  apply decide_eq_decide.mpr
  rw [List.map_le_map_iff Fin.val (fun _ _ h => h), ← List.not_lt, ordered]
  change (¬ 2^128 - 1 < value ds) ↔ value ds < 2^128
  omega

theorem isUuid58_correct (s : List CodeUnit) :
    isUuid58 s = (decode (s.map specByte)).isOk := by
  rw [isUuid58, regex_correct]
  by_cases len : s.length = 22
  · cases hp : parse (s.map specByte) with
    | none => simp [decode, len, hp, Except.isOk, Except.toBool]
    | some ds =>
      rw [within_limit hp len]
      by_cases fits : value ds < 2^128 <;> simp [decode, len, hp, fits, Except.isOk, Except.toBool]
  · have width : (s.length == 22) = false := beq_eq_false_iff_ne.mpr len
    simp [decode, len, width, Except.isOk, Except.toBool]

theorem isUuid58_iff_decodeWords (r : Rounding) (s : List CodeUnit) :
    isUuid58 s = true ↔ ∃ w, decodeWords r s = some (.ok w) := by
  rw [isUuid58_correct, decode_correct]
  cases decode (s.map specByte) <;> simp [wordsResult, Except.isOk, Except.toBool]

end Uuid58.Js
