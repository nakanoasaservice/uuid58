import UuidText

/-! Relate a left-to-right parse to the four big-endian words of section 5.1. -/
namespace Uuid58.Js.Text

def isMark (dashed : Bool) (i : Nat) := dashed && marks.contains i

/-- Read the indicated positions, requiring a hyphen at each separator. The natural
accumulator gives the mathematical value of every hex digit, most significant first. -/
def scan (s : List CodeUnit) (dashed : Bool) (positions : List Nat) (acc : Option Nat) : Option Nat :=
  if (positions.filter (isMark dashed)).all (fun i => s[i]!.val == 45) then
    ((positions.filter (fun i => !isMark dashed i)).map (fun i => s[i]!)).foldl step acc
  else none

theorem scan_cons (s : List CodeUnit) (dashed : Bool) (i : Nat) (rest : List Nat) (acc : Option Nat) :
    scan s dashed (i :: rest) acc =
      if isMark dashed i then (if s[i]!.val = 45 then scan s dashed rest acc else none)
      else scan s dashed rest (step acc s[i]!) := by
  cases h : isMark dashed i <;> by_cases hyphen : s[i]!.val = 45 <;>
    simp [scan, h, hyphen, -List.getElem!_eq_getElem?_getD]

private theorem fold_none (s : List CodeUnit) : s.foldl step none = none := by
  induction s with
  | nil => rfl
  | cons u us ih => exact ih

theorem scan_none (s : List CodeUnit) (dashed : Bool) (positions : List Nat) :
    scan s dashed positions none = none := by simp [scan, fold_none]

private theorem fold_from (s : List CodeUnit) (a : Nat) :
    s.foldl step (some a) = (s.foldl step (some 0)).map (fun n => a * 16^s.length + n) := by
  obtain ⟨rev, rfl⟩ : ∃ rev : List CodeUnit, s = rev.reverse :=
    ⟨s.reverse, (List.reverse_reverse _).symm⟩
  induction rev with
  | nil => simp
  | cons u xs ih =>
    simp only [List.reverse_cons, List.foldl_append, List.foldl_cons, List.foldl_nil, List.length_append,
      List.length_singleton, ih]
    cases xs.reverse.foldl step (some 0) <;> cases hd : digit? u <;>
      simp [step, hd, Nat.pow_succ, Nat.add_mul, Nat.mul_assoc, Nat.add_assoc]

def scanResult : Option Nat → Except Error Nat
  | none => .error .invalidCharacter
  | some n => .ok n

private theorem four_blocks (s : List CodeUnit) (dashed : Bool) :
    let b := block s dashed
    let read := fun k => (b k).foldl step (some 0)
    scanResult ((b 0 ++ b 1 ++ b 2 ++ b 3).foldl step (some 0)) =
      (checked (read 0) (read 1) (read 2) (read 3)).map (fun w => w.val.value) := by
  intro b read
  have appendWord (k : Nat) (acc : Option Nat) :
      (b k).foldl step acc = acc.bind (fun a => (read k).map (fun n => a * 2^32 + n)) := by
    cases acc with
    | none => exact fold_none _
    | some a => simpa [b, block, indices, read] using fold_from (b k) a
  have fits (k n : Nat) (h : read k = some n) : n % 2^32 = n :=
    Nat.mod_eq_of_lt (block_fits s dashed k n h)
  simp only [List.foldl_append]
  rw [appendWord 3, appendWord 2, appendWord 1]
  change scanResult ((((read 0).bind _).bind _).bind _) = _
  cases h0 : read 0 <;> cases h1 : read 1 <;> cases h2 : read 2 <;> cases h3 : read 3 <;>
    simp [checked, Except.map, scanResult, Words.value]
  rw [fits 0 _ h0, fits 1 _ h1, fits 2 _ h2, fits 3 _ h3]

theorem scan_spec (s : List CodeUnit) (dashed : Bool) (len : s.length = if dashed then 36 else 32) :
    scanResult (scan s dashed (List.range' 0 s.length) (some 0)) =
      (parse s).map (fun w => w.val.value) := by
  have separators : ∀ d : Bool,
      (List.range' 0 (if d then 36 else 32)).filter (isMark d) = (if d then marks else []) := by decide
  have digits : ∀ d : Bool,
      (List.range' 0 (if d then 36 else 32)).filter (fun i => !isMark d i) =
        indices d 0 ++ indices d 1 ++ indices d 2 ++ indices d 3 := by decide
  have shape : form 32 36 s.length = some dashed := by rw [len]; cases dashed <;> rfl
  unfold parse
  rw [shape]
  simp only [scan, len, separators, digits, List.map_append]
  cases dashed with
  | false => exact four_blocks s false
  | true =>
    change scanResult (if hasMarks s then _ else none) = _
    cases hasMarks s <;> first | rfl | exact four_blocks s true

end Uuid58.Js.Text

namespace Uuid58

/-- Section 5.1 on byte slices. Widen each byte separately to preserve byte-length errors. -/
def parseUuidBytes (bs : List Byte) : Except Error UUID :=
  (Js.Text.parse (bs.map Js.toCodeUnit)).map fun w => w.val.uuid w.property

end Uuid58
