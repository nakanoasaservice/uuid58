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
sha="$(git rev-parse --verify "$ref^{commit}")"
tmp="$(mktemp -d)"

cleanup() {
  git -C "$root" worktree remove --force "$tmp" >/dev/null 2>&1 || rm -rf "$tmp"
}
trap cleanup EXIT

git -C "$root" worktree add --quiet --detach "$tmp" "$sha"
ln -s "$root/node_modules" "$tmp/node_modules"
(cd "$tmp" && pnpm exec vp pack >/dev/null)

mkdir -p "$root/bench/.baseline"
cp "$tmp/dist/index.js" "$root/bench/.baseline/index.js"
printf '%s %s\n' "$sha" "$ref" > "$root/bench/.baseline/REF"
echo "Saved baseline from $ref ($(echo "$sha" | cut -c1-7)) to bench/.baseline/"
