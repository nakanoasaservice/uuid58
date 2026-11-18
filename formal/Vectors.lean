import Lean.Data.Json
import Spec

open Lean Uuid58

private def field (j : Json) (key : String) : Except String String :=
  j.getObjValAs? String key

-- Only the numeric codec is under test. Read the UUID column as a hex integer.
private def uuidValue (s : String) : Except String UUID := do
  let hex := (s.replace "-" "").toLower.toList
  unless hex.length = 32 do throw s!"bad UUID in vectors: {s}"
  let mut n := 0
  for c in hex do
    let i := "0123456789abcdef".toList.idxOf c
    unless i < 16 do throw s!"bad hex in vectors: {s}"
    n := 16*n + i
  if h : n < 2^128 then return ⟨n, h⟩ else throw "UUID outside 128 bits"

private def checkPair (uuid encoded : String) : Except String Unit := do
  let v ← uuidValue uuid
  unless encode v = bytes encoded do throw s!"wrong encoding for {uuid}"
  match decode (bytes encoded) with
  | .ok u => unless u = v do throw s!"wrong value for {encoded}"
  | .error e => throw s!"failed to decode {encoded}: {repr e}"

private def kind : Uuid58.Error → String
  | .invalidLength => "invalid_length"
  | .invalidCharacter => "invalid_character"
  | .overflow => "overflow"

private def checkVectors (json : Json) : Except String Nat := do
  unless (← field json "spec_version") = "1.1.0" do throw "spec version mismatch"
  unless bytes (← field json "alphabet") = alphabet do throw "alphabet mismatch"
  let pairs ← json.getObjValAs? (Array Json) "roundtrip"
  let extra ← (← json.getObjVal? "encode").getObjValAs? (Array Json) "valid"
  let invalid ← (← json.getObjVal? "decode").getObjValAs? (Array Json) "invalid"
  for c in pairs do checkPair (← field c "uuid") (← field c "uuid58")
  for c in extra do checkPair (← field c "input") (← field c "output")
  for c in invalid do
    let expected ← c.getObjValAs? (Array String) "errors"
    match decode (bytes (← field c "input")) with
    | .error e => if expected.contains (kind e) then continue
    | .ok _ => pure ()
    throw s!"wrong rejection for {← field c "description"}"
  return pairs.size + extra.size + invalid.size

def main (args : List String) : IO Unit := do
  let [path] := args | throw (IO.userError "expected path to spec/vectors.json")
  let json ← IO.ofExcept (Json.parse (← IO.FS.readFile path))
  IO.println s!"Checked {← IO.ofExcept (checkVectors json)} numeric codec vectors."
