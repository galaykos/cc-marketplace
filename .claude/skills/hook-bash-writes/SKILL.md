---
name: hook-bash-writes
description: Use when a hook in this marketplace must see files written through Bash — a Write/Edit guard gaining Bash coverage, a content scan of heredoc or echo text, or a harness proving it. Covers the two byte-locked shared blocks, the caller loop, what they miss, and the latency and harness traps.
---

# Seeing Bash writes from a hook

A guard matched on `Write|Edit` is blind to `cat > f <<EOF`, `tee`, `sed -i` and `>>`.
Two shared blocks close most of that gap. This skill is how to use them without
forking them. Standing of each rule is in brackets.

## The two blocks

| block | function | prints |
|---|---|---|
| `templates/blocks/bash-write-targets.md` | `cc_bash_write_targets <command>` | one target path per line, spelled as in the command |
| `templates/blocks/bash-write-chunks.md` | `cc_bash_write_chunks <command>` | chunks: a `\036` + WRITER header line, then the text written |

- Paste each block **verbatim** (`cat` it in, never retype) above the hook's main `{`.
  Plugins install alone, so nothing is sourced. [**gate** — `pc_shared_blocks` prints
  `shared-block-drift <path> <name>.md` for any hook defining the function without the
  exact block text]
- Need only paths (a path guard)? Paste targets alone. Need the written text (a content
  guard)? Paste targets THEN chunks — the caller resolves each chunk's file through
  `cc_bash_write_targets`. Why chunks carries its own `mask()`:
  `rationale/derivations/templates-and-blocks.md` § `templates/blocks/bash-write-chunks.md`.
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
   ≤ 50 ms median (measure 20 runs; record median and max in the CHANGELOG).
4. A path or disk guard (it reads the targets) caps them with a named constant
   (`MAX_BASH_TARGETS=8` … `| head -n "$MAX_BASH_TARGETS"`) and says so in the header.
   A content guard judges every chunk, one target per writer (`head -n 1`), bounded by
   the command text itself.
5. Resolve a relative target against the payload `.cwd`, never the hook's own cwd. When
   the command holds a `cd`/`pushd` OUTSIDE heredoc bodies, skip relative targets — a
   miss, never a wrong file. The body-stripping awk in `plugins/testing/hooks/protect-tests.sh`
   (the `hascd` lines) is the reference; a `cd` inside a body moves nothing.
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

## What the blocks do NOT see — name these in the hook header

[**recorded** — the header is prose; name each gap your guard inherits]

- interpreter writes: python `open()`, php `file_put_contents`;
- `cp` / `mv` / `install` destinations;
- `{ …; } > f` groups, here-strings `<<<`, printf format substitution;
- a path held in a variable (`> "$out"`);
- a quoted string or `\` continuation spanning lines, a second heredoc on one line;
- a relative target after an in-command `cd` (skipped per step 5);
- targets past your cap.

Deletion (`rm` of a hook or config) is command-guard's `destructive-guard.sh`, not a
write guard's business.

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

## Anti-patterns

- Forking the extractor into a hook-local `cc_<plugin>_bash_chunks` — the fork never
  gets the next fix. The block exists because one hook did exactly that.
- Asking on every Bash call, or on a target that does not exist yet. A guard that fires
  on everything is trained away within a day.
- Claiming "Bash writes covered" in a README or lane row without the gap list beside it.
