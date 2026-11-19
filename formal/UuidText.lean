import JsDecode

/-! Section 5 on ECMAScript strings, measured in UTF-16 code units. -/
namespace Uuid58.Js.Text

abbrev Nibble := Fin 16
abbrev ValidWords := { w : Words // w.valid }

def digit? (u : CodeUnit) : Option Nibble :=
  if h : 48 ≤ u.val ∧ u.val < 58 then some ⟨u.val - 48, by omega⟩
  else if h : 65 ≤ u.val ∧ u.val < 71 then some ⟨u.val - 55, by omega⟩
  else if h : 97 ≤ u.val ∧ u.val < 103 then some ⟨u.val - 87, by omega⟩
  else none

def lower (d : Nibble) : CodeUnit :=
  ⟨(if d.val < 10 then 48 else 87) + d.val, by have := d.isLt; split <;> omega⟩

theorem digit_lower : ∀ d : Nibble, digit? (lower d) = some d := by decide

def step (acc : Option Nat) (u : CodeUnit) : Option Nat := do
  let n ← acc
  let d ← digit? u
  return n * 16 + d.val

/-- Each group of eight digits supplies one word, most significant first. -/
def position (dashed : Bool) (i : Nat) :=
  if dashed then i + ([8,12,16,20].filter (· ≤ i)).length else i

def indices (dashed : Bool) (k : Nat) :=
  (List.range' (8*k) 8).map (position dashed)

def block (s : List CodeUnit) (dashed : Bool) (k : Nat) :=
  (indices dashed k).map (fun i => s[i]!)

def marks : List Nat := [8,13,18,23]
def hasMarks (s : List CodeUnit) := marks.all fun i => s[i]!.val == 45

def form (plain dashed length : Nat) : Option Bool :=
  if length = plain then some false else if length = dashed then some true else none

def checked (a b c d : Option Nat) : Except Error ValidWords :=
  match a, b, c, d with
  | some x, some y, some z, some t =>
    .ok ⟨⟨x % 2^32, y % 2^32, z % 2^32, t % 2^32⟩,
      Nat.mod_lt _ (by decide), Nat.mod_lt _ (by decide), Nat.mod_lt _ (by decide), Nat.mod_lt _ (by decide)⟩
  | _, _, _, _ => .error .invalidCharacter

def parse (s : List CodeUnit) : Except Error ValidWords :=
  match form 32 36 s.length with
  | none => .error .invalidLength
  | some dashed =>
    if dashed && !hasMarks s then .error .invalidCharacter else
      let read := fun k => (block s dashed k).foldl step (some 0)
      checked (read 0) (read 1) (read 2) (read 3)

/-- Section 5.1 checks the separators and all 32 digit positions. -/
def wellFormed (s : List CodeUnit) : Bool :=
  match form 32 36 s.length with
  | none => false
  | some dashed => !(dashed && !hasMarks s) &&
      (List.range 32).all fun i => (digit? s[position dashed i]!).isSome

private theorem fold_accepts (s : List CodeUnit) (a : Option Nat) :
    (s.foldl step a).isSome = (a.isSome && s.all fun u => (digit? u).isSome) := by
  induction s generalizing a with
  | nil => simp
  | cons u us ih =>
    rw [List.foldl_cons, ih]
    cases a <;> cases h : digit? u <;> simp [step, h]

private theorem fold_bound (s : List CodeUnit) (a : Option Nat) (m : Nat)
    (ha : ∀ x, a = some x → x < m) {n : Nat} (hn : s.foldl step a = some n) : n < m * 16^s.length := by
  induction s generalizing a m with
  | nil => simpa using ha n hn
  | cons u us ih =>
    have bound (x : Nat) (hx : step a u = some x) : x < m*16 := by
      cases a with
      | none => simp [step] at hx
      | some v =>
        have small := ha v rfl
        cases hd : digit? u with
        | none => simp [step, hd] at hx
        | some d => simp [step, hd] at hx; have := d.isLt; omega
    simpa only [List.length_cons, Nat.pow_succ', Nat.mul_assoc] using ih _ _ bound hn

/-- Converting the eight-digit Horner value to a 32-bit word preserves the entire value. -/
theorem block_fits (s : List CodeUnit) (dashed : Bool) (k n : Nat)
    (h : (block s dashed k).foldl step (some 0) = some n) : n < 2^32 := by
  have bound := fold_bound _ _ 1 (by intro x hx; cases hx; decide) h
  simpa [block, indices] using bound

theorem parse_accepts (s : List CodeUnit) : (parse s).isOk = wellFormed s := by
  have accepts (a b c d : Option Nat) : (checked a b c d).isOk =
      (a.isSome && b.isSome && c.isSome && d.isSome) := by
    cases a <;> cases b <;> cases c <;> cases d <;> rfl
  have digits (dashed : Bool) : block s dashed 0 ++ block s dashed 1 ++ block s dashed 2 ++ block s dashed 3 =
      (List.range 32).map fun i => s[position dashed i]! := by cases dashed <;> rfl
  unfold parse wellFormed
  cases form 32 36 s.length with
  | none => rfl
  | some h =>
    dsimp only
    cases h && !hasMarks s with
    | true => rfl
    | false =>
      simp only [Bool.false_eq_true, ite_false, accepts, fold_accepts, Option.isSome_some,
        Bool.true_and, Bool.not_false, ← List.all_append, digits, List.all_map, Function.comp_def]

def word (w : Words) : Nat → Nat
  | 0 => w.a | 1 => w.b | 2 => w.c | 3 => w.d | _ => 0

def nibble (n i : Nat) : Nibble := Fin.ofNat 16 (n / 16^(7-i))

/-- A separator emits a hyphen. The remaining positions select the 32 digits from left to right. -/
def digitIndex (p : Nat) : Option Nat :=
  if p ∈ marks then none else some (p - (marks.filter (· < p)).length)

def character (w : Words) (p : Nat) : CodeUnit :=
  match digitIndex p with
  | none => 45
  | some i => lower (nibble (word w (i/8)) (i%8))

def canonical (w : Words) := (List.range 36).map (character w)

private theorem canonical_block (w : Words) (k : Fin 4) :
    block (canonical w) true k.val = (List.range 8).map (fun i => lower (nibble (word w k.val) i)) := by
  obtain ⟨k, hk⟩ := k
  have cases : k = 0 ∨ k = 1 ∨ k = 2 ∨ k = 3 := by omega
  rcases cases with rfl | rfl | rfl | rfl <;> rfl

private theorem read_nibbles (n : Nat) (hn : n < 2^32) :
    ((List.range 8).map (fun i => lower (nibble n i))).foldl step (some 0) = some n := by
  have push (a : Nat) (d : Nibble) : step (some a) (lower d) = some (a * 16 + d.val) := by
    simp [step, digit_lower]
  rw [show List.range 8 = [0,1,2,3,4,5,6,7] by decide]
  simp only [List.map_cons, List.map_nil, List.foldl_cons, List.foldl_nil, push, Option.some.injEq,
    nibble, Fin.val_ofNat, Nat.reduceSub, Nat.reducePow]
  omega

theorem parse_canonical (w : ValidWords) : parse (canonical w.val) = .ok w := by
  have length : (canonical w.val).length = 36 := by simp [canonical]
  have marksOk : hasMarks (canonical w.val) = true := rfl
  have read (k : Nat) (hk : k < 4) (h : word w.val k < 2^32) :
      (block (canonical w.val) true k).foldl step (some 0) = some (word w.val k) := by
    have layout := canonical_block w.val ⟨k, hk⟩
    dsimp only at layout
    rw [layout, read_nibbles _ h]
  obtain ⟨a,b,c,d⟩ := w.property
  simp only [parse, length, show form 32 36 36 = some true by decide, marksOk, Bool.not_true,
    Bool.and_false, Bool.false_eq_true, ite_false]
  rw [read 0 (by decide) a, read 1 (by decide) b, read 2 (by decide) c, read 3 (by decide) d]
  simp only [checked, word, Nat.mod_eq_of_lt a, Nat.mod_eq_of_lt b, Nat.mod_eq_of_lt c, Nat.mod_eq_of_lt d]

end Uuid58.Js.Text
