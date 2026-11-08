# Changelog — toolchain-experts

Consumer-facing changes only. Newest first. Started at 0.4.1; earlier versions have no entries rather than invented ones.

## 0.4.3 — 2026-11-08

- **analyzer-triage: never regenerate or extend a baseline to make findings disappear.** Step 5 said a new defect could be fixed "or added to baseline with a reason". Now a new defect is fixed, or that one line is suppressed with its reason. Writing baseline entries (phpstan `--generate-baseline`/`-b`, psalm `--set-baseline`, eslint `--suppress-all`/`--suppress-rule`, or a hand edit) is the user's decision. Shrink-only runs (psalm `--update-baseline`, eslint `--prune-suppressions`) are named as fine. rector and biome keep no baseline file, and biome's `lint --suppress` is named as the same move. Standing: agent-graded here. Where command-guard 0.9.5 is installed it is a gate, with a human in it: config-guard asks before those flags run or an existing baseline file is edited.
- `detect-analyzers.sh` also reports a PHP-format phpstan baseline (`phpstan-baseline.php`). Standing: gate (`detect-analyzers.test.sh`).

## 0.4.2 — 2026-10-31

- **eslint's baseline is `eslint-suppressions.json`, not `.eslintcache`.** `scripts/detect-analyzers.sh` reported the lint cache in the baseline slot. It now reports ESLint's bulk-suppressions file at the project root, or `-`. A custom `--suppressions-location` is not followed. Standing: gate — `detect-analyzers.test.sh`.
- **`level: max` now prints a strictness line.** The phpstan level was read as digits only, so `level: max` printed nothing. It now prints `strictness phpstan level max`, and `level unparsed` when a `level:` key exists but cannot be read (a `%parameter%`, say). Standing: gate — `detect-analyzers.test.sh`.
- **php-expert names the right level reach.** It said nullables go unchecked at level 5 and argument types below level 2. Per phpstan.org/user-guide/rule-levels, argument types are checked from level 5 and calls on nullable types from level 8.

## 0.4.1 — 2026-10-28

- **Comments cut to what a reader needs; behaviour unchanged.** `scripts/detect-analyzers.sh`: each keeps a header saying what it does and misses, and one line per trap the code cannot show; the history moved to the marketplace repository's rationale/derivations/, which an install does not contain.
