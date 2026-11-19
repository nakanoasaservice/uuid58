import Bytes
import JsDecode

/-! The JavaScript public byte API on the contents of a Uint8Array view. -/
namespace Uuid58.Js

private abbrev W : Nat := 2^32

/-- Storing a signed JS bitwise result into the Uint32Array preserves all its bits. -/
private theorem pack_correct (a b c d : BitVec 8) :
    Extracted.packWord a b c d = a ++ b ++ c ++ d := by
  have bits := (BitVec.setWidth_append_append_append_eq_shiftLeft_setWidth_or
    (b := a) (b' := b) (b'' := c) (b''' := d) (w'''' := 32)).symm
  simp only [BitVec.setWidth_eq, Nat.reduceAdd] at bits
  simp only [Extracted.packWord, Nat.reduceMod]
  with_reducible exact bits

private def readWord (bs : List Byte) : BitVec 32 :=
  Extracted.packWord (.ofFin bs[0]!) (.ofFin bs[1]!) (.ofFin bs[2]!) (.ofFin bs[3]!)

private def readWords (bs : List Byte) : Words :=
  ⟨(readWord bs).toNat, (readWord (bs.drop 4)).toNat,
    (readWord (bs.drop 8)).toNat, (readWord (bs.drop 12)).toNat⟩

private theorem read_valid (bs : List Byte) : (readWords bs).valid :=
  ⟨(readWord _).isLt, (readWord _).isLt, (readWord _).isLt, (readWord _).isLt⟩

private theorem fold_four (bs : List Byte) (acc : Nat) (len : 4 ≤ bs.length) :
    bs.foldl pushByte acc = (bs.drop 4).foldl pushByte (acc*W + (readWord bs).toNat) := by
  match bs with
  | [] | [_] | [_, _] | [_, _, _] => simp at len
  | a :: b :: c :: d :: tail =>
    simp only [List.foldl_cons, List.drop_succ_cons, List.drop_zero, readWord,
      List.getElem!_cons_succ, List.getElem!_cons_zero]
    apply congrArg (tail.foldl pushByte)
    rw [pack_correct]
    simp only [pushByte, W, BitVec.toNat_append_eq_mul_add, BitVec.toNat_ofFin]
    omega

private theorem read_value (bs : List Byte) (len : bs.length = 16) :
    byteValue bs = (readWords bs).value := by
  have step (i acc : Nat) (hi : i + 4 ≤ 16) : (bs.drop i).foldl pushByte acc =
      (bs.drop (i+4)).foldl pushByte (acc*W + (readWord (bs.drop i)).toNat) := by
    rw [fold_four _ acc (by simp [len]; omega), List.drop_drop]
  change (bs.drop 0).foldl pushByte 0 = _
  rw [step 0 _ (by decide), step 4 _ (by decide), step 8 _ (by decide), step 12 _ (by decide),
    List.drop_of_length_le (show bs.length ≤ 16 by omega)]
  simp [readWords, Words.value]

private def writeWord (n : Nat) : List Byte :=
  (Extracted.unpackWord (BitVec.ofNat 32 n)).map BitVec.toFin

private def writeWords (w : Words) : List Byte :=
  writeWord w.a ++ writeWord w.b ++ writeWord w.c ++ writeWord w.d

private theorem write_word (n : Nat) : writeWord n = bigEndian 4 n := by
  unfold writeWord Extracted.unpackWord
  simp only [List.map_cons, List.map_nil, bigEndian, List.nil_append, List.cons_append,
    List.cons.injEq, and_true, Fin.ext_iff]
  change (((BitVec.ofNat 32 n >>> (24 : Nat)).setWidth 8).toNat = _ ∧
          ((BitVec.ofNat 32 n >>> (16 : Nat)).setWidth 8).toNat = _ ∧
          ((BitVec.ofNat 32 n >>> (8 : Nat)).setWidth 8).toNat = _ ∧
          ((BitVec.ofNat 32 n).setWidth 8).toNat = _)
  simp only [BitVec.toNat_setWidth, BitVec.toNat_ushiftRight, BitVec.toNat_ofNat,
    Nat.shiftRight_eq_div_pow, lowByte]
  omega

private theorem write_value (v : UUID) : writeWords (Words.ofNat v.val) = bigEndian 16 v.val := by
  have wordMod (n : Nat) : bigEndian 4 (n % W) = bigEndian 4 n := bigEndian_mod 4 n
  simp only [writeWords, Words.ofNat, write_word, wordMod]
  rw [bigEndian_add 12 4 v.val, bigEndian_add 8 4 (v.val / W), bigEndian_add 4 4 (v.val / W / W)]

/-- The byte inputs are the elements of the view, indexed relative to its start. -/
def encodeBytesSafe (r : Rounding) (bs : List Byte) : Option (Except Error (List CodeUnit)) :=
  if bs.length ≠ Extracted.byteInputLength then some (.error .invalidLength)
  else (encodeWords r (readWords bs)).map fun chars => .ok (chars.map toCodeUnit)

/-- On success the source copies all four words into a newly allocated 16-byte view. -/
def decodeBytesSafe (r : Rounding) (s : List CodeUnit) : Option (Except Error (List Byte)) :=
  (decodeWords r s).map (Except.map writeWords)

def uuidOfBytes (bs : List Byte) (len : bs.length = 16) : UUID :=
  ⟨byteValue bs, by simpa only [len] using byteValue_lt bs⟩

private theorem uuidOfBytes_val (bs : List Byte) (len : bs.length = 16) :
    (uuidOfBytes bs len).val = byteValue bs := rfl

def encodeBytesSpec (bs : List Byte) : Except Error (List CodeUnit) :=
  if len : bs.length = 16 then .ok ((encode (uuidOfBytes bs len)).map toCodeUnit)
  else .error .invalidLength

def decodeBytesSpec (s : List CodeUnit) : Except Error (List Byte) :=
  (decode (s.map specByte)).map (fun v => bigEndian 16 v.val)

theorem encodeBytesSafe_correct (r : Rounding) (bs : List Byte) :
    encodeBytesSafe r bs = some (encodeBytesSpec bs) := by
  by_cases len : bs.length = 16
  · have uuid : (readWords bs).uuid (read_valid bs) = uuidOfBytes bs len := Fin.ext (read_value bs len).symm
    simp [encodeBytesSafe, Extracted.byteInputLength, encodeBytesSpec, len, encode_correct r _ (read_valid bs), uuid]
  · simp [encodeBytesSafe, Extracted.byteInputLength, encodeBytesSpec, len]

theorem decodeBytesSafe_correct (r : Rounding) (s : List CodeUnit) :
    decodeBytesSafe r s = some (decodeBytesSpec s) := by
  rw [decodeBytesSafe, decode_correct]
  unfold decodeBytesSpec
  cases decode (s.map specByte) <;> simp [wordsResult, Except.map, write_value]

/-- The safe APIs return error objects. The ordinary APIs throw those errors. -/
inductive Completion (α : Type) where
  | returned (value : α)
  | threw (kind : Error)

def throwOnError {α} : Except Error α → Completion α
  | .ok x => .returned x
  | .error kind => .threw kind

def encodeBytes (r : Rounding) (bs : List Byte) := (encodeBytesSafe r bs).map throwOnError
def decodeBytes (r : Rounding) (s : List CodeUnit) := (decodeBytesSafe r s).map throwOnError

theorem encodeBytes_correct (r : Rounding) (bs : List Byte) :
    encodeBytes r bs = some (throwOnError (encodeBytesSpec bs)) := by
  rw [encodeBytes, encodeBytesSafe_correct]; rfl

theorem decodeBytes_correct (r : Rounding) (s : List CodeUnit) :
    decodeBytes r s = some (throwOnError (decodeBytesSpec s)) := by
  rw [decodeBytes, decodeBytesSafe_correct]; rfl

theorem bytes_decode_encode (r : Rounding) (bs : List Byte) (len : bs.length = 16) :
    ∃ s, encodeBytesSafe r bs = some (.ok s) ∧ decodeBytesSafe r s = some (.ok bs) := by
  refine ⟨(encode (uuidOfBytes bs len)).map toCodeUnit, ?_, ?_⟩
  · simp [encodeBytesSafe_correct, encodeBytesSpec, len]
  · rw [decodeBytesSafe_correct, decodeBytesSpec, specBytes_of_encoded_text, decode_encode]
    change some (Except.ok (bigEndian 16 (byteValue bs)) : Except Error (List Byte)) = _
    rw [← len, bigEndian_byteValue]

theorem bytes_encode_decode (r : Rounding) (s : List CodeUnit) (bs : List Byte)
    (ok : decodeBytesSafe r s = some (.ok bs)) : encodeBytesSafe r bs = some (.ok s) := by
  rw [decodeBytesSafe_correct, decodeBytesSpec] at ok
  cases hv : decode (s.map specByte) with
  | error e => simp [hv, Except.map] at ok
  | ok v =>
    simp [hv, Except.map] at ok
    subst bs
    have len := length_bigEndian 16 v.val
    have value : uuidOfBytes (bigEndian 16 v.val) len = v := by
      apply Fin.ext
      rw [uuidOfBytes_val]
      exact byteValue_bigEndian 16 v.val v.isLt
    rw [encodeBytesSafe_correct, encodeBytesSpec, dite_eq_left len, value, encoded_text_of_decode hv]

end Uuid58.Js
