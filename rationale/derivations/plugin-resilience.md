# resilience scripts: why, limits, history

Each `##` heading is a file under `plugins/resilience/` whose header points here by name. Standing: `recorded` — no gate reads this file; its dates and measurements are as they stood when written.

## plugins/resilience/scripts/diff-risk.sh

Written 2026-11-08 for Track 3 item Q7 of the 2026-11-07 integration roadmap: a diff risk score from the revert and hotfix history of the touched files, wired into `/resilience:review`. The owner decided it informs only: it never blocks and never changes which rubrics run.

**The formula.** score = 3 × reverts + 2 × fixes + 1 × follow-ups. A follow-up is a revert or fix whose author date is at most 14 days after the file's previous commit, so the formula reads as "per revert 3, per fix 2, +1 when it came quickly". The weights are a judgment, not a fit: a revert says a change shipped broken badly enough to undo, a fix says it shipped broken, and a quick one says the breakage surfaced soon after the change. Nothing measured them.

**What counts.** Subjects only, lower-cased. A revert is git's own `Revert "…"` or a conventional `revert:` / `revert(scope):` / `revert!:`. A fix is a whole word from `fix fixes fixed hotfix hotfixes hot-fix bugfix bugfixes bug-fix`, where a word is a run of letters, digits, `_` and `-`. The hyphen inside the word is what keeps `fixed-width`, `fix-up` and `prefix` out; `fixture` is never a listed word. A revert subject that quotes a fix counts once, as a revert. Merge commits are skipped (`--no-merges`).

**Which history.** The log starts at the merge-base, not at HEAD, so the branch's own commits are the change under review and never score it. `--full-history` keeps commits that history simplification would drop, so the pathspec walk and the unfiltered walk see the same commits.

**One walk.** One `git log` per run, pathspec-limited to the touched files with `--literal-pathspecs`. A touched name git prints C-quoted (a quote, backslash or control byte in it) cannot be passed back as a pathspec, and neither can more than 2,000 names; either case walks without a pathspec and awk filters by name. Both sides are read with `core.quotePath=false`, so a quoted name matches its quoted self. Measured 2026-11-08 on this repository (1,240 commits): 0.04 s for a 6-file diff over one year, 0.5 s for 937 files over ten years.

**Untrusted text.** Subjects reach awk on stdin and leave through `printf "%s"`; nothing passes them to a shell, an `eval` or a format string. Control bytes (0x01–0x1f, 0x7f) print as `?`, so an escape sequence in a subject cannot drive the terminal. The `--since` value and the base label reach awk through `ENVIRON`, not `-v`, which would process backslash escapes.

**Exit codes.** 0 for every valid run, including nothing touched and nothing scored. 2 for usage and for no base: no `origin/HEAD`, `main` or `master`, a `--base` naming no commit, no shared history, or a repository with no commits. Falling back to HEAD there would silently drop the branch's committed changes, so the script asks for `--base`. 3 for not a git work tree, or git failing to read it. 4 for git or awk missing.

**Misses.** History before a rename (`--no-renames`; the old name is not followed). A fix whose subject never says fix, and a fix squashed into a feature commit. Signals older than `--since` (default one year), and the follow-up test for a file's oldest commit inside the window, whose previous change lies outside it. Lower-casing is ASCII only. A word like `fixed` in `fixed size buffer` counts as a fix.

## plugins/resilience/scripts/__tests__/diff-risk.test.sh

Builds a throwaway repository with dated commits (`GIT_AUTHOR_DATE` / `GIT_COMMITTER_DATE` as `@<epoch> +0000`), so the 14-day window and the one-year `--since` are tested against fixed day offsets rather than whatever the clock says. It isolates git from the machine's config (`GIT_CONFIG_GLOBAL`, `GIT_CONFIG_NOSYSTEM`, `GIT_CEILING_DIRECTORIES`) and unsets `GIT_DIR`, so a run from inside a git hook cannot write to the outer repository.

The metacharacter subject uses `touch pwned_*` canaries, not the `$(rm -rf /)` the roadmap brief named: a canary proves the text never ran without a regression being able to delete anything. The near-miss subjects (`prefix fixture`, `fixed-width font`, `Reverting is hard: notes`) are the input the score must stay silent on.

Mutation check on 2026-11-08: seven broken copies of the script (revert weight 2, `-` splitting words, a subject passed to `sh -c`, no control-byte sanitizing, the walk started at HEAD, no follow-ups, a quoted name passed as a pathspec) each drew at least one FAIL. The harness also passed under busybox awk as well as mawk.
