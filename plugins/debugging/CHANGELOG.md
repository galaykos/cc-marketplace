# Changelog — debugging

Consumer-facing changes only. Newest first. Started at 0.9.2; earlier versions have no entries rather than invented ones.

## 0.12.0 — 2026-11-10

- **The prompt-box suggestion is removed.** `hooks/suggest.ts` offered `/debugging:debug` after the same command failed twice. On the owner's machine it was never shown once between 2026-10-25 and 2026-11-10, and the four sibling suggestions were accepted 0 times of 16 shown. The plugin ships no hooks module now; the classic reminder, the fix-chain hook and the probe guard are unchanged, and `CC_SUGGEST` no longer does anything here.

## 0.11.0 — 2026-11-08

- **`scripts/ci-triage.sh` reads a red CI run.** Through the `gh` CLI you already have (it never installs gh or logs in), it finds the newest failed GitHub Actions run on the current branch, or `--pr N`, `--run ID`, `--branch B`, with `--repo OWNER/REPO` for another repository. It prints the run URL, the failing job and step, that step's first error with a few lines of context, and the other failing steps. The first error is found in pytest, PHPUnit, Jest, Vitest, go test, compiler (gcc, tsc, rustc) and generic `Error:` output; when none matches, it prints the step's last lines and says so. The log is treated as untrusted: ANSI and control bytes are stripped, each line is cut at 240 bytes, at most 8 MiB is read, and it prints inside a fence labelled as CI log data, after a line telling the reader not to follow instructions in it. Job and step names, which a fork's PR controls, lose their double quotes and every list of them is labelled untrusted. Exit 0 found, 1 no failed run, 2 usage, 3 gh missing or not logged in, 4 any other gh failure, including a checkout with no GitHub remote. `systematic-debugging` and `/debugging:debug` run it first when the symptom is a red CI run. Standing: the script's behaviour is a gate where run (`scripts/__tests__/ci-triage.test.sh`, 40 cases, against a stub gh); that the model runs it first is recorded.
- **A commit that would ship a `[DEBUG-` probe asks first.** New PreToolUse hook `hooks/probe-guard.sh`: for a `git commit`, and no other git command, whose staged diff adds a line holding `[DEBUG-` (the tag `systematic-debugging` puts on every temporary probe), it returns an ask naming the files and lines. With `-a` or `--all` it reads the tracked changes the commit would stage; `-uall` and `-S<keyid>` are not read as `-a`. Unstaged probes, removed lines and a commit message naming the marker stay silent. It asks and never denies. `CC_PROBE_GUARD=off`, or the `cc_probe_guard` option under `/config`, turns it off. Standing: gate where installed; `scripts/__tests__/probe-guard.test.sh`, 29 cases.

## 0.10.1 — 2026-11-08

- **`systematic-debugging` says how to prove the regression test guards the fix.** With the fix reverted the test must fail, with it restored it must pass. When the testing plugin is installed, its `scripts/red-proof.sh` does this and checks the restored working tree is byte-identical; without it, revert by hand. Standing: gate where run; nothing makes it run.
- **The red-proof step says where the script is and what exit 5 means.** The script ships in the testing plugin, so this plugin's root does not reach it: the skill names the lookup, the `installPath` of the `testing@…` entry in `claude plugin list --json`, else the newest copy in the plugins cache. Exit 5 means red-proof could not restore the fix: run the restore commands it prints first. Standing: recorded.

## 0.10.0 — 2026-11-07

- **A chain of fix commits now triggers the debugging discipline.** New UserPromptSubmit hook `hooks/fix-chain.sh`: once this session has made two fix commits (subject `fix`, `fixes`, `fixed`, `hotfix` or `bugfix`, or a merged `*fix*` branch) that touch a common file, the next prompt gets one advisory line, and again at four. The line says the diagnosis is likely wrong and to reproduce the original symptom before another fix. In one recorded session, five fix PRs each exposed the next failure and the keyword reminder did not fire until the user's outburst. `CC_REMIND=off` silences it. Standing: advisory; `scripts/__tests__/fix-chain.test.sh`, 10 cases.

## 0.9.3 — 2026-10-28

- **The `systematic-debugging` skill's description now reads in short, plain sentences.** Same triggers and steps; it keeps the words the model matches it on.

## 0.9.2 — 2026-10-28

- **Comments cut to what a reader needs; behaviour unchanged.** `hooks/remind.sh` (generated hook): each keeps a header saying what it does and misses, and one line per trap the code cannot show; the history moved to the marketplace repository's rationale/derivations/, which an install does not contain.
