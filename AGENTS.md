# AGENTS.md

## Language

Write issues, pull requests, and commit messages in English.

## Layout

One implementation per directory, all checked against `spec/vectors.json`. `site/` is the website (it builds against `js/` and reads `spec/`). `formal/` holds the Lean proofs.

## Toolchain and verify commands

Toolchain majors are selected in each directory's `mise.toml`. For JavaScript, `package.json` pins development Node.js in `devEngines.runtime` and pnpm in `packageManager`; Vite+ reads those pins. Run the commands from that directory; they mirror `.github/workflows/ci-<name>.yml`.

| Dir | Toolchain | Verify |
| --- | --- | --- |
| `js/` | Node 24, pnpm 12, Vite+ (`vp`) | `pnpm install --frozen-lockfile`, `vp check`, `vp test run`, `vp pack`, `vp exec jsr publish --dry-run` |
| `site/` | Node 24, pnpm 12, Vite+ (`vp`) | `pnpm install --frozen-lockfile`, `vp check`, `vp build` |
| `python/` | uv 0.13 (CI: Python 3.10-3.15) | `uv sync --locked`, `uv run ruff check`, `uv run ruff format --check`, `uv run mypy`, `uv run pytest`, `uv build` |
| `rust/` | stable + MSRV 1.85 | `cargo fmt --check`, `cargo clippy --locked --all-targets --all-features -- -D warnings`, `cargo test --locked --all-features` (CI also runs no-default-features, `thumbv7em-none-eabi`, docs, MSRV, `cargo publish --dry-run`) |
| `go/` | Go 1.27 locally (CI: 1.26 and stable) | `gofmt -l .` (must be empty), `go vet ./...`, `go test -race ./...` |
| `java/` | Temurin 25, Maven via `./mvnw` (CI: Java 8, 17, 21, 25) | `./mvnw -B verify` |
| `dotnet/` | .NET 10 SDK + .NET 8 runtime | `dotnet format --verify-no-changes`, `dotnet build -c Release`, `dotnet test -c Release --no-build` |
| `ruby/` | Ruby 4.0 locally (CI: 3.2 and latest) | `bundle install`, `bundle exec rake test`, `bundle exec rake build` |
| `dart/` | Dart 3.14 locally (CI: 3.6 and stable) | `dart pub get`, `dart format --output=none --set-exit-if-changed .`, `dart analyze --fatal-infos`, `dart test` |
| `postgres/` | PostgreSQL 14 and 18 | `psql -v ON_ERROR_STOP=1 -f test.sql` |
| `mysql/` | MySQL 8.4 and 26, MariaDB 10.11 and 12 | `./test.sh` |
| `/` (Nix) | Nix with flakes | `nix flake check -L` |
| `spec/`, `formal/` | Python 3, Lean + Aeneas (`formal/lean-toolchain`, `formal/aeneas-version`) | `python3 spec/generate_vectors.py --check`, `formal/check.sh` |

## CI

- `ci.yml` runs on every PR to `main`. Its `changes` job picks the `ci-*.yml` jobs from the changed paths (`spec/` or `ci.yml` changes run all language jobs); `actions-lock` runs only when `.github/workflows/**` (including `actions.lock`) or an `action.yml` / `action.yaml` manifest changes.
- `check` is the single required status check. It always reports; skipped jobs count as passing.
- Actions are locked in `.github/workflows/actions.lock`. After changing any `uses:`, run `gh actions-lock` (extension `github/gh-actions-lock`) and commit the lockfile; CI runs `gh actions-lock --verify`.

## Dependency updates

- Dependabot opens update PRs (`.github/dependabot.yml`): language ecosystems daily, `github-actions` and `nix` weekly, with a cooldown. Patch/minor updates are grouped per directory; each major is its own PR.
- `.github/workflows/dependabot-triage.yml` enables auto-merge for patch/minor updates on versions >= 1.0. GitHub merges them once `check` passes. Majors, 0.x minors and updates without a SemVer type (for example `nix` flake inputs) are left for review.
- Dependabot updates `actions.lock` together with the workflow files in `github-actions` PRs.

Not managed by Dependabot (update by hand, together):

- The Vite+ toolchain in `js/` and `site/`: `vite-plus` and the Vite core alias are pinned in each `pnpm-workspace.yaml` catalog; Vitest is bundled with Vite+. Update both directories together with `vp migrate` and refresh both lockfiles. CI and release workflows resolve the Vite+ version from each directory's catalog automatically.
- `uv_build` in `python/pyproject.toml`: keep it in step with `[tool.uv] required-version` and `python/mise.toml`.
- Maven in `java/.mvn/wrapper/maven-wrapper.properties`: keep it in step with `java/mise.toml`.
- JUnit majors in `java/pom.xml`: JUnit 6 requires Java 17, and the library targets Java 8.
- Toolchain versions in `mise.toml` files, CI matrices, and `formal/lean-toolchain` / `formal/aeneas-version` (with the SHA-256 sums in `ci-spec.yml`).

## Deploys and releases

- Merging to `main` deploys the website to GitHub Pages (`pages.yml`) when the merge touches `site/`, `js/`, `spec/` or `pages.yml`. Nothing else deploys or publishes on merge.
- Packages publish only when a release tag is pushed. Each tag triggers its workflow and creates a GitHub Release:

  | Tag | Workflow | Publishes to |
  | --- | --- | --- |
  | `js/v*` | `publish.yml` | npm and JSR |
  | `python/v*` | `publish-python.yml` | PyPI |
  | `rust/v*` | `publish-rust.yml` | crates.io |
  | `go/v*` | `publish-go.yml` | Go module proxy, CLI binaries, Homebrew tap |
  | `java/v*` | `publish-java.yml` | Maven Central |
  | `dotnet/v*` | `publish-dotnet.yml` | NuGet |
  | `ruby/v*` | `publish-ruby.yml` | RubyGems |
  | `dart/v*` | `publish-dart.yml` | pub.dev |

- PostgreSQL, MySQL, and Nix have no publish workflow. PHP is developed and released in `nakanoasaservice/uuid58-php`, like Swift in `uuid58-swift`.
- Do not push release tags or run publish commands unless asked.
