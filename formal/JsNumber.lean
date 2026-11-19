import Mathlib.Data.Nat.Find

/-! The nonnegative finite part of ECMAScript Number. A tick is the least
positive binary64 subnormal, 2^-1074. All distances below are integers. -/
namespace Uuid58.Js

set_option exponentiation.threshold 2048
set_option maxRecDepth 4096

abbrev unit : Nat := 2^1074

/-- Subnormals use shift zero. Normal numbers use a 53-bit significand and
shifts up to 2045. Allowing shorter significands represents the same values. -/
def Finite64 (ticks : Nat) : Prop :=
  ∃ m e : Nat, m < 2^53 ∧ e ≤ 2045 ∧ ticks = m * 2^e

private def distance (x y : Nat) := (x - y) + (y - x)

/-- Nearest to `n/d`, in units of `2^-1074`. Multiplication by the positive
common denominator preserves distances. The results hold for either tie choice. -/
def Nearest (n d ticks : Nat) : Prop := Finite64 ticks ∧ ∀ z, Finite64 z →
  distance (ticks*d) (n*unit) ≤ distance (z*d) (n*unit)

/-- There is always a closest point in the finite grid. -/
private theorem nearest_exists (n d : Nat) : ∃ t, Nearest n d t := by
  classical
  let attainable := fun k => ∃ z, Finite64 z ∧ distance (z*d) (n*unit) = k
  have hz : Finite64 0 := ⟨0, 0, by decide, by decide, rfl⟩
  have existsDist : ∃ k, attainable k := ⟨_, 0, hz, rfl⟩
  obtain ⟨t, ht, he⟩ := Nat.find_spec existsDist
  exact ⟨t, ht, fun z h => he ▸ Nat.find_min' existsDist ⟨z, h, rfl⟩⟩

/-- The only property of the rounding implementation used by the codec.
The proved domain is finite and strictly below the overflow threshold. -/
structure Rounding where
  ticks : Nat → Nat → Nat
  nearest : ∀ n d, 0 < d → n < d * 2^53 → Nearest n d (ticks n d)

theorem rounding_exists : Nonempty Rounding :=
  ⟨⟨fun n d => Classical.choose (nearest_exists n d),
    fun n d _ _ => Classical.choose_spec (nearest_exists n d)⟩⟩

private theorem integer_finite (n : Nat) (h : n < 2^53) : Finite64 (n*unit) :=
  ⟨n, 1074, h, by decide, rfl⟩

theorem integer_exact (r : Rounding) (n : Nat) (h : n < 2^53) : r.ticks n 1 = n*unit := by
  have best := (r.nearest n 1 (by decide) (by simpa using h)).2 _ (integer_finite n h)
  simp only [Nat.mul_one, distance, Nat.sub_self] at best
  omega

private theorem brackets {n d y lo hi : Nat} (hd : 0 < d) (h : Nearest n d y)
    (lower : Finite64 lo) (upper : Finite64 hi) (hl : lo*d ≤ n*unit) (hu : n*unit ≤ hi*d) :
    lo ≤ y ∧ y ≤ hi := by
  constructor
  · apply Nat.le_of_not_lt
    intro hlt
    have := Nat.mul_lt_mul_of_pos_right hlt hd
    have best := h.2 lo lower
    unfold distance at best
    omega
  · apply Nat.le_of_not_lt
    intro hlt
    have := Nat.mul_lt_mul_of_pos_right hlt hd
    have best := h.2 hi upper
    unfold distance at best
    omega

/-- For the encoder's divisors, rounding cannot change the integer quotient.
`q` and `q + 1 - 2^-20` are representable. The exact ratio lies between them
because it is at least `1/d` below `q + 1`, and `d ≤ 2^20`. -/
theorem floor_div_exact (r : Rounding) (n d : Nat) (hd : 0 < d) (hd' : d ≤ 2^20)
    (hn : n < d * 2^32) : r.ticks n d / unit = n / d := by
  let q := n / d
  have hq : q < 2^32 := (Nat.div_lt_iff_lt_mul hd).2 (by simpa [Nat.mul_comm] using hn)
  have hnear := r.nearest n d hd (Nat.lt_of_lt_of_le hn (Nat.mul_le_mul_left d (by decide)))
  let m := (q+1)*2^20-1
  let upper := m*2^1054
  have hrepr : Finite64 upper := ⟨m, 1054, by dsimp [m]; omega, by decide, rfl⟩
  have hupper : upper + 2^1054 = (q+1)*unit := by
    change m*2^1054 + 2^1054 = _
    have hp : 0 < (q+1)*2^20 := Nat.mul_pos (Nat.succ_pos _) (by decide)
    have hm : m.succ = (q+1)*2^20 := Nat.sub_add_cancel hp
    rw [← Nat.succ_mul, hm, Nat.mul_assoc]
  have hl : q*unit*d ≤ n*unit := by
    rw [Nat.mul_right_comm]; exact Nat.mul_le_mul_right _ (Nat.div_mul_le_self n d)
  have hu : n*unit ≤ upper*d := by
    have hnext : n+1 ≤ (q+1)*d := by
      have := Nat.mod_lt n hd
      have := Nat.div_add_mod n d
      simp only [q, Nat.succ_mul, Nat.mul_comm (n/d) d]; omega
    have a := Nat.mul_le_mul_right unit hnext
    rw [Nat.succ_mul] at a
    have b := congrArg (· * d) hupper
    change (upper + 2^1054)*d = ((q+1)*unit)*d at b
    rw [Nat.add_mul, Nat.mul_right_comm (q+1) unit d] at b
    have c : 2^1054*d ≤ unit := Nat.mul_le_mul_left _ hd'
    apply Nat.le_of_add_le_add_right (b := 2^1054*d)
    rw [b]
    exact Nat.le_trans (Nat.add_le_add_left c _) a
  obtain ⟨hlo, hhi⟩ := brackets hd hnear (integer_finite q (by omega)) hrepr hl hu
  apply Nat.le_antisymm
  · apply Nat.le_of_lt_succ
    apply (Nat.div_lt_iff_lt_mul (by decide : 0 < unit)).2
    exact Nat.lt_of_le_of_lt hhi (hupper ▸ Nat.lt_add_of_pos_right (by decide))
  · exact (Nat.le_div_iff_mul_le (by decide : 0 < unit)).2 hlo

/-- These partial operations cover nonnegative, exactly representable integer
intermediates. Out-of-domain computations have no successful execution. -/
def integer (r : Rounding) (n : Nat) : Option Nat :=
  if n < 2^53 then some (r.ticks n 1 / unit) else none

def add (r : Rounding) (a b : Nat) := integer r (a+b)
def mul (r : Rounding) (a b : Nat) := integer r (a*b)
def sub (r : Rounding) (a b : Nat) := if b ≤ a then integer r (a-b) else none

def floorDiv (r : Rounding) (a b : Nat) : Option Nat :=
  if b = 0 then none else some (r.ticks a b / unit)

/-- Plain Number division on the decoder's integer domain. The guard
requires an integral quotient in the exactly representable range. -/
def exactDiv (r : Rounding) (a b : Nat) : Option Nat :=
  if 0 < b ∧ a % b = 0 ∧ a/b < 2^53 then some (r.ticks a b / unit) else none

theorem exactDiv_mul (r : Rounding) (q d : Nat) (hd : 0 < d) (hq : q < 2^53) :
    exactDiv r (q*d) d = some q := by
  have hn : q*d < d*2^53 := by rw [Nat.mul_comm d]; exact Nat.mul_lt_mul_of_pos_right hq hd
  have best := (r.nearest _ _ hd hn).2 _ (integer_finite q hq)
  rw [Nat.mul_right_comm q unit d] at best
  simp only [distance, Nat.sub_self, Nat.zero_add] at best
  have eqn : r.ticks (q*d) d * d = (q*d)*unit := by omega
  rw [Nat.mul_right_comm q d unit] at eqn
  have exactTicks := Nat.eq_of_mul_eq_mul_right hd eqn
  simp [exactDiv, hd, hq, exactTicks, Nat.mul_div_cancel _ hd,
    Nat.mul_div_cancel _ (by decide : 0 < unit)]

@[simp] theorem integer_of_lt (r : Rounding) (n : Nat) (h : n < 2^53) :
    integer r n = some n := by
  rw [integer, ite_eq_left h, integer_exact r n h, Nat.mul_div_cancel _ (by decide : 0 < unit)]

end Uuid58.Js
