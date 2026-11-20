import RustTables

open Aeneas Aeneas.Std Aeneas.Std.WP Result
namespace RustUuid58

abbrev Decoded := core.result.Result Std.U128 RustUuid58.Error

private def checked (n : Nat) : Decoded :=
  if h : n < 2^128 then .Ok ⟨⟨⟨n, h⟩⟩⟩ else .Err .Overflow

private theorem join_correct (hi mid lo : Std.U64) (hh : hi.val < 58^2) (hm : mid.val < Uuid58.chunk) :
    join_chunks hi mid lo ⦃ r => r = checked ((hi.val * Uuid58.chunk + mid.val) * Uuid58.chunk + lo.val) ⦄ := by
  unfold join_chunks CHUNK
  step as ⟨h, hhi⟩
  step as ⟨c, hc⟩
  step as ⟨first, hf⟩
  step as ⟨m, hmid⟩
  step as ⟨p, hp⟩
  step as ⟨c', hc'⟩
  have hmul := U128.checked_mul_bv_spec p c'
  cases heq : U128.checked_mul p c' with
  | none =>
    rw [heq] at hmul
    simp only [lift, bind_ok, spec_ok]
    have hov : ¬(hi.val * Uuid58.chunk + mid.val) * Uuid58.chunk + lo.val < 2^128 := by
      simp only [U128.max_eq, hp, hf, hhi, hc, hmid, hc'] at hmul
      unfold Uuid58.chunk; omega
    rw [checked, dite_eq_right hov]
  | some shifted =>
    rw [heq] at hmul
    simp only [lift, bind_ok]
    let low := core.convert.num.FromU128U64.from lo
    have hadd := U128.checked_add_bv_spec shifted low
    cases ea : U128.checked_add shifted low with
    | none =>
      rw [ea] at hadd
      simp only [spec_ok]
      have hov : ¬(hi.val * Uuid58.chunk + mid.val) * Uuid58.chunk + lo.val < 2^128 := by
        simp only [U128.max_eq, low, core.convert.num.FromU128U64.from_val_eq, hmul.2.1, hp, hf,
          hhi, hc, hmid, hc'] at hadd
        unfold Uuid58.chunk; omega
      rw [checked, dite_eq_right hov]
    | some result =>
      rw [ea] at hadd
      simp only [spec_ok]
      have hn : result.val = (hi.val * Uuid58.chunk + mid.val) * Uuid58.chunk + lo.val := by
        simpa only [low, core.convert.num.FromU128U64.from_val_eq, hmul.2.1, hp, hf,
          hhi, hc, hmid, hc'] using hadd.2.1
      rw [← hn]
      have hr : result.val < 2^128 := result.bv.isLt
      rw [checked, dite_eq_left hr]
      rfl

/-- Express the three specified errors and a successful UUID in the Rust result type. -/
def rustResult : Except Uuid58.Error Uuid58.UUID → Decoded
  | .error .invalidLength => .Err .InvalidLength
  | .error .invalidCharacter => .Err .InvalidCharacter
  | .error .overflow => .Err .Overflow
  | .ok v => .Ok ⟨⟨v⟩⟩

/-- The table entry of a byte: its digit value, or the marker for a byte outside the alphabet. -/
def digitValue (b : Uuid58.Byte) : Nat :=
  match Uuid58.digit? b with
  | none => 2^31
  | some d => d.val

@[step] private theorem digit_correct (input : Array Std.U8 22#usize) (pos : Std.Usize)
    (h : pos.val < 22) :
    digit input pos ⦃ r => r.val = digitValue (toByte input.val[pos.val]!) ⦄ := by
  unfold digit
  step as ⟨table, htable⟩
  step as ⟨b, hb⟩
  step as ⟨idx, hidx⟩
  step as ⟨d, hd⟩
  have inInput : pos.val < input.val.length := by scalar_tac
  have entry : d = digitTable[(toByte input.val[pos.val]!).val]! := by
    rw [← htable, getElem!_pos input.val pos.val inInput, ← hb]
    change d = table.val[b.val]!
    rw [getElem!_pos table.val b.val (by scalar_tac)]
    simpa only [hidx] using hd
  rw [lookup_correct] at entry
  simp only [core.convert.num.FromU64U32.from_val_eq, entry, digitValue]
  cases Uuid58.digit? (toByte input.val[pos.val]!) with
  | none => rfl
  | some digit =>
    change digit.val % 2^32 = digit.val
    exact Nat.mod_eq_of_lt (by omega)

/-- Five table entries weighted like five digits. -/
def half (x : Nat → Uuid58.Byte) (p : Nat) : Nat :=
  digitValue (x p) * 58^4 + digitValue (x (p+1)) * 58^3 + digitValue (x (p+2)) * 58^2 +
    digitValue (x (p+3)) * 58 + digitValue (x (p+4))

def segment (x : Nat → Uuid58.Byte) (p : Nat) : List Uuid58.Byte :=
  [x p, x (p+1), x (p+2), x (p+3), x (p+4)]

private theorem digitValue_le (b : Uuid58.Byte) : digitValue b ≤ 2^31 := by
  unfold digitValue
  split <;> omega

@[step] private theorem read_half_correct (input : Array Std.U8 22#usize) (pos : Std.Usize)
    (h : pos.val + 5 ≤ 22) :
    read_half input pos ⦃ r => r.val = half (fun i => toByte input.val[i]!) pos.val ⦄ := by
  unfold read_half HALF_LEAD
  have b0 := digitValue_le (toByte input.val[pos.val]!)
  have b1 := digitValue_le (toByte input.val[pos.val + 1]!)
  have b2 := digitValue_le (toByte input.val[pos.val + 2]!)
  have b3 := digitValue_le (toByte input.val[pos.val + 3]!)
  have b4 := digitValue_le (toByte input.val[pos.val + 4]!)
  step as ⟨d0, h0⟩
  step as ⟨t0, ht0⟩
  step as ⟨p1, hp1⟩
  step as ⟨d1, h1⟩
  rw [hp1] at h1
  step as ⟨w2, hw2⟩
  step as ⟨w3, hw3⟩
  rw [hw2] at hw3
  have t1Fits : d1.val * w3.val ≤ 2^31 * (58 * 58 * 58) := by
    rw [hw3, h1]; exact Nat.mul_le_mul_right _ b1
  step as ⟨t1, ht1⟩
  rw [hw3] at ht1
  step as ⟨s1, hs1⟩
  step as ⟨p2, hp2⟩
  step as ⟨d2, h2⟩
  rw [hp2] at h2
  have t2Fits : d2.val * w2.val ≤ 2^31 * (58 * 58) := by
    rw [hw2, h2]; exact Nat.mul_le_mul_right _ b2
  step as ⟨t2, ht2⟩
  rw [hw2] at ht2
  step as ⟨s2, hs2⟩
  step as ⟨p3, hp3⟩
  step as ⟨d3, h3⟩
  rw [hp3] at h3
  step as ⟨t3, ht3⟩
  step as ⟨s3, hs3⟩
  step as ⟨p4, hp4⟩
  step as ⟨d4, h4⟩
  rw [hp4] at h4
  step as ⟨r, hr⟩
  simp only [half]
  omega

private def horner (acc : Nat) (xs : List Uuid58.Byte) : Nat :=
  xs.foldl (fun a b => a * 58 + digitValue b) acc

private theorem horner_ge (xs : List Uuid58.Byte) (acc : Nat) : acc ≤ horner acc xs := by
  induction xs generalizing acc with
  | nil => exact Nat.le_refl _
  | cons b bs ih => exact Nat.le_trans (by omega) (ih (acc * 58 + digitValue b))

/-- A character outside the alphabet lifts the sum to the marker. -/
private theorem horner_none (xs : List Uuid58.Byte) (acc : Nat) (h : Uuid58.parse xs = none) :
    2^31 ≤ horner acc xs := by
  induction xs generalizing acc with
  | nil => simp [Uuid58.parse] at h
  | cons b bs ih =>
    cases hb : Uuid58.digit? b with
    | none =>
      have marked : digitValue b = 2^31 := by simp [digitValue, hb]
      exact Nat.le_trans (by omega) (horner_ge bs (acc * 58 + digitValue b))
    | some d =>
      cases hbs : Uuid58.parse bs with
      | none => exact ih _ hbs
      | some ds => simp [Uuid58.parse, hb, hbs] at h

/-- Otherwise the sum is the value of the digits. -/
private theorem horner_some (xs : List Uuid58.Byte) (acc : Nat) (ds : List Uuid58.Digit)
    (h : Uuid58.parse xs = some ds) :
    horner acc xs = acc * 58^ds.length + Uuid58.value ds ∧ ds.length = xs.length := by
  induction xs generalizing acc ds with
  | nil =>
    simp [Uuid58.parse] at h
    subst h
    simp [horner, Uuid58.value]
  | cons b bs ih =>
    cases hb : Uuid58.digit? b with
    | none => simp [Uuid58.parse, hb] at h
    | some d =>
      cases hbs : Uuid58.parse bs with
      | none => simp [Uuid58.parse, hb, hbs] at h
      | some rest =>
        simp [Uuid58.parse, hb, hbs] at h
        subst h
        have entry : digitValue b = d.val := by simp [digitValue, hb]
        obtain ⟨sum, len⟩ := ih (acc * 58 + d.val) rest hbs
        refine ⟨?_, by simp [len]⟩
        change horner (acc * 58 + digitValue b) bs = _
        rw [entry, sum]
        simp only [Uuid58.value, List.length_cons, Nat.pow_succ]
        ring

private theorem half_horner (x : Nat → Uuid58.Byte) (p : Nat) : half x p = horner 0 (segment x p) := by
  simp only [half, horner, segment, List.foldl_cons, List.foldl_nil]
  omega

private theorem half_parse (x : Nat → Uuid58.Byte) (p : Nat) :
    match Uuid58.parse (segment x p) with
    | none => 2^31 ≤ half x p
    | some ds => half x p = Uuid58.value ds ∧ ds.length = 5 := by
  rw [half_horner]
  cases h : Uuid58.parse (segment x p) with
  | none => exact horner_none _ 0 h
  | some ds =>
    obtain ⟨sum, len⟩ := horner_some _ 0 ds h
    exact ⟨by simpa using sum, by simpa [segment] using len⟩

private theorem pair_parse (a b : Uuid58.Byte) :
    match Uuid58.parse [a, b] with
    | none => 2^31 ≤ digitValue a ∨ 2^31 ≤ digitValue b
    | some ds => digitValue a * 58 + digitValue b = Uuid58.value ds ∧ ds.length = 2 ∧
        digitValue a < 58 ∧ digitValue b < 58 := by
  unfold digitValue
  cases h0 : Uuid58.digit? a <;> cases h1 : Uuid58.digit? b <;>
    simp [Uuid58.parse, h0, h1, Uuid58.value]

theorem or_lt_two_pow_iff (a b n : Nat) : a ||| b < 2^n ↔ a < 2^n ∧ b < 2^n :=
  ⟨fun h => ⟨Nat.lt_of_le_of_lt Nat.left_le_or h, Nat.lt_of_le_of_lt Nat.right_le_or h⟩,
    fun h => Nat.or_lt_two_pow h.1 h.2⟩

private theorem explode (l : List Std.U8) (h : l.length = 22) :
    l.map toByte = [toByte l[0]!, toByte l[1]!] ++ segment (fun i => toByte l[i]!) 2 ++
      segment (fun i => toByte l[i]!) 7 ++ segment (fun i => toByte l[i]!) 12 ++
      segment (fun i => toByte l[i]!) 17 := by
  have enumerate : l = (List.range 22).map (fun i => l[i]!) := by
    apply List.ext_getElem (by simp [h])
    intro i hi _
    simp only [List.getElem_map, List.getElem_range, getElem!_pos l i hi]
  conv_lhs => rw [enumerate]
  rfl

private theorem half_iff (x : Nat → Uuid58.Byte) (p : Nat) :
    half x p < 2^31 ↔ (Uuid58.parse (segment x p)).isSome := by
  have h := half_parse x p
  cases e : Uuid58.parse (segment x p) with
  | none =>
    simp only [e] at h
    simp only [Option.isSome_none, Bool.false_eq_true, iff_false]
    omega
  | some ds =>
    simp only [e] at h
    have small := Uuid58.value_lt ds
    rw [h.2] at small
    simp only [Option.isSome_some, iff_true]
    omega

private theorem pair_iff (a b : Uuid58.Byte) :
    (digitValue a < 2^31 ∧ digitValue b < 2^31) ↔ (Uuid58.parse [a, b]).isSome := by
  have h := pair_parse a b
  cases e : Uuid58.parse [a, b] with
  | none =>
    simp only [e] at h
    simp only [Option.isSome_none, Bool.false_eq_true, iff_false]
    omega
  | some ds =>
    simp only [e] at h
    simp only [Option.isSome_some, iff_true]
    omega

private def joinFive (a b c d e : Option (List Uuid58.Digit)) : Option (List Uuid58.Digit) :=
  match a, b, c, d, e with
  | some da, some d1, some d2, some d3, some d4 => some (da ++ d1 ++ d2 ++ d3 ++ d4)
  | _, _, _, _, _ => none

private theorem parse_five (a s1 s2 s3 s4 : List Uuid58.Byte) :
    Uuid58.parse (a ++ s1 ++ s2 ++ s3 ++ s4) = joinFive (Uuid58.parse a) (Uuid58.parse s1)
      (Uuid58.parse s2) (Uuid58.parse s3) (Uuid58.parse s4) := by
  simp only [Uuid58.parse_append, joinFive]
  cases Uuid58.parse a <;> cases Uuid58.parse s1 <;> cases Uuid58.parse s2 <;>
    cases Uuid58.parse s3 <;> cases Uuid58.parse s4 <;> rfl

private theorem joinFive_none (a b c d e : Option (List Uuid58.Digit))
    (h : ¬ ((((a.isSome ∧ b.isSome) ∧ c.isSome) ∧ d.isSome) ∧ e.isSome)) :
    joinFive a b c d e = none := by
  cases a <;> cases b <;> cases c <;> cases d <;> cases e <;> simp [joinFive] at h ⊢

/-- One comparison of the OR of the six sums decides whether all 22 bytes are in the alphabet. -/
private theorem decode_22 (input : Slice Std.U8) (hl : input.val.length = 22) :
    decode_value input ⦃ r => r = rustResult (Uuid58.decode (input.val.map toByte)) ⦄ := by
  have hlen : input.len = 22#usize := by apply UScalar.val_eq_imp; simpa using hl
  let x : Nat → Uuid58.Byte := fun i => toByte input.val[i]!
  have pa := pair_parse (x 0) (x 1)
  have p1 := half_parse x 2
  have p2 := half_parse x 7
  have p3 := half_parse x 12
  have p4 := half_parse x 17
  unfold decode_value
  simp only [core.array.TryFromSharedArraySlice.try_from, hlen, ↓reduceDIte, bind_ok]
  step as ⟨first, hfirst⟩
  step as ⟨second, hsecond⟩
  step as ⟨midHigh, hmidHigh⟩
  step as ⟨midLow, hmidLow⟩
  step as ⟨loHigh, hloHigh⟩
  step as ⟨loLow, hloLow⟩
  simp only [Array.from_val] at hfirst hsecond hmidHigh hmidLow hloHigh hloLow
  replace hfirst : first.val = digitValue (x 0) := hfirst
  replace hsecond : second.val = digitValue (x 1) := hsecond
  replace hmidHigh : midHigh.val = half x 2 := hmidHigh
  replace hmidLow : midLow.val = half x 7 := hmidLow
  replace hloHigh : loHigh.val = half x 12 := hloHigh
  replace hloLow : loLow.val = half x 17 := hloLow
  step as ⟨o1, ho1⟩
  step as ⟨o2, ho2⟩
  step as ⟨o3, ho3⟩
  step as ⟨o4, ho4⟩
  step as ⟨seen, hseen⟩
  rw [invalid_marker, bind_ok]
  step as ⟨limit, hlimit⟩
  have limitVal : limit.val = 2^31 := by rw [hlimit]; rfl
  have seenVal : seen.val = digitValue (x 0) ||| digitValue (x 1) ||| half x 2 ||| half x 7 |||
      half x 12 ||| half x 17 := by
    rw [hseen, UScalar.val_or, ho4, UScalar.val_or, ho3, UScalar.val_or, ho2, UScalar.val_or, ho1,
      UScalar.val_or, hfirst, hsecond, hmidHigh, hmidLow, hloHigh, hloLow]
  have bounded : seen.val < 2^31 ↔ ((((Uuid58.parse [x 0, x 1]).isSome ∧
      (Uuid58.parse (segment x 2)).isSome) ∧ (Uuid58.parse (segment x 7)).isSome) ∧
      (Uuid58.parse (segment x 12)).isSome) ∧ (Uuid58.parse (segment x 17)).isSome := by
    rw [seenVal]
    simp only [or_lt_two_pow_iff, half_iff, pair_iff]
  have total : ([x 0, x 1] ++ segment x 2 ++ segment x 7 ++ segment x 12 ++ segment x 17).length = 22 := by
    simp [segment]
  rw [show input.val.map toByte = [x 0, x 1] ++ segment x 2 ++ segment x 7 ++ segment x 12 ++
    segment x 17 from explode input.val hl]
  simp only [Uuid58.decode, total, ne_eq, not_true_eq_false, ↓reduceIte, parse_five]
  by_cases valid : seen.val < 2^31
  · have below : ¬ seen ≥ limit := by scalar_tac
    rw [ite_eq_right below]
    obtain ⟨⟨⟨⟨sa, s1⟩, s2⟩, s3⟩, s4⟩ := bounded.mp valid
    obtain ⟨da, ea⟩ := Option.isSome_iff_exists.mp sa
    obtain ⟨d1, e1⟩ := Option.isSome_iff_exists.mp s1
    obtain ⟨d2, e2⟩ := Option.isSome_iff_exists.mp s2
    obtain ⟨d3, e3⟩ := Option.isSome_iff_exists.mp s3
    obtain ⟨d4, e4⟩ := Option.isSome_iff_exists.mp s4
    simp only [ea] at pa
    simp only [e1] at p1
    simp only [e2] at p2
    simp only [e3] at p3
    simp only [e4] at p4
    obtain ⟨va, la, small0, small1⟩ := pa
    obtain ⟨v1, l1⟩ := p1
    obtain ⟨v2, l2⟩ := p2
    obtain ⟨v3, l3⟩ := p3
    obtain ⟨v4, l4⟩ := p4
    have b1 := Uuid58.value_lt d1
    have b2 := Uuid58.value_lt d2
    have b3 := Uuid58.value_lt d3
    have b4 := Uuid58.value_lt d4
    rw [l1] at b1
    rw [l2] at b2
    rw [l3] at b3
    rw [l4] at b4
    unfold HALF
    step as ⟨scaled, hscaled⟩
    step as ⟨hi, hhi⟩
    step as ⟨midScaled, hmidScaled⟩
    step as ⟨mid, hmid⟩
    step as ⟨loScaled, hloScaled⟩
    step as ⟨lo, hlo⟩
    have hiVal : hi.val = Uuid58.value da := by omega
    have midVal : mid.val = Uuid58.value (d1 ++ d2) := by rw [Uuid58.value_append, l2]; omega
    have loVal : lo.val = Uuid58.value (d3 ++ d4) := by rw [Uuid58.value_append, l4]; omega
    have hiSmall : hi.val < 58^2 := by omega
    have midSmall : mid.val < Uuid58.chunk := by unfold Uuid58.chunk; omega
    apply spec_mono (join_correct hi mid lo hiSmall midSmall)
    intro r hr
    rw [hr, hiVal, midVal, loVal,
      ← Uuid58.join_decode da (d1 ++ d2) (d3 ++ d4) (by simp [l1, l2]) (by simp [l3, l4])]
    simp only [ea, e1, e2, e3, e4, joinFive, List.append_assoc]
    unfold checked
    split <;> rfl
  · have above : seen ≥ limit := by scalar_tac
    rw [ite_eq_left above, joinFive_none _ _ _ _ _ (fun h => valid (bounded.mpr h))]
    simp [rustResult]

/-- All byte slices, including ill-formed UTF-8 and inputs failing multiple checks. -/
theorem decode_correct (input : Slice Std.U8) :
    decode_value input ⦃ r => r = rustResult (Uuid58.decode (input.val.map toByte)) ⦄ := by
  by_cases hl : input.val.length = 22
  · exact decode_22 input hl
  · have hlen : input.len ≠ 22#usize := by intro e; apply hl; simpa using congrArg UScalar.val e
    simp [decode_value, core.array.TryFromSharedArraySlice.try_from, Uuid58.decode, hl, hlen,
      rustResult]

/-- A caller's `AsRef` implementation supplies the byte slice to the public API. -/
theorem public_decode_correct {α : Type} (asRef : core.convert.AsRef α (Slice Std.U8))
    (x : α) (s : Slice Std.U8) (view : asRef.as_ref x ⦃ t => t = s ⦄) :
    decode asRef x ⦃ r => r = rustResult (Uuid58.decode (s.val.map toByte)) ⦄ := by
  unfold decode
  apply spec_bind view
  rintro _ rfl
  exact decode_correct _

theorem is_valid_correct {α : Type} (asRef : core.convert.AsRef α (Slice Std.U8))
    (x : α) (s : Slice Std.U8) (view : asRef.as_ref x ⦃ t => t = s ⦄) :
    is_valid asRef x ⦃ b => b = (Uuid58.decode (s.val.map toByte)).isOk ⦄ := by
  unfold is_valid
  apply spec_bind (public_decode_correct asRef x s view)
  rintro _ rfl
  cases Uuid58.decode (s.val.map toByte) with
  | ok v => simp [rustResult, core.result.Result.is_ok, Except.isOk, Except.toBool]
  | error e => cases e <;> simp [rustResult, core.result.Result.is_ok, Except.isOk, Except.toBool]

end RustUuid58
