import Proofs

/-! Arithmetic used by the Rust implementation's 2 + 10 + 10 split. -/
namespace Uuid58

theorem value_append (xs ys : List Digit) :
    value (xs ++ ys) = value xs * 58^ys.length + value ys := by
  induction xs with
  | nil => simp [value]
  | cons d ds ih =>
    simp [value, ih, Nat.pow_add, Nat.add_mul, Nat.mul_assoc, Nat.add_assoc]

theorem value_fold (ds : List Digit) (acc : Nat) :
    ds.foldl (fun a d => a * 58 + d.val) acc = acc * 58^ds.length + value ds := by
  induction ds generalizing acc with
  | nil => simp [value]
  | cons d ds ih =>
    simp [value, ih, Nat.pow_succ', Nat.add_mul, Nat.mul_assoc, Nat.add_assoc]

theorem digits_snoc (k n : Nat) (h : n < 58^(k+1)) :
    digits k (n / 58) ++ [⟨n % 58, Nat.mod_lt _ (by decide)⟩] = digits (k+1) n := by
  let ds := digits k (n / 58) ++ [⟨n % 58, Nat.mod_lt _ (by decide)⟩]
  have hl : ds.length = k+1 := by simp [ds]
  have hq : n / 58 < 58^k := (Nat.div_lt_iff_lt_mul (by decide)).2 (by simpa [Nat.pow_succ] using h)
  have hv : value ds = n := by
    simp [ds, value_append, value, value_digits _ _ hq, Nat.div_add_mod, Nat.mul_comm]
  simpa only [hl, hv] using (digits_value ds).symm

/-- Any split of the digits: the leading `a` digits and the trailing `b`. -/
theorem digits_append (a b n : Nat) (h : n < 58^(a+b)) :
    digits a (n / 58^b) ++ digits b (n % 58^b) = digits (a+b) n := by
  let ds := digits a (n / 58^b) ++ digits b (n % 58^b)
  have hl : ds.length = a+b := by simp [ds]
  have p : 0 < 58^b := Nat.pow_pos (by decide)
  have hq : n / 58^b < 58^a := (Nat.div_lt_iff_lt_mul p).2 (by simpa [Nat.pow_add] using h)
  have hv : value ds = n := by
    simp only [ds, value_append, length_digits, value_digits _ _ hq, value_digits _ _ (Nat.mod_lt _ p)]
    exact Nat.div_add_mod' n (58^b)
  simpa only [hl, hv] using (digits_value ds).symm

abbrev chunk : Nat := 58^10

theorem split_encode (v : UUID) :
    digits 2 (v.val / chunk / chunk) ++ digits 10 (v.val / chunk % chunk) ++
      digits 10 (v.val % chunk) = digits 22 v.val := by
  let hi := v.val / chunk / chunk
  let mid := v.val / chunk % chunk
  let lo := v.val % chunk
  let ds := digits 2 hi ++ digits 10 mid ++ digits 10 lo
  have hHi : hi < 58^2 := by
    have := v.isLt
    dsimp [hi, chunk]; omega
  have hMid : mid < chunk := Nat.mod_lt _ (by decide)
  have hLo : lo < chunk := Nat.mod_lt _ (by decide)
  have hl : ds.length = 22 := by simp [ds]
  have hv : value ds = v.val := by
    simp only [ds, value_append, length_digits, value_digits _ _ hHi,
      value_digits _ _ hMid, value_digits _ _ hLo]
    dsimp [hi, mid, lo, chunk]
    omega
  simpa only [hl, hv] using (digits_value ds).symm

theorem join_decode (hi mid lo : List Digit) (hm : mid.length = 10) (hl : lo.length = 10) :
    value (hi ++ mid ++ lo) = (value hi * chunk + value mid) * chunk + value lo := by
  simp only [value_append, hm, hl, chunk]

end Uuid58
