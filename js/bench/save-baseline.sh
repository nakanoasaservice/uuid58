#!/bin/sh
# Builds the library at a git ref and saves the bundle as the benchmark baseline.
#
#   pnpm bench:baseline          # baseline = HEAD (last commit)
#   pnpm bench:baseline main     # baseline = main, e.g. to measure a whole branch
#
# The working tree is not touched: the ref is checked out into a temporary
# git worktree that reuses this checkout's node_modules.
set -eu

ref="${1:-HEAD}"
root="$(git rev-parse --show-toplevel)"
pkg="$root/js"
sha="$(git rev-parse --verify "$ref^{commit}")"
tmp="$(mktemp -d)"

cleanup() {
  git -C "$root" worktree remove --force "$tmp" >/dev/null 2>&1 || rm -rf "$tmp"
}
trap cleanup EXIT

git -C "$root" worktree add --quiet --detach "$tmp" "$sha"
# Refs from before the move into js/ have the package at the repository root.
src="$tmp/js"
[ -f "$src/package.json" ] || src="$tmp"
ln -s "$pkg/node_modules" "$src/node_modules"
(cd "$src" && pnpm exec vp pack >/dev/null)

mkdir -p "$pkg/bench/.baseline"
cp "$src/dist/index.js" "$pkg/bench/.baseline/index.js"
printf '%s %s\n' "$sha" "$ref" > "$pkg/bench/.baseline/REF"
echo "Saved baseline from $ref ($(echo "$sha" | cut -c1-7)) to js/bench/.baseline/"
