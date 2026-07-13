---
description: On-demand Tier-2 reuse check — per-language dead-code tool shellout, export-aware orphan/reachability detection, and a deprecated-reference report for a symbol or path. Warn-only, never edits code.
argument-hint: [symbol|path]
---

Run the precise, expensive reuse check the ambient Tier-1 hook deliberately skips. This is
**warn-only**: you report findings, you **never edit code** and never treat a finding as a
gate. `$ARGUMENTS` is the target — a symbol name, a file, or a directory. If empty, scope to
the symbols the current change touched (or ask which symbol/path to check).

## 1. Detect the ecosystem, then shell out with the adapter contract

Detect each manifest present at the repo root and, for the matching language, run its dead-code
tool **only if it is on `PATH`**. A tool that is absent, misconfigured, errors, or times out →
**degrade** to the export-aware heuristic in step 2 and say precision was unavailable — never
fail the command. Apply a **timeout (~60s)** and an **output cap (~200 lines)** to every tool.

- **JS/TS — `package.json` present:** prefer **`knip`** (`npx --no-install knip` or `knip`);
  `ts-prune` is deprecated in favor of knip, use it only as a fallback if knip is absent.
  **Exit code:** a non-zero exit from knip usually means "found unused/dead exports," **not**
  failure — parse the reported unused files/exports from stdout; treat a run that produced
  parseable findings as success regardless of exit status. A tool crash with no findings →
  degrade.
- **Python — `pyproject.toml`/`setup.cfg`/any `*.py`:** run **`vulture`** (`vulture <path>`).
  **Exit code:** vulture **exits 0 even with findings** — do not read the exit code as the
  signal; parse stdout (`<file>:<line>: unused function 'x' (NN% confidence)`). Favor higher
  confidence; note low-confidence items as soft.
- **Go — `go.mod` present:** run **`deadcode`** (`go run golang.org/x/tools/cmd/deadcode ./...`).
  It needs a **buildable `main`**; a library-only module or a build error → degrade (note that
  deadcode cannot analyze reachability without an entrypoint). A non-zero exit that still lists
  functions is findings, not failure.
- **Rust — `Cargo.toml` present:** best-effort only. `cargo-udeps` reports unused **dependencies**,
  not dead **symbols** (wrong granularity), so it does **not** answer this question — note this
  documented gap and fall through to the heuristic (compiler `dead_code` warnings from a normal
  `cargo build` are the closest signal if already available; do not force a build).
- **Any other language / no manifest:** language-agnostic heuristic only (step 2).

## 2. Export-aware orphan / reachability detection (low false-positive)

This is where the structural false positives live, so bound it tightly:

1. Locate the target symbol's definition(s).
2. Count **inbound references** repo-wide (`grep`/`rg` the identifier), then subtract the
   definition site(s) and any references that live **only in test files** — a symbol used
   solely by tests is test-scaffolding, note it separately, do not call it a live production use.
3. Report the symbol as an **orphan** *only* when **both** hold: it is **module-private /
   non-exported** (not part of a public surface) **and** it has **zero** non-definition,
   non-test inbound references.
4. **Exclude exported / public-API symbols from the orphan verdict.** A library export, a
   barrel/`index` re-export, an `export … as` alias, a `pub`/`public` item, or a symbol
   referenced by name in a config/manifest may have all its callers outside this repo — reporting
   these as dead is the classic false positive. For an exported symbol, report inbound-ref *count*
   as information, not an orphan verdict.

## 3. Deprecated-reference report

Independently of orphan status, report where the target is **referenced despite being
deprecated**: check the target's definition for a deprecation marker (`@deprecated`,
`#[deprecated]`, `[Obsolete]`, `Deprecated:` doc-comment, `DeprecationWarning`,
`typing_extensions.deprecated`, or a plain `DEPRECATED`/`TODO: remove` comment). If it is
deprecated, list every site that still references it and name the documented replacement if one
is given. This is the Tier-2 answer to the ambient hook's one-line warning.

## 4. Output

Emit a short advisory report — no file writes, no edits:

- **Tool used** (which adapter ran, or "degraded to heuristic" and why).
- **Deprecated?** yes/no + marker location + replacement, and the reference sites if deprecated.
- **Orphan?** for a module-private symbol with zero live inbound refs, say so and where it is
  defined; for an exported symbol, report the inbound-ref count and explicitly note it is
  excluded from the orphan verdict (callers may be external).
- **Recommendation** — remove the orphan, migrate off the deprecated symbol to its replacement,
  or "looks live, safe to reuse." Advisory only; the user or a follow-up decides and edits.

Composition: this command owns reuse-time deadness and on-demand orphan/reachability. Defer the
"dead code as a review-catalog" framing to `code-review` code-smells, speculative-generality /
don't-build-dead-weight to `code-architecture` yagni-check, and whole-package/dependency-level
deprecation to `packages` package-hygiene.
