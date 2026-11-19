import JsEncode

/-! Refinement of the TypeScript decoder on ECMAScript strings, including lone surrogates. -/
namespace Uuid58.Js

private abbrev W : Nat := 2^32
private abbrev C : Nat := 58^3
abbrev CodeUnit := Fin (2^16)

/-- Preserve the UTF-16 length and each ASCII code. Every other code unit maps
to a byte outside the alphabet, including a surrogate in either position. -/
def specByte (u : CodeUnit) : Byte :=
  if h : u.val < 128 then ⟨u.val, by omega⟩ else ⟨128, by decide⟩

private def inverseTable : List Int8 :=
  (bytes Extracted.alphabet).zipIdx.foldl (fun table (b, i) => table.set b.val (Int8.ofNat i))
    (List.replicate 128 (-1))

private def tableDigit (i : Nat) : Option Nat :=
  let index := inverseTable[i]!.toInt
  if index < 0 then none else some index.toNat

/-- The validated Int8Array uses -1 for an absent digit and 0 through 57 for hits. -/
def digitAt (u : CodeUnit) : Option Nat :=
  if u.val < 128 then tableDigit u.val else none

set_option maxRecDepth 4096 in
private theorem ascii_lookup : ∀ i : Fin 128,
    tableDigit i.val = (digit? ⟨i.val, by have := i.isLt; omega⟩).map Fin.val := by decide

theorem digitAt_correct (u : CodeUnit) : digitAt u = (digit? (specByte u)).map Fin.val := by
  by_cases h : u.val < 128
  · simpa only [digitAt, specByte, ite_eq_left h, dite_eq_left h] using ascii_lookup ⟨u.val,h⟩
  · simp only [digitAt, specByte, ite_eq_right h, dite_eq_right h]; decide

private def pushDigit (v : Nat) (d : Digit) := v*58+d.val
private theorem fold_push (ds : List Digit) (acc : Nat) :
    ds.foldl pushDigit acc = acc*58^ds.length + value ds := value_fold ds acc

private theorem fold_zero (ds : List Digit) : ds.foldl pushDigit 0 = value ds := by
  rw [fold_push, Nat.zero_mul, Nat.zero_add]

private abbrev parsed (s : List CodeUnit) := parse (s.map specByte)

/-- The outer option tracks checked Number arithmetic. The inner option is the
numeric result of readDigits, with none representing the -1 sentinel. -/
def readBlock (r : Rounding) : List CodeUnit → Nat → Option (Option Nat)
  | [], acc => some (some acc)
  | u::us, acc => match digitAt u with
    | none => some none
    | some digit => do readBlock r us (← Extracted.readDigit r acc digit)

private theorem push_ok (r : Rounding) (acc : Nat) (d : Digit) (h : acc*58+d.val < 2^53) :
    Extracted.readDigit r acc d.val = some (pushDigit acc d) := by
  have prod : mul r acc 58 = some (acc*58) := integer_of_lt r _ (Nat.lt_of_le_of_lt (Nat.le_add_right ..) h)
  have total : add r (acc*58) d.val = some (pushDigit acc d) := integer_of_lt r _ h
  simp [Extracted.readDigit, prod, total]

private theorem read_correct (r : Rounding) (s : List CodeUnit) (acc : Nat)
    (cap : (acc+1)*58^s.length ≤ 2^53) :
    readBlock r s acc = some ((parsed s).map (fun ds => ds.foldl pushDigit acc)) := by
  induction s generalizing acc with
  | nil => rfl
  | cons u us ih =>
    cases digit : digit? (specByte u) with
    | none => simp [readBlock, digitAt_correct, parsed, parse, digit]
    | some d =>
      have cap' : ((acc+1)*58)*58^us.length ≤ 2^53 := by
        simpa only [List.length_cons, Nat.pow_succ', Nat.mul_assoc] using cap
      have room := Nat.le_trans (Nat.le_mul_of_pos_right _ (Nat.pow_pos (by decide : 0 < 58))) cap'
      have hd := d.isLt
      have fits : acc*58+d.val < 2^53 := by omega
      have bound : pushDigit acc d+1 ≤ (acc+1)*58 := by unfold pushDigit; omega
      have rest := ih (pushDigit acc d) (Nat.le_trans (Nat.mul_le_mul_right _ bound) cap')
      simp only [readBlock, digitAt_correct, digit, Option.map_some, push_ok r acc d fits,
        parsed, List.map_cons, parse] at rest ⊢
      cases hp : parse (us.map specByte) <;> simp_all

/-- Split off three low words. The high register is deliberately unbounded
until the decoder performs its final overflow comparison. -/
def Words.ofNat (n : Nat) : Words := ⟨n/W/W/W, n/W/W%W, n/W%W, n%W⟩

private theorem divmod_word {hi lo : Nat} (h : lo < W) :
    (hi*W+lo)/W = hi ∧ (hi*W+lo)%W = lo := by dsimp only [W] at *; omega

private theorem unpack (w : Words) (hb : w.b < W) (hc : w.c < W) (hd : w.d < W) :
    Words.ofNat w.value = w := by
  have a := divmod_word (hi := w.a) hb
  have b := divmod_word (hi := w.a*W+w.b) hc
  have c := divmod_word (hi := (w.a*W+w.b)*W+w.c) hd
  simp only [Words.ofNat, Words.value, c.1,c.2,b.1,b.2,a.1,a.2]

private theorem top_fits (n : Nat) : n/W/W/W < W ↔ n < 2^128 := by
  have pos : 0 < W := by decide
  rw [Nat.div_lt_iff_lt_mul pos, Nat.div_lt_iff_lt_mul pos, Nat.div_lt_iff_lt_mul pos]
  rfl

private theorem pack_ofNat (n : Nat) : (Words.ofNat n).value = n := by
  have reconstruct (v : Nat) : v/W*W+v%W=v := by simpa [Nat.mul_comm] using Nat.div_add_mod v W
  simp only [Words.ofNat, Words.value, reconstruct]

/-- One group propagates three carries from low to high, exactly as in decodeWords. -/
def appendChunk (r : Rounding) (w : Words) (chunk : Nat) : Option Words := do
  let t3 ← Extracted.accumulate3 r w.d chunk
  let t2 ← Extracted.accumulate2 r w.c t3 (t3%W)
  let t1 ← Extracted.accumulate1 r w.b t2 (t2%W)
  let top ← Extracted.accumulate0 r w.a t1 (t1%W)
  return ⟨top,t1%W,t2%W,t3%W⟩

private theorem word_bound {w c : Nat} (hw : w < W) (hc : c < C) : w*C+c < C*W := by
  dsimp only [C,W] at *; omega

private theorem low_ok (r : Rounding) {w c : Nat} (hw : w < W) (hc : c < C) :
    Extracted.accumulate3 r w c = some (w*C+c) := by
  have safe : w*C+c < 2^53 := Nat.lt_trans (word_bound hw hc) (by decide)
  have prod : mul r w C = some (w*C) := integer_of_lt r _ (Nat.lt_of_le_of_lt (Nat.le_add_right ..) safe)
  have total : add r (w*C) c = some (w*C+c) := integer_of_lt r _ safe
  change (do return ← add r (← mul r w C) c) = _
  simp [prod, total]

private theorem carry_ok (r : Rounding) {w cur : Nat} (hw : w < W) (ht : cur < C*W) :
    Extracted.accumulate2 r w cur (cur%W) = some (w*C+cur/W) := by
  have carry : cur/W < C := (Nat.div_lt_iff_lt_mul (by decide)).2 ht
  have eqn : cur-cur%W = cur/W*W := Nat.sub_eq_of_eq_add' (Nat.mod_add_div' cur W).symm
  have safe : w*C+cur/W < 2^53 := Nat.lt_trans (word_bound hw carry) (by decide)
  have prod : mul r w C = some (w*C) := integer_of_lt r _ (Nat.lt_of_le_of_lt (Nat.le_add_right ..) safe)
  have diff : sub r cur (cur%W) = some (cur/W*W) := by
    have fits : cur-cur%W < 2^53 := Nat.lt_of_le_of_lt (Nat.sub_le ..) (Nat.lt_trans ht (by decide))
    calc
      _ = some (cur-cur%W) := by
        simp only [sub, ite_eq_left (Nat.mod_le cur W)]; exact integer_of_lt r _ fits
      _ = _ := congrArg some eqn
  have quotient := exactDiv_mul r (cur/W) W (by decide) (Nat.lt_trans carry (by decide))
  have total : add r (w*C) (cur/W) = some (w*C+cur/W) := integer_of_lt r _ safe
  unfold Extracted.accumulate2
  exact Option.bind_eq_some_iff.mpr ⟨_, prod, Option.bind_eq_some_iff.mpr ⟨_, diff,
    Option.bind_eq_some_iff.mpr ⟨_, quotient, total⟩⟩⟩

private theorem attach (p w c : Nat) :
    (p*C+(w*C+c)/W)*W+(w*C+c)%W = (p*W+w)*C+c := by
  have recn (x : Nat) : x/W*W + x%W = x := by simpa [Nat.mul_comm] using Nat.div_add_mod x W
  simp only [Nat.add_mul, Nat.mul_right_comm p C W, Nat.add_assoc, recn]

theorem appendChunk_correct (r : Rounding) (n chunk : Nat) (hn : n < 2^128) (hchunk : chunk < C) :
    appendChunk r (Words.ofNat n) chunk = some (Words.ofNat (n*C+chunk)) := by
  let w := Words.ofNat n
  let t3 := w.d*C+chunk
  let t2 := w.c*C+t3/W
  let t1 := w.b*C+t2/W
  let result : Words := ⟨w.a*C+t1/W,t1%W,t2%W,t3%W⟩
  have pos : 0 < W := by decide
  have h3 := word_bound (Nat.mod_lt n pos) hchunk
  have h2 := word_bound (Nat.mod_lt (n/W) pos) ((Nat.div_lt_iff_lt_mul pos).2 h3)
  have h1 := word_bound (Nat.mod_lt (n/W/W) pos) ((Nat.div_lt_iff_lt_mul pos).2 h2)
  have s3 : Extracted.accumulate3 r w.d chunk = some t3 := low_ok r (Nat.mod_lt n pos) hchunk
  have s2 : Extracted.accumulate2 r w.c t3 (t3%W) = some t2 := carry_ok r (Nat.mod_lt _ pos) h3
  have s1 : Extracted.accumulate1 r w.b t2 (t2%W) = some t1 := carry_ok r (Nat.mod_lt _ pos) h2
  have s0 : Extracted.accumulate0 r w.a t1 (t1%W) = some result.a := carry_ok r ((top_fits n).2 hn) h1
  have run : appendChunk r w chunk = some result := by
    unfold appendChunk
    exact Option.bind_eq_some_iff.mpr ⟨_, s3, Option.bind_eq_some_iff.mpr ⟨_, s2,
      Option.bind_eq_some_iff.mpr ⟨_, s1, Option.bind_eq_some_iff.mpr ⟨_, s0, rfl⟩⟩⟩⟩
  have val : result.value = w.value*C+chunk := by
    change (((w.a*C+t1/W)*W+t1%W)*W+t2%W)*W+t3%W = _
    rw [attach w.a w.b (t2/W), attach (w.a*W+w.b) w.c (t3/W), attach ((w.a*W+w.b)*W+w.c) w.d chunk]
    rfl
  rw [pack_ofNat n] at val
  have canonical := unpack result (Nat.mod_lt t1 pos) (Nat.mod_lt t2 pos) (Nat.mod_lt t3 pos)
  rw [val] at canonical
  exact canonical ▸ run

private abbrev Result := Except Error Words

private def finish (w : Words) : Result :=
  if Extracted.overflow w.a then .error .overflow
  else .ok ⟨w.a%W,w.b%W,w.c%W,w.d%W⟩

private def checked (n : Nat) : Result :=
  if n < 2^128 then .ok (Words.ofNat n) else .error .overflow

private theorem finish_correct (n : Nat) : finish (Words.ofNat n) = checked n := by
  by_cases h : n < 2^128
  · have top := (top_fits n).2 h
    have noCarry : ¬ n/W/W/W ≥ W := Nat.not_le_of_gt top
    simp [finish, checked, h, Words.ofNat, Extracted.overflow, show Extracted.wordBase = W by decide,
      noCarry, Nat.mod_eq_of_lt top]
  · have carry : n/W/W/W ≥ W := Nat.le_of_not_lt (fun small => h ((top_fits n).1 small))
    simp [finish, checked, h, Words.ofNat, Extracted.overflow, show Extracted.wordBase = W by decide, carry]

private def decodeGroups (r : Rounding) : Nat → Words → List CodeUnit → Option Result
  | 0, w, _ => some (finish w)
  | k+1, w, s => do
    let some chunk ← readBlock r (s.take 3) 0 | return .error .invalidCharacter
    let next ← appendChunk r w chunk
    decodeGroups r k next (s.drop 3)

/-- The source checks length in UTF-16 code units and only checks the high
register for overflow after reading the last group. -/
def decodeWords (r : Rounding) (s : List CodeUnit) : Option (Except Error Words) :=
  if s.length ≠ 22 then some (.error .invalidLength) else do
    let some head ← readBlock r (s.take 4) 0 | return .error .invalidCharacter
    decodeGroups r 6 ⟨0,0,0,head⟩ (s.drop 4)

private def expected (n : Nat) (s : List CodeUnit) : Result :=
  match parsed s with
  | none => .error .invalidCharacter
  | some ds => checked (ds.foldl pushDigit n)

private theorem expected_append (n : Nat) (a b : List CodeUnit) :
    expected n (a++b) = match parsed a with
      | none => .error .invalidCharacter
      | some ds => expected (ds.foldl pushDigit n) b := by
  unfold expected parsed
  simp only [List.map_append, parse_append]
  cases parse (a.map specByte) <;> cases parse (b.map specByte) <;> simp [List.foldl_append]

private theorem parsed_length {s : List CodeUnit} {ds : List Digit} (h : parsed s = some ds) :
    ds.length = s.length := by simpa using congrArg List.length (map_parse h)

private theorem read_from_zero (r : Rounding) (s : List CodeUnit) (h : s.length ≤ 4) :
    readBlock r s 0 = some ((parsed s).map value) := by
  have cap : (0+1)*58^s.length ≤ 2^53 := by
    exact Nat.le_trans (Nat.mul_le_mul_left 1 (Nat.pow_le_pow_right (by decide : 0 < 58) h)) (by decide)
  simpa only [fold_zero] using read_correct r s 0 cap

/-- The remaining groups can hold any suffix of k three-digit blocks. While
one block remains, the prefix fits below 58^19 and all four limbs fit in 32 bits. -/
private theorem groups_correct (r : Rounding) (k n : Nat) (s : List CodeUnit)
    (len : s.length = 3*k) (cap : (n+1)*C^k ≤ 58^22) :
    decodeGroups r k (Words.ofNat n) s = some (expected n s) := by
  induction k generalizing n s with
  | zero =>
    have empty : s = [] := List.length_eq_zero_iff.mp (by omega)
    subst s; exact congrArg some (finish_correct n)
  | succ k ih =>
    let head := s.take 3
    let tail := s.drop 3
    have part : head++tail = s := List.take_append_drop ..
    have lh : head.length = 3 := by simp [head]; omega
    have lt : tail.length = 3*k := by simp [tail, len]; omega
    have cap' : ((n+1)*C)*C^k ≤ 58^22 := by simpa only [Nat.pow_succ', Nat.mul_assoc] using cap
    have room := Nat.le_trans (Nat.le_mul_of_pos_right _ (Nat.pow_pos (by decide : 0 < C))) cap'
    have fits : n < 2^128 := by dsimp only [C] at room; omega
    have readHead := read_from_zero r head (by omega)
    have spec := expected_append n head tail
    rw [part] at spec
    cases hp : parsed head with
    | none =>
      simp only [hp, Option.map_none] at readHead spec
      dsimp only [head] at readHead
      simp [decodeGroups, readHead, spec]
    | some ds =>
      have dl := (parsed_length hp).trans lh
      have digitBound := value_lt ds
      rw [dl] at digitBound
      have nextCap := Nat.le_trans (Nat.mul_le_mul_right (C^k)
        (show n*C+value ds+1 ≤ (n+1)*C by dsimp only [C] at digitBound ⊢; omega)) cap'
      simp only [hp, Option.map_some] at readHead
      simp only [hp, fold_push, dl] at spec
      have advance := appendChunk_correct r n (value ds) fits digitBound
      have rest := ih (n*C+value ds) tail lt nextCap
      dsimp only [head] at readHead
      dsimp only [tail] at rest spec
      simp [decodeGroups, readHead, advance, rest, spec]

def wordsResult : Except Error UUID → Except Error Words
  | .ok uuid => .ok (Words.ofNat uuid.val)
  | .error e => .error e

/-- Every UTF-16 string gives the specified four words or the first specified
error. The outer some also establishes that every Number operation succeeds. -/
theorem decode_correct (r : Rounding) (s : List CodeUnit) :
    decodeWords r s = some (wordsResult (decode (s.map specByte))) := by
  by_cases len : s.length = 22
  · let head := s.take 4
    let tail := s.drop 4
    have part : head++tail = s := List.take_append_drop ..
    have lh : head.length = 4 := by simp [head, len]
    have lt : tail.length = 3*6 := by simp [tail,len]
    have readHead := read_from_zero r head (by omega)
    have spec := expected_append 0 head tail
    rw [part] at spec
    have allDigits : wordsResult (decode (s.map specByte)) = expected 0 s := by
      cases hp : parse (s.map specByte) with
      | none => simp [decode, len, expected, parsed, hp, wordsResult]
      | some ds =>
        by_cases valid : value ds < 2^128 <;>
          simp [decode, len, expected, parsed, hp, fold_zero, checked, wordsResult, valid]
    rw [allDigits, spec]
    cases hp : parsed head with
    | none =>
      simp only [hp, Option.map_none] at readHead
      dsimp only [head] at readHead
      simp [decodeWords, len, readHead]
    | some ds =>
      have dl := (parsed_length hp).trans lh
      have bound := value_lt ds
      rw [dl] at bound
      have initial : Words.ofNat (value ds) = ⟨0,0,0,value ds⟩ := by
        have small : value ds < W := Nat.lt_trans bound (by decide)
        simp [Words.ofNat, Nat.div_eq_of_lt small, Nat.mod_eq_of_lt small]
      have cap : (value ds+1)*C^6 ≤ 58^22 := by dsimp only [C]; omega
      have rest := groups_correct r 6 (value ds) tail lt cap
      rw [initial] at rest
      simp only [hp, Option.map_some] at readHead
      dsimp only [head] at readHead
      dsimp only [tail] at rest ⊢
      simp [decodeWords, len, readHead, rest, fold_zero]
  · simp [decodeWords, len, decode, wordsResult]

/-- Position scanned by invalidCharacterError in the original JS string. -/
def invalidIndex (s : List CodeUnit) := s.findIdx fun u => (digitAt u).isNone

private theorem invalidIndex_lt (s : List CodeUnit) (bad : parsed s = none) :
    invalidIndex s < s.length := by
  induction s with
  | nil => simp [parsed, parse] at bad
  | cons u us ih =>
    cases first : digit? (specByte u) with
    | none => simp [invalidIndex, List.findIdx_cons, digitAt_correct, first]
    | some d =>
      have tail : parsed us = none := by
        cases hp : parse (us.map specByte) with
        | none => exact hp
        | some ds => simp [parsed, parse, first, hp] at bad
      simpa [invalidIndex, List.findIdx_cons, digitAt_correct, first] using Nat.succ_lt_succ (ih tail)

theorem invalid_index_correct (r : Rounding) (s : List CodeUnit)
    (bad : decodeWords r s = some (.error .invalidCharacter)) :
    invalidIndex s < s.length ∧ invalidIndex s = s.findIdx (fun u => (digit? (specByte u)).isNone) := by
  constructor
  · apply invalidIndex_lt
    rw [decode_correct] at bad
    by_cases len : s.length = 22
    · cases hp : parsed s with
      | none => rfl
      | some ds =>
        change parse (s.map specByte) = some ds at hp
        by_cases fits : value ds < 2^128 <;> simp [decode, len, hp, fits, wordsResult] at bad
    · simp [decode, len, wordsResult] at bad
  · unfold invalidIndex
    congr 1; funext u; rw [digitAt_correct]; cases digit? (specByte u) <;> rfl

/-- Each ASCII output byte is one ECMAScript string code unit. -/
def toCodeUnit (b : Byte) : CodeUnit := ⟨b.val, Nat.lt_trans b.isLt (by decide)⟩

private theorem ascii_symbols : ∀ d : Digit, specByte (toCodeUnit (symbol d)) = symbol d := by decide

theorem specBytes_of_encoded_text (v : UUID) :
    ((encode v).map toCodeUnit).map specByte = encode v := by
  simp [encode, List.map_map, Function.comp_def, ascii_symbols]

theorem encoded_text_of_decode {s : List CodeUnit} {v : UUID} (ok : decode (s.map specByte) = .ok v) :
    (encode v).map toCodeUnit = s := by
  have back := encode_decode ok
  calc
    (encode v).map toCodeUnit = (s.map specByte).map toCodeUnit := congrArg _ back
    _ = s.map id := by
      rw [List.map_map]
      apply List.map_congr_left
      intro u hu
      have mem : specByte u ∈ encode v := back ▸ List.mem_map.mpr ⟨u, hu, rfl⟩
      have ascii : u.val < 128 := by
        by_cases h : u.val < 128
        · exact h
        · have invalid : (128 : Byte) ∉ alphabet := by decide
          exact False.elim (invalid (by simpa [specByte, h] using encode_alphabet v mem))
      apply Fin.ext
      simp [toCodeUnit, specByte, ascii]
    _ = s := List.map_id _

theorem roundtrip (r : Rounding) (w : Words) (hw : w.valid) :
    (do let bs ← encodeWords r w; decodeWords r (bs.map toCodeUnit)) = some (.ok w) := by
  have words := unpack w hw.2.1 hw.2.2.1 hw.2.2.2
  apply Option.bind_eq_some_iff.mpr
  refine ⟨_, encode_correct r w hw, ?_⟩
  rw [decode_correct, specBytes_of_encoded_text, decode_encode]
  change some (Except.ok (Words.ofNat w.value) : Except Error Words) = _
  rw [words]

end Uuid58.Js
