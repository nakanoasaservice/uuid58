#!/usr/bin/env bash
# Regenerate the Rust and JavaScript models on every run.
set -euo pipefail
formal=$(cd "$(dirname "$0")" && pwd)
cd "$formal"
aeneas=$(realpath "${AENEAS_DIR:?Set AENEAS_DIR to the extracted Aeneas release (see formal/README.md)}")
backend="$aeneas/backends/lean"
if [[ "$("$aeneas/aeneas" -version)" != "aeneas $(cat aeneas-version)" ]] ||
   [[ "$(cat lean-toolchain)" != "$(cat "$backend/lean-toolchain")" ]]; then
  echo "The Aeneas release must match formal/aeneas-version and formal/lean-toolchain." >&2
  exit 1
fi
# Resolve elan's selected toolchain before changing directories.
lean_bin="$(lean --print-prefix)/bin"
rust_nightly=$(python3 -c 'import sys, tomllib; print(tomllib.load(open(sys.argv[1], "rb"))["toolchain"]["channel"])' "$aeneas/rust-toolchain")
export RUSTUP_TOOLCHAIN="$rust_nightly"
if ! rustup run "$rust_nightly" rustc --version >/dev/null 2>&1; then
  rustup toolchain install "$rust_nightly" --profile minimal --component rust-src --no-self-update
fi

build=$(mktemp -d)
trap 'rm -rf "$build"' EXIT
(
  cd ../rust
  "$aeneas/charon" rustc --preset=aeneas --consts initializers --sysroot default \
    --start-from=crate::encode_array --start-from=crate::decode --start-from=crate::is_valid \
    --dest-file "$build/uuid58.llbc" -- --edition=2024 --crate-type=lib --crate-name=uuid58 src/lib.rs
)
"$aeneas/aeneas" -backend lean -loops-to-rec -warnings-as-errors -namespace RustUuid58 \
  -dest "$build" "$build/uuid58.llbc"

# Lake resolves the transitive revisions in the release's lake-manifest.json.
(cd "$backend" && MATHLIB_NO_CACHE_ON_UPDATE=1 "$lean_bin/lake" build +Aeneas:olean)
backend_path=$(cd "$backend" && "$lean_bin/lake" env printenv LEAN_PATH)
export LEAN_PATH="$build:$backend_path"
check=("$lean_bin/lean" -DwarningAsError=true)
(cd "$build" && "${check[@]}" -o Uuid58.olean Uuid58.lean)
python3 extract_js.py ../js/src > "$build/JsExtracted.lean"
python3 -B extract_js_text.py ../js/src > "$build/JsTextExtracted.lean"
"${check[@]}" -o "$build/JsNumber.olean" JsNumber.lean
(cd "$build" && "${check[@]}" -o JsExtracted.olean JsExtracted.lean)
(cd "$build" && "${check[@]}" -o JsTextExtracted.olean JsTextExtracted.lean)
for module in Spec Proofs Bytes Chunk RustTables RustEncode RustDecode JsEncode JsDecode JsValidate JsBytes UuidText JsTextParse JsText; do
  "${check[@]}" -o "$build/$module.olean" "$module.lean"
done
"${check[@]}" Audit.lean
"${check[@]}" --run Vectors.lean ../spec/vectors.json
