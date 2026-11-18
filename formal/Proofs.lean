import Spec

namespace Uuid58

theorem parse_symbol : ∀ (d : Digit), digit? (symbol d) = some d := by decide

set_option maxRecDepth 4096 in
theorem symbol_parse : ∀ (b : Byte), (digit? b).map symbol = some b ∨ digit? b = none := by
  decide

set_option maxRecDepth 8192 in
set_option maxHeartbeats 800000 in
private theorem alphabet_order : ∀ (x y : Digit), symbol x < symbol y ↔ x < y := by
  decide

@[simp] theorem length_digits (k n : Nat) : (digits k n).length = k := by
  induction k generalizing n with
  | zero => rfl
  | succ k ih => simp [digits, ih]

theorem value_lt (ds : List Digit) : value ds < 58 ^ ds.length := by
  induction ds with
  | nil => decide
  | cons d ds ih =>
    have h := Nat.mul_le_mul_right (58 ^ ds.length) (Nat.succ_le_of_lt d.isLt)
    simp only [Nat.succ_mul] at h
    simp only [value, List.length_cons, Nat.pow_succ, Nat.mul_comm (58^ds.length) 58]
    omega

theorem value_digits (k n : Nat) (h : n < 58^k) : value (digits k n) = n := by
  induction k generalizing n with
  | zero => simp_all [digits, value, Nat.lt_one_iff]
  | succ k ih =>
    have p : 0 < 58^k := Nat.pow_pos (by decide)
    have q : n / 58^k < 58 := (Nat.div_lt_iff_lt_mul p).2 (by simpa [Nat.pow_succ, Nat.mul_comm] using h)
    simp only [digits, value, length_digits, Nat.mod_eq_of_lt q, ih _ (Nat.mod_lt _ p)]
    simpa [Nat.mul_comm] using Nat.div_add_mod n (58^k)

theorem digits_value (ds : List Digit) : digits ds.length (value ds) = ds := by
  induction ds with
  | nil => rfl
  | cons d ds ih =>
    have p : 0 < 58 ^ ds.length := Nat.pow_pos (by decide)
    have bound := value_lt ds
    simp [digits, value, Nat.mul_comm d.val, Nat.mul_add_div p,
      Nat.div_eq_of_lt bound, Nat.mod_eq_of_lt bound, Nat.mod_eq_of_lt d.isLt, ih]

theorem parse_map (ds : List Digit) : parse (ds.map symbol) = some ds := by
  induction ds with
  | nil => rfl
  | cons d ds ih => simp [parse, parse_symbol, ih]

theorem map_parse {s : List Byte} {ds : List Digit} (h : parse s = some ds) :
    ds.map symbol = s := by
  induction s generalizing ds with
  | nil => simpa [parse] using h.symm
  | cons b bs ih =>
    cases hd : digit? b with
    | none => simp [parse, hd] at h
    | some d =>
      cases hs : parse bs with
      | none => simp [parse, hd, hs] at h
      | some rest =>
        have hb := symbol_parse b
        simp [hd] at hb
        simp [parse, hd, hs] at h
        subst ds
        simp [hb, ih hs]

theorem parse_append (xs ys : List Byte) :
    parse (xs ++ ys) = (do return (← parse xs) ++ (← parse ys)) := by
  induction xs with
  | nil => simp [parse]
  | cons x xs ih =>
    simp only [List.cons_append, parse, ih]
    cases digit? x <;> cases parse xs <;> cases parse ys <;> rfl

theorem encode_length (v : UUID) : (encode v).length = 22 := by simp [encode]

theorem encode_alphabet (v : UUID) {b : Byte} (h : b ∈ encode v) : b ∈ alphabet := by
  obtain ⟨d, _, rfl⟩ := List.mem_map.mp h
  have hl : alphabet.length = 58 := by decide
  have hd : d.val < alphabet.length := by rw [hl]; exact d.isLt
  rw [symbol, getElem!_pos alphabet d.val hd]
  exact List.getElem_mem _

private theorem fits (v : UUID) : v.val < 58^22 :=
  Nat.lt_trans v.isLt (by decide : 2^128 < 58^22)

theorem decode_encode (v : UUID) : decode (encode v) = .ok v := by
  simp [decode, encode, parse_map, value_digits _ _ (fits v), v.isLt]

theorem encode_decode {s : List Byte} {v : UUID} (h : decode s = .ok v) :
    encode v = s := by
  by_cases hl : s.length = 22
  · cases hp : parse s with
    | none => simp [decode, hl, hp] at h
    | some ds =>
      by_cases hv : value ds < 2^128
      · have eq : (⟨value ds, hv⟩ : UUID) = v := by simpa [decode, hl, hp, hv] using h
        subst v
        have hm := map_parse hp
        have len : ds.length = 22 := by simpa [← hm] using hl
        simpa [encode, ← len, digits_value] using hm
      · simp [decode, hl, hp, hv] at h
  · simp [decode, hl] at h

theorem encode_injective {u v : UUID} (h : encode u = encode v) : u = v := by
  have eq := congrArg decode h
  simpa [decode_encode] using eq

private theorem place_lt {a b x y p : Nat} (hx : x < p) (hy : y < p) :
    a*p + x < b*p + y ↔ a < b ∨ (a = b ∧ x < y) := by
  have step {i j : Nat} (h : i < j) : i*p + p ≤ j*p := by
    simpa [Nat.succ_mul] using Nat.mul_le_mul_right p (Nat.succ_le_of_lt h)
  by_cases h : a < b
  · have := step h; omega
  · by_cases h' : b < a
    · have := step h'; omega
    · have : a = b := by omega
      subst b
      omega

theorem value_order (a b : List Digit) (h : a.length = b.length) :
    a.map symbol < b.map symbol ↔ value a < value b := by
  induction a generalizing b with
  | nil => cases b <;> simp_all [value]
  | cons x xs ih =>
    cases b with
    | nil => simp at h
    | cons y ys =>
      have hl : xs.length = ys.length := by simpa using h
      have inj : symbol x = symbol y ↔ x = y := by
        constructor
        · intro e; have := congrArg digit? e; simpa [parse_symbol] using this
        · exact congrArg symbol
      simp only [List.map_cons, List.cons_lt_cons_iff, alphabet_order, inj, ih ys hl, value, hl]
      simpa only [Fin.lt_def, Fin.ext_iff] using
        (place_lt (a := x.val) (b := y.val) (hl ▸ value_lt xs) (value_lt ys)).symm

/-- `<` on `List Byte` is lexicographic comparison of unsigned bytes. -/
theorem encode_order (u v : UUID) : encode u < encode v ↔ u < v := by
  simpa [encode, Fin.lt_def, value_digits _ _ (fits u), value_digits _ _ (fits v)] using
    value_order (digits 22 u.val) (digits 22 v.val) (by simp)

theorem max_encoding : encode ⟨2^128-1, by decide⟩ = bytes "YcVfxkQb6JRzqk5kF2tNLv" := by decide

end Uuid58
