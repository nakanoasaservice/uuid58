import RustUuidText

/-! Relate the two nibbles of each Rust big-endian byte to section 5.2. -/
open Aeneas Aeneas.Std
namespace RustUuid58.Format
open Uuid58.Js

def separator (i : Nat) := [4, 6, 8, 10].contains i
def mark (i : Nat) : List Std.U8 := if separator i then [45#u8] else []

def high (b : Std.U8) : Text.Nibble := Fin.ofNat 16 (b.val / 16)
def low (b : Std.U8) : Text.Nibble := Fin.ofNat 16 b.val
def symbol (d : Text.Nibble) := natByte (Text.lower d).val

def emit (i : Nat) : List Std.U8 → List Std.U8
  | [] => []
  | b :: rest => mark i ++ [symbol (high b), symbol (low b)] ++ emit (i+1) rest

def canonical (w : Words) : List Std.U8 := (Text.canonical w).map (fun u => natByte u.val)

private theorem ascii_character (w : Words) (p : Nat) : (Text.character w p).val < 128 := by
  have lower : ∀ d : Text.Nibble, (Text.lower d).val < 128 := by decide
  unfold Text.character
  split <;> first | decide | apply lower

theorem canonical_ascii (w : Words) : ∀ b ∈ canonical w, b.val < 128 := by
  intro b hb
  obtain ⟨p, _, rfl⟩ := List.mem_map.mp (show b ∈ (List.range 36).map _ by
    simpa only [canonical, Text.canonical, List.map_map] using hb)
  change (Text.character w p).val % 256 < 128
  have := ascii_character w p
  omega

theorem canonical_units (w : Words) :
    ((canonical w).map toByte).map toCodeUnit = Text.canonical w := by
  simp only [canonical, Text.canonical, List.map_map]
  apply List.map_congr_left
  intro p _
  apply Fin.ext
  change (Text.character w p).val % 256 = _
  exact Nat.mod_eq_of_lt (Nat.lt_trans (ascii_character w p) (by decide))

private theorem le_byte (v : BitVec w) (i : Nat) :
    v.toLEBytes[i]! = (v >>> (8*i)).setWidth 8 := by
  apply BitVec.eq_of_getLsbD_eq
  intro j hj
  change (v.toLEBytes[i]!).testBit j = _
  rw [BitVec.toLEBytes_getElem!_testBit v i j hj]
  simp only [BitVec.getElem!_eq_testBit_toNat, BitVec.getLsbD, BitVec.toNat_setWidth,
    BitVec.toNat_ushiftRight, Nat.testBit_mod_two_pow, hj, decide_true, Bool.true_and, Nat.testBit_shiftRight]

private theorem be_byte (v : Std.U128) (i : Nat) (hi : i < 16) :
    ((core.num.U128.to_be_bytes v).val[i]!).val = v.val / 2^(8*(15-i)) % 256 := by
  have length : v.bv.toLEBytes.length = 16 := by simp
  have j : 15-i < v.bv.toLEBytes.length := by omega
  have lookup : v.bv.toBEBytes[i]! = v.bv.toLEBytes[15-i]! := by
    unfold BitVec.toBEBytes
    rw [getElem!_pos v.bv.toLEBytes.reverse i (by simpa [length] using hi), List.getElem_reverse,
      getElem!_pos v.bv.toLEBytes (15-i) j]
    simp only [length]
  have len : i < (core.num.U128.to_be_bytes v).val.length := by simpa using hi
  rw [getElem!_pos (core.num.U128.to_be_bytes v).val i len]
  simp only [core.num.U128.to_be_bytes, Array.from_val, List.getElem_map]
  have inBE : i < v.bv.toBEBytes.length := by simpa using hi
  change (v.bv.toBEBytes[i]'inBE).toNat = _
  rw [← getElem!_pos, lookup, le_byte]
  simp [BitVec.toNat_setWidth, Nat.shiftRight_eq_div_pow]

/-- The finite layout contains exactly the two nibbles at each byte index and four hyphens. -/
private theorem layout (f : Nat → Std.U8) :
    emit 0 ((List.range 16).map f) = (List.range 36).map (fun p =>
      match Text.digitIndex p with
      | none => 45#u8
      | some j => symbol (if j % 2 = 0 then high (f (j/2)) else low (f (j/2)))) := by rfl

private theorem nibble_at (v : Std.U128) (j : Nat) (hj : j < 32) :
    let b := (core.num.U128.to_be_bytes v).val[j/2]!
    (if j % 2 = 0 then high b else low b) =
      Text.nibble (Text.word (Words.ofNat v.val) (j/8)) (j%8) := by
  dsimp only
  have byte := be_byte v (j/2) (by omega)
  apply Fin.ext
  simp only [apply_ite Fin.val, high, low, Fin.val_ofNat, byte]
  clear byte
  generalize v.val = n
  change _ = (Text.nibble (Text.word ⟨n/2^32/2^32/2^32, n/2^32/2^32%2^32, n/2^32%2^32, n%2^32⟩ (j/8)) (j%8)).val
  iterate 32
    cases j
    case zero =>
      simp [Text.nibble, Text.word]
      all_goals omega
    rename_i j
  omega

theorem emit_canonical (v : Std.U128) :
    emit 0 (core.num.U128.to_be_bytes v).val = canonical (Words.ofNat v.val) := by
  let bs := (core.num.U128.to_be_bytes v).val
  have enumerate : bs = (List.range 16).map (fun i => bs[i]!) := by
    apply List.ext_getElem (by simp [bs])
    intro i hi _
    simp only [List.getElem_map, List.getElem_range, getElem!_pos bs i hi]
  change emit 0 bs = _
  rw [enumerate, layout]
  simp only [canonical, Text.canonical, List.map_map]
  apply List.map_congr_left
  intro p hp
  have bound : ∀ p : Fin 36, (Text.digitIndex p.val).getD 0 < 32 := by decide
  have hj := bound ⟨p, List.mem_range.mp hp⟩
  simp only [Function.comp_apply, Text.character]
  cases h : Text.digitIndex p with
  | none => rfl
  | some j =>
    have lt : j < 32 := by simpa [h] using hj
    exact congrArg symbol (nibble_at v j lt)

end RustUuid58.Format
