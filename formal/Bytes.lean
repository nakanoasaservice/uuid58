import Spec

/-! Big-endian UUID bytes in sections 3 and 4 of the specification. -/
namespace Uuid58

def pushByte (acc : Nat) (b : Byte) : Nat := acc * 256 + b.val
def byteValue (bs : List Byte) : Nat := bs.foldl pushByte 0

def lowByte (n : Nat) : Byte := ⟨n % 256, Nat.mod_lt _ (by decide)⟩

/-- Emit exactly the requested width, including leading zero bytes. -/
def bigEndian : Nat → Nat → List Byte
  | 0, _ => []
  | k+1, n => bigEndian k (n / 256) ++ [lowByte n]

@[simp] theorem length_bigEndian (k n : Nat) : (bigEndian k n).length = k := by
  induction k generalizing n <;> simp [bigEndian, *]

theorem bigEndian_add (a b n : Nat) :
    bigEndian (a+b) n = bigEndian a (n / 256^b) ++ bigEndian b n := by
  induction b generalizing n with
  | zero => simp [bigEndian]
  | succ b ih =>
    change bigEndian (a+b) (n / 256) ++ [lowByte n] =
      bigEndian a (n / 256^(b+1)) ++ (bigEndian b (n / 256) ++ [lowByte n])
    rw [ih, Nat.div_div_eq_div_mul, Nat.pow_succ', List.append_assoc]

theorem bigEndian_mod (k n : Nat) : bigEndian k (n % 256^k) = bigEndian k n := by
  induction k generalizing n with
  | zero => rfl
  | succ k ih =>
    have last : lowByte (n % (256 * 256^k)) = lowByte n :=
      Fin.ext (Nat.mod_mul_right_mod n 256 _)
    simp only [Nat.pow_succ', bigEndian, Nat.mod_mul_right_div_self, ih, last]

private theorem fold_bytes (bs : List Byte) (acc k : Nat) (fits : acc < 256^k) :
    let n := bs.foldl pushByte acc
    n < 256^(k + bs.length) ∧ bigEndian (k + bs.length) n = bigEndian k acc ++ bs := by
  induction bs generalizing acc k with
  | nil => simpa using fits
  | cons b bs ih =>
    have hb := b.isLt
    have cap : pushByte acc b < 256^(k+1) := by rw [Nat.pow_succ]; unfold pushByte; omega
    have div : pushByte acc b / 256 = acc := by unfold pushByte; omega
    have mod : lowByte (pushByte acc b) = b := by apply Fin.ext; unfold lowByte pushByte; dsimp; omega
    simpa only [List.foldl_cons, List.length_cons, Nat.add_right_comm k 1 bs.length,
      Nat.add_assoc, Nat.add_comm 1 bs.length, bigEndian, div, mod, List.append_assoc,
      List.singleton_append] using ih (pushByte acc b) (k+1) cap

theorem byteValue_lt (bs : List Byte) : byteValue bs < 256^bs.length := by
  simpa [byteValue] using (fold_bytes bs 0 0 (by decide)).1

theorem bigEndian_byteValue (bs : List Byte) : bigEndian bs.length (byteValue bs) = bs := by
  simpa [byteValue, bigEndian] using (fold_bytes bs 0 0 (by decide)).2

theorem byteValue_bigEndian (k n : Nat) (fits : n < 256^k) : byteValue (bigEndian k n) = n := by
  induction k generalizing n with
  | zero => simp_all [bigEndian, byteValue, Nat.lt_one_iff]
  | succ k ih =>
    have bound : n / 256 < 256^k := (Nat.div_lt_iff_lt_mul (by decide)).2 (by simpa [Nat.pow_succ] using fits)
    change ((bigEndian k (n / 256) ++ [lowByte n]).foldl pushByte 0) = n
    rw [List.foldl_append]
    change byteValue (bigEndian k (n / 256)) * 256 + n % 256 = n
    rw [ih _ bound]; omega

end Uuid58
