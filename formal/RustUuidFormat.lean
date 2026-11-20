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
      | 4 => ok true
      | 6 => ok true
      | 8 => ok true
      | 10 => ok true
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

private abbrev Pair := Array Std.U8 2#usize

/-- The two digits of byte `i`. -/
private def pairOf (i : Nat) : Pair :=
  Array.make 2#usize [natByte lowerHex[i / 16]!, natByte lowerHex[i % 16]!]

/-- Entries below `i` are final and the loop writes the rest. -/
private theorem pairs_loop_correct (n : Nat) (t : Array Pair 256#usize)
    (i : Std.Usize) (h : i.val + n = 256) :
    make_hex_pairs_loop LOWER_HEX t i ⦃ r => r.val = t.val.take i.val ++
      (List.range' i.val n).map pairOf ⦄ := by
  induction n generalizing i t with
  | zero =>
    rw [make_hex_pairs_loop]
    have hi : ¬ i < 256#usize := by scalar_tac
    have all : t.val.length ≤ i.val := by scalar_tac
    simp [hi, List.take_of_length_le all]
  | succ n ih =>
    rw [make_hex_pairs_loop]
    have hi : i < 256#usize := by scalar_tac
    simp only [ite_eq_left hi]
    have small : i.val < 256 := by scalar_tac
    step as ⟨high, hhigh⟩
    step as ⟨first, hfirst⟩
    step as ⟨low, lowVal⟩
    step as ⟨second, hsecond⟩
    have inTable : i.val < t.val.length := by scalar_tac
    have entry : (Array.make 2#usize [first, second] : Pair) = pairOf i.val := by
      have lowerLen : lowerHex.length = 16 := by decide
      have e1 : first = natByte lowerHex[i.val / 16]! := by
        rw [hfirst, getElem!_pos lowerHex (i.val / 16) (by omega)]
        simp only [lower_eq, List.getElem_map, hhigh]
      have e2 : second = natByte lowerHex[i.val % 16]! := by
        rw [hsecond, getElem!_pos lowerHex (i.val % 16) (by omega)]
        simp only [lower_eq, List.getElem_map, lowVal]
      rw [e1, e2, pairOf]
    rw [entry]
    step as ⟨t', ht⟩
    step as ⟨j, hj⟩
    apply spec_mono (ih t' j (by omega))
    intro r hr
    rw [hr, ht, Array.set_val_eq, hj, List.take_succ_eq_append_getElem (by simpa using inTable),
      List.take_set_of_le (Nat.le_refl _), List.getElem_set_self, List.range'_succ]
    simp

private def pairTable : List Pair := (List.range' 0 256).map pairOf

@[step] private theorem pairs_correct : HEX_PAIRS ⦃ t => t.val = pairTable ⦄ := by
  unfold HEX_PAIRS make_hex_pairs
  apply spec_mono (pairs_loop_correct 256 _ 0#usize (by scalar_tac))
  intro t h
  simpa [pairTable] using h

private theorem lower_symbol : ∀ d : Text.Nibble, natByte lowerHex[d.val]! = symbol d := by decide

/-- The entry of a byte holds the characters of its two nibbles. -/
private theorem pair_lookup (b : Std.U8) :
    pairTable[b.val]! = Array.make 2#usize [symbol (high b), symbol (low b)] := by
  have small : b.val < 256 := by scalar_tac
  have inTable : b.val < pairTable.length := by simp [pairTable]; omega
  rw [getElem!_pos pairTable b.val inTable]
  simp only [pairTable, List.getElem_map, List.getElem_range', pairOf, Nat.zero_add, Nat.one_mul]
  rw [← lower_symbol (high b), ← lower_symbol (low b)]
  have hv : (high b).val = b.val / 16 := by
    change b.val / 16 % 16 = b.val / 16
    omega
  have lv : (low b).val = b.val % 16 := rfl
  rw [hv, lv]

/-- Starting from any old buffer, processing the remaining bytes fills the suffix
after `pos` and preserves the already written prefix. -/
private theorem write_loop_correct (s : Slice Std.U8) (len : s.val.length = 16)
    (remaining i : Nat) (cursor : i + remaining = 16) (buf : Buffer) (pos : Std.Usize)
    (room : pos.val + (emit i (s.val.drop i)).length = 36) :
    write_uuid_loop (iterAt s i (by omega)) buf pos
      ⦃ out => out.val = buf.val.take pos.val ++ emit i (s.val.drop i) ⦄ := by
  induction remaining generalizing i buf pos with
  | zero =>
    have atEnd : i = s.val.length := by omega
    subst i
    rw [write_uuid_loop, next_end]
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
    rw [write_uuid_loop, next_byte s i inSlice (by omega)]
    simp only [bind_ok]
    change (Std.bind (match (index i (by omega)).val with
      | 4 => ok true | 6 => ok true | 8 => ok true | 10 => ok true | _ => ok false) _) ⦃ _ ⦄
    rw [separator_eq, show (index i (by omega)).val = i from Usize.ofNatCore_val_eq _, bind_ok]
    apply spec_bind (writeMark_correct i buf pos (by omega))
    rintro ⟨buf', j⟩ ⟨hj, hp⟩
    step as ⟨table, htable⟩
    step as ⟨idx, hidx⟩
    step as ⟨pair, hpair⟩
    have entry : pair = Array.make 2#usize [symbol (high b), symbol (low b)] := by
      rw [hpair, ← getElem!_pos table.val idx.val (by scalar_tac), htable, hidx]
      exact pair_lookup b
    step as ⟨first, hfirst⟩
    have firstVal : first = symbol (high b) := by rw [hfirst]; simp [entry]
    apply spec_bind (store_prefix buf' j first (by omega))
    intro written hwritten
    step as ⟨second, hsecond⟩
    have secondVal : second = symbol (low b) := by rw [hsecond]; simp [entry]
    step as ⟨next, hn⟩
    apply spec_bind (store_prefix written next second (by omega))
    intro written' hwritten'
    step as ⟨stop, hs⟩
    apply spec_mono (ih (i+1) (by omega) written' stop (by change _ + (emit (i+1) tail).length = _; omega))
    intro out hout
    rw [hout, hs, show j.val+2 = next.val+1 by omega, hwritten', hn, hwritten, hp, firstVal, secondVal]
    simp [tail, List.append_assoc]

/-- Every initial buffer is overwritten with the canonical 36 bytes. -/
private theorem write_uuid_correct (v : Std.U128) (buf : Array Std.U8 36#usize) :
    write_uuid v buf ⦃ out => out.val = Format.canonical (Words.ofNat v.val) ⦄ := by
  let s := (core.num.U128.to_be_bytes v).to_slice
  have len : s.val.length = 16 := by simp [s, Array.to_slice]
  have layout : emit 0 s.val = Format.canonical (Words.ofNat v.val) := by
    simpa only [s, Array.to_slice, Slice.from_val] using emit_canonical v
  have size : (emit 0 s.val).length = 36 := by rw [layout]; simp [Format.canonical, Text.canonical]
  unfold write_uuid
  simp only [lift, bind_ok, core.slice.Slice.iter, Iterator.enumerate.trait_default, Iterator.enumerate.default]
  change write_uuid_loop (iterAt s 0 (by decide)) buf 0#usize ⦃ _ ⦄
  apply spec_mono (write_loop_correct s len 16 0 (by decide) buf 0#usize (by simp [size]))
  intro out hout
  simpa [layout] using hout

/-- Every initial buffer is overwritten with the canonical 36 bytes. The returned
string contains the bytes of that final buffer. -/
theorem format_uuid_correct (v : Std.U128) (buf : Array Std.U8 36#usize) :
    format_uuid v buf ⦃ text out => out.val = Format.canonical (Words.ofNat v.val) ∧ text = out.to_slice ⦄ := by
  unfold format_uuid
  apply spec_bind (write_uuid_correct v buf)
  intro out written
  have ascii : ∀ b ∈ out.to_slice.val, b.val < 128 := by
    simpa only [Array.to_slice, Slice.from_val, written] using canonical_ascii (Words.ofNat v.val)
  let text : Str := out.to_slice
  have converted : ascii_str out.to_slice = ok text := by
    unfold ascii_str
    rw [_root_.core.str.converts.from_utf8_ascii _ ascii, bind_ok]
  simp only [lift, bind_ok]
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
