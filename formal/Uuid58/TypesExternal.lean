module
public import Aeneas

@[expose] public section

/-- The crate only observes the error tag of `from_utf8`. -/
@[rust_type "core::str::error::Utf8Error"]
abbrev core.str.error.Utf8Error := Unit
