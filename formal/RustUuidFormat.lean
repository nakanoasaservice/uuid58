import RustUuidLayout

open Aeneas Aeneas.Std Aeneas.Std.WP Result
namespace RustUuid58
open Uuid58.Js Format TextIter
open core.iter.adapters.enumerate core.iter.traits.iterator

private abbrev Buffer := Array Std.U8 36#usize

private theorem store_prefix (buf : Buffer) (pos : Std.Usize) (b : Std.U8) (h : pos.val < 36) :
    buf.update pos b ⦃ out => out.val.take (pos.val+1) = buf.val.take pos.val ++ [b] ⦄ := by
  apply spec_mono (Array.update_spec buf pos b (by simpa using h))
  rintro _ rfl
  rw [Array.set_val_eq, List.take_succ_eq_append_getElem (by simpa using h),
    List.take_set_of_le (Nat.le_refl _), List.getElem_set_self]

private theorem separator_eq (i : Nat) :
    (match i with
      | 4 | 6 | 8 | 10 => ok true
      | _ => ok false : Result Bool) = ok (separator i) := by
  split <;> simp_all [separator]

private def writeMark (i : Nat) (buf : Buffer) (pos : Std.Usize) : Result (Buffer × Std.Usize) := do
  if separator i then
    let buf' ← buf.update pos 45#u8
    let pos' ← pos + 1#usize
    ok (buf', pos')
  else ok (buf, pos)

private theorem writeMark_correct (i : Nat) (buf : Buffer) (pos : Std.Usize) (h : pos.val < 36) :
    writeMark i buf pos ⦃ out j => j.val = pos.val + (mark i).length ∧
      out.val.take j.val = buf.val.take pos.val ++ mark i ⦄ := by
  unfold writeMark
  cases hs : separator i with
  | false => simp [mark, hs]
  | true =>
    simp only [ite_true]
    apply spec_bind (store_prefix buf pos _ h)
    intro out hout
    step as ⟨j, hj⟩
    simp [mark, hs, hj, hout]

private theorem hex_lookup (index : Std.Usize) (d : Text.Nibble) (h : index.val = d.val) :
    Array.index_usize format_uuid.HEX index = ok (symbol d) := by
  have table : ∀ d : Text.Nibble, format_uuid.HEX.val[d.val]! = symbol d := by
    unfold format_uuid.HEX
    decide
  have bound : index.val < format_uuid.HEX.val.length := by simp [h]
  have checked := Array.index_usize_spec format_uuid.HEX index bound
  cases eqn : Array.index_usize format_uuid.HEX index with
  | ret b =>
    rw [eqn, spec_ok] at checked
    rw [checked, ← getElem!_pos format_uuid.HEX.val index.val bound, h, table]
  | vis e k => simp [eqn] at checked
  | div => simp [eqn] at checked

private def shifted (b : Std.U8) : Std.U8 := ⟨b.bv >>> (4 : Nat)⟩

private theorem high_index (b : Std.U8) :
    (core.convert.num.FromUsizeU8.from (shifted b)).val = (high b).val := by
  rw [core.convert.num.FromUsizeU8.from_val_eq]
  change (b.bv >>> (4 : Nat)).toNat = b.val / 16 % 16
  rw [BitVec.toNat_ushiftRight, Nat.shiftRight_eq_div_pow]
  change b.val / 16 = b.val / 16 % 16
  have small := b.bv.isLt
  change b.val < 256 at small
  omega

private theorem low_index (b : Std.U8) :
    (core.convert.num.FromUsizeU8.from (b &&& 15#u8)).val = (low b).val := by
  rw [core.convert.num.FromUsizeU8.from_val_eq]
  change (b.bv &&& BitVec.ofNat 8 15).toNat = b.val % 16
  rw [BitVec.toNat_and]
  exact Nat.and_two_pow_sub_one_eq_mod b.val 4

/-- Starting from any old buffer, processing the remaining bytes fills the suffix
after `pos` and preserves the already written prefix. -/
private theorem format_loop_correct (s : Slice Std.U8) (len : s.val.length = 16)
    (remaining i : Nat) (cursor : i + remaining = 16) (buf : Buffer) (pos : Std.Usize)
    (room : pos.val + (emit i (s.val.drop i)).length = 36) :
    format_uuid_loop (iterAt s i (by omega)) buf pos
      ⦃ out => out.val = buf.val.take pos.val ++ emit i (s.val.drop i) ⦄ := by
  induction remaining generalizing i buf pos with
  | zero =>
    have atEnd : i = s.val.length := by omega
    subst i
    rw [format_uuid_loop, next_end]
    simp [emit] at room ⊢
    simp [room]
  | succ remaining ih =>
    have inSlice : i < s.val.length := by omega
    let b := s.val[i]
    let tail := s.val.drop (i+1)
    have rest : s.val.drop i = b :: tail := List.drop_eq_getElem_cons inSlice
    have body : emit i (s.val.drop i) = mark i ++ [symbol (high b), symbol (low b)] ++ emit (i+1) tail := by
      rw [rest, emit]
    rw [body] at room ⊢
    simp only [List.length_append, List.length_cons, List.length_nil] at room
    rw [format_uuid_loop, next_byte s i inSlice (by omega)]
    simp only [bind_ok]
    change (Std.bind (match (index i (by omega)).val with
      | 4 | 6 | 8 | 10 => ok true | _ => ok false) _) ⦃ _ ⦄
    rw [separator_eq, show (index i (by omega)).val = i from Usize.ofNatCore_val_eq _, bind_ok]
    apply spec_bind (writeMark_correct i buf pos (by omega))
    rintro ⟨buf', j⟩ ⟨hj, hp⟩
    have shift : b >>> 4#i32 = ok (shifted b) := rfl
    change (Std.bind (b >>> 4#i32) _) ⦃ _ ⦄
    simp only [shift, bind_ok, lift, hex_lookup _ _ (high_index b)]
    apply spec_bind (store_prefix buf' j (symbol (high b)) (by omega))
    intro first hfirst
    change (Std.bind (Array.index_usize format_uuid.HEX (core.convert.num.FromUsizeU8.from (b &&& 15#u8))) _) ⦃ _ ⦄
    rw [hex_lookup _ _ (low_index b), bind_ok]
    step as ⟨next, hn⟩
    apply spec_bind (store_prefix first next (symbol (low b)) (by omega))
    intro second hsecond
    step as ⟨stop, hs⟩
    apply spec_mono (ih (i+1) (by omega) second stop (by change _ + (emit (i+1) tail).length = _; omega))
    intro out hout
    rw [hout, hs, show j.val+2 = next.val+1 by omega, hsecond, hn, hfirst, hp]
    simp [tail, List.append_assoc]

/-- Every initial buffer is overwritten with the canonical 36 bytes. The returned
string contains the bytes of that final buffer. -/
theorem format_uuid_correct (v : Std.U128) (buf : Array Std.U8 36#usize) :
    format_uuid v buf ⦃ text out => out.val = Format.canonical (Words.ofNat v.val) ∧ text = out.to_slice ⦄ := by
  let s := (core.num.U128.to_be_bytes v).to_slice
  have len : s.val.length = 16 := by simp [s, Array.to_slice]
  have layout : emit 0 s.val = Format.canonical (Words.ofNat v.val) := by
    simpa only [s, Array.to_slice, Slice.from_val] using emit_canonical v
  have size : (emit 0 s.val).length = 36 := by rw [layout]; simp [Format.canonical, Text.canonical]
  unfold format_uuid
  simp only [lift, bind_ok, core.slice.Slice.iter, Iterator.enumerate.trait_default, Iterator.enumerate.default]
  change (Std.bind (format_uuid_loop (iterAt s 0 (by decide)) buf 0#usize) _) ⦃ _ ⦄
  apply spec_bind (format_loop_correct s len 16 0 (by decide) buf 0#usize (by simp [size]))
  intro out hout
  have written : out.val = Format.canonical (Words.ofNat v.val) := by simpa [layout] using hout
  have ascii : ∀ b ∈ out.to_slice.val, b.val < 128 := by
    simpa only [Array.to_slice, Slice.from_val, written] using canonical_ascii (Words.ofNat v.val)
  let text : Str := out.to_slice
  have converted : ascii_str out.to_slice = ok text := by
    unfold ascii_str
    rw [_root_.core.str.converts.from_utf8_ascii _ ascii, bind_ok]
  change (Std.bind (ascii_str out.to_slice) _) ⦃ _ ⦄
  rw [converted, bind_ok, spec_ok]
  exact ⟨written, rfl⟩

/-- Aeneas represents `&str` by its underlying byte slice. -/
def strAsBytes : core.convert.AsRef Str (Slice Std.U8) where
  as_ref text := ok text

/-- Parse the string returned by the extracted formatter using the extracted public Rust parser. -/
theorem format_parse_roundtrip (v : Std.U128) (buf : Array Std.U8 36#usize) :
    (do let (text, _) ← format_uuid v buf; parse_uuid_str strAsBytes text)
      ⦃ r => r = core.result.Result.Ok v ⦄ := by
  apply spec_bind (format_uuid_correct v buf)
  rintro ⟨text, out⟩ ⟨written, view⟩
  apply spec_mono (parse_uuid_str_correct strAsBytes text text ((spec_ok text).mpr rfl))
  intro r hr
  rw [hr, view]
  simp only [Array.to_slice, Slice.from_val, written, Uuid58.parseUuidBytes, canonical_units]
  let uuid := v.bv.toFin
  let w : Text.ValidWords := ⟨Words.ofNat uuid.val, Words.valid_of_uuid uuid⟩
  change rustResult ((Text.parse (Text.canonical w.val)).map _) = _
  rw [Text.parse_canonical w]
  change rustResult (.ok ((Words.ofNat uuid.val).uuid (Words.valid_of_uuid uuid))) = _
  rw [Words.uuid_ofNat]
  rfl

/-- The public decoder returns the canonical contents of the destination on success.
On the first decoding error it returns that error and preserves the entire destination. -/
theorem decode_to_uuid_buf_correct {α : Type} (asRef : core.convert.AsRef α (Slice Std.U8))
    (x : α) (s : Slice Std.U8) (view : asRef.as_ref x ⦃ t => t = s ⦄) (buf : Array Std.U8 36#usize) :
    decode_to_uuid_buf asRef x buf ⦃ result out =>
      match rustResult (Uuid58.decode (s.val.map toByte)) with
      | .Ok v => out.val = Format.canonical (Words.ofNat v.val) ∧ result = .Ok out.to_slice
      | .Err e => result = .Err e ∧ out = buf ⦄ := by
  unfold decode_to_uuid_buf
  apply spec_bind (public_decode_correct asRef x s view)
  rintro _ rfl
  cases rustResult (Uuid58.decode (s.val.map toByte)) with
  | Ok v =>
    simp only [core.result.Result.Insts.CoreOpsTry.branch, bind_ok]
    apply spec_bind (format_uuid_correct v buf)
    rintro ⟨text, out⟩ ⟨written, returned⟩
    apply (spec_ok _).mpr
    exact ⟨written, congrArg core.result.Result.Ok returned⟩
  | Err e =>
    simp [core.result.Result.Insts.CoreOpsTry.branch,
      core.result.Result.Insts.CoreOpsTry_traitFromResidualResult.from_residual]

end RustUuid58
