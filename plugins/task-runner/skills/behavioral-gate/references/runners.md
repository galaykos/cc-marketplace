# Per-runner empty-detection

An empty suite that exits 0 is the canonical false-green, and runners signal "no tests"
differently. `behavioral-gate.sh` is authoritative; this mirrors it. **Fail-closed:** no
positive "N ran and passed" signal is a failure, not a pass, and unparseable output is exit
2. All of it runs under a hard timeout (`timeout`/`gtimeout`, else a `perl` alarm+fork
returning 124), so a hang is a verdict rather than a block.

| Runner | Empty signal | Detection |
|---|---|---|
| `pytest` | exit **5** | exit 5 ⇒ `empty-suite` |
| `node --test` | `tests 0`, no counts, exits 0 | parse executed counts, not `tests N` |
| `jest` | exit 1 "No tests found" **unless** `--passWithNoTests` | that flag masks the signal ⇒ `unverifiable-suite` |
| `vitest` | exits 0 "no test files found" | "no test files" / 0 collected |
| `go test ./...` | `no test files`, exits 0 | covered first: a real result line beats a no-test package |
| `package.json` script (opaque) | no parseable count | fail closed — never a silent pass |
| `vendor/bin/pest`, else `phpunit` | `No tests executed` / `No tests found` | covered needs `OK (N tests`, a non-zero `Tests:`, or `FAILURES!` |
| `cargo test` | `0 passed` on **every** target | covered first (one line per target); `error[E…]` ⇒ `unverifiable-suite` |
| `bundle exec rspec`, else `rspec` | `0 examples` | empty first — one summary line per run |
| `./gradlew test --rerun-tasks`, else `./mvnw test`, else system `gradle`/`mvn` (wrappers first) | `Tests run: 0`, `:test NO-SOURCE`, `did not discover any tests` | covered needs `Tests run: N≥1` or `N tests completed`, else the weak row below; `:test UP-TO-DATE` ⇒ `unverifiable-suite` |
| `--runner '<cmd>::<empty-regex>'` | the caller's regex | escape for a language with no row; the gate still owns not-started (126/127/signal) and timeout (124) |

**The one weak row.** A green `gradle test` prints no counts, only `BUILD SUCCESSFUL`
(9.7.1, 2026-09-22), so it falls back to *sources exist and the task did not fail*. Past it:
a `--tests` filter, or `failOnNoDiscoveredTests=false` (true by default on 9, so there that
property detects empty, not this gate). `--rerun-tasks` is needed because the gate runs from
a copied checkout carrying `build/`, where a plain `gradle test` executes nothing.

## Adding a runner

Extend `behavioral-gate.sh` and add a row; an uncharacterized empty signal is fail-closed,
never assumed-pass. `--runner`'s residual is the caller's — a regex that never matches turns
an empty suite green and nothing here can tell — so state the regex in the run report.
