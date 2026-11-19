import Lean.Data.Json
import UuidText

open Lean Uuid58

private def field (j : Json) (key : String) : Except String String :=
  j.getObjValAs? String key

/-- JSON strings contain Unicode scalar values. JS counts a supplementary scalar as two units. -/
private def utf16 (s : String) : List Js.CodeUnit := s.toList.flatMap fun c =>
  let n := c.toNat
  if n < 0x10000 then [Fin.ofNat _ n] else
    let offset := n - 0x10000
    [Fin.ofNat _ (0xD800 + offset / 1024), Fin.ofNat _ (0xDC00 + offset % 1024)]

private def checkPair (uuid encoded : String) (canonical : Bool) : Except String Unit := do
  let .ok w := Js.Text.parse (utf16 uuid) | throw s!"failed to parse {uuid}"
  let v := w.val.uuid w.property
  if canonical && Js.Text.canonical w.val != utf16 uuid then throw s!"wrong UUID spelling for {encoded}"
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
  let invalidUuid ← (← json.getObjVal? "encode").getObjValAs? (Array Json) "invalid"
  let invalid ← (← json.getObjVal? "decode").getObjValAs? (Array Json) "invalid"
  for c in pairs do checkPair (← field c "uuid") (← field c "uuid58") true
  for c in extra do checkPair (← field c "input") (← field c "output") false
  for c in invalidUuid do
    let expected ← c.getObjValAs? (Array String) "errors"
    match Js.Text.parse (utf16 (← field c "input")) with
    | .error e => if expected.contains (kind e) then continue
    | .ok _ => pure ()
    throw s!"wrong UUID rejection for {← field c "description"}"
  for c in invalid do
    let expected ← c.getObjValAs? (Array String) "errors"
    match decode (bytes (← field c "input")) with
    | .error e => if expected.contains (kind e) then continue
    | .ok _ => pure ()
    throw s!"wrong rejection for {← field c "description"}"
  return pairs.size + extra.size + invalidUuid.size + invalid.size

def main (args : List String) : IO Unit := do
  let [path] := args | throw (IO.userError "expected path to spec/vectors.json")
  let json ← IO.ofExcept (Json.parse (← IO.FS.readFile path))
  IO.println s!"Checked {← IO.ofExcept (checkVectors json)} UUID string and numeric codec vectors."
