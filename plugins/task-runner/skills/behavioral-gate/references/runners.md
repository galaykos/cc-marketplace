# Per-runner empty-detection

The behavioral gate must fail an empty / zero-collected test suite (an empty suite that
exits 0 is the canonical false-green). Runners disagree on how they signal "no tests", so
detection is per-runner. `behavioral-gate.sh` is the authoritative implementation; this
table is the reference it mirrors.

| Runner | Empty signal | Detection |
|--------|--------------|-----------|
| `pytest` | exit code **5** ("no tests ran") | exit 5 ⇒ `empty-suite` |
| `node --test` | prints `tests 0` / no `pass`/`fail` counts, exits 0 | parse the summary; `tests 0` ⇒ `empty-suite` |
| `jest` | exits **1** with "No tests found" **unless** `--passWithNoTests` | run WITHOUT `--passWithNoTests`; "No tests found" / exit 1-no-tests ⇒ `empty-suite` |
| `vitest` | exits 0 "no test files found" | parse output for "no test files"/0 collected ⇒ `empty-suite` |
| `go test ./...` | prints `no test files`, exits 0 | grep `no test files` across packages ⇒ `empty-suite` when no package has tests |
| `package.json` script (opaque) | no parseable count | **fail closed** — a code-producing run whose runner emits no count ⇒ exit 2, never a silent pass |

## Fail-closed rule

The governing principle: for a run that needs behavioral coverage, the ABSENCE of a positive
"N tests ran and passed" signal is a **failure**, not a pass. A runner whose output cannot be
parsed for a non-zero collected count fails the gate. This inverts the historical default
(exit 0 = pass regardless of whether anything ran), which is exactly the false-green the gate
exists to remove.

## Timeout

Own-tests run under a hard timeout: `timeout`/`gtimeout` when present, else a `perl` alarm+
fork fallback (returns 124 on expiry). A suite that hangs is a gate failure with a timeout
label, not an indefinite block.

## Adding a runner

Extend `behavioral-gate.sh`'s detection function and add a row here. A new runner with no
reliable empty signal defaults to fail-closed until its signal is characterized — never add
it as an assumed-pass.
