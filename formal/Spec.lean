import Std

/-! uuid58 specification 1.1.0, sections 2–4. Text is a sequence of bytes;
section 4.1 permits measuring the input length in bytes. -/
namespace Uuid58

abbrev Byte := Fin 256
abbrev Digit := Fin 58
abbrev UUID := Fin (2^128)

def bytes (s : String) : List Byte := s.toUTF8.data.toList.map UInt8.toFin

def alphabet := bytes "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

def symbol (d : Digit) : Byte := alphabet[d.val]!

def digit? (b : Byte) : Option Digit :=
  let i := alphabet.idxOf b
  if h : i < 58 then some ⟨i, h⟩ else none

/-- The positional polynomial of section 3.1, most significant digit first. -/
def value : List Digit → Nat
  | [] => 0
  | d :: ds => d.val * 58^ds.length + value ds

/-- Emit exactly `width` digits, including leading zero digits. -/
def digits : Nat → Nat → List Digit
  | 0, _ => []
  | k+1, n => ⟨n / 58^k % 58, Nat.mod_lt _ (by decide)⟩ :: digits k (n % 58^k)

def encode (v : UUID) := (digits 22 v.val).map symbol

def parse : List Byte → Option (List Digit)
  | [] => some []
  | b :: bs => do return (← digit? b) :: (← parse bs)

inductive Error where
  | invalidLength | invalidCharacter | overflow
  deriving DecidableEq, Repr

def decode (s : List Byte) : Except Error UUID :=
  if s.length ≠ 22 then .error .invalidLength
  else match parse s with
    | none => .error .invalidCharacter
    | some ds =>
      if h : value ds < 2^128 then .ok ⟨value ds, h⟩ else .error .overflow

end Uuid58
