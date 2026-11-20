import RustTables

open Aeneas Aeneas.Std Aeneas.Std.WP Result
namespace RustUuid58

/-- Granlund and Montgomery, "Division by Invariant Integers using Multiplication" (1994).
`m` is `2^k / d` rounded up by `e / d`. Multiplying by it divides exactly while `n * e < 2^k`. -/
theorem recip_div {n d m k e : Nat} (hd : 0 < d) (hm : d * m = 2^k + e) (he : n * e < 2^k) :
    n * m / 2^k = n / d := by
  have split := Nat.div_add_mod n d
  have small := Nat.mod_lt n hd
  have key : d * (n * m) = n * 2^k + n * e := by
    rw [← Nat.mul_assoc, Nat.mul_comm d n, Nat.mul_assoc, hm, Nat.mul_add]
  apply Nat.div_eq_of_lt_le
  · apply Nat.le_of_mul_le_mul_left _ hd
    rw [key, ← Nat.mul_assoc]
    exact Nat.le_trans (Nat.mul_le_mul_right _ (by omega)) (Nat.le_add_right _ _)
  · apply Nat.lt_of_mul_lt_mul_left (a := d)
    rw [key, ← Nat.mul_assoc]
    have bound : n * 2^k + n * e < (n + 1) * 2^k := by rw [Nat.add_mul, Nat.one_mul]; omega
    exact Nat.lt_of_lt_of_le bound (Nat.mul_le_mul_right _ (by rw [Nat.mul_add]; omega))

private theorem low_half (x : Std.U128) :
    (x &&& UScalar.cast .U128 core.num.U64.MAX).val = x.val % 2^64 := by
  rw [UScalar.val_and, show (UScalar.cast .U128 core.num.U64.MAX).val = 2^64 - 1 by rfl]
  exact Nat.and_two_pow_sub_one_eq_mod x.val 64

/-- The four partial products of the two halves add up to the high half of the product.
No intermediate sum exceeds it, so none overflows. -/
@[step] private theorem mul_high_correct (x y : Std.U128) :
    mul_high x y ⦃ r => r.val = x.val * y.val / 2^128 ⦄ := by
  unfold mul_high mul_high.LOW
  step as ⟨x1, hx1⟩
  step as ⟨x0, hx0⟩
  step as ⟨y1, hy1⟩
  step as ⟨y0, hy0⟩
  rw [low_half] at hx0 hy0
  rw [Nat.shiftRight_eq_div_pow] at hx1 hy1
  have bx : x.val < 2^128 := by scalar_tac
  have by' : y.val < 2^128 := by scalar_tac
  have bx0 : x0.val ≤ 2^64 - 1 := by omega
  have by0 : y0.val ≤ 2^64 - 1 := by omega
  have bx1 : x1.val ≤ 2^64 - 1 := by omega
  have by1 : y1.val ≤ 2^64 - 1 := by omega
  have p00 := Nat.mul_le_mul bx0 by0
  have p01 := Nat.mul_le_mul bx0 by1
  have p10 := Nat.mul_le_mul bx1 by0
  have p11 := Nat.mul_le_mul bx1 by1
  have expand : x.val * y.val =
      x1.val * y1.val * 2^128 + (x0.val * y1.val + x1.val * y0.val) * 2^64 + x0.val * y0.val := by
    have hx : x.val = x1.val * 2^64 + x0.val := by omega
    have hy : y.val = y1.val * 2^64 + y0.val := by omega
    rw [hx, hy]
    ring
  step as ⟨i1, hi1⟩
  step as ⟨i2, hi2⟩
  step as ⟨i3, hi3⟩
  step as ⟨i4, hi4⟩
  rw [low_half] at hi4
  rw [Nat.shiftRight_eq_div_pow] at hi2
  step as ⟨i5, hi5⟩
  step as ⟨i6, hi6⟩
  step as ⟨i7, hi7⟩
  rw [low_half] at hi7
  step as ⟨cross, hcross⟩
  step as ⟨i8, hi8⟩
  step as ⟨i9, hi9⟩
  rw [Nat.shiftRight_eq_div_pow] at hi9
  step as ⟨i10, hi10⟩
  step as ⟨i11, hi11⟩
  rw [Nat.shiftRight_eq_div_pow] at hi11
  step as ⟨i12, hi12⟩
  step as ⟨i13, hi13⟩
  rw [Nat.shiftRight_eq_div_pow] at hi13
  have total : i12.val + i13.val = x.val * y.val / 2^128 := by rw [expand]; omega
  have fits : x.val * y.val / 2^128 < 2^128 := by
    apply Nat.div_lt_of_lt_mul
    exact Nat.mul_lt_mul'' bx by'
  step as ⟨r, hr⟩
  omega

/-- `58^10 = 2^10 * 29^10`: shift by ten bits, then divide by `29^10` with its reciprocal. -/
@[step] private theorem div_chunk_correct (v : Std.U128) :
    div_chunk v ⦃ r => r.val = v.val / Uuid58.chunk ⦄ := by
  unfold div_chunk CHUNK_ODD_RECIPROCAL
  step as ⟨n, hn⟩
  step as ⟨p, hp⟩
  step as ⟨r, hr⟩
  rw [Nat.shiftRight_eq_div_pow] at hn hr
  have bv : v.val < 2^128 := by scalar_tac
  have small : n.val < 2^118 := by omega
  have exact := recip_div (n := n.val) (d := 29^10) (m := 444661262681138210456988474620035424)
    (k := 167) (e := 146471680819296) (by decide) (by decide) (by omega)
  change p.val = n.val * 444661262681138210456988474620035424 / 2^128 at hp
  unfold Uuid58.chunk
  omega

/-- What `write_half` reads off its fixed-point number: the integer part, then the same
of the fraction times 58. -/
def fixedDigits : Nat → Nat → List Nat
  | 0, _ => []
  | n+1, t => t / 2^58 :: fixedDigits n (t % 2^58 * 58)

private def symbolAt (d : Nat) : Std.U8 := symbolTable[d]!

/-- After writing `n` digits, the bytes outside their interval retain their original values. -/
private theorem write_half_loop_correct (n : Nat) (t : Std.U64) (out : Array Std.U8 22#usize)
    (i stop : Std.Usize) (hpos : stop.val = i.val + n) (hend : stop.val ≤ 22) :
    write_half_loop out t stop i ⦃ a => a.val = out.val.take i.val ++
      (fixedDigits n t.val).map symbolAt ++ out.val.drop stop.val ⦄ := by
  induction n generalizing t out i with
  | zero =>
    rw [write_half_loop]
    have hs : ¬ i < stop := by scalar_tac
    simp [hs, fixedDigits, hpos]
  | succ n ih =>
    rw [write_half_loop]
    have hs : i < stop := by scalar_tac
    simp only [ite_eq_left hs]
    unfold FRACTION_BITS
    have bt : t.val < 2^64 := by scalar_tac
    step as ⟨table, htable⟩
    step as ⟨top, htop⟩
    rw [Nat.shiftRight_eq_div_pow] at htop
    step with UScalar.cast_inBounds_spec as ⟨idx, hidx⟩
    step as ⟨symbol, hsymbol⟩
    have hsym : symbol = symbolAt (t.val / 2^58) := by
      have inTable : idx.val < table.val.length := by scalar_tac
      rw [hsymbol, symbolAt, ← htop, ← hidx, ← htable, getElem!_pos table.val idx.val inTable]
    step as ⟨out', hout⟩
    rw [show (1#u64 <<< 58#u32) = ok 288230376151711744#u64 by rfl]
    simp only [bind_ok]
    step as ⟨mask, hmask⟩
    step as ⟨fraction, hfraction⟩
    have hfrac : fraction.val = t.val % 2^58 := by
      rw [hfraction, UScalar.val_and, show mask.val = 2^58 - 1 by scalar_tac]
      exact Nat.and_two_pow_sub_one_eq_mod t.val 58
    step as ⟨next, hnext⟩
    step as ⟨j, hj⟩
    apply spec_mono (ih next out' j (by omega) )
    intro result hr
    have inside : i.val < out.val.length := by scalar_tac
    rw [hr, hout, Array.set_val_eq, hj, List.take_succ_eq_append_getElem (by simpa using inside),
      List.take_set_of_le (Nat.le_refl _), List.getElem_set_self,
      List.drop_set_of_lt (by omega)]
    simp [fixedDigits, hsym, hnext, hfrac]

/-- Each step keeps the number modulo `58 * 2^58`, so digit `j` is the integer part of
`58^j * t / 2^58` modulo 58. -/
private theorem fixed_closed (n t : Nat) (ht : t < 58 * 2^58) :
    fixedDigits n t = (List.range n).map (fun j => 58^j * t / 2^58 % 58) := by
  induction n generalizing t with
  | zero => rfl
  | succ n ih =>
    have next : t % 2^58 * 58 < 58 * 2^58 := by omega
    rw [fixedDigits, ih _ next, List.range_succ_eq_map, List.map_cons, List.map_map]
    congr 1
    · simp only [Nat.pow_zero, Nat.one_mul]
      omega
    · apply List.map_congr_left
      intro j _
      have e1 : 58^j * (t % 2^58 * 58) = 58^(j+1) * (t % 2^58) := by ring
      have e2 : 58^(j+1) * t = 58^(j+1) * (t % 2^58) + 58 * (58^j * (t / 2^58)) * 2^58 := by
        have split := Nat.div_add_mod t (2^58)
        calc 58^(j+1) * t = 58^(j+1) * (2^58 * (t / 2^58) + t % 2^58) := by rw [split]
          _ = _ := by ring
      simp only [Function.comp_apply, Nat.succ_eq_add_one]
      rw [e1, e2, Nat.add_mul_div_right _ _ (by decide), Nat.add_mul_mod_self_left]

/-- The reciprocal of `58^4` exceeds `2^58 / 58^4` by less than `2^-34`, which is too little
to change any of the five digits of a number below `58^5`. -/
private theorem half_digits (v : Nat) (hv : v < 58^5) :
    fixedDigits 5 (v * (2^58 / 58^4 + 1)) = (Uuid58.digits 5 v).map (·.val) := by
  have exact (j : Nat) (hj : j ≤ 4) :
      58^j * (v * (2^58 / 58^4 + 1)) / 2^58 = v / 58^(4-j) := by
    rw [Nat.mul_left_comm]
    apply recip_div (e := 305888) (Nat.pow_pos (by decide))
    · have cases : j = 0 ∨ j = 1 ∨ j = 2 ∨ j = 3 ∨ j = 4 := by omega
      rcases cases with rfl | rfl | rfl | rfl | rfl <;> decide
    · omega
  rw [fixed_closed _ _ (by omega)]
  simp only [show List.range 5 = [0, 1, 2, 3, 4] by decide, List.map_cons, List.map_nil,
    exact 0 (by decide), exact 1 (by decide), exact 2 (by decide), exact 3 (by decide),
    exact 4 (by decide), Uuid58.digits]
  simp only [List.cons.injEq, and_true, true_and, Nat.reduceSub, Nat.reducePow, Nat.div_one]
  omega

/-- Writing `b` right after `a` is writing `a ++ b`. -/
private theorem splice_append {α : Type} (xs a b : List α) (p : Nat) (h : p ≤ xs.length) :
    (xs.take p ++ a ++ xs.drop (p + a.length)).take (p + a.length) ++ b ++
      (xs.take p ++ a ++ xs.drop (p + a.length)).drop (p + a.length + b.length) =
    xs.take p ++ (a ++ b) ++ xs.drop (p + a.length + b.length) := by
  have lp : (xs.take p ++ a).length = p + a.length := by
    rw [List.length_append, List.length_take, Nat.min_eq_left h]
  rw [List.take_left' lp, ← lp, List.drop_length_add_append, List.drop_drop, lp]
  simp only [List.append_assoc]

@[step] private theorem write_half_correct (v : Std.U64) (out : Array Std.U8 22#usize)
    (pos : Std.Usize) (hv : v.val < 58^5) (hpos : pos.val + 5 ≤ 22) :
    write_half v out pos ⦃ a => a.val = out.val.take pos.val ++
      (Uuid58.digits 5 v.val).map ofDigit ++ out.val.drop (pos.val + 5) ⦄ := by
  unfold write_half
  step as ⟨recip, hrecip⟩
  have fits : v.val * recip.val < 2^64 := by rw [hrecip]; omega
  step as ⟨t, ht⟩
  step as ⟨stop, hstop⟩
  apply spec_mono (write_half_loop_correct 5 t out pos stop (by omega) (by omega))
  intro a ha
  rw [ha, ht, hrecip, half_digits _ hv, hstop, List.map_map]
  congr 2
  apply List.map_congr_left
  intro d _
  exact symbol_lookup d

@[step] private theorem write_chunk_correct (v : Std.U64) (out : Array Std.U8 22#usize)
    (pos : Std.Usize) (hv : v.val < Uuid58.chunk) (hpos : pos.val + 10 ≤ 22) :
    write_chunk v out pos ⦃ a => a.val = out.val.take pos.val ++
      (Uuid58.digits 10 v.val).map ofDigit ++ out.val.drop (pos.val + 10) ⦄ := by
  unfold write_chunk HALF
  have bound : v.val < 58^10 := hv
  step as ⟨high, hhigh⟩
  have highFits : high.val < 58^5 := by omega
  step as ⟨out1, hout1⟩
  step as ⟨low, hlow⟩
  have lowFits : low.val < 58^5 := by omega
  step as ⟨pos2, hpos2⟩
  step as ⟨out2, hout2⟩
  have len : out.val.length = 22 := by scalar_tac
  have joined := splice_append out.val ((Uuid58.digits 5 high.val).map ofDigit)
    ((Uuid58.digits 5 low.val).map ofDigit) pos.val (by omega)
  simp only [List.length_map, Uuid58.length_digits] at joined
  rw [hout2, hout1, hpos2, joined, ← List.map_append, hhigh, hlow,
    show (656356768 : Nat) = 58^5 by decide, Uuid58.digits_append 5 5 v.val hv, Nat.add_assoc]

/-- For every `u128` and every initial buffer, the encoder writes the specified 22 bytes. -/
theorem encode_correct (v : Std.U128) (out : Array Std.U8 22#usize) :
    encode_into v out ⦃ a => a.val.map toByte = Uuid58.encode v.bv.toFin ⦄ := by
  unfold encode_into CHUNK
  have bv : v.val < 2^128 := by scalar_tac
  step as ⟨rest, hrest⟩
  unfold Uuid58.chunk at hrest
  step as ⟨c, hc⟩
  have below : rest.val * c.val ≤ v.val := by rw [hrest, hc]; exact Nat.div_mul_le_self _ _
  step as ⟨product, hproduct⟩
  step as ⟨remainder, hremainder⟩
  step with UScalar.cast_inBounds_spec as ⟨lo, hlo⟩
  step as ⟨shifted, hshifted⟩
  rw [Nat.shiftRight_eq_div_pow] at hshifted
  step with UScalar.cast_inBounds_spec as ⟨narrow, hnarrow⟩
  step as ⟨odd, hodd⟩
  step as ⟨hi, hhi⟩
  rw [hodd] at hhi
  rw [hc] at hproduct
  step as ⟨hi', hhi'⟩
  step as ⟨c', hc'⟩
  have below' : hi'.val * c'.val ≤ rest.val := by
    rw [hhi', hc', hhi, hnarrow, hshifted]
    omega
  step as ⟨product', hproduct'⟩
  rw [hc'] at hproduct'
  step as ⟨remainder', hremainder'⟩
  step with UScalar.cast_inBounds_spec as ⟨mid, hmid⟩
  have hiVal : hi.val = v.val / Uuid58.chunk / Uuid58.chunk := by unfold Uuid58.chunk; omega
  have midVal : mid.val = v.val / Uuid58.chunk % Uuid58.chunk := by unfold Uuid58.chunk; omega
  have loVal : lo.val = v.val % Uuid58.chunk := by unfold Uuid58.chunk; omega
  step as ⟨table, htable⟩
  step as ⟨d0, hd0⟩
  step with UScalar.cast_inBounds_spec as ⟨i0, hi0⟩
  step as ⟨masked, hmasked⟩
  have firstIndex : masked.val = hi.val / 58 := by
    rw [hmasked, UScalar.val_and, hi0, hd0]
    change hi.val / 58 &&& 2^6 - 1 = _
    rw [Nat.and_two_pow_sub_one_eq_mod]
    unfold Uuid58.chunk at hiVal
    omega
  step as ⟨s0, hs0⟩
  step as ⟨out1, hout1⟩
  step as ⟨d1, hd1⟩
  step with UScalar.cast_inBounds_spec as ⟨i1, hi1⟩
  step as ⟨s1, hs1⟩
  step as ⟨out2, hout2⟩
  have hiSmall : hi.val < 58^2 := by unfold Uuid58.chunk at hiVal; omega
  step as ⟨out3, hout3⟩
  step as ⟨out4, hout4⟩
  have len : out.val.length = 22 := by scalar_tac
  have tableLen : table.val.length = 64 := by simp
  have e0 : s0 = ofDigit ⟨hi.val / 58, by omega⟩ := by
    rw [hs0, ← getElem!_pos table.val masked.val (by omega), htable, firstIndex]
    exact symbol_lookup ⟨hi.val / 58, by omega⟩
  have e1 : s1 = ofDigit ⟨hi.val % 58, by omega⟩ := by
    rw [hs1, ← getElem!_pos table.val i1.val (by omega), htable, hi1, hd1]
    exact symbol_lookup ⟨hi.val % 58, by omega⟩
  have heads : out2.val.take 2 = (Uuid58.digits 2 hi.val).map ofDigit := by
    have d0 : (⟨hi.val / 58^1 % 58, Nat.mod_lt _ (by decide)⟩ : Uuid58.Digit) =
        ⟨hi.val / 58, by omega⟩ :=
      Fin.ext (show hi.val / 58^1 % 58 = hi.val / 58 by omega)
    have d1 : (⟨hi.val % 58^1 / 58^0 % 58, Nat.mod_lt _ (by decide)⟩ : Uuid58.Digit) =
        ⟨hi.val % 58, by omega⟩ :=
      Fin.ext (show hi.val % 58^1 / 58^0 % 58 = hi.val % 58 by omega)
    rw [hout2, hout1, Array.set_val_eq, Array.set_val_eq, e0, e1]
    simp only [Uuid58.digits, List.map_cons, List.map_nil, d0, d1]
    rcases hl : out.val with _ | ⟨x0, _ | ⟨x1, tail⟩⟩
    · simp [hl] at len
    · simp [hl] at len
    · simp
  have joined : (out2.val.take 2 ++ (Uuid58.digits 10 mid.val).map ofDigit ++ out2.val.drop 12).take 12 ++
        (Uuid58.digits 10 lo.val).map ofDigit ++
        (out2.val.take 2 ++ (Uuid58.digits 10 mid.val).map ofDigit ++ out2.val.drop 12).drop 22 =
      out2.val.take 2 ++ ((Uuid58.digits 10 mid.val).map ofDigit ++ (Uuid58.digits 10 lo.val).map ofDigit) ++
        out2.val.drop 22 := by
    have general := splice_append out2.val ((Uuid58.digits 10 mid.val).map ofDigit)
      ((Uuid58.digits 10 lo.val).map ofDigit) 2 (by scalar_tac)
    simp only [List.length_map, Uuid58.length_digits] at general
    exact general
  have written : out4.val = (Uuid58.digits 2 hi.val ++ Uuid58.digits 10 mid.val ++
      Uuid58.digits 10 lo.val).map ofDigit := by
    have ends : out2.val.drop 22 = [] := List.drop_eq_nil_of_le (by scalar_tac)
    rw [hout4, hout3]
    change (out2.val.take 2 ++ (Uuid58.digits 10 mid.val).map ofDigit ++ out2.val.drop 12).take 12 ++
        (Uuid58.digits 10 lo.val).map ofDigit ++
        (out2.val.take 2 ++ (Uuid58.digits 10 mid.val).map ofDigit ++ out2.val.drop 12).drop 22 = _
    rw [joined, ends, heads, List.append_nil, List.map_append, List.map_append, List.append_assoc]
  rw [written, List.map_map, hiVal, midVal, loVal]
  change List.map Uuid58.symbol _ = List.map Uuid58.symbol _
  exact congrArg (List.map Uuid58.symbol) (Uuid58.split_encode v.bv.toFin)

end RustUuid58
