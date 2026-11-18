import RustTables

open Aeneas Aeneas.Std Aeneas.Std.WP Result
namespace RustUuid58

@[step] private theorem symbol_correct (i : Std.Usize) (h : i.val < 58) :
    digit_symbol i ⦃ b => b = ofDigit ⟨i.val, h⟩ ⦄ := by
  unfold digit_symbol
  step as ⟨b, hb⟩
  subst b
  simp [ofDigit, Uuid58.symbol, alphabet_eq, ofByte, show Uuid58.alphabet.length = 58 by decide, h]

private theorem drop_set_here (xs : List α) (i : Nat) (x : α) (h : i < xs.length) :
    (xs.set i x).drop i = x :: xs.drop (i+1) := by
  rw [List.drop_eq_getElem_cons (l := xs.set i x) (by simpa using h),
      List.drop_set_of_lt (by omega)]
  simp

/-- After writing this chunk, the bytes outside its interval retain their original values. -/
private theorem write_loop_correct (n : Nat) (v : Std.U64) (out : Array Std.U8 22#usize)
    (start stop : Std.Usize) (hpos : stop.val = start.val + n)
    (hend : stop.val ≤ 22) (hv : v.val < 58^n) :
    write_digits_loop v out start stop ⦃ a => a.val = out.val.take start.val ++
      (Uuid58.digits n v.val).map ofDigit ++ out.val.drop stop.val ⦄ := by
  induction n generalizing v out stop with
  | zero =>
    rw [write_digits_loop]
    have hs : ¬ stop > start := by scalar_tac
    simp [hs, Uuid58.digits, hpos]
  | succ n ih =>
    rw [write_digits_loop]
    have hs : stop > start := by scalar_tac
    simp only [ite_eq_left hs]
    step as ⟨j, hj⟩
    step as ⟨remn, hrem⟩
    step with UScalar.cast_inBounds_spec as ⟨idx, hidx⟩
    step as ⟨b, hb⟩
    step as ⟨next, hn⟩
    step as ⟨q, hq⟩
    have hv' : q.val < 58^n := by
      rw [hq]; exact (Nat.div_lt_iff_lt_mul (by decide)).2 (by simpa [Nat.pow_succ] using hv)
    apply spec_mono (ih q next j (by omega) (by omega) hv')
    intro result hr
    subst next b
    rw [hr, Array.set_val_eq, List.take_set_of_le (by omega), drop_set_here _ _ _ (by scalar_tac)]
    rw [← Uuid58.digits_snoc _ _ hv]
    simp [hq, hidx, hrem, List.append_assoc, show j.val + 1 = stop.val by omega]

@[step] private theorem write_correct (v : Std.U64) (out : Array Std.U8 22#usize)
    (start stop : Std.Usize) (hs : start.val ≤ stop.val) (he : stop.val ≤ 22)
    (h : v.val < 58^(stop.val-start.val)) :
    write_digits v out start stop ⦃ a => a.val = out.val.take start.val ++
      (Uuid58.digits (stop.val-start.val) v.val).map ofDigit ++ out.val.drop stop.val ⦄ :=
  write_loop_correct _ v out start stop (by omega) he h

theorem encode_correct (v : Std.U128) :
    encode_array v ⦃ a => a.val.map toByte = Uuid58.encode v.bv.toFin ⦄ := by
  unfold encode_array CHUNK
  step as ⟨c, hc⟩
  step as ⟨l, hl⟩
  step with UScalar.cast_inBounds_spec as ⟨lo, hlo⟩
  step as ⟨r, hr⟩
  step as ⟨m, hm⟩
  step with UScalar.cast_inBounds_spec as ⟨mid, hmid⟩
  step as ⟨d, hd⟩
  step with UScalar.cast_inBounds_spec as ⟨hi, hhi⟩
  step as ⟨a, ha⟩
  step as ⟨b, hb⟩
  step as ⟨out, hout⟩
  have written : out.val = ((Uuid58.digits 2 hi.val ++ Uuid58.digits 10 mid.val ++
      Uuid58.digits 10 lo.val).map ofDigit) := by
    simp [hout, hb, ha, List.take_append, List.drop_append, List.append_assoc]
  rw [written, List.map_map]
  change List.map Uuid58.symbol _ = List.map Uuid58.symbol _
  apply congrArg (List.map Uuid58.symbol)
  have hc' : c.val = Uuid58.chunk := hc
  rw [hhi, hd, hmid, hm, hr, hlo, hl, hc']
  exact Uuid58.split_encode v.bv.toFin

end RustUuid58
