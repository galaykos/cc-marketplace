# Changelog

## 0.9.1 — 2026-10-26

- **Shorter deny and ask messages; what is denied, asked or allowed is unchanged.** Each message now says what was blocked or what to confirm, the alternative, and one way out. A deny still says not to retry the command in another form; for the user it names the narrow exception, a regex line in `.claude/destructive-guard-allow`, instead of turning the whole guard off. The `cd` deny ends "then re-issue the corrected command"; config-guard asks "Confirm this is a real config change, not a way around a failing check." Gate: `destructive-guard.test.sh` and `config-guard.test.sh` pin the new texts; every earlier verdict case passes unchanged.

## 0.9.0 — 2026-10-15

- **A destructive guard that cannot finish now asks or blocks the call, where it used to let it run unjudged.** Both `destructive-guard.sh` entries in `hooks/hooks.json` set `onFailure: "block"` (added in CLI 2.1.295): a run the host cannot start, or one past the 15 s timeout, blocks the Bash, MCP shell, `Write` or `Edit` call. Two changes keep that off ordinary work. The entries start the script as `bash "${CLAUDE_PLUGIN_ROOT}/hooks/destructive-guard.sh"`, through the `bash` on PATH, not its `#!/bin/bash` shebang, so a host with no `/bin/bash` (NixOS) still runs it. And the script stops a judgment still running after 12 s and asks (`GUARD_DEADLINE`, which the harness lowers), on every CLI version and in every mode, `deny-only` included, since it has not ruled out a deny. Measured 2026-10-15 against a fake local Messages API, no model call, one run each: a 10,000-line `bash <<'EOF'` body (109 KB) under 0.8.5's guard was blocked at 15 s on 2.1.300 ("timed out; blocking because onFailure is \"block\"") and ran unjudged on 2.1.291; this version asks at 12 s on both. In a bwrap sandbox with no `/bin/bash` and `bash` on PATH, this version's first cut, which ran the script by path, blocked a plain `ls` on 2.1.300 ("failed; blocking because onFailure is \"block\"", `/bin/sh: … not found`); this version runs it and still denies `php artisan migrate:fresh`, on 2.1.291 as well. The script's own fail-open stays: a missing `jq`, unparseable input or an internal error still exits 0, which is not a hook failure, and with no `mktemp` or `sleep` the judgment runs unwatched. Below 2.1.295 the key is ignored, measured on 2.1.291 in a scratch config dir: `claude plugin validate --strict` passes, the plugin installs from a local marketplace, `claude plugin list` shows it enabled and `claude plugin details` lists its PreToolUse hook; the same copy with an invalid `timeout` fails validation and `details` cannot find the plugin. 2.1.300's validator checks the value (`continue` or `block`). The cost, stated in the README's Failure mode: with no `bash` on PATH at all, or the plugin dir gone under a running session, every such call is blocked from 2.1.295, and `CLAUDE_DESTRUCTIVE_GUARD=off` cannot lift it, since the script reads it; `/plugin disable command-guard` can. The watchdog adds ~3.5 ms a call (median 28.5 → 32 ms on `git status && ls -la`, 21 runs). Standing: **gate** for the key, the `bash` form and the deadline ask (`destructive-guard.test.sh`: "every destructive-guard entry in hooks.json sets onFailure: block", red against 0.8.5; each entry run through `/bin/sh -c` on a copy whose shebang names no interpreter, and a 2,000-line body under `GUARD_DEADLINE=1` asking once inside 3 s, both red against the first cut); **measured** that the host blocks such a run on 2.1.300 and runs it on 2.1.291 (above). config-guard's entry starts its script the same way, `bash "${CLAUDE_PLUGIN_ROOT}/hooks/config-guard.sh"`: run by path, it errored on a host with no `/bin/bash` and the ask never came. It keeps no `onFailure`, so a run that cannot start still lets the write through, as before. Standing: **gate** — `config-guard.test.sh` runs the entry through `/bin/sh -c` on a copy whose shebang names no interpreter and wants the ask; red against the path form.
- **`rm -rf \` is denied.** A recursive `rm` whose target's shell value is only backslashes (`\` ending the command, `'\'`, `\\`, `"\\"`) passed: `norm_cmd` drops backslashes, so the target vanished before the rules read it. `rm`'s own words are now read with the shell's quote removal, and so is a shell's `-c` script or `eval`'s arguments (`bash -c 'rm -rf \'`, `sudo bash -c 'rm -rf \\'`, `eval 'rm -rf \'`), and such a target is denied like `rm -rf /`. A backslash anywhere else is no target: this version's first cut grepped the whole segment, so it denied `rm -rf "$(echo "$p" | tr '\\' '/')"` (an ask), `find . -name '\\' -exec rm -rf {} +` and `rm -rf build # strip '\\' later`, and allowed every wrapped spelling. Git Bash on Windows takes a backslash path for a Windows one, so `\` is the current drive's root (read, not measured); Claude Code's dangerous-`rm` check flags the same target from 2.1.281; on Linux and macOS it names a file called `\`, so the deny costs nothing there. A `\` before a newline is a continuation, not a target, and a `\ ` before a space escapes it. Eleven `destructive-guard.test.sh` checks: the four spellings, `sudo rm -rf \` and `ls; rm -rf \` denied, all six allowed by 0.8.5; a continuation (`rm -rf build \` + newline + `dist`), one joining the next word, `rm -rf \ foo` and a non-recursive `rm -f '\'` stay allowed. Eight more (475 in all, with the failure bullet's six): the four wrapped spellings denied, the three first-cut denials back to 0.8.5's verdicts, and a `#` comment inside a `-c` script. Misses: `$'\\'`, a variable holding `\`, and a command `ssh` or `su -c` runs.
- **Docs.** The README's "Why you might want `deny-only`" names the host's dangerous-`rm` check and what it does not judge, where it said "any general-purpose command-risk check"; `rules.md` and the README state the timeout residual by CLI version, measured on 2.1.291 and 2.1.300.

## 0.8.5 — 2026-10-14

- **destructive-guard no longer times out on a large heredoc, so it no longer fails open on one.** Every heredoc body line went through the per-segment checks, each costing tens of forks, so a 21 KB `python3 - <<'EOF'` took 22.6 s against the hook's 15 s timeout: a 15 s stall, then the whole command ran unjudged. That shape is the batched multi-file write agents make most. A body is now dropped before the command is split, unless the line opening it names a shell (`rbash` and `mksh` too), `ssh`, `su`, `sudo -i`/`-s`, `runuser`, `chroot`, `xargs`, `eval`, `exec`, `source`, `.` or one of the SQL clients the guard already matches on the whole command (`bash <<EOF`, `cat <<EOF | sh`, `. /dev/stdin <<EOF`, `psql <<SQL` keep their bodies, which run). A body is also kept where its reader can sit off that line: an opener line continued with `\` or ending in `|`, `(`, `{` or `do`; a heredoc inside an unquoted `$( )`, `( )` or `<( )` (not an assignment's `x=$(…)`, nor a quoted `"$(…)"`, whose output is one word), or on an fd number (`exec 3<<EOF`); a `$`-named or quoted command (`"$SHELL" <<EOF`); a line led by `done`, `fi`, `esac`, `}` or `)` (`done <<EOF` feeding a loop that `eval`s). Once a body is dropped, the whole command is read when a later line pipes into a shell, `ssh` or SQL client with any words before it (`{ cat <<EOF … EOF; } | sh`, `… } | sudo -u deploy bash`, `… } | timeout 60 bash`, `… } | mysql`) or into a `$`-named command (`… } | $SHELL`), or when a body captured in `x=$( )` or `x="$( )"` is followed by `eval`, a shell's `-c` or a `$`-named command (`eval "$x"`, `bash -c "$x"`, `$x`). A pipe led by `grep`, `egrep`, `fgrep` or `rg` is a filter whatever its pattern names, and a `"$( )"` that is not assigned (a commit message's `-m "$(cat <<'EOF' … )"`) is not run later: on this version's first cut `… | grep -c bash` (or `-i ssh`, `-v su`, `exec`) after a `python3 -` body read the body as commands, so a 19 KB one took 62 s through the hook, past the 15 s timeout, and the `git reset --hard` after it ran unjudged; and `git commit -m "$(cat <<'EOF' … )" && bash -c 'npm test'` was denied on the message text. A `<<` the guard cannot place keeps every line after it: inside quotes (`git commit -m "handle <<END"`), after a `#`, in arithmetic or inside `${ }` or `$[ ]` (`echo ${v%<<EOF }` opens no heredoc), with a delimiter other than letters, digits, `_`, `.` or `-`, on a line a quote or `${` stays open across, after a backtick or an unmatched `)`, or with a terminator line that differs by blanks. A `#` glued to a closing `)` is part of a word, not a comment (`cat <(true)#'` opens a quote). A second heredoc on one line and a heredoc inside a kept body are tracked to their own terminators. A body with no terminator is kept, as bash reads it to the end. A 20 KB command with 7 heredocs now takes ~0.35 s, where the old code took 66 s on the same machine; a plain `git status && ls -la` stays at 26–27 ms median (20 runs), as a command with no `<<` skips the scan.
- Residual, now stated in the hook header and `rules.md`: a destructive command inside a body fed to anything else (`python3 -`, `node -`, `at`, a shell function, alias or `coproc`), written to a script a later line runs (`cat > x.sh <<EOF … EOF; bash x.sh`), or read into a variable by `read` and run later, is not read; all three were read before. A `case` pattern's `)` inside `$( )` closes it early for the scan, so a body there is judged as if outside. A huge body fed to a shell, `ssh` or a SQL client, or kept because its `<<` could not be placed or a later line may run it, is still read line by line and can still time out. The `destructive-commands` skill no longer tells the model an interpreter's heredoc is read through.
- `destructive-guard.test.sh` gains a `heredoc bodies` section (67 checks, 427 in all): the 20 KB / 7-heredoc command judged under 2 s through the hook entry point, silent, and asking once `git reset --hard` follows the bodies; a body fed to `bash`, `sh`, `ssh` and `psql` still judged; a `cat` body is data; `<<-`, a missing terminator, an arithmetic `<<` and a `<<<` here-string hide nothing after them; 24 shapes where the body may run or the `<<` may open nothing — each case above, `exec <<EOF` and `exec 3<<EOF` read by a later `bash`, `source <( )`, two heredocs on one line, `<<IN` inside a kept `<<OUT` body, `x=$((a << b))` — judged as 0.8.4 judged them; a commit message in `"$(cat <<'EOF' … )"`, an assignment's `$(cat <<'EOF' … )`, a body holding `| sh` and one whose opener line ends in a `# it's …` comment stay data. Twenty more pin 0.8.4's verdict where a body may run after all (all but the `eval` pipe fail on the block as first extracted): the seven later-pipe shapes above and `} | eval "$(cat)"` through the hook entry point, `${v%<<EOF }` (deny, and ask with `git reset --hard`), `$[x<<EOF ]`, `cat <(true)#'`, `eval "$x"`, `bash -c "$x"` and `$x` after `x=$(cat <<'EOF' … )`, `eval "$x"` after `x="$(…)"`, and `rbash`, `mksh`, `sudo -i` and `runuser -l deploy` reading a body; three keep a body data when a later `sh -c`, an escaped `\|` or `git push` does not take it. Against 0.8.4 the two timing checks (64–66 s each) and nine body-is-data checks fail. Ten more (446): `| grep -c bash`, `| grep -i ssh`, `| grep -v su`, `| grep exec` and `| rg -l sh` after a `python3 -` body stay silent, and `grep -v "^#" s.sh | bash` after a `cat > s.sh` body is still denied; a 19 KB body before `| grep -c bash` is judged under 2 s through the hook and the `git reset --hard` after it asks; a commit message's `"$(cat <<'EOF' … )"` before `&& bash -c 'npm test'` is data, and `export X="$(cat <<'EOF' … )"` then `bash -c "$X"` is still denied. Seven of them fail on this version's first cut.
- **The heredoc scan is now a shared block, `templates/blocks/heredoc-bodies.md` (`cc_strip_heredoc_bodies`), so the four other hooks that drop bodies before reading a command run this same scan.** destructive-guard calls it in mode `inert` with `SQL_CLIENT_RE` as the extra readers. Its output equaled the in-hook scanner's on 2,611 distinct `<<` Bash commands from local transcripts; the 20 KB / 7-heredoc command takes 350–359 ms (in-hook scanner, same machine and run: 348–351 ms), and `git status && ls -la` 25.9–26.2 ms median over 20 runs (26.3–26.6 ms). Against the block as first extracted, the later-pipe, `x=$( )`, `${ }`/`$[ ]` and shell-name rules change its output on 31 of 2,705 distinct `<<` transcript commands (18 now read whole, at most 3.6 s; 13 drop a body it kept for a `bash` inside `<( )` or an escaped `\|`) and the guard's verdict on none; the 20 KB command 335–365 ms, `git status && ls -la` 24.4–24.8 ms median. Standing: gate — `pc_shared_blocks` fails the build on a copy that is not byte-identical; `destructive-guard.test.sh` (427) and its pins (157) pass.

- **`rm -rf .playwright-mcp` no longer asks.** The Playwright MCP writes its snapshots and screenshots to `.playwright-mcp/` in the directory it runs from, untracked, so every cleanup drew the recursive-delete ask; one session approved the same delete four times. `.playwright-mcp` and `./.playwright-mcp`, with or without a trailing `/`, are now scratch like `node_modules`, when the command does not `cd` first and the dir under the Bash call's own `cwd` (the payload's; `--check` uses its own) is not a symlink, because `rm -rf link/` empties the link's target. Still asks: `.playwright-mcp/../src`, `.playwright-mcp/*`, another target beside it (`rm -rf .playwright-mcp src` judges `src` on its own), `cd sub && rm -rf .playwright-mcp`, and the same `cd` in a subshell, `(cd sub && rm -rf .playwright-mcp/)`, or through `env -C sub` / `--chdir`; the symlink test reads the name as typed, so a symlinked `.PLAYWRIGHT-MCP/` asks. Residual: the match is on the lowercased command, so a real `.PLAYWRIGHT-MCP` dir passes too; a spaced long `env` option before `-C` hides the move (`env --unset X -C sub rm -rf .playwright-mcp` passes). `destructive-guard.test.sh` gains 12 checks: `rm -rf .playwright-mcp` and `rm -rf ./.playwright-mcp/` silent, and silent through the hook when the payload `cwd`'s dir is real, fail against the first cut of this version; the ask for each shape above, a symlinked dir through `--check`, and a payload `cwd` whose dir is a symlink pass on both, except the subshell `cd`, `env -C` and the uppercase symlink, which passed on that first cut.

- **A recursive delete of a capitalised path is checked under its own name.** Every `rm -rf` target was lowercased before the guard asked the filesystem and git whether deleting it loses anything, so on a case-sensitive disk `rm -rf Docs` looked up `docs`, found nothing, and passed as a delete of nothing, with untracked files under `Docs/`; 0.8.4 did the same. The existence, symlink and git checks now use the target as typed; the rules still match the lowercased command. Standing: gate — `destructive-guard.test.sh` "rm -rf Docs" with an untracked file under it asks, and allows on 0.8.4; the harness now runs 450 checks.

## 0.8.4 — 2026-10-05

- **destructive-guard judges a command run through `env`, behind any documented git global option, and a `git clean` whose `-n` belongs to `-e`.** `env rm -rf /`, `env -i terraform destroy`, `git -P push --force`, `git --no-replace-objects push --force` and `git clean -fdx -e -n` used to pass; each now gets its bare form's verdict. `env` is skipped as a wrapper with its `-i`, `-u NAME`, `-C DIR`, `-P PATH`, `-a NAME`/`--argv0`, `--` and `VAR=` arguments (a bare `env` or `env | …` stays a read); a spaced `-S`/`--split-string` string is read as the command it splits into, so `env -S 'rm -rf /'` is denied where it passed. The git option strip covers every documented option that still runs the subcommand, plus `--shallow-file`; past the short list (`-C`, `-c`, `--git-dir` …) it applies only where git leads the segment, so `gh pr create --title "fix git -P push --force docs"` stays a read. `-e`/`--exclude`'s pattern (an `--exc…` abbreviation too) is no longer read as `-n`, nor is a path after `--` (`git clean -f -- -n` asks), and a later `--no-dry-run` cancels the dry run (`git clean -fdx -n --no-dry-run` is denied); git's abbreviations count too, so `git clean -fdx -n --no-dry` is denied (without `-x` both ask) and `git clean -fdx --dry`, a dry run, is no longer denied. The dry-run scan now starts after `git clean`, so a wrapper's `-n` is not clean's: `sudo -n git clean -fd` asks and `sudo -n git clean -fdx` is denied, where both passed. A wrapper's option value is skipped too (`sudo -u -g -h -p -C -D -r -t -U -T` and `--user/--group/--host/--prompt/--chdir`, `doas -a -C -u`, `nice -n`/`--adjustment`, `ionice -c -n -p`, `time -f -o`, `exec -a`), so `sudo -u bob grep "rm -rf /" f` is a read and is no longer denied; when the skip leaves no command word (`sudo -u rm -rf /`) the old reading stands. The `-x` deny now reads only a short-flag cluster holding `x` as a flag: `git clean --exclude=foo -f` and `git clean -fdex` (an `-e` pattern) ask instead of being denied, and `git clean -f -x` and `git clean --force -x` are denied instead of asking. Because the guard reads through quoted text, that wider `-x` match also denies prose that spells it, `gh pr create --body "run git clean -f -x to reset"`, which asked before; and `env -i bash -c 'echo "rm -rf /"'` is now denied like `bash -c 'echo "rm -rf /"'`, the `bash -c` read-through the deny message names. Three of the limits named below are therefore gone (`env`, `git clean … -e -n`, an unlisted git global option). Still refused, as before and as the hook header and rules.md now say: a wrapper named by path other than `env` (`/usr/bin/sudo -u bob grep "rm -rf /" f`) and a reader behind an unlisted wrapper option (`sudo -R /x grep "rm -rf /" f`). Still missed: a `-C`/`-c` value holding a space, `env -S'…'` with the string glued on, an unlisted wrapper option whose value names a reader (`sudo -R cat rm -rf /`), and `bash -c "git -P push"`.
- **destructive-guard reads `--e` and `--ex` as `--exclude`, reports its own version, and finds devops's plan reader on an installed copy.** Git takes `--e` and `--ex` for `--exclude`, so in `git clean -fdx --ex -n` the `-n` is the pattern and ignored files are removed; the guard read it as a dry run and passed it, and now denies it like `git clean -fdx`. `git clean -n --e --no-dry-run`, a dry run whose pattern is `--no-dry-run`, stays allowed, and so do `git clean -fdx --e -- -n` and `git clean -fdx --ex -e -n`, dry runs to git (the `--` or `-e` is the pattern). Without `-x`, `git clean -fd --e -n` and `git clean --ex -n` are no longer read as dry runs and ask where they passed, as `git clean -e -n` now does. `--version` printed 0.7.0 and now prints the plugin's version. The `terraform apply -auto-approve` ask names devops's `plan-audit.sh` only when it finds it; it looked only beside command-guard (`<dir>/devops/`), which an installed copy never is (`cache/<marketplace>/command-guard/<version>/`), so the hint never showed. It now also looks in `cache/<marketplace>/devops/<version>/` and names the highest version, skipping a version dir the host has marked `.orphaned_at` and ranking a release over its pre-release (`1.0.0` over `1.0.0-rc1`). `destructive-guard-pins.test.sh` gains 11 pins (157): the two denies and three dry runs, `--version` against `plugin.json`, and the hint on a fake versioned tree (absent without devops, present with it, naming 0.10.0 over 0.9.0, over 0.10.0-rc1 and over an orphaned 0.11.0, the rest of the ask unchanged).
- **Hook comments cut to contract and limits; behaviour unchanged.** The shared blocks in `hooks/destructive-guard.sh` and `hooks/config-guard.sh` keep each function's contract and limits in a few lines; the derivations and history moved to the marketplace repository's `rationale/`. After this cut both hooks parsed to the same code as before (bash's own parser, comments ignored); the next entry then refactored both.
- **The rest of the hook and test comments are cut to a contract line per file, plus off-switch and `Misses:` lines where it reads one or had a residual; behaviour unchanged.** The derivations and history moved to the marketplace repository's `rationale/derivations/plugin-command-guard.md`, which an install does not contain. `destructive-guard.sh`'s banner-separated blocks are now named functions (`check_cli`, `guard_command`, `guard_file_write`, `match_rule_table`, `strip_git_global_options`), with `rules()` still the one rule table, and `config-guard.sh` caps Bash targets with `MAX_BASH_TARGETS=8`. Those two hooks therefore differ in code, so instead of a parse comparison: new pin tests (20 in `destructive-guard-pins.test.sh`, 2 in `config-guard-pins.test.sh`) passed on the old and the new code, and a run of the old against the new hook found 0 divergences in 812 input pairs for `destructive-guard.sh` and 84 for `config-guard.sh` (output, exit status and every file left behind compared). Both existing tests parse to the same code as before. Limits now written down, behaviour unchanged: the destructive guard's header and README name a command run through `env`, `git clean … -e -n` (read as a dry run), and an unlisted git global option or a `-C`/`-c` value holding a space before a git subcommand (all but the last are fixed in the first bullet above); an allow-file line is matched unanchored on the whole lowercased command, so anchor it (`^…$`) and write it in lowercase; a plain `rm` of a config passes both hooks; config-guard does not judge an MCP `apply_patch` (the README said it asked). Not tested: bash 5, and hooks firing in parallel.

## 0.8.3 — 2026-10-01

- **A write to the allow-file through a differently-cased path is denied.** The Write/Edit check matched the file's name case-sensitively, while a case-insensitive filesystem (the macOS default) opens the same file under any ASCII letter case. The path, and an `apply_patch` body, are now lowercased before the match, as the Bash-command check already did. On a case-sensitive filesystem this over-denies a differently-cased sibling file. If `tr` is missing the check falls back to the exact-case match it had before.
- Not caught on the write path, stated in the hook header: an MCP write tool other than `*apply_patch` and `*create_new_file`, `NotebookEdit`'s `notebook_path`, and a non-ASCII spelling the filesystem folds to the name.
- **config-guard reads a write after a lone `&`.** The shared `cc_bash_write_targets` block now ends a command at a lone `&`: `echo x & sed -i s/a/b/ tsconfig.json` used to return no target, so no ask; it asks now. `sed -i s/a/b/ notes.txt & cat tsconfig.json` used to read `tsconfig.json` as a `sed` operand and ask; it no longer does. `cmd |& tee <config>` is read, and a `-`-led file after `sed … --` or `perl -i` is returned. Still not read: a `>& file` redirect, a bare `-x` operand with no `/` or `.` in it, and operands after a `&` inside `$(( ))` or `${ }`.
- The description no longer says the agent "cannot edit" the allow-file; it says the file is guarded from agent writes. The README made the same change in 0.8.2.
- The allow-file harness pins two more shapes as denied: `git grep -- --output=x <file>` (a known over-denial a later change may relax) and `git grep -e -- -O<cmd> <file>` (not an over-denial: there `--` is `-e`'s argument and `-O` runs a program).

## 0.8.2 — 2026-10-01

- **Reading the allow-file is no longer blocked.** destructive-guard denied any Bash command whose text named `.claude/destructive-guard-allow` unless it was a bare reader with no redirect, so `grep x .claude/destructive-guard-allow 2>/dev/null` and `git log -- .claude/destructive-guard-allow` were refused. A command naming the file now passes when every part of it, piped or chained, is a pure read: `cat`, `head`, `tail`, `wc`, `grep`/`egrep`/`fgrep`, `stat`, `ls`, `file`, `diff`, `cmp`, or `git log`/`show`/`diff`/`blame`/`grep`/`ls-files`/`cat-file` with the subcommand first and no `--output`, `-o`/`-O`, pager, `--ext-diff`, `--textconv`, `--filters` or `-c` option, redirecting only to an unquoted `/dev/null` or a descriptor.
- Everything else naming the file is denied: `awk`, `sed -n` and `find` as before, and any backtick, `$`, `~`, `{}`, unquoted `#` or parenthesis, a leading env assignment, a reader typed with a quote or a path, and a chained step that is not itself a pure read. Two rules are stricter than before. The reader list is closed: `less`, `more`, `jq`, `yq`, `rg`, `ag`, `ack`, `sort`, `uniq`, `tree`, `column`, `comm`, `echo` and `printf` naming the file used to pass and are now denied, because each can write or run a program or is not a reader at all — use `cat` or `grep`. And every chained step is judged: `cat .claude/destructive-guard-allow || echo none` and `cd x && grep y .claude/destructive-guard-allow` used to pass and are now denied.
- Not caught, as before: a path built from a variable or a glob, a script that writes the file, and any program git config names (a diff driver, textconv, clean filter, pager, `core.fsmonitor`, `gpg.program`), set before the command runs. The README no longer says the agent "cannot" write the file.
- **config-guard: the `sed -i` gap listed under 0.7.3 is closed.** The shared `cc_bash_write_targets` block now returns every file a `sed -i` / `perl -i` command edits instead of its last word, never a trailing redirect, and recognises GNU `--in-place[=SUF]` and BSD `-I`. So `sed -i 's/a/b/' tsconfig.json 2>/dev/null`, `sed --in-place … .eslintrc.json` and a config that is not the last operand now ask. Still not read: a globbed operand, a `\` line continuation, sed or perl reached through another word (`gsed`, `/usr/bin/sed`, `xargs`, `find -exec`), and a dot-named file right after a bare `-i` when another file follows (read as BSD's backup suffix). A lone `&` does not split a command, so a config named after one can draw an ask it should not.

## 0.8.1 — 2026-10-01

Security fix: two bypasses in destructive-guard's command splitter, each letting a deny-tier command run unjudged behind a segment led by a reader (`ls`, `cat`, `grep` …). Both are closed in `split_segments` and in `check_cd_chain`'s copy of the same walk.

- **Closed: a backslash inside single quotes (every platform).** The walk treated `\` as an escape inside `'…'`, where the shell reads it literally. `grep 'x\' f; <command>` came back as one `grep` segment, so the command after the `;` was never judged. A backslash in `'…'` is now literal.
- **Closed: a blank line (macOS only).** The awk program set `RS = "\0"`, which the awk macOS ships (BWK, `20200816`) reads as paragraph mode. A blank line started a new record without clearing the segment in progress: `ls a`, a blank line, then `<command>` produced the segment `ls a<command>`. A double quote opened before the blank line and closed after it desynchronised the same way. The walk now runs once over the whole input with the default `RS`. mawk and gawk were not affected.
- `$'…'` keeps `\'` as an escape, as the shell does; making every single-quoted backslash literal would have hidden the command after `grep $'x\'' f;`. After two or more `$` bash opens a plain quote and zsh an ANSI one, so from that quote on the walk splits on every separator, quoted or not. That can deny a command that only quotes a destructive string after `$$'`; it cannot hide one.
- Not changed: a newline inside quotes still ends a segment.
- CI runs Ubuntu only, so it cannot see a regression of the blank-line fix. The harness rows that cover it fail only under BWK awk; run `scripts/__tests__/destructive-guard.test.sh` on macOS after touching either walk.

## 0.8.0 — 2026-09-30

- **Off-switches are now `/config` options:** `cc_config_guard`, `claude_destructive_guard`, under `/config` (or `/plugin configure command-guard`), each with today's default. The environment variable (`CC_CONFIG_GUARD`, `CLAUDE_DESTRUCTIVE_GUARD`) still overrides its option. An interactive `/plugin install` now shows a Configure dialog for these options; it is optional — Esc keeps the defaults.
- `claude_destructive_guard` keeps the variable's values (`deny`, `deny-only`, `off`).

## 0.7.3 — 2026-09-29

- **config-guard sees Bash writes.** Its matcher was the write tools only, so `cat > tsconfig.json <<EOF`, `tee`, `>>` or `sed -i` onto an existing settings, hooks, manifest or lint/test config never reached it. `hooks.json` now matches `Bash` too. The hook reads up to 8 write targets through the shared `cc_bash_write_targets` block (redirect, `tee`, `sed -i`, `perl -i`), resolves a relative one against the payload `cwd` (a `~/` one against `$HOME`), and asks on the first that is a guarded file and already exists, with the same reason text as a Write. destructive-guard still runs on Bash beside it; each emits its own verdict.
- Not caught on Bash: interpreter writes (python `open()`, php `file_put_contents`), `cp`/`mv`/`install` destinations, `{ …; } > f` groups, a path held in a variable, a `sed -i` whose config is not its last word (another file after it, or a trailing redirect such as `2>/dev/null`), a `\` continuation, a relative target after an in-command `cd`, the 9th target on, and `rm` of a config or hook (a deletion, still destructive-guard's).
- non-write Bash: 20.4 ms median, 21.3 ms max (20 runs)

## 0.7.2 — 2026-09-26

- The four meta-bundles (core-, frontend-, craft-, workflow-suite) were retired on 2026-09-26; install through `all-plugins` or `/stack-scan:suggest`. `config-guard.sh`'s comment and its test fixture no longer name a retired bundle; no behaviour changed.

## 0.7.1 — 2026-09-25

### Changed
- `hooks/hooks.json` quotes `${CLAUDE_PLUGIN_ROOT}` in every hook command. Claude Code 2.1.282's `plugin validate --strict` rejects the unquoted form (an install path with a space splits into several words); the marketplace's CI pin moved to 2.1.282 with it.

## 0.7.0 — 2026-09-24

### Added
- **A live `.env` is protected from being overwritten, not only from being deleted.** The rule
  table denied `rm .env` and `> .env` and allowed everything else, so on 2026-09-24 an agent
  ran `cd /tmp/dq-bg && …; cp .env.example .env && php artisan key:generate` with no
  prompt. The worktree it meant to `cd` into had never been created, and both writes landed
  in the real project. The credentials were gone, and so was the `APP_KEY` that the stored
  OAuth tokens and sessions were encrypted with. The guard now denies `cp`/`mv`/`install`/`ln`/`rsync`/`tee`
  onto an existing `.env`/`.env.*` that git has no clean copy of, a truncating `>` onto
  `.env.*`, and `artisan key:generate` when the file already holds an `APP_KEY`. It also
  denies any relative `.env` write after a `cd`, because the guard cannot tell which
  `.env` that is. The decision is based on the file's state, not the command's spelling: `cp .env.example .env` in a clone with
  no `.env` still passes, as do `key:generate --show`, appends, copies aside, and absolute
  paths inside the OS temp directory.
- **A `cd` that must fail is denied before the chain runs.** If the target is an absolute path that does not exist, no earlier segment names
  it, and its `&&` chain ends in `;`, the Bash tool's persisted working directory
  means every step after the `;` runs in the live tree. The deny reason is its own. It
  tells the model to check `test -d` in a separate call and then re-issue the command with `&&`, and to
  treat an earlier call that was meant to create the directory as having run nothing.
  Relative targets are not judged.
- **A `Write` that replaces an existing, untracked `.env` asks.** An `Edit`, a `Write` that
  creates the file, and `deny-only` stay silent.
- 34 harness assertions, including the incident command verbatim and the fresh-clone controls.

## 0.6.8 — 2026-09-23

### Changed
- **Prompt audit (Claude Code's built-in `claude-api` skill, `prompt-audit` subcommand; target Opus 5.5 / Fable 5.1):** `/command-guard:check` states the no-self-exemption rule in the present tense instead of the 0.2.0/0.2.1 attempt history. Method: that built-in skill's `shared/prompt-audit.md`; the full report and diff are in the maintainers' working area, not shipped.

## 0.6.7

### Changed
- **The `terraform apply -auto-approve` ask now names a way to answer it.** When the
  **devops** plugin is installed beside this one, the ask reason carries the resolved path
  to its plan reader — `terraform show -json plan.out | bash <devops>/scripts/plan-audit.sh`,
  exit 2 when the plan deletes or replaces a resource that holds data — so the prompt is
  a read rather than a coin flip. The path is resolved from this hook's own
  `CLAUDE_PLUGIN_ROOT` and named only when the file is actually on disk; with devops
  absent the reason is unchanged. The verdict stays **ask** (panel finding 43).
- **`tofu apply -auto-approve` asks too.** The rule matched `terraform` only, so the
  OpenTofu spelling of the same command was allowed silently.

## 0.6.6

### Changed
- **Both refusals name `CLAUDE_DESTRUCTIVE_GUARD`.** The deny reason named the
  `.claude/<allowfile>` opt-out and not the environment switch; the ask reason named
  neither. Each now states the value that silences it (`off`, and `deny-only` for the ask
  tier), and the deny adds the fact that makes the difference in practice: the variable is
  read from the hook's own process, so prefixing it to the command does nothing. The
  person who needs that fact is the one reading the refusal (panel finding UX 1).

## 0.6.5

### Fixed
- **`destructive-guard.test.sh`'s "guard touched nothing" assert failed on other
  people's edits.** It snapshotted `git status --porcelain` over the whole working tree
  before and after the run, so any concurrent change anywhere in the repo — a parallel
  worker, a generator run, an unsaved-then-saved file — reported the guard as having
  mutated the tree. The snapshot is scoped to `-- plugins/command-guard` now; the assert
  keeps its intent and states its residual (a write outside this plugin's directory is no
  longer seen, and the guard's only filesystem reach is reading `.claude/<allowfile>`).
  221 asserts, 0 failed.

## 0.6.4

### Fixed
- **`config-guard` was undocumented in the README.** The plugin has shipped a second
  `PreToolUse` hook since 0.6.1 — an `ask` on a write to settings, any `hooks.json`, a
  hook script, a plugin manifest or a lint/type-check/test config — and the README named
  it only in the environment-variable table. An installer met the prompt before they met
  the feature. It now has its own section (what it matches, why `ask` and not `deny`, the
  self-exemption, and the three things it does not catch) and a row in "What has teeth".
- **`config-guard.sh`'s header listed one file set and its code matched another.**
  `pyproject.toml` has been in the `case` since 0.6.1 and absent from the header comment
  that enumerates the covered files; `phpstan.neon.dist`, `psalm.xml.dist` and
  `.golangci.yaml` were missing the same way. The header is the list now.
- **`rm -rf ./some-dir` was given as an `ask` example in two places that the
  recoverability check contradicts.** Since 0.4.0 a relative path git can restore is
  `allow`, and the README's own tier table and the hook header both used the bare form
  as the canonical ask. Measured: `rm -rf ./tracked` → allow, `rm -rf ./untracked` →
  ask, `rm -rf ./absent` → allow. Both now say "when git cannot restore it".
- **`references/rules.md`'s "Tuning it" section listed two of the four switches.**
  `deny-only` was argued in the limits paragraph above it and absent from the list, and
  `config-guard` and `CC_CONFIG_GUARD` appeared nowhere in the file the command sends a
  reader to for "the guard's stated limits". Both are named now.

## 0.6.3

### Fixed
- **`config-guard` now honours `CLAUDE_DESTRUCTIVE_GUARD=deny-only`.** core-suite's README tells installers that variable buys the click-free half of this plugin, but config-guard read only its own `CC_CONFIG_GUARD` — so the documented setting left an ask tier running on every config write. Both values that mean "no ask tier" (`off`, `deny-only`) now silence it.

## 0.6.2

### Fixed
- **The allow-file guard now covers MCP file writes.** 0.6.1 widened the matcher to
  `*apply_patch|*create_new_file` but left the script gating on the four host tool
  names, so the matcher fired and the script exited — silent coverage, and the file
  that disarms this guard stayed editable through any MCP server while the host tools
  were blocked. `create_new_file` is read from `pathInProject`; `apply_patch` carries
  no single path, so its patch body is checked for the basename. Four assertions.

## 0.6.1

Two releases shipped under this one version number — `config-guard` landed after the
MCP allow-file fix without a bump, so the entries are merged here rather than split
across two `0.6.1` headings that a consumer could not order or tell apart.

### Added
- **`config-guard`: an `ask` before the agent edits its own guardrails.** Settings
  files, any `hooks.json`, any hook script, plugin manifests, and lint/type-check/test
  configs (eslint, biome, rubocop, ruff, phpstan, psalm, golangci, pytest, tsconfig,
  clippy). Given a gate it cannot satisfy, the cheapest path out is to edit the gate —
  turn off the rule, add an ignore, delete the hook — and it reads in a diff summary as
  "updated config". `ask`, not `deny`, because editing these is often exactly the task;
  the point is that it becomes a decision someone made. It reads the PATH, not the
  diff: it cannot tell adding a rule from deleting one, and says so in the prompt. It
  self-exempts inside a marketplace repository, which edits these files as its product.
  `CC_CONFIG_GUARD=off` disables it; `scripts/__tests__/config-guard.test.sh` drives
  21 cases.

### Fixed
- **The allow-file cannot be edited through an MCP file tool.** The second matcher
  protecting `.claude/destructive-guard-allow` covered the four host write tools only;
  an IDE-MCP write bypassed the protection on the file that disarms this guard.
- **"187 assertions" in the README is 217** — the harness has printed the larger number
  since 0.6.0 added thirty.

## 0.6.0

### Fixed
- **`git push -f` was allowed.** The deny rule ` git push .*(--force( |$)| -f( |$))`
  could not match `-f` as the first word after `push`: the pattern's own literal
  space consumed the only space, so `git push -f origin main` — the commonest
  spelling of a force push — fell through to allow while `git push origin main -f`
  denied. The rule is now ` git push( [^ ]+)* (--force|-[a-eg-z]*f[a-z]*)( |$)`, which
  also catches clustered short flags (`-uf`, `-fu`). `--force-with-lease` stays on
  the ask tier. Found by classifying a corpus of common commands through `--check`.
- **git global options bypassed every git rule.** Each rule is written
  ` git <subcommand> …`, so `git -C /path push --force`, `git -c core.pager=cat
  reset --hard` and `git --git-dir=… clean -fd` matched nothing. `-C`, `-c`,
  `--git-dir`, `--work-tree`, `--namespace`, `--no-pager`, `--no-optional-locks`,
  `--literal-pathspecs` and `--bare` are now stripped from the normalised segment
  before matching. `-C` is the form an agent reaches for whenever it works outside
  its cwd, so this was the live gap, not a theoretical one.

### Changed
- **`git clean -n` / `--dry-run` no longer asks.** A dry run deletes nothing; it is
  the preview the ask tier's own alternative text recommends, so prompting on it
  trained a click-through on the one command that makes the real one safe.
  `-fdxn` and `-fdx --dry-run` are dry runs too and skip the `-x` deny.
- `git checkout .` now asks, as `git checkout -- .` already did — same act, different
  spelling. `git checkout -f` / `--force` (throws away local changes to switch) and
  `git restore --source=<rev> .` / `--worktree .` join the ask tier; `git restore
  --staged .` (index only) stays allowed.
- `crontab -r` asks: it removes every cron job for the user with no confirmation and
  no backup, one key away from `crontab -e`.
- The `DELETE FROM` ask reason no longer claims "no WHERE on this line": the rule
  asks on every shell-run DELETE and always did. The message now says so.
- `GUARD_VERSION` 0.6.0. 30 new classification assertions in the harness cover each
  of the above in both directions.

## 0.5.3

- `lane.tsv` comment names `approaches:consult-remind` as the prompt-time nudge on
  irreversible tokens — fresh-take merged into approaches on 2026-09-14. No
  behaviour change.

## 0.5.2

### Added
- `lane.tsv`: the hook, `/command-guard:check` and the `destructive-commands` skill
  now declare their territory, phase and trigger in the marketplace's lane graph
  (`scripts/lib/plugin-checks.sh`, `pc_lanes_*`). All three are `any`-phase guards —
  a command can be about to run in every phase. Declaration only; no behaviour change.

## 0.5.1

### Changed
- Citations of the four-laws / has-teeth doctrine now point at
  `.claude/skills/authoring-skills/SKILL.md` in the marketplace repository — the
  authoring plugin was demoted to a tracked project skill on 2026-09-03. Prose only;
  no behaviour change.

## 0.5.0

### Changed
- **`rm -rf` on a path inside the OS temp directory no longer asks.** Reported
  case: `rm -rf /tmp/pintcheck && echo cleaned` drew a permission prompt. Every
  absolute path was classified "outside the project" and sent to the ask tier,
  so the guard interrupted on the one directory the operating system itself
  clears on boot and every `mktemp -d` on the machine writes into. Recognised
  roots: `/tmp`, `/private/tmp`, `/var/tmp` (and their `/private` prefixes),
  macOS's `/var/folders/<ab>/<hash>/<T|C>/`, and `$TMPDIR`/`$TMP` resolved from
  the hook's own environment.

  Three boundaries are deliberate, and each is a paired assertion in the harness
  so that loosening one shows up as a failing test rather than as a wider
  exemption:
  - **The roots stay denied.** `rm -rf /tmp`, `/tmp/`, `/tmp/*`, `/private/tmp`
    and `/var/tmp` are hard stops — emptying the shared temp directory destroys
    other processes' state, not just this session's. `/private/tmp` and
    `/var/tmp` are new denies; they are multi-component spellings of the same
    directories that the single-component system-directory rule never reached.
  - **`..` disqualifies the path.** `/tmp/../etc` asks, because a prefix stops
    proving containment once the path can walk back out of it.
  - **An unresolvable variable asks.** `$TMPDIR/build` is silent when `TMPDIR`
    is set in the hook's environment and asks when it is not, since unset makes
    that command `rm -rf /build`. The braced `${TMPDIR}/build` always asks: the
    segment splitter cuts on `{`/`}` before the token forms, and it is not worth
    weakening a splitter that exists for `{ cmd; }` groups and the fork bomb.

  No other tier moved: the rule table, the recoverability check for relative
  paths, and the evasion and fail-open behaviour are untouched.

## 0.4.1

### Changed
- **Every hook entry now declares a `timeout`.** `destructive-guard.sh` 15s. Before this release the
  plugin expressed no opinion about how long its own hook may hold a turn and
  relied entirely on the host default; a hook that blocks — a slow network mount,
  a large transcript — stalled the user with no per-hook ceiling. Sizes are per
  script, not one house number: 5s for a jq-only classifier, 10s for git/find
  work, 15s where the script shells out to the network, a package manager or
  node. No hook logic changed.

## 0.4.0 — 2026-08-26

Cuts the interruptions the ask tier was causing and closes three holes found by
probing the guard against its own claims. (Written as 0.2.0 on a branch cut
before 0.2.1–0.3.1 landed; renumbered on merge, so the entries below are older
than this one despite the collision in the branch's own history.)

- **`CLAUDE_DESTRUCTIVE_GUARD=deny-only`** — keeps every hard stop, drops the
  ask tier. Measured motivation: across 2016 local transcripts the ask tier
  fired in 64 sessions and the deny tier in 69, but only the ask tier costs a
  prompt. A `PreToolUse` ask also *overrides* a host permission classifier, so
  on a host that has one the ask tier converts a silent judgement into a click.
  Not the default — outside such a host nothing replaces the ask tier.
- **`rm -rf <relative path>` no longer asks when git can restore the path.**
  Absent, or tracked with nothing untracked/modified/ignored under it → silent;
  anything else → ask, as before. Ignored content counts as a loss because git
  has no copy of it, which is the `.env`-under-the-directory case. The check is
  skipped entirely when the command contains `cd`/`pushd`, because the process's
  cwd is then not the one the `rm` resolves against. Runs only on the branch
  that was about to prompt, so ordinary Bash calls gain no `git` invocation.
- **Fixed: bare SQL through an MCP SQL tool was never gated.** Every SQL rule
  was conditioned on a client name (`psql`, `mysql`, …) appearing in the string, <!-- removed-ok -->
  which an `execute_sql_query` payload has no reason to contain — so
  `DROP DATABASE prod`, `TRUNCATE TABLE users` and `DELETE FROM users` all
  passed through the one tool family the plugin advertised as covered. SQL
  context is now declared by the hook from `tool_name`/field, not sniffed.
- **Fixed: the `> .env` deny rule could never fire.** A segment whose lead word
  reads (`echo`, `printf`, `cat`, `true`) was skipped before the rule table ran,
  so `rm .env` was denied but `echo x > .env` was allowed. A segment carrying a
  redirect now skips both the reader and the git-safe exemption — the redirect
  is the effect, whatever the lead word claims.
- **Fixed: `git push origin +main` was allowed.** The force-push rule matched
  only `--force`/`-f`, not the `+refspec` form that does the same thing.
- Harness reaches 173 assertions, including a throwaway git repo fixture for
  the recoverability rules (a mocked git would only test the mock).

## 0.3.1

### Fixed
- `commands/check.md` claimed "ask- and allow-tier targets run fine" after 0.3.0
  removed the self-exemption. Measured: false for **ask**. With no exemption the
  check invocation is itself classified, so checking an ask-tier target draws a
  confirmation prompt worded as though something will be destroyed — for a
  command that only classifies. Allow-tier is genuinely silent. The doc now
  carries a measured tier-by-tier table instead of a claim.

### Added
- **Hook-mode assertions in the `no self-exemption` harness section.** Every
  assertion added in 0.3.0 drove CLI mode (`--check`), which reaches `classify()`
  directly. A reviewer planted the 0.2.0 substring bug one layer up — a `case` on
  the raw command string in the HOOK path, before `classify()` is called — and
  the whole section passed 141/0 with the hole live. That is the same
  CLI-mode/hook-mode composition gap that let the original defect ship,
  reappearing in the tests written to close it. Four vectors now drive the real
  `PreToolUse` entry point; verified against the planted hole, which they fail.

### Changed
- Removed two byte-identical duplicate assertions. The section asserts 9 distinct
  vectors, not the 10 the 0.3.0 changelog claimed. Measured against the real
  historical guards, those 9 split three ways: **5** discriminate against a
  0.2.1-style positional exemption; **3** (the `-c` wrapper forms) fail only
  against a 0.2.0-style substring exemption; **1** (the `eval` form) catches
  NEITHER prior release, because both required a `bash`/`sh` lead word — it pins a
  hypothetical looser exemption only. Kept deliberately, and labelled rather than
  counted as coverage it does not provide.

## 0.3.0

### Security
- **Reverts the self-exemption entirely.** 0.2.0 added it and 0.2.1 rewrote it;
  both were bypassable, so the convenience it bought is withdrawn rather than
  patched a third time.
  - 0.2.0 matched `bash` / the guard path / `--check` as substrings ANYWHERE in a
    segment. `bash -c PAYLOAD name arg...` executes PAYLOAD and demotes the rest
    to `$0`/`$1`, so appending the magic words to a destructive `bash -c` call
    unlocked it.
  - 0.2.1 matched by argv POSITION, which closed that vector and left three
    others open: command substitution, backticks, and redirection to a raw disk.
    An exemption that `continue`s past classification skips the WHOLE segment,
    and a shell segment carries side effects the shell evaluates independently of
    argv — the payload runs before or beside the classifier that argv claims is
    all that happens.
  - The general rule this settles: an exemption keyed on what a command LOOKS
    like cannot be safe while the shell will evaluate parts of that same string on
    its own terms. A safe version would have to classify the segment anyway and
    suppress only the verdict arising from the `--check` argument, which means
    parsing shell grammar — something this guard deliberately does not do.

### Changed
- `commands/check.md` now states the limitation instead of the plugin trying to
  engineer around it: for a **deny-tier** target the CLI step is itself denied, so
  the command reports `deny` from `references/rules.md` rather than retrying.
  `ask` and `allow` targets are unaffected. Standing: **unfixed by design**.

### Added
- A `no self-exemption` harness section pinning all ten known bypass vectors plus
  two controls as DENY. Verified against both prior releases: 5 assertions fail
  against 0.2.1 and 10 against 0.2.0. If a third exemption is ever added, this
  section is what should stop it.

## 0.2.1

### Security
- **Fixes a bypass introduced by 0.2.0.** That release's self-exemption matched
  its three tokens anywhere in the command segment. But `bash -c PAYLOAD name arg...`
  executes PAYLOAD and turns everything after it into `$0`/`$1`/..., so appending
  the literal words `destructive-guard.sh --check y` to a `bash -c "<destructive>"`
  call satisfied all three substrings while the shell still ran the payload --
  re-opening the exact `bash -c` wrapper hole this guard's own deny text warns
  models not to attempt. Four vectors confirmed allowed, including a `bash -lc`
  filesystem wipe with the magic tail appended.
- The exemption now matches by POSITION: word 1 must be `bash`/`sh`, word 2 must
  be the guard's own path, word 3 must be `--check`. `-c` lands in word 2, where
  only that path is accepted. Seven bypass vectors plus a control are asserted in
  the harness and fail against 0.2.0.

## 0.2.0

### Fixed
- The guard denied its own `/command-guard:check` CLI. That command's stated
  primary use is unpacking why a command was blocked, so it was broken for
  exactly the deny-tier targets it exists to explain — and because the deny text
  says "Do NOT retry", the model abandoned the check rather than working around
  it. `bash <path>/hooks/destructive-guard.sh --check '<cmd>'` is now exempt, on
  three clauses: bash/sh lead word, a path ending in `hooks/destructive-guard.sh`,
  and `--check` present. `--check` classifies and exits without ever executing
  its argument; any other flag still falls through to normal classification.

### Added
- A `self-exemption` section in the harness. The previous 128 assertions drove
  CLI mode and hook mode separately and never sent the HOOK a Bash payload whose
  command IS the CLI invocation, so the composition was nobody's case. The new
  section also asserts the exemption does not leak: the bare targets are still
  denied, a non-`--check` flag on the same script is still denied, and a
  lookalike path does not inherit it. Verified against the old code: 3 of the new
  assertions fail on it.

### Known limitation
- The guard still cannot distinguish MENTIONING a destructive command from
  RUNNING one. A heredoc that writes a file quoting `terraform destroy` is denied
  like the real thing (a reader-led quoted write such as `printf ... >> notes.md`
  passes, so the blast radius is heredoc-shaped and multi-line writes). This is
  unfixed: narrowing it means reasoning about whether written text is later
  executed, which this classifier deliberately does not attempt. Documentation
  and audit records must redact the string or use a non-shell write path.

## 0.1.0 — 2026-08-02

First release.

- `PreToolUse` hook on `Bash` and on MCP tools that shell out or run SQL
  (`*execute_terminal_command`, `*execute_sql_query`, `*run_command`,
  `*shell_command`, `*run_in_terminal`), classifying the command string into
  `deny` / `ask` / `allow`.
- `deny` covers framework schema resets (Laravel, Rails, Django, Prisma,
  Sequelize, TypeORM, Knex, Alembic, Doctrine, Flyway, Liquibase, Supabase,
  WP-CLI), executed `DROP`/`TRUNCATE`/`FLUSHALL`/`dropDatabase()`, `rm -rf` on
  `/`, `~`, `$HOME`, `.` or a top-level system directory, `rm` of `.env`,
  history-destroying git commands, `docker compose down -v` and volume removal,
  `kubectl delete` of stateful objects, `terraform`/`pulumi destroy`, cloud CLI
  deletes, and raw-device writes.
- `ask` covers scoped destructive commands: `git reset --hard`, `git clean -fd`,
  `git branch -D`, `rm -rf <project path>`, `DELETE FROM`, `kubectl delete pod`,
  `helm uninstall`, `terraform apply -auto-approve`, `npm publish`,
  `curl … | sh`, `find … -delete`, `history -c`.
- Reads through quotes, `bash -c`/`eval` wrappers, whitespace, `&&` chains and
  heredocs; exempts read-only commands, and drops that exemption when output is
  piped into a shell.
- `.claude/destructive-guard-allow` — a user-owned exemption list the agent is
  blocked from writing, via `Write`/`Edit` and via shell redirects.
- `CLAUDE_DESTRUCTIVE_GUARD=ask|off` environment switches, unreachable from a
  command string.
- `/command-guard:check "<command>"` classifies without executing;
  `--check` exits 0/1/2 for allow/ask/deny.
- `destructive-commands` skill: substitution table, the handover protocol for
  when a reset is genuinely needed, and what the guard cannot see.
- 128-assertion harness at `scripts/__tests__/destructive-guard.test.sh`,
  including false-positive controls and fail-open cases; run in CI by the
  repo-wide plugin harness step.
