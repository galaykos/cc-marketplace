# Authority conflicts outside PHP and JS

> Last verified: 2026-08-02 — https://docs.astral.sh/uv/ · https://go.dev/doc/toolchain · https://rust-lang.github.io/rustup/overrides.html · https://learn.microsoft.com/dotnet/core/tools/global-json · https://pnpm.io/catalogs

The SKILL body's scan order covers PHP and JS/TS. This file covers the case that
makes other ecosystems different in kind rather than in filename: **two local
files disagree about the version, and the one that wins is not the obvious one.**

Naming where a floor is declared is not what this file is for — that is a lookup
anyone can do. Every entry below is a place where reading the obvious source, or
running the obvious command, returns a confidently WRONG answer. `lock beats
manifest, runtime beats lock` is the SKILL's rule; these five are the cases where
"runtime" itself is ambiguous, so cite BOTH sources and say which one decides.

## Go — the shell binary is not the compiler

`go version` reports the toolchain on `PATH`. It is not necessarily what builds
the module.

- `go.mod`'s `go` directive has been a **minimum**, not a pin, since 1.21.
- A `toolchain goX.Y.Z` line, or a `go` line newer than the local toolchain, makes
  the Go command **download and run a different compiler** — silently, by design,
  unless `GOTOOLCHAIN=local` forbids it.
- So the answer is decided by `go` + `toolchain` + `GOTOOLCHAIN`, and
  `go env GOTOOLCHAIN` is part of the evidence.
- `go.sum` is a checksum database, not a lockfile. It pins nothing; it verifies.
  Do not cite it as the source of an installed version.

## Rust — a file in the directory overrides the toolchain manager

- `rust-toolchain.toml` (or the legacy `rust-toolchain`) **overrides rustup for
  that directory tree**. `rustc -V` run from elsewhere, or with the file absent,
  answers a different question than the build does.
- `Cargo.toml`'s `rust-version` is the MSRV — a compatibility floor the crate
  claims, not the compiler in use.
- `Cargo.lock` is the dependency lock and does not constrain the compiler at all.
- Cite the toolchain file's `channel` when present; fall back to `rustup show
  active-toolchain`, never to a bare `rustc -V`.

## .NET — `dotnet --version` reports a resolution, not a choice

- `global.json` pins an SDK `version` plus a `rollForward` policy. The policy can
  select a **different SDK than the one `dotnet --version` prints** in a directory
  with no `global.json`, and a missing pinned SDK is a hard failure rather than a
  fallback, depending on the policy.
- `TargetFramework` in the `.csproj` is what the code targets; the SDK is what
  builds it. They are independent and both matter.
- Cite `global.json` + `dotnet --list-sdks`, not `dotnet --version` alone.

## Python — the lock carries its own floor, and a stale file outranks nothing

- `pyproject.toml`'s `requires-python` is the declared floor. `uv.lock` records
  its **own** `requires-python`, which can be STRICTER — the lock is authoritative
  and the manifest can read as more permissive than the project actually is.
- `.python-version` is intent (what the version manager should select). The
  interpreter inside the project's virtualenv is fact.
- A repo holding both `uv.lock` (or `poetry.lock` / `pdm.lock`) and a legacy
  `requirements.txt` is authoritative in the lock. Installing from the txt
  desynchronizes the environment from the lock without any error.
- One lockfile per repo: if two of `uv.lock` / `poetry.lock` / `pdm.lock` /
  `requirements*.txt` are committed and both are live, that is the finding.

## JVM — the version is not in the build script

- Gradle version catalogs live in `gradle/libs.versions.toml`; `build.gradle(.kts)`
  references them by alias. Reading the build script alone reports aliases, not
  versions.
- The `java { toolchain { languageVersion } }` block decides the compiler Gradle
  uses, independently of `JAVA_HOME` — so `java -version` can disagree with the
  build and both be "true".
- `gradle/wrapper/gradle-wrapper.properties` pins Gradle itself; the wrapper is
  the fact, a locally installed `gradle` is not.

## Cross-ecosystem overrides

`.tool-versions` (asdf) and `mise.toml` pin MANY runtimes at once and override
per-ecosystem files inside their tree. When one is present, read it first and
report it as the intended runtime for every language it names — then check
whether each ecosystem's own file agrees, and report the disagreement.

## pnpm `catalog:` is an alias, not a version

A dependency written `"react": "catalog:"` (or `catalog:react19`) is **not** a
version specifier. It resolves through the `catalogs` block of
`pnpm-workspace.yaml`. Reporting `catalog:` as the version — or giving up — breaks
every downstream skill that branches on a major (vite, nextjs, vue3, react all do).

Resolve it, then cite BOTH sources:

    react — 19.2.0  (package.json: "catalog:" → pnpm-workspace.yaml catalogs.default.react)

`workspace:*` and `workspace:^` resolve to the sibling package's own version in
this repo; cite the sibling's `package.json`, and flag that the published version
will differ from the local one.

## Red flags to add to the SKILL's list

- `go version` cited with no `toolchain` / `GOTOOLCHAIN` check.
- `rustc -V` cited from a tree containing `rust-toolchain.toml`.
- `dotnet --version` cited with a `global.json` present.
- A `requirements.txt` install proposed in a repo with a committed `uv.lock`.
- A version reported as literally `catalog:` or `workspace:*`.
- Two live lockfiles for one ecosystem in one repo.
