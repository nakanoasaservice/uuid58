import RustTables

open Aeneas Aeneas.Std Aeneas.Std.WP Result
namespace RustUuid58

abbrev Block := core.result.Result Std.U64 RustUuid58.Error

private def word64 (n : Nat) : Std.U64 := ⟨BitVec.ofNat 64 n⟩

private def readResult (acc : Nat) (s : List Uuid58.Byte) : Block :=
  match Uuid58.parse s with
  | none => .Err .InvalidCharacter
  | some ds => .Ok (word64 (ds.foldl (fun a d => a * 58 + d.val) acc))

/-- `pre` has already been read, `bs` is this chunk, and `tail` belongs to later chunks.
The capacity bound ensures that every multiply and addition in the loop fits in a u64. -/
private theorem read_loop_correct (bs pre tail : List Std.U8) (input : Slice Std.U8)
    (pos stop : Std.Usize) (acc : Std.U64) (hs : input.val = pre ++ bs ++ tail)
    (hp : pos.val = pre.length) (he : stop.val = pre.length + bs.length)
    (cap : (acc.val+1) * 58^bs.length ≤ 2^64) :
    read_digits_loop input pos stop acc ⦃ r => r = readResult acc.val (bs.map toByte) ⦄ := by
  induction bs generalizing pre pos acc with
  | nil =>
    rw [read_digits_loop]
    have h : ¬ pos < stop := by simp at he; scalar_tac
    simp [h, readResult, Uuid58.parse, word64]
  | cons b bs ih =>
    rw [read_digits_loop]
    have h : pos < stop := by simp at he; scalar_tac
    simp only [ite_eq_left h]
    step as ⟨t, ht⟩
    have hbound : pos.val < input.val.length := by simp [hs, hp]
    step as ⟨x, hx⟩
    have hx' : x = b := by simpa [hs, hp, List.append_assoc] using hx
    clear hx
    subst x
    step as ⟨idx, hidx⟩
    step as ⟨d, hd⟩
    have hd' : d = digitTable[(toByte b).val]! := by
      rw [← ht]
      change d = t.val[b.val]!
      rw [getElem!_pos _ _ (by scalar_tac)]
      simpa only [hidx] using hd
    rw [lookup_correct] at hd'
    cases hb : Uuid58.digit? (toByte b) with
    | none =>
      have bad : d = INVALID := by rw [hd', hb]; unfold INVALID; rfl
      simp [bad, readResult, Uuid58.parse, hb]
    | some digit =>
      have hdv : d.val = digit.val := by
        have hbyte : d = natByte digit.val := by simpa [hb] using hd'
        rw [hbyte]
        change digit.val % 256 = digit.val
        exact Nat.mod_eq_of_lt (by omega)
      have good : d ≠ INVALID := by intro eq; rw [eq] at hdv; unfold INVALID at hdv; scalar_tac
      simp only [ite_eq_right good]
      have cap' : ((acc.val+1) * 58) * 58^bs.length ≤ 2^64 := by
        simpa [Nat.pow_succ', Nat.mul_assoc] using cap
      have room : (acc.val + 1) * 58 ≤ 2^64 :=
        (Nat.le_mul_of_pos_right _ (Nat.pow_pos (by decide))).trans cap'
      step as ⟨m, hm⟩
      step as ⟨w, hw⟩
      step as ⟨next, hn⟩
      step as ⟨j, hj⟩
      have hn' : next.val = acc.val * 58 + digit.val := by omega
      have capNext : (next.val+1) * 58^bs.length ≤ 2^64 :=
        (Nat.mul_le_mul_right _ (show next.val+1 ≤ (acc.val+1)*58 by omega)).trans cap'
      apply spec_mono (ih (pre ++ [b]) j next (by simpa [List.append_assoc] using hs)
        (by simp [hj, hp]) (by simp_all [Nat.add_assoc, Nat.add_comm, Nat.add_left_comm]) capNext)
      intro r hr
      rw [hr]
      simp [readResult, Uuid58.parse, hb, hn']
      cases Uuid58.parse (bs.map toByte) <;> rfl

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

private theorem length_of_parse {xs : List Std.U8} {ds : List Uuid58.Digit}
    (h : Uuid58.parse (xs.map toByte) = some ds) : ds.length = xs.length := by
  simpa using congrArg List.length (Uuid58.map_parse h)

private theorem word64_val {n : Nat} (h : n < 2^64) : (word64 n).val = n :=
  Nat.mod_eq_of_lt h

private theorem decode_three (input : Slice Std.U8) (a b c : List Std.U8)
    (hs : input.val = a ++ b ++ c) (ha : a.length = 2) (hb : b.length = 10)
    (hc : c.length = 10) :
    decode_value input ⦃ r => r = rustResult (Uuid58.decode (input.val.map toByte)) ⦄ := by
  have hl : input.val.length = 22 := by simp [hs, ha, hb, hc]
  have hal := read_loop_correct a [] (b ++ c) input 0#usize 2#usize 0#u64
    (by simpa [List.append_assoc] using hs) (by simp) (by simp [ha]) (by simp [ha])
  have hbl := read_loop_correct b a c input 2#usize 12#usize 0#u64 hs
    (by simp [ha]) (by simp [ha, hb]) (by simp [hb])
  have hcl := read_loop_correct c (a ++ b) [] input 12#usize 22#usize 0#u64
    (by simpa using hs) (by simp [ha, hb]) (by simp [ha, hb, hc]) (by simp [hc])
  unfold decode_value Uuid58.decode ENCODED_LEN
  have hlen : input.len = 22#usize := by apply UScalar.val_eq_imp; simpa using hl
  simp [hlen, hl]
  simp only [hs, List.map_append, Uuid58.parse_append]
  apply spec_bind hal
  intro ra hra
  rw [hra]
  cases pa : Uuid58.parse (a.map toByte) with
  | none => simp [readResult, pa, core.result.Result.Insts.CoreOpsTry.branch,
      core.result.Result.Insts.CoreOpsTry_traitFromResidualResult.from_residual,
      rustResult]
  | some da =>
    simp [readResult, pa, core.result.Result.Insts.CoreOpsTry.branch, Uuid58.value_fold]
    apply spec_bind hbl
    intro rb hrb
    rw [hrb]
    cases pb : Uuid58.parse (b.map toByte) with
    | none => simp [readResult, pb,
        core.result.Result.Insts.CoreOpsTry_traitFromResidualResult.from_residual,
        rustResult]
    | some db =>
      simp [readResult, pb, Uuid58.value_fold]
      apply spec_bind hcl
      intro rc hrc
      rw [hrc]
      cases pc : Uuid58.parse (c.map toByte) with
      | none => simp [readResult, pc,
          core.result.Result.Insts.CoreOpsTry_traitFromResidualResult.from_residual,
          rustResult]
      | some dc =>
        simp [readResult, pc, Uuid58.value_fold]
        have la := (length_of_parse pa).trans ha
        have lb := (length_of_parse pb).trans hb
        have lc := (length_of_parse pc).trans hc
        have ba := Uuid58.value_lt da
        have bb := Uuid58.value_lt db
        have bc := Uuid58.value_lt dc
        rw [la] at ba; rw [lb] at bb; rw [lc] at bc
        have va := word64_val (n := Uuid58.value da) (by omega)
        have vb := word64_val (n := Uuid58.value db) (by omega)
        have vc := word64_val (n := Uuid58.value dc) (by omega)
        apply spec_mono (join_correct _ _ _ (by rwa [va]) (by rwa [vb]))
        intro r hr
        rw [hr, va, vb, vc, ← Uuid58.join_decode da db dc lb lc]
        rw [List.append_assoc]
        unfold checked
        split <;> rfl

/-- All byte slices, including ill-formed UTF-8 and inputs failing multiple checks. -/
theorem decode_correct (input : Slice Std.U8) :
    decode_value input ⦃ r => r = rustResult (Uuid58.decode (input.val.map toByte)) ⦄ := by
  by_cases hl : input.val.length = 22
  · let a := input.val.take 2
    let b := (input.val.drop 2).take 10
    let c := (input.val.drop 2).drop 10
    apply decode_three input a b c
    · dsimp [a, b, c]
      rw [List.append_assoc, List.take_append_drop, List.take_append_drop]
    · simp [a, hl]
    · simp [b, hl]
    · simp [c, hl]
  · have hlen : input.len ≠ 22#usize := by intro e; apply hl; simpa using congrArg UScalar.val e
    simp [decode_value, ENCODED_LEN, Uuid58.decode, hl, hlen, rustResult]

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
