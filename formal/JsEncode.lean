import JsExtracted
import Chunk

/-! Refinement of the JavaScript encoder's word and digit arithmetic. -/
namespace Uuid58.Js

private abbrev W : Nat := 2^32
private abbrev C : Nat := 58^3

private def split (r : Rounding) (n d : Nat) : Option (Nat × Nat) := do
  let q ← floorDiv r n d
  return (q, ← sub r n (← mul r q d))

private theorem floorDiv_ok (r : Rounding) {n d : Nat} (hd : 0 < d) (hs : d ≤ 2^20)
    (hn : n < d*W) : floorDiv r n d = some (n/d) := by
  simp [floorDiv, Nat.ne_of_gt hd, floor_div_exact r n d hd hs hn]

private theorem split_ok (r : Rounding) {n d : Nat} (hd : 0 < d) (hs : d ≤ 2^20)
    (hn : n < d*W) : split r n d = some (n/d, n%d) := by
  have safe : n < 2^53 := Nat.lt_of_lt_of_le hn
    (Nat.le_trans (Nat.mul_le_mul_right W hs) (by decide))
  have prod := Nat.div_mul_le_self n d
  have remn : n - n/d*d = n%d := by
    have := Nat.mod_add_div n d; rw [Nat.mul_comm (n/d) d]; omega
  simp [split, floorDiv_ok r hd hs hn, mul, sub, prod, integer_of_lt r _ (by omega : n/d*d < 2^53),
    integer_of_lt r (n%d) (by have := Nat.mod_lt n hd; omega), remn]

private theorem first_ok (r : Rounding) (w : Nat) (hw : w < W) :
    Extracted.step0 r w = some (w/C, w%C) :=
  split_ok r (n := w) (d := C) (by decide) (by decide) (by dsimp [C,W] at *; omega)

private theorem next_ok (r : Rounding) (c w : Nat) (hc : c < C) (hw : w < W) :
    Extracted.step1 r c w = some ((c*W+w)/C, (c*W+w)%C) := by
  have bound : c*W+w < C*W := by dsimp only [W,C] at hc hw ⊢; omega
  have safe : c*W+w < 2^53 := Nat.lt_trans bound (by decide)
  have hm : mul r c W = some (c*W) := integer_of_lt r (c*W) (Nat.lt_of_le_of_lt (Nat.le_add_right ..) safe)
  have ha : add r (c*W) w = some (c*W+w) := integer_of_lt r (c*W+w) safe
  have hs := split_ok r (n := c*W+w) (d := C) (by decide) (by decide) bound
  change (mul r c W).bind (fun p => (add r p w).bind (fun n => split r n C)) = _
  exact Option.bind_eq_some_iff.mpr ⟨_, hm, Option.bind_eq_some_iff.mpr ⟨_, ha, hs⟩⟩

structure Words where
  a : Nat
  b : Nat
  c : Nat
  d : Nat

def Words.valid (w : Words) := w.a < W ∧ w.b < W ∧ w.c < W ∧ w.d < W
def Words.value (w : Words) := ((w.a*W + w.b)*W + w.c)*W + w.d

/-- The four extracted register updates, in source order. -/
def divideWords (r : Rounding) (w : Words) : Option (Words × Nat) := do
  let (a, c0) ← Extracted.step0 r w.a
  let (b, c1) ← Extracted.step1 r c0 w.b
  let (c, c2) ← Extracted.step2 r c1 w.c
  let (d, rem) ← Extracted.step3 r c2 w.d
  return (⟨a, b, c, d⟩, rem)

private theorem reassemble (n : Nat) : n/C*C + n%C = n := by
  simpa [Nat.mul_comm] using Nat.div_add_mod n C

private theorem extend_value {p q c w digit rem : Nat} (prev : q*C + c = p)
    (step : digit*C + rem = c*W + w) : (q*W+digit)*C + rem = p*W+w := by
  rw [Nat.add_mul, Nat.mul_right_comm q W C, Nat.add_assoc, step, ← prev,
    Nat.add_mul, Nat.add_assoc]

private theorem divmod_unique {n q rem : Nat} (h : q*C+rem = n) (small : rem < C) :
    n/C = q ∧ n%C = rem := by dsimp only [C] at *; omega

private theorem quotient_word {c w : Nat} (hc : c < C) (hw : w < W) : (c*W+w)/C < W := by
  dsimp only [C,W] at *; omega

theorem divideWords_correct (r : Rounding) (w : Words) (h : w.valid) :
    ∃ q, divideWords r w = some (q, w.value%C) ∧ q.valid ∧ q.value = w.value/C := by
  obtain ⟨ha,hb,hc,hd⟩ := h
  let x := w.a%C*W+w.b
  let y := x%C*W+w.c
  let z := y%C*W+w.d
  let q : Words := ⟨w.a/C, x/C, y/C, z/C⟩
  have hC : 0 < C := by decide
  have hx := Nat.mod_lt w.a hC
  have hy := Nat.mod_lt x hC
  have hz := Nat.mod_lt y hC
  have eqn : q.value*C + z%C = w.value :=
    extend_value (extend_value (extend_value (reassemble w.a) (reassemble x)) (reassemble y)) (reassemble z)
  obtain ⟨quo,remn⟩ := divmod_unique eqn (Nat.mod_lt z hC)
  refine ⟨q, ?_, ⟨Nat.lt_of_le_of_lt (Nat.div_le_self ..) ha,
    quotient_word hx hb, quotient_word hy hc, quotient_word hz hd⟩, quo.symm⟩
  have s2 : Extracted.step2 r (x%C) w.c = some (y/C,y%C) := next_ok r _ _ hy hc
  have s3 : Extracted.step3 r (y%C) w.d = some (z/C,z%C) := next_ok r _ _ hz hd
  have run : divideWords r w = some (q, z%C) := by
    unfold divideWords
    apply Option.bind_eq_some_iff.mpr
    refine ⟨_, first_ok r w.a ha, ?_⟩
    apply Option.bind_eq_some_iff.mpr
    refine ⟨_, next_ok r _ _ hx hb, ?_⟩
    apply Option.bind_eq_some_iff.mpr
    refine ⟨_, s2, ?_⟩
    exact Option.bind_eq_some_iff.mpr ⟨_, s3, rfl⟩
  simpa only [remn] using run

private theorem digit_ok (r : Rounding) (n : Nat) (hn : n < 58^4) :
    Extracted.digitStep r n = some (n/58, n%58) := by
  have hf := floorDiv_ok r (n := n) (by decide : 0 < 58) (by decide) (by dsimp only [W]; omega)
  have eqn : n/58 % W = n/58 := Nat.mod_eq_of_lt (by dsimp only [W]; omega)
  have hs := split_ok r (n := n) (by decide : 0 < 58) (by decide) (by dsimp only [W]; omega)
  simpa [Extracted.digitStep, split, hf, eqn] using hs

/-- `writeDigits` fills the buffer right to left, so the current low digit
follows the digits emitted by the remaining iterations. -/
def writeDigits (r : Rounding) : Nat → Nat → Option (List Digit)
  | 0, _ => some []
  | k+1, n => do
    let (q, d) ← Extracted.digitStep r n
    if h : d < 58 then return (← writeDigits r k q) ++ [⟨d,h⟩] else none

private theorem write_correct (r : Rounding) (k n : Nat) (small : n < 58^4) (h : n < 58^k) :
    writeDigits r k n = some (digits k n) := by
  induction k generalizing n with
  | zero => rfl
  | succ k ih =>
    have hq : n/58 < 58^k := (Nat.div_lt_iff_lt_mul (by decide)).2 (by simpa [Nat.pow_succ] using h)
    have rest := ih (n/58) (Nat.lt_of_le_of_lt (Nat.div_le_self ..) small) hq
    simp [writeDigits, digit_ok r n small, Nat.mod_lt _ (by decide : 0 < 58), rest, digits_snoc k n h]

/-- Six low groups followed by the leading group in the low word. The source
extractor reads the loop bound and both group widths from `encodeWords`. -/
def groups (r : Rounding) : Nat → Words → Option (List Digit)
  | 0, w => writeDigits r Extracted.leading w.d
  | k+1, w => do
    let (q, rem) ← divideWords r w
    let suffix ← writeDigits r Extracted.width rem
    return (← groups r k q) ++ suffix

private theorem digits_split (k n : Nat) (h : n < 58^(k+3)) :
    digits k (n/C) ++ digits 3 (n%C) = digits (k+3) n := by
  let ds := digits k (n/C) ++ digits 3 (n%C)
  have hq : n/C < 58^k := (Nat.div_lt_iff_lt_mul (by decide)).2 (by simpa [Nat.pow_add] using h)
  have hl : ds.length = k+3 := by simp [ds]
  have hv : value ds = n := by
    simpa only [ds, value_append, length_digits, value_digits k _ hq,
      value_digits 3 _ (Nat.mod_lt _ (by decide))] using reassemble n
  simpa only [hl,hv] using (digits_value ds).symm

private theorem groups_correct (r : Rounding) (k : Nat) (w : Words) (hw : w.valid)
    (h : w.value < 58^(4+3*k)) : groups r k w = some (digits (4+3*k) w.value) := by
  induction k generalizing w with
  | zero =>
    have hd := hw.2.2.2
    have low : w.d = w.value := by
      dsimp only [Words.value,W] at h hd ⊢; omega
    change writeDigits r 4 w.d = some (digits 4 w.value)
    rw [low]; exact write_correct r 4 _ h h
  | succ k ih =>
    let n := w.value
    have p : 4+3*(k+1) = (4+3*k)+3 := by omega
    rw [p] at h ⊢
    obtain ⟨q, step, valid, hq⟩ := divideWords_correct r w hw
    have highBound : q.value < 58^(4+3*k) := by
      rw [hq]; apply (Nat.div_lt_iff_lt_mul (by decide)).2
      simpa [Nat.pow_add] using h
    have hr : n%C < 58^3 := Nat.mod_lt _ (by decide)
    have emit := write_correct r 3 (n%C) (Nat.lt_trans hr (by decide)) hr
    change writeDigits r Extracted.width (w.value%C) = _ at emit
    simp [groups, step, emit, ih q valid highBound, hq, n, digits_split _ _ h]

def Words.uuid (w : Words) (hw : w.valid) : UUID :=
  ⟨w.value, by obtain ⟨a,b,c,d⟩ := hw; dsimp only [Words.value,W] at *; omega⟩

/-- Look up the digits in the alphabet read from the TypeScript source. -/
def encodeWords (r : Rounding) (w : Words) : Option (List Byte) :=
  (groups r Extracted.rounds w).map (List.map fun d => (bytes Extracted.alphabet)[d.val]!)

/-- The encoder emits exactly the specification's 22 ASCII bytes for each
big-endian input of four unsigned 32-bit words. -/
theorem encode_correct (r : Rounding) (w : Words) (hw : w.valid) :
    encodeWords r w = some (encode (w.uuid hw)) := by
  have bound := (w.uuid hw).isLt
  have fits : w.value < 58^(4+3*6) := Nat.lt_trans bound (by decide)
  change (groups r 6 w).map _ = _
  rw [groups_correct r 6 w hw fits]; rfl

end Uuid58.Js
