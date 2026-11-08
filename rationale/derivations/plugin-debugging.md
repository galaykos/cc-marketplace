# Derivations — debugging

Each section holds what made a check exist, its measurements and history, so the file's own header stays three lines.

## plugins/debugging/hooks/fix-chain.sh

Added 2026-11-07 (Process track, gitignored `taskmaster-docs/integration-roadmap-2026-11-07.md` item PR1). In session
4552acb6 of `rationale/session-retro-2026-11-05.md` (issue 17) fixes #68–#72 each exposed the next failure: about 5 h
and 6 PRs before anything stopped the chain. `hooks/remind.sh` fires on stuck-loop phrases in the prompt and did not
fire until "am I a joke to you?"; the `suggest.ts` mod offers `/debugging:debug` in the prompt box after the same Bash
command fails twice, which a chain of shipped fixes never does. The signal used here is the commit history: two fix
commits made since the session's first prompt that touch a common file. The first prompt records the session start
(epoch seconds, keyed on the transcript path), so a chain that began in an earlier session is not seen. Merge commits
add no files, so a PR chain counts through its fix-named branch commits. Harness: `scripts/__tests__/fix-chain.test.sh`.
