---
name: hook-bash-writes
description: Use when a hook in this marketplace must see files written through Bash — a Write/Edit guard gaining Bash coverage, a python heredoc or other interpreter write, a content scan of heredoc or echo text, or a harness proving it. Covers the three byte-locked write blocks, the caller loop, what they miss, and the latency and harness traps.
---

# Seeing Bash writes from a hook

A guard matched on `Write|Edit` is blind to `cat > f <<EOF`, `tee`, `sed -i` and `>>`.
Two shared blocks read what the command text names; a third reads what an interpreter
run changed on disk. This skill is how to use them without forking them. Standing of
each rule is in brackets.

## The three blocks

| block | function | prints |
|---|---|---|
| `templates/blocks/bash-write-targets.md` | `cc_bash_write_targets <command>` | one target path per line, spelled as in the command |
| `templates/blocks/bash-write-chunks.md` | `cc_bash_write_chunks <command>` | chunks: a `\036` + WRITER header line, then the text written |
| `templates/blocks/bash-write-effects.md` | `cc_bash_write_effects <root> <marker> <command> <max>`, `cc_bash_effects_mark <root> <marker>` | absolute paths git reports changed or untracked since `<marker>`, after an interpreter, `cp`, `mv`, `install` or `patch` run |

- Paste each block **verbatim** (`cat` it in, never retype) above the hook's main `{`.
  Plugins install alone, so nothing is sourced. [**gate** — `pc_shared_blocks` prints
  `shared-block-drift <path> <name>.md` for any hook defining the function without the
  exact block text]
- Need only paths (a path guard)? Paste targets alone. Need the written text (a content
  guard)? Paste targets THEN chunks — the caller resolves each chunk's file through
  `cc_bash_write_targets`. Why chunks carries its own `mask()`:
  `rationale/derivations/templates-and-blocks.md` § `templates/blocks/bash-write-chunks.md`.
- A PostToolUse hook that must see `python3 - <<'EOF' … open(p, 'w')` pastes effects as
  well (step 7). A PreToolUse guard cannot: the effect does not exist yet.
- Never edit a block in a hook. A fix goes into `templates/blocks/`, then every hook
  that carries it is re-pasted in the same change. Recount the copies:
  `grep -rl 'cc_bash_write_targets() {' plugins/`.

## Caller contract

1. Tool gate: add `Bash)` beside the write tools, and add `Bash` to the hook's
   `hooks.json` matcher. [**recorded** — a payload piped straight to the script
   cannot prove the matcher; read `hooks.json`]
2. `cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')`.
3. **Cheap exit first:** `[ -n "$(cc_bash_write_targets "$cmd")" ] || exit 0` before
   reading anything else. A non-write Bash call is the common case and must cost
   ≤ 50 ms median (measure 20 runs; record median and max in the CHANGELOG). An effects
   adopter reads cwd and the state root and marks BEFORE this exit (step 7): about 6 ms
   more on every call, measured on route.sh.
4. A path or disk guard (it reads the targets) caps them with a named constant
   (`MAX_BASH_TARGETS=8` … `| head -n "$MAX_BASH_TARGETS"`) and says so in the header.
   A content guard judges every chunk, one target per writer (`head -n 1`), bounded by
   the command text itself.
5. Resolve a relative target against the payload `.cwd`, never the hook's own cwd. When
   the command holds a `cd`/`pushd` OUTSIDE heredoc bodies, skip relative targets — a
   miss, never a wrong file. Drop bodies with `cc_strip_heredoc_bodies all` (paste
   `templates/blocks/heredoc-bodies.md`); a `cd` inside a body moves nothing.
   Reference: `plugins/secret-scanning/hooks/unicode-scan.sh`, the Bash branch.
6. Content guards read chunks with the canonical loop from
   `plugins/secret-scanning/hooks/scan.sh` (its `if [ "$tool" = Bash ]` branch):

```bash
sep=$(printf '\036'); n=0; keep=0
while IFS= read -r l; do
  case "$l" in
    "$sep"*) tgt=$(cc_bash_write_targets "${l#?}" | head -n 1)
             if [ -n "$tgt" ]; then n=$((n + 1)); ctgt[$n]=$tgt; ctext[$n]=""; keep=1; else keep=0; fi ;;
    *) [ "$keep" = 1 ] && ctext[$n]="${ctext[$n]}$l
" ;;
  esac
done <<EOF_C
$(cc_bash_write_chunks "$cmd")
EOF_C
```

   A header whose writer resolves no target (`psql <<SQL`, `git commit -F - <<EOF`) is
   skipped. Append vs overwrite is not reported: test the header text for `>>`,
   `tee -a` or `tee --append`.
7. Interpreter writes, PostToolUse only: one marker per hook,
   `$(cc_plugin_state "$root" <plugin>)/bash-effects.mark`. Read the effects with the OLD
   marker, then mark — on EVERY call the hook sees, an Edit and a command that wrote
   nothing too, or an Edit's file reads as the next run's write. Feed each printed path
   to the Write branch's per-file logic (it reads the file from disk), deduped against
   the targets, capped by a named constant (`MAX_BASH_EFFECTS=8`). Reference:
   `plugins/skill-router/hooks/route.sh`. A match costs one `git status`: 18 ms median on
   a 2,786-file repo, 50 ms on 100k files, 110–200 ms right after a clone until any git
   command refreshes the index. Measured numbers and the design:
   `rationale/derivations/templates-and-blocks.md` § `templates/blocks/bash-write-effects.md`.

## What the blocks do NOT see — name these in the hook header

[**recorded** — the header is prose; name each gap your guard inherits]

- interpreter writes: python `open()`, php `file_put_contents` — unless the hook carries effects;
- `cp` / `mv` / `install` destinations — effects sees `cp` and `install`; `mv`, `cp -p` keep the source's mtime;
- `{ …; } > f` groups (chunks only; `cc_bash_write_targets` reports the target), here-strings `<<<`, printf format substitution;
- a path held in a variable (`> "$out"`);
- a quoted string or `\` continuation spanning lines, a second heredoc on one line;
- a relative target after an in-command `cd` (skipped per step 5);
- targets past your cap.

Effects adds its own: a writer it does not name (`npx prettier --write`, `make`,
`git apply`), gitignored outputs, no git, a file written then reverted, the first call in
a repo (no marker yet), files past its cap. It also reads too much: anything changed since
the hook's previous call (an IDE save, a parallel agent) counts as this run's write.

Deletion is not a write guard's business, and no guard here stops a plain `rm` of a hook or
config: command-guard's `destructive-guard.sh` judges a recursive `rm` by its target, an `rm`
naming a `.env`, and a command naming its own allow-file.

## Harness traps

- Write harness edits with the Edit tool, not a Bash heredoc: the installed
  destructive-guard reads heredoc text, so a heredoc that plants a dangerous-looking
  fixture can be blocked before the harness exists.
- Prove four things, each with its own label: a heredoc write fires; a `sed -i` or
  `>>` write fires; a non-write command (`ls -la && git status`) is silent; a guarded
  name appearing only INSIDE a heredoc body is silent.
- Every pre-existing Write/Edit case must still pass unchanged — move shared logic
  (a path classifier) into a function both branches call, so the two paths cannot drift.
- Build payloads in a `mktemp` dir outside any git repo, or a repo-root self-exemption
  can silence the case you meant to test.
- Effects cases need a git repo per case, under a name no other case uses: a reused
  directory carries an earlier case's marker and fired state. Prove four things: an
  interpreter write fires what an Edit of the file would; a matching run that wrote
  nothing is silent; a file an Edit changed between two Bash calls is not read again;
  the first call in a repo is silent.

## Anti-patterns

- Forking the extractor into a hook-local `cc_<plugin>_bash_chunks` — the fork never
  gets the next fix. The block exists because one hook did exactly that.
- Asking on every Bash call, or on a target that does not exist yet. A guard that fires
  on everything is trained away within a day.
- Claiming "Bash writes covered" in a README or lane row without the gap list beside it.
- Marking only the calls that look like writes: the window then stretches back over every
  unmarked call, and whatever those wrote is read as the next run's write.
