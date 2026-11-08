# Changelog — debugging

Consumer-facing changes only. Newest first. Started at 0.9.2; earlier versions have no entries rather than invented ones.

## 0.10.1 — 2026-11-08

- **`systematic-debugging` says how to prove the regression test guards the fix.** With the fix reverted the test must fail, with it restored it must pass. When the testing plugin is installed, its `scripts/red-proof.sh` does this and checks the restored working tree is byte-identical; without it, revert by hand. Standing: gate where run; nothing makes it run.

## 0.10.0 — 2026-11-07

- **A chain of fix commits now triggers the debugging discipline.** New UserPromptSubmit hook `hooks/fix-chain.sh`: once this session has made two fix commits (subject `fix`, `fixes`, `fixed`, `hotfix` or `bugfix`, or a merged `*fix*` branch) that touch a common file, the next prompt gets one advisory line, and again at four. The line says the diagnosis is likely wrong and to reproduce the original symptom before another fix. In one recorded session, five fix PRs each exposed the next failure and the keyword reminder did not fire until the user's outburst. `CC_REMIND=off` silences it. Standing: advisory; `scripts/__tests__/fix-chain.test.sh`, 10 cases.

## 0.9.3 — 2026-10-28

- **The `systematic-debugging` skill's description now reads in short, plain sentences.** Same triggers and steps; it keeps the words the model matches it on.

## 0.9.2 — 2026-10-28

- **Comments cut to what a reader needs; behaviour unchanged.** `hooks/remind.sh` (generated hook): each keeps a header saying what it does and misses, and one line per trap the code cannot show; the history moved to the marketplace repository's rationale/derivations/, which an install does not contain.
